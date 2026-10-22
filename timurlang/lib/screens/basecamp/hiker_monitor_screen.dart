// ============================================
// TimurLang - Hiker Monitor Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/simaksi_permit.dart';
import '../../services/auth_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';

class HikerMonitorScreen extends StatefulWidget {
  const HikerMonitorScreen({super.key});

  @override
  State<HikerMonitorScreen> createState() => _HikerMonitorScreenState();
}

class _HikerMonitorScreenState extends State<HikerMonitorScreen> {
  List<SimaksiPermit> _activeHikers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Tarik permit terbaru dari server Supabase jika online
    if (SupabaseService.instance.isInitialized) {
      try {
        final remotePermits = await SupabaseService.instance.getAllPermits();
        for (final p in remotePermits) {
          await DatabaseService.instance.insertPermit(p);
        }
      } catch (_) {}
    }

    final user = AuthService.instance.currentUser;
    if (user != null) {
      final post = await DatabaseService.instance.getBasecampByUserId(user.id);
      final gunungId = user.gunungId ?? post?.gunungId;
      if (gunungId != null) {
        final permits = await DatabaseService.instance.getActivePermitsForBasecamp(
          gunungId: gunungId,
          basecampId: post?.id,
        );
        if (mounted) {
          setState(() {
            _activeHikers = permits;
            _isLoading = false;
          });
        }
        return;
      }
    }

    final permits = await DatabaseService.instance.getActivePermits();
    if (mounted) {
      setState(() {
        _activeHikers = permits.where((p) => p.statusIzin == 'Di Jalur').toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _processCheckOut(String hash) async {
    final res = await BlockchainService.instance.checkOutPermit(hash);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: res.success ? AppTheme.safeGreen : AppTheme.dangerRed),
      );
      if (res.success) {
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalPeople = _activeHikers.fold<int>(0, (sum, p) => sum + p.jumlahAnggota);

    return Scaffold(
      appBar: AppBar(title: const Text('Monitor Pendaki')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeHikers.isEmpty
              ? const Center(child: Text('Tidak ada rombongan di jalur saat ini.'))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.skyBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.groups_outlined, color: AppTheme.skyBlue, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total: $totalPeople Orang di Jalur',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                ),
                                Text(
                                  'Dari ${_activeHikers.length} rombongan pendaki aktif',
                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _activeHikers.length,
                        itemBuilder: (context, i) {
                          final p = _activeHikers[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hiking, color: AppTheme.accentOrange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ID User: ${p.userId.substring(0, 8)}...',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentOrange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Di Jalur', style: TextStyle(color: AppTheme.accentOrange, fontSize: 10)),
                              ),
                            ],
                          ),
                          const Divider(),
                          Text('Gunung: ${p.namaGunung ?? p.gunungId}'),
                          Text('Rombongan: ${p.jumlahAnggota} orang'),
                          Text('Tanggal Naik: ${p.tanggalNaik.toString().substring(0, 10)}'),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _processCheckOut(p.blockHash),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.safeGreen),
                              child: const Text('Konfirmasi Check-out (Turun)'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}
