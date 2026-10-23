// ============================================
// TimurLang - Universal AI Assistant Screen
// Multi-topic intelligent chatbot with quick suggestions & API configuration
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

  final List<String> _quickSuggestions = [
    'Rekomendasi Gunung Pemula',
    'Tips Packing & Perlengkapan',
    'Fenomena Cuaca di Gunung',
    'Panduan Latihan Fisik',
    'Cara Booking Simaksi',
    'Tebak-tebakan Santai',
    'Etika Leave No Trace',
    'Panduan P3K Lapangan',
  ];

  @override
  void initState() {
    super.initState();
    _checkConnection();
    GeminiService.instance.initialize().then((_) {
      if (mounted) setState(() {});
    });
    if (GeminiService.instance.history.isEmpty) {
      GeminiService.instance.addGreeting();
    }
  }

  Future<void> _checkConnection() async {
    final online = await SyncService.instance.hasConnection();
    if (mounted) setState(() => _isOnline = online);
  }

  Future<void> _sendMessage([String? textToSend]) async {
    final text = textToSend ?? _textCtrl.text.trim();
    if (text.isEmpty) return;

    if (textToSend == null) {
      _textCtrl.clear();
    }
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
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo_timurlang.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tbot AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Asisten Cerdas TimurLang',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
            tooltip: 'Bersihkan Riwayat',
            onPressed: () {
              setState(() {
                GeminiService.instance.clearHistory();
                GeminiService.instance.addGreeting();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppTheme.warning.withValues(alpha: 0.15),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 14, color: AppTheme.warning),
                  SizedBox(width: 6),
                  Text(
                    'Mode Luring: Menggunakan AI Offline Engine lokal.',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Chat Messages List
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border, width: 1),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo_timurlang.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tbot sedang mengetik...',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Quick Topic Suggestions Carousel
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickSuggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = _quickSuggestions[index];
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: AppTheme.surface,
                  side: const BorderSide(color: AppTheme.border),
                  elevation: 0,
                  pressElevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                  onPressed: _isTyping ? null : () => _sendMessage(suggestion),
                );
              },
            ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Tanyakan apa saja ke Tbot...',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceSubtle,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _isTyping ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(ChatMessage msg) {
    final bubbleContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * (msg.isUser ? 0.84 : 0.78),
      ),
      decoration: BoxDecoration(
        color: msg.isUser ? AppTheme.primary : AppTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
          bottomRight: Radius.circular(msg.isUser ? 4 : 18),
        ),
        border: Border.all(
          color: msg.isUser ? AppTheme.primary : AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: msg.isUser ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFormattedMessage(msg.text, msg.isUser),
          if (!msg.isUser) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  msg.isFromCloud ? Icons.auto_awesome : Icons.offline_bolt_outlined,
                  size: 12,
                  color: msg.isFromCloud ? AppTheme.primary : AppTheme.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  msg.isFromCloud ? 'Gemini Cloud AI' : 'Offline Engine',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: msg.isFromCloud ? AppTheme.primary : AppTheme.warning,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: bubbleContent,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo_timurlang.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Flexible(child: bubbleContent),
        ],
      ),
    );
  }

  Widget _buildFormattedMessage(String rawText, bool isUser) {
    if (isUser) {
      return SelectableText(
        rawText,
        style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.white),
      );
    }

    final lines = rawText.split('\n');
    final List<Widget> widgets = [];
    final headerColor = isUser ? Colors.white : AppTheme.textPrimary;
    final defaultTextColor = isUser ? Colors.white.withValues(alpha: 0.95) : AppTheme.textPrimary;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      final trimmed = line.trim();

      // Baris kosong antar paragraf
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Format Header (#, ##, ###)
      if (trimmed.startsWith('### ')) {
        final title = trimmed.substring(4).replaceAll('**', '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: SelectableText(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: headerColor,
              height: 1.3,
            ),
          ),
        ));
        continue;
      } else if (trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        final title = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').replaceAll('**', '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 3),
          child: SelectableText(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: headerColor,
              height: 1.3,
            ),
          ),
        ));
        continue;
      }

      // Format Bullet List (- atau *)
      bool isBullet = false;
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        line = '•  ${trimmed.substring(2)}';
        isBullet = true;
      }

      // Parse inline **bold**, *italic*, `code`
      final spans = _parseInlineSpans(line, isUser);

      widgets.add(Padding(
        padding: EdgeInsets.only(
          left: isBullet ? 4.0 : 0.0,
          bottom: 2.0,
        ),
        child: SelectableText.rich(
          TextSpan(children: spans),
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: defaultTextColor,
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  List<InlineSpan> _parseInlineSpans(String line, bool isUser) {
    final List<InlineSpan> spans = [];
    final pattern = RegExp(r'(\*\*[^*]+?\*\*|\*[^*]+?\*|`[^`]+?`)');
    int lastEnd = 0;

    final normalColor = isUser ? Colors.white70 : AppTheme.textPrimary;
    final boldColor = isUser ? Colors.white : AppTheme.textPrimary;
    final italicColor = isUser ? Colors.white70 : AppTheme.textSecondary;

    for (final match in pattern.allMatches(line)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: line.substring(lastEnd, match.start),
          style: TextStyle(color: normalColor),
        ));
      }

      final text = match.group(0)!;
      // Bold **teks**
      if (text.startsWith('**') && text.endsWith('**') && text.length >= 4) {
        final inner = text.substring(2, text.length - 2);
        spans.add(TextSpan(
          text: inner,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: boldColor,
          ),
        ));
      }
      // Italic *teks*
      else if (text.startsWith('*') && text.endsWith('*') && text.length >= 2) {
        final inner = text.substring(1, text.length - 1);
        spans.add(TextSpan(
          text: inner,
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: italicColor,
          ),
        ));
      }
      // Inline `code`
      else if (text.startsWith('`') && text.endsWith('`') && text.length >= 2) {
        final inner = text.substring(1, text.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isUser
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isUser
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppTheme.border,
              ),
            ),
            child: Text(
              inner,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isUser ? Colors.amberAccent : AppTheme.primary,
              ),
            ),
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastEnd),
        style: TextStyle(color: normalColor),
      ));
    }

    return spans;
  }
}
