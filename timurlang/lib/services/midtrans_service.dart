// ============================================
// TimurLang - Midtrans Service
// Snap Transaction & Payment Status Verification
// ============================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

class MidtransService {
  static final MidtransService instance = MidtransService._internal();
  MidtransService._internal();

  bool get isConfigured =>
      AppConstants.midtransServerKey.isNotEmpty &&
      AppConstants.midtransServerKey != 'SB-Mid-server-YOUR_SERVER_KEY_HERE';

  String _getAuthHeader() {
    final serverKey = AppConstants.midtransServerKey;
    final encodedKey = base64Encode(utf8.encode('$serverKey:'));
    return 'Basic $encodedKey';
  }

  /// Membuat transaksi Snap di Midtrans dan mengembalikan redirectUrl untuk WebView
  Future<({
    bool success,
    String? redirectUrl,
    String? token,
    String message,
    bool isConfigured,
  })> createSnapTransaction({
    required String orderId,
    required int grossAmount,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    required String itemName,
    required int itemPrice,
    required int quantity,
  }) async {
    if (!isConfigured) {
      return (
        success: false,
        redirectUrl: null,
        token: null,
        message: 'Midtrans Server Key belum diatur di lib/config/constants.dart',
        isConfigured: false,
      );
    }

    try {
      final url = Uri.parse(AppConstants.midtransSnapUrl);
      final body = {
        'transaction_details': {
          'order_id': orderId,
          'gross_amount': grossAmount,
        },
        'item_details': [
          {
            'id': 'simaksi-${DateTime.now().millisecondsSinceEpoch}',
            'price': itemPrice,
            'quantity': quantity,
            'name': itemName.length > 50 ? itemName.substring(0, 50) : itemName,
          }
        ],
        'customer_details': {
          'first_name': customerName,
          'email': customerEmail,
          if (customerPhone != null && customerPhone.isNotEmpty)
            'phone': customerPhone,
        },
        'credit_card': {
          'secure': true,
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _getAuthHeader(),
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final redirectUrl = data['redirect_url'] as String?;
        final token = data['token'] as String?;

        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          return (
            success: true,
            redirectUrl: redirectUrl,
            token: token,
            message: 'Transaksi berhasil dibuat',
            isConfigured: true,
          );
        }
      }

      final errorMessages = data['error_messages'] as List<dynamic>?;
      final errMsg = errorMessages != null && errorMessages.isNotEmpty
          ? errorMessages.join(', ')
          : (data['message'] ?? 'Gagal membuat transaksi di Midtrans (${response.statusCode})');

      return (
        success: false,
        redirectUrl: null,
        token: null,
        message: errMsg.toString(),
        isConfigured: true,
      );
    } catch (e) {
      debugPrint('Error Midtrans createSnapTransaction: $e');
      return (
        success: false,
        redirectUrl: null,
        token: null,
        message: 'Terjadi kesalahan koneksi Midtrans: ${e.toString()}',
        isConfigured: true,
      );
    }
  }

  /// Cek status transaksi langsung ke API Midtrans
  Future<({
    bool success,
    bool isPaid,
    String status,
    String message,
  })> checkTransactionStatus(String orderId) async {
    if (!isConfigured) {
      return (
        success: false,
        isPaid: false,
        status: 'unconfigured',
        message: 'Midtrans Server Key belum diatur',
      );
    }

    try {
      final url = Uri.parse('${AppConstants.midtransApiBaseUrl}/$orderId/status');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': _getAuthHeader(),
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final transactionStatus = (data['transaction_status'] as String?)?.toLowerCase() ?? '';
      final fraudStatus = (data['fraud_status'] as String?)?.toLowerCase();

      debugPrint('Midtrans status for $orderId: $transactionStatus (fraud: $fraudStatus)');

      // settlement = pembayaran lunas
      // capture = kartu kredit terverifikasi dan sukses
      if (transactionStatus == 'settlement' ||
          (transactionStatus == 'capture' && fraudStatus == 'accept')) {
        return (
          success: true,
          isPaid: true,
          status: transactionStatus,
          message: 'Pembayaran berhasil dikonfirmasi!',
        );
      } else if (transactionStatus == 'pending') {
        return (
          success: true,
          isPaid: false,
          status: 'pending',
          message: 'Pembayaran masih menunggu (belum selesai).',
        );
      } else if (transactionStatus == 'expire') {
        return (
          success: true,
          isPaid: false,
          status: 'expire',
          message: 'Waktu pembayaran telah kedaluwarsa.',
        );
      } else if (transactionStatus == 'cancel' || transactionStatus == 'deny') {
        return (
          success: true,
          isPaid: false,
          status: transactionStatus,
          message: 'Pembayaran dibatalkan atau ditolak.',
        );
      } else {
        return (
          success: false,
          isPaid: false,
          status: transactionStatus,
          message: data['status_message']?.toString() ?? 'Status pembayaran: $transactionStatus',
        );
      }
    } catch (e) {
      debugPrint('Error Midtrans checkTransactionStatus: $e');
      return (
        success: false,
        isPaid: false,
        status: 'error',
        message: 'Gagal mengecek status pembayaran: ${e.toString()}',
      );
    }
  }
}
