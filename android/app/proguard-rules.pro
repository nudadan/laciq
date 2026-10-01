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

# ML Kit (pembacaan teks struk): di build rilis dari Play, TextRecognizer.processImage
# gagal dengan NullPointerException di kelas internal vision-common
# (com.google.android.gms.internal.mlkit_vision_common.zzmj.<init>) karena R8
# memangkas/mengubah kelas yang diakses lewat refleksi/komponen. Terlihat hanya di
# build rilis (R8); build debug tidak terkena. Jaga seluruh paket ML Kit.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_latin.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_text_chinese.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_devanagari.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_japanese.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_korean.**
