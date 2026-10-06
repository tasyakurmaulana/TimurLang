// ============================================
// TimurLang - Gemini AI Service (Mock)
// Survival Assistant chatbot
// ============================================

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  final List<ChatMessage> _history = [];
  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Send message to Survival Assistant (mock Gemini)
  Future<String> sendMessage(String message) async {
    // Add user message
    _history.add(ChatMessage(text: message, isUser: true, timestamp: DateTime.now()));

    // Simulate thinking
    await Future.delayed(const Duration(milliseconds: 800));

    final response = _generateResponse(message.toLowerCase());
    _history.add(ChatMessage(text: response, isUser: false, timestamp: DateTime.now()));

    return response;
  }

  String _generateResponse(String input) {
    // P3K / First Aid responses
    if (input.contains('luka') || input.contains('berdarah') || input.contains('terluka')) {
      return '''🏥 **Penanganan Luka Terbuka:**

1. **Hentikan pendarahan** - Tekan luka dengan kain bersih selama 10-15 menit
2. **Bersihkan luka** - Bilas dengan air bersih mengalir
3. **Oleskan antiseptik** - Gunakan betadine/povidone iodine jika tersedia
4. **Tutup luka** - Balut dengan perban steril
5. **Pantau infeksi** - Perhatikan kemerahan, bengkak, atau nanah

⚠️ Segera evakuasi jika pendarahan tidak berhenti dalam 20 menit atau luka sangat dalam.''';
    }

    if (input.contains('patah') || input.contains('fraktur') || input.contains('tulang')) {
      return '''🦴 **Penanganan Dugaan Patah Tulang:**

1. **Jangan gerakkan** area yang cedera
2. **Imobilisasi** - Buat bidai dari ranting/tongkat trekking
3. **Kompres dingin** - Gunakan air dingin/es jika ada
4. **Tinggikan** area cedera jika memungkinkan
5. **Minum pereda nyeri** - Parasetamol jika tersedia

🚨 **JANGAN** mencoba meluruskan tulang yang patah! Segera hubungi tim SAR/evakuasi.''';
    }

    if (input.contains('hipotermia') || input.contains('kedinginan') || input.contains('menggigil')) {
      return '''🥶 **Penanganan Hipotermia:**

1. **Pindahkan** ke tempat terlindung dari angin
2. **Ganti pakaian basah** dengan yang kering
3. **Selimuti** dengan sleeping bag/selimut berlapis
4. **Hangatkan bertahap** - minuman hangat manis (BUKAN alkohol!)
5. **Hindari mengosok** kulit secara kasar
6. **Dekatkan** sumber panas (hand warmer, botol air hangat)

⚠️ Tanda bahaya: kebingungan, bicara tidak jelas, kantuk berlebih → EVAKUASI SEGERA!''';
    }

    if (input.contains('tersesat') || input.contains('hilang') || input.contains('arah')) {
      return '''🧭 **Panduan Saat Tersesat:**

1. **STOP** - Sit, Think, Observe, Plan
2. **Jangan panik** - Tetap tenang dan hemat energi
3. **Tandai lokasi** - Buat tanda yang mencolok
4. **Gunakan kompas** TimurLang untuk orientasi arah
5. **Cari sumber air** - Ikuti aliran air ke hilir (biasanya menuju pemukiman)
6. **Buat sinyal** - 3 peluit berurutan = tanda darurat internasional
7. **Berteduh** jika menjelang gelap, JANGAN bergerak di malam hari

📍 Aktifkan SOS di aplikasi untuk mengirim koordinat terakhir Anda!''';
    }

    if (input.contains('ular') || input.contains('gigit')) {
      return '''🐍 **Penanganan Gigitan Ular:**

1. **Tenang** - Jangan panik, gerak minimal
2. **Imobilisasi** area gigitan di bawah jantung
3. **Lepas perhiasan** sebelum bengkak
4. **Balut tekanan** - perban elastis TIDAK terlalu kencang
5. **JANGAN** hisap, iris, atau kompres es
6. **Catat waktu** dan ciri ular jika terlihat
7. **Evakuasi SEGERA** ke fasilitas medis

⏰ Golden period: 2-4 jam untuk anti bisa ular.''';
    }

    if (input.contains('waktu') || input.contains('estimasi') || input.contains('tempuh')) {
      return '''⏱️ **Estimasi Waktu Tempuh Pendakian:**

📐 Rumus Naismith (standar pendakian):
- **Datar**: ~5 km/jam
- **Menanjak**: +1 jam per 600m elevasi
- **Menurun**: +1 jam per 800m elevasi

📊 Contoh kalkulasi:
- Jarak 8 km, elevasi naik 1200m
- Waktu datar: 8/5 = 1.6 jam
- Waktu pendakian: 1200/600 = 2 jam
- **Total estimasi: ~3.6 jam (3 jam 36 menit)**

💡 Tambahkan 20-30% untuk faktor kelelahan, cuaca, dan medan sulit.''';
    }

    if (input.contains('dehidrasi') || input.contains('haus') || input.contains('air')) {
      return '''💧 **Penanganan & Pencegahan Dehidrasi:**

1. **Minum rutin** - 250ml setiap 20-30 menit
2. **Tambahkan elektrolit** - oralit/garam+gula ke air
3. **Hindari kafein** dan alkohol
4. **Tanda dehidrasi ringan**: haus, mulut kering, urine kuning pekat
5. **Tanda bahaya**: pusing, mual, detak jantung cepat → istirahat total!

📏 Kebutuhan air pendakian: 1 liter per 2 jam aktivitas
🏔️ Di ketinggian >3000m, kebutuhan air meningkat 50%!''';
    }

    if (input.contains('halo') || input.contains('hai') || input.contains('help') || input.contains('bantuan')) {
      return '''🏔️ **Halo! Saya Survival Assistant TimurLang.**

Saya dapat membantu Anda dengan:
- 🏥 **P3K Darurat**: luka, patah tulang, hipotermia, gigitan ular
- 🧭 **Navigasi**: panduan saat tersesat
- ⏱️ **Estimasi waktu** tempuh pendakian
- 💧 **Pencegahan** dehidrasi & hipotermia
- 🆘 **Prosedur darurat** dan evakuasi

Ceritakan kondisi atau keluhan Anda, dan saya akan memberikan panduan penanganan yang tepat!''';
    }

    // Default response
    return '''🏔️ **Survival Assistant TimurLang**

Terima kasih atas pertanyaan Anda. Berikut panduan umum keselamatan:

1. Selalu informasikan rencana pendakian ke pihak basecamp
2. Bawa perlengkapan P3K yang memadai
3. Pantau cuaca sebelum dan selama pendakian
4. Jangan mendaki sendirian di jalur yang tidak familiar
5. Patuhi batas jam operasional pendakian

💡 Tanyakan hal spesifik seperti:
- "Cara menangani luka terbuka"
- "Estimasi waktu tempuh pendakian"
- "Apa yang harus dilakukan saat tersesat"
- "Penanganan hipotermia"

Saya siap membantu! 🙌''';
  }

  /// Clear chat history
  void clearHistory() {
    _history.clear();
  }
}
