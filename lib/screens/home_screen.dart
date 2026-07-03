import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../models/scan_result.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  List<ScanResult> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await HistoryService.load();
    if (mounted) setState(() { _history = h; _loadingHistory = false; });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (xfile == null) return;
      if (!mounted) return;
      await Get.to(
        () => ResultScreen(imageFile: xfile),
        transition: Transition.downToUp,
      );
      // History saved inside ResultScreen; just refresh on return
      _loadHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildHero(),
              _buildActions(),
              const SizedBox(height: 24),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
    child: Row(children: [
      // Logo
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.camera_enhance_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 10),
      Text('PhotoGPT', style: AppTheme.display(20)),
      const Spacer(),
      IconButton(
        onPressed: () => Get.to(() => const SettingsScreen(), transition: Transition.rightToLeft),
        icon: const Icon(Icons.settings_outlined, color: AppTheme.muted),
      ),
    ]),
  ).animate().fadeIn(duration: 400.ms);

  Widget _buildHero() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withOpacity(0.25), AppTheme.accent.withOpacity(0.1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PillBadge(text: 'AI Vision', color: AppTheme.accent, icon: Icons.auto_awesome),
          const SizedBox(height: 12),
          Text('Stop Googling.\nJust point your\ncamera.', style: AppTheme.display(22, h: 1.25)),
          const SizedBox(height: 8),
          Text(
            'AI answers everything — food, plants, medicine, math, text, products.',
            style: AppTheme.body(13, h: 1.5),
          ),
        ])),
        const SizedBox(width: 16),
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
          ),
          child: const Icon(Icons.camera_enhance_rounded, color: Colors.white, size: 34),
        ),
      ]),
    ),
  ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(begin: 0.05, end: 0);

  Widget _buildActions() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Row(children: [
      Expanded(child: _ActionButton(
        icon: Icons.camera_alt_rounded,
        label: 'Take Photo',
        color: AppTheme.primary,
        onTap: () => _pickImage(ImageSource.camera),
      )),
      const SizedBox(width: 12),
      Expanded(child: _ActionButton(
        icon: Icons.photo_library_rounded,
        label: 'Gallery',
        color: AppTheme.accent,
        onTap: () => _pickImage(ImageSource.gallery),
      )),
    ]),
  ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.05, end: 0);

  Widget _buildHistorySection() => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('Recent Scans', style: AppTheme.display(16)),
            const Spacer(),
            if (_history.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await HistoryService.clear();
                  _loadHistory();
                },
                child: Text('Clear', style: AppTheme.body(13, color: AppTheme.danger)),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(child: _loadingHistory
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _history.isEmpty
            ? _buildEmptyHistory()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _history.length,
                itemBuilder: (context, i) => _HistoryCard(
                  result: _history[i],
                  onDelete: () async {
                    await HistoryService.delete(_history[i].id);
                    _loadHistory();
                  },
                ).animate().fadeIn(delay: Duration(milliseconds: i * 40)),
              ),
        ),
      ],
    ),
  );

  Widget _buildEmptyHistory() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.photo_camera_outlined, size: 56, color: AppTheme.faint),
      const SizedBox(height: 16),
      Text('No scans yet', style: AppTheme.display(16, color: AppTheme.muted)),
      const SizedBox(height: 8),
      Text('Take a photo or pick from gallery', style: AppTheme.body(13)),
    ]),
  );
}

// ── Action Button ──────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(label, style: AppTheme.body(13, w: FontWeight.w600, color: color)),
      ]),
    ),
  );
}

// ── History Card ───────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onDelete;
  const _HistoryCard({required this.result, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasImage = result.imagePath.isNotEmpty;
    return GestureDetector(
      onTap: () => Get.to(
        () => ResultScreen(existingResult: result),
        transition: Transition.downToUp,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.hairline),
        ),
        child: Row(children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: hasImage
              ? Image.network(
                  result.imagePath,
                  width: 72, height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72, height: 72,
                    color: AppTheme.surface2,
                    child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.faint),
                  ),
                )
              : Container(
                  width: 72, height: 72,
                  color: AppTheme.surface2,
                  child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.faint),
                ),
          ),
          // Content
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                result.question,
                style: AppTheme.body(13, w: FontWeight.w600, color: AppTheme.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                result.answer,
                style: AppTheme.body(12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                _formatTime(result.timestamp),
                style: AppTheme.body(11, color: AppTheme.faint),
              ),
            ]),
          )),
          // Delete
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.faint),
            onPressed: onDelete,
          ),
        ]),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
