#!/usr/bin/env python3
import sys
import os
import struct

def pack_icns(assets_dir, output_icns):
    mapping = [
        ("icon_16.png", b"icp4"),
        ("icon_32.png", b"icp5"),
        ("icon_64.png", b"icp6"),
        ("icon_128.png", b"ic07"),
        ("icon_256.png", b"ic08"),
        ("icon_512.png", b"ic09"),
        ("icon_1024.png", b"ic10")
    ]
    
    chunks = bytearray()
    for filename, chunk_type in mapping:
        path = os.path.join(assets_dir, filename)
        if not os.path.exists(path):
            print(f"[Warning] Missing {path}")
            continue
        with open(path, "rb") as f:
            png_bytes = f.read()
        chunk_len = len(png_bytes) + 8
        chunks.extend(chunk_type)
        chunks.extend(struct.pack(">I", chunk_len))
        chunks.extend(png_bytes)
        
    total_len = 8 + len(chunks)
    header = b"icns" + struct.pack(">I", total_len)
    
    os.makedirs(os.path.dirname(os.path.abspath(output_icns)), exist_ok=True)
    with open(output_icns, "wb") as f:
        f.write(header + chunks)
        
    print(f"Created {output_icns} ({total_len} bytes)")

if __name__ == "__main__":
    assets = sys.argv[1] if len(sys.argv) > 1 else "assets"
    out = sys.argv[2] if len(sys.argv) > 2 else "assets/AppIcon.icns"
    pack_icns(assets, out)
