// ============================================
// TimurLang - Manage Trail Checkpoints Screen
// Khusus Akun Basecamp: Mengatur, menambah, mengedit,
// dan menghapus titik pos / checkpoint jalur pendakian
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../models/basecamp_post.dart';
import '../../models/mountain.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../services/trail_service.dart';

class ManageTrailCheckpointsScreen extends StatefulWidget {
  final BasecampPost basecampPost;
  final Mountain? mountain;

  const ManageTrailCheckpointsScreen({
    super.key,
    required this.basecampPost,
    this.mountain,
  });

  @override
  State<ManageTrailCheckpointsScreen> createState() => _ManageTrailCheckpointsScreenState();
}

class _ManageTrailCheckpointsScreenState extends State<ManageTrailCheckpointsScreen> {
  late BasecampPost _currentBasecamp;
  Mountain? _mountain;
  List<TrailCheckpoint> _checkpoints = [];
  bool _isCustomized = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentBasecamp = widget.basecampPost;
    _mountain = widget.mountain;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Muat data gunung jika belum ada
      _mountain ??= await DatabaseService.instance.getMountainById(_currentBasecamp.gunungId);

      // 2. Muat checkpoints khusus untuk basecamp ini saja (otoritas basecamp masing-masing)
      _loadCheckpointsForBasecamp(_currentBasecamp);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadCheckpointsForBasecamp(BasecampPost bc) {
    if (bc.checkpointsJson != null && bc.checkpointsJson!.trim().isNotEmpty) {
      final parsed = TrailCheckpoint.listFromJson(bc.checkpointsJson!);
      if (parsed.isNotEmpty) {
        _checkpoints = List.from(parsed);
        _isCustomized = true;
        return;
      }
    }
    // Jika belum kustom, generate dari template default acuan
    final peakElevasi = _mountain?.elevasiMdpl ?? 3000;
    _checkpoints = TrailService.instance.generateDefaultCheckpoints(bc.namaPos, peakElevasi);
    _isCustomized = false;
  }

  void _resetToDefaultTemplate() {
    HapticFeedback.mediumImpact();
    final peakElevasi = _mountain?.elevasiMdpl ?? 3000;
    setState(() {
      _checkpoints = TrailService.instance.generateDefaultCheckpoints(_currentBasecamp.namaPos, peakElevasi);
      _isCustomized = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Template pos default dimuat. Anda dapat mengedit dan menyimpannya.'),
        backgroundColor: AppTheme.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _moveCheckpoint(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _checkpoints.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      final item = _checkpoints.removeAt(oldIndex);
      _checkpoints.insert(newIndex, item);
      _isCustomized = true;
    });
  }

  void _deleteCheckpoint(int index) {
    HapticFeedback.mediumImpact();
    final removed = _checkpoints[index];
    setState(() {
      _checkpoints.removeAt(index);
      _isCustomized = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed.name} dihapus.'),
        action: SnackBarAction(
          label: 'BATAL',
          textColor: Colors.amberAccent,
          onPressed: () {
            setState(() {
              _checkpoints.insert(index, removed);
            });
          },
        ),
      ),
    );
  }

  void _showAddOrEditDialog({TrailCheckpoint? initial, int? index}) {
    final isEdit = initial != null && index != null;
    final nameCtrl = TextEditingController(text: initial?.name ?? 'Pos ${_checkpoints.length}');
    final elevasiCtrl = TextEditingController(
      text: initial != null ? initial.elevationMdpl.toString() : '${1500 + (_checkpoints.length * 250)}',
    );
    final descCtrl = TextEditingController(
      text: initial?.description ?? 'Pos peristirahatan dan area cek kondisi pendaki',
    );
    bool hasWater = initial?.hasWater ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isEdit ? Icons.edit_location_alt : Icons.add_location_alt,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEdit ? 'Edit Titik Pos' : 'Tambah Titik Pos Baru',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 12),

                  // Nama Pos
                  Text(
                    'Nama Pos / Titik Checkpoint',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Pos 2 - Watu Ceper',
                      prefixIcon: const Icon(Icons.signpost_outlined, size: 18),
                      filled: true,
                      fillColor: AppTheme.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Elevasi MDPL
                  Text(
                    'Ketinggian / Elevasi (MDPL)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: elevasiCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Contoh: 2150',
                      prefixIcon: const Icon(Icons.landscape_outlined, size: 18),
                      suffixText: 'MDPL',
                      suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: AppTheme.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sumber Air Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: hasWater ? Colors.lightBlue.withValues(alpha: 0.1) : AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasWater ? Colors.lightBlue : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.water_drop_rounded,
                              color: hasWater ? Colors.lightBlue : AppTheme.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tersedia Sumber Mata Air',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  hasWater ? 'Pendaki dapat mengambil air di pos ini' : 'Tidak ada mata air di pos ini',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: hasWater,
                          activeThumbColor: Colors.lightBlue,
                          onChanged: (val) => setModalState(() => hasWater = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Deskripsi
                  Text(
                    'Keterangan / Fasilitas Pos',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Shelter istirahat, tanah datar muat 5 tenda',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                      filled: true,
                      fillColor: AppTheme.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Simpan / Tambah Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final elevasi = int.tryParse(elevasiCtrl.text.trim()) ?? 1000;
                        final desc = descCtrl.text.trim();
                        if (name.isEmpty) return;

                        final newCp = TrailCheckpoint(
                          name: name,
                          location: initial?.location ?? const LatLng(0, 0),
                          elevationMdpl: elevasi,
                          description: desc.isNotEmpty ? desc : 'Pos peristirahatan pendakian',
                          hasWater: hasWater,
                        );

                        Navigator.pop(ctx);
                        setState(() {
                          if (isEdit) {
                            _checkpoints[index] = newCp;
                          } else {
                            _checkpoints.add(newCp);
                          }
                          _isCustomized = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isEdit ? 'Perbarui Titik Pos' : 'Tambahkan ke Jalur',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveCheckpoints() async {
    if (_checkpoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap cantumkan minimal 1 titik pos/basecamp sebelum menyimpan.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final jsonStr = TrailCheckpoint.listToJson(_checkpoints);

      // 1. Simpan ke database lokal SQLite
      await DatabaseService.instance.updateBasecampCheckpoints(_currentBasecamp.id, jsonStr);

      // 2. Update status lokal BasecampPost
      _currentBasecamp = _currentBasecamp.copyWith(checkpointsJson: jsonStr);
      _isCustomized = true;

      // 3. Sinkron ke server Supabase jika online
      if (SupabaseService.instance.isInitialized) {
        try {
          await SupabaseService.instance.syncBasecampPost(_currentBasecamp);
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Titik pos ${_currentBasecamp.namaPos} berhasil disimpan! Data langsung terupdate di Peta Offline.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.safeGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan titik pos: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mountainName = _mountain?.namaGunung ?? 'Gunung';
    final peakElevasi = _mountain?.elevasiMdpl ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Atur Titik Pos Jalur',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Card Informasi Jalur & Basecamp
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.terrain, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                mountainName,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$peakElevasi MDPL',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.signpost_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Jalur / Basecamp: ${_currentBasecamp.namaPos}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Keterangan Basecamp Terkelola (Otoritas Resmi Basecamp Masing-Masing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shield_outlined, size: 18, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Otoritas Jalur: ${_currentBasecamp.namaPos}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Pengaturan titik pos hanya berlaku untuk pos & shelter di jalur basecamp Anda.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Status Banner (Kustom vs Template Default)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isCustomized
                        ? AppTheme.safeGreen.withValues(alpha: 0.1)
                        : AppTheme.warningYellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isCustomized
                          ? AppTheme.safeGreen.withValues(alpha: 0.4)
                          : AppTheme.warningYellow.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isCustomized ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: _isCustomized ? AppTheme.safeGreen : AppTheme.warningYellow,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isCustomized
                              ? 'Titik pos kustom aktif untuk jalur ini dan akan tampil langsung di Peta Offline.'
                              : 'Saat ini jalur menggunakan template pos acuan. Sesuaikan atau tambah pos untuk mengaktifkan data kustom.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Section Title & Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daftar Titik Pos (${_checkpoints.length} Titik)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddOrEditDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Pos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // List of Checkpoints
                if (_checkpoints.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(28),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.wrong_location_outlined, size: 42, color: AppTheme.textSecondary),
                        const SizedBox(height: 10),
                        Text(
                          'Belum Ada Titik Pos',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ketuk "Tambah Pos" untuk membuat pos kustom atau gunakan template acuan.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _resetToDefaultTemplate,
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Gunakan Template Acuan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary, width: 1.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  for (int i = 0; i < _checkpoints.length; i++) ...[
                    _buildCheckpointCard(i, _checkpoints[i]),
                    const SizedBox(height: 10),
                  ],
                ],

                const SizedBox(height: 20),

                // Big Save Button at bottom
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveCheckpoints,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Titik Pos Jalur',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildCheckpointCard(int index, TrailCheckpoint cp) {
    final isFirst = index == 0;
    final isLast = index == _checkpoints.length - 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index Circle
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isLast
                      ? Colors.redAccent
                      : isFirst
                          ? AppTheme.primary
                          : AppTheme.primarySubtle,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: (isFirst || isLast) ? Colors.white : AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Title and MDPL
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cp.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${cp.elevationMdpl} MDPL',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (cp.hasWater)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.water_drop, size: 11, color: Colors.lightBlue),
                                SizedBox(width: 3),
                                Text(
                                  'Sumber Air',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Reorder Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: index > 0 ? () => _moveCheckpoint(index, index - 1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: index < _checkpoints.length - 1 ? () => _moveCheckpoint(index, index + 1) : null,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            cp.description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 6),

          // Edit & Delete row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showAddOrEditDialog(initial: cp, index: index),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _deleteCheckpoint(index),
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('Hapus'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppTheme.dangerRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
