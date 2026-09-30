# google_mlkit_text_recognition referensi recognizer aksara lain (Mandarin,
# Devanagari, Jepang, Korea) yang sengaja tidak kita sertakan (hanya Latin).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Room dibuat lewat refleksi (Room.databaseBuilder -> XxxDatabase_Impl.newInstance()).
# Aturan konsumen dari room-runtime 2.2.5 (dependensi transitif) hanya menjaga NAMA kelas
# turunan RoomDatabase, bukan konstruktornya, sehingga R8 membuang <init>() dan WorkManager
# (androidx.work.impl.WorkDatabase, dipakai lewat InitializationProvider) mati saat startup
# di build rilis: "Failed to create an instance of androidx.work.impl.WorkDatabase".
# Terlihat hanya di build rilis (R8); build debug tidak terkena.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
