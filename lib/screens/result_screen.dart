import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../models/scan_result.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

// dart:io only on mobile — used for history image thumbnails
import 'result_screen_io.dart' if (dart.library.html) 'result_screen_web.dart';

class ResultScreen extends StatefulWidget {
  final XFile? imageFile;          // new scan
  final ScanResult? existingResult; // viewing from history
  const ResultScreen({super.key, this.imageFile, this.existingResult})
      : assert(imageFile != null || existingResult != null);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _questionCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = false;
  String? _answer;
  String? _error;
  int _remaining = -1;
  bool _byok = false;
  ScanResult? _savedResult;
  Uint8List? _imageBytes; // for Image.memory display

  final List<_ChatMessage> _chat = [];

  @override
  void initState() {
    super.initState();
    _loadImageBytes();
    if (widget.existingResult != null) {
      _answer = widget.existingResult!.answer;
      _byok = widget.existingResult!.byok;
      _chat.add(_ChatMessage(
        question: widget.existingResult!.question,
        answer: widget.existingResult!.answer,
      ));
    } else {
      _questionCtrl.text = 'What do you see? Describe in detail.';
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkKeyThenAnalyze());
    }
  }

  Future<void> _loadImageBytes() async {
    if (widget.imageFile != null) {
      final bytes = await widget.imageFile!.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    } else if (widget.existingResult != null) {
      // Load from path (mobile) or skip (web)
      final bytes = await loadBytesFromPath(widget.existingResult!.imagePath);
      if (mounted && bytes != null) setState(() => _imageBytes = bytes);
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkKeyThenAnalyze() async {
    final key = await AiService.getSavedApiKey();
    if (key == null || key.isEmpty) {
      setState(() { _error = 'no_key'; _loading = false; });
      return;
    }
    _analyze();
  }

  Future<void> _analyze({String? question}) async {
    final String q = question ??
        (_questionCtrl.text.trim().isEmpty
            ? 'What do you see? Describe in detail.'
            : _questionCtrl.text.trim());

    setState(() { _loading = true; _error = null; });

    try {
      final xfile = widget.imageFile;
      if (xfile == null) {
        setState(() { _error = 'No image available for follow-up from history.'; _loading = false; });
        return;
      }

      final result = await AiService.analyze(imageFile: xfile, question: q);

      setState(() {
        _answer = result.answer;
        _remaining = result.remaining;
        _byok = result.byok;
        _loading = false;
        _chat.add(_ChatMessage(question: q, answer: result.answer));
      });

      // Save to history on first analysis
      if (_savedResult == null && widget.existingResult == null) {
        _savedResult = ScanResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          imagePath: xfile.path,
          question: q,
          answer: result.answer,
          timestamp: DateTime.now(),
          byok: result.byok,
        );
        HistoryService.add(_savedResult!);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } on LimitReachedException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } on InvalidKeyException catch (e) {
      setState(() { _error = '🔑 ${e.message}'; _loading = false; });
    } on AiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() {
        _error = 'Request failed: $e\n\nCheck your API key in Settings.';
        _loading = false;
      });
    }
  }

  Future<void> _followUp() async {
    final q = _questionCtrl.text.trim();
    if (q.isEmpty) return;
    _questionCtrl.clear();
    await _analyze(question: q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(children: [
        _buildImageHeader(),
        Expanded(child: _buildContent()),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildImageHeader() => Stack(children: [
    // Image — cross-platform
    _imageBytes != null
      ? Image.memory(
          _imageBytes!,
          width: double.infinity,
          height: 260,
          fit: BoxFit.cover,
        )
      : Container(
          width: double.infinity,
          height: 260,
          color: AppTheme.surface2,
          child: const Center(
            child: Icon(Icons.image_rounded, color: AppTheme.faint, size: 64),
          ),
        ),
    // Gradient overlay
    Container(
      height: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppTheme.bg.withOpacity(0.9)],
          stops: const [0.5, 1.0],
        ),
      ),
    ),
    // Back button
    SafeArea(child: Padding(
      padding: const EdgeInsets.all(8),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
        onPressed: () => Get.back(),
      ),
    )),
    // Remaining badge
    if (_remaining >= 0)
      Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        right: 16,
        child: PillBadge(
          text: _byok ? '∞ BYOK' : '$_remaining/5 left',
          color: _byok ? AppTheme.good : (_remaining > 1 ? AppTheme.accent : AppTheme.amber),
        ),
      ),
  ]);

  Widget _buildContent() {
    if (_loading && _chat.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: AppTheme.primary),
        const SizedBox(height: 16),
        Text('Analyzing image...', style: AppTheme.body(14)),
      ]));
    }

    if (_error != null && _chat.isEmpty) {
      if (_error == 'no_key') {
        return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.vpn_key_rounded, color: AppTheme.accent, size: 56),
            const SizedBox(height: 20),
            Text('Add Your Groq API Key', style: AppTheme.display(18), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Go to Settings → paste your free Groq API key from console.groq.com\n\nIt\'s 100% free — no credit card needed.',
              style: AppTheme.body(14, h: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: AppTheme.accentButton(),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Open Settings'),
              onPressed: () async {
                await Get.to(() => const SettingsScreen());
                setState(() => _error = null);
                _checkKeyThenAnalyze();
              },
            ),
          ]),
        ));
      }
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
          const SizedBox(height: 16),
          Text(_error!, style: AppTheme.body(14, color: AppTheme.ink), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            style: AppTheme.primaryButton(),
            onPressed: _analyze,
            child: const Text('Retry'),
          ),
        ]),
      ));
    }

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: [
        ..._chat.map((msg) => _buildChatBubble(msg)),
        if (_loading) _buildThinking(),
        if (_error != null) _buildErrorBubble(_error!),
      ],
    );
  }

  Widget _buildChatBubble(_ChatMessage msg) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Text(msg.question, style: AppTheme.body(13, color: AppTheme.ink)),
        ),
      ),
      GlassCard(
        padding: const EdgeInsets.all(14),
        child: MarkdownBody(
          data: msg.answer,
          styleSheet: MarkdownStyleSheet(
            p: AppTheme.body(14, color: AppTheme.ink, h: 1.6),
            h1: AppTheme.display(18),
            h2: AppTheme.display(16),
            strong: AppTheme.body(14, w: FontWeight.w700, color: AppTheme.ink),
            code: AppTheme.body(13, color: AppTheme.accent),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ],
  ).animate().fadeIn(duration: 300.ms);

  Widget _buildThinking() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
      ),
      const SizedBox(width: 10),
      Text('Thinking...', style: AppTheme.body(13)),
    ]),
  );

  Widget _buildErrorBubble(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.danger.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
    ),
    child: Text(msg, style: AppTheme.body(13, color: AppTheme.danger)),
  );

  Widget _buildInputBar() => Container(
    padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border(top: BorderSide(color: AppTheme.hairline)),
    ),
    child: Row(children: [
      Expanded(
        child: TextField(
          controller: _questionCtrl,
          style: AppTheme.body(14, color: AppTheme.ink),
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Ask anything about this image…',
            hintStyle: AppTheme.body(14),
            filled: true,
            fillColor: AppTheme.glass,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primary),
            ),
          ),
          onSubmitted: (_) => _followUp(),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _loading ? null : _followUp,
        child: AnimatedContainer(
          duration: 200.ms,
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _loading
                ? [AppTheme.faint, AppTheme.faint]
                : [AppTheme.primary, AppTheme.accent],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: _loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}

class _ChatMessage {
  final String question;
  final String answer;
  const _ChatMessage({required this.question, required this.answer});
}
