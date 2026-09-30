#!/usr/bin/env python3
"""Rasterize the Vektor vector mark for native icon and Apple TV layers."""
from pathlib import Path
import json
import struct
import zlib

root = Path(__file__).resolve().parents[1] / "Resources"
info = {"author":"xcode", "version":1}
def metadata(path, value):
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(dict(value, info=info), indent=2) + "\n")

def png(path, width, height, foreground=False, transparent=False):
    # Independent vector rasterization: dark plate and teal V; no provider artwork.
    points = [(0.16,0.20),(0.34,0.20),(0.50,0.56),(0.66,0.20),(0.84,0.20),(0.59,0.80),(0.41,0.80)]
    size = min(width, height)
    points = [((width-size)/2+x*size, (height-size)/2+y*size) for x,y in points]
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            inside = False
            if foreground:
                for i, (ax,ay) in enumerate(points):
                    bx,by = points[i-1]
                    if (ay > y) != (by > y) and x < (bx-ax)*(y-ay)/(by-ay)+ax:
                        inside = not inside
            rows.extend((81,216,184,255) if inside else (0,0,0,0) if transparent else (15,20,25,255))
    def chunk(kind, data):
        return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data))
    path.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(rows))+chunk(b"IEND",b""))

for platform in ["iOS", "tvOS"]:
    catalog = root / platform / "Assets.xcassets"
    metadata(catalog, {})
    metadata(catalog / "AccentColor.colorset", {"colors":[{"idiom":"universal", "color":{"color-space":"srgb", "components":{"red":"0.28","green":"0.86","blue":"0.76","alpha":"1.0"}}}]})
    if platform == "iOS":
        icon = catalog / "AppIcon.appiconset"
        metadata(icon, {"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}]})
        png(icon / "AppIcon.png",1024,1024,True)
    else:
        brand = catalog / "AppIcon.brandassets"
        assets = []
        for name,width,height in [("Icon",400,240),("StoreIcon",1280,768)]:
            stack = brand / f"{name}.imagestack"
            metadata(stack, {"layers":[{"filename":"Front.imagestacklayer"},{"filename":"Back.imagestacklayer"}]})
            for layer in ["Front", "Back"]:
                folder = stack / f"{layer}.imagestacklayer"
                metadata(folder, {})
                imageset = folder / "Content.imageset"
                scales = [1,2] if name == "Icon" else [1]
                metadata(imageset, {"images":[{"filename":f"image-{scale}x.png", "idiom":"tv", "scale":f"{scale}x"} for scale in scales]})
                for scale in scales:
                    png(imageset / f"image-{scale}x.png",width*scale,height*scale,layer=="Front",layer=="Front")
            assets.append({"filename":f"{name}.imagestack","idiom":"tv","role":"primary-app-icon","size":f"{width}x{height}"})
        shelf = brand / "TopShelf.imageset"
        metadata(shelf,{"images":[{"filename":"shelf.png","idiom":"tv","scale":"1x"},{"filename":"shelf-2x.png","idiom":"tv","scale":"2x"}]})
        png(shelf / "shelf.png",1920,720,True)
        png(shelf / "shelf-2x.png",3840,1440,True)
        assets.append({"filename":"TopShelf.imageset","idiom":"tv","role":"top-shelf-image","size":"1920x720"})
        wide = brand / "TopShelfWide.imageset"
        metadata(wide,{"images":[{"filename":"shelf.png","idiom":"tv","scale":"1x"},{"filename":"shelf-2x.png","idiom":"tv","scale":"2x"}]})
        png(wide / "shelf.png",2320,720,True)
        png(wide / "shelf-2x.png",4640,1440,True)
        assets.append({"filename":"TopShelfWide.imageset","idiom":"tv","role":"top-shelf-image-wide","size":"2320x720"})
        metadata(brand, {"assets":assets})
print("Generated native Vektor icon assets.")
