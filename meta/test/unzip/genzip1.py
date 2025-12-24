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
    # We must split data into 65535 byte chunks because the Deflate
    # "Stored" block length header is only 16-bit.
    compressed_data = b""
    offset = 0
    total_len = len(content)

    while True:
        chunk_size = min(total_len - offset, 65535)
        is_final = (offset + chunk_size) == total_len

        chunk = content[offset : offset + chunk_size]

        # Header Byte:
        # Bit 0: BFINAL (1 if last block, 0 if not)
        # Bits 1-2: BTYPE (00 = stored)
        header_byte = 0x01 if is_final else 0x00

        nlen = (~chunk_size) & 0xFFFF

        # <BHH = Byte, UShort, UShort
        block_header = struct.pack('<BHH', header_byte, chunk_size, nlen)
        compressed_data += block_header + chunk

        offset += chunk_size
        if is_final:
            break

    # Calculate Metadata
    crc = zlib.crc32(content)
    compressed_size = len(compressed_data)
    uncompressed_size = len(content) # Use total length here

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