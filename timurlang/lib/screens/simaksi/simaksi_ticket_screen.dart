// ============================================
// TimurLang - Simaksi Tickets Screen
// Aura Travel Design System
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../models/simaksi_permit.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/ticket_card.dart';

class SimaksiTicketScreen extends StatefulWidget {
  final bool embedded;
  const SimaksiTicketScreen({super.key, this.embedded = false});

  @override
  State<SimaksiTicketScreen> createState() => _SimaksiTicketScreenState();
}

class _SimaksiTicketScreenState extends State<SimaksiTicketScreen> {
  List<SimaksiPermit> _permits = [];
  bool _isLoading = true;
  Timer? _autoRefreshTimer;
  String _selectedFilter = 'Semua'; // 'Semua', 'Terdaftar', 'Di Jalur', 'Selesai'

  @override
  void initState() {
    super.initState();
    _loadTickets();
    // Auto refresh setiap 3 detik agar saat Basecamp memindai QR,
    // status tiket otomatis terupdate dan QR code langsung hilang di layar pendaki!
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadTickets(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTickets({bool silent = false}) async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      // Tarik permit terbaru dari Supabase jika online
      if (SupabaseService.instance.isInitialized) {
        try {
          final remotePermits = await SupabaseService.instance.getPermitsByUser(user.id);
          for (final p in remotePermits) {
            await DatabaseService.instance.insertPermit(p);
          }
        } catch (_) {}
      }

      final permits = await DatabaseService.instance.getPermitsByUser(user.id);
      if (mounted) {
        setState(() {
          _permits = permits;
          if (!silent) _isLoading = false;
        });
      }
    } else {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  List<SimaksiPermit> get _filteredPermits {
    if (_selectedFilter == 'Terdaftar') {
      return _permits.where((p) {
        final status = p.statusIzin;
        return (status == AppConstants.statusTerdaftar ||
                status == AppConstants.statusDiajukan ||
                status == AppConstants.statusTervalidasi ||
                status == AppConstants.statusRescheduled ||
                status.toLowerCase().contains('daftar')) &&
            !p.isCancelled &&
            !p.isOfficialCancellation &&
            !p.isRefundRequested;
      }).toList();
    } else if (_selectedFilter == 'Di Jalur') {
      return _permits.where((p) => p.statusIzin == AppConstants.statusDiJalur).toList();
    } else if (_selectedFilter == 'Selesai') {
      return _permits.where((p) => p.statusIzin == AppConstants.statusSelesai).toList();
    } else if (_selectedFilter == 'Dibatalkan') {
      return _permits.where((p) =>
        p.isCancelled ||
        p.isOfficialCancellation ||
        p.isRefundRequested ||
        p.isRefundCompleted
      ).toList();
    }
    return _permits;
  }

  int _countForFilter(String filter) {
    if (filter == 'Terdaftar') {
      return _permits.where((p) {
        final status = p.statusIzin;
        return (status == AppConstants.statusTerdaftar ||
                status == AppConstants.statusDiajukan ||
                status == AppConstants.statusTervalidasi ||
                status == AppConstants.statusRescheduled ||
                status.toLowerCase().contains('daftar')) &&
            !p.isCancelled &&
            !p.isOfficialCancellation &&
            !p.isRefundRequested;
      }).length;
    } else if (filter == 'Di Jalur') {
      return _permits.where((p) => p.statusIzin == AppConstants.statusDiJalur).length;
    } else if (filter == 'Selesai') {
      return _permits.where((p) => p.statusIzin == AppConstants.statusSelesai).length;
    } else if (filter == 'Dibatalkan') {
      return _permits.where((p) =>
        p.isCancelled ||
        p.isOfficialCancellation ||
        p.isRefundRequested ||
        p.isRefundCompleted
      ).length;
    }
    return _permits.length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPermits;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          'Tiket SIMAKSI',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: widget.embedded ? false : true,
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
              onRefresh: _loadTickets,
              child: Column(
                children: [
                  // Filter Bar (Semua, Terdaftar, Di Jalur, Selesai, Dibatalkan)
                  _buildFilterBar(),

                  // List of filtered tickets
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              return TicketCard(
                                permit: filtered[i],
                                onStatusChanged: () => _loadTickets(silent: false),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['Semua', 'Terdaftar', 'Di Jalur', 'Selesai', 'Dibatalkan'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            final count = _countForFilter(filter);

            Color badgeBg;
            Color badgeText;
            if (filter == 'Di Jalur') {
              badgeBg = isSelected ? Colors.white.withValues(alpha: 0.25) : AppTheme.secondary.withValues(alpha: 0.15);
              badgeText = isSelected ? Colors.white : AppTheme.secondary;
            } else if (filter == 'Selesai') {
              badgeBg = isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF94A3B8).withValues(alpha: 0.2);
              badgeText = isSelected ? Colors.white : const Color(0xFF64748B);
            } else if (filter == 'Dibatalkan') {
              badgeBg = isSelected ? Colors.white.withValues(alpha: 0.25) : AppTheme.dangerRed.withValues(alpha: 0.15);
              badgeText = isSelected ? Colors.white : AppTheme.dangerRed;
            } else {
              badgeBg = isSelected ? Colors.white.withValues(alpha: 0.25) : AppTheme.primarySubtle;
              badgeText = isSelected ? Colors.white : AppTheme.primary;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedFilter = filter);
                },
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
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
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

  Widget _buildEmptyState() {
    IconData emptyIcon;
    String emptyTitle;
    String emptyDesc;

    if (_selectedFilter == 'Terdaftar') {
      emptyIcon = Icons.how_to_reg_outlined;
      emptyTitle = 'Tidak Ada Tiket Terdaftar';
      emptyDesc = 'Tiket yang telah diajukan dan belum check-in di pos basecamp akan muncul di sini.';
    } else if (_selectedFilter == 'Di Jalur') {
      emptyIcon = Icons.hiking_rounded;
      emptyTitle = 'Tidak Ada Pendaki di Jalur';
      emptyDesc = 'Tiket yang telah diverifikasi oleh petugas pos dan sedang aktif mendaki akan muncul di sini.';
    } else if (_selectedFilter == 'Selesai') {
      emptyIcon = Icons.task_alt_rounded;
      emptyTitle = 'Belum Ada Riwayat Selesai';
      emptyDesc = 'Tiket pendakian yang telah check-out dari basecamp akan tersimpan di sini.';
    } else {
      emptyIcon = Icons.confirmation_num_outlined;
      emptyTitle = 'Belum Ada Tiket SIMAKSI';
      emptyDesc = 'Anda belum memiliki riwayat pengajuan izin pendakian.';
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySubtle,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border, width: 1.2),
                  ),
                  child: Icon(emptyIcon, size: 38, color: AppTheme.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  emptyTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  emptyDesc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_selectedFilter == 'Semua') ...[
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.mountainList);
                    },
                    icon: const Icon(Icons.terrain_rounded, size: 18),
                    label: Text(
                      'Jelajahi Gunung & Buat Izin',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
