#!/usr/bin/env python3
"""
Policy Export Script
 
Exports policies from source cluster and prepares them for import.
Can either save to archive (tar.gz) for later import or immediately chain to import script.

Features:
- Cursor-based pagination for efficient policy retrieval
- Adaptive page size retry: respects custom page sizes, falls back to smaller sizes only on failures
- Dynamic batch creation respecting 9.9 MiB payload limit
- Parallel batch creation using ThreadPoolExecutor
- Archive creation with metadata and checksums
- Optional immediate import mode (chains to import_policies.py)

Requirements:
- Python 3.7+ (standard library only)

Usage:
  # Save to archive
  ./export_policies.py \\
    --source-url https://source-cluster:8443 \\
    --source-token SOURCE_TOKEN \\
    --output policies-export.tar.gz

  # Immediate import
  ./export_policies.py \\
    --source-url https://source-cluster:8443 \\
    --source-token SOURCE_TOKEN \\
    --import-now \\
    --target-url https://target-cluster:8443 \\
    --target-token TARGET_TOKEN
"""

import json
import urllib.parse
import argparse
import sys
import os
import time
import tempfile
import shutil
import tarfile
import subprocess
import atexit
from typing import List, Dict, Optional, Tuple, Any
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed

# Import shared utilities
from policy_replication_common import (
    HTTPClient, BatchInfo, ExportStats,
    format_bytes, format_duration, setup_logging, calculate_checksum,
    validate_url,
    print_section_header,
    DEFAULT_PAGE_SIZE, MIN_PAGE_SIZE, MAX_PAGE_SIZE, PAGE_SIZE_FALLBACKS,
    MAX_PAYLOAD_BYTES, MIN_PAYLOAD_BYTES, ARCHIVE_VERSION,
    PRESERVE_POLICY_ID, PRESERVE_POLICY_STATE
)

# JSON array overhead: 2 bytes for "[]"
JSON_ARRAY_OVERHEAD = 2

# Maximum parallel workers for batch creation
# Limited to prevent excessive resource usage
MAX_PARALLEL_WORKERS = 10


class PolicyExporter:
    """Exports policies from source cluster and creates batches"""
    
    def __init__(self, args):
        self.source_url = args.source_url.rstrip('/')
        self.source_token = args.source_token
        self.page_size = args.page_size
        self.max_payload_bytes = args.max_payload_bytes
        self.output_file = args.output
        self.import_now = args.import_now
        
        # Import mode arguments
        self.target_url = args.target_url.rstrip('/') if args.target_url else None
        self.target_token = args.target_token
        self.timeout = args.timeout
        
        self.temp_dir = tempfile.mkdtemp(prefix='policy-export-')
        self.http_client = HTTPClient(timeout=self.timeout)
        
        # Register cleanup only if NOT in import mode
        # (import script needs access to temp files)
        if not args.import_now:
            atexit.register(self.cleanup)
        
        self.stats = ExportStats(
            current_page_size=self.page_size,
            current_max_payload=self.max_payload_bytes
        )
        
        self.logger = setup_logging(args.verbose)
    
    def cleanup(self):
        """Clean up temporary directory and HTTP connection"""
        # Close HTTP connection
        if hasattr(self, 'http_client') and self.http_client:
            try:
                self.http_client.close()
            except Exception as e:
                if hasattr(self, 'logger'):
                    self.logger.warning(f'Failed to close HTTP connection: {e}')
        
        # Clean up temp directory
        if self.temp_dir:
            try:
                shutil.rmtree(self.temp_dir)
            except FileNotFoundError:
                pass  # Already deleted, this is fine
            except Exception as e:
                if hasattr(self, 'logger'):
                    self.logger.warning(f'Failed to clean up temp directory: {e}')
    
    def _build_filter_params(self, page_size: int,
                             cursor_token: Optional[str]) -> str:
        """Build filter parameters for policy export request"""
        filter_obj = {
            'paginationResponseSize': page_size
        }
        if cursor_token:
            filter_obj['searchAfter'] = json.loads(cursor_token)
        
        filter_json = json.dumps(filter_obj, separators=(',', ':'))
        return urllib.parse.quote(filter_json)
    
    def _try_export_with_fallback(self, get_endpoint: str, page_num: int,
                                  filter_params: str, page_size: int, cursor_token: Optional[str] = None) -> Tuple[bool, int, str, int]:
        """
        Try to export page with fallback to smaller page sizes
        
        Returns:
            Tuple of (success, http_code, body, final_page_size)
        """
        # Build dynamic fallback sequence starting with requested size
        fallback_sizes = [page_size]
        for size in PAGE_SIZE_FALLBACKS:
            if size < page_size and size not in fallback_sizes:
                fallback_sizes.append(size)
        
        http_code = 0
        body = ''
        
        for fallback_index, current_page_size in enumerate(fallback_sizes):
            if fallback_index > 0:
                self.logger.warning(f'Retrying page {page_num} with reduced page size: {current_page_size}')
                # Rebuild filter with new page size, preserving cursor
                filter_params = self._build_filter_params(current_page_size, cursor_token)
            
            request_url = f'{get_endpoint}?sort=policyId:asc&filter={filter_params}'
            headers = {
                'Authorization': f'Bearer {self.source_token}',
                'Accept': 'application/json'
            }
            
            request_start = time.time()
            http_code, body = self.http_client.fetch_with_retry(
                request_url, headers=headers, logger=self.logger
            )
            request_duration = time.time() - request_start
            
            if http_code == 200:
                # Track successful request timing
                self.stats.total_request_time += request_duration
                self.stats.request_count += 1
                
                if fallback_index > 0:
                    self.logger.info(f'Page {page_num} exported successfully with reduced page size: {current_page_size}')
                return True, http_code, body, current_page_size
            
            self.logger.warning(f'Export failed with page size {current_page_size} (HTTP {http_code})')
        
        return False, http_code, body, page_size
    
    def _parse_response(self, body: str) -> List[Dict[str, Any]]:
        """Parse JSON response and extract policies array from items property"""
        try:
            response_data = json.loads(body)
            # API returns object with 'items' array property
            return response_data['items']
        except json.JSONDecodeError as e:
            self.logger.error(f'Failed to parse JSON response: {e}')
            # Log first 500 chars for debugging
            preview = body[:500] + ('...' if len(body) > 500 else '')
            self.logger.debug(f'Response body preview: {preview}')
            raise ValueError(f'Invalid JSON response from API: {e}') from e
    
    def _get_next_cursor(self, items: List[Dict[str, Any]], previous_cursor: str) -> Optional[str]:
        """
        Get cursor for next page from items
        
        Returns:
            Next cursor token or None if pagination should stop
        """
        if not items:
            return None
        
        last_policy_id = items[-1].get('id', '')
        if not last_policy_id or last_policy_id == 'null':
            self.logger.warning('Last policy has no ID, stopping pagination')
            return None
        
        new_cursor = json.dumps([last_policy_id])
        
        # Detect infinite loop
        if new_cursor == previous_cursor:
            self.logger.error('Pagination cursor not advancing - possible API issue')
            return None
        
        return new_cursor
    
    def export_policies(self) -> List[Dict[str, Any]]:
        """Export all policies from source cluster with pagination"""
        self.logger.info('Retrieving all policies with cursor-based pagination...')
        
        get_endpoint = f'{self.source_url}/aiops/api/v2/configuration/policies'
        all_policies = []
        page_num = 0
        cursor_token = ''
        previous_cursor = ''
        page_size = self.page_size
        
        while True:
            page_num += 1
            
            # Build filter parameters
            filter_encoded = self._build_filter_params(page_size, cursor_token)
            
            self.logger.info(f'Exporting page {page_num} with page size {page_size} '
                           f'(total: {len(all_policies)} policies)...')
            
            page_export_start = time.time()
            
            # Try export with fallback page sizes
            export_success, http_code, body, final_page_size = self._try_export_with_fallback(
                get_endpoint, page_num, filter_encoded, page_size, cursor_token
            )
            
            if not export_success:
                self.logger.error('Failed to retrieve policies after trying all page sizes')
                self.logger.error(f'Last response (HTTP {http_code}): {body}')
                raise Exception('Policy export failed')
            
            # Update page size if it changed due to fallback
            if final_page_size != page_size:
                self.logger.warning(f'Page size reduced from {page_size} to {final_page_size} due to export failure')
                page_size = final_page_size
                self.stats.current_page_size = page_size
            
            # Parse response
            items = self._parse_response(body)
            page_export_duration = time.time() - page_export_start
            self.logger.info(f'Retrieved {len(items)} policies from page {page_num} '
                           f'in {page_export_duration:.2f}s')
            
            # Add policies
            all_policies.extend(items)
            
            # Check if we're done
            if len(items) < page_size:
                break
            
            # Get cursor for next page
            next_cursor = self._get_next_cursor(items, previous_cursor)
            if not next_cursor:
                break
            
            cursor_token = next_cursor
            previous_cursor = cursor_token
        
        self.logger.info(f'Retrieved total of {len(all_policies)} policies')
        self.stats.policies_exported = len(all_policies)
        return all_policies
    
    def _create_metadata_dict(self, batch_count: int) -> dict:
        """Create metadata dictionary"""
        return {
            'version': ARCHIVE_VERSION,
            'export_timestamp': datetime.now(timezone.utc).isoformat() + 'Z',
            'source_cluster': self.source_url,
            'total_policies': self.stats.policies_exported,
            'total_batches': batch_count,
            'preserve_policy_id': PRESERVE_POLICY_ID,
            'preserve_policy_state': PRESERVE_POLICY_STATE
        }
    
    def _calculate_batch_boundaries(self, policies: List[Dict[str, Any]]) -> List[Tuple[List[Dict[str, Any]], List[str]]]:
        """
        Calculate batch boundaries based on payload size limits
        
        Returns:
            List of tuples (policies, serialized_jsons) for each batch
        """
        self.logger.info(f'Calculating batch boundaries for {len(policies)} policies...')
        batch_data = []
        current_batch = []
        current_batch_jsons = []
        current_batch_bytes = JSON_ARRAY_OVERHEAD  # Start with []
        
        for policy in policies:
            policy_json = json.dumps(policy, separators=(',', ':'))
            policy_bytes = len(policy_json)
            
            projected_batch_size = current_batch_bytes + policy_bytes
            if current_batch:
                projected_batch_size += 1  # Add comma
            
            if policy_bytes > (self.stats.current_max_payload - JSON_ARRAY_OVERHEAD):
                self.logger.error(f'Single policy exceeds payload limit: {policy_bytes} bytes')
                raise Exception('Policy too large for batch')
            
            if projected_batch_size > self.stats.current_max_payload and current_batch:
                batch_data.append((current_batch, current_batch_jsons))
                current_batch = [policy]
                current_batch_jsons = [policy_json]
                current_batch_bytes = JSON_ARRAY_OVERHEAD + policy_bytes
            else:
                current_batch.append(policy)
                current_batch_jsons.append(policy_json)
                current_batch_bytes = projected_batch_size
        
        if current_batch:
            batch_data.append((current_batch, current_batch_jsons))
        
        return batch_data
    
    def create_single_batch(self, policies: List[Dict[str, Any]], serialized_jsons: List[str],
                            batch_num: int, batches_dir: str) -> Optional[BatchInfo]:
        """Create a single batch file from pre-serialized JSON"""
        try:
            batch_file = os.path.join(batches_dir, f'batch_{batch_num:03d}.json')
            
            # Write pre-serialized JSON array
            with open(batch_file, 'w') as f:
                f.write('[')
                f.write(','.join(serialized_jsons))
                f.write(']')
            
            batch_size = os.path.getsize(batch_file)
            checksum = calculate_checksum(batch_file)
            
            return BatchInfo(
                batch_num=batch_num,
                policy_count=len(policies),
                size_bytes=batch_size,
                file_path=batch_file,
                checksum=checksum
            )
        except Exception as e:
            self.logger.error(f"Failed to create batch {batch_num}: {e}")
            return None
    
    def create_batches_parallel(self, policies: List[Dict[str, Any]]) -> List[BatchInfo]:
        """Create batches in parallel using ThreadPoolExecutor"""
        self.logger.info(f'Creating payload-size-limited batches '
                        f'(max: {format_bytes(self.stats.current_max_payload)})...')
        
        batches_dir = os.path.join(self.temp_dir, 'batches')
        os.makedirs(batches_dir, exist_ok=True)
        
        # Calculate batch boundaries (returns policies + serialized JSON)
        batch_data = self._calculate_batch_boundaries(policies)
        
        # Create batch files in parallel
        self.logger.info(f'Creating {len(batch_data)} batch files in parallel...')
        batch_infos = []
        
        with ThreadPoolExecutor(max_workers=min(MAX_PARALLEL_WORKERS, len(batch_data))) as executor:
            futures = {}
            for i, (policies_subset, serialized_jsons) in enumerate(batch_data, 1):
                future = executor.submit(
                    self.create_single_batch,
                    policies_subset,
                    serialized_jsons,  # Pass pre-serialized JSON
                    i,
                    batches_dir
                )
                futures[future] = i
            
            for future in as_completed(futures):
                batch_num = futures[future]
                try:
                    batch_info = future.result()
                    if batch_info:
                        batch_infos.append(batch_info)
                        total_batched = sum(b.policy_count for b in batch_infos)
                        self.logger.info(
                            f"Created batch {batch_info.batch_num}: "
                            f"{batch_info.policy_count} policies, "
                            f"{format_bytes(batch_info.size_bytes)} "
                            f"({total_batched}/{len(policies)})"
                        )
                except Exception as e:
                    self.logger.error(f"Batch {batch_num} creation failed: {e}")
        
        # Sort by batch number
        batch_infos.sort(key=lambda x: x.batch_num)
        
        total_bytes = sum(b.size_bytes for b in batch_infos)
        largest_bytes = max(b.size_bytes for b in batch_infos) if batch_infos else 0
        
        self.logger.info(
            f"Created {len(batch_infos)} batches, "
            f"total: {format_bytes(total_bytes)}, "
            f"largest: {format_bytes(largest_bytes)}"
        )
        
        self.stats.batches_created = len(batch_infos)
        return batch_infos
    
    def create_archive(self, batch_infos: List[BatchInfo]) -> str:
        """Create tar.gz archive with batches and metadata"""
        self.logger.info(f"Creating archive: {self.output_file}")
        
        # Create metadata using shared method
        metadata = self._create_metadata_dict(len(batch_infos))
        # Add archive-specific fields
        metadata.update({
            "export_duration_seconds": self.stats.export_duration,
            "batch_creation_duration_seconds": self.stats.batch_creation_duration,
            "page_size_used": self.stats.current_page_size,
            "max_payload_bytes": self.stats.current_max_payload
        })
        
        metadata_file = os.path.join(self.temp_dir, 'metadata.json')
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        # Create manifest
        manifest = {
            "batches": [
                {
                    "batch_num": b.batch_num,
                    "filename": os.path.basename(b.file_path),
                    "policy_count": b.policy_count,
                    "size_bytes": b.size_bytes,
                    "checksum_sha256": b.checksum
                }
                for b in batch_infos
            ]
        }
        
        manifest_file = os.path.join(self.temp_dir, 'manifest.json')
        with open(manifest_file, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        # Create tar.gz archive
        with tarfile.open(self.output_file, 'w:gz') as tar:
            tar.add(metadata_file, arcname='metadata.json')
            tar.add(manifest_file, arcname='manifest.json')
            
            for batch_info in batch_infos:
                arcname = f"batches/{os.path.basename(batch_info.file_path)}"
                tar.add(batch_info.file_path, arcname=arcname)
        
        archive_size = os.path.getsize(self.output_file)
        self.logger.info(f"Archive created: {format_bytes(archive_size)}")
        
        return self.output_file
    
    def chain_to_import(self, batch_infos: List[BatchInfo]):
        """Chain to import script for immediate import"""
        self.logger.info("Chaining to import script for immediate import...")
        
        # Prepare batches directory for import script
        batches_dir = os.path.join(self.temp_dir, 'batches')
        
        # Create metadata using shared method
        metadata = self._create_metadata_dict(len(batch_infos))
        
        metadata_file = os.path.join(self.temp_dir, 'metadata.json')
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        # Build import command
        script_dir = os.path.dirname(os.path.abspath(__file__))
        import_script = os.path.join(script_dir, 'import_policies.py')
        
        cmd = [
            sys.executable,
            import_script,
            '--batches-dir', batches_dir,
            '--metadata-file', metadata_file,
            '--target-url', self.target_url,
            '--target-token', self.target_token,
            '--timeout', str(self.timeout)
        ]
        
        self.logger.info(f"Executing: {' '.join(cmd[:3])} ...")
        
        try:
            result = subprocess.run(cmd, check=True)
            return result.returncode == 0
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Import script failed with exit code {e.returncode}")
            return False
    
    def print_summary(self):
        """Print summary statistics"""
        print_section_header("Export Summary")
        print(f"Policies exported:       {self.stats.policies_exported}")
        print(f"Batches created:         {self.stats.batches_created}")
        print(f"Export time:             {format_duration(self.stats.export_duration)}")
        print(f"Batch creation time:     {format_duration(self.stats.batch_creation_duration)}")
        print(f"Total time:              {format_duration(self.stats.total_duration)}")
        
        if self.stats.current_page_size != self.page_size:
            print(f"\nPage size adjusted:      {self.page_size} → {self.stats.current_page_size}")
        
        # Calculate average export time
        if self.stats.request_count > 0:
            avg_export_time = self.stats.total_request_time / self.stats.request_count
            print(f"\nAverage export time:     {avg_export_time:.2f}s")
        
        if self.output_file and os.path.exists(self.output_file):
            archive_size = os.path.getsize(self.output_file)
            print(f"\nArchive created:         {self.output_file}")
            print(f"Archive size:            {format_bytes(archive_size)}")
        
        print("=" * 42)
    
    def run(self):
        """Main execution flow"""
        start_time = time.time()
        
        try:
            # Step 1: Export policies
            export_start = time.time()
            policies = self.export_policies()
            self.stats.export_duration = time.time() - export_start
            
            if not policies:
                self.logger.warning("No policies found to process")
                self.stats.total_duration = time.time() - start_time
                self.print_summary()
                return
            
            print()
            
            # Step 2: Create batches
            batch_start = time.time()
            batch_infos = self.create_batches_parallel(policies)
            self.stats.batch_creation_duration = time.time() - batch_start
            
            print()
            
            # Step 3: Either create archive or chain to import
            if self.import_now:
                success = self.chain_to_import(batch_infos)
                if not success:
                    sys.exit(1)
            else:
                self.create_archive(batch_infos)
            
            self.stats.total_duration = time.time() - start_time
            
            # Print summary
            self.print_summary()
            
            print()
            self.logger.info("Policy export completed successfully!")
            
        except KeyboardInterrupt:
            print()
            self.logger.warning("Operation interrupted by user")
            sys.exit(130)
        except Exception as e:
            self.logger.error(f"Export failed: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)
        finally:
            if not self.import_now:
                self.cleanup()


def validate_args(args):
    """Validate command-line arguments"""
    if not args.source_url:
        print('Error: --source-url is required', file=sys.stderr)
        sys.exit(1)

    if not args.source_token:
        print('Error: --source-token is required', file=sys.stderr)
        sys.exit(1)
    
    if not validate_url(args.source_url):
        print(f'Error: Invalid source URL: {args.source_url}', file=sys.stderr)
        sys.exit(1)
    
    if args.import_now:
        if not args.target_url:
            print('Error: --import-now requires --target-url', file=sys.stderr)
            sys.exit(1)
        if not args.target_token:
            print('Error: --target-token is required when using --import-now', file=sys.stderr)
            sys.exit(1)
        if not validate_url(args.target_url):
            print(f'Error: Invalid target URL: {args.target_url}', file=sys.stderr)
            sys.exit(1)
    else:
        if not args.output:
            print('Error: --output is required when not using --import-now', file=sys.stderr)
            sys.exit(1)
    
    if not (MIN_PAGE_SIZE <= args.page_size <= MAX_PAGE_SIZE):
        print(f'Error: --page-size must be between {MIN_PAGE_SIZE} and {MAX_PAGE_SIZE}',
              file=sys.stderr)
        sys.exit(1)
    
    if args.max_payload_bytes < MIN_PAYLOAD_BYTES:
        print(f'Error: --max-payload-bytes must be >= {MIN_PAYLOAD_BYTES} (1.9 MiB)',
              file=sys.stderr)
        sys.exit(1)

    if args.timeout <= 0:
        print('Error: --timeout must be a positive integer', file=sys.stderr)
        sys.exit(1)


def main():
    """Main entry point"""
    # Check Python version
    if sys.version_info < (3, 7):
        print('Error: Python 3.7 or higher is required', file=sys.stderr)
        sys.exit(1)

    parser = argparse.ArgumentParser(
        description='Export policies from source cluster',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Save to archive
  %(prog)s --source-url https://source:8443 \\
           --source-token $SOURCE_TOKEN \\
           --timeout 180 \\
           --output policies-export.tar.gz

  # Immediate import
  %(prog)s --source-url https://source:8443 \\
           --source-token $SOURCE_TOKEN \\
           --import-now \\
           --target-url https://target:8443 \\
           --target-token $TARGET_TOKEN \\
           --timeout 180
        """
    )
    
    # Required arguments
    parser.add_argument('--source-url', required=True,
                       help='Source cluster URL (e.g., https://source:8443)')
    parser.add_argument('--source-token', required=True,
                       help='Source cluster bearer token')
    
    # Output mode
    parser.add_argument('--output', '-o',
                       help='Output archive file (e.g., policies.tar.gz)')
    parser.add_argument('--import-now', action='store_true',
                       help='Immediately import to target (no archive created)')
    
    # Import mode arguments
    parser.add_argument('--target-url',
                       help='Target cluster URL (required with --import-now)')
    parser.add_argument('--target-token',
                       help='Target cluster bearer token (required with --import-now)')
    
    # Optional arguments
    parser.add_argument('--page-size', type=int, default=DEFAULT_PAGE_SIZE,
                       help=f'Initial page size for exporting policies ({MIN_PAGE_SIZE}-{MAX_PAGE_SIZE}, '
                            f'default: {DEFAULT_PAGE_SIZE})')
    parser.add_argument('--max-payload-bytes', type=int, default=MAX_PAYLOAD_BYTES,
                       help=f'Maximum JSON payload size per batch in bytes '
                            f'(default: {MAX_PAYLOAD_BYTES} = 2 MiB)')
    parser.add_argument('--timeout', type=int, default=120,
                       help='HTTP request timeout in seconds (default: 120)')
    parser.add_argument('--verbose', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Validate arguments
    validate_args(args)
    
    # Display configuration
    print_section_header('Export Configuration')
    print(f'  Source cluster:       {args.source_url}')
    if args.import_now:
        print(f'  Mode:                 Immediate import')
        print(f'  Target cluster:       {args.target_url}')
    else:
        print(f'  Mode:                 Save to archive')
        print(f'  Output file:          {args.output}')
    print(f'  Page size:            {args.page_size} policies/page')
    print(f'  Max payload:          {format_bytes(args.max_payload_bytes)}')
    print(f'  Timeout:              {args.timeout}s')
    print('=' * 42)
    print()
    
    # Run exporter
    exporter = PolicyExporter(args)
    exporter.run()


if __name__ == '__main__':
    main()
