// ============================================
// TimurLang - Simaksi Tickets Screen
// ============================================

import 'package:flutter/material.dart';
import '../../models/simaksi_permit.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/ticket_card.dart';

class SimaksiTicketScreen extends StatefulWidget {
  const SimaksiTicketScreen({super.key});

  @override
  State<SimaksiTicketScreen> createState() => _SimaksiTicketScreenState();
}

class _SimaksiTicketScreenState extends State<SimaksiTicketScreen> {
  List<SimaksiPermit> _permits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      final permits = await DatabaseService.instance.getPermitsByUser(user.id);
      setState(() {
        _permits = permits;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tiket Simaksi Saya')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _permits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 80, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text('Belum ada tiket.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
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
    );
  }
}
