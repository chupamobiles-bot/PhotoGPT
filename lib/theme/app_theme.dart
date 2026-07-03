import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color bg       = Color(0xFF080B14);
  static const Color surface  = Color(0xFF0F1220);
  static const Color surface2 = Color(0xFF161B2E);
  static const Color glass    = Color(0xFF1A1F35);
  static const Color primary  = Color(0xFF7C3AED); // violet
  static const Color accent   = Color(0xFF06B6D4); // cyan
  static const Color good     = Color(0xFF10B981);
  static const Color amber    = Color(0xFFF59E0B);
  static const Color danger   = Color(0xFFEF4444);
  static const Color ink      = Color(0xFFFFFFFF);
  static const Color muted    = Color(0xFF8892B0);
  static const Color faint    = Color(0xFF3D4466);
  static const Color hairline = Color(0xFF1E2440);

  // ── Text ──────────────────────────────────────────────────────────────────
  static TextStyle display(double size, {FontWeight w = FontWeight.w700, Color color = ink, double? h}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: color, height: h);

  static TextStyle body(double size, {FontWeight w = FontWeight.w400, Color color = muted, double? h}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: color, height: h);

  // ── Button ────────────────────────────────────────────────────────────────
  static ButtonStyle primaryButton({double radius = 16}) => ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: ink,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
  );

  static ButtonStyle accentButton({double radius = 16}) => ElevatedButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: bg,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
  );

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(primary: primary, surface: surface),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    useMaterial3: true,
  );
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color? borderColor;
  const GlassCard({super.key, required this.child, this.padding, this.radius = 20, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.glass,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppTheme.hairline),
    ),
    child: child,
  );
}

class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned(top: -100, right: -60, child: _blob(AppTheme.primary, 260)),
    Positioned(bottom: 80, left: -80, child: _blob(AppTheme.accent, 200)),
    child,
  ]);

  Widget _blob(Color c, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [c.withOpacity(0.1), Colors.transparent]),
    ),
  );
}

class PillBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const PillBadge({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, color: color, size: 12), const SizedBox(width: 4)],
      Text(text, style: AppTheme.body(11, w: FontWeight.w700, color: color)),
    ]),
  );
}
