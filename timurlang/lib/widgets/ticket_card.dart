// ============================================
// TimurLang - Ticket Card Widget
// Boarding pass with interactive WIB, WITA, WIT time zone converter
// ============================================

import 'dart:convert';
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
  final VoidCallback? onStatusChanged;
  final bool initiallyExpanded;

  const TicketCard({
    super.key,
    required this.permit,
    this.onTap,
    this.onStatusChanged,
    this.initiallyExpanded = true,
  });

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  late String _nativeZone;
  late String _selectedZone;
  late bool _isExpanded;
  String? _resolvedBasecampName;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
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

      // 3. Fallback jika basecampId tidak terhubung langsung, cek dari gunungId
      if (widget.permit.gunungId.isNotEmpty) {
        final bcs = await DatabaseService.instance.getRegisteredBasecampsByMountain(widget.permit.gunungId);
        if (bcs.isNotEmpty && mounted) {
          // Jika untuk Gunung Merbabu (mtn-014), gunakan jalur Selo Boyolali sebagai basecamp utama yang dipilih pendaki
          if (widget.permit.gunungId == 'mtn-014' ||
              (widget.permit.namaGunung?.toLowerCase().contains('merbabu') ?? false)) {
            final selo = bcs.firstWhere(
              (b) => b.namaPos.toLowerCase().contains('selo'),
              orElse: () => bcs.first,
            );
            setState(() {
              _resolvedBasecampName = selo.namaPos;
            });
            return;
          }
          if (bcs.length == 1) {
            setState(() {
              _resolvedBasecampName = bcs.first.namaPos;
            });
            return;
          }
        }
      }
    } catch (_) {}
  }

  /// QR hanya aktif saat tiket baru terdaftar / diajukan atau telah di-reschedule.
  /// Setelah di-scan dan divalidasi oleh Basecamp (Di Jalur, Selesai, Ditolak, Dibatalkan),
  /// QR code otomatis hangus / nonaktif (single-use).
  bool get _isQrActive =>
      widget.permit.statusIzin == AppConstants.statusTerdaftar ||
      widget.permit.statusIzin == AppConstants.statusDiajukan ||
      widget.permit.statusIzin == AppConstants.statusRescheduled;

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
      case AppConstants.statusDibatalkanPendaki:
      case AppConstants.statusDibatalkan:
        return AppTheme.dangerRed;
      case AppConstants.statusDibatalkanBasecamp:
        return const Color(0xFFF59E0B);
      case AppConstants.statusRescheduled:
        return const Color(0xFF0D9488);
      case AppConstants.statusRefundDiajukan:
        return const Color(0xFFEA580C);
      case AppConstants.statusRefundSelesai:
        return AppTheme.safeGreen;
      default:
        return AppTheme.warningYellow;
    }
  }

  String _getDisplayBadgeStatus(String status) {
    if (status == AppConstants.statusDibatalkanPendaki) {
      return 'Dibatalkan';
    }
    if (status == AppConstants.statusDibatalkanBasecamp) {
      return 'Batal Resmi';
    }
    return status;
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
            // Upper Dark Green Status Zone (Overflow-Safe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.primary,
              child: Row(
                children: [
                  const Icon(Icons.confirmation_num_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'BOARDING PASS / SIMAKSI',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                    ),
                    child: Text(
                      _getDisplayBadgeStatus(widget.permit.statusIzin),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
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
                  // Banner Resmi Basecamp (Refund 100% atau Reschedule)
                  if (widget.permit.isOfficialCancellation)
                    _buildOfficialCancellationBanner(context),

                  // Banner Pengajuan Refund Sedang Diproses
                  if (widget.permit.isRefundRequested)
                    _buildRefundRequestedBanner(context),

                  // Banner Refund 100% Selesai Ditransfer
                  if (widget.permit.isRefundCompleted)
                    _buildRefundCompletedBanner(context),

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
                                _resolvedBasecampName ??
                                    ((widget.permit.namaBasecamp != null &&
                                            widget.permit.namaBasecamp != 'Pos Basecamp Resmi' &&
                                            widget.permit.namaBasecamp!.isNotEmpty)
                                        ? widget.permit.namaBasecamp!
                                        : (widget.permit.gunungId == 'mtn-014' ||
                                                (widget.permit.namaGunung?.toLowerCase().contains('merbabu') ?? false)
                                            ? 'Selo Boyolali'
                                            : 'Pos Basecamp Resmi')),
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
                          if (widget.permit.isCancellableByUser) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _showVoluntaryCancelDialog(context),
                                icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.dangerRed),
                                label: Text(
                                  'Batalkan Tiket',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.dangerRed,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppTheme.dangerRed.withValues(alpha: 0.45), width: 1.2),
                                  backgroundColor: AppTheme.dangerRed.withValues(alpha: 0.06),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final isBatalPendaki = widget.permit.statusIzin == AppConstants.statusDibatalkanPendaki ||
        widget.permit.opsiPembatalan == 'cancelled_no_refund';
    final isBatalBasecamp = widget.permit.isOfficialCancellation;
    final isRefundRequested = widget.permit.isRefundRequested;
    final isRefundSelesai = widget.permit.isRefundCompleted;

    final Color primaryColor = isDiJalur
        ? AppTheme.safeGreen
        : isSelesai
            ? AppTheme.mistGrey
            : (isDitolak || isBatalPendaki)
                ? AppTheme.dangerRed
                : (isBatalBasecamp || isRefundRequested)
                    ? const Color(0xFFF59E0B)
                    : isRefundSelesai
                        ? AppTheme.safeGreen
                        : AppTheme.warningYellow;

    final IconData icon = isDiJalur
        ? Icons.verified
        : isSelesai
            ? Icons.task_alt
            : isBatalPendaki
                ? Icons.cancel_presentation_rounded
                : isBatalBasecamp
                    ? Icons.campaign_rounded
                    : isRefundRequested
                        ? Icons.pending_actions_rounded
                        : isRefundSelesai
                            ? Icons.price_check_rounded
                            : isDitolak
                                ? Icons.cancel_outlined
                                : Icons.info_outline;

    final String title = isDiJalur
        ? 'QR SEKALI PAKAI TELAH DIGUNAKAN'
        : isSelesai
            ? 'PENDAKIAN TELAH SELESAI'
            : isBatalPendaki
                ? 'TIKET DIBATALKAN (NON-REFUNDABLE)'
                : isBatalBasecamp
                    ? 'PEMBATALAN RESMI PENGELOLA BASECAMP'
                    : isRefundRequested
                        ? 'PENGAJUAN REFUND SEDANG DIPROSES'
                        : isRefundSelesai
                            ? 'REFUND 100% TELAH DITRANSFER'
                            : isDitolak
                                ? 'TIKET DITOLAK'
                                : 'QR CODE SUDAH TIDAK AKTIF';

    final String subtitle = isDiJalur
        ? 'Tiket telah berhasil divalidasi oleh petugas Basecamp. Pendaki resmi terdaftar & sedang berada di jalur.'
        : isSelesai
            ? 'Pendakian dan check-out telah selesai. Tiket ini sudah tidak berlaku lagi.'
            : isBatalPendaki
                ? 'Tiket dibatalkan atas inisiatif pendaki. Sesuai regulasi resmi pengelola, pembatalan mandiri bersifat Non-Refundable (dana hangus).'
                : isBatalBasecamp
                    ? 'Jalur ditutup resmi oleh basecamp: ${widget.permit.alasanPembatalan ?? "Kebijakan pengelola"}. Silakan pilih Refund 100% atau Reschedule di bagian atas tiket.'
                    : isRefundRequested
                        ? 'Pengembalian dana 100% sebesar Rp ${(widget.permit.totalBiaya ?? 0).toInt()} sedang dalam proses transfer oleh pengelola basecamp.'
                        : isRefundSelesai
                            ? 'Pengembalian dana 100% sebesar Rp ${(widget.permit.totalBiaya ?? 0).toInt()} telah selesai diproses oleh pihak basecamp.'
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
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ── BANNER PEMBATALAN RESMI BASECAMP (OPSI REFUND ATAU RESCHEDULE) ──
  Widget _buildOfficialCancellationBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            blurRadius: 8,
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
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PEMBATALAN RESMI BASECAMP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      'Kebijakan Resmi Pengelola Basecamp',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.permit.alasanPembatalan ?? 'Penutupan jalur resmi akibat kondisi cuaca / force majeure dari pihak pengelola basecamp.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF78350F),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Berdasarkan regulasi resmi, Anda berhak memilih untuk mendapatkan Refund Penuh (100%) atau Reschedule (Ubah Jadwal Pendakian):',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: const Color(0xFF92400E),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRefundDialog(context),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: Text(
                    'Refund 100%',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRescheduleDialog(context),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                  label: Text(
                    'Reschedule',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── BANNER PENGAJUAN REFUND SEDANG DIPROSES ──
  Widget _buildRefundRequestedBanner(BuildContext context) {
    Map<String, dynamic>? refundInfo;
    if (widget.permit.rekeningRefund != null && widget.permit.rekeningRefund!.isNotEmpty) {
      try {
        refundInfo = jsonDecode(widget.permit.rekeningRefund!);
      } catch (_) {}
    }

    final provider = refundInfo?['provider'] ?? '';
    final nomor = refundInfo?['nomor'] ?? '';
    final nama = refundInfo?['nama'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFB923C), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFEA580C), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PENGAJUAN REFUND 100% SEDANG DIPROSES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pengembalian dana Rp ${(widget.permit.totalBiaya ?? 0).toInt()} sedang diproses transfer oleh basecamp${provider.isNotEmpty ? " ke rekening $provider $nomor (a.n $nama)" : ""}.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF7C2D12),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BANNER REFUND 100% SELESAI ──
  Widget _buildRefundCompletedBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REFUND 100% TELAH SELESAI DITRANSFER',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pengembalian dana Rp ${(widget.permit.totalBiaya ?? 0).toInt()} telah selesai ditransfer oleh pihak pengelola basecamp.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF14532D),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── DIALOG PEMBATALAN SUKARELA OLEH PENDAKI (NON-REFUNDABLE) ──
  void _showVoluntaryCancelDialog(BuildContext context) {
    String selectedReason = 'Kondisi fisik kurang fit / sakit';
    final otherCtrl = TextEditingController();
    bool isAgreed = false;
    bool isSubmitting = false;

    final reasons = [
      'Kondisi fisik kurang fit / sakit',
      'Ada keperluan / urusan keluarga mendadak',
      'Perubahan rencana rombongan pendakian',
      'Kekhawatiran terhadap kondisi cuaca',
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
                            color: AppTheme.dangerRed.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cancel_outlined, color: AppTheme.dangerRed, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Batalkan Tiket SIMAKSI',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                widget.permit.namaGunung ?? 'Gunung',
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
                    const Divider(height: 24, color: AppTheme.border),

                    // Kotak Peringatan Regulasi Non-Refundable
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Text(
                                'Kebijakan Resmi: Non-Refundable',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Pembatalan atas inisiatif pendaki sendiri TIDAK DAPAT DI-REFUND (dana tiket hangus).\n• Pengembalian dana hanya diberikan jika ada pembatalan resmi oleh pihak pengelola basecamp (misal: penutupan jalur akibat erupsi atau cuaca ekstrem).\n• Tiket Anda akan dibatalkan dan kuota akan dilepaskan kembali ke basecamp untuk pendaki lain.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: const Color(0xFF7F1D1D),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Pilih Alasan Pembatalan:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...reasons.map((r) {
                      final isSelected = selectedReason == r;
                      return InkWell(
                        onTap: () => setModalState(() => selectedReason = r),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
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
                          hintText: 'Tuliskan alasan Anda...',
                          filled: true,
                          fillColor: AppTheme.surfaceSubtle,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Checkbox konfirmasi
                    InkWell(
                      onTap: () => setModalState(() => isAgreed = !isAgreed),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isAgreed,
                            activeColor: AppTheme.dangerRed,
                            onChanged: (v) => setModalState(() => isAgreed = v ?? false),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Saya memahami dan menyetujui bahwa dana tiket ini tidak dapat dikembalikan (Non-Refundable).',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              'Kembali',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (!isAgreed || isSubmitting)
                                ? null
                                : () async {
                                    setModalState(() => isSubmitting = true);
                                    final finalReason = selectedReason == 'Lainnya' && otherCtrl.text.trim().isNotEmpty
                                        ? otherCtrl.text.trim()
                                        : selectedReason;

                                    final res = await BlockchainService.instance.cancelPermitByUser(
                                      permitId: widget.permit.id,
                                      reason: finalReason,
                                    );

                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            res.message,
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          backgroundColor: res.success ? const Color(0xFF1E293B) : AppTheme.dangerRed,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                      widget.onStatusChanged?.call();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.dangerRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Batalkan Tiket',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
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

  // ── DIALOG PENGAJUAN REFUND 100% ──
  void _showRefundDialog(BuildContext context) {
    String selectedProvider = 'BCA';
    final accountNumCtrl = TextEditingController();
    final accountNameCtrl = TextEditingController();
    bool isSubmitting = false;

    final providers = [
      'BCA',
      'Mandiri',
      'BRI',
      'BNI',
      'BSI',
      'Bank Jateng',
      'Bank Jatim',
      'GoPay',
      'OVO',
      'DANA',
      'ShopeePay',
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
                            color: const Color(0xFF15803D).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.payments_rounded, color: Color(0xFF15803D), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pengajuan Refund 100%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Kebijakan Resmi Pembatalan Basecamp',
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

                    // Ringkasan Pengembalian
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined, color: Color(0xFF16A34A), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Pengembalian Dana (100% Full Refund):',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF166534),
                                  ),
                                ),
                                Text(
                                  'Rp ${(widget.permit.totalBiaya ?? 0).toInt()}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Pilih Bank / E-Wallet:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedProvider,
                          isExpanded: true,
                          items: providers.map((p) {
                            return DropdownMenuItem<String>(
                              value: p,
                              child: Text(p, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => selectedProvider = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Nomor Rekening / Akun E-Wallet:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: accountNumCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Contoh: 1234567890',
                        filled: true,
                        fillColor: AppTheme.surfaceSubtle,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Nama Pemilik Rekening / Akun:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: accountNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Budi Santoso',
                        filled: true,
                        fillColor: AppTheme.surfaceSubtle,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final numStr = accountNumCtrl.text.trim();
                              final nameStr = accountNameCtrl.text.trim();
                              if (numStr.isEmpty || nameStr.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Harap lengkapi nomor dan nama pemilik rekening',
                                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: const Color(0xFFD97706),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final res = await BlockchainService.instance.requestRefund(
                                permitId: widget.permit.id,
                                bankOrWallet: selectedProvider,
                                accountNumber: numStr,
                                accountHolder: nameStr,
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res.message,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: res.success ? const Color(0xFF1E293B) : AppTheme.dangerRed,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                widget.onStatusChanged?.call();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
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
                              'Kirim Pengajuan Refund 100%',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
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

  // ── DIALOG RESCHEDULE (UBAH JADWAL) ──
  void _showRescheduleDialog(BuildContext context) {
    DateTime newTanggalNaik = widget.permit.tanggalNaik.isAfter(DateTime.now())
        ? widget.permit.tanggalNaik.add(const Duration(days: 7))
        : DateTime.now().add(const Duration(days: 3));
    DateTime newTanggalTurun = newTanggalNaik.add(const Duration(days: 1));
    bool isSubmitting = false;

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
                            color: AppTheme.primarySubtle,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_calendar_rounded, color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reschedule Tanggal Pendakian',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Pilih jadwal baru tanpa biaya tambahan',
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
                      'Pilih Tanggal Naik Baru:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: newTanggalNaik,
                          firstDate: DateTime.now().add(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 180)),
                        );
                        if (picked != null) {
                          setModalState(() {
                            newTanggalNaik = picked;
                            if (newTanggalTurun.isBefore(newTanggalNaik)) {
                              newTanggalTurun = newTanggalNaik.add(const Duration(days: 1));
                            }
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
                            const SizedBox(width: 10),
                            Text(
                              AppDateUtils.formatDateIndonesian(newTanggalNaik),
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Pilih Tanggal Turun Baru:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: newTanggalTurun,
                          firstDate: newTanggalNaik,
                          lastDate: newTanggalNaik.add(const Duration(days: 14)),
                        );
                        if (picked != null) {
                          setModalState(() => newTanggalTurun = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_available_rounded, size: 18, color: AppTheme.secondary),
                            const SizedBox(width: 10),
                            Text(
                              AppDateUtils.formatDateIndonesian(newTanggalTurun),
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final res = await BlockchainService.instance.reschedulePermit(
                                permitId: widget.permit.id,
                                newTanggalNaik: newTanggalNaik,
                                newTanggalTurun: newTanggalTurun,
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res.message,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: res.success ? const Color(0xFF1E293B) : AppTheme.dangerRed,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                widget.onStatusChanged?.call();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
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
                              'Konfirmasi Jadwal Baru',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
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
}
