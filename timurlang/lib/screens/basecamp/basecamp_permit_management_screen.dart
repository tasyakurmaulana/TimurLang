// ============================================
// TimurLang - Basecamp Permit Management Screen
// Manajemen Reservasi, Kebijakan Pembatalan Resmi Basecamp,
// & Pengolahan Opsi Refund 100% / Reschedule
// Aura Travel Design System
// ============================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/simaksi_permit.dart';
import '../../models/basecamp_post.dart';
import '../../services/blockchain_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/date_utils.dart';

class BasecampPermitManagementScreen extends StatefulWidget {
  final BasecampPost basecampPost;

  const BasecampPermitManagementScreen({
    super.key,
    required this.basecampPost,
  });

  @override
  State<BasecampPermitManagementScreen> createState() => _BasecampPermitManagementScreenState();
}

class _BasecampPermitManagementScreenState extends State<BasecampPermitManagementScreen> {
  List<SimaksiPermit> _allPermits = [];
  final Map<String, String> _leaderNames = {};
  bool _isLoading = true;
  String _selectedTab = 'Semua'; // 'Semua', 'Menunggu Refund', 'Terdaftar', 'Dibatalkan'

  @override
  void initState() {
    super.initState();
    _loadPermits();
  }

  Future<void> _loadPermits() async {
    // Tarik permit terbaru dari Supabase
    if (SupabaseService.instance.isInitialized) {
      try {
        final remotePermits = await SupabaseService.instance.getAllPermits();
        for (final p in remotePermits) {
          await DatabaseService.instance.insertPermit(p);
        }
      } catch (_) {}
    }

    final permits = await DatabaseService.instance.getAllPermitsForBasecamp(
      gunungId: widget.basecampPost.gunungId,
      basecampId: widget.basecampPost.id,
    );

    // Ambil nama ketua pendaki
    for (final p in permits) {
      if (_leaderNames.containsKey(p.id)) continue;
      String? name;
      if (p.members.isNotEmpty) {
        final ketua = p.members.firstWhere(
          (m) => m.isKetua,
          orElse: () => p.members.first,
        );
        if (ketua.nama.trim().isNotEmpty) {
          name = ketua.nama.trim();
        }
      }
      if (name == null || name.isEmpty) {
        try {
          final u = await DatabaseService.instance.getUserById(p.userId);
          if (u != null && u.namaLengkap.trim().isNotEmpty) {
            name = u.namaLengkap.trim();
          }
        } catch (_) {}
      }
      _leaderNames[p.id] = name ?? 'Ketua Pendaki';
    }

    if (mounted) {
      setState(() {
        _allPermits = permits;
        _isLoading = false;
      });
    }
  }

  List<SimaksiPermit> get _filteredPermits {
    if (_selectedTab == 'Menunggu Refund') {
      return _allPermits.where((p) => p.isRefundRequested).toList();
    } else if (_selectedTab == 'Terdaftar') {
      return _allPermits.where((p) {
        return (p.statusIzin == AppConstants.statusTerdaftar ||
                p.statusIzin == AppConstants.statusDiajukan ||
                p.statusIzin == AppConstants.statusTervalidasi ||
                p.statusIzin == AppConstants.statusRescheduled) &&
            !p.isCancelled &&
            !p.isOfficialCancellation &&
            !p.isRefundRequested;
      }).toList();
    } else if (_selectedTab == 'Dibatalkan') {
      return _allPermits.where((p) =>
        p.isCancelled ||
        p.isOfficialCancellation ||
        p.isRefundRequested ||
        p.isRefundCompleted
      ).toList();
    }
    return _allPermits;
  }

  int get _countPendingRefunds => _allPermits.where((p) => p.isRefundRequested).length;
  int get _countActiveBooked => _allPermits.where((p) {
    return (p.statusIzin == AppConstants.statusTerdaftar ||
            p.statusIzin == AppConstants.statusDiajukan ||
            p.statusIzin == AppConstants.statusTervalidasi ||
            p.statusIzin == AppConstants.statusRescheduled) &&
        !p.isCancelled &&
        !p.isOfficialCancellation &&
        !p.isRefundRequested;
  }).length;
  int get _countCancelled => _allPermits.where((p) =>
    p.isCancelled ||
    p.isOfficialCancellation ||
    p.isRefundRequested ||
    p.isRefundCompleted
  ).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPermits;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Manajemen Reservasi & Pembatalan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.surface,
              onRefresh: _loadPermits,
              child: Column(
                children: [
                  // Action Hero Card: Kebijakan Pembatalan Resmi Basecamp
                  _buildOfficialClosureActionCard(),

                  // Filter Tabs Bar
                  _buildTabsBar(),

                  // List of Tickets
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              return _buildPermitCard(filtered[i]);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  // Hero Card: Tombol Umumkan Pembatalan Resmi
  Widget _buildOfficialClosureActionCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kebijakan Pembatalan Resmi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Tutup jalur akibat cuaca ekstrem/bencana & berikan hak Refund 100% / Reschedule ke pendaki',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showOfficialCancellationAnnouncementDialog,
              icon: const Icon(Icons.announcement_rounded, size: 16),
              label: Text(
                'Umumkan Pembatalan Resmi Jalur',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsBar() {
    final tabs = [
      {'label': 'Semua', 'count': _allPermits.length},
      {'label': 'Menunggu Refund', 'count': _countPendingRefunds},
      {'label': 'Terdaftar', 'count': _countActiveBooked},
      {'label': 'Dibatalkan', 'count': _countCancelled},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.6), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: tabs.map((tab) {
            final label = tab['label'] as String;
            final count = tab['count'] as int;
            final isSelected = _selectedTab == label;

            Color badgeBg;
            Color badgeText;
            if (label == 'Menunggu Refund') {
              badgeBg = isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFEA580C).withValues(alpha: 0.15);
              badgeText = isSelected ? Colors.white : const Color(0xFFEA580C);
            } else if (label == 'Dibatalkan') {
              badgeBg = isSelected ? Colors.white.withValues(alpha: 0.25) : AppTheme.dangerRed.withValues(alpha: 0.15);
              badgeText = isSelected ? Colors.white : AppTheme.dangerRed;
            } else {
              badgeBg = isSelected ? Colors.white.withValues(alpha: 0.25) : AppTheme.primarySubtle;
              badgeText = isSelected ? Colors.white : AppTheme.primary;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedTab = label),
                borderRadius: BorderRadius.circular(9999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: badgeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPermitCard(SimaksiPermit permit) {
    final leaderName = _leaderNames[permit.id] ?? 'Ketua Pendaki';
    final isPendingRefund = permit.isRefundRequested;
    final isOfficialCancelled = permit.isOfficialCancellation;
    final isVoluntaryCancelled = permit.statusIzin == AppConstants.statusDibatalkanPendaki;
    final isRefundDone = permit.isRefundCompleted;

    Color statusColor;
    String statusLabel = permit.statusIzin;

    if (isPendingRefund) {
      statusColor = const Color(0xFFEA580C);
      statusLabel = 'Menunggu Transfer Refund';
    } else if (isRefundDone) {
      statusColor = AppTheme.safeGreen;
      statusLabel = 'Refund 100% Selesai';
    } else if (isOfficialCancelled) {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Batal Resmi (Opsi Refund/Reschedule)';
    } else if (isVoluntaryCancelled) {
      statusColor = AppTheme.dangerRed;
      statusLabel = 'Batal oleh Pendaki (Non-Refund)';
    } else {
      statusColor = AppTheme.skyBlue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPendingRefund
              ? const Color(0xFFFB923C)
              : AppTheme.border,
          width: isPendingRefund ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Leader Name & Status
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leaderName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Rombongan: ${permit.jumlahAnggota} Orang',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.border),

          // Detail Tanggal & Total Biaya
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tanggal Naik:', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppTheme.textSecondary)),
                    Text(
                      AppDateUtils.formatDateIndonesian(permit.tanggalNaik),
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tanggal Turun:', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppTheme.textSecondary)),
                    Text(
                      AppDateUtils.formatDateIndonesian(permit.tanggalTurun),
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Biaya:', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppTheme.textSecondary)),
                  Text(
                    'Rp ${(permit.totalBiaya ?? 0).toInt()}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
                  ),
                ],
              ),
            ],
          ),

          // Alasan Pembatalan (jika ada)
          if (permit.alasanPembatalan != null && permit.alasanPembatalan!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Alasan: ${permit.alasanPembatalan}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Jika ada pengajuan Refund: tampilkan info rekening
          if (isPendingRefund) ...[
            const SizedBox(height: 12),
            _buildRefundDetailsCard(permit),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmCompleteRefund(permit),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(
                  'Tandai Refund Telah Ditransfer (Selesai)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],

          // Tombol Pembatalan Resmi Basecamp per tiket (hanya jika tiket aktif/terdaftar)
          if (!permit.isCancelled && !isPendingRefund && !isOfficialCancelled && permit.statusIzin != AppConstants.statusDiJalur && permit.statusIzin != AppConstants.statusSelesai) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSinglePermitOfficialCancelDialog(permit),
                  icon: const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFD97706)),
                  label: Text(
                    'Batalkan Resmi (Opsi Refund/Reschedule)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCD34D)),
                    backgroundColor: const Color(0xFFFFFBEB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefundDetailsCard(SimaksiPermit permit) {
    Map<String, dynamic>? refundInfo;
    if (permit.rekeningRefund != null && permit.rekeningRefund!.isNotEmpty) {
      try {
        refundInfo = jsonDecode(permit.rekeningRefund!);
      } catch (_) {}
    }

    final provider = refundInfo?['provider'] ?? '-';
    final nomor = refundInfo?['nomor'] ?? '-';
    final nama = refundInfo?['nama'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFFEA580C)),
              const SizedBox(width: 6),
              Text(
                'Data Rekening Pengembalian Dana 100%:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFC2410C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• Bank / E-Wallet: $provider\n• Nomor Rekening: $nomor\n• Atas Nama: $nama\n• Nominal Transfer: Rp ${(permit.totalBiaya ?? 0).toInt()}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7C2D12),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Dialog Pembatalan Resmi Jalur Massal
  void _showOfficialCancellationAnnouncementDialog() {
    String selectedReason = 'Cuaca Ekstrem / Hujan Badai & Angin Kencang';
    final otherCtrl = TextEditingController();
    bool isSubmitting = false;

    final reasons = [
      'Cuaca Ekstrem / Hujan Badai & Angin Kencang',
      'Aktivitas Vulkanik Meningkat / Status Waspada Erupsi',
      'Jalur Mengalami Longsor / Kerusakan Berat',
      'Penutupan Jalur Resmi Balai Taman Nasional',
      'Lainnya',
    ];

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pengumuman Pembatalan Resmi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Pos ${widget.basecampPost.namaPos}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppTheme.border),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        'Pemberitahuan ini akan memberlakukan pembatalan resmi pada seluruh tiket aktif yang terdaftar di basecamp ini. Setiap pendaki otomatis mendapatkan hak memilih antara Refund 100% atau Reschedule (Ubah Jadwal).',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF92400E), height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Pilih Alasan Pembatalan Resmi:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return InkWell(
                        onTap: () => setModalState(() => selectedReason = r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: isSelected ? const Color(0xFFD97706) : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    if (selectedReason == 'Lainnya') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherCtrl,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Tuliskan alasan resmi...',
                          filled: true,
                          fillColor: AppTheme.surfaceSubtle,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final finalReason = selectedReason == 'Lainnya' && otherCtrl.text.trim().isNotEmpty
                                  ? otherCtrl.text.trim()
                                  : selectedReason;

                              final count = await BlockchainService.instance.cancelAllActivePermitsForBasecamp(
                                gunungId: widget.basecampPost.gunungId,
                                basecampId: widget.basecampPost.id,
                                officialReason: finalReason,
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Berhasil memberlakukan pembatalan resmi pada $count tiket. Pendaki telah diberikan opsi Refund 100% atau Reschedule.',
                                      style: GoogleFonts.plusJakartaSans(),
                                    ),
                                    backgroundColor: const Color(0xFFD97706),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                _loadPermits();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Berlakukan Pembatalan Resmi Jalur',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Dialog Pembatalan Resmi untuk 1 Tiket
  void _showSinglePermitOfficialCancelDialog(SimaksiPermit permit) {
    String selectedReason = 'Cuaca Ekstrem / Hujan Badai & Angin Kencang';
    final otherCtrl = TextEditingController();
    bool isSubmitting = false;

    final reasons = [
      'Cuaca Ekstrem / Hujan Badai & Angin Kencang',
      'Aktivitas Vulkanik Meningkat / Status Waspada Erupsi',
      'Jalur Mengalami Longsor / Kerusakan Berat',
      'Penutupan Jalur Resmi Balai Taman Nasional',
      'Lainnya',
    ];

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Batalkan Tiket Secara Resmi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Tiket ${_leaderNames[permit.id] ?? "Pendaki"} (${permit.jumlahAnggota} Orang)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppTheme.border),

                    Text(
                      'Pilih Alasan Kebijakan Resmi Basecamp:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return InkWell(
                        onTap: () => setModalState(() => selectedReason = r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: isSelected ? const Color(0xFFD97706) : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    if (selectedReason == 'Lainnya') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherCtrl,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Tuliskan alasan resmi...',
                          filled: true,
                          fillColor: AppTheme.surfaceSubtle,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final finalReason = selectedReason == 'Lainnya' && otherCtrl.text.trim().isNotEmpty
                                  ? otherCtrl.text.trim()
                                  : selectedReason;

                              final res = await BlockchainService.instance.cancelPermitByBasecamp(
                                permitId: permit.id,
                                officialReason: finalReason,
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.message, style: GoogleFonts.plusJakartaSans()),
                                    backgroundColor: res.success ? const Color(0xFFD97706) : AppTheme.dangerRed,
                                  ),
                                );
                                _loadPermits();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Konfirmasi Pembatalan Resmi',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Konfirmasi Penyelesaian Transfer Refund
  void _confirmCompleteRefund(SimaksiPermit permit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Konfirmasi Selesai Refund',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah Anda sudah mentransfer dana sebesar Rp ${(permit.totalBiaya ?? 0).toInt()} ke rekening pendaki?\n\nStatus tiket akan diperbarui menjadi SELESAI REFUND.',
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await BlockchainService.instance.completeRefundByBasecamp(permitId: permit.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message, style: GoogleFonts.plusJakartaSans()),
                    backgroundColor: const Color(0xFF15803D),
                  ),
                );
                _loadPermits();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
            ),
            child: Text('Ya, Sudah Ditransfer', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.confirmation_num_outlined, size: 54, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'Tidak ada reservasi pada tab ini',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
