"""Membuat aset situs dari screenshot di store-assets/ (tidak di-commit).

Jalankan dari akar repo: python docs/situs-beranda/tools/build_assets.py
Keluaran ke docs/situs-beranda/img dan fonts (ini yang di-deploy).
"""
from PIL import Image
from fontTools import subset
from fontTools.ttLib import TTFont
import os

OUT = "docs/situs-beranda"
RAW = "store-assets/_raw"
ULT = "store-assets/_raw/ultimate"

# (berkas sumber, kotak potong tanpa status bar & bar navigasi, nama keluaran)
SHOTS = [
    (f"{RAW}/01_ringkasan.png", (0, 85, 1220, 2300), "ringkasan"),
    (f"{RAW}/02_transaksi.png", (0, 85, 1220, 2300), "transaksi"),
    (f"{RAW}/03_anggaran.png", (0, 85, 1220, 2300), "anggaran"),
    (f"{RAW}/06_ringkasan_proyeksi.png", (0, 85, 1220, 2300), "proyeksi"),
    (f"{RAW}/04_dompet.png", (0, 85, 1220, 2300), "dompet"),
    (f"{ULT}/U1_pengalih_buku.png", (0, 80, 1220, 2590), "buku-kas"),
    (f"{ULT}/U2_scan_ai.png", (0, 80, 1220, 2590), "scan-ai"),
    (f"{ULT}/U3_ringkasan_warung.png", (0, 80, 1220, 2590), "ringkasan-buku"),
    (f"{ULT}/U3b_ringkasan_grafik.png", (0, 80, 1220, 2590), "grafik"),
]

for src, box, name in SHOTS:
    im = Image.open(src).convert("RGB").crop(box)
    w = 560
    im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    im.save(f"{OUT}/img/{name}.webp", "WEBP", quality=82, method=6)
    print(name, im.size, os.path.getsize(f"{OUT}/img/{name}.webp") // 1024, "KB")

# Ikon
icon = Image.open("assets/icon/icon.png").convert("RGBA")
icon.resize((192, 192), Image.LANCZOS).save(f"{OUT}/img/icon-192.png", optimize=True)
icon.resize((64, 64), Image.LANCZOS).save(f"{OUT}/img/favicon.png", optimize=True)
icon.resize((180, 180), Image.LANCZOS).save(f"{OUT}/img/apple-touch-icon.png", optimize=True)

# Gambar bagikan (Open Graph) 1200x630 dari feature graphic
fg = Image.open("store-assets/feature-graphic-laciq-1024x500.png").convert("RGB")
og = Image.new("RGB", (1200, 630), (11, 15, 30))
scale = 1200 / fg.width
fg2 = fg.resize((1200, round(fg.height * scale)), Image.LANCZOS)
og.paste(fg2, (0, (630 - fg2.height) // 2))
og.save(f"{OUT}/img/og.jpg", quality=88, optimize=True)

# Font: subset Latin ke woff2
text = "".join(chr(c) for c in range(0x20, 0x7F)) + "–—‘’“”•·…→←✓×Rp€"
for name in ("SpaceGrotesk", "PlusJakartaSans"):
    opts = subset.Options()
    opts.flavor = "woff2"
    opts.layout_features = ["*"]
    font = TTFont(f"assets/fonts/{name}.ttf")
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(font)
    font.flavor = "woff2"
    font.save(f"{OUT}/fonts/{name}.woff2")
    print(name, os.path.getsize(f"{OUT}/fonts/{name}.woff2") // 1024, "KB")
