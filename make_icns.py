#!/usr/bin/env python3
"""Generate .icns from a PNG file — no iconutil needed.
Usage: python3 make_icns.py input.png output.icns
"""
import struct, sys, os, subprocess, tempfile

def resize_png(src, size, dst):
    """Resize PNG to exact square dimensions using sips."""
    subprocess.run(
        ["sips", "-z", str(size), str(size), src, "--out", dst],
        capture_output=True
    )
    return os.path.exists(dst)

def make_icns(input_png, output_icns):
    """Create .icns by embedding PNG data for each icon type."""
    tmpdir = tempfile.mkdtemp()
    
    # Make sure source is square 1024x1024
    square = os.path.join(tmpdir, "1024.png")
    resize_png(input_png, 1024, square)
    if not os.path.exists(square):
        print(f"  ✗ Could not resize {input_png}")
        return False
    
    # Icon types and their sizes
    # ic10 = 1024x1024 (512@2x) — most important
    # ic09 = 512x512
    # ic08 = 256x256
    # ic07 = 128x128
    icon_types = [
        (b"ic07", 128),
        (b"ic08", 256),
        (b"ic09", 512),
        (b"ic10", 1024),
    ]
    
    entries = []
    for icon_type, size in icon_types:
        png_path = os.path.join(tmpdir, f"{size}.png")
        if size == 1024:
            png_path = square
        else:
            resize_png(square, size, png_path)
        
        if os.path.exists(png_path):
            with open(png_path, "rb") as f:
                png_data = f.read()
            # Entry = type(4) + total_entry_size(4) + data
            entry_size = 8 + len(png_data)
            entries.append(icon_type + struct.pack(">I", entry_size) + png_data)
    
    if not entries:
        print("  ✗ No icon entries generated")
        return False
    
    # Build icns file: header('icns' + total_size) + entries
    all_entries = b"".join(entries)
    total_size = 8 + len(all_entries)
    icns_data = b"icns" + struct.pack(">I", total_size) + all_entries
    
    with open(output_icns, "wb") as f:
        f.write(icns_data)
    
    print(f"  ✓ AppIcon.icns created ({len(icns_data):,} bytes, {len(entries)} sizes)")
    
    # Cleanup
    import shutil
    shutil.rmtree(tmpdir, ignore_errors=True)
    return True

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 make_icns.py input.png output.icns")
        sys.exit(1)
    
    success = make_icns(sys.argv[1], sys.argv[2])
    sys.exit(0 if success else 1)
