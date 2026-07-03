import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyCtrl = TextEditingController();
  bool _keyVisible = false;
  bool _saving = false;
  String? _savedKey;
  int _remaining = -1;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final key = await AiService.getSavedApiKey();
    final rem = await AiService.remaining();
    if (mounted) setState(() {
      _savedKey = key;
      _keyCtrl.text = key ?? '';
      _remaining = rem;
      _loadingStats = false;
    });
  }

  Future<void> _saveKey() async {
    setState(() => _saving = true);
    await AiService.saveApiKey(_keyCtrl.text.trim());
    setState(() { _saving = false; _savedKey = _keyCtrl.text.trim(); });
    Get.snackbar(
      'Saved',
      'Your Groq API key has been saved. Unlimited scans enabled!',
      backgroundColor: AppTheme.good.withOpacity(0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  Future<void> _clearKey() async {
    await AiService.clearApiKey();
    _keyCtrl.clear();
    setState(() => _savedKey = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.ink, size: 20),
        ),
        title: Text('Settings', style: AppTheme.display(18)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildUsageCard().animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          _buildByokCard().animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 20),
          _buildOtherSection().animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 20),
          _buildAboutCard().animate().fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildUsageCard() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.bolt_rounded, color: AppTheme.amber, size: 20),
        const SizedBox(width: 8),
        Text('Daily Usage', style: AppTheme.display(15)),
      ]),
      const SizedBox(height: 16),
      if (_loadingStats)
        const Center(child: CircularProgressIndicator(color: AppTheme.primary))
      else if (_savedKey != null && _savedKey!.isNotEmpty)
        _statRow(Icons.all_inclusive, 'Unlimited scans', AppTheme.good, 'BYOK active')
      else ...[
        _statRow(
          Icons.camera_alt_rounded,
          '$_remaining scans remaining today',
          _remaining > 1 ? AppTheme.good : AppTheme.amber,
          'Resets at midnight',
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _remaining < 0 ? 0 : _remaining / 5,
            backgroundColor: AppTheme.faint,
            valueColor: AlwaysStoppedAnimation(
              _remaining > 2 ? AppTheme.good : (_remaining > 0 ? AppTheme.amber : AppTheme.danger),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text('5 free scans per day · Add API key below for unlimited', style: AppTheme.body(12)),
      ],
    ]),
  );

  Widget _statRow(IconData icon, String label, Color color, String sub) => Row(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 10),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.body(14, color: AppTheme.ink)),
      Text(sub, style: AppTheme.body(12)),
    ]),
  ]);

  Widget _buildByokCard() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.vpn_key_rounded, color: AppTheme.accent, size: 20),
        const SizedBox(width: 8),
        Text('Your Groq API Key', style: AppTheme.display(15)),
        const Spacer(),
        if (_savedKey != null && _savedKey!.isNotEmpty)
          PillBadge(text: 'Active', color: AppTheme.good, icon: Icons.check_circle_outline),
      ]),
      const SizedBox(height: 8),
      Text(
        'Get a free key from console.groq.com — no billing required. Gives you unlimited scans with Llama 4 Vision.',
        style: AppTheme.body(13, h: 1.5),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _keyCtrl,
        obscureText: !_keyVisible,
        style: AppTheme.body(13, color: AppTheme.ink),
        decoration: InputDecoration(
          hintText: 'gsk_...',
          hintStyle: AppTheme.body(13),
          filled: true,
          fillColor: AppTheme.surface2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.accent),
          ),
          suffixIcon: IconButton(
            icon: Icon(_keyVisible ? Icons.visibility_off : Icons.visibility, color: AppTheme.muted, size: 18),
            onPressed: () => setState(() => _keyVisible = !_keyVisible),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ElevatedButton(
          style: AppTheme.accentButton(),
          onPressed: _saving ? null : _saveKey,
          child: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Save Key'),
        )),
        if (_savedKey != null && _savedKey!.isNotEmpty) ...[
          const SizedBox(width: 10),
          TextButton(
            onPressed: _clearKey,
            child: Text('Remove', style: AppTheme.body(14, color: AppTheme.danger)),
          ),
        ],
      ]),
    ]),
  );

  Widget _buildOtherSection() => GlassCard(
    child: Column(children: [
      _tileRow(
        icon: Icons.delete_outline_rounded,
        label: 'Clear Scan History',
        color: AppTheme.danger,
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text('Clear History?', style: AppTheme.display(16)),
              content: Text('All saved scans will be deleted.', style: AppTheme.body(14, color: AppTheme.ink)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Clear', style: TextStyle(color: AppTheme.danger)),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await HistoryService.clear();
            Get.snackbar('Done', 'Scan history cleared.', snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppTheme.surface2, colorText: AppTheme.ink,
              margin: const EdgeInsets.all(16),
            );
          }
        },
      ),
    ]),
  );

  Widget _tileRow({required IconData icon, required String label, required Color color, required VoidCallback onTap}) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: AppTheme.body(14, color: color)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: AppTheme.faint, size: 20),
        ]),
      ),
    );

  Widget _buildAboutCard() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.camera_enhance_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PhotoGPT', style: AppTheme.display(15)),
          Text('v1.0.0 · Open Source', style: AppTheme.body(11)),
        ]),
      ]),
      const SizedBox(height: 12),
      Text(
        'Built with Llama 4 Vision (Groq) · Free for everyone · ⭐ Star on GitHub',
        style: AppTheme.body(13, h: 1.5),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.ink,
          side: BorderSide(color: AppTheme.hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.star_outline_rounded, size: 16),
        label: const Text('Star on GitHub'),
        onPressed: () => launchUrl(Uri.parse('https://github.com/YOUR_USERNAME/photogpt')),
      ),
    ]),
  );
}
