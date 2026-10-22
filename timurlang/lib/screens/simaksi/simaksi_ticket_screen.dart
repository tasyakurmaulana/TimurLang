// ============================================
// TimurLang - Simaksi Tickets Screen
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/simaksi_permit.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/ticket_card.dart';

class SimaksiTicketScreen extends StatefulWidget {
  const SimaksiTicketScreen({super.key});

  @override
  State<SimaksiTicketScreen> createState() => _SimaksiTicketScreenState();
}

class _SimaksiTicketScreenState extends State<SimaksiTicketScreen> {
  List<SimaksiPermit> _permits = [];
  bool _isLoading = true;
  Timer? _autoRefreshTimer;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tiket Simaksi Saya')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTickets,
              child: _permits.isEmpty
                  ? Center(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 80, color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 16),
                              Text('Belum ada tiket.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                            ],
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _permits.length,
                      itemBuilder: (context, i) {
                        return TicketCard(permit: _permits[i]);
                      },
                    ),
            ),
    );
  }
}
