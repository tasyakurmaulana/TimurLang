// ============================================
// TimurLang - Midtrans Payment Screen (WebView)
// ============================================

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/theme.dart';
import '../../services/midtrans_service.dart';

class MidtransPaymentScreen extends StatefulWidget {
  final String orderId;
  final String redirectUrl;
  final String mountainName;
  final int totalAmount;

  const MidtransPaymentScreen({
    super.key,
    required this.orderId,
    required this.redirectUrl,
    required this.mountainName,
    required this.totalAmount,
  });

  @override
  State<MidtransPaymentScreen> createState() => _MidtransPaymentScreenState();
}

class _MidtransPaymentScreenState extends State<MidtransPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _detectPaymentCallback(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _detectPaymentCallback(url);
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              _detectPaymentCallback(change.url!);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }

  void _detectPaymentCallback(String url) {
    final lower = url.toLowerCase();
    // Midtrans redirect URL indikator sukses
    if (lower.contains('#/success') ||
        lower.contains('status_code=200') ||
        lower.contains('transaction_status=settlement') ||
        lower.contains('transaction_status=capture') ||
        lower.contains('/finish')) {
      _checkPaymentStatus(silent: false);
    }
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (_isCheckingStatus) return;
    setState(() => _isCheckingStatus = true);

    final result = await MidtransService.instance.checkTransactionStatus(widget.orderId);

    if (!mounted) return;
    setState(() => _isCheckingStatus = false);

    if (result.isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran berhasil diverifikasi!'),
          backgroundColor: AppTheme.safeGreen,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } else {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.status == 'pending'
                ? AppTheme.accentOrange
                : AppTheme.dangerRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pembayaran?'),
        content: const Text(
          'Pembayaran belum diverifikasi. Apakah Anda yakin ingin kembali ke halaman sebelumnya?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tetap di Sini', style: TextStyle(color: AppTheme.primaryGreen)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave && context.mounted) {
          Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pembayaran Midtrans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                'Order ID: ${widget.orderId}',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat ulang',
              onPressed: () => _controller.reload(),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isLoading)
              LinearProgressIndicator(
                value: _loadingProgress > 0 ? _loadingProgress / 100 : null,
                color: AppTheme.primaryGreen,
                backgroundColor: AppTheme.cardDark,
                minHeight: 3,
              ),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                border: const Border(top: BorderSide(color: Colors.white10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Tagihan:',
                            style: TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                          Text(
                            'Rp ${widget.totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isCheckingStatus ? null : () => _checkPaymentStatus(silent: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isCheckingStatus
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(_isCheckingStatus ? 'Mengecek...' : 'Saya Sudah Bayar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
