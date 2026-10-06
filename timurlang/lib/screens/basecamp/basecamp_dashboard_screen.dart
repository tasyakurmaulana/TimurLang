// ============================================
// TimurLang - Basecamp Dashboard Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';

class BasecampDashboardScreen extends StatefulWidget {
  const BasecampDashboardScreen({super.key});

  @override
  State<BasecampDashboardScreen> createState() => _BasecampDashboardScreenState();
}

class _BasecampDashboardScreenState extends State<BasecampDashboardScreen> {
  int _activeSOS = 0;
  int _activeHikers = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sos = await DatabaseService.instance.getActiveSOSIncidents();
    final permits = await DatabaseService.instance.getActivePermits();
    
    if (mounted) {
      setState(() {
        _activeSOS = sos.length;
        _activeHikers = permits.where((p) => p.statusIzin == 'Di Jalur').length;
      });
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Basecamp?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Basecamp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final res = await SyncService.instance.syncAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Petugas: ${user?.namaLengkap}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // SOS Alert Banner
              if (_activeSOS > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.dangerGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DARURAT AKTIF!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('$_activeSOS sinyal SOS membutuhkan penanganan.'),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // In a real app, this would go to a specific SOS handling screen
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menuju layar penanganan SOS')));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.dangerRed,
                        ),
                        child: const Text('Tindak'),
                      ),
                    ],
                  ),
                ),

              // Stat Cards
              Row(
                children: [
                  Expanded(
                    child: _statCard('Pendaki di Jalur', _activeHikers.toString(), Icons.hiking, AppTheme.skyBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _statCard('Sinyal SOS', _activeSOS.toString(), Icons.sos, AppTheme.dangerRed),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Actions
              const Text('Operasional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              _actionCard(
                'Verifikasi Tiket Simaksi',
                'Pindai atau masukkan hash tiket pendaki',
                Icons.qr_code_scanner,
                AppTheme.primaryGreen,
                () => Navigator.pushNamed(context, AppRoutes.ticketVerify).then((_) => _loadData()),
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Monitor Pendaki di Jalur',
                'Pantau status pendaki yang sedang beraktivitas',
                Icons.radar,
                AppTheme.accentOrange,
                () => Navigator.pushNamed(context, AppRoutes.hikerMonitor).then((_) => _loadData()),
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Update Status Jalur',
                'Ubah status Buka/Tutup/Waspada',
                Icons.edit_road,
                AppTheme.mistGrey,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur update status jalur akan datang')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _actionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
