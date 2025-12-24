#!/usr/bin/env python3

import os
import struct
import sys
import zlib

def create_zip():
    filename = sys.argv[1].encode() if len(sys.argv) > 1 else b"test.txt"
    content = sys.stdin.buffer.read()
    deflate64 = os.environ.get('DEFLATE64', False)
    if len(content) <= 0:
        content = b"Test"

    # --- 1. Create the Raw Deflate Stream (Stored Block) ---
    # We are faking "compression" by creating a valid Deflate stream
    # that just wraps raw bytes.
    # Header Byte: 0x01
    #   Bit 0 = 1 (BFINAL, this is the last block)
    #   Bits 1-2 = 00 (BTYPE, stored/uncompressed)
    # LEN: 2 bytes, Little Endian length of data
    # NLEN: 2 bytes, Little Endian one's complement of length

    length = len(content)
    nlen = (~length) & 0xFFFF

    # Construct the payload
    # <HH means two unsigned short integers (2 bytes) in Little Endian
    deflate_header = b'\x01' + struct.pack('<HH', length, nlen)
    compressed_data = deflate_header + content

    # Calculate Metadata
    crc = zlib.crc32(content)
    compressed_size = len(compressed_data)
    uncompressed_size = length

    # --- 2. Construct ZIP Headers ---

    # Common Values
    # Version needed: 2.0 (or 2.1 on deflate64)
    # Flags: 0
    # Compression Method: 8 (or 9 for deflate64)
    # Time/Date: 0 (for simplicity)
    ver = deflate64 and 21 or 20
    flags = 0
    method = deflate64 and 9 or 8

    # A. Local File Header
    # Signature (4s) = PK\x03\x04
    lfh_fmt = '<4sHHHHHIIIHH'
    lfh = struct.pack(
        lfh_fmt,
        b'\x50\x4b\x03\x04', # Signature
        ver, flags, method, 0, 0, # Ver, Flags, Method, Time, Date
        crc, compressed_size, uncompressed_size, # CRC, Sizes
        len(filename), 0 # Filename len, Extra len
    )

    # B. Central Directory Header
    # Signature (4s) = PK\x01\x02
    cdh_fmt = '<4sHHHHHHIIIHHHHHII'
    cdh = struct.pack(
        cdh_fmt,
        b'\x50\x4b\x01\x02', # Signature
        ver, ver, flags, method, 0, 0, # MadeBy, Needed, Flags, Method, Time, Date
        crc, compressed_size, uncompressed_size, # CRC, Sizes
        len(filename), 0, 0, # Name len, Extra len, Comment len
        0, 0, 0x81a40000, # Disk Start, Int Attr, Ext Attr (Permissions)
        0 # Relative Offset of Local Header (0 because it's the first file)
    )

    # C. End of Central Directory Record
    # Signature (4s) = PK\x05\x06
    # We need to calculate where the Central Directory starts and how big it is
    offset_of_cd = len(lfh) + len(filename) + compressed_size
    size_of_cd = len(cdh) + len(filename)

    eocd_fmt = '<4sHHHHIIH'
    eocd = struct.pack(
        eocd_fmt,
        b'\x50\x4b\x05\x06', # Signature
        0, 0, 1, 1, # Disk nums, Recs on disk, Total recs
        size_of_cd, offset_of_cd, 0 # CD Size, CD Offset, Comment len
    )

    # --- 3. Write the File ---
    with sys.stdout.buffer as f:
        f.write(lfh)
        f.write(filename)
        f.write(compressed_data)
        f.write(cdh)
        f.write(filename)
        f.write(eocd)

if __name__ == "__main__":
    create_zip()