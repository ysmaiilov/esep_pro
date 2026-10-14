import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

void toast(String msg) {
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1900)));
}

extension Ctx on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  Color get debt => cs.error;
  Color get debtBg => cs.errorContainer;
  Color get accent => cs.tertiary;
  Color get accentBg => cs.tertiaryContainer;
  Color get muted => cs.onSurfaceVariant;
  Color get line => cs.outlineVariant;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

TextStyle mono({Color? color, double size = 14, FontWeight w = FontWeight.w700}) => TextStyle(
    color: color, fontSize: size, fontWeight: w, fontFeatures: const [FontFeature.tabularFigures()]);

// ===================== THEME =====================
ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final cs = dark
      ? const ColorScheme.dark(
          primary: Color(0xFF6FCF97), onPrimary: Color(0xFF06210F),
          primaryContainer: Color(0xFF1B3B28), onPrimaryContainer: Color(0xFFBFEBD0),
          secondary: Color(0xFF9CC9AE), onSecondary: Color(0xFF06210F),
          tertiary: Color(0xFFE2B866), onTertiary: Color(0xFF2B1E00),
          tertiaryContainer: Color(0xFF3F3015), onTertiaryContainer: Color(0xFFF6E3B8),
          error: Color(0xFFFF8E78), onError: Color(0xFF3A0A00),
          errorContainer: Color(0xFF4A2219), onErrorContainer: Color(0xFFFFD9D1),
          surface: Color(0xFF16201A), onSurface: Color(0xFFE6EBE4),
          onSurfaceVariant: Color(0xFF9FAA9C), outline: Color(0xFF3A4A3F),
          outlineVariant: Color(0xFF263229))
      : const ColorScheme.light(
          primary: Color(0xFF14532D), onPrimary: Colors.white,
          primaryContainer: Color(0xFFE4EDE3), onPrimaryContainer: Color(0xFF0A2E19),
          secondary: Color(0xFF3F6B50), onSecondary: Colors.white,
          tertiary: Color(0xFFB07A1E), onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFF6E9D3), onTertiaryContainer: Color(0xFF3A2700),
          error: Color(0xFFAE3B26), onError: Colors.white,
          errorContainer: Color(0xFFF6E1DA), onErrorContainer: Color(0xFF5A1608),
          surface: Colors.white, onSurface: Color(0xFF1C1B17),
          onSurfaceVariant: Color(0xFF6E7566), outline: Color(0xFFB9BDB0),
          outlineVariant: Color(0xFFE1E2D8));
  final bg = dark ? const Color(0xFF0E1511) : const Color(0xFFF2F3EC);
  OutlineInputBorder ob(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: cs,
    scaffoldBackgroundColor: bg,
    splashFactory: InkSparkle.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1B261F) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: ob(cs.outlineVariant),
      enabledBorder: ob(cs.outlineVariant),
      focusedBorder: ob(cs.primary, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: BorderSide(color: cs.outlineVariant),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surface,
      indicatorColor: cs.primaryContainer,
      height: 68,
      surfaceTintColor: Colors.transparent,
      labelTextStyle:
          const WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2A3A30) : const Color(0xFF0A2E19),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 1),
  );
}

// ===================== HELPERS =====================
Future<T?> openSheet<T>(BuildContext c, WidgetBuilder b) => showModalBottomSheet<T>(
    context: c, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: b);

Future<bool> confirmDialog(BuildContext c, String msg, {String? yes, bool danger = true}) async {
  final r = await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('no'))),
              FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: danger ? ctx.debt : null,
                      foregroundColor: danger ? ctx.cs.onError : null),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(yes ?? tr('yes_delete'))),
            ],
          ));
  return r == true;
}

Future<double?> askAmount(BuildContext c, String title, double initial) async {
  final ctl = TextEditingController(text: numStr(initial));
  final r = await showDialog<double>(
      context: c,
      builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: AppField(label: tr('amount'), controller: ctl, number: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('no'))),
              FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => Navigator.pop(ctx, pnum(ctl.text)),
                  child: Text(tr('save'))),
            ],
          ));
  return r;
}

List<Widget> divided(BuildContext c, Iterable<Widget> items) {
  final out = <Widget>[];
  var i = 0;
  for (final w in items) {
    if (i++ > 0) out.add(Divider(height: 1, thickness: 1, color: c.line));
    out.add(w);
  }
  return out;
}

// ===================== WIDGETS =====================
class FadeIn extends StatelessWidget {
  final Widget child;
  final int i;
  const FadeIn({super.key, required this.child, this.i = 0});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + (i > 6 ? 6 : i) * 70),
        curve: Curves.easeOutCubic,
        builder: (c, v, ch) => Opacity(
            opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: ch)),
        child: child,
      );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;
  final VoidCallback? onTap;
  const AppCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.color,
      this.border,
      this.onTap});
  @override
  Widget build(BuildContext c) => Material(
        color: color ?? c.cs.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), side: BorderSide(color: border ?? c.line)),
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class ScreenHeader extends StatelessWidget {
  final String title, sub;
  const ScreenHeader(this.title, this.sub, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: c.muted, fontSize: 13.5)),
        ]),
      );
}

class StatTile extends StatelessWidget {
  final String label, value;
  final String? foot;
  final Color? valueColor;
  final IconData? icon;
  const StatTile(
      {super.key, required this.label, required this.value, this.foot, this.valueColor, this.icon});
  @override
  Widget build(BuildContext c) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 15, color: c.muted), const SizedBox(width: 6)],
            Expanded(
                child: Text(label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, letterSpacing: .5, color: c.muted, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: mono(size: 20, color: valueColor ?? c.cs.onSurface, w: FontWeight.w800))),
          if (foot != null) ...[
            const SizedBox(height: 4),
            Text(foot!, style: TextStyle(fontSize: 11.5, color: c.muted)),
          ],
        ]),
      );
}

class SectionHead extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHead(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (action != null)
            GestureDetector(
                onTap: onAction,
                child: Text(action!, style: TextStyle(color: c.cs.primary, fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
      );
}

class EmptyBlock extends StatelessWidget {
  final String title, desc;
  final IconData icon;
  const EmptyBlock(this.title, this.desc, {super.key, this.icon = Icons.inbox_rounded});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
        child: Center(
          child: Column(children: [
            Icon(icon, size: 40, color: c.muted.withAlpha(150)),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(desc, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12.5)),
            ],
          ]),
        ),
      );
}

enum PillKind { paid, debt, accent, neutral }

class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final PillKind kind;
  const Pill(this.text, {super.key, this.icon, this.kind = PillKind.neutral});
  @override
  Widget build(BuildContext c) {
    Color bg, fg;
    switch (kind) {
      case PillKind.paid:
        bg = c.cs.primaryContainer;
        fg = c.cs.primary;
      case PillKind.debt:
        bg = c.debtBg;
        fg = c.debt;
      case PillKind.accent:
        bg = c.accentBg;
        fg = c.accent;
      case PillKind.neutral:
        bg = c.line;
        fg = c.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
        Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

Widget statusPill(String status) {
  if (status == 'paid') return Pill(tr('badge_paid'), icon: Icons.check_rounded, kind: PillKind.paid);
  if (status == 'returned') return Pill(tr('badge_returned'), icon: Icons.undo_rounded, kind: PillKind.accent);
  return Pill(tr('badge_debt'), icon: Icons.attach_money_rounded, kind: PillKind.debt);
}

class IconBox extends StatelessWidget {
  final IconData icon;
  final double size;
  const IconBox(this.icon, {super.key, this.size = 42});
  @override
  Widget build(BuildContext c) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.cs.primaryContainer, borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, size: size * .48, color: c.cs.primary),
      );
}

class PillTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const PillTabs({super.key, required this.labels, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: c.cs.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: i == index ? c.cs.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(
                      child: Text(labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: i == index ? c.cs.onPrimary : c.muted))),
                ),
              ),
            ),
        ]),
      );
}

class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onDec, onInc;
  const QtyStepper({super.key, required this.qty, required this.onDec, required this.onInc});
  @override
  Widget build(BuildContext c) => Container(
        decoration: BoxDecoration(color: c.cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              visualDensity: VisualDensity.compact,
              color: c.cs.primary,
              icon: const Icon(Icons.remove_rounded),
              onPressed: onDec),
          SizedBox(width: 28, child: Center(child: Text('$qty', style: mono(size: 14)))),
          IconButton(
              visualDensity: VisualDensity.compact,
              color: c.cs.primary,
              icon: const Icon(Icons.add_rounded),
              onPressed: onInc),
        ]),
      );
}

class MiniBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const MiniBtn(this.icon, this.onTap, {super.key, this.color});
  @override
  Widget build(BuildContext c) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (color ?? c.muted).withAlpha(90))),
          child: Icon(icon, size: 16, color: color ?? c.cs.primary),
        ),
      );
}

class OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const OptionTile(
      {super.key, required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? c.cs.primaryContainer : c.cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? c.cs.primary : c.line, width: selected ? 1.6 : 1),
            ),
            child: Row(children: [
              Icon(icon, size: 20, color: c.cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
              if (selected) Icon(Icons.check_circle_rounded, size: 20, color: c.cs.primary),
            ]),
          ),
        ),
      );
}

class AppField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool number;
  final ValueChanged<String>? onChanged;
  const AppField(
      {super.key, required this.label, this.controller, this.hint, this.number = false, this.onChanged});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );
}

class BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? bg, fg;
  const BigButton(this.label, {super.key, this.icon, this.onPressed, this.bg, this.fg});
  @override
  Widget build(BuildContext c) => FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg),
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(label),
      );
}

class SheetBody extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  const SheetBody({super.key, required this.title, required this.children, this.icon});
  @override
  Widget build(BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, color: c.cs.primary), const SizedBox(width: 8)],
              Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close_rounded, size: 18)),
            ]),
            const SizedBox(height: 14),
            ...children,
          ]),
        ),
      );
}

/// "ledger" total card – a signature element of the original design
class TotalCard extends StatelessWidget {
  final String label, value;
  final List<Widget> extra;
  const TotalCard(this.label, this.value, {super.key, this.extra = const []});
  @override
  Widget build(BuildContext c) => AppCard(
        color: c.cs.primaryContainer,
        border: Colors.transparent,
        child: Column(children: [
          ...extra,
          // Сумма узун болсо, шрифт кичирейбейт: сумма кийинки катарга өтөт
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(value, textAlign: TextAlign.end, style: mono(size: 22, color: c.cs.primary, w: FontWeight.w800)),
            ],
          ),
        ]),
      );
}
