// Membuat unduh/template-buku-kas-umkm.xlsx (halaman /template-buku-kas-umkm).
// Pakai: npm install exceljs (di folder mana pun), lalu
//   NODE_PATH=<folder>/node_modules node build_template_xlsx.js <berkas-keluaran.xlsx>
// Semua angka di Ringkasan dihitung dengan rumus, tanpa makro. Baris contoh berawalan "Contoh:".
const ExcelJS = require('exceljs');

const out = process.argv[2] || 'template-buku-kas-umkm.xlsx';
const LAST = 1004; // baris data terakhir (baris 5..1004 = 1.000 baris)
const FIRST = 5;

const C = {
  head: 'FF1F2A5C', headText: 'FFFFFFFF', input: 'FFFFF9E5', sample: 'FF8A8FA8',
  band: 'FFEEF1FF', ok: 'FFD1FAE5', bad: 'FFFEE2E2', line: 'FFD0D5E8',
};
const thin = { style: 'thin', color: { argb: C.line } };
const box = { top: thin, left: thin, bottom: thin, right: thin };
const RP = '#,##0;[Red]-#,##0';
const TGL = 'dd/mm/yyyy';

const wb = new ExcelJS.Workbook();
wb.creator = 'LaciQ';
wb.title = 'Template Buku Kas UMKM';
wb.calcProperties.fullCalcOnLoad = true;

function headRow(ws, rowNum, labels) {
  const r = ws.getRow(rowNum);
  labels.forEach((t, i) => {
    const c = r.getCell(i + 1);
    c.value = t;
    c.font = { bold: true, color: { argb: C.headText } };
    c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: C.head } };
    c.alignment = { vertical: 'middle', horizontal: 'center', wrapText: true };
    c.border = box;
  });
  r.height = 30;
}
function title(ws, text, sub) {
  ws.getCell('A1').value = text;
  ws.getCell('A1').font = { bold: true, size: 16, color: { argb: C.head } };
  if (sub) { ws.getCell('A2').value = sub; ws.getCell('A2').font = { italic: true, color: { argb: 'FF555B7A' } }; }
}

const wsP = wb.addWorksheet('Petunjuk', { properties: { tabColor: { argb: 'FF1F2A5C' } } });

// ---------- Daftar (kategori, bisa diubah) ----------
const kategoriMasuk = ['Penjualan', 'Jasa', 'Modal disetor', 'Pinjaman diterima', 'Pendapatan lain'];
const kategoriKeluar = ['Bahan baku/stok', 'Gaji & upah', 'Sewa', 'Listrik, air & internet', 'Transport & kirim', 'Pemasaran & iklan', 'Peralatan', 'Pajak & biaya admin', 'Cicilan usaha', 'Lain-lain'];
const wsD = wb.addWorksheet('Daftar', { properties: { tabColor: { argb: 'FF9AA3C7' } } });
title(wsD, 'Daftar kategori', 'Ubah nama kategori sesuai usahamu. Pilihan di lembar Kas Masuk/Kas Keluar mengikuti daftar ini.');
headRow(wsD, 4, ['Kategori Kas Masuk', 'Kategori Kas Keluar']);
for (let i = 0; i < 15; i++) {
  const r = FIRST + i;
  [kategoriMasuk[i], kategoriKeluar[i]].forEach((v, j) => {
    const c = wsD.getCell(r, j + 1);
    c.value = v || null;
    c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: C.input } };
    c.border = box;
  });
}
wsD.getColumn(1).width = 30; wsD.getColumn(2).width = 30;
const listMasuk = 'Daftar!$A$5:$A$19';
const listKeluar = 'Daftar!$B$5:$B$19';

// ---------- Kas Masuk ----------
const wsM = wb.addWorksheet('Kas Masuk', { properties: { tabColor: { argb: 'FF34D399' } }, views: [{ state: 'frozen', ySplit: 4 }] });
title(wsM, 'Kas Masuk', 'Catat setiap uang yang masuk ke usaha. Kolom berlatar kuning diisi manual.');
headRow(wsM, 4, ['Tanggal', 'Keterangan', 'Kategori', 'Dari (pelanggan/sumber)', 'Jumlah (Rp)']);
const sampleM = [
  ['2026-11-02', 'Contoh: penjualan harian', 'Penjualan', 'Pelanggan umum', 850000],
  ['2026-11-05', 'Contoh: pesanan katering', 'Jasa', 'Ibu Sari', 1500000],
  ['2026-11-10', 'Contoh: modal tambahan', 'Modal disetor', 'Pemilik', 2000000],
];
// ---------- Kas Keluar ----------
const wsK = wb.addWorksheet('Kas Keluar', { properties: { tabColor: { argb: 'FFFB7185' } }, views: [{ state: 'frozen', ySplit: 4 }] });
title(wsK, 'Kas Keluar', 'Kolom "Untuk" memisahkan pengeluaran usaha dari uang yang kamu ambil untuk pribadi (Prive).');
headRow(wsK, 4, ['Tanggal', 'Keterangan', 'Kategori', 'Untuk', 'Jumlah (Rp)']);
const sampleK = [
  ['2026-11-03', 'Contoh: belanja bahan', 'Bahan baku/stok', 'Usaha', 420000],
  ['2026-11-07', 'Contoh: bayar listrik toko', 'Listrik, air & internet', 'Usaha', 250000],
  ['2026-11-12', 'Contoh: ambil untuk pribadi', 'Lain-lain', 'Prive', 500000],
];

function fillSheet(ws, sample, listRef, jenisCol4) {
  for (let r = FIRST; r <= LAST; r++) {
    for (let c = 1; c <= 5; c++) {
      const cell = ws.getCell(r, c);
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: C.input } };
      cell.border = box;
    }
    ws.getCell(r, 1).numFmt = TGL;
    ws.getCell(r, 5).numFmt = RP;
  }
  sample.forEach((row, i) => {
    const r = FIRST + i;
    const [d, ket, kat, c4, jml] = row;
    ws.getCell(r, 1).value = new Date(d + 'T00:00:00Z');
    ws.getCell(r, 2).value = ket;
    ws.getCell(r, 3).value = kat;
    ws.getCell(r, 4).value = c4;
    ws.getCell(r, 5).value = jml;
    for (let c = 1; c <= 5; c++) ws.getCell(r, c).font = { italic: true, color: { argb: C.sample } };
  });
  ws.dataValidations.add(`A${FIRST}:A${LAST}`, { type: 'date', operator: 'greaterThan', formulae: [new Date('2000-01-01T00:00:00Z')], allowBlank: true, showErrorMessage: true, errorTitle: 'Tanggal tidak valid', error: 'Isi tanggal, misalnya 15/11/2026.' });
  ws.dataValidations.add(`C${FIRST}:C${LAST}`, { type: 'list', formulae: [listRef], allowBlank: true, showErrorMessage: false });
  ws.dataValidations.add(`E${FIRST}:E${LAST}`, { type: 'decimal', operator: 'greaterThanOrEqual', formulae: [0], allowBlank: true, showErrorMessage: true, errorTitle: 'Jumlah tidak valid', error: 'Isi angka tanpa tanda minus. Uang keluar dicatat di lembar Kas Keluar.' });
  ws.getColumn(1).width = 14; ws.getColumn(2).width = 38; ws.getColumn(3).width = 26; ws.getColumn(4).width = 26; ws.getColumn(5).width = 18;
}
fillSheet(wsM, sampleM, listMasuk);
fillSheet(wsK, sampleK, listKeluar);
wsK.dataValidations.add(`D${FIRST}:D${LAST}`, { type: 'list', formulae: ['"Usaha,Prive"'], allowBlank: true, showErrorMessage: true, errorTitle: 'Pilih salah satu', error: 'Pilih Usaha atau Prive.' });

// ---------- Ringkasan Bulanan ----------
const wsR = wb.addWorksheet('Ringkasan Bulanan', { properties: { tabColor: { argb: 'FF4F6BFF' } } });
title(wsR, 'Ringkasan Bulanan', 'Terhitung otomatis dari lembar Kas Masuk dan Kas Keluar. Jangan ketik di sel tanpa latar kuning.');
wsR.getCell('A3').value = 'Tahun'; wsR.getCell('A3').font = { bold: true };
wsR.getCell('B3').value = 2026;
wsR.getCell('A4').value = 'Saldo awal tahun (Rp)'; wsR.getCell('A4').font = { bold: true };
wsR.getCell('B4').value = 0; wsR.getCell('B4').numFmt = RP;
['B3', 'B4'].forEach(a => { wsR.getCell(a).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: C.input } }; wsR.getCell(a).border = box; });
wsR.getCell('C3').value = 'Ganti tahun untuk melihat tahun lain.'; wsR.getCell('C4').value = 'Uang usaha yang kamu pegang di awal tahun (kas + saldo rekening usaha).';
['C3', 'C4'].forEach(a => { wsR.getCell(a).font = { italic: true, color: { argb: 'FF555B7A' } }; });
headRow(wsR, 6, ['Bulan', 'Kas Masuk', 'Kas Keluar (Usaha)', 'Laba Kas Usaha', 'Prive (ambil pribadi)', 'Saldo Akhir']);
const bulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
bulan.forEach((nama, i) => {
  const r = 7 + i;
  const rows = `${i + 1}`;
  const rng = (sheet, col) => `'${sheet}'!$${col}$${FIRST}:$${col}$${LAST}`;
  const win = (sheet) => `${rng(sheet, 'A')},">="&DATE($B$3,${rows},1),${rng(sheet, 'A')},"<"&DATE($B$3,${rows}+1,1)`;
  wsR.getCell(r, 1).value = nama;
  wsR.getCell(r, 2).value = { formula: `SUMIFS(${rng('Kas Masuk', 'E')},${win('Kas Masuk')})` };
  wsR.getCell(r, 3).value = { formula: `SUMIFS(${rng('Kas Keluar', 'E')},${win('Kas Keluar')},${rng('Kas Keluar', 'D')},"Usaha")` };
  wsR.getCell(r, 4).value = { formula: `B${r}-C${r}` };
  wsR.getCell(r, 5).value = { formula: `SUMIFS(${rng('Kas Keluar', 'E')},${win('Kas Keluar')},${rng('Kas Keluar', 'D')},"Prive")` };
  wsR.getCell(r, 6).value = { formula: i === 0 ? `$B$4+D${r}-E${r}` : `F${r - 1}+D${r}-E${r}` };
  for (let c = 1; c <= 6; c++) {
    const cell = wsR.getCell(r, c);
    cell.border = box;
    if (c > 1) cell.numFmt = RP;
    if (i % 2 === 1) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: C.band } };
  }
});
const tr = 19;
wsR.getCell(tr, 1).value = 'Total tahun';
[['B', 'B'], ['C', 'C'], ['D', 'D'], ['E', 'E']].forEach(([col]) => { wsR.getCell(`${col}${tr}`).value = { formula: `SUM(${col}7:${col}18)` }; });
wsR.getCell(`F${tr}`).value = { formula: 'F18' };
for (let c = 1; c <= 6; c++) {
  const cell = wsR.getCell(tr, c);
  cell.font = { bold: true }; cell.border = { ...box, top: { style: 'medium', color: { argb: C.head } } };
  if (c > 1) cell.numFmt = RP;
}
wsR.getCell('A20').value = 'Laba Kas Usaha = Kas Masuk dikurangi Kas Keluar (Usaha). Ini hitungan uang tunai, bukan laporan laba rugi akuntansi. Modal disetor dan pinjaman yang diterima ikut terhitung sebagai Kas Masuk.';
wsR.getCell('A20').font = { italic: true, size: 10, color: { argb: 'FF555B7A' } };
wsR.mergeCells('A20:F21'); wsR.getCell('A20').alignment = { wrapText: true, vertical: 'top' };
wsR.getColumn(1).width = 26; for (let c = 2; c <= 6; c++) wsR.getColumn(c).width = 20;
wsR.getColumn(3).width = 22;

// Ringkasan per kategori
headRow(wsR, 23, ['Kategori Kas Masuk (setahun)', 'Total (Rp)', '', 'Kategori Kas Keluar Usaha (setahun)', 'Total (Rp)', '']);
for (let i = 0; i < 15; i++) {
  const r = 24 + i;
  const src = FIRST + i;
  const yr = (sheet) => `'${sheet}'!$A$${FIRST}:$A$${LAST},">="&DATE($B$3,1,1),'${sheet}'!$A$${FIRST}:$A$${LAST},"<"&DATE($B$3+1,1,1)`;
  wsR.getCell(r, 1).value = { formula: `IF(Daftar!A${src}="","",Daftar!A${src})` };
  wsR.getCell(r, 2).value = { formula: `IF(A${r}="","",SUMIFS('Kas Masuk'!$E$${FIRST}:$E$${LAST},'Kas Masuk'!$C$${FIRST}:$C$${LAST},A${r},${yr('Kas Masuk')}))` };
  wsR.getCell(r, 4).value = { formula: `IF(Daftar!B${src}="","",Daftar!B${src})` };
  wsR.getCell(r, 5).value = { formula: `IF(D${r}="","",SUMIFS('Kas Keluar'!$E$${FIRST}:$E$${LAST},'Kas Keluar'!$C$${FIRST}:$C$${LAST},D${r},'Kas Keluar'!$D$${FIRST}:$D$${LAST},"Usaha",${yr('Kas Keluar')}))` };
  [1, 2, 4, 5].forEach(c => { wsR.getCell(r, c).border = box; });
  wsR.getCell(r, 2).numFmt = RP; wsR.getCell(r, 5).numFmt = RP;
}

// ---------- Utang Piutang ----------
const wsU = wb.addWorksheet('Utang Piutang', { properties: { tabColor: { argb: 'FFFBBF24' } }, views: [{ state: 'frozen', ySplit: 8 }] });
title(wsU, 'Utang & Piutang', 'Piutang = orang lain berutang kepadamu. Utang = kamu berutang kepada orang lain. Isi "Dibayar" setiap ada pembayaran.');
wsU.getCell('A4').value = 'Total Piutang belum dibayar'; wsU.getCell('A4').font = { bold: true };
wsU.getCell('C4').value = { formula: `SUMIFS($H$9:$H$508,$B$9:$B$508,"Piutang")` };
wsU.getCell('A5').value = 'Total Utang belum dibayar'; wsU.getCell('A5').font = { bold: true };
wsU.getCell('C5').value = { formula: `SUMIFS($H$9:$H$508,$B$9:$B$508,"Utang")` };
wsU.getCell('A6').value = 'Jatuh tempo terlewat (jumlah catatan)'; wsU.getCell('A6').font = { bold: true };
wsU.getCell('C6').value = { formula: `COUNTIF($I$9:$I$508,"Terlambat")` };
['C4', 'C5'].forEach(a => { wsU.getCell(a).numFmt = RP; });
['C4', 'C5', 'C6'].forEach(a => { wsU.getCell(a).font = { bold: true }; wsU.getCell(a).border = box; });
headRow(wsU, 8, ['Tanggal', 'Jenis', 'Nama', 'Keterangan', 'Jumlah (Rp)', 'Jatuh tempo', 'Dibayar (Rp)', 'Sisa (Rp)', 'Status']);
const UL = 508;
for (let r = 9; r <= UL; r++) {
  for (let c = 1; c <= 9; c++) {
    const cell = wsU.getCell(r, c);
    cell.border = box;
    if (c <= 7) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: C.input } };
  }
  wsU.getCell(r, 1).numFmt = TGL; wsU.getCell(r, 6).numFmt = TGL;
  wsU.getCell(r, 5).numFmt = RP; wsU.getCell(r, 7).numFmt = RP; wsU.getCell(r, 8).numFmt = RP;
  wsU.getCell(r, 8).value = { formula: `IF(E${r}="","",E${r}-N(G${r}))` };
  wsU.getCell(r, 9).value = { formula: `IF(E${r}="","",IF(E${r}-N(G${r})<=0,"Lunas",IF(AND(F${r}<>"",F${r}<TODAY()),"Terlambat","Belum lunas")))` };
}
const sampleU = [
  ['2026-11-04', 'Piutang', 'Contoh: Toko Maju', 'Contoh: pesanan 20 kotak', 600000, '2026-11-20', 200000],
  ['2026-11-06', 'Utang', 'Contoh: Pemasok tepung', 'Contoh: bahan baku tempo', 450000, '2026-11-25', 0],
];
sampleU.forEach((row, i) => {
  const r = 9 + i;
  wsU.getCell(r, 1).value = new Date(row[0] + 'T00:00:00Z');
  wsU.getCell(r, 2).value = row[1]; wsU.getCell(r, 3).value = row[2]; wsU.getCell(r, 4).value = row[3];
  wsU.getCell(r, 5).value = row[4]; wsU.getCell(r, 6).value = new Date(row[5] + 'T00:00:00Z'); wsU.getCell(r, 7).value = row[6];
  for (let c = 1; c <= 7; c++) wsU.getCell(r, c).font = { italic: true, color: { argb: C.sample } };
});
wsU.dataValidations.add(`B9:B${UL}`, { type: 'list', formulae: ['"Piutang,Utang"'], allowBlank: true, showErrorMessage: true, errorTitle: 'Pilih salah satu', error: 'Pilih Piutang atau Utang.' });
wsU.dataValidations.add(`E9:E${UL}`, { type: 'decimal', operator: 'greaterThanOrEqual', formulae: [0], allowBlank: true, showErrorMessage: true, errorTitle: 'Jumlah tidak valid', error: 'Isi angka tanpa tanda minus.' });
wsU.conditionalFormattings.push(
  { ref: `I9:I${UL}`, rules: [
    { type: 'cellIs', operator: 'equal', formulae: ['"Lunas"'], style: { fill: { type: 'pattern', pattern: 'solid', bgColor: { argb: C.ok } } } },
    { type: 'cellIs', operator: 'equal', formulae: ['"Terlambat"'], style: { fill: { type: 'pattern', pattern: 'solid', bgColor: { argb: C.bad } } } },
  ] });
[14, 11, 26, 30, 16, 14, 16, 16, 14].forEach((w, i) => { wsU.getColumn(i + 1).width = w; });
wsU.getColumn(1).width = 14;
// label ringkasan memakai A:B digabung
['A4:B4', 'A5:B5', 'A6:B6'].forEach(r => wsU.mergeCells(r));

// ---------- Petunjuk (sheet pertama) ----------
wsP.getColumn(1).width = 110;
const lines = [
  ['Template Buku Kas UMKM', 'h'],
  ['Gratis dari LaciQ (laciq.solusimandiri.id). Tidak ada makro, tidak perlu internet, tidak perlu daftar.', 'i'],
  ['', ''],
  ['Cara pakai (3 langkah)', 'b'],
  ['1. Hapus baris contoh (tulisannya abu-abu miring dan berawalan "Contoh:") di lembar Kas Masuk, Kas Keluar, dan Utang Piutang.', ''],
  ['2. Catat setiap uang masuk di Kas Masuk dan setiap uang keluar di Kas Keluar. Kolom "Untuk" membedakan pengeluaran Usaha dari uang yang kamu ambil untuk pribadi (Prive).', ''],
  ['3. Buka Ringkasan Bulanan. Isi Tahun dan Saldo awal tahun, lalu lihat kas masuk, kas keluar, laba kas, prive, dan saldo tiap bulan.', ''],
  ['', ''],
  ['Aturan singkat', 'b'],
  ['• Sel berlatar kuning diisi manual. Sel lain berisi rumus, jangan diketik ulang.', ''],
  ['• Template menampung 1.000 baris Kas Masuk, 1.000 baris Kas Keluar, dan 500 catatan utang/piutang. Untuk lebih banyak, buat salinan berkas per tahun.', ''],
  ['• Nama kategori bisa diubah di lembar Daftar.', ''],
  ['• Tulis jumlah sebagai angka positif. Uang keluar dicatat di Kas Keluar, bukan sebagai angka minus.', ''],
  ['• Jangan mengganti kata "Usaha" dan "Prive" di kolom Untuk, serta "Piutang" dan "Utang" di Utang Piutang: rumus mencarinya persis.', ''],
  ['', ''],
  ['Batasan', 'b'],
  ['Template ini pencatat uang tunai sederhana, bukan laporan laba rugi, neraca, atau perhitungan pajak. Untuk pembukuan resmi atau pajak, tanyakan akuntan atau konsultan pajak.', ''],
  ['', ''],
  ['Bosan mengetik di Excel?', 'b'],
  ['LaciQ (aplikasi Android) mencatat dari HP dan bisa mengekspor laporan ke Excel (fitur Premium). Tanpa akun, data tersimpan di HP-mu. Cari "LaciQ: Buku Kas & Catatan Uang" di Google Play.', ''],
];
lines.forEach(([t, k], i) => {
  const c = wsP.getCell(i + 1, 1);
  c.value = t;
  c.alignment = { wrapText: true, vertical: 'top' };
  if (k === 'h') c.font = { bold: true, size: 20, color: { argb: C.head } };
  if (k === 'b') c.font = { bold: true, size: 13, color: { argb: C.head } };
  if (k === 'i') c.font = { italic: true, color: { argb: 'FF555B7A' } };
});

wb.xlsx.writeFile(out).then(() => console.log('OK', out));
