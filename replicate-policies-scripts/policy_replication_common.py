#!/usr/bin/env python3
"""
Policy Replication Common Module

Shared utilities, constants, and classes for policy replication scripts.
Used by both export_policies.py and import_policies.py.

Requirements:
- Python 3.7+ (standard library only)
"""

import urllib.parse
import http.client
import logging
import sys
import os
import ssl
import time
import hashlib
from typing import Dict, Optional, Tuple, cast
from dataclasses import dataclass


# Configuration Constants
# Using 100 bytes safety margin for wrapper + encoding variations
IMPORT_WRAPPER_OVERHEAD = 100  # bytes (13 for wrapper + 87 safety margin)
MAX_PAYLOAD_BYTES = int(2 * 1024 * 1024) - IMPORT_WRAPPER_OVERHEAD  # 2 MiB - overhead = 2,097,052 bytes
MIN_PAYLOAD_BYTES = int(1.9 * 1024 * 1024) - IMPORT_WRAPPER_OVERHEAD  # 1.9 MiB - overhead = 1,992,194 bytes
DEFAULT_PAGE_SIZE = 10000
MIN_PAGE_SIZE = 1000
MAX_PAGE_SIZE = 10000
PAGE_SIZE_FALLBACKS = [10000, 5000, 2500, 1000, 500, 250, 100]
MAX_RETRIES = 3
RETRY_BACKOFF_BASE = 2
PRESERVE_POLICY_ID = True
PRESERVE_POLICY_STATE = True
ARCHIVE_VERSION = '1.0'
REQUEST_TIMEOUT = 120
CHUNK_SIZE = 4096
SECTION_WIDTH = 42


@dataclass
class BatchInfo:
    """Information about a created batch"""
    batch_num: int
    policy_count: int
    size_bytes: int
    file_path: str
    checksum: Optional[str] = None


@dataclass
class ExportStats:
    """Statistics for the export process"""
    policies_exported: int = 0
    batches_created: int = 0
    export_duration: float = 0.0
    batch_creation_duration: float = 0.0
    total_duration: float = 0.0
    current_page_size: int = DEFAULT_PAGE_SIZE
    current_max_payload: int = MAX_PAYLOAD_BYTES
    total_request_time: float = 0.0
    request_count: int = 0


@dataclass
class ImportStats:
    """Statistics for the import process"""
    batches_imported: int = 0
    batches_failed: int = 0
    import_duration: float = 0.0
    total_duration: float = 0.0
    batches_split: int = 0
    total_request_time: float = 0.0
    request_count: int = 0


class ColoredFormatter(logging.Formatter):
    """Custom formatter with colors for console output"""
    
    COLORS = {
        'DEBUG': '\033[0;36m',    # Cyan
        'INFO': '\033[0;34m',     # Blue
        'WARNING': '\033[1;33m',  # Yellow
        'ERROR': '\033[0;31m',    # Red
        'SUCCESS': '\033[0;32m',  # Green
        'PROGRESS': '\033[0;36m', # Cyan
    }
    RESET = '\033[0m'
    
    def format(self, record):
        log_color = self.COLORS.get(record.levelname, self.RESET)
        record.levelname = f"{log_color}[{record.levelname}]{self.RESET}"
        return super().format(record)


class HTTPClient:
    """HTTP client with connection reuse, retry logic and SSL support"""
    
    def __init__(self, timeout: int = REQUEST_TIMEOUT):
        self.ssl_context = ssl._create_unverified_context()
        self.timeout = timeout
        self.connection = None  # Persistent connection
        self.current_host = None
        self.current_port = None
    
    def _ensure_connection(self, host: str, port: int):
        """Create or reuse connection to host:port"""
        if (self.connection is None or
            self.current_host != host or
            self.current_port != port):
            # Close old connection if exists
            if self.connection:
                try:
                    self.connection.close()
                except Exception:
                    pass  # Ignore errors when closing old connection
            
            # Create new connection
            self.connection = http.client.HTTPSConnection(
                host, port,
                context=self.ssl_context,
                timeout=self.timeout
            )
            self.current_host = host
            self.current_port = port

    def _parse_url(self, url: str) -> Tuple[str, int, str]:
        """
        Parse URL into components
        
        Returns:
            Tuple of (host, port, path_with_query)
        """
        parsed = urllib.parse.urlparse(url)
        host = parsed.hostname
        if not host:
            raise ValueError(f'Invalid URL: {url}')
        
        port = parsed.port or (443 if parsed.scheme == 'https' else 80)
        path = parsed.path or '/'
        if parsed.query:
            path += '?' + parsed.query
        
        return host, port, path
    
    def fetch_with_retry(self, url: str, method: str = 'GET',
                        data: Optional[bytes] = None,
                        headers: Optional[Dict[str, str]] = None,
                        max_retries: int = MAX_RETRIES,
                        logger: Optional[logging.Logger] = None) -> Tuple[int, str]:
        """
        Request URL with connection reuse and exponential backoff retry
        
        Returns:
            Tuple of (http_code, response_body)
        """
        if headers is None:
            headers = {}
        
        # Parse URL once
        try:
            host, port, path = self._parse_url(url)
        except ValueError as e:
            if logger:
                logger.error(f'URL parsing failed: {e}')
            return 0, str(e)
        
        for retry in range(max_retries):
            try:
                # Ensure connection exists
                self._ensure_connection(host, port)
                
                # Verify connection was established (should never fail, but satisfies type checker)
                assert self.connection is not None, "Connection should be established by _ensure_connection"
                
                # Make request on persistent connection
                self.connection.request(method, path, body=data, headers=headers)
                response = self.connection.getresponse()
                
                # Read response
                try:
                    body = response.read().decode('utf-8')
                except UnicodeDecodeError as e:
                    if logger:
                        logger.error(f'Failed to decode response as UTF-8: {e}')
                    return response.status, ''
                
                status = response.status
                
                # Connection stays open for reuse
                return status, body
                
            except (http.client.HTTPException, OSError, ConnectionError) as e:
                # Connection failed, close and will recreate on next attempt
                if self.connection:
                    try:
                        self.connection.close()
                    except Exception:
                        pass
                    self.connection = None
                
                if retry < max_retries - 1:
                    wait_time = min(RETRY_BACKOFF_BASE ** retry, 60)
                    if logger:
                        logger.warning(f'Request failed: {e}, retrying in {wait_time}s...')
                    time.sleep(wait_time)
                else:
                    if logger:
                        logger.error(f'Request failed after {max_retries} retries: {e}')
                    return 0, str(e)
            
            except Exception as e:
                # Unexpected error
                if self.connection:
                    try:
                        self.connection.close()
                    except Exception:
                        pass
                    self.connection = None
                
                if logger:
                    logger.error(f'Unexpected error: {e}')
                return 0, str(e)
        
        # This should never be reached due to loop logic, but kept for safety
        return 0, 'Max retries exceeded'
    
    def close(self):
        """Close persistent connection"""
        if self.connection:
            try:
                self.connection.close()
            except Exception:
                pass  # Ignore errors when closing
            self.connection = None
            self.current_host = None
            self.current_port = None


def format_bytes(bytes_val: int) -> str:
    """Format bytes in human-readable format with 1 decimal place for KB and MB"""
    if bytes_val < 1024:
        return f"{bytes_val}B"
    elif bytes_val < 1048576:
        return f"{bytes_val / 1024:.1f}KB"
    else:
        return f"{bytes_val / 1048576:.1f}MB"


def format_duration(seconds: float) -> str:
    """Format duration as HH:MM:SS"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def setup_logging(verbose: bool = False) -> logging.Logger:
    """Setup logging configuration"""
    level = logging.DEBUG if verbose else logging.INFO
    
    # Create custom SUCCESS level (25 is between INFO and WARNING)
    success_level = 25
    logging.addLevelName(success_level, 'SUCCESS')
    
    if not hasattr(logging.Logger, 'success'):
        def success(self, message, *args, **kwargs):
            if self.isEnabledFor(success_level):
                self._log(success_level, message, args, **kwargs)
        
        # Add success method to Logger class once
        setattr(logging.Logger, 'success', success)
    
    logger = logging.getLogger(__name__)
    logger.setLevel(level)
    
    if not any(getattr(handler, '_policy_replication_handler', False) for handler in logger.handlers):
        handler = logging.StreamHandler(sys.stderr)
        setattr(handler, '_policy_replication_handler', True)
        formatter = ColoredFormatter('%(levelname)s %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(cast(logging.Handler, handler))
    
    return logger


def calculate_checksum(file_path: str) -> str:
    """Calculate SHA256 checksum of a file"""
    sha256_hash = hashlib.sha256()
    with open(file_path, 'rb') as f:
        for byte_block in iter(lambda: f.read(CHUNK_SIZE), b''):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def validate_url(url: str) -> bool:
    """Validate URL format"""
    try:
        result = urllib.parse.urlparse(url)
        return bool(result.scheme and result.netloc)
    except Exception:
        return False


def validate_file_exists(file_path: str, file_description: str = 'File') -> None:
    """
    Validate that a file exists, exit with error if not
    
    Args:
        file_path: Path to file
        file_description: Description for error message
    """
    if not os.path.exists(file_path):
        print(f'Error: {file_description} not found: {file_path}', file=sys.stderr)
        sys.exit(1)


def validate_directory_exists(dir_path: str, dir_description: str = 'Directory') -> None:
    """
    Validate that a directory exists, exit with error if not
    
    Args:
        dir_path: Path to directory
        dir_description: Description for error message
    """
    if not os.path.exists(dir_path):
        print(f'Error: {dir_description} not found: {dir_path}', file=sys.stderr)
        sys.exit(1)


def print_section_header(title: str, width: int = SECTION_WIDTH):
    """Print a formatted section header"""
    print('\n' + '=' * width)
    print(title)
    print('=' * width)
