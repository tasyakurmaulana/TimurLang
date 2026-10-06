// ============================================
// TimurLang - Survival Assistant (Gemini AI)
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/gemini_service.dart';
import '../../services/sync_service.dart';

class SurvivalAssistantScreen extends StatefulWidget {
  const SurvivalAssistantScreen({super.key});

  @override
  State<SurvivalAssistantScreen> createState() => _SurvivalAssistantScreenState();
}

class _SurvivalAssistantScreenState extends State<SurvivalAssistantScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    if (GeminiService.instance.history.isEmpty) {
      _sendInitialGreeting();
    }
  }

  Future<void> _checkConnection() async {
    final online = await SyncService.instance.hasConnection();
    if (mounted) setState(() => _isOnline = online);
  }

  Future<void> _sendInitialGreeting() async {
    await GeminiService.instance.sendMessage('halo');
    if (mounted) setState(() {});
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || !_isOnline) return;

    _textCtrl.clear();
    setState(() => _isTyping = true);

    await GeminiService.instance.sendMessage(text);

    if (mounted) {
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = GeminiService.instance.history;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: AppTheme.primaryGreen),
            SizedBox(width: 10),
            Text('Survival Assistant'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              GeminiService.instance.clearHistory();
              _sendInitialGreeting();
            },
          )
        ],
      ),
      body: Column(
        children: [
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: AppTheme.dangerRed,
              child: const Text(
                'Koneksi terputus. AI membutuhkan internet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                return _chatBubble(msg);
              },
            ),
          ),
          
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('AI sedang mengetik...', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    enabled: _isOnline,
                    decoration: InputDecoration(
                      hintText: 'Tanyakan panduan P3K, navigasi...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isOnline ? _sendMessage : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? AppTheme.primaryGreen : AppTheme.cardDarkElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 0),
            bottomRight: Radius.circular(msg.isUser ? 0 : 16),
          ),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
      ),
    );
  }
}
