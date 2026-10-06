// ============================================
// TimurLang - Course Feedback Model
// ============================================

class CourseFeedback {
  final String id;
  final String userId;
  final String namaPengguna;
  final String kesanPesan;
  final int? rating;
  final DateTime submittedAt;

  CourseFeedback({
    required this.id,
    required this.userId,
    required this.namaPengguna,
    required this.kesanPesan,
    this.rating,
    required this.submittedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'nama_pengguna': namaPengguna,
      'kesan_pesan': kesanPesan,
      'rating': rating,
      'submitted_at': submittedAt.toIso8601String(),
    };
  }

  factory CourseFeedback.fromMap(Map<String, dynamic> map) {
    return CourseFeedback(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      namaPengguna: map['nama_pengguna'] as String,
      kesanPesan: map['kesan_pesan'] as String,
      rating: map['rating'] as int?,
      submittedAt: DateTime.parse(map['submitted_at'] as String),
    );
  }
}
