// ============================================
// TimurLang - Course Feedback Screen
// ============================================

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/course_feedback.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
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

  Future<void> _submitFeedback() async {
    if (_kesanCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kesan dan pesan tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final feedback = CourseFeedback(
      id: const Uuid().v4(),
      userId: user.id,
      namaPengguna: user.namaLengkap,
      kesanPesan: _kesanCtrl.text.trim(),
      rating: _rating,
      submittedAt: DateTime.now(),
    );

    await DatabaseService.instance.insertFeedback(feedback);
    
    setState(() {
      _isLoading = false;
      _kesanCtrl.clear();
      _rating = 5;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terima kasih atas saran dan kesan Anda!'), backgroundColor: AppTheme.safeGreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.embedded) const SizedBox(height: 32),
          const Text(
            'Saran & Kesan Mata Kuliah',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Evaluasi untuk mata kuliah Pemrograman Aplikasi Mobile.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 32),
          
          const Text('Rating', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: AppTheme.warningYellow,
                  size: 32,
                ),
                onPressed: () => setState(() => _rating = index + 1),
              );
            }),
          ),
          const SizedBox(height: 24),

          CustomTextField(
            controller: _kesanCtrl,
            label: 'Kesan dan Pesan',
            hint: 'Tuliskan pengalaman belajar, saran materi, dll...',
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitFeedback,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Kirim Evaluasi'),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return SafeArea(child: content);
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluasi Mata Kuliah')),
      body: content,
    );
  }
}
