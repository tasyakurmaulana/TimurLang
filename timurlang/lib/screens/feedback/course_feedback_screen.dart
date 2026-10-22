// ============================================
// TimurLang - Course Feedback Screen
// ============================================

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/course_feedback.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/custom_text_field.dart';

class CourseFeedbackScreen extends StatefulWidget {
  final bool embedded;
  const CourseFeedbackScreen({super.key, this.embedded = false});

  @override
  State<CourseFeedbackScreen> createState() => _CourseFeedbackScreenState();
}

class _CourseFeedbackScreenState extends State<CourseFeedbackScreen> {
  final _kesanCtrl = TextEditingController();
  int _rating = 5;
  bool _isLoading = false;

  // 5 Saran & Kesan terbaru dari database
  List<CourseFeedback> _recentFeedbacks = [];
  bool _isLoadingFeedbacks = true;

  @override
  void initState() {
    super.initState();
    _loadRecentFeedbacks();
  }

  @override
  void dispose() {
    _kesanCtrl.dispose();
    super.dispose();
  }

  /// Memuat 5 saran dan kesan terbaru dari SQLite dan Supabase
  Future<void> _loadRecentFeedbacks({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoadingFeedbacks = true);
    }

    try {
      // 1. Ambil data lokal terlebih dahulu agar responsif dan dapat diakses saat offline
      final localFeedbacks = await DatabaseService.instance.getLatestFeedbacks(limit: 5);
      if (mounted) {
        setState(() {
          _recentFeedbacks = localFeedbacks;
          if (!silent) _isLoadingFeedbacks = false;
        });
      }

      // 2. Tarik data terbaru dari Supabase jika online
      if (!SupabaseService.instance.isInitialized) {
        await SupabaseService.instance.initialize();
      }

      if (SupabaseService.instance.isInitialized) {
        final remoteFeedbacks = await SupabaseService.instance.getLatestFeedbacks(limit: 5);
        if (remoteFeedbacks.isNotEmpty) {
          // Simpan ke SQLite lokal
          for (final fb in remoteFeedbacks) {
            await DatabaseService.instance.insertFeedback(fb);
          }
          final updated = await DatabaseService.instance.getLatestFeedbacks(limit: 5);
          if (mounted) {
            setState(() {
              _recentFeedbacks = updated;
              _isLoadingFeedbacks = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Gagal memuat feedback terbaru: $e');
    } finally {
      if (mounted && _isLoadingFeedbacks) {
        setState(() => _isLoadingFeedbacks = false);
      }
    }
  }

  /// Sensor sebagian nama pengguna (setengah nama disensor bintang)
  /// Contoh: "Tasyakur Maulana" -> "Tasy**** Maul***"
  /// Contoh: "Budi" -> "Bu**"
  String _maskUsername(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'Pengguna';

    final words = clean.split(RegExp(r'\s+'));
    return words.map((word) {
      if (word.length <= 1) return '*';
      if (word.length == 2) return '${word[0]}*';
      if (word.length == 3) return '${word.substring(0, 2)}*';

      // Sensor separuh karakter di bagian akhir
      final visibleLen = (word.length / 2).ceil();
      final maskedLen = word.length - visibleLen;
      return '${word.substring(0, visibleLen)}${'*' * maskedLen}';
    }).join(' ');
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return AppDateUtils.formatDateIndonesian(dt);
  }

  Widget _buildRatingStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: AppTheme.warningYellow,
          size: 16,
        );
      }),
    );
  }

  Widget _buildFeedbackCard(CourseFeedback fb) {
    final maskedName = _maskUsername(fb.namaPengguna);
    final initial = fb.namaPengguna.trim().isNotEmpty
        ? fb.namaPengguna.trim()[0].toUpperCase()
        : 'U';
    final ratingVal = fb.rating ?? 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            maskedName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Mahasiswa',
                            style: TextStyle(fontSize: 9.5, color: AppTheme.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(fb.submittedAt),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              _buildRatingStars(ratingVal),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border, width: 1),
            ),
            child: Text(
              fb.kesanPesan,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback() async {
    final text = _kesanCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kesan dan pesan tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silakan login terlebih dahulu untuk mengirim saran & kesan.'),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        }
        return;
      }

      final feedback = CourseFeedback(
        id: const Uuid().v4(),
        userId: user.id,
        namaPengguna: user.namaLengkap,
        kesanPesan: text,
        rating: _rating,
        submittedAt: DateTime.now(),
      );

      // 1. Simpan ke database lokal SQLite
      await DatabaseService.instance.insertFeedback(feedback);

      // 2. Sinkronkan ke Supabase secara langsung
      bool isSynced = false;
      try {
        if (!SupabaseService.instance.isInitialized) {
          await SupabaseService.instance.initialize();
        }

        if (SupabaseService.instance.isInitialized) {
          // Pastikan akun user tersinkronisasi di tabel users Supabase agar foreign key valid
          await SupabaseService.instance.syncUser(user);

          // Upload feedback ke Supabase
          isSynced = await SupabaseService.instance.syncFeedback(feedback);

          // Sinkronkan juga semua data feedback lokal lama yang belum pernah terkirim ke Supabase
          final allFeedbacks = await DatabaseService.instance.getAllFeedbacks();
          for (final fb in allFeedbacks) {
            if (fb.id != feedback.id) {
              await SupabaseService.instance.syncFeedback(fb);
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error saat sync feedback ke Supabase: $e');
      }

      // 3. Jika offline atau gagal kirim langsung, masukkan ke antrean sinkronisasi
      if (!isSynced) {
        await SyncService.instance.addToQueue(
          tableName: 'course_feedbacks',
          recordId: feedback.id,
          action: 'insert',
          payload: feedback.toMap(),
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _kesanCtrl.clear();
          _rating = 5;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSynced
                ? 'Terima kasih atas saran dan kesan Anda! (Berhasil tersimpan ke Supabase)'
                : 'Saran & kesan tersimpan di lokal dan akan otomatis diunggah saat online.'),
            backgroundColor: AppTheme.safeGreen,
          ),
        );

        // Segera muat ulang 5 feedback terbaru agar feedback yang baru saja diinput langsung tampil
        await _loadRecentFeedbacks(silent: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: () => _loadRecentFeedbacks(silent: false),
      color: AppTheme.primaryGreen,
      backgroundColor: AppTheme.cardDark,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.embedded) const SizedBox(height: 16),
            const Text(
              'Saran & Kesan Mata Kuliah',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Evaluasi dan masukan untuk mata kuliah Pemrograman Aplikasi Mobile.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Form Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Beri Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.warningYellow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: AppTheme.warningYellow, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '$_rating / 5 Bintang',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.warningYellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: AppTheme.warningYellow,
                          size: 36,
                        ),
                        onPressed: () => setState(() => _rating = index + 1),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _kesanCtrl,
                    label: 'Kesan dan Pesan',
                    hint: 'Tuliskan pengalaman belajar, saran materi, kendala, dll...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitFeedback,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Kirim Evaluasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Header Bagian 5 Saran & Kesan Terbaru
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.forum_rounded, color: AppTheme.skyBlue, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saran & Kesan Terbaru',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        '5 ulasan evaluasi terbaru dari pengguna lain',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: AppTheme.textSecondary),
                  tooltip: 'Segarkan data',
                  onPressed: () => _loadRecentFeedbacks(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Daftar 5 Saran & Kesan Terbaru
            if (_isLoadingFeedbacks)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_recentFeedbacks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border, width: 1),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.rate_review_outlined, size: 44, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada saran & kesan dari pengguna lain.',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Jadilah yang pertama mengirimkan evaluasi mata kuliah!',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              )
            else
              ..._recentFeedbacks.map(_buildFeedbackCard),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );

    if (widget.embedded) return SafeArea(child: content);
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluasi Mata Kuliah')),
      body: content,
    );
  }
}
