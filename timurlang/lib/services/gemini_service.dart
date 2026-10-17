// ============================================
// TimurLang - Universal AI Chatbot Service
// Intelligent, multi-domain conversational assistant
// ============================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isFromCloud;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isFromCloud = false,
  });
}

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  final List<ChatMessage> _history = [];
  List<ChatMessage> get history => List.unmodifiable(_history);

  // Gemini API Key (dapat diset via --dart-define=GEMINI_API_KEY=your_key)
  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  Future<void> initialize() async {
    // Bersihkan residu pengaturan API key lama dari penyimpanan lokal jika ada
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_gemini_api_key');
    } catch (_) {}
  }

  /// Tambah pesan sambutan awal tanpa membuat pesan palsu dari user
  void addGreeting() {
    if (_history.isEmpty) {
      _history.add(
        ChatMessage(
          text: '👋 Halo! Saya TimurLang AI Assistant.\n\n'
              'Saya adalah asisten cerdas universal yang siap membantu Anda menjawab berbagai pertanyaan:\n'
              '• 🏔️ Informasi jalur, etika, dan rekomendasi gunung\n'
              '• 🌤️ Prakiraan cuaca & fenomena alam\n'
              '• 🏥 Pertolongan Pertama (P3K) & tips keselamatan\n'
              '• 📱 Panduan fitur aplikasi TimurLang\n'
              '• 💡 Pengetahuan umum, sains, coding, maupun obrolan santai\n\n'
              'Apa yang ingin Anda tanyakan atau diskusikan hari ini?',
          isUser: false,
          timestamp: DateTime.now(),
          isFromCloud: true,
        ),
      );
    }
  }

  /// Send message to Universal Assistant
  Future<String> sendMessage(String message) async {
    // Add user message
    _history.add(ChatMessage(text: message, isUser: true, timestamp: DateTime.now()));

    String response;
    bool isCloud = false;

    // Hubungi Google Gemini API menggunakan kunci terpasang
    try {
      response = await _callGeminiApi(message);
      isCloud = true;
    } catch (e) {
      // Fallback ke Universal Intelligence Engine lokal jika offline / request gagal
      response = _generateUniversalResponse(message);
      isCloud = false;
    }

    _history.add(ChatMessage(
      text: response,
      isUser: false,
      timestamp: DateTime.now(),
      isFromCloud: isCloud,
    ));
    return response;
  }

  /// Call Gemini Flash API with context & alternating turn validation
  Future<String> _callGeminiApi(String message) async {
    if (_geminiApiKey.isEmpty) {
      throw Exception('API Key Gemini belum disetel.');
    }
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$_geminiApiKey',
    );

    // Filter dan pastikan riwayat percakapan strictly alternating (user -> model -> user)
    final List<Map<String, dynamic>> contents = [];
    String? lastRole;

    // Ambil maksimal 8 riwayat sebelum pesan terakhir
    final previousHistory = _history.length > 1
        ? (_history.length > 8 ? _history.sublist(_history.length - 8, _history.length - 1) : _history.sublist(0, _history.length - 1))
        : <ChatMessage>[];

    for (final item in previousHistory) {
      final role = item.isUser ? 'user' : 'model';
      final text = item.text.trim();
      if (text.isEmpty) continue;

      if (contents.isEmpty) {
        if (role == 'user') {
          contents.add({
            'role': 'user',
            'parts': [{'text': text}]
          });
          lastRole = 'user';
        }
      } else if (role == lastRole) {
        final parts = contents.last['parts'] as List;
        final currentText = parts[0]['text'] as String;
        parts[0]['text'] = '$currentText\n$text';
      } else {
        contents.add({
          'role': role,
          'parts': [{'text': text}]
        });
        lastRole = role;
      }
    }

    // Turn terakhir harus dari 'user' dengan pesan terbaru saat ini
    contents.add({
      'role': 'user',
      'parts': [{'text': message.trim()}]
    });

    final body = json.encode({
      'system_instruction': {
        'parts': [
          {
            'text': 'Kamu adalah TimurLang AI Assistant, asisten cerdas universal berbahasa Indonesia. '
                'Kamu dapat menjawab segala macam topik secara akurat, lugas, dan membantu: '
                'pengetahuan umum, sains, teknologi, matematika, rekomendasi gunung & wisata, '
                'tips produktivitas, percakapan santai, maupun panduan fitur aplikasi TimurLang dan keselamatan pendakian. '
                'Gunakan gaya bahasa yang ramah, natural, informatif, dan terstruktur dengan rapi. '
                'PENTING: Susun teks dengan bersih dan rapi. Hindari pemakaian tanda bintang ganda (**) yang berlebihan pada kata-kata biasa.'
          }
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      }
    });

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final jsonRes = json.decode(res.body);
      final text = jsonRes['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null && text.toString().trim().isNotEmpty) {
        return text.toString().trim();
      }
    }

    throw Exception('Gemini API returned status ${res.statusCode}: ${res.body}');
  }

  /// Universal Intelligence Engine (Multi-domain conversation)
  String _generateUniversalResponse(String input) {
    final text = input.toLowerCase().trim();

    // 1. Greeting & Casual Chat
    if (text == 'halo' || text == 'hai' || text.startsWith('halo ') || text.startsWith('hai ') || text == 'p' || text == 'hi') {
      return '''👋 **Halo! Saya TimurLang AI Assistant.**

Saya adalah asisten cerdas universal yang siap membantu Anda menjawab berbagai hal:
- 🏔️ **Gunung & Petualangan:** Rekomendasi jalur, estimasi waktu, tips packing, etika pendakian.
- 🌤️ **Cuaca & Alam:** Penjelasan kondisi cuaca, fenomena awan, navigasi arah.
- 📱 **Fitur TimurLang:** Panduan Simaksi, peta offline, pemantau jatuh/SOS, rekam medis.
- 💡 **Pengetahuan Umum:** Sains, teknologi, tips kesehatan, produktivitas, maupun obrolan santai.
- 🏥 **P3K & Keselamatan:** Penanganan cedera atau darurat di alam bebas.

Ada yang bisa saya bantu atau ingin Anda diskusikan hari ini? 😊''';
    }

    if (text.contains('siapa kamu') || text.contains('kamu siapa') || text.contains('tentang kamu') || text.contains('bot apa')) {
      return '''🤖 **Tentang TimurLang AI:**

Saya adalah asisten virtual serba bisa yang terintegrasi di dalam aplikasi **TimurLang**. 

Selain memandu Anda mengenai aktivitas luar ruang dan sistem perizinan simaksi gunung, saya dirancang untuk menjawab pertanyaan umum, membantu mencari solusi sehari-hari, hingga menjadi teman diskusi yang interaktif! ✨''';
    }

    if (text.contains('apa kabar') || text.contains('gimana kabarmu') || text.contains('sehat')) {
      return '''Alhamdulillah, saya selalu aktif dan siap membantu Anda 24/7! ⚡ 

Bagaimana dengan kabar Anda hari ini? Sedang merencanakan perjalanan seru, belajar, atau ada hal menarik yang ingin ditanyakan?''';
    }

    if (text.contains('terima kasih') || text.contains('makasih') || text.contains('thanks') || text.contains('thx')) {
      return '''Sama-sama! Senang sekali bisa membantu Anda. 🙌

Jika ada pertanyaan lain seputar alam, teknologi, atau topik apa pun, silakan tanyakan saja ya! Semoga hari Anda menyenangkan! ✨''';
    }

    if (text.contains('lucu') || text.contains('lelucon') || text.contains('jokes') || text.contains('tebak')) {
      final jokes = [
        '😄 **Tebak-tebakan santai:**\n\n*Kenapa gunung nggak pernah kesepian?*\nJawabannya: *Karena selalu ada puncaknya yang bikin heboh, dan lerengnya selalu punya temen lereng sebelah!* 😂',
        '🧗 **Humor Pendaki:**\n\n*Apa bedanya pacaran sama mendaki gunung?*\n*Kalau mendaki gunung butuh carrier yang kuat, kalau pacaran butuh komitmen yang nggak gampang drop!* 🎒',
        '💡 **Tebak-tebakan:**\n\n*Awan apa yang paling pintar?*\nJawabannya: *Awan-cerai (wawancara) beasiswa!* ☁️🎓',
      ];
      return jokes[DateTime.now().second % jokes.length];
    }

    // 2. Rekomendasi Gunung & Destinasi Wisata
    if (text.contains('rekomendasi gunung') || text.contains('gunung pemula') || text.contains('gunung cocok untuk pemula') || text.contains('gunung santai')) {
      return '''🏔️ **Rekomendasi Gunung Cocok untuk Pemula di Jawa:**

1. **Gunung Prau (2.565 mdpl - Dieng, Jateng)**
   - Waktu tempuh: 2,5 - 4 jam
   - Daya tarik: Golden Sunrise terbaik dan Bukit Teletubbies. Jalur relatif landai dan jelas via Patakbanteng atau Kalilembu.

2. **Gunung Andong (1.726 mdpl - Magelang, Jateng)**
   - Waktu tempuh: 1,5 - 2,5 jam
   - Daya tarik: Sangat ramah pemula, pemandangan 360° melihat Merbabu, Merapi, Sindoro, dan Sumbing.

3. **Gunung Papandayan (2.665 mdpl - Garut, Jabar)**
   - Waktu tempuh: 3 - 4 jam
   - Daya tarik: Hutan Mati ikonik, kawah belerang eksotis, dan padang edelweis Tegal Alun.

4. **Gunung Ijen (2.386 mdpl - Banyuwangi, Jatim)**
   - Waktu tempuh: 2 - 3 jam
   - Daya tarik: Fenomena Blue Fire langka dunia dan danau kawah asam berwarna toska.

💡 *Tips:* Pastikan selalu booking Simaksi resmi melalui aplikasi TimurLang sebelum mendaki ya!''';
    }

    if (text.contains('semeru') || text.contains('mahameru')) {
      return '''🌋 **Informasi Gunung Semeru (3.676 mdpl):**

- **Status:** Puncak tertinggi di Pulau Jawa (Atap Pulau Jawa).
- **Ikon Utama:** Ranu Kumbolo, Tanjakan Cinta, Oro-Oro Ombo (hamparan bunga verbena), dan Kalimati.
- **Tingkat Kesulitan:** Grade 4 (Sulit - Sangat Butuh Fisik Prima).
- **Catatan Keselamatan:** Jalur puncak sering dibatasi sesuai rekomendasi PVMBG karena aktivitas vulkanik kawah Jonggring Saloko.
- **Suhu Malam:** Bisa mencapai 0°C hingga minus (fenomena embun es / upas di Ranu Kumbolo).''';
    }

    if (text.contains('rinjani')) {
      return '''🏝️ **Informasi Gunung Rinjani (3.726 mdpl - Lombok, NTB):**

- **Daya Tarik:** Danau Segara Anak, Gunung Barujari (anak gunung berapi), dan pemandangan sunrise megah dengan latar Gunung Agung Bali.
- **Jalur Populer:** Sembalun (padang savana menanjak) dan Senaru (hutan tropis teduh).
- **Durasi Normal:** 3 hari 2 malam atau 4 hari 3 malam.
- **Tips:** Siapkan perlengkapan tahan angin kencang di Plawangan Sembalun dan summit attack berpasir terjal.''';
    }

    if (text.contains('merbabu')) {
      return '''🌾 **Informasi Gunung Merbabu (3.145 mdpl - Jawa Tengah):**

- **Jalur Populer:** Selo (Boyolali), Suwanting (Magelang), Thekelan, Wekas.
- **Pemandangan:** Padang sabana bertingkat yang sangat luas dengan latar belakang megah Gunung Merapi di seberangnya.
- **Karakter Jalur:** Jalur Selo relatif terbuka dan berdebu saat kemarau, sedangkan jalur Suwanting memiliki tanjakan fisik yang cukup menantang.''';
    }

    // 3. Tips Perlengkapan & Packing (Ultralight / Standar)
    if (text.contains('packing') || text.contains('perlengkapan') || text.contains('bawa apa') || text.contains('alat pendakian')) {
      return '''🎒 **Daftar Perlengkapan Wajib Pendakian (Checklist):**

**1. Shelter & Tidur:**
- Tenda double-layer sesuai kapasitas
- Sleeping bag (sesuaikan comfort rating dengan suhu gunung)
- Matras aluminium / tiup
- Flysheet tambahan

**2. Pakaian (Prinsip Layering):**
- Base layer (baju sintetis/quick-dry, HINDARI bahan katun tebal)
- Mid layer (fleece / jaket insulasi)
- Outer layer (jaket waterproof & windbreaker)
- Jas hujan (ponco / rain suit)
- Sarung tangan, buff, dan kupluk hangat

**3. Navigasi & Penerangan:**
- Headlamp + baterai cadangan
- Aplikasi TimurLang (peta offline & kompas aktif)

**4. Logistik & Masak:**
- Kompor lapangan + gas canister
- Nesting/panci masak & sendok/garpu
- Air minum (minimal 2-3 liter per orang) + makanan padat kalori (madu, cokelat, oat)

**5. Medis & Keselamatan:**
- Kotak P3K standar & obat pribadi
- Peluit darurat''';
    }

    if (text.contains('etika') || text.contains('leave no trace') || text.contains('aturan mendaki')) {
      return '''🌿 **Prinsip Dasar "Leave No Trace" (Etika Pendaki):**

1. **Rencanakan dan persiapkan matang-matang:** Cek kuota, simaksi, dan ramalan cuaca.
2. **Berjalan dan berkemah di jalur yang sudah ada:** Jangan membuka jalur liar baru.
3. **Bawa pulang sampah Anda:** *"Take nothing but pictures, leave nothing but footprints, kill nothing but time."*
4. **Tinggalkan apa yang Anda temukan:** Jangan memetik bunga edelweis atau merusak batuan.
5. **Kurangi dampak api unggun:** Hindari membuat api unggun di area rawan kebakaran hutan.
6. **Hormati satwa liar:** Jangan memberi makan hewan liar di gunung.
7. **Hargai pendaki lain:** Jangan menyetel musik kencang menggunakan speaker di area perkemahan.''';
    }

    // 4. Sains, Cuaca, & Fenomena Alam
    if (text.contains('cuaca') || text.contains('awan') || text.contains('hujan') || text.contains('petir')) {
      return '''🌤️ **Memahami Fenomena Cuaca di Alam Bebas:**

- **Awan Kumulonimbus (Cb):** Awan hitam pekat menjulang tinggi seperti menara/jamur. Pertanda badai petir, hujan lebat mendadak, dan angin kencang. Jika melihat awan ini mendekat, **segera turun dari puncak atau punggungan terbuka!**
- **Awan Lentikularis (Topi Awan):** Awan berbentuk piring melayang di atas puncak gunung. Sangat indah, tapi mengindikasikan adanya angin badai berkecepatan ekstrem (*turbulence*) di ketinggian puncak.
- **Ketinggian vs Suhu (*Lapse Rate*):** Setiap kenaikan elevasi 100 meter, suhu udara alami akan turun sekitar 0.6°C - 0.65°C.

💡 *Tips:* Gunakan menu **Informasi Cuaca** di aplikasi TimurLang untuk memantau data satelit live lokasi Anda!''';
    }

    if (text.contains('bumi') || text.contains('gravitasi') || text.contains('sains') || text.contains('matahari')) {
      return '''🔬 **Fakta Sains Menarik:**

- **Tekanan Udara di Ketinggian:** Semakin tinggi Anda mendaki, molekul oksigen di udara semakin renggang. Pada ketinggian 3.000 mdpl, tekanan udara berkurang sekitar 30% dibanding permukaan laut, itulah sebabnya napas terasa lebih cepat terengah-engah.
- **Titik Didih Air:** Di permukaan laut air mendidih pada 100°C, tetapi di puncak gunung (misal 3.000 mdpl) air bisa mendidih pada suhu ~90°C karena tekanan atmosfer yang lebih rendah. Akibatnya, memasak makanan butuh waktu sedikit lebih lama!''';
    }

    // 5. Teknologi & Coding / Aplikasi TimurLang
    if (text.contains('timurlang') || text.contains('aplikasi ini') || text.contains('cara pakai') || text.contains('fitur')) {
      return '''📱 **Panduan Fitur Aplikasi TimurLang:**

1. **Informasi Cuaca:** Terintegrasi API satelit real-time berdasarkan GPS presisi Anda beserta prakiraan 5 hari ke depan.
2. **Siaga SOS & Deteksi Jatuh:** Sensor akselerometer mendeteksi guncangan hebat secara otomatis dan meluncurkan suar darurat SAR bahkan saat aplikasi berada di luar layar.
3. **Peta Offline & Jalur:** Navigasi jalur pendakian tanpa memerlukan koneksi internet aktif.
4. **Kompas 3D Digital:** Penunjuk arah mata angin kardinal dengan kalibrasi sensor gyroscope.
5. **Booking Simaksi Terpadu:** Pengajuan izin pendakian resmi dengan validasi kuota harian pos basecamp.
6. **Rekam Medis Darurat:** Informasi golongan darah dan kontak keluarga darurat yang siap diakses penyelamat saat genting.''';
    }

    if (text.contains('simaksi') || text.contains('booking') || text.contains('izin')) {
      return '''📋 **Cara Pengajuan Simaksi di TimurLang:**

1. Buka menu **Gunung** di beranda atau pilih gunung tujuan Anda.
2. Pastikan kuota harian masih tersedia dan jalur berstatus **"Buka"**.
3. Ketuk tombol **"Booking Simaksi"**.
4. Lengkapi formulir tanggal naik, tanggal turun, pos basecamp, serta jumlah anggota rombongan.
5. Lanjutkan ke verifikasi dan selesaikan pembayaran untuk mendapatkan e-Tiket resmi dengan kode hash validasi!''';
    }

    if (text.contains('coding') || text.contains('flutter') || text.contains('dart') || text.contains('teknologi')) {
      return '''💻 **Seputar Teknologi Aplikasi TimurLang:**

Aplikasi ini dibangun menggunakan **Flutter & Dart** dengan arsitektur modern:
- **State Management & Service Singleton:** Mengatur sinkronisasi data antar modul secara efisien.
- **Hardware Integration:** Mengakses sensor akselerometer (`sensors_plus`), giroskop, GPS satelit (`geolocator`), serta native Kotlin channel (`MethodChannel`) untuk bring-to-front saat darurat.
- **Dual Database:** SQLite lokal untuk kemampuan penuh luring (*offline-first*) dan Supabase Cloud untuk sinkronisasi daring.''';
    }

    // 6. Kesehatan, Produktivitas, & Kebugaran
    if (text.contains('latihan fisik') || text.contains('olahraga') || text.contains('persiapan fisik') || text.contains('jogging')) {
      return '''🏃‍♂️ **Panduan Latihan Fisik Sebelum Pendakian:**

Lakukan latihan rutin 2-3 minggu sebelum mendaki:
1. **Latihan Kardio (3-4x seminggu):**
   - Jogging santai 30-45 menit untuk membangun kapasitas paru-paru (*VO2 Max*).
   - Naik-turun tangga gedung/jembatan penyeberangan (sangat efektif melatih otot paha dan betis).
2. **Latihan Kekuatan (*Strength Training*):**
   - Squats, lunges, dan calf raises untuk memperkuat lutut dan tungkai.
   - Plank dan core workout untuk kestabilan punggung saat menggendong tas carrier berat.
3. **Simulasi Carrier:**
   - Berjalan kaki sambil membawa tas ransel berisi beban 5-8 kg untuk membiasakan postur tubuh.''';
    }

    if (text.contains('ams') || text.contains('mountain sickness') || text.contains('penyakit ketinggian')) {
      return '''⛰️ **Memahami Acute Mountain Sickness (AMS):**

AMS terjadi akibat tubuh belum sempat beraklimatisasi dengan penurunan kadar oksigen di ketinggian (>2.400 mdpl).

- **Gejala Umum:** Pusing/sakit kepala berdenyut, mual, kehilangan nafsu makan, lemas tidak wajar, sulit tidur.
- **Pencegahan:**
  1. Naik perlahan (*Climb high, sleep low*).
  2. Perbanyak minum air putih (hindari dehidrasi).
  3. Jangan memaksakan diri berlari di jalur terjal.
- **Penanganan:**
  - Istirahat dan jangan lanjutkan naik.
  - Jika gejala memburuk atau sesak napas → **SEGERA TURUN KE ELEVASI LEBIH RENDAH!**''';
    }

    // 7. P3K & Keselamatan (Tetap didukung jika dibutuhkan)
    if (text.contains('luka') || text.contains('berdarah')) {
      return '''🏥 **Penanganan Luka Terbuka:**
1. Hentikan pendarahan dengan menekan luka menggunakan kain bersih selama 10-15 menit.
2. Bilas luka dengan air bersih mengalir.
3. Oleskan antiseptik (povidone iodine) dan balut dengan perban steril.''';
    }

    if (text.contains('patah') || text.contains('fraktur')) {
      return '''🦴 **Penanganan Dugaan Patah Tulang:**
1. Jangan gerakkan area yang cedera.
2. Buat bidai penyangga darurat dari ranting/trekking pole.
3. Kompres dingin untuk mengurangi pembengkakan dan jangan mencoba meluruskan tulang sendiri.''';
    }

    if (text.contains('hipotermia') || text.contains('kedinginan')) {
      return '''🥶 **Penanganan Hipotermia:**
1. Pindahkan korban ke tempat terlindung dari terpaan angin kencang.
2. Ganti seluruh pakaian basah dengan pakaian kering.
3. Masukkan ke dalam sleeping bag berlapis dan berikan minuman manis hangat bertahap.''';
    }

    if (text.contains('ular') || text.contains('gigitan ular')) {
      return '''🐍 **Penanganan Gigitan Ular:**
1. Tenangkan korban dan minimalkan gerakan tubuh agar racun tidak cepat menyebar.
2. Posisikan area gigitan lebih rendah dari posisi jantung.
3. JANGAN mengiris, menghisap luka, atau mengompres es batu.
4. Segera evakuasi ke fasilitas medis terdekat.''';
    }

    // 8. General Open-Ended Conversational Fallback (Offline Mode)
    return 'Maaf, saya saat ini berjalan dalam mode luring (offline engine) atau koneksi ke Google Gemini Cloud terputus.\n\n'
        'Dalam mode luring, saya dapat menjawab topik seperti:\n'
        '• Rekomendasi gunung pemula & jalur (Prau, Andong, Semeru, Rinjani, Merbabu)\n'
        '• Tips packing & perlengkapan outdoor\n'
        '• Pemahaman cuaca & fenomena alam\n'
        '• Panduan P3K & pertolongan cedera darurat\n'
        '• Panduan fitur TimurLang & Simaksi\n\n'
        '💡 Untuk jawaban cerdas universal dari Google Gemini AI, pastikan ponsel Anda terhubung ke internet. Anda juga dapat mengecek status API Key melalui ikon pengaturan di kanan atas.';
  }

  /// Clear chat history
  void clearHistory() {
    _history.clear();
  }
}
