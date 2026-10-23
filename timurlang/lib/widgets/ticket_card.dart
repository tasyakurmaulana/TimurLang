// ============================================
// TimurLang - Ticket Card Widget
// Boarding pass with interactive WIB, WITA, WIT time zone converter
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../models/simaksi_permit.dart';
import '../services/blockchain_service.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';
import '../utils/time_zone_helper.dart';

class TicketCard extends StatefulWidget {
  final SimaksiPermit permit;
  final VoidCallback? onTap;

  const TicketCard({super.key, required this.permit, this.onTap});

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  late String _nativeZone;
  late String _selectedZone;
  bool _isExpanded = false;
  String? _resolvedBasecampName;

  @override
  void initState() {
    super.initState();
    _nativeZone = TimeZoneHelper.getMountainTimeZone(
      mountainName: widget.permit.namaGunung,
    );
    _selectedZone = _nativeZone;
    final initialName = widget.permit.namaBasecamp;
    if (initialName != null &&
        initialName.isNotEmpty &&
        initialName != 'Pos Basecamp Resmi') {
      _resolvedBasecampName = initialName;
    } else {
      _loadBasecampName();
    }
  }

  @override
  void didUpdateWidget(TicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.permit.namaBasecamp != oldWidget.permit.namaBasecamp ||
        widget.permit.basecampId != oldWidget.permit.basecampId ||
        widget.permit.gunungId != oldWidget.permit.gunungId) {
      final initialName = widget.permit.namaBasecamp;
      if (initialName != null &&
          initialName.isNotEmpty &&
          initialName != 'Pos Basecamp Resmi') {
        _resolvedBasecampName = initialName;
      } else {
        _loadBasecampName();
      }
    }
  }

  Future<void> _loadBasecampName() async {
    try {
      // 1. Cek langsung via basecampId
      if (widget.permit.basecampId != null &&
          widget.permit.basecampId!.isNotEmpty) {
        final bc = await DatabaseService.instance.getBasecampById(widget.permit.basecampId!);
        if (bc != null && mounted) {
          setState(() {
            _resolvedBasecampName = bc.namaPos;
          });
          return;
        }
      }

      // 2. Jika permit.namaBasecamp sudah ada dan bukan default generic, gunakan langsung
      final candidateName = widget.permit.namaBasecamp;
      if (candidateName != null &&
          candidateName.isNotEmpty &&
          candidateName != 'Pos Basecamp Resmi') {
        if (mounted) {
          setState(() {
            _resolvedBasecampName = candidateName;
          });
        }
        return;
      }

      // 3. Fallback HANYA jika gunung memiliki tepat 1 basecamp resmi
      if (widget.permit.gunungId.isNotEmpty) {
        final bcs = await DatabaseService.instance.getRegisteredBasecampsByMountain(widget.permit.gunungId);
        if (bcs.length == 1 && mounted) {
          setState(() {
            _resolvedBasecampName = bcs.first.namaPos;
          });
          return;
        }
      }
    } catch (_) {}
  }

  /// QR hanya aktif saat tiket baru terdaftar / diajukan.
  /// Setelah di-scan dan divalidasi oleh Basecamp (Di Jalur, Selesai, Ditolak),
  /// QR code otomatis hangus / hilang (single-use).
  bool get _isQrActive =>
      widget.permit.statusIzin == AppConstants.statusTerdaftar ||
      widget.permit.statusIzin == AppConstants.statusDiajukan;

  Color _getStatusColor() {
    switch (widget.permit.statusIzin) {
      case 'Terdaftar':
        return AppTheme.skyBlue;
      case 'Tervalidasi':
        return AppTheme.safeGreen;
      case 'Di Jalur':
        return AppTheme.accentOrange;
      case 'Selesai':
        return AppTheme.mistGrey;
      case 'Ditolak':
        return AppTheme.dangerRed;
      default:
        return AppTheme.warningYellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Upper Dark Green Status Zone
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              color: AppTheme.primary,
              child: Row(
                children: [
                  const Icon(Icons.confirmation_num_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'BOARDING PASS / SIMAKSI',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      widget.permit.statusIzin,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Inward Notch Edge Separator with Dotted Line
            Row(
              children: [
                Container(
                  width: 14,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boxWidth = constraints.constrainWidth();
                      const dashWidth = 4.0;
                      const dashSpace = 4.0;
                      final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
                      return Flex(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        direction: Axis.horizontal,
                        children: List.generate(dashCount, (idx) {
                          return const SizedBox(
                            width: dashWidth,
                            height: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: AppTheme.border),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
                Container(
                  width: 14,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ],
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Nama Gunung
                  Text(
                    widget.permit.namaGunung ?? 'Gunung',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Jalur Pendakian (Basecamp)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.signpost_rounded, size: 16, color: AppTheme.accentOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jalur Pendakian (Basecamp)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                _resolvedBasecampName ?? widget.permit.namaBasecamp ?? 'Pos Basecamp Resmi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Tanggal Naik & Tanggal Turun
                  Row(
                    children: [
                      Expanded(child: _info('Naik', AppDateUtils.formatDateIndonesian(widget.permit.tanggalNaik))),
                      const SizedBox(width: 16),
                      Expanded(child: _info('Turun', AppDateUtils.formatDateIndonesian(widget.permit.tanggalTurun))),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 4. Rombongan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _info('Rombongan', '${widget.permit.jumlahAnggota} orang'),
                      if (widget.permit.members.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showMembersDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.skyBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_alt_outlined, size: 13, color: AppTheme.skyBlue),
                                SizedBox(width: 4),
                                Text(
                                  'Lihat Anggota',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.skyBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 5. Dropdown Toggle Button
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isExpanded ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isExpanded ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isExpanded ? Icons.schedule_rounded : Icons.qr_code_2_rounded,
                            size: 16,
                            color: _isExpanded ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isExpanded ? 'Sembunyikan Detail Jadwal & QR Code' : 'Buka Detail Jadwal & QR Code',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isExpanded ? AppTheme.primary : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: _isExpanded ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 6. Dropdown Expandable Section (Jadwal masuk basecamp kebawah sampai QR)
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        // ── Jadwal Masuk Basecamp & Dynamic Timezone Switcher ──
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Bar: Title & Subtitle
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 15, color: AppTheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Jadwal Masuk Basecamp',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _selectedZone == _nativeZone
                                        ? 'Zona Asli Pos'
                                        : 'Lokal: $_nativeZone',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Interactive WIB, WITA, WIT Switcher
                              _buildTimeZoneChips(),
                              const SizedBox(height: 10),

                              // Time Range Display
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        TimeZoneHelper.convertTimeRange('07:00 - 16:00', _nativeZone, _selectedZone),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _selectedZone,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Flexible(
                                    child: Text(
                                      _selectedZone == _nativeZone
                                          ? 'Waktu Lokal Gunung'
                                          : '(Lokal: 07:00 - 16:00 $_nativeZone)',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        // QR Code Section (Single-Use: hanya muncul saat belum divalidasi)
                        if (_isQrActive) ...[
                          Center(
                            child: GestureDetector(
                              onTap: () => _showQrDialog(context),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    QrImageView(
                                      data: widget.permit.blockHash,
                                      version: QrVersions.auto,
                                      size: 150.0,
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.all(4),
                                    ),
                                    const SizedBox(height: 6),
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.fullscreen, size: 14, color: Color(0xFF475569)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Ketuk untuk memperbesar QR',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Tunjukkan kode QR kepada petugas di pos basecamp saat check-in.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.permit.blockHash.startsWith('0x')) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => BlockchainService.openExplorer(context, widget.permit.blockHash),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primarySubtle,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Verifikasi di Polygonscan ↗',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          _buildUsedQrSection(context),
                        ],
                      ],
                    ),
                    crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 260),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeZoneChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: AppTheme.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: TimeZoneHelper.supportedTimeZones.map((zone) {
          final isSelected = _selectedZone == zone;
          final isNative = _nativeZone == zone;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedZone = zone);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        zone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (isNative && !isSelected) ...[
                      const SizedBox(width: 3),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildUsedQrSection(BuildContext context) {
    final isDiJalur = widget.permit.statusIzin == AppConstants.statusDiJalur;
    final isSelesai = widget.permit.statusIzin == AppConstants.statusSelesai;
    final isDitolak = widget.permit.statusIzin == AppConstants.statusDitolak;

    final Color primaryColor = isDiJalur
        ? AppTheme.safeGreen
        : isSelesai
            ? AppTheme.mistGrey
            : isDitolak
                ? AppTheme.dangerRed
                : AppTheme.warningYellow;

    final IconData icon = isDiJalur
        ? Icons.verified
        : isSelesai
            ? Icons.task_alt
            : isDitolak
                ? Icons.cancel_outlined
                : Icons.info_outline;

    final String title = isDiJalur
        ? 'QR SEKALI PAKAI TELAH DIGUNAKAN'
        : isSelesai
            ? 'PENDAKIAN TELAH SELESAI'
            : isDitolak
                ? 'TIKET DITOLAK'
                : 'QR CODE SUDAH TIDAK AKTIF';

    final String subtitle = isDiJalur
        ? 'Tiket telah berhasil divalidasi oleh petugas Basecamp. Pendaki resmi terdaftar & sedang berada di jalur.'
        : isSelesai
            ? 'Pendakian dan check-out telah selesai. Tiket ini sudah tidak berlaku lagi.'
            : isDitolak
                ? 'Pengajuan izin pendakian ditolak oleh pihak pengelola.'
                : 'QR Code telah dinonaktifkan.';

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryColor, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isDiJalur ? const Color(0xFF1E3A2F) : primaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDiJalur ? Icons.hiking_rounded : Icons.check_circle_outline,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Status: ${widget.permit.statusIzin}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrDialog(BuildContext context) {
    if (!_isQrActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'QR Code sekali pakai ini sudah tervalidasi dan hangus (Status: ${widget.permit.statusIzin}).',
          ),
          backgroundColor: AppTheme.cardDark,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_2, color: AppTheme.secondary, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'QR Tiket Simaksi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: widget.permit.blockHash,
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.permit.namaGunung ?? 'Gunung',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Jam Check-in: ${TimeZoneHelper.convertTimeRange('07:00 - 16:00', _nativeZone, _selectedZone)} $_selectedZone\n(QR Code ini hanya berlaku sekali di pos basecamp)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMembersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups, color: AppTheme.secondary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anggota Rombongan (${widget.permit.jumlahAnggota} Orang)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 350),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.permit.members.length,
                  itemBuilder: (context, i) {
                    final m = widget.permit.members[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: m.isKetua
                              ? AppTheme.primary.withValues(alpha: 0.4)
                              : AppTheme.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                m.isKetua ? Icons.star_rounded : Icons.person_outline_rounded,
                                size: 16,
                                color: m.isKetua ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  m.nama,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                ),
                              ),
                              if (m.isKetua)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primarySubtle,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD4E0D2)),
                                  ),
                                  child: const Text('Ketua', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.home_outlined, size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  m.alamat,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: AppTheme.secondary),
                              const SizedBox(width: 6),
                              Text(
                                'Darurat: ${m.kontakDarurat}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.secondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
