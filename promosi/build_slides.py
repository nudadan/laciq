"""Membuat gambar promosi LaciQ (Instagram feed 1080x1350 dan Story 1080x1920).

Cara pakai:  python promosi/build_slides.py
Hasil:       promosi/gambar/*.png  (HTML perantara di promosi/_html/)
Butuh Google Chrome (mode headless). Font dan screenshot diambil dari docs/situs-beranda.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.join(os.path.dirname(ROOT), "docs", "situs-beranda").replace("\\", "/")
HTML_DIR = os.path.join(ROOT, "_html")
OUT_DIR = os.path.join(ROOT, "gambar")
CHROME = next(
    (p for p in (
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    ) if os.path.exists(p)),
    None,
)

CSS = """
@font-face{font-family:"SG";src:url(file:///%(site)s/fonts/SpaceGrotesk.woff2) format("woff2");font-weight:300 700}
@font-face{font-family:"PJ";src:url(file:///%(site)s/fonts/PlusJakartaSans.woff2) format("woff2");font-weight:200 800}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:%(w)dpx;height:%(h)dpx;overflow:hidden}
body{font-family:"PJ",system-ui,sans-serif;color:#e9ecf8;
  background:radial-gradient(900px 700px at 85%% -5%%,rgba(138,77,255,.35),transparent 60%%),
             radial-gradient(800px 700px at -10%% 105%%,rgba(79,107,255,.32),transparent 60%%),#0b0f1e;
  position:relative}
.top{position:absolute;left:72px;right:72px;top:%(pad_top)dpx;display:flex;align-items:center;justify-content:space-between}
.brand{display:flex;align-items:center;gap:16px;font-family:"SG";font-weight:700;font-size:34px;letter-spacing:-.01em}
.brand img{width:56px;height:56px;border-radius:14px}
.count{font-size:26px;color:#a1a9c7;font-weight:600}
.copy{position:absolute;left:72px;right:72px;top:%(copy_top)dpx}
.badge{display:inline-block;font-weight:700;font-size:26px;padding:9px 22px;border-radius:999px;margin-bottom:26px;letter-spacing:.02em}
.b-free{background:rgba(52,211,153,.16);color:#34d399;border:2px solid rgba(52,211,153,.4)}
.b-pro{background:rgba(79,107,255,.2);color:#9fb0ff;border:2px solid rgba(79,107,255,.5)}
.b-ult{background:rgba(138,77,255,.22);color:#c9a6ff;border:2px solid rgba(138,77,255,.55)}
h1{font-family:"SG";font-weight:700;font-size:%(h1)dpx;line-height:1.08;letter-spacing:-.025em}
h1 em{font-style:normal;background:linear-gradient(135deg,#7f93ff,#b07bff);-webkit-background-clip:text;background-clip:text;color:transparent}
.sub{margin-top:26px;font-size:%(sub)dpx;line-height:1.4;color:#c3c9e3;font-weight:500}
.phone{position:absolute;left:50%%;transform:translateX(-50%%);width:%(pw)dpx;border-radius:64px 64px 0 0;
  border:12px solid #232b57;border-bottom:none;overflow:hidden;box-shadow:0 30px 80px rgba(0,0,0,.55),0 0 0 2px rgba(255,255,255,.06);
  background:#0b0f1e;top:%(phone_top)dpx;height:%(phone_h)dpx}
.phone img{display:block;width:100%%}
.swipe{position:absolute;right:72px;bottom:44px;font-size:28px;font-weight:700;color:#fff;background:rgba(255,255,255,.1);
  border:2px solid rgba(255,255,255,.16);padding:12px 26px;border-radius:999px;backdrop-filter:blur(6px)}
.center{position:absolute;left:72px;right:72px;top:%(center_top)dpx;text-align:center}
.center .icon{width:200px;height:200px;border-radius:48px;box-shadow:0 24px 70px rgba(79,107,255,.5);margin-bottom:52px}
.pill{display:inline-block;margin-top:44px;font-family:"SG";font-weight:700;font-size:40px;padding:26px 54px;border-radius:999px;
  background:linear-gradient(135deg,#4f6bff,#8a4dff);color:#fff;box-shadow:0 18px 50px rgba(79,107,255,.45)}
.url{margin-top:36px;font-size:32px;color:#a1a9c7;font-weight:600}
.cols{display:grid;grid-template-columns:1fr 1fr;gap:28px;margin-top:44px}
.col{border-radius:32px;padding:34px 32px;font-size:31px;line-height:1.45;font-weight:600}
.col h3{font-family:"SG";font-size:36px;margin-bottom:16px}
.col li{margin:0 0 10px 30px}
.yes{background:rgba(52,211,153,.1);border:2px solid rgba(52,211,153,.35)}
.yes h3{color:#34d399}
.no{background:rgba(251,113,133,.09);border:2px solid rgba(251,113,133,.35)}
.no h3{color:#fb7185}
.items{list-style:none;margin-top:40px}
.items li{display:flex;gap:22px;align-items:flex-start;font-size:40px;line-height:1.3;font-weight:600;margin-bottom:30px;
  background:rgba(255,255,255,.05);border:2px solid rgba(255,255,255,.1);border-radius:30px;padding:28px 32px}
.items li b{flex:none;width:58px;height:58px;border-radius:18px;background:linear-gradient(135deg,#4f6bff,#8a4dff);
  display:flex;align-items:center;justify-content:center;font-family:"SG";font-size:32px;color:#fff;margin-top:2px}
.items li span{color:#a1a9c7;font-weight:500;display:block;font-size:30px;margin-top:6px}
.note{margin-top:34px;font-size:30px;color:#a1a9c7;line-height:1.45;font-weight:500}
"""

PRESETS = {
    "feed": dict(w=1080, h=1350, pad_top=64, copy_top=170, h1=84, sub=38, pw=560, phone_top=690, phone_h=670,
                 center_top=330),
    "story": dict(w=1080, h=1920, pad_top=120, copy_top=330, h1=92, sub=42, pw=620, phone_top=1030, phone_h=1000,
                  center_top=620),
}


def page(kind, body):
    p = PRESETS[kind]
    css = CSS % dict(site=SITE, **p)
    return f'<!doctype html><html lang="id"><head><meta charset="utf-8"><style>{css}</style></head><body>{body}</body></html>'


def top(n=None, total=None):
    c = f'<div class="count">{n} / {total}</div>' if n else ""
    return f'<div class="top"><div class="brand"><img src="file:///{SITE}/img/icon-192.png">LaciQ</div>{c}</div>'


def phone(img):
    return f'<div class="phone"><img src="file:///{SITE}/img/{img}.webp"></div>'


def feature(kind, n, total, badge, bcls, title, sub, img, swipe=True):
    b = f'<span class="badge {bcls}">{badge}</span><br>' if badge else ""
    sw = '<div class="swipe">Geser →</div>' if swipe else ""
    return page(kind, f'{top(n, total) if n else top()}<div class="copy">{b}<h1>{title}</h1><p class="sub">{sub}</p></div>{phone(img)}{sw}')


def cta(kind, n, total, title, sub):
    return page(kind, f'{top(n, total) if n else top()}<div class="center"><img class="icon" src="file:///{SITE}/img/icon-192.png">'
                      f'<h1>{title}</h1><p class="sub">{sub}</p>'
                      f'<div class="pill">Tersedia di Google Play</div>'
                      f'<p class="url">Cari “LaciQ: Catatan Keuangan”<br>laciq.solusimandiri.id</p></div>')


def privacy_body(n, total):
    return (f'{top(n, total)}<div class="copy"><span class="badge b-ult">Ringkasan AI · Ultimate</span><br>'
            '<h1>Yang dikirim ke AI, <em>hanya angka</em></h1>'
            '<div class="cols">'
            '<div class="col yes"><h3>Dikirim</h3><ul><li>Total pengeluaran dan pemasukan</li><li>Nama kategori</li></ul></div>'
            '<div class="col no"><h3>Tidak dikirim</h3><ul><li>Catatan transaksi</li><li>Nama toko</li><li>Tanggal transaksi</li><li>Foto struk</li></ul></div>'
            '</div>'
            '<p class="note">Selalu minta persetujuanmu dulu. AI bisa keliru, jadi anggap ini gambaran, bukan nasihat keuangan.</p></div>'
            '<div class="swipe">Geser →</div>')


def list_slide(kind, n, total, badge, bcls, title, items, note=None, swipe=True):
    lis = "".join(f'<li><b>{i + 1}</b><div>{t}<span>{d}</span></div></li>' for i, (t, d) in enumerate(items))
    nt = f'<p class="note">{note}</p>' if note else ""
    sw = '<div class="swipe">Geser →</div>' if swipe else ""
    return page(kind, f'{top(n, total)}<div class="copy"><span class="badge {bcls}">{badge}</span><br><h1>{title}</h1>'
                      f'<ul class="items">{lis}</ul>{nt}</div>{sw}')


def slides():
    F, S = "feed", "story"
    out = {}
    # Karusel C: Laporan Bulanan dan Excel (6 slide)
    C = "karusel-laporan-excel"
    out[f"{C}-1"] = feature(F, 1, 6, "Premium", "b-pro", "Akhir bulan, <em>uangnya ke mana</em>?",
                            "Laporan Bulanan merangkum bulanmu dalam satu layar, tanpa kamu hitung sendiri.", "laporan")
    out[f"{C}-2"] = list_slide(F, 2, 6, "Laporan Bulanan · Premium", "b-pro", "Sorotan otomatis tiap bulan",
                               [("Pemasukan vs pengeluaran", "Sisa atau defisit, sekali lihat"),
                                ("Anggaran yang lewat", "Kategori yang sudah jebol atau hampir habis"),
                                ("Dibanding bulan lalu", "Di tanggal yang sama, jadi adil"),
                                ("Kategori terbesar", "Ketahuan bocornya di mana")],
                               "Dihitung di HP-mu, tanpa internet.")
    out[f"{C}-3"] = feature(F, 3, 6, "Ultimate", "b-ult", "Mau <em>rangkuman</em> beberapa kalimat?",
                            "Ringkasan AI hanya menerima angka total dan nama kategori, setelah kamu setuju. Bisa keliru, bukan nasihat keuangan.",
                            "ringkasan-ai")
    out[f"{C}-4"] = feature(F, 4, 6, "Premium", "b-pro", "Satu ketukan, <em>jadi Excel</em>",
                            "Pilih bulan ini, 3 bulan terakhir, atau seluruh riwayat. Berkas dibuat di HP-mu dan kamu yang membagikannya.",
                            "excel")
    out[f"{C}-5"] = list_slide(F, 5, 6, "Isi berkas .xlsx", "b-pro", "Lima lembar, <em>siap diolah</em>",
                               [("Ringkasan", "Total periode dan 5 pengeluaran terbesar"),
                                ("Transaksi", "Angka dan tanggal asli, bisa dijumlah dan difilter"),
                                ("Per kategori", "Jumlah transaksi, total, dan porsinya"),
                                ("Per bulan dan per dompet", "Selisih bulanan dan arus tiap dompet")],
                               "CSV tetap gratis untuk semua paket.")
    out[f"{C}-6"] = cta(F, 6, 6, "Laporanmu, <em>tanpa ribet</em>",
                        "Laporan Bulanan dan ekspor Excel ada di paket Premium. Paket gratis ada ekspor CSV.")
    # Karusel A: kenalan (7 slide)
    A = "karusel-kenalan"
    out[f"{A}-1"] = feature(F, 1, 7, None, "", "Gaji habis, tapi <em>ke mana</em>?",
                            "Catat tiap hari dalam hitungan detik, lalu lihat bocornya di mana.", "ringkasan")
    out[f"{A}-2"] = feature(F, 2, 7, "Gratis", "b-free", "Tanpa akun. <em>Tanpa login.</em>",
                            "Pasang, langsung catat. Datamu tersimpan di HP-mu, bukan di server kami.", "transaksi")
    out[f"{A}-3"] = feature(F, 3, 7, "Premium", "b-pro", "Ucapkan, <em>langsung tercatat</em>",
                            "“Makan siang dua puluh lima ribu” mengisi nominal, tanggal, dan kategori. Kamu cek, lalu simpan.", "suara")
    out[f"{A}-4"] = feature(F, 4, 7, "Ultimate", "b-ult", "Foto struk, <em>terisi sendiri</em>",
                            "Nama toko, total, tanggal, dan kategori terisi. Tinggal dicek sebelum disimpan.", "scan-ai")
    out[f"{A}-5"] = feature(F, 5, 7, "Ultimate", "b-ult", "Uang pribadi dan usaha, <em>tidak tercampur</em>",
                            "Sampai 5 buku kas dalam satu aplikasi, dengan saldo dan laporan masing-masing.", "buku-kas")
    out[f"{A}-6"] = feature(F, 6, 7, "Premium", "b-pro", "Laporan bulan ini, <em>sekali lihat</em>",
                            "Sorotan otomatis dihitung di HP-mu, plus ekspor ke Excel bila perlu.", "laporan")
    out[f"{A}-7"] = cta(F, 7, 7, "Mulai catat <em>hari ini</em>",
                        "Paket gratis sudah cukup untuk mencatat, menganggarkan, dan menabung. Menampilkan iklan banner.")
    # Karusel B: AI dan privasi (4 slide)
    B = "karusel-ai-privasi"
    out[f"{B}-1"] = feature(F, 1, 4, "Ultimate", "b-ult", "AI di aplikasi keuangan? <em>Ini batasnya.</em>",
                            "Ringkasan bulanan dibuat AI dari angka, bukan dari catatan pribadimu.", "ringkasan-ai")
    out[f"{B}-2"] = page(F, privacy_body(2, 4))
    out[f"{B}-3"] = feature(F, 3, 4, None, "", "Kamu yang <em>memutuskan</em>",
                            "Ada dialog persetujuan sebelum data apa pun dikirim. Menolak tidak mematikan fitur lain.", "persetujuan-ai")
    out[f"{B}-4"] = cta(F, 4, 4, "Catatan keuangan yang <em>menghormati privasi</em>",
                        "Tanpa akun, data di HP, dan kamu tahu persis apa yang diproses.")
    # Posting tunggal peluncuran
    out["posting-peluncuran"] = feature(F, None, None, None, "", "LaciQ <em>sudah tayang</em> di Google Play",
                                         "Catat uang tanpa daftar akun. Dengan suara, scan struk, dan laporan bulanan.", "ringkasan", swipe=False)
    # Story
    out["story-1-peluncuran"] = feature(S, None, None, None, "", "LaciQ <em>sudah tayang</em>!",
                                         "Catatan keuangan tanpa akun, datamu tetap di HP-mu.", "ringkasan", swipe=False)
    out["story-2-suara"] = feature(S, None, None, "Premium", "b-pro", "Ucapkan, <em>langsung tercatat</em>",
                                    "“Makan siang dua puluh lima ribu.” Formulir terisi, kamu tinggal cek.", "suara", swipe=False)
    out["story-3-ajakan"] = cta(S, None, None, "Coba LaciQ <em>gratis</em>",
                                "Ketuk tautan di stiker untuk membuka Google Play.")
    return out


def main():
    if not CHROME:
        sys.exit("Chrome/Edge tidak ditemukan")
    os.makedirs(HTML_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, html in slides().items():
        kind = "story" if name.startswith("story") else "feed"
        w, h = PRESETS[kind]["w"], PRESETS[kind]["h"]
        hp = os.path.join(HTML_DIR, name + ".html")
        op = os.path.join(OUT_DIR, name + ".png")
        with open(hp, "w", encoding="utf-8") as f:
            f.write(html)
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                        f"--window-size={w},{h}", "--allow-file-access-from-files", "--virtual-time-budget=4000",
                        f"--screenshot={op}", "file:///" + hp.replace("\\", "/")],
                       check=True, capture_output=True, timeout=90)
        print("ok", name)


if __name__ == "__main__":
    main()
