<div align="center">

  # 🏔️ TimurLang
  ### *Sistem Informasi Perizinan (SIMAKSI) & Keselamatan Pendakian Terpadu*
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.47.2-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.13.2-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)
  [![Database](https://img.shields.io/badge/Database-SQLite%20%7C%20Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
  [![Blockchain](https://img.shields.io/badge/Blockchain-Polygon%20Amoy-8247E5?style=for-the-badge&logo=polygon&logoColor=white)](https://polygon.technology)
  [![AI Engine](https://img.shields.io/badge/AI-Google%20Gemini-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)
  [![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

  <p align="center">
    <b>Aplikasi mobile cerdas berbasis <i>Offline-First</i>, <i>Web3 Blockchain</i>, dan <i>Generative AI</i> untuk mendigitalkan birokrasi perizinan pendakian gunung di Indonesia serta memitigasi risiko kecelakaan di alam bebas.</b>
  </p>

  [Fitur Utama](#-fitur-utama) •
  [Arsitektur Sistem](#-arsitektur-sistem) •
  [Tech Stack](#-teknologi--dependensi) •
  [Struktur Folder](#-struktur-proyek) •
  [Panduan Instalasi](#-panduan-instalasi--menjalankan) •
  [Hasil Pengujian](#-hasil-pengujian-sistem)

</div>

---

## 📖 Tentang TimurLang

Mendaki gunung merupakan kegiatan luar ruangan yang memiliki risiko tinggi. Tiga permasalahan utama yang sering dihadapi adalah:
1. **Birokrasi Perizinan Manual:** Antrean formulir kertas dan peredaran tiket SIMAKSI palsu di pos gerbang masuk.
2. **Keterbatasan Sinyal Seluler (*Blank Spot*):** Wilayah pegunungan minim sinyal internet sehingga aplikasi umum berbasis *cloud-only* tidak dapat berfungsi.
3. **Keterlambatan Respon Darurat:** Insiden jatuh (*fall incident*), hipotermia, atau tersesat yang tidak terdeteksi oleh pos basecamp.

**TimurLang** hadir sebagai solusi terpadu untuk menghubungkan **Pendaki (*Hiker*)** dan **Petugas Pos (*Ranger*)** melalui platform mobile yang tetap dapat diandalkan baik dalam kondisi *online* maupun luring total (*offline-first*).

---

## ✨ Fitur Utama

### 🎟️ 1. Digital SIMAKSI & Pembayaran Non-Tunai
* **Reservasi Online:** Pemesanan izin mendaki dengan manajemen kuota harian otomatis per jalur basecamp.
* **Payment Gateway Terintegrasi:** Pembayaran instan via **Midtrans Snap** (QRIS, Virtual Account Bank, dan e-Wallet).
* **E-Tiket Dinamis:** Penerbitan tiket elektronik berformat QR Code yang memuat identitas dan manifes anggota rombongan.

### 🔗 2. Verifikasi Tiket Web3 Blockchain (Polygon Amoy)
* **Pencatatan Permanen (*Immutable Ledger*):** Setiap tiket yang terbayar dienkapsulasi dan disiarkan ke jaringan *Polygon Amoy Testnet* (Chain ID: `80002`).
* **Anti-Pemalsuan:** Petugas dan pendaki dapat memverifikasi keabsahan tiket secara publik melalui tautan *Transaction Hash* (TxHash) pada *Polygonscan*.

### 🚨 3. Pemantauan Keselamatan & Deteksi Jatuh Cerdas (*Fall Detection*)
* **Algoritma Akselerometer Otomatis:** Memantau vektor akselerasi ($G = \sqrt{x^2 + y^2 + z^2}$). Ketika terdeteksi kondisi jatuh bebas yang disusul benturan keras, sistem otomatis memicu dialog darurat layar penuh.
* **Hitung Mundur 30 Detik:** Memberi jeda waktu kepada pendaki untuk membatalkan pemicuan palsu (*false alarm*).
* **Sirene & Morse SOS:** Membunyikan alarm audio bervolume tinggi, getaran haptik ritmis, dan suar senter kamera berkedip sinyal kode Morse SOS ($\cdot\cdot\cdot ---\ \cdot\cdot\cdot$).

### 🧭 4. Navigasi Peta Luring (*Offline-First GPS & Compass*)
* **Peta Jalur Ter-cache:** Memanfaatkan `flutter_map` untuk merender ubin peta (*raster tiles*) dan jalur kontur pos pendakian tanpa memerlukan koneksi internet.
* **Kompas Digital Real-Time:** Integrasi sensor magnetometer untuk memandu orientasi arah mata angin di tengah kabut atau hutan lebat.

### 🤖 5. "Tanya Tbot" — Asisten Survival Bertenaga AI
* **Google Gemini AI 1.5 Flash:** Asisten cerdas yang diprogram dengan pengetahuan taktis pertolongan pertama (penanganan hipotermia, pembuatan bivak darurat, filter air, dan navigasi bintang).
* **Desain Interaktif:** Tombol FAB mengambang bergaya *comic speech bubble* dengan animasi *floating bobbing* yang dinamis dan menarik.

### 🛂 6. Dasbor Khusus Petugas Basecamp (*Ranger Mode*)
* **Pemindai QR Cepat:** Validasi tiket pendaki dalam waktu < 2 detik untuk proses *Check-In* ("Di Jalur") dan *Check-Out* ("Selesai").
* **Hiker Live Monitor:** Memantau jumlah dan daftar rombongan pendaki yang sedang aktif berada di atas gunung secara *real-time*.
* **Sinkronisasi Luring-ke-Daring (*Auto-Sync*):** Transaksi verifikasi yang dicatat saat pos mati listrik/kehilangan sinyal tersimpan aman di SQLite lokal dan otomatis disinkronkan ke cloud Supabase ketika internet pulih.

### 🩸 7. Rekam Medis & Autentikasi Biometrik
* **Profil Kesehatan Darurat:** Menyimpan golongan darah, alergi, penyakit bawaan, serta nomor kontak darurat keluarga (*In Case of Emergency* / ICE).
* **Fingerprint Security:** Pengamanan akses tiket dan data pribadi menggunakan sensor sidik jari (*biometric local auth*).

---

## 🏗️ Arsitektur Sistem

TimurLang mengadopsi arsitektur berlapis (*layered architecture*) yang memprioritaskan ketahanan luring (*offline resilience*):

```
┌────────────────────────────────────────────────────────┐
│             PRESENTATION LAYER (Flutter UI)            │
│  • Dashboard  • Peta Offline  • AI Chat  • QR Scanner  │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│              CORE APPLICATION & SERVICE LAYER          │
│  • AuthService   • TrailService     • GeminiService    │
│  • SyncService   • DatabaseService  • BlockchainService│
└─────────────┬───────────────────────────────┬──────────┘
              │                               │
┌─────────────▼───────────────┐ ┌─────────────▼──────────┐
│   LOCAL PERSISTENCE (Offline)│ │  CLOUD & PERIPHERAL    │
│   • SQLite (sqflite)        │ │  • Supabase (PostgreSQL│
│   • SharedPreferences       │ │  • Polygon Amoy Web3   │
│   • Hardware Sensors        │ │  • Midtrans Gateway    │
│     (GPS, Kompas, Akselerometer, Flash, Biometrik) │  • OpenWeatherMap API   │
└─────────────────────────────┘ └────────────────────────┘
```

---

## 🛠️ Teknologi & Dependensi

| Kategori | Teknologi / Pustaka | Kegunaan |
|:---|:---|:---|
| **Framework** | [Flutter](https://flutter.dev) (v3.47.2) & [Dart](https://dart.dev) (v3.13.2) | Pengembangan antarmuka mobile cross-platform |
| **Local DB** | [`sqflite`](https://pub.dev/packages/sqflite) & `path_provider` | Database relasional lokal untuk arsitektur *offline-first* |
| **Cloud Backend** | [`supabase_flutter`](https://pub.dev/packages/supabase_flutter) | Backend-as-a-Service (PostgreSQL, Auth, & Storage) |
| **Blockchain** | [`web3dart`](https://pub.dev/packages/web3dart) | Komunikasi RPC dengan *smart contract/ledger* Polygon Amoy |
| **Kecerdasan Buatan** | [Google Generative AI](https://ai.google.dev) (Gemini 1.5 Flash) | Natural language processing untuk asisten survival "Tbot" |
| **Sensors & Hardware** | `sensors_plus`, `geolocator`, `flutter_compass`, `local_auth` | Pembacaan akselerometer, koordinat GPS, kompas, dan sidik jari |
| **Kamera & QR** | `mobile_scanner` & `qr_flutter` | Pemindaian dan pembuatan kode QR tiket perizinan |
| **Audio & Notifikasi**| `audioplayers`, `flutter_local_notifications` | Pemicu sirene darurat dan heads-up notification prioritas tinggi |
| **Pemetaan** | `flutter_map` & `latlong2` | Visualisasi jalur pendakian berbasis OpenStreetMap luring |
| **Payment Gateway** | `webview_flutter` & Midtrans Snap API | Penyedia antarmuka pembayaran digital (QRIS, VA Bank, e-Wallet) |

---

## 📁 Struktur Proyek

```
timurlang/
├── android/               # Konfigurasi native Android & permission manifest
├── assets/
│   ├── images/            # Ilustrasi UI dan katalog foto gunung Indonesia
│   └── sounds/            # File audio sirene darurat SOS
├── lib/
│   ├── app.dart           # Inisialisasi rute dan konfigurasi tema global (AppTheme)
│   ├── main.dart          # Entry point aplikasi & inisialisasi background services
│   ├── config/            # Konstanta API keys, RPC endpoints, & style tokens
│   ├── data/              # Dataset awal rute gunung & basecamp di Indonesia
│   ├── models/            # Data models (Hiker, SIMAKSI Permit, Medical Profile, dll.)
│   ├── screens/           # Tampilan antarmuka pengguna
│   │   ├── ai/            # Antarmuka obrolan asisten AI "Tanya Tbot"
│   │   ├── auth/          # Layanan autentikasi akun & sidik jari
│   │   ├── basecamp/      # Dasbor petugas pos, Hiker Monitor & QR Scanner
│   │   ├── compass/       # Layar navigasi kompas digital
│   │   ├── home/          # Beranda utama & FAB balon komik animasi
│   │   ├── map/           # Peta interaktif jalur & rute pos luring
│   │   ├── mountain/      # Katalog gunung & prakiraan cuaca
│   │   ├── profile/       # Pengaturan profil & formulir rekam medis
│   │   ├── safety/        # Layar darurat deteksi jatuh & suar Morse SOS
│   │   └── simaksi/       # Formulir reservasi tiket & pembayaran Midtrans
│   ├── services/          # Business logic (Database, Blockchain, Sync, AI, Weather)
│   ├── utils/             # Helper fungsi (Date formatting, Image cache, Hashing)
│   └── widgets/           # Komponen widget yang dapat digunakan kembali
└── test/                  # Automated unit test & widget testing
```

---

## 🚀 Panduan Instalasi & Menjalankan

### 1. Prasyarat Sistem
* [Flutter SDK](https://docs.flutter.dev/get-started/install) ($\ge$ versi 3.47.x)
* [Android Studio](https://developer.android.com/studio) dengan Android SDK Command-line Tools
* Perangkat fisik Android dengan fitur sensor gerak, GPS, dan kamera (atau Emulator Android)

### 2. Kloning Repositori
```bash
git clone https://github.com/tasyakurmaulana/TimurLang.git
cd TimurLang/timurlang
```

### 3. Instalasi Dependensi
```bash
flutter pub get
```

### 4. Konfigurasi Lingkungan (*Environment Variables*)
Buat atau periksa konfigurasi kredensial pada berkas layanan terkait (`lib/config/` atau `lib/services/`):
* **Supabase URL & Anon Key** (`supabase_service.dart`)
* **Google Gemini API Key** (`gemini_service.dart`)
* **Midtrans Client Key** (`simaksi_payment_screen.dart`)
* **Polygon Amoy RPC URL** (`blockchain_service.dart`)

### 5. Menjalankan Aplikasi
Hubungkan perangkat Android Anda via kabel USB (aktifkan *USB Debugging*), lalu jalankan perintah:
```bash
flutter run
```

---

## 🧪 Hasil Pengujian Sistem

Aplikasi TimurLang telah melalui serangkaian pengujian komprehensif:

* **Black Box Testing:** 100% kasus uji fungsional utama (Autentikasi, SIMAKSI, QR Scanner, Fall Alert, dan Offline Sync) berstatus **PASS**.
* **Integrasi Sensor:** Akurasi deteksi jatuh (*Fall Detection*) mencapai $\ge 90\%$ tanpa memicu *false positive* pada aktivitas jalan santai.
* **User Acceptance Testing (UAT):** Diuji oleh 10 responden (7 pendaki dan 3 pengelola basecamp) dengan total 68 pengujian:
  $$\text{Persentase Kelayakan UAT} = \frac{67 \text{ Sesuai}}{68 \text{ Kasus Uji}} \times 100\% = \mathbf{98.53\%}$$
  Berdasarkan skala kelayakan Sugiyono/Arikunto, aplikasi memperoleh predikat **"Sangat Layak / Sangat Baik"** dan secara resmi dinyatakan **Diterima (*Accepted*)**.

---

## 👨‍💻 Pengembang

* **Tasyakur Maulana**  
  *Proyek Akhir Mata Kuliah Pemrograman Aplikasi Mobile (PAM) — Semester 5*  
  GitHub: [@tasyakurmaulana](https://github.com/tasyakurmaulana)

---

<div align="center">
  <p>Dibuat dengan ❤️ untuk komunitas pendaki dan kelestarian alam pegunungan Indonesia.</p>
  <i>"Take nothing but pictures, leave nothing but footprints, kill nothing but time."</i>
</div>
