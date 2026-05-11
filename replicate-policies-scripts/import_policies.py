#!/usr/bin/env python3
"""
Policy Import Script
 
Imports exported policy batches to target cluster
Can read from tar.gz archive or directly from batches directory (for immediate mode).

Features:
- Archive extraction and validation
- Checksum verification
- Sequential batch imports (downstream service requirement)
- Adaptive batch splitting: splits failed batches in half and retries
- Exponential backoff retry
- Comprehensive error handling

Requirements:
- Python 3.7+ (standard library only)

Usage:
  # Import from archive
  ./import_policies.py \\
    --archive policies-export.tar.gz \\
    --target-url https://target-cluster:8443 \\
    --target-token TARGET_TOKEN

  # Import from directory (used by export script in immediate mode)
  ./import_policies.py \\
    --batches-dir /path/to/batches \\
    --metadata-file /path/to/metadata.json \\
    --target-url https://target-cluster:8443 \\
    --target-token TARGET_TOKEN
"""

import json
import argparse
import sys
import os
import time
import tempfile
import shutil
import tarfile
import math
import atexit
from typing import List, Tuple

# Import shared utilities
from policy_replication_common import (
    HTTPClient, BatchInfo, ImportStats,
    format_bytes, format_duration, setup_logging, calculate_checksum,
    validate_url, validate_file_exists, validate_directory_exists,
    print_section_header,
    MAX_RETRIES, RETRY_BACKOFF_BASE,
    PRESERVE_POLICY_ID, PRESERVE_POLICY_STATE,
    MIN_PAYLOAD_BYTES
)

# Import-specific constants
MAX_SPLIT_DEPTH = 8  # Maximum recursion depth for batch splitting


class PolicyImporter:
    """Imports policy batches to target cluster"""
    
    def __init__(self, args):
        self.target_url = args.target_url.rstrip('/')
        self.target_token = args.target_token
        self.archive_file = args.archive
        self.batches_dir = args.batches_dir
        self.metadata_file = args.metadata_file
        self.dry_run = args.dry_run
        self.timeout = args.timeout
        
        self.temp_dir = None
        self.http_client = HTTPClient(timeout=self.timeout)
        
        # Register cleanup
        atexit.register(self.cleanup)
        
        self.stats = ImportStats()
        self.logger = setup_logging(args.verbose)
        
        self.metadata = {}
        self.manifest = {}
        # Tracks the LARGEST batch size that has successfully imported
        # Used as a threshold for proactive splitting of subsequent batches
        # Updates when a larger successful batch is encountered
        self.last_successful_batch_size_bytes = None
    
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
    
    def extract_archive(self) -> Tuple[str, str]:
        """
        Extract archive to temporary directory
        
        Returns:
            Tuple of (batches_dir, metadata_file)
        """
        self.logger.info(f"Extracting archive: {self.archive_file}")
        
        self.temp_dir = tempfile.mkdtemp(prefix="policy-import-")
        
        try:
            with tarfile.open(self.archive_file, 'r:gz') as tar:
                tar.extractall(self.temp_dir)
        except Exception as e:
            self.logger.error(f"Failed to extract archive: {e}")
            raise
        
        batches_dir = os.path.join(self.temp_dir, 'batches')
        metadata_file = os.path.join(self.temp_dir, 'metadata.json')
        manifest_file = os.path.join(self.temp_dir, 'manifest.json')
        
        # Validate extracted files
        if not os.path.exists(metadata_file):
            raise Exception("Archive missing metadata.json")
        if not os.path.exists(manifest_file):
            raise Exception("Archive missing manifest.json")
        if not os.path.exists(batches_dir):
            raise Exception("Archive missing batches directory")
        
        self.logger.info("Archive extracted successfully")
        
        return batches_dir, metadata_file
    
    def load_metadata(self, metadata_file: str):
        """Load and validate metadata"""
        self.logger.info("Loading metadata...")
        
        with open(metadata_file, 'r') as f:
            self.metadata = json.load(f)
        
        # Validate metadata
        required_fields = ['version', 'export_timestamp', 'total_policies', 'total_batches']
        for field in required_fields:
            if field not in self.metadata:
                raise Exception(f"Metadata missing required field: {field}")
        
        self.logger.info(f"Metadata loaded: {self.metadata['total_policies']} policies "
                        f"in {self.metadata['total_batches']} batches")
        self.logger.info(f"Exported from: {self.metadata.get('source_cluster', 'unknown')}")
        self.logger.info(f"Export timestamp: {self.metadata.get('export_timestamp', 'unknown')}")
    
    def load_manifest(self):
        """Load and validate manifest"""
        manifest_file = os.path.join(self.temp_dir or os.path.dirname(self.metadata_file), 
                                     'manifest.json')
        
        if not os.path.exists(manifest_file):
            self.logger.warning("No manifest.json found, skipping checksum verification")
            return
        
        self.logger.info("Loading manifest...")
        
        with open(manifest_file, 'r') as f:
            self.manifest = json.load(f)
        
        self.logger.info(f"Manifest loaded: {len(self.manifest.get('batches', []))} batches")
    
    def verify_checksums(self, batches_dir: str) -> bool:
        """Verify batch file checksums against manifest"""
        if not self.manifest or 'batches' not in self.manifest:
            self.logger.warning("No manifest available, skipping checksum verification")
            return True
        
        self.logger.info("Verifying batch checksums...")
        
        all_valid = True
        for batch_entry in self.manifest['batches']:
            filename = batch_entry['filename']
            expected_checksum = batch_entry.get('checksum_sha256')
            
            if not expected_checksum:
                continue
            
            batch_file = os.path.join(batches_dir, filename)
            if not os.path.exists(batch_file):
                self.logger.error(f"Batch file missing: {filename}")
                all_valid = False
                continue
            
            actual_checksum = calculate_checksum(batch_file)
            if actual_checksum != expected_checksum:
                self.logger.error(f"Checksum mismatch for {filename}")
                self.logger.error(f"  Expected: {expected_checksum}")
                self.logger.error(f"  Actual:   {actual_checksum}")
                all_valid = False
            else:
                self.logger.debug(f"Checksum verified: {filename}")
        
        if all_valid:
            self.logger.info("All checksums verified successfully")
        else:
            self.logger.error("Checksum verification failed")
        
        return all_valid
    
    def get_batch_files(self, batches_dir: str) -> List[BatchInfo]:
        """Get list of batch files to import"""
        batch_files = sorted([f for f in os.listdir(batches_dir) if f.endswith('.json')])
        
        batch_infos = []
        for i, filename in enumerate(batch_files, 1):
            file_path = os.path.join(batches_dir, filename)
            
            # Try to get policy count from manifest first
            policy_count = None
            if self.manifest and 'batches' in self.manifest:
                for batch_entry in self.manifest['batches']:
                    if batch_entry['filename'] == filename:
                        policy_count = batch_entry['policy_count']
                        break
            
            # Fallback: load file to count policies
            if policy_count is None:
                with open(file_path, 'r') as f:
                    policies = json.load(f)
                policy_count = len(policies)
            
            batch_info = BatchInfo(
                batch_num=i,
                policy_count=policy_count,
                size_bytes=os.path.getsize(file_path),
                file_path=file_path
            )
            batch_infos.append(batch_info)
        
        return batch_infos
    
    def split_batch(self, batch_file: str, output_dir: str, num_splits: int = 2) -> List[str]:
        """Split a batch JSON array into N smaller files"""
        with open(batch_file, 'r') as f:
            policies = json.load(f)
        
        total_policies = len(policies)
        num_splits = max(1, min(num_splits, total_policies))
        policies_per_split = math.ceil(total_policies / num_splits)
        
        os.makedirs(output_dir, exist_ok=True)
        
        split_files = []
        for i in range(num_splits):
            start_idx = i * policies_per_split
            end_idx = min(start_idx + policies_per_split, total_policies)
            
            if start_idx >= total_policies:
                break
            
            split_policies = policies[start_idx:end_idx]
            split_file = os.path.join(output_dir, f'split_{i+1}.json')
            
            with open(split_file, 'w') as f:
                json.dump(split_policies, f, separators=(',', ':'))
            
            split_size = os.path.getsize(split_file)
            split_files.append(split_file)
            self.logger.info(f"Split {i+1}: {len(split_policies)} policies, {format_bytes(split_size)}")
        
        return split_files
    
    def import_batch_with_retry(self, batch_file: str, batch_id: str,
                                total_batches: int, post_endpoint: str) -> bool:
        """Import a single batch with retry logic"""
        # Read file once with error handling
        try:
            with open(batch_file, 'rb') as f:
                batch_data = f.read()
            policies = json.loads(batch_data.decode('utf-8'))
        except (IOError, OSError) as e:
            self.logger.error(f'Failed to read batch file {batch_id}: {e}')
            return False
        except (UnicodeDecodeError, json.JSONDecodeError) as e:
            self.logger.error(f'Failed to parse batch file {batch_id}: {e}')
            return False
        
        wrapped_payload = {"policies": policies}
        batch_data = json.dumps(wrapped_payload, separators=(',', ':')).encode('utf-8')
        batch_size_bytes = len(batch_data)
        retry_count = 0
        
        while retry_count < MAX_RETRIES:
            if retry_count > 0:
                wait_time = min(RETRY_BACKOFF_BASE ** retry_count, 60)
                self.logger.warning(f"Retry {retry_count}/{MAX_RETRIES} for batch {batch_id} after waiting {wait_time}s...")
                time.sleep(wait_time)
            
            self.logger.info(
                f"Importing batch {batch_id}/{total_batches} "
                f"({len(policies)} policies, {format_bytes(batch_size_bytes)})..."
            )
            
            headers = {
                "Authorization": f"Bearer {self.target_token}",
                "Content-Type": "application/json",
                "Accept": "application/json"
            }
            
            request_start = time.time()
            http_code, body = self.http_client.fetch_with_retry(
                post_endpoint,
                method='POST',
                data=batch_data,
                headers=headers,
                max_retries=1,  # We handle retries here
                logger=self.logger
            )
            request_duration = time.time() - request_start
            
            if http_code in [200, 201]:
                # Track successful request timing
                self.stats.total_request_time += request_duration
                self.stats.request_count += 1
                
                # Update last_successful_batch_size_bytes to track the largest successful batch
                # This allows the threshold to grow as we discover larger batches work
                if (self.last_successful_batch_size_bytes is None or
                    batch_size_bytes > self.last_successful_batch_size_bytes):
                    self.last_successful_batch_size_bytes = batch_size_bytes
                
                self.logger.info(
                    f"Batch {batch_id}/{total_batches} imported successfully "
                    f"in {request_duration:.2f}s"
                )
                return True
            else:
                self.logger.error(
                    f"Batch {batch_id}/{total_batches} failed in "
                    f"{request_duration:.2f}s (HTTP {http_code})"
                )
                if retry_count == MAX_RETRIES - 1:
                    self.logger.error(f"Response: {body}")
                retry_count += 1
        
        return False
    
    def _should_split_batch(self, batch_file: str, batch_id: str, split_level: int) -> bool:
        """
        Determine if batch should be split
        
        Returns:
            True if batch can and should be split, False otherwise
        """
        if split_level >= MAX_SPLIT_DEPTH:
            self.logger.error(f'Max split depth ({MAX_SPLIT_DEPTH}) reached for batch {batch_id}')
            return False
        
        with open(batch_file, 'r') as f:
            policies = json.load(f)
        
        if len(policies) <= 1:
            self.logger.error(f'Cannot split batch {batch_id} further (contains only 1 policy)')
            return False
        
        return True
    
    def _import_split_batches(self, split_files: List[str], batch_id: str,
                              total_batches: int, post_endpoint: str,
                              split_level: int) -> Tuple[int, int]:
        """
        Import split batch files recursively
        
        Returns:
            Tuple of (succeeded_count, failed_count)
        """
        total_succeeded = 0
        total_failed = 0
        
        for i, sub_batch_file in enumerate(split_files, 1):
            sub_batch_id = f'{batch_id}.{i}'
            self.logger.info(f'Importing sub-batch {sub_batch_id} (from split batch {batch_id})')
            
            success, sub_succeeded, sub_failed = self.import_batch_with_splitting(
                sub_batch_file, sub_batch_id, total_batches,
                post_endpoint, split_level + 1
            )
            
            total_succeeded += sub_succeeded
            total_failed += sub_failed
        
        return total_succeeded, total_failed
    
    def import_batch_with_splitting(self, batch_file: str, batch_id: str,
                                    total_batches: int, post_endpoint: str,
                                    split_level: int = 0) -> Tuple[bool, int, int]:
        """
        Import batch with splitting on failure
        
        Args:
            split_level: Current recursion depth (max: MAX_SPLIT_DEPTH)
        
        Returns:
            Tuple of (success, sub_batches_succeeded, sub_batches_failed)
        """
        batch_size_bytes = os.path.getsize(batch_file)
        
        # Proactive splitting: if we have a known successful size and current batch is larger,
        # skip the import attempt and split immediately to avoid timeouts
        if (self.last_successful_batch_size_bytes and
            self.last_successful_batch_size_bytes > 0 and
            batch_size_bytes > self.last_successful_batch_size_bytes and
            self._should_split_batch(batch_file, batch_id, split_level)):
            
            self.logger.info(
                f'Proactively splitting batch {batch_id} '
                f'({format_bytes(batch_size_bytes)} > last successful {format_bytes(self.last_successful_batch_size_bytes)})'
            )
            # Skip to split logic below
        else:
            # Try import with existing retry logic
            if self.import_batch_with_retry(batch_file, batch_id, total_batches, post_endpoint):
                return True, 1, 0
        
        # Check if we should split
        if not self._should_split_batch(batch_file, batch_id, split_level):
            return False, 0, 1
        
        with open(batch_file, 'r') as f:
            policies = json.load(f)
        
        policy_count = len(policies)
        num_splits = 2
        
        if self.last_successful_batch_size_bytes and self.last_successful_batch_size_bytes > 0:
            target_batch_size_bytes = max(self.last_successful_batch_size_bytes, MIN_PAYLOAD_BYTES)
            num_splits = math.ceil(batch_size_bytes / target_batch_size_bytes)
            num_splits = max(2, min(num_splits, policy_count))
            self.logger.warning(
                f'Splitting batch {batch_id} into {num_splits} sub-batches '
                f'(split level: {split_level}, failed size: {format_bytes(batch_size_bytes)}, '
                f'target size: {format_bytes(target_batch_size_bytes)}, '
                f'last successful size: {format_bytes(self.last_successful_batch_size_bytes)})...'
            )
        else:
            self.logger.warning(
                f'Splitting batch {batch_id} into {num_splits} sub-batches '
                f'(split level: {split_level}, failed size: {format_bytes(batch_size_bytes)}, '
                f'no previous successful batch size available)...'
            )
        
        self.stats.batches_split += 1
        
        split_dir_name = f'split_{batch_id.replace(".", "_")}_level{split_level}'
        split_dir = os.path.join(self.temp_dir or tempfile.gettempdir(), split_dir_name)
        split_files = self.split_batch(batch_file, split_dir, num_splits=num_splits)
        
        # Import split batches
        total_succeeded, total_failed = self._import_split_batches(
            split_files, batch_id, total_batches, post_endpoint, split_level
        )
        
        all_success = total_failed == 0
        
        if all_success:
            self.logger.info(f'All sub-batches from batch {batch_id} imported successfully')
        else:
            self.logger.error(f'Some sub-batches from batch {batch_id} failed: '
                            f'{total_succeeded} succeeded, {total_failed} failed')
        
        return all_success, total_succeeded, total_failed
    
    def import_batches(self, batch_infos: List[BatchInfo]):
        """Import batches sequentially to target cluster"""
        if self.dry_run:
            self.logger.warning("DRY RUN MODE - Batches validated but not imported")
            return
        
        self.logger.info("Starting sequential batch import with adaptive splitting...")
        
        # Get preserve settings from metadata
        preserve_id = self.metadata.get('preserve_policy_id', PRESERVE_POLICY_ID)
        preserve_state = self.metadata.get('preserve_policy_state', PRESERVE_POLICY_STATE)
        
        # Build POST endpoint for new public-API v2 endpoint
        post_endpoint = (
            f"{self.target_url}/aiops/api/v2/configuration/policy-batches"
            f"?preservepolicyid={str(preserve_id).lower()}"
            f"&preservepolicystate={str(preserve_state).lower()}"
        )
        
        total_batches = len(batch_infos)
        
        for batch_info in batch_infos:
            _, succeeded, failed = self.import_batch_with_splitting(
                batch_info.file_path,
                str(batch_info.batch_num),
                total_batches,
                post_endpoint
            )
            
            # Accumulate sub-batch results
            self.stats.batches_imported += succeeded
            self.stats.batches_failed += failed
        
        self.logger.info(
            f"All batches processed: {self.stats.batches_imported} succeeded, "
            f"{self.stats.batches_failed} failed"
        )
    
    def print_summary(self):
        """Print summary statistics"""
        print_section_header("Import Summary")
        print(f"Batches imported:        {self.stats.batches_imported}")
        print(f"Batches failed:          {self.stats.batches_failed}")
        print(f"Import time:             {format_duration(self.stats.import_duration)}")
        print(f"Total time:              {format_duration(self.stats.total_duration)}")
        
        if self.stats.batches_split > 0:
            print(f"\nBatches split:           {self.stats.batches_split} batch(es) required splitting")
        
        # Calculate average import time and throughput
        if not self.dry_run and self.stats.request_count > 0:
            avg_import_time = self.stats.total_request_time / self.stats.request_count
            print(f"\nAverage import time:     {avg_import_time:.2f}s")
            
            if self.stats.import_duration > 0:
                total_policies = self.metadata.get('total_policies', 0)
                if total_policies > 0:
                    throughput = total_policies / self.stats.import_duration
                    print(f"Throughput:              {throughput:.1f} policies/sec")
        
        print("=" * 42)
    
    def run(self):
        """Main execution flow"""
        start_time = time.time()
        
        try:
            # Step 1: Extract archive or use provided directory
            if self.archive_file:
                batches_dir, metadata_file = self.extract_archive()
                self.metadata_file = metadata_file
                self.batches_dir = batches_dir
            else:
                batches_dir = self.batches_dir
                metadata_file = self.metadata_file
            
            print()
            
            # Step 2: Load metadata
            self.load_metadata(metadata_file)
            
            print()
            
            # Step 3: Load manifest and verify checksums
            self.load_manifest()
            if not self.verify_checksums(batches_dir):
                if not self.dry_run:
                    raise Exception("Checksum verification failed")
            
            print()
            
            # Step 4: Get batch files
            batch_infos = self.get_batch_files(batches_dir)
            self.logger.info(f"Found {len(batch_infos)} batch files to import")
            
            print()
            
            # Step 5: Import batches
            upload_start = time.time()
            self.import_batches(batch_infos)
            self.stats.import_duration = time.time() - upload_start
            
            self.stats.total_duration = time.time() - start_time
            
            # Step 6: Print summary
            self.print_summary()
            
            if self.stats.batches_failed > 0:
                print()
                self.logger.error("Some batches failed to import")
                sys.exit(1)
            
            print()
            self.logger.info("Policy import completed successfully!")
            
        except KeyboardInterrupt:
            print()
            self.logger.warning("Operation interrupted by user")
            sys.exit(130)
        except Exception as e:
            self.logger.error(f"Import failed: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)
        finally:
            self.cleanup()


def validate_args(args):
    """Validate command-line arguments"""
    if not args.target_url:
        print('Error: --target-url is required', file=sys.stderr)
        sys.exit(1)

    if not args.target_token:
        print('Error: --target-token is required', file=sys.stderr)
        sys.exit(1)
    
    if not validate_url(args.target_url):
        print(f'Error: Invalid target URL: {args.target_url}', file=sys.stderr)
        sys.exit(1)
    
    # Must have either archive or batches-dir + metadata-file
    if args.archive:
        if args.batches_dir or args.metadata_file:
            print('Error: Cannot use --archive with --batches-dir or --metadata-file', file=sys.stderr)
            sys.exit(1)
        validate_file_exists(args.archive, 'Archive file')
    else:
        if not args.batches_dir or not args.metadata_file:
            print('Error: Must provide either --archive or both --batches-dir and --metadata-file',
                  file=sys.stderr)
            sys.exit(1)
        validate_directory_exists(args.batches_dir, 'Batches directory')
        validate_file_exists(args.metadata_file, 'Metadata file')

    if args.timeout <= 0:
        print('Error: --timeout must be a positive integer', file=sys.stderr)
        sys.exit(1)


def main():
    """Main entry point"""
    # Check Python version first
    if sys.version_info < (3, 7):
        print('Error: Python 3.7 or higher is required', file=sys.stderr)
        sys.exit(1)
    
    parser = argparse.ArgumentParser(
        description='Import policies to target cluster',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Import from archive
  %(prog)s --archive policies-export.tar.gz \\
           --target-url https://target:8443 \\
           --target-token $TARGET_TOKEN \\
           --timeout 180

  # Import from directory (used by export script)
  %(prog)s --batches-dir /path/to/batches \\
           --metadata-file /path/to/metadata.json \\
           --target-url https://target:8443 \\
           --target-token $TARGET_TOKEN \\
           --timeout 180
        """
    )
    
    # Required arguments
    parser.add_argument('--target-url', required=True,
                       help='Target cluster URL (e.g., https://target:8443)')
    parser.add_argument('--target-token', required=True,
                       help='Target cluster bearer token')
    
    # Input source (mutually exclusive)
    parser.add_argument('--archive', '-a',
                       help='Input archive file (e.g., policies.tar.gz)')
    parser.add_argument('--batches-dir',
                       help='Directory containing batch files (alternative to --archive)')
    parser.add_argument('--metadata-file',
                       help='Metadata JSON file (required with --batches-dir)')
    
    # Optional arguments
    parser.add_argument('--timeout', type=int, default=120,
                       help='HTTP request timeout in seconds (default: 120)')
    parser.add_argument('--dry-run', action='store_true',
                       help='Validate archive but don\'t import')
    parser.add_argument('--verbose', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Validate arguments
    validate_args(args)
    
    # Display configuration
    print_section_header('Import Configuration')
    print(f'  Target cluster:       {args.target_url}')
    if args.archive:
        print(f'  Input:                {args.archive}')
    else:
        print(f'  Batches directory:    {args.batches_dir}')
        print(f'  Metadata file:        {args.metadata_file}')
    print(f'  Dry run:              {args.dry_run}')
    print(f'  Timeout:              {args.timeout}s')
    print('=' * 42)
    print()
    
    # Run importer
    importer = PolicyImporter(args)
    importer.run()


if __name__ == '__main__':
    main()
