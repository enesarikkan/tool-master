import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:saf/saf.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DmPcsNotebookApp());
}


enum CodexDeviceClass {
  phone,
  tablet,
}

class CodexDeviceProfile {
  final CodexDeviceClass deviceClass;
  final Size logicalSize;
  final Orientation orientation;
  final double shortestSide;
  final bool isLargeTablet;

  const CodexDeviceProfile({
    required this.deviceClass,
    required this.logicalSize,
    required this.orientation,
    required this.shortestSide,
    required this.isLargeTablet,
  });

  bool get isPhone => deviceClass == CodexDeviceClass.phone;
  bool get isTablet => deviceClass == CodexDeviceClass.tablet;

  String get label => isTablet ? 'Tablet' : 'Telefon';

  String get detail {
    final width = logicalSize.width.round();
    final height = logicalSize.height.round();
    final rotation =
        orientation == Orientation.landscape ? 'Yatay' : 'Dikey';

    if (isLargeTablet) {
      return '$label • Büyük ekran • $rotation • ${width}×$height dp';
    }

    return '$label • $rotation • ${width}×$height dp';
  }

  static CodexDeviceProfile of(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final shortest = size.shortestSide;

    // Flutter arayüzleri için cihaz modelinden ziyade kullanılabilir mantıksal
    // ekran alanını ölçmek daha güvenlidir. 600dp Material tablet eşiğidir.
    final isTablet = shortest >= 600.0;

    return CodexDeviceProfile(
      deviceClass:
          isTablet ? CodexDeviceClass.tablet : CodexDeviceClass.phone,
      logicalSize: size,
      orientation: media.orientation,
      shortestSide: shortest,
      isLargeTablet: shortest >= 720.0,
    );
  }
}


class CodexAppearanceController extends ChangeNotifier {
  static const _key = 'dmpcs_appearance_v15';

  bool loaded = false;
  String themeMode = 'system';
  String accent = 'arcane';
  double fontScale = 1.0;
  bool reduceMotion = false;
  double motionScale = 1.0;
  bool backgroundGrid = true;
  double gridStrength = 1.0;
  String surfaceStyle = 'soft';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final savedTheme = map['themeMode']?.toString();
        if (savedTheme == 'system' ||
            savedTheme == 'dark' ||
            savedTheme == 'light') {
          themeMode = savedTheme!;
        }
        final savedAccent = map['accent']?.toString();
        if (savedAccent == 'sage') {
          // v0.1.2 palette migration: eski soluk adaçayı varsayılanını
          // yeni Tool Master arcane mavisine taşı.
          accent = 'arcane';
        } else if (CodexThemePalette.accents.containsKey(savedAccent)) {
          accent = savedAccent!;
        }
        fontScale =
            ((map['fontScale'] as num?)?.toDouble() ?? 1.0)
                .clamp(.85, 1.30)
                .toDouble();
        reduceMotion = map['reduceMotion'] as bool? ?? false;
        motionScale =
            ((map['motionScale'] as num?)?.toDouble() ?? 1.0)
                .clamp(.5, 1.6)
                .toDouble();
        backgroundGrid = map['backgroundGrid'] as bool? ?? true;
        gridStrength =
            ((map['gridStrength'] as num?)?.toDouble() ?? 1.0)
                .clamp(.2, 1.8)
                .toDouble();
        final savedSurface = map['surfaceStyle']?.toString();
        if (savedSurface == 'soft' ||
            savedSurface == 'contrast' ||
            savedSurface == 'flat') {
          surfaceStyle = savedSurface!;
        }
      }
    } catch (_) {
      // Bozuk görünüm ayarı uygulamanın açılmasını engellemez.
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  ThemeMode get materialThemeMode {
    switch (themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Color get accentColor =>
      CodexThemePalette.accents[accent] ??
      CodexThemePalette.accents['sage']!;

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'themeMode': themeMode,
        'accent': accent,
        'fontScale': fontScale,
        'reduceMotion': reduceMotion,
        'motionScale': motionScale,
        'backgroundGrid': backgroundGrid,
        'gridStrength': gridStrength,
        'surfaceStyle': surfaceStyle,
      }),
    );
  }

  Future<void> setThemeMode(String value) async {
    if (!{'system', 'dark', 'light'}.contains(value)) return;
    themeMode = value;
    notifyListeners();
    await _save();
  }

  Future<void> setAccent(String value) async {
    if (!CodexThemePalette.accents.containsKey(value)) return;
    accent = value;
    notifyListeners();
    await _save();
  }

  Future<void> setFontScale(double value) async {
    fontScale = value.clamp(.85, 1.30).toDouble();
    notifyListeners();
    await _save();
  }

  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
    notifyListeners();
    await _save();
  }

  Future<void> setMotionScale(double value) async {
    motionScale = value.clamp(.5, 1.6).toDouble();
    notifyListeners();
    await _save();
  }

  Future<void> setBackgroundGrid(bool value) async {
    backgroundGrid = value;
    notifyListeners();
    await _save();
  }

  Future<void> setGridStrength(double value) async {
    gridStrength = value.clamp(.2, 1.8).toDouble();
    notifyListeners();
    await _save();
  }

  Future<void> setSurfaceStyle(String value) async {
    if (!{'soft', 'contrast', 'flat'}.contains(value)) return;
    surfaceStyle = value;
    notifyListeners();
    await _save();
  }
}

class CodexAppearanceScope
    extends InheritedNotifier<CodexAppearanceController> {
  const CodexAppearanceScope({
    super.key,
    required CodexAppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static CodexAppearanceController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<
        CodexAppearanceScope>();
    assert(scope != null, 'CodexAppearanceScope bulunamadı.');
    return scope!.notifier!;
  }
}

class CodexThemePalette {
  // Tool Master logosundaki cobalt / arcane mavi + altın ailesi temel alınır.
  static const accents = <String, Color>{
    'arcane': Color(0xFF315CBE),
    'violet': Color(0xFF6D5BC8),
    'teal': Color(0xFF2F7C7B),
    'emerald': Color(0xFF397B5B),
    'amber': Color(0xFFA96E1A),
    'rose': Color(0xFFB55776),
    'crimson': Color(0xFFB94E55),
    'slate': Color(0xFF536579),
  };

  static const accentLabels = <String, String>{
    'arcane': 'Arcane Mavi',
    'violet': 'Menekşe',
    'teal': 'Derin Turkuaz',
    'emerald': 'Zümrüt',
    'amber': 'Kehribar',
    'rose': 'Gül',
    'crimson': 'Kızıl',
    'slate': 'Arduvaz',
  };

  static ThemeData theme({
    required Brightness brightness,
    required Color accent,
    required String surfaceStyle,
  }) {
    final dark = brightness == Brightness.dark;

    // Açık tema: temiz, serin ve okunaklı.
    // Koyu tema: logo ile uyumlu gece laciverti.
    final background = dark
        ? const Color(0xFF090E18)
        : const Color(0xFFF5F7FA);
    final surface = dark
        ? const Color(0xFF111827)
        : const Color(0xFFFFFFFF);
    final surface2 = dark
        ? const Color(0xFF172033)
        : const Color(0xFFEEF2F7);
    final surfaceHigh = dark
        ? const Color(0xFF1D283B)
        : const Color(0xFFF9FBFD);
    final text = dark
        ? const Color(0xFFF4F7FC)
        : const Color(0xFF182033);
    final muted = dark
        ? const Color(0xFF9AA7B8)
        : const Color(0xFF667085);
    final border = dark
        ? const Color(0xFF29354A)
        : const Color(0xFFDCE3EC);

    // Aynı accent açık temada daha tok, koyu temada biraz daha parlak görünür.
    final primary = dark
        ? Color.lerp(accent, Colors.white, .24)!
        : accent;
    final secondary = dark
        ? const Color(0xFFE0B35D)
        : const Color(0xFFAC741D);
    final tertiary = dark
        ? const Color(0xFF9286EA)
        : const Color(0xFF6258B7);

    final contrastFactor = surfaceStyle == 'contrast'
        ? 1.0
        : surfaceStyle == 'flat'
            ? .32
            : .68;

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      surface: surface,
      error: const Color(0xFFD86570),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: scheme.copyWith(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primary.withValues(alpha: dark ? .22 : .11),
        onPrimaryContainer: dark ? const Color(0xFFEAF0FF) : const Color(0xFF18326E),
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: secondary.withValues(alpha: dark ? .20 : .11),
        tertiary: tertiary,
        surface: surface,
        surfaceContainer: surface,
        surfaceContainerLow: surface2,
        surfaceContainerHigh: surfaceHigh,
        outline: border,
        outlineVariant: border.withValues(alpha: .82),
        onSurface: text,
        onSurfaceVariant: muted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: .85),
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: surfaceStyle == 'flat' ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: dark ? .22 : .07),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: border.withValues(alpha: contrastFactor),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        selectedColor: primary.withValues(alpha: dark ? .20 : .12),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: TextStyle(
          color: text,
          fontSize: 11.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: border.withValues(alpha: .55),
          disabledForegroundColor: muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark
            ? const Color(0xFF1D283B)
            : const Color(0xFF182033),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: muted.withValues(alpha: .72),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: .22),
        selectionHandleColor: primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2.withValues(alpha: dark ? .78 : .72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),
        hintStyle: TextStyle(
          color: muted,
          fontSize: 13,
        ),
        labelStyle: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class AppColors {
  static const bg = Color(0xFF090E18);
  static const panel = Color(0xFF111827);
  static const panel2 = Color(0xFF172033);
  static const panel3 = Color(0xFF1D283B);
  static const border = Color(0xFF29354A);
  static const purple = Color(0xFF7192F2);
  static const gold = Color(0xFFE0B35D);
  static const green = Color(0xFF69B98E);
  static const red = Color(0xFFD86570);
  static const blue = Color(0xFF62A6E8);
  static const muted = Color(0xFF9AA7B8);
  static const text = Color(0xFFF4F7FC);
}


/// Aynı editör içinde canlı biçimlendirme.
///
/// Metnin gerçek Markdown içeriğini değiştirmez. Yalnızca EditableText'in
/// çizdiği TextSpan'leri biçimlendirir. Böylece kayıt edilen içerik Markdown
/// olarak kalırken kullanıcı yazdığı yerde sonucu görür.
class LiveMarkdownController extends TextEditingController {
  bool livePreview = true;

  void setLivePreview(bool value) {
    if (livePreview == value) return;
    livePreview = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!livePreview ||
        (withComposing &&
            value.composing.isValid &&
            !value.composing.isCollapsed)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final base = (style ?? const TextStyle()).copyWith(
      color: style?.color ?? Theme.of(context).colorScheme.onSurface,
      fontSize: style?.fontSize ?? 15.5,
      height: style?.height ?? 1.55,
    );

    if (text.isEmpty) {
      return TextSpan(text: '', style: base);
    }

    final caret = selection.isValid ? selection.baseOffset : -1;
    final lines = text.split('\n');
    final children = <InlineSpan>[];
    var absolute = 0;
    var dmBlock = false;

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final trimmed = line.trim();

      if (trimmed == ':::dm') {
        dmBlock = true;
      }

      children.addAll(
        _lineSpans(
          line: line,
          absoluteStart: absolute,
          caret: caret,
          base: base,
          dmBlock: dmBlock,
        ),
      );

      if (trimmed == ':::' && dmBlock) {
        dmBlock = false;
      }

      if (index < lines.length - 1) {
        children.add(TextSpan(text: '\n', style: base));
        absolute += line.length + 1;
      } else {
        absolute += line.length;
      }
    }

    return TextSpan(style: base, children: children);
  }

  List<InlineSpan> _lineSpans({
    required String line,
    required int absoluteStart,
    required int caret,
    required TextStyle base,
    required bool dmBlock,
  }) {
    final spans = <InlineSpan>[];
    final lineEnd = absoluteStart + line.length;
    final activeLine = caret >= absoluteStart && caret <= lineEnd;
    var offset = 0;
    var lineStyle = dmBlock
        ? base.copyWith(
            color: const Color(0xFFF0B0B0),
            backgroundColor: const Color(0x221F0B0B),
          )
        : base;

    final heading = RegExp(r'^(#{1,6})\s+').firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      final sizes = <int, double>{
        1: 29,
        2: 25,
        3: 22,
        4: 19,
        5: 17,
        6: 15.5,
      };
      lineStyle = lineStyle.copyWith(
        fontSize: sizes[level] ?? 15.5,
        fontWeight: FontWeight.w900,
        height: 1.30,
      );
      offset = heading.end;
      final marker = line.substring(0, offset);
      spans.add(
        TextSpan(
          text: marker,
          style: activeLine
              ? lineStyle.copyWith(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )
              : _syntaxHidden(lineStyle),
        ),
      );
    } else if (line.startsWith('> ')) {
      offset = 2;
      lineStyle = lineStyle.copyWith(
        fontStyle: FontStyle.italic,
        color: const Color(0xFFD8D9E2),
      );
      spans.add(
        TextSpan(
          text: '> ',
          style: lineStyle.copyWith(
            color: AppColors.purple,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else if (line.startsWith('- [ ] ') ||
        line.toLowerCase().startsWith('- [x] ')) {
      offset = 6;
      final done = line.toLowerCase().startsWith('- [x] ');
      spans.add(
        TextSpan(
          text: line.substring(0, offset),
          style: base.copyWith(
            color: done ? AppColors.green : AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      if (done) {
        lineStyle = lineStyle.copyWith(
          color: AppColors.muted,
          decoration: TextDecoration.lineThrough,
        );
      }
    } else if (RegExp(r'^\d+\.\s+').hasMatch(line)) {
      final match = RegExp(r'^\d+\.\s+').firstMatch(line)!;
      offset = match.end;
      spans.add(
        TextSpan(
          text: line.substring(0, offset),
          style: base.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else if (line.startsWith('- ')) {
      offset = 2;
      spans.add(
        TextSpan(
          text: '- ',
          style: base.copyWith(
            color: AppColors.purple,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    if (line.trim() == '---') {
      return [
        TextSpan(
          text: line,
          style: base.copyWith(
            color: AppColors.muted,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ];
    }

    if (line.trim() == ':::dm' || line.trim() == ':::') {
      return [
        TextSpan(
          text: line,
          style: base.copyWith(
            color: AppColors.red,
            fontWeight: FontWeight.w900,
          ),
        ),
      ];
    }

    spans.addAll(
      _inlineSpans(
        content: line.substring(offset),
        absoluteStart: absoluteStart + offset,
        caret: caret,
        base: lineStyle,
      ),
    );

    return spans;
  }

  List<InlineSpan> _inlineSpans({
    required String content,
    required int absoluteStart,
    required int caret,
    required TextStyle base,
  }) {
    final spans = <InlineSpan>[];
    final token = RegExp(
      r'(!)?\[\[([^\]]+)\]\]|'
      r'`([^`\n]+)`|'
      r'\*\*([^*\n]+)\*\*|'
      r'~~([^~\n]+)~~|'
      r'\*([^*\n]+)\*|'
      r'#[A-Za-z0-9_\-ğüşöçıİĞÜŞÖÇ]+|'
      r'\^[A-Za-z0-9_\-]+',
    );

    var cursor = 0;
    for (final match in token.allMatches(content)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: content.substring(cursor, match.start),
            style: base,
          ),
        );
      }

      final raw = match.group(0)!;
      final tokenStart = absoluteStart + match.start;
      final tokenEnd = absoluteStart + match.end;
      final active = caret >= tokenStart && caret <= tokenEnd;

      if (match.group(2) != null) {
        _wikiSpans(
          spans: spans,
          raw: raw,
          inner: match.group(2)!,
          embed: match.group(1) == '!',
          active: active,
          base: base,
        );
      } else if (match.group(3) != null) {
        _wrappedSpans(
          spans: spans,
          raw: raw,
          openLength: 1,
          closeLength: 1,
          active: active,
          base: base,
          contentStyle: base.copyWith(
            fontFamily: 'monospace',
            color: AppColors.gold,
            backgroundColor: AppColors.panel2,
          ),
        );
      } else if (match.group(4) != null) {
        _wrappedSpans(
          spans: spans,
          raw: raw,
          openLength: 2,
          closeLength: 2,
          active: active,
          base: base,
          contentStyle: base.copyWith(
            fontWeight: FontWeight.w900,
          ),
        );
      } else if (match.group(5) != null) {
        _wrappedSpans(
          spans: spans,
          raw: raw,
          openLength: 2,
          closeLength: 2,
          active: active,
          base: base,
          contentStyle: base.copyWith(
            color: AppColors.muted,
            decoration: TextDecoration.lineThrough,
          ),
        );
      } else if (match.group(6) != null) {
        _wrappedSpans(
          spans: spans,
          raw: raw,
          openLength: 1,
          closeLength: 1,
          active: active,
          base: base,
          contentStyle: base.copyWith(
            fontStyle: FontStyle.italic,
          ),
        );
      } else if (raw.startsWith('#')) {
        spans.add(
          TextSpan(
            text: raw,
            style: base.copyWith(
              color: AppColors.purple,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      } else if (raw.startsWith('^')) {
        spans.add(
          TextSpan(
            text: raw,
            style: base.copyWith(
              color: AppColors.blue,
              fontSize: (base.fontSize ?? 15.5) * .80,
            ),
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(cursor),
          style: base,
        ),
      );
    }

    return spans;
  }

  void _wikiSpans({
    required List<InlineSpan> spans,
    required String raw,
    required String inner,
    required bool embed,
    required bool active,
    required TextStyle base,
  }) {
    if (active) {
      spans.add(
        TextSpan(
          text: raw,
          style: base.copyWith(
            color: AppColors.purple,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      return;
    }

    final openLength = embed ? 3 : 2;
    final open = raw.substring(0, openLength);
    final close = raw.substring(raw.length - 2);
    final pipe = inner.indexOf('|');

    spans.add(TextSpan(text: open, style: _syntaxHidden(base)));

    if (pipe >= 0) {
      spans.add(
        TextSpan(
          text: inner.substring(0, pipe + 1),
          style: _syntaxHidden(base),
        ),
      );
      spans.add(
        TextSpan(
          text: inner.substring(pipe + 1),
          style: base.copyWith(
            color: AppColors.purple,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: inner,
          style: base.copyWith(
            color: embed ? AppColors.gold : AppColors.purple,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    spans.add(TextSpan(text: close, style: _syntaxHidden(base)));
  }

  void _wrappedSpans({
    required List<InlineSpan> spans,
    required String raw,
    required int openLength,
    required int closeLength,
    required bool active,
    required TextStyle base,
    required TextStyle contentStyle,
  }) {
    final open = raw.substring(0, openLength);
    final content = raw.substring(
      openLength,
      raw.length - closeLength,
    );
    final close = raw.substring(raw.length - closeLength);
    final markerStyle = active
        ? base.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          )
        : _syntaxHidden(base);

    spans.add(TextSpan(text: open, style: markerStyle));
    spans.add(TextSpan(text: content, style: contentStyle));
    spans.add(TextSpan(text: close, style: markerStyle));
  }

  TextStyle _syntaxHidden(TextStyle base) {
    return base.copyWith(
      color: Colors.transparent,
      fontSize: 0.01,
      height: 0.01,
      letterSpacing: -0.2,
    );
  }
}

class DmPcsNotebookApp extends StatefulWidget {
  const DmPcsNotebookApp({super.key});

  @override
  State<DmPcsNotebookApp> createState() => _DmPcsNotebookAppState();
}

class _DmPcsNotebookAppState extends State<DmPcsNotebookApp> {
  late final VaultStore store;
  late final CodexAppearanceController appearance;

  @override
  void initState() {
    super.initState();
    store = VaultStore();
    appearance = CodexAppearanceController();
    appearance.addListener(_appearanceChanged);
    store.load();
    appearance.load();
  }

  void _appearanceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appearance.removeListener(_appearanceChanged);
    appearance.dispose();
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = appearance.accentColor;

    return CodexAppearanceScope(
      controller: appearance,
      child: VaultScope(
        store: store,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Tool Master',
          themeMode: appearance.materialThemeMode,
          theme: CodexThemePalette.theme(
            brightness: Brightness.light,
            accent: accent,
            surfaceStyle: appearance.surfaceStyle,
          ),
          darkTheme: CodexThemePalette.theme(
            brightness: Brightness.dark,
            accent: accent,
            surfaceStyle: appearance.surfaceStyle,
          ),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final scaled = media.copyWith(
              textScaler: TextScaler.linear(
                appearance.fontScale,
              ),
            );
            return MediaQuery(
              data: scaled,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const CodexShell(),
        ),
      ),
    );
  }
}

class VaultScope extends InheritedNotifier<VaultStore> {
  const VaultScope({
    super.key,
    required VaultStore store,
    required super.child,
  }) : super(notifier: store);

  static VaultStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<VaultScope>();
    assert(scope != null, 'VaultScope bulunamadı.');
    return scope!.notifier!;
  }
}

enum NoteType {
  note,
  npc,
  monster,
  session,
  location,
  quest,
  item,
  organization,
  lore,
  rule,
  journal,
  handout,
  template,
}

extension NoteTypeX on NoteType {
  String get label {
    switch (this) {
      case NoteType.note:
        return 'Not';
      case NoteType.npc:
        return 'NPC';
      case NoteType.monster:
        return 'Canavar';
      case NoteType.session:
        return 'Oturum';
      case NoteType.location:
        return 'Mekân';
      case NoteType.quest:
        return 'Görev';
      case NoteType.item:
        return 'Eşya';
      case NoteType.organization:
        return 'Organizasyon';
      case NoteType.lore:
        return 'Lore';
      case NoteType.rule:
        return 'Kural';
      case NoteType.journal:
        return 'Günlük';
      case NoteType.handout:
        return 'Handout';
      case NoteType.template:
        return 'Şablon';
    }
  }

  String get iconAsset {
    switch (this) {
      case NoteType.note:
        return 'note';
      case NoteType.npc:
        return 'npc';
      case NoteType.monster:
        return 'monster';
      case NoteType.session:
        return 'session';
      case NoteType.location:
        return 'location';
      case NoteType.quest:
        return 'quest';
      case NoteType.item:
        return 'item';
      case NoteType.organization:
        return 'organization';
      case NoteType.lore:
        return 'lore';
      case NoteType.rule:
        return 'book_open';
      case NoteType.journal:
        return 'scroll';
      case NoteType.handout:
        return 'letter';
      case NoteType.template:
        return 'book_open';
    }
  }
}

class NoteRecord {
  final String id;
  String title;
  String content;
  NoteType type;
  String visibility;
  bool pinned;
  bool archived;
  bool bookmarked;
  DateTime createdAt;
  DateTime updatedAt;
  Map<String, String> properties;
  Map<String, String> propertyTypes;
  List<String> detailFields;

  NoteRecord({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.visibility,
    required this.pinned,
    required this.archived,
    required this.bookmarked,
    required this.createdAt,
    required this.updatedAt,
    required this.properties,
    required this.propertyTypes,
    required this.detailFields,
  });

  factory NoteRecord.blank({
    required String id,
    required NoteType type,
  }) {
    final now = DateTime.now();
    return NoteRecord(
      id: id,
      title: '',
      content: '',
      type: type,
      visibility: 'Sadece Ben',
      pinned: false,
      archived: false,
      bookmarked: false,
      createdAt: now,
      updatedAt: now,
      properties: {},
      propertyTypes: {},
      detailFields: [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type.name,
        'visibility': visibility,
        'pinned': pinned,
        'archived': archived,
        'bookmarked': bookmarked,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'properties': properties,
        'propertyTypes': propertyTypes,
        'detailFields': detailFields,
      };

  factory NoteRecord.fromJson(Map<String, dynamic> json) {
    return NoteRecord(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: NoteType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NoteType.note,
      ),
      visibility: json['visibility'] as String? ?? 'Sadece Ben',
      pinned: json['pinned'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      bookmarked: json['bookmarked'] as bool? ?? false,
      createdAt: DateTime.tryParse(
            json['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            json['updatedAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      properties: Map<String, String>.from(
        json['properties'] as Map? ?? {},
      ),
      propertyTypes: Map<String, String>.from(
        json['propertyTypes'] as Map? ?? {},
      ),
      detailFields: ((json['detailFields'] as List?) ??
              (json['properties'] as Map?)?.keys.toList() ??
              const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}



class VaultCatalogEntry {
  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  int noteCount;

  VaultCatalogEntry({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.noteCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'noteCount': noteCount,
      };

  factory VaultCatalogEntry.fromJson(Map<String, dynamic> json) {
    return VaultCatalogEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Kasa',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      noteCount: (json['noteCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class JsonImportResult {
  final int imported;
  final int skipped;
  final int totalRows;

  const JsonImportResult({
    required this.imported,
    required this.skipped,
    required this.totalRows,
  });
}

class VaultStore extends ChangeNotifier {
  static const _notesKey = 'dmpcs_notes_v04';
  static const _vaultNameKey = 'dmpcs_vault_name_v04';
  static const _backupKey = 'dmpcs_notes_backup_v08';
  static const _storageTreeUriKey = 'dmpcs_storage_tree_uri_v10';
  static const _storageDisplayNameKey = 'dmpcs_storage_display_name_v10';
  static const _activeVaultIdKey = 'dmpcs_active_vault_id_v10';

  final Saf _saf = Saf();
  final List<NoteRecord> notes = [];
  final List<VaultCatalogEntry> vaultCatalog = [];
  String vaultName = 'Kasa';
  String? selectedId;
  String searchText = '';
  String? selectedTag;
  bool loaded = false;
  bool graphMode = false;
  bool saving = false;
  DateTime? lastSavedAt;
  String? storageError;
  Timer? _saveDebounce;

  String? storageTreeUri;
  String? storageDisplayName;
  String? appRootUri;
  String? activeVaultId;
  bool externalStorageReady = false;
  bool switchingVault = false;

  bool get hasExternalStorage =>
      externalStorageReady && appRootUri != null && activeVaultId != null;

  String get storageLabel => storageDisplayName == null
      ? 'Kayıt konumu seçilmedi'
      : '${storageDisplayName!} / dmpcsnotebook';

  VaultCatalogEntry? get activeVaultDescriptor {
    final id = activeVaultId;
    if (id == null) return null;
    for (final item in vaultCatalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<NoteRecord> _decodeNotes(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Kayıt verisi liste formatında değil.');
    }
    return decoded
        .map(
          (e) => NoteRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Önce eski/yerel önbelleği yükle. İlk kurulumda bu veri seçilen
      // dmpcsnotebook klasörüne taşınacaktır.
      vaultName = prefs.getString(_vaultNameKey) ?? 'Kasa';
      final raw = prefs.getString(_notesKey);

      if (raw != null && raw.isNotEmpty) {
        try {
          notes
            ..clear()
            ..addAll(_decodeNotes(raw));
        } catch (error) {
          final backup = prefs.getString(_backupKey);
          if (backup != null && backup.isNotEmpty) {
            notes
              ..clear()
              ..addAll(_decodeNotes(backup));
            storageError =
                'Ana yerel kayıt okunamadı; güvenli yedek geri yüklendi.';
          }
        }
      }

      storageTreeUri = prefs.getString(_storageTreeUriKey);
      storageDisplayName = prefs.getString(_storageDisplayNameKey);
      activeVaultId = prefs.getString(_activeVaultIdKey);

      if (storageTreeUri != null && storageTreeUri!.isNotEmpty) {
        try {
          await _connectExternalStorage(
            storageTreeUri!,
            createIfMissing: true,
            migrateCurrentIfNew: true,
          );
        } catch (error) {
          externalStorageReady = false;
          appRootUri = null;
          storageError =
              'Seçilen kayıt konumuna erişilemedi. Konumu yeniden seç: $error';
        }
      }
    } catch (error) {
      storageError = 'Kasa yüklenirken hata oluştu: $error';
    } finally {
      loaded = true;
      notifyListeners();
    }
  }


  Future<bool> chooseStorageLocation() async {
    try {
      await flushSave();

      final picked = await _saf.pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      if (picked == null) return false;

      final prefs = await SharedPreferences.getInstance();
      storageTreeUri = picked.uri;
      storageDisplayName = picked.name.isEmpty ? 'Seçilen klasör' : picked.name;
      await prefs.setString(_storageTreeUriKey, storageTreeUri!);
      await prefs.setString(
        _storageDisplayNameKey,
        storageDisplayName!,
      );

      await _connectExternalStorage(
        storageTreeUri!,
        createIfMissing: true,
        migrateCurrentIfNew: true,
      );

      storageError = null;
      notifyListeners();
      return true;
    } catch (error) {
      storageError = 'Kayıt konumu hazırlanamadı: $error';
      notifyListeners();
      return false;
    }
  }

  Future<void> _connectExternalStorage(
    String treeUri, {
    required bool createIfMissing,
    required bool migrateCurrentIfNew,
  }) async {
    final existingRoot = await _saf.child(
      treeUri,
      const ['dmpcsnotebook'],
    );

    final root = existingRoot ??
        (createIfMissing
            ? await _saf.mkdirp(treeUri, const ['dmpcsnotebook'])
            : null);

    if (root == null) {
      throw const FormatException('dmpcsnotebook klasörü bulunamadı.');
    }

    appRootUri = root.uri;

    final indexFile = await _saf.child(
      root.uri,
      const ['index.json'],
    );

    if (indexFile == null) {
      if (!migrateCurrentIfNew) {
        throw const FormatException('Kasa dizini bulunamadı.');
      }

      final now = DateTime.now();
      final firstId = activeVaultId?.trim().isNotEmpty == true
          ? activeVaultId!
          : 'vault_${now.microsecondsSinceEpoch}';

      activeVaultId = firstId;
      vaultCatalog
        ..clear()
        ..add(
          VaultCatalogEntry(
            id: firstId,
            name: vaultName.trim().isEmpty ? 'Kasa' : vaultName.trim(),
            createdAt: now,
            updatedAt: now,
            noteCount: notes.length,
          ),
        );

      await _writeVaultFile(firstId);
      await _writeIndex();
      await _writeRootReadme();
      await _writeAppSettingsSnapshot();
    } else {
      await _readIndex(indexFile.uri);

      if (vaultCatalog.isEmpty) {
        final now = DateTime.now();
        final id = 'vault_${now.microsecondsSinceEpoch}';
        activeVaultId = id;
        vaultCatalog.add(
          VaultCatalogEntry(
            id: id,
            name: 'Kasa',
            createdAt: now,
            updatedAt: now,
            noteCount: 0,
          ),
        );
        notes.clear();
        vaultName = 'Kasa';
        await _writeVaultFile(id);
        await _writeIndex();
      } else {
        final requested = activeVaultId;
        final resolved = vaultCatalog.any((v) => v.id == requested)
            ? requested!
            : vaultCatalog.first.id;
        activeVaultId = resolved;
        await _loadVaultFile(resolved);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeVaultIdKey, activeVaultId!);
    externalStorageReady = true;
  }

  Future<void> _readIndex(String fileUri) async {
    final bytes = await _saf.readFileBytes(fileUri);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('index.json geçersiz.');
    }

    final map = Map<String, dynamic>.from(decoded);
    final list = (map['vaults'] as List?) ?? const [];
    vaultCatalog
      ..clear()
      ..addAll(
        list.whereType<Map>().map(
              (item) => VaultCatalogEntry.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ),
      );

    final storedActive = map['activeVaultId']?.toString();
    if (storedActive != null && storedActive.isNotEmpty) {
      activeVaultId = storedActive;
    }
  }

  Future<void> _writeIndex() async {
    final rootUri = appRootUri;
    if (rootUri == null) return;

    final payload = const JsonEncoder.withIndent('  ').convert({
      'format': 'dmpcsnotebook-storage-v1',
      'updatedAt': DateTime.now().toIso8601String(),
      'activeVaultId': activeVaultId,
      'vaults': vaultCatalog.map((e) => e.toJson()).toList(),
    });

    await _saf.writeFileBytes(
      rootUri,
      'index.json',
      'application/json',
      Uint8List.fromList(utf8.encode(payload)),
      overwrite: true,
    );
  }

  Future<String> _vaultDirectoryUri(String id) async {
    final rootUri = appRootUri;
    if (rootUri == null) {
      throw const FormatException('Kayıt klasörü hazır değil.');
    }
    final dir = await _saf.mkdirp(
      rootUri,
      ['vaults', id],
    );
    return dir.uri;
  }

  Future<void> _writeVaultFile(String id) async {
    final dirUri = await _vaultDirectoryUri(id);

    final current = await _saf.child(
      dirUri,
      const ['vault.json'],
    );
    if (current != null) {
      try {
        final oldBytes = await _saf.readFileBytes(current.uri);
        await _saf.writeFileBytes(
          dirUri,
          'backup.json',
          'application/json',
          oldBytes,
          overwrite: true,
        );
      } catch (_) {
        // Ana kaydın yazılması yedek hatası yüzünden durmaz.
      }
    }

    final payload = const JsonEncoder.withIndent('  ').convert({
      'format': 'dmpcsnotebook-v10',
      'vaultId': id,
      'vaultName': vaultName,
      'savedAt': DateTime.now().toIso8601String(),
      'notes': notes.map((e) => e.toJson()).toList(),
    });

    await _saf.writeFileBytes(
      dirUri,
      'vault.json',
      'application/json',
      Uint8List.fromList(utf8.encode(payload)),
      overwrite: true,
    );

    for (final item in vaultCatalog) {
      if (item.id == id) {
        item.name = vaultName;
        item.updatedAt = DateTime.now();
        item.noteCount = notes.length;
        break;
      }
    }
  }

  Future<void> _loadVaultFile(String id) async {
    final rootUri = appRootUri;
    if (rootUri == null) {
      throw const FormatException('Kayıt klasörü hazır değil.');
    }

    final file = await _saf.child(
      rootUri,
      ['vaults', id, 'vault.json'],
    );

    if (file == null) {
      final descriptor = vaultCatalog.firstWhere((e) => e.id == id);
      vaultName = descriptor.name;
      notes.clear();
      selectedId = null;
      await _writeVaultFile(id);
      return;
    }

    final bytes = await _saf.readFileBytes(file.uri);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('vault.json geçersiz.');
    }

    final map = Map<String, dynamic>.from(decoded);
    final rawNotes = (map['notes'] as List?) ?? const [];
    final loadedNotes = rawNotes
        .whereType<Map>()
        .map(
          (item) => NoteRecord.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();

    notes
      ..clear()
      ..addAll(loadedNotes);
    vaultName = map['vaultName']?.toString().trim().isNotEmpty == true
        ? map['vaultName'].toString().trim()
        : vaultCatalog.firstWhere((e) => e.id == id).name;
    selectedId = null;
    searchText = '';
    selectedTag = null;
    graphMode = false;
  }

  Future<void> _writeRootReadme() async {
    final rootUri = appRootUri;
    if (rootUri == null) return;

    const content =
        'Tool Master veri klasörü\\n\\n'
        'Bu klasör uygulama tarafından otomatik oluşturuldu.\\n\\n'
        '- index.json: kasa listesi ve aktif kasa\\n'
        '- app_settings.json: uygulama ayarlarının taşınabilir kopyası\\n'
        '- vaults/<kasa-id>/vault.json: kasa verisi\\n'
        '- vaults/<kasa-id>/backup.json: bir önceki güvenli kopya\\n\\n'
        'Dosyaları elle değiştirirken önce yedek almanız önerilir.\\n';

    await _saf.writeFileBytes(
      rootUri,
      'README.txt',
      'text/plain',
      Uint8List.fromList(utf8.encode(content)),
      overwrite: true,
    );
  }

  Future<void> _writeAppSettingsSnapshot() async {
    final rootUri = appRootUri;
    if (rootUri == null) return;

    final prefs = await SharedPreferences.getInstance();
    final rawConfig = prefs.getString('dmpcs_hybrid_config_v06');

    final payload = const JsonEncoder.withIndent('  ').convert({
      'format': 'dmpcsnotebook-app-settings-v1',
      'savedAt': DateTime.now().toIso8601String(),
      'uiConfig': rawConfig == null
          ? null
          : (() {
              try {
                return jsonDecode(rawConfig);
              } catch (_) {
                return rawConfig;
              }
            })(),
      'storageDisplayName': storageDisplayName,
      'activeVaultId': activeVaultId,
    });

    await _saf.writeFileBytes(
      rootUri,
      'app_settings.json',
      'application/json',
      Uint8List.fromList(utf8.encode(payload)),
      overwrite: true,
    );
  }

  Future<void> switchVault(String id) async {
    if (!hasExternalStorage || id == activeVaultId) return;
    if (!vaultCatalog.any((item) => item.id == id)) return;

    switchingVault = true;
    notifyListeners();
    try {
      await flushSave();
      activeVaultId = id;
      await _loadVaultFile(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeVaultIdKey, id);
      await _writeIndex();
      await _saveLocalCacheOnly();
      storageError = null;
    } catch (error) {
      storageError = 'Kasa değiştirilemedi: $error';
    } finally {
      switchingVault = false;
      notifyListeners();
    }
  }

  Future<void> createVault(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (!hasExternalStorage) {
      throw const FormatException('Önce kayıt konumu seçilmelidir.');
    }

    await flushSave();
    final now = DateTime.now();
    final id = 'vault_${now.microsecondsSinceEpoch}';

    vaultCatalog.add(
      VaultCatalogEntry(
        id: id,
        name: clean,
        createdAt: now,
        updatedAt: now,
        noteCount: 0,
      ),
    );

    activeVaultId = id;
    vaultName = clean;
    notes.clear();
    selectedId = null;
    searchText = '';
    selectedTag = null;
    graphMode = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeVaultIdKey, id);
    notifyListeners();
    await _save();
  }

  Future<void> deleteVault(String id) async {
    if (!hasExternalStorage) return;
    if (vaultCatalog.length <= 1) {
      throw const FormatException('Son kasa silinemez.');
    }

    if (id == activeVaultId) {
      final next = vaultCatalog.firstWhere((item) => item.id != id);
      await switchVault(next.id);
    }

    final rootUri = appRootUri!;
    final dir = await _saf.child(rootUri, ['vaults', id]);
    if (dir != null) {
      await _saf.delete(dir.uri);
    }
    vaultCatalog.removeWhere((item) => item.id == id);
    await _writeIndex();
    notifyListeners();
  }

  Future<void> _saveLocalCacheOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      notes.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_notesKey, encoded);
    await prefs.setString(_vaultNameKey, vaultName);
  }

  Future<void> _save() async {
    saving = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(_notesKey);
      if (previous != null && previous.isNotEmpty) {
        try {
          _decodeNotes(previous);
          await prefs.setString(_backupKey, previous);
        } catch (_) {
          // Bozuk veri güvenli yedeğin üzerine yazılmaz.
        }
      }

      await _saveLocalCacheOnly();

      if (hasExternalStorage) {
        await _writeVaultFile(activeVaultId!);
        await _writeIndex();
        await _writeAppSettingsSnapshot();
      }

      lastSavedAt = DateTime.now();
      storageError = null;
    } catch (error) {
      storageError = 'Kayıt kaydedilemedi: $error';
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  void scheduleSave({
    Duration delay = const Duration(milliseconds: 650),
  }) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(delay, () {
      _save();
    });
  }

  Future<void> flushSave() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await _save();
  }

  void commitBulkChanges({
    bool immediate = false,
  }) {
    notifyListeners();
    scheduleSave(
      delay: immediate
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );
  }

  String exportVaultJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'dmpcsnotebook-v08',
      'exportedAt': DateTime.now().toIso8601String(),
      'vaultName': vaultName,
      'notes': notes.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> importVaultJson(
    String raw, {
    bool merge = false,
  }) async {
    final decoded = jsonDecode(raw);
    List<dynamic> noteData;
    String? importedName;

    if (decoded is List) {
      noteData = decoded;
    } else if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      noteData = (map['notes'] as List?) ?? const [];
      importedName = map['vaultName']?.toString();
    } else {
      throw const FormatException('Desteklenmeyen yedek formatı.');
    }

    final imported = noteData
        .map(
          (e) => NoteRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    if (merge) {
      final existingIds = notes.map((e) => e.id).toSet();
      for (final note in imported) {
        if (!existingIds.contains(note.id)) {
          notes.add(note);
        }
      }
    } else {
      notes
        ..clear()
        ..addAll(imported);
      if (importedName != null && importedName.trim().isNotEmpty) {
        vaultName = importedName.trim();
      }
    }

    selectedId = null;
    notifyListeners();
    await _save();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  NoteRecord? get selected {
    if (selectedId == null) return null;
    for (final note in notes) {
      if (note.id == selectedId) return note;
    }
    return null;
  }

  List<NoteRecord> get visibleNotes {
    Iterable<NoteRecord> data = notes.where((n) => !n.archived);

    if (selectedTag != null) {
      data = data.where((n) {
        final tags = <String>{...extractTags(n.content)};
        final propertyTags = n.properties['tags'];
        if (propertyTags != null) {
          for (final raw in propertyTags.split(',')) {
            final clean = raw.trim();
            if (clean.isNotEmpty) {
              tags.add(clean.startsWith('#') ? clean : '#$clean');
            }
          }
        }
        return tags.contains(selectedTag);
      });
    }

    if (searchText.trim().isNotEmpty) {
      data = runSearch(
        searchText,
        source: data.toList(),
      );
    }

    final list = data.toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  List<String> get allFolders {
    final set = <String>{'/'};
    for (final note in notes.where((n) => !n.archived)) {
      final folder = note.properties['folder']?.trim();
      if (folder != null && folder.isNotEmpty) {
        set.add(folder.startsWith('/') ? folder : '/$folder');
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get allTags {
    final set = <String>{};
    for (final n in notes.where((item) => !item.archived)) {
      set.addAll(extractTags(n.content));

      final propertyTags = n.properties['tags'];
      if (propertyTags != null) {
        for (final raw in propertyTags.split(',')) {
          final tag = raw.trim();
          if (tag.isNotEmpty) {
            set.add(tag.startsWith('#') ? tag : '#$tag');
          }
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> extractLinks(String content) {
    final regex = RegExp(r'\[\[([^\]]+)\]\]');
    return regex
        .allMatches(content)
        .map((m) => m.group(1)!.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> extractNoteLinks(NoteRecord note) {
    final buffer = StringBuffer(note.content);
    for (final value in note.properties.values) {
      if (value.trim().isNotEmpty) {
        buffer
          ..write('\n')
          ..write(value);
      }
    }
    return extractLinks(buffer.toString());
  }

  List<String> extractTags(String content) {
    final regex = RegExp(r'#([A-Za-z0-9_\-ğüşöçıİĞÜŞÖÇ]+)');
    return regex
        .allMatches(content)
        .map((m) => '#${m.group(1)}')
        .toSet()
        .toList();
  }

  String linkTarget(String rawLink) {
    var target = rawLink.trim();
    final pipe = target.indexOf('|');
    if (pipe >= 0) {
      target = target.substring(0, pipe);
    }
    final hash = target.indexOf('#');
    if (hash >= 0) {
      target = target.substring(0, hash);
    }
    final block = target.indexOf('^');
    if (block >= 0) {
      target = target.substring(0, block);
    }
    return target.trim();
  }

  String linkDisplay(String rawLink) {
    final pipe = rawLink.indexOf('|');
    if (pipe >= 0 && pipe + 1 < rawLink.length) {
      return rawLink.substring(pipe + 1).trim();
    }
    return rawLink.trim();
  }

  NoteRecord? resolveLink(String rawLink) {
    final target = linkTarget(rawLink).toLowerCase();
    if (target.isEmpty) return selected;

    for (final note in notes) {
      if (note.title.trim().toLowerCase() == target) {
        return note;
      }

      final aliases = note.properties['aliases'];
      if (aliases != null) {
        final values = aliases
            .split(',')
            .map((e) => e.trim().toLowerCase());
        if (values.contains(target)) {
          return note;
        }
      }
    }

    return null;
  }

  List<NoteRecord> backlinksFor(NoteRecord target) {
    if (target.title.trim().isEmpty) return [];

    return notes.where((source) {
      if (source.id == target.id || source.archived) return false;

      return extractNoteLinks(source).any((rawLink) {
        final resolved = resolveLink(rawLink);
        return resolved?.id == target.id;
      });
    }).toList();
  }

  List<NoteRecord> unlinkedMentionsFor(NoteRecord target) {
    final title = target.title.trim();
    if (title.length < 2) return [];

    final linkedIds = backlinksFor(target).map((e) => e.id).toSet();
    final q = title.toLowerCase();

    return notes.where((source) {
      if (source.id == target.id || source.archived) return false;
      if (linkedIds.contains(source.id)) return false;
      return source.content.toLowerCase().contains(q);
    }).toList();
  }

  List<NoteRecord> outgoingResolved(NoteRecord note) {
    final result = <NoteRecord>[];

    for (final link in extractNoteLinks(note)) {
      final resolved = resolveLink(link);
      if (resolved != null &&
          !result.any((item) => item.id == resolved.id)) {
        result.add(resolved);
      }
    }

    return result;
  }

  List<String> unresolvedLinks(NoteRecord note) {
    return extractNoteLinks(note)
        .where((link) => resolveLink(link) == null)
        .toList();
  }

  List<String> headingsFor(NoteRecord note) {
    final headings = <String>[];

    for (final line in note.content.split('\n')) {
      final trimmed = line.trim();
      if (RegExp(r'^#{1,6}\s+').hasMatch(trimmed)) {
        final heading = trimmed.replaceFirst(
          RegExp(r'^#{1,6}\s+'),
          '',
        );
        if (heading.isNotEmpty) headings.add(heading);
      }
    }

    return headings;
  }

  List<String> blocksFor(NoteRecord note) {
    final blocks = <String>[];
    final regex = RegExp(r'\^([A-Za-z0-9\-_]+)\s*$');

    for (final line in note.content.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        blocks.add(match.group(1)!);
      }
    }

    return blocks;
  }

  List<String> tasksFor(NoteRecord note) {
    return note.content.split('\n').where((line) {
      final value = line.trimLeft().toLowerCase();
      return value.startsWith('- [ ]') ||
          value.startsWith('- [x]');
    }).toList();
  }

  List<NoteRecord> runSearch(
    String query, {
    List<NoteRecord>? source,
  }) {
    Iterable<NoteRecord> result =
        source ?? notes.where((n) => !n.archived);

    final clean = query.trim();
    if (clean.isEmpty) return result.toList();

    final tokens = <String>[];
    final regex = RegExp(r'"([^"]+)"|(\[[^\]]+\])|(\S+)');

    for (final match in regex.allMatches(clean)) {
      final token =
          match.group(1) ?? match.group(2) ?? match.group(3);
      if (token != null && token.isNotEmpty) {
        tokens.add(token);
      }
    }

    for (final token in tokens) {
      if (token.startsWith('tag:')) {
        final raw = token.substring(4).trim();
        final tag = raw.startsWith('#') ? raw : '#$raw';
        result = result.where(
          (n) => extractTags(n.content).contains(tag),
        );
      } else if (token.startsWith('type:')) {
        final raw = token.substring(5).trim().toLowerCase();
        result = result.where(
          (n) =>
              n.type.name.toLowerCase() == raw ||
              n.type.label.toLowerCase() == raw,
        );
      } else if (token.startsWith('path:')) {
        final raw = token.substring(5).trim().toLowerCase();
        result = result.where(
          (n) =>
              (n.properties['folder'] ?? '')
                  .toLowerCase()
                  .contains(raw),
        );
      } else if (token.startsWith('link:')) {
        final raw = token.substring(5).trim().toLowerCase();
        result = result.where(
          (n) => extractNoteLinks(n).any(
            (link) =>
                linkTarget(link).toLowerCase().contains(raw),
          ),
        );
      } else if (token.startsWith('task-todo:')) {
        final raw = token.substring(10).trim().toLowerCase();
        result = result.where(
          (n) => n.content
              .split('\n')
              .where(
                (line) =>
                    line.trimLeft().startsWith('- [ ]'),
              )
              .any(
                (line) => line.toLowerCase().contains(raw),
              ),
        );
      } else if (token.startsWith('task-done:')) {
        final raw = token.substring(10).trim().toLowerCase();
        result = result.where(
          (n) => n.content
              .split('\n')
              .where(
                (line) => line
                    .trimLeft()
                    .toLowerCase()
                    .startsWith('- [x]'),
              )
              .any(
                (line) => line.toLowerCase().contains(raw),
              ),
        );
      } else if (token.startsWith('task:')) {
        final raw = token.substring(5).trim().toLowerCase();
        result = result.where(
          (n) => tasksFor(n).any(
            (line) => line.toLowerCase().contains(raw),
          ),
        );
      } else if (token.startsWith('[') &&
          token.endsWith(']')) {
        final inner = token.substring(1, token.length - 1);
        final colon = inner.indexOf(':');

        if (colon < 0) {
          final key = inner.toLowerCase();
          result = result.where(
            (n) => n.properties.keys
                .any((k) => k.toLowerCase() == key),
          );
        } else {
          final key =
              inner.substring(0, colon).trim().toLowerCase();
          final value =
              inner.substring(colon + 1).trim().toLowerCase();

          result = result.where(
            (n) => n.properties.entries.any(
              (entry) =>
                  entry.key.toLowerCase() == key &&
                  entry.value.toLowerCase().contains(value),
            ),
          );
        }
      } else {
        final raw = token.toLowerCase();
        result = result.where(
          (n) =>
              n.title.toLowerCase().contains(raw) ||
              n.content.toLowerCase().contains(raw) ||
              n.properties.entries.any(
                (entry) =>
                    entry.key.toLowerCase().contains(raw) ||
                    entry.value.toLowerCase().contains(raw),
              ),
        );
      }
    }

    return result.toList();
  }


  Future<JsonImportResult> importGenericJson(
    dynamic decoded, {
    bool merge = true,
    String? titleKey,
    String? contentKey,
    String? typeKey,
    String? tagsKey,
    String? folderKey,
  }) async {
    final rows = _normalizeJsonRows(decoded);

    if (rows.isEmpty) {
      throw const FormatException(
        'JSON içinde aktarılabilir kayıt bulunamadı.',
      );
    }

    final imported = <NoteRecord>[];
    var skipped = 0;

    if (!merge) {
      notes.clear();
      selectedId = null;
    }

    for (final row in rows) {
      if (row is! Map) {
        skipped++;
        continue;
      }

      final map = Map<String, dynamic>.from(row);

      final resolvedTitleKey = titleKey ?? _guessJsonKey(
        map,
        const ['title', 'name', 'ad', 'isim', 'başlık', 'baslik'],
      );
      final resolvedContentKey = contentKey ?? _guessJsonKey(
        map,
        const [
          'content',
          'body',
          'description',
          'text',
          'notes',
          'not',
          'açıklama',
          'aciklama',
          'icerik',
          'içerik',
        ],
      );
      final resolvedTypeKey = typeKey ?? _guessJsonKey(
        map,
        const ['type', 'kind', 'category', 'tur', 'tür'],
      );
      final resolvedTagsKey = tagsKey ?? _guessJsonKey(
        map,
        const ['tags', 'labels', 'etiket', 'etiketler'],
      );
      final resolvedFolderKey = folderKey ?? _guessJsonKey(
        map,
        const ['folder', 'path', 'klasor', 'klasör'],
      );

      final title = _jsonValueToString(
        resolvedTitleKey == null ? null : map[resolvedTitleKey],
      ).trim();

      final body = _jsonValueToString(
        resolvedContentKey == null ? null : map[resolvedContentKey],
      ).trim();

      final rawType = _jsonValueToString(
        resolvedTypeKey == null ? null : map[resolvedTypeKey],
      ).trim();

      final rawFolder = _jsonValueToString(
        resolvedFolderKey == null ? null : map[resolvedFolderKey],
      ).trim();

      final note = NoteRecord.blank(
        id: DateTime.now().microsecondsSinceEpoch.toString() +
            imported.length.toString(),
        type: _noteTypeFromJson(rawType),
      );

      note.title = title;
      note.content = body;
      note.properties['folder'] =
          rawFolder.isEmpty ? '/' : rawFolder;
      note.propertyTypes['folder'] = 'text';

      final rawTags =
          resolvedTagsKey == null ? null : map[resolvedTagsKey];

      if (rawTags != null) {
        final tags = <String>[];

        if (rawTags is List) {
          for (final tag in rawTags) {
            final clean = _jsonValueToString(tag).trim();
            if (clean.isNotEmpty) {
              tags.add(
                clean.startsWith('#') ? clean : '#$clean',
              );
            }
          }
        } else {
          for (final part in
              _jsonValueToString(rawTags).split(',')) {
            final clean = part.trim();
            if (clean.isNotEmpty) {
              tags.add(
                clean.startsWith('#') ? clean : '#$clean',
              );
            }
          }
        }

        if (tags.isNotEmpty) {
          final tagLine = tags.join(' ');
          note.content = note.content.trim().isEmpty
              ? tagLine
              : '${note.content.trim()}\n\n$tagLine';
        }
      }

      final consumed = <String>{
        if (resolvedTitleKey != null) resolvedTitleKey,
        if (resolvedContentKey != null) resolvedContentKey,
        if (resolvedTypeKey != null) resolvedTypeKey,
        if (resolvedTagsKey != null) resolvedTagsKey,
        if (resolvedFolderKey != null) resolvedFolderKey,
      };

      for (final entry in map.entries) {
        if (consumed.contains(entry.key)) continue;
        if (entry.value == null) continue;

        final value = _jsonValueToString(entry.value).trim();
        if (value.isEmpty) continue;

        note.properties[entry.key] = value;
        note.propertyTypes[entry.key] =
            _inferJsonPropertyType(entry.value);
      }

      note.updatedAt = DateTime.now();
      note.createdAt = DateTime.now();

      notes.add(note);
      imported.add(note);
    }

    if (imported.isNotEmpty) {
      selectedId = imported.first.id;
    }

    notifyListeners();
    await _save();

    return JsonImportResult(
      imported: imported.length,
      skipped: skipped,
      totalRows: rows.length,
    );
  }

  List<dynamic> _normalizeJsonRows(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);

      for (final key in const [
        'notes',
        'items',
        'records',
        'data',
        'entries',
        'results',
      ]) {
        final value = map[key];
        if (value is List) {
          return value;
        }
      }

      return [map];
    }

    return const [];
  }

  String? _guessJsonKey(
    Map<String, dynamic> map,
    List<String> candidates,
  ) {
    for (final key in map.keys) {
      final lower = key.toLowerCase();
      for (final candidate in candidates) {
        if (lower == candidate.toLowerCase()) {
          return key;
        }
      }
    }
    return null;
  }

  String _jsonValueToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is List) {
      return value.map(_jsonValueToString).join(', ');
    }
    if (value is Map) {
      return jsonEncode(value);
    }
    return value.toString();
  }

  NoteType _noteTypeFromJson(String raw) {
    final value = raw.trim().toLowerCase();

    for (final type in NoteType.values) {
      if (type.name.toLowerCase() == value ||
          type.label.toLowerCase() == value) {
        return type;
      }
    }

    if (value.contains('npc') ||
        value.contains('character') ||
        value.contains('karakter')) {
      return NoteType.npc;
    }
    if (value.contains('monster') ||
        value.contains('creature') ||
        value.contains('canavar')) {
      return NoteType.monster;
    }
    if (value.contains('session') ||
        value.contains('oturum')) {
      return NoteType.session;
    }
    if (value.contains('location') ||
        value.contains('place') ||
        value.contains('mekan') ||
        value.contains('mekân')) {
      return NoteType.location;
    }
    if (value.contains('quest') ||
        value.contains('görev') ||
        value.contains('gorev')) {
      return NoteType.quest;
    }
    if (value.contains('item') ||
        value.contains('eşya') ||
        value.contains('esya')) {
      return NoteType.item;
    }
    if (value.contains('organization') ||
        value.contains('faction') ||
        value.contains('organizasyon')) {
      return NoteType.organization;
    }
    if (value.contains('lore')) {
      return NoteType.lore;
    }
    if (value.contains('rule') ||
        value.contains('kural')) {
      return NoteType.rule;
    }
    if (value.contains('journal') ||
        value.contains('günlük') ||
        value.contains('gunluk')) {
      return NoteType.journal;
    }
    if (value.contains('handout')) {
      return NoteType.handout;
    }
    if (value.contains('template') ||
        value.contains('şablon') ||
        value.contains('sablon')) {
      return NoteType.template;
    }

    return NoteType.note;
  }

  String _inferJsonPropertyType(dynamic value) {
    if (value is bool) return 'checkbox';
    if (value is num) return 'number';
    if (value is List) return 'list';

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return 'date';
    }

    return 'text';
  }

  int get orphanCount {
    var count = 0;
    for (final note in notes.where((n) => !n.archived)) {
      if (extractNoteLinks(note).isEmpty &&
          backlinksFor(note).isEmpty) {
        count++;
      }
    }
    return count;
  }

  Future<NoteRecord> create(NoteType type) async {
    final note = NoteRecord.blank(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
    );
    notes.insert(0, note);
    selectedId = note.id;
    graphMode = false;
    notifyListeners();
    await _save();
    return note;
  }

  Future<void> updateNote(
    NoteRecord note, {
    String? title,
    String? content,
    NoteType? type,
    String? visibility,
  }) async {
    if (title != null) note.title = title;
    if (content != null) note.content = content;
    if (type != null) note.type = type;
    if (visibility != null) note.visibility = visibility;
    note.updatedAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> togglePin(NoteRecord note) async {
    note.pinned = !note.pinned;
    note.updatedAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> toggleBookmark(NoteRecord note) async {
    note.bookmarked = !note.bookmarked;
    notifyListeners();
    await _save();
  }

  Future<NoteRecord> createDailyNote() async {
    final now = DateTime.now();
    final title =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    for (final note in notes) {
      if (!note.archived &&
          note.type == NoteType.journal &&
          note.title == title) {
        select(note.id);
        return note;
      }
    }

    final note = await create(NoteType.journal);
    note.title = title;
    note.updatedAt = now;
    await _save();
    notifyListeners();
    return note;
  }

  Future<NoteRecord> createFromTemplate(
    NoteRecord template,
  ) async {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final note = await create(NoteType.note);
    note.content = template.content
        .replaceAll('{{date}}', date)
        .replaceAll('{{time}}', time)
        .replaceAll('{{title}}', '');
    note.properties = Map<String, String>.from(
      template.properties,
    );
    note.propertyTypes = Map<String, String>.from(
      template.propertyTypes,
    );
    note.updatedAt = now;
    await _save();
    notifyListeners();
    return note;
  }

  Future<NoteRecord> duplicate(NoteRecord source) async {
    final now = DateTime.now();
    final copy = NoteRecord(
      id: now.microsecondsSinceEpoch.toString(),
      title: source.title.trim().isEmpty
          ? ''
          : '${source.title} — Kopya',
      content: source.content,
      type: source.type,
      visibility: source.visibility,
      pinned: false,
      archived: false,
      bookmarked: false,
      createdAt: now,
      updatedAt: now,
      properties: Map<String, String>.from(source.properties),
      propertyTypes: Map<String, String>.from(source.propertyTypes),
      detailFields: List<String>.from(source.detailFields),
    );
    notes.insert(0, copy);
    selectedId = copy.id;
    notifyListeners();
    await _save();
    return copy;
  }

  Future<void> archive(NoteRecord note) async {
    note.archived = true;
    if (selectedId == note.id) selectedId = null;
    notifyListeners();
    await _save();
  }

  Future<void> restore(NoteRecord note) async {
    note.archived = false;
    note.updatedAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> deleteForever(NoteRecord note) async {
    notes.removeWhere((n) => n.id == note.id);
    if (selectedId == note.id) selectedId = null;
    notifyListeners();
    await _save();
  }

  Future<void> addProperty(
    NoteRecord note,
    String key,
    String value, {
    String type = 'text',
  }) async {
    note.properties[key] = value;
    note.propertyTypes[key] = type;
    note.updatedAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> removeProperty(
    NoteRecord note,
    String key,
  ) async {
    note.properties.remove(key);
    note.propertyTypes.remove(key);
    note.updatedAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> renameVault(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    vaultName = v;
    final active = activeVaultDescriptor;
    if (active != null) {
      active.name = v;
      active.updatedAt = DateTime.now();
    }
    notifyListeners();
    await _save();
  }

  void select(String id) {
    selectedId = id;
    graphMode = false;
    notifyListeners();
  }

  void clearSelection() {
    selectedId = null;
    notifyListeners();
  }

  void setSearch(String value) {
    searchText = value;
    graphMode = false;
    selectedId = null;
    notifyListeners();
  }

  void setTag(String? tag) {
    selectedTag = tag;
    graphMode = false;
    notifyListeners();
  }

  void showGraph() {
    graphMode = true;
    selectedId = null;
    notifyListeners();
  }
}

class VaultWorkspace extends StatefulWidget {
  const VaultWorkspace({super.key});

  @override
  State<VaultWorkspace> createState() => _VaultWorkspaceState();
}

class _VaultWorkspaceState extends State<VaultWorkspace> {
  bool rightPanelOpen = true;

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    if (!store.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tablet = constraints.maxWidth >= 900;
        final wide = constraints.maxWidth >= 1180;

        if (!tablet) {
          return _CompactLayout(
            onCreate: () => _showCreateSheet(context),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: wide ? 278 : 240,
                  child: _LeftSidebar(
                    onCreate: () => _showCreateSheet(context),
                  ),
                ),
                const VerticalDivider(),
                Expanded(
                  child: _CenterWorkspace(
                    onToggleRightPanel: () {
                      setState(() {
                        rightPanelOpen = !rightPanelOpen;
                      });
                    },
                    rightPanelOpen: rightPanelOpen,
                    onCreate: () => _showCreateSheet(context),
                  ),
                ),
                if (wide && rightPanelOpen) ...[
                  const VerticalDivider(),
                  const SizedBox(
                    width: 330,
                    child: _InspectorPanel(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final store = VaultScope.of(context);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Yeni Kayıt',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'İçerik eklenmez. Yalnızca kayıt türü seçilir ve boş editör açılır.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount:
                      MediaQuery.sizeOf(context).width >= 900 ? 4 : 3,
                  childAspectRatio: 1.35,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final type in NoteType.values)
                      _CreateTypeCard(
                        type: type,
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await store.create(type);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompactLayout extends StatelessWidget {
  final VoidCallback onCreate;
  const _CompactLayout({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final selected = store.selected;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selected == null
              ? store.vaultName
              : selected.title.trim().isEmpty
                  ? 'Başlıksız'
                  : selected.title,
        ),
        leading: selected == null
            ? null
            : IconButton(
                onPressed: store.clearSelection,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        actions: [
          if (selected != null)
            _NoteOverflowMenu(note: selected),
        ],
      ),
      drawer: selected == null ? null : const Drawer(
        child: SafeArea(child: _LeftSidebar()),
      ),
      body: selected == null
          ? const _CompactLibrary()
          : const _NoteEditor(),
      floatingActionButton: selected == null
          ? FloatingActionButton.extended(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni'),
            )
          : null,
    );
  }
}

class _CompactLibrary extends StatelessWidget {
  const _CompactLibrary();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.visibleNotes;

    if (store.graphMode) {
      return const _GraphView();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          onChanged: store.setSearch,
          decoration: const InputDecoration(
            hintText: 'Ara...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 16),
        if (notes.isEmpty)
          const _EmptyLibrary()
        else
          for (final note in notes) ...[
            _NoteListTile(note: note),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _LeftSidebar extends StatelessWidget {
  final VoidCallback? onCreate;

  const _LeftSidebar({this.onCreate});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return Container(
      color: const Color(0xFF0D1015),
      child: Column(
        children: [
          _VaultHeader(
            onCreate: onCreate,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              onChanged: store.setSearch,
              decoration: const InputDecoration(
                hintText: 'Hızlı ara',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
              children: [
                _SidebarAction(
                  icon: Icons.notes_rounded,
                  label: 'Tüm Notlar',
                  count: store.notes
                      .where((n) => !n.archived)
                      .length
                      .toString(),
                  selected:
                      !store.graphMode && store.selectedTag == null,
                  onTap: () {
                    store.setTag(null);
                    store.clearSelection();
                  },
                ),
                _SidebarAction(
                  icon: Icons.push_pin_outlined,
                  label: 'Sabitlenenler',
                  count: store.notes
                      .where((n) => n.pinned && !n.archived)
                      .length
                      .toString(),
                  onTap: () {
                    store.setTag(null);
                    store.clearSelection();
                    store.setSearch('');
                  },
                ),
                _SidebarAction(
                  icon: Icons.search_rounded,
                  label: 'Gelişmiş Arama',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _AdvancedSearchPage(),
                      ),
                    );
                  },
                ),
                _SidebarAction(
                  icon: Icons.bolt_rounded,
                  label: 'Hızlı Geçiş',
                  onTap: () => _showQuickSwitcher(context),
                ),
                _SidebarAction(
                  icon: Icons.hub_outlined,
                  label: 'Grafik',
                  count: store.notes.length.toString(),
                  selected: store.graphMode,
                  onTap: store.showGraph,
                ),
                _SidebarAction(
                  icon: Icons.hub_outlined,
                  label: 'Yerel Grafik',
                  onTap: () {
                    if (store.selected == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Önce bir not aç.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _LocalGraphPage(),
                      ),
                    );
                  },
                ),
                _SidebarAction(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Yer İmleri',
                  count: store.notes
                      .where((n) => n.bookmarked && !n.archived)
                      .length
                      .toString(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _BookmarksPage(),
                      ),
                    );
                  },
                ),
                _SidebarAction(
                  icon: Icons.table_chart_outlined,
                  label: 'Bases',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _BasesPage(),
                      ),
                    );
                  },
                ),
                _SidebarAction(
                  icon: Icons.dashboard_outlined,
                  label: 'Canvas',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _CanvasPage(),
                      ),
                    );
                  },
                ),
                _SidebarAction(
                  icon: Icons.calendar_today_outlined,
                  label: 'Bugünün Notu',
                  onTap: () => store.createDailyNote(),
                ),
                _SidebarAction(
                  icon: Icons.book_outlined,
                  label: 'Şablondan Oluştur',
                  onTap: () => _showTemplates(context),
                ),
                _SidebarAction(
                  icon: Icons.link_off_rounded,
                  label: 'Bağlantısız',
                  count: store.orphanCount.toString(),
                  onTap: () {
                    store.clearSelection();
                    store.setTag(null);
                  },
                ),
                const SizedBox(height: 12),
                const _SidebarSectionTitle('KLASÖRLER'),
                for (final folder in store.allFolders)
                  _SidebarAction(
                    icon: folder == '/'
                        ? Icons.folder_open_rounded
                        : Icons.folder_outlined,
                    label: folder == '/' ? 'Kök' : folder,
                    onTap: () {
                      store.setTag(null);
                      store.setSearch(
                        folder == '/' ? '' : 'path:$folder',
                      );
                    },
                  ),
                const SizedBox(height: 12),
                const _SidebarSectionTitle('ETİKETLER'),
                if (store.allTags.isEmpty)
                  const _SidebarMutedText('Henüz etiket yok')
                else
                  for (final tag in store.allTags)
                    _SidebarAction(
                      icon: Icons.tag_rounded,
                      label: tag,
                      selected: store.selectedTag == tag,
                      onTap: () => store.setTag(tag),
                    ),
                const SizedBox(height: 12),
                const _SidebarSectionTitle('TÜRLER'),
                for (final type in NoteType.values)
                  _SidebarAction(
                    icon: Icons.circle_outlined,
                    label: type.label,
                    count: store.notes
                        .where(
                          (n) => n.type == type && !n.archived,
                        )
                        .length
                        .toString(),
                    onTap: () {},
                  ),
                const SizedBox(height: 12),
                const _SidebarSectionTitle('SİSTEM'),
                _SidebarAction(
                  icon: Icons.archive_outlined,
                  label: 'Arşiv',
                  count: store.notes
                      .where((n) => n.archived)
                      .length
                      .toString(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const HybridArchivePage(),
                      ),
                    );
                  },
                ),
                _SidebarAction(
                  icon: Icons.settings_outlined,
                  label: 'Kasa Ayarları',
                  onTap: () => _showVaultSettings(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVaultSettings(BuildContext context) {
    final store = VaultScope.of(context);
    final controller = TextEditingController(text: store.vaultName);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kasa Ayarları'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Kasa adı',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              store.renameVault(controller.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _VaultHeader extends StatelessWidget {
  final VoidCallback? onCreate;
  const _VaultHeader({this.onCreate});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.vaultName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Tool Master',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

class _CenterWorkspace extends StatelessWidget {
  final VoidCallback onToggleRightPanel;
  final bool rightPanelOpen;
  final VoidCallback onCreate;

  const _CenterWorkspace({
    required this.onToggleRightPanel,
    required this.rightPanelOpen,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    if (store.graphMode) {
      return Column(
        children: [
          _WorkspaceTopbar(
            title: 'Grafik',
            onCreate: onCreate,
            onToggleRightPanel: onToggleRightPanel,
            rightPanelOpen: rightPanelOpen,
          ),
          const Expanded(child: _GraphView()),
        ],
      );
    }

    if (store.selected != null) {
      return Column(
        children: [
          _WorkspaceTopbar(
            title: store.selected!.title.trim().isEmpty
                ? 'Başlıksız'
                : store.selected!.title,
            onCreate: onCreate,
            onToggleRightPanel: onToggleRightPanel,
            rightPanelOpen: rightPanelOpen,
          ),
          const Expanded(child: _NoteEditor()),
        ],
      );
    }

    return Column(
      children: [
        _WorkspaceTopbar(
          title: 'Notlar',
          onCreate: onCreate,
          onToggleRightPanel: onToggleRightPanel,
          rightPanelOpen: rightPanelOpen,
        ),
        Expanded(
          child: _LibraryPane(onCreate: onCreate),
        ),
      ],
    );
  }
}

class _WorkspaceTopbar extends StatelessWidget {
  final String title;
  final VoidCallback onCreate;
  final VoidCallback onToggleRightPanel;
  final bool rightPanelOpen;

  const _WorkspaceTopbar({
    required this.title,
    required this.onCreate,
    required this.onToggleRightPanel,
    required this.rightPanelOpen,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Komut paleti',
            onPressed: () => _showCommandPalette(context),
            icon: const Icon(Icons.terminal_rounded),
          ),
          IconButton(
            tooltip: 'Sağ panel',
            onPressed: onToggleRightPanel,
            icon: Icon(
              rightPanelOpen
                  ? Icons.last_page_rounded
                  : Icons.first_page_rounded,
            ),
          ),
          if (store.selected != null)
            _NoteOverflowMenu(note: store.selected!),
        ],
      ),
    );
  }

  void _showCommandPalette(BuildContext context) {
    _showVaultCommandPalette(context);
  }
}

class _LibraryPane extends StatelessWidget {
  final VoidCallback onCreate;
  const _LibraryPane({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.visibleNotes;

    if (notes.isEmpty) {
      return _EmptyLibrary(onCreate: onCreate);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Row(
          children: [
            Text(
              '${notes.length} kayıt',
              style: const TextStyle(color: AppColors.muted),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.sort_rounded, size: 18),
              label: const Text('Son düzenlenen'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final note in notes) ...[
          _NoteListTile(note: note),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final VoidCallback? onCreate;
  const _EmptyLibrary({this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _FantasyIcon('book_open', size: 72),
              const SizedBox(height: 20),
              const Text(
                'Kasa boş',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hiçbir NPC, oturum, bağlantı veya örnek içerik eklenmedi. '
                'İlk kaydı sen oluşturduğunda kasa büyümeye başlayacak.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              if (onCreate != null)
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('İlk Kaydı Oluştur'),
                ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _FeatureChip('[[Bağlantılar]]'),
                  _FeatureChip('#Etiketler'),
                  _FeatureChip('Backlink'),
                  _FeatureChip('Özellikler'),
                  _FeatureChip('Grafik'),
                  _FeatureChip('DM Görünürlüğü'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteListTile extends StatelessWidget {
  final NoteRecord note;
  const _NoteListTile({required this.note});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final links = store.extractNoteLinks(note).length;
    final tags = store.extractTags(note.content);

    return Material(
      color: store.selectedId == note.id
          ? AppColors.panel2
          : AppColors.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => store.select(note.id),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.panel3,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: _FantasyIcon(
                  note.type.iconAsset,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title.trim().isEmpty
                                ? 'Başlıksız'
                                : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (note.pinned)
                          const Icon(
                            Icons.push_pin_rounded,
                            size: 16,
                            color: AppColors.gold,
                          ),
                        if (note.bookmarked)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.bookmark_rounded,
                              size: 16,
                              color: AppColors.blue,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${note.type.label} • $links bağlantı'
                      '${tags.isEmpty ? '' : ' • ${tags.take(2).join(' ')}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _NoteOverflowMenu extends StatelessWidget {
  final NoteRecord note;

  const _NoteOverflowMenu({required this.note});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return PopupMenuButton<String>(
      tooltip: 'Not menüsü',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        switch (value) {
          case 'pin':
            store.togglePin(note);
            break;
          case 'bookmark':
            store.toggleBookmark(note);
            break;
          case 'duplicate':
            store.duplicate(note);
            break;
          case 'copy_link':
            Clipboard.setData(
              ClipboardData(
                text: '[[${note.title.trim().isEmpty ? 'Başlıksız' : note.title.trim()}]]',
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Not bağlantısı panoya kopyalandı.')),
            );
            break;
          case 'export_json':
            Clipboard.setData(
              ClipboardData(
                text: const JsonEncoder.withIndent('  ').convert(note.toJson()),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kayıt JSON olarak panoya kopyalandı.')),
            );
            break;
          case 'related':
            _showCodexRelatedRecords(context, note);
            break;
          case 'stats':
            _showCodexRecordStats(context, note);
            break;
          case 'focus':
            store.select(note.id);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CodexFocusPage(noteId: note.id),
              ),
            );
            break;
          case 'archive':
            store.archive(note);
            break;
          case 'delete':
            _showDeleteNoteDialog(context, note);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pin',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              note.pinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
            ),
            title: Text(
              note.pinned ? 'Sabitlemeyi kaldır' : 'Sabitle',
            ),
          ),
        ),
        PopupMenuItem(
          value: 'bookmark',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              note.bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
            title: Text(
              note.bookmarked
                  ? 'Yer iminden kaldır'
                  : 'Yer imine ekle',
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.copy_all_outlined),
            title: Text('Kopyasını oluştur'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'copy_link',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.link_rounded),
            title: Text('Not bağlantısını kopyala'),
          ),
        ),
        const PopupMenuItem(
          value: 'export_json',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.data_object_rounded),
            title: Text('Bu kaydı JSON kopyala'),
          ),
        ),
        const PopupMenuItem(
          value: 'related',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_tree_outlined),
            title: Text('İlişkili kayıtlar'),
          ),
        ),
        const PopupMenuItem(
          value: 'stats',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.analytics_outlined),
            title: Text('Kayıt istatistikleri'),
          ),
        ),
        const PopupMenuItem(
          value: 'focus',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.center_focus_strong_outlined),
            title: Text('Odak modu'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'archive',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.archive_outlined),
            title: Text('Arşivle'),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline_rounded,
              color: AppColors.red,
            ),
            title: Text(
              'Kalıcı sil',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ),
      ],
    );
  }
}

void _showDeleteNoteDialog(
  BuildContext context,
  NoteRecord note,
) {
  final store = VaultScope.of(context);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Kalıcı silinsin mi?'),
      content: const Text(
        'Bu kayıt kalıcı olarak silinecek.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () {
            store.deleteForever(note);
            Navigator.pop(dialogContext);
          },
          child: const Text('Sil'),
        ),
      ],
    ),
  );
}

class _TypeSpecificNoteWorkspace extends StatelessWidget {
  final NoteRecord note;

  const _TypeSpecificNoteWorkspace({required this.note});

  @override
  Widget build(BuildContext context) {
    switch (note.type) {
      case NoteType.note:
        return _GeneralNoteWorkspace(note: note);
      case NoteType.npc:
        return _NpcWorkspace(note: note);
      case NoteType.monster:
        return _MonsterWorkspace(note: note);
      case NoteType.session:
        return _SessionWorkspace(note: note);
      case NoteType.location:
        return _LocationWorkspace(note: note);
      case NoteType.quest:
        return _QuestWorkspace(note: note);
      case NoteType.item:
        return _ItemWorkspace(note: note);
      case NoteType.organization:
        return _OrganizationWorkspace(note: note);
      case NoteType.lore:
        return _LoreWorkspace(note: note);
      case NoteType.rule:
        return _RuleWorkspace(note: note);
      case NoteType.journal:
        return _JournalWorkspace(note: note);
      case NoteType.handout:
        return _HandoutWorkspace(note: note);
      case NoteType.template:
        return _TemplateWorkspace(note: note);
    }
  }
}

class _WorkspaceHero extends StatelessWidget {
  final NoteRecord note;
  final String title;
  final String subtitle;
  final IconData icon;

  const _WorkspaceHero({
    required this.note,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF241B32), Color(0xFF141820)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              _WorkspaceCounter(
                value: '${store.extractNoteLinks(note).length}',
                label: 'link',
              ),
              const SizedBox(height: 5),
              _WorkspaceCounter(
                value: '${store.backlinksFor(note).length}',
                label: 'back',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCounter extends StatelessWidget {
  final String value;
  final String label;

  const _WorkspaceCounter({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const _WorkspaceCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.purple),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 11),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _WorkspaceFieldGrid extends StatelessWidget {
  final NoteRecord note;
  final List<String> fields;
  final int columns;

  const _WorkspaceFieldGrid({
    required this.note,
    required this.fields,
    this.columns = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveColumns = constraints.maxWidth < 560 ? 1 : columns;
        final width = effectiveColumns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 8 * (effectiveColumns - 1)) /
                effectiveColumns;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final field in fields)
              SizedBox(
                width: width,
                child: _StoredNotePropertyField(
                  note: note,
                  label: field,
                  icon: _StructuredCreatorPageState._fieldIcon(field),
                  multiline: _StructuredCreatorPageState._isLongField(field),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AbilityGrid extends StatelessWidget {
  final NoteRecord note;
  const _AbilityGrid({required this.note});

  @override
  Widget build(BuildContext context) {
    const fields = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth < 520 ? 3 : 6;
        final width = (constraints.maxWidth - ((cols - 1) * 6)) / cols;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final field in fields)
              SizedBox(
                width: width,
                child: _StoredNotePropertyField(
                  note: note,
                  label: field,
                  icon: Icons.analytics_outlined,
                  multiline: false,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final NoteRecord note;
  final String propertyKey;
  final String title;
  final String subtitle;

  const _ConnectionCard({
    required this.note,
    required this.propertyKey,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final raw = note.properties[propertyKey] ?? '';
    final links = store.extractLinks(raw);

    return _WorkspaceCard(
      title: title,
      subtitle: subtitle,
      icon: Icons.hub_outlined,
      trailing: IconButton(
        tooltip: 'Not bağla',
        onPressed: () => _pickRelation(context),
        icon: const Icon(Icons.add_link_rounded),
      ),
      children: [
        if (links.isEmpty)
          const Text(
            'Henüz bağlantı yok.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final rawLink in links)
                ActionChip(
                  avatar: const Icon(Icons.link_rounded, size: 15),
                  label: Text(store.linkDisplay(rawLink)),
                  onPressed: () {
                    final target = store.resolveLink(rawLink);
                    if (target != null) store.select(target.id);
                  },
                ),
            ],
          ),
      ],
    );
  }

  void _pickRelation(BuildContext context) {
    final store = VaultScope.of(context);
    final candidates = store.notes
        .where((item) => !item.archived && item.id != note.id)
        .toList();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$title — bağlantı ekle'),
        content: SizedBox(
          width: 520,
          height: 420,
          child: candidates.isEmpty
              ? const Center(
                  child: Text(
                    'Bağlanabilecek başka kayıt yok.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView(
                  children: [
                    for (final item in candidates)
                      ListTile(
                        leading: _FantasyIcon(item.type.iconAsset, size: 25),
                        title: Text(
                          item.title.trim().isEmpty ? 'Başlıksız' : item.title,
                        ),
                        subtitle: Text(item.type.label),
                        onTap: () {
                          final titleValue = item.title.trim();
                          if (titleValue.isEmpty) return;
                          final current = note.properties[propertyKey] ?? '';
                          final link = '[[$titleValue]]';
                          if (!current.contains(link)) {
                            store.addProperty(
                              note,
                              propertyKey,
                              current.trim().isEmpty
                                  ? link
                                  : '${current.trim()}\n$link',
                            );
                          }
                          Navigator.pop(dialogContext);
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GeneralNoteWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _GeneralNoteWorkspace({required this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WorkspaceHero(
          note: note,
          title: 'Gelişmiş Not',
          subtitle: 'Serbest metnin yanında durum, kaynak, konu ve bağlantıları ayrı yönet.',
          icon: Icons.note_alt_outlined,
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Not Özeti',
          icon: Icons.subject_rounded,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const ['Kategori', 'Durum', 'Konu', 'Özet'],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _ConnectionCard(
          note: note,
          propertyKey: 'Bağlantılı Notlar',
          title: 'Bağlantılar',
          subtitle: 'Bu notun başka kayıtlarla ilişkisini kur.',
        ),
      ],
    );
  }
}

class _NpcWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _NpcWorkspace({required this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WorkspaceHero(
          note: note,
          title: 'NPC Dosyası',
          subtitle: 'Kimlik, masada canlandırma, motivasyon, sır ve ilişki ağı tek yerde.',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Kimlik Kartı',
          subtitle: 'Masada ilk bakacağın çekirdek bilgiler.',
          icon: Icons.badge_outlined,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const [
                'Irk / Tür', 'Yaş', 'Meslek / Rol', 'Ünvan / Lakap',
                'Konum', 'Fraksiyon', 'Durum'
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Rolplay Paneli',
          icon: Icons.theater_comedy_outlined,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const [
                'Görünüş', 'Kişilik', 'Ses / Konuşma', 'İdeal',
                'Bağ', 'Kusur', 'Alışkanlık'
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Motivasyon & Baskı Noktaları',
          icon: Icons.flag_outlined,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const [
                'Motivasyon', 'Kısa Vadeli Hedef', 'Uzun Vadeli Hedef', 'Korku'
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Bilgi Katmanları',
          subtitle: 'Oyuncuya açık olanla DM bilgisini ayır.',
          icon: Icons.lock_outline_rounded,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const [
                'Oyuncuların Bildiği', 'DM Bilgisi', 'Sır', 'Söylenti / Yanlış Bilgi'
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _ConnectionCard(
          note: note,
          propertyKey: 'İlişkiler',
          title: 'İlişki Ağı',
          subtitle: 'NPC, organizasyon, mekân ve diğer kayıtları bağla.',
        ),
      ],
    );
  }
}

class _MonsterWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _MonsterWorkspace({required this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WorkspaceHero(
          note: note,
          title: 'Canavar Stat Block',
          subtitle: 'Savaş değerleri, ability score, aksiyon, taktik ve encounter bağlantıları.',
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Çekirdek Statlar',
          icon: Icons.shield_outlined,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              columns: 3,
              fields: const [
                'Boyut', 'Tür', 'Alignment', 'CR', 'Proficiency Bonus',
                'AC', 'HP', 'Hit Dice', 'Hız'
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Ability Scores',
          icon: Icons.analytics_outlined,
          children: [_AbilityGrid(note: note)],
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Savunma & Duyular',
          icon: Icons.security_outlined,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const [
                'Saving Throws', 'Skills', 'Vulnerabilities', 'Dirençler',
                'Bağışıklıklar', 'Condition Immunities', 'Duyular',
                'Passive Perception', 'Languages'
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Aksiyon & Davranış',
          icon: Icons.flash_on_outlined,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const [
                'Saldırılar', 'Özellikler', 'Bonus Actions', 'Reactions',
                'Legendary Actions', 'Lair Actions', 'Mythic Actions',
                'Savaş Taktiği', 'Kaçış / Teslim Davranışı',
                'Hedef Önceliği', 'Loot'
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _ConnectionCard(
          note: note,
          propertyKey: 'Encounter Bağlantıları',
          title: 'Encounter Kullanımı',
          subtitle: 'Bu canavarı kullandığın oturum, mekân ve karşılaşmaları bağla.',
        ),
      ],
    );
  }
}

class _SessionWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _SessionWorkspace({required this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WorkspaceHero(
          note: note,
          title: 'Oturum Kontrol Masası',
          subtitle: 'Hazırlık, sahneler, encounter, kararlar ve oturum sonrası kayıtları birbirinden ayır.',
          icon: Icons.calendar_month_outlined,
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Oturum Bilgisi',
          icon: Icons.event_outlined,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const ['Oturum No', 'Tarih', 'Oyuncular', 'Başlangıç Konumu'],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Hazırlık',
          icon: Icons.checklist_rounded,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const [
                'Önceki Oturum Özeti', 'Açık Görevler', 'Açılış',
                'Hedefler', 'Hazırlık Notları'
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Masa Akışı',
          icon: Icons.account_tree_outlined,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const ['Sahneler', 'Encounter Listesi', 'Loot'],
            ),
          ],
        ),
        const SizedBox(height: 9),
        _ConnectionCard(
          note: note,
          propertyKey: 'NPC Listesi',
          title: 'Bu Oturumdaki Kayıtlar',
          subtitle: 'NPC, canavar, mekân ve görevleri oturuma bağla.',
        ),
        const SizedBox(height: 9),
        _WorkspaceCard(
          title: 'Oturum Sonucu',
          icon: Icons.history_edu_outlined,
          children: [
            _WorkspaceFieldGrid(
              note: note,
              fields: const [
                'Kararlar', 'Zaman Çizelgesi', 'Verilen Bilgiler',
                'Sonraki Oturum Notları'
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _LocationWorkspace({required this.note});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WorkspaceHero(
            note: note,
            title: 'Mekân Dosyası',
            subtitle: 'Atmosfer, önemli noktalar, sakinler, olaylar, tehlikeler ve sırlar.',
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Kimlik & Atmosfer',
            icon: Icons.explore_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Mekân Türü', 'Bölge', 'Atmosfer', 'İlk İzlenim'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'İçerik',
            icon: Icons.map_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Önemli Noktalar', 'Olaylar', 'Söylentiler', 'Tehlikeler', 'Sırlar'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _ConnectionCard(
            note: note,
            propertyKey: 'Önemli NPC',
            title: 'Bağlı Kayıtlar',
            subtitle: 'NPC, fraksiyon, görev ve diğer mekânları bağla.',
          ),
        ],
      );
}

class _QuestWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _QuestWorkspace({required this.note});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WorkspaceHero(
            note: note,
            title: 'Görev Takibi',
            subtitle: 'Durum, hedefler, ipuçları, ödül, başarısızlık ve gizli gerçeği ayrı tut.',
            icon: Icons.task_alt_rounded,
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Görev Özeti',
            icon: Icons.flag_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Durum', 'Görevi Veren', 'Konum', 'Ana Hedef'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'İlerleme',
            icon: Icons.checklist_rounded,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Yan Hedefler', 'İpuçları', 'İlerleme Notları'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Sonuçlar',
            icon: Icons.emoji_events_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Ödül', 'Başarısızlık Durumu', 'Gizli Gerçek'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _ConnectionCard(
            note: note,
            propertyKey: 'Görev Bağlantıları',
            title: 'Görev Ağı',
            subtitle: 'NPC, mekân, eşya ve oturum kayıtlarını bağla.',
          ),
        ],
      );
}

class _ItemWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _ItemWorkspace({required this.note});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WorkspaceHero(
            note: note,
            title: 'Eşya Dosyası',
            subtitle: 'Mekanik, değer, geçmiş, sahiplik, gizli özellik ve lanet.',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Kimlik',
            icon: Icons.inventory_2_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Eşya Türü', 'Nadirlik', 'Değer', 'Ağırlık', 'Sahibi', 'Bulunduğu Yer'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Mekanik & Gizli Özellik',
            icon: Icons.auto_awesome_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Mekanik', 'Gizli Özellik', 'Lanet', 'Geçmiş'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _ConnectionCard(
            note: note,
            propertyKey: 'Eşya Bağlantıları',
            title: 'Sahiplik & Hikâye Ağı',
            subtitle: 'Karakter, NPC, mekân ve görevlerle ilişkilendir.',
          ),
        ],
      );
}

class _OrganizationWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _OrganizationWorkspace({required this.note});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WorkspaceHero(
            note: note,
            title: 'Organizasyon Panosu',
            subtitle: 'Amaç, liderlik, kaynaklar, üyeler, müttefikler, düşmanlar ve sırlar.',
            icon: Icons.account_tree_outlined,
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Kimlik & Güç',
            icon: Icons.account_balance_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Organizasyon Türü', 'Amaç', 'Lider', 'Merkez', 'Kaynaklar', 'Durum'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Planlar & Sırlar',
            icon: Icons.lock_outline_rounded,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Güncel Plan', 'Geçmiş', 'Sırlar'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _ConnectionCard(
            note: note,
            propertyKey: 'Üyeler',
            title: 'Üyeler & İlişkiler',
            subtitle: 'Üye, müttefik ve düşman kayıtlarını bağla.',
          ),
        ],
      );
}

class _LoreWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _LoreWorkspace({required this.note});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WorkspaceHero(
            note: note,
            title: 'Lore Arşivi',
            subtitle: 'Kaynak, tarih, oyuncu bilgisi, söylenti ve gerçek bilgiyi katmanlara ayır.',
            icon: Icons.auto_stories_outlined,
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Kaynak & Zaman',
            icon: Icons.menu_book_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Kategori', 'Kaynak', 'Tarih / Dönem'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Bilgi Katmanları',
            icon: Icons.layers_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Oyuncuların Bildiği', 'Söylenti', 'Gerçek', 'DM Yorumu'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _ConnectionCard(
            note: note,
            propertyKey: 'Lore Bağlantıları',
            title: 'Referans Ağı',
            subtitle: 'Kişi, mekân, olay ve organizasyonlara bağla.',
          ),
        ],
      );
}

class _RuleWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _RuleWorkspace({required this.note});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WorkspaceHero(
            note: note,
            title: 'Kural Masası',
            subtitle: 'Kaynak kuralı, yorumunu, house rule ve örnekleri yan yana tut.',
            icon: Icons.gavel_outlined,
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Kaynak',
            icon: Icons.menu_book_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Kaynak', 'Kategori', 'Sayfa / Bölüm'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Kural & Masa Yorumu',
            icon: Icons.balance_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Kural Açıklaması', 'House Rule Notu', 'Örnekler', 'İstisnalar'],
              ),
            ],
          ),
        ],
      );
}

class _JournalWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _JournalWorkspace({required this.note});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WorkspaceHero(
            note: note,
            title: 'Günlük & Kronoloji',
            subtitle: 'Tarih, konu, karakter, önemli olay ve sonraki hedefleri kronolojik tut.',
            icon: Icons.history_edu_outlined,
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Kayıt Başlığı',
            icon: Icons.calendar_today_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Tarih', 'Karakter', 'Oturum', 'Konu', 'Ruh Hali'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Kronoloji',
            icon: Icons.timeline_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Önemli Olaylar', 'Kararlar', 'Keşifler', 'Sonraki Hedefler'],
              ),
            ],
          ),
        ],
      );
}

class _HandoutWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _HandoutWorkspace({required this.note});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WorkspaceHero(
            note: note,
            title: 'Handout Hazırlayıcı',
            subtitle: 'Oyuncuya gösterilecek içerik ile DM arka plan bilgisini ayrı tut.',
            icon: Icons.mail_outline_rounded,
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Sunum',
            icon: Icons.visibility_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Tür', 'Görünürlük', 'Oyuncuya Verilecek Metin'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'DM Arka Planı',
            icon: Icons.lock_outline_rounded,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['DM Açıklaması', 'Gizli Bağlam', 'Ne Zaman Verilecek'],
              ),
            ],
          ),
        ],
      );
}

class _TemplateWorkspace extends StatelessWidget {
  final NoteRecord note;
  const _TemplateWorkspace({required this.note});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _WorkspaceHero(
            note: note,
            title: 'Şablon Tasarımcısı',
            subtitle: 'Tekrar kullanılacak alan, varsayılan property ve metin yapısını tanımla.',
            icon: Icons.data_object_rounded,
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Şablon Kimliği',
            icon: Icons.dashboard_customize_outlined,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Şablon Kategorisi', 'Açıklama', 'Varsayılan Tür'],
              ),
            ],
          ),
          const SizedBox(height: 9),
          _WorkspaceCard(
            title: 'Değişkenler & Kurallar',
            icon: Icons.code_rounded,
            children: [
              _WorkspaceFieldGrid(
                note: note,
                fields: const ['Değişkenler', 'Varsayılan Properties', 'Kullanım Notu'],
              ),
            ],
          ),
        ],
      );
}

class _TypeNoteSection {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> fields;

  const _TypeNoteSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fields,
  });
}

class _TypeNoteSchema {
  static String description(NoteType type) {
    switch (type) {
      case NoteType.note:
        return 'Serbest nottan fazlası: konu, durum, özet, kaynak ve bağlantıları ayrı tut.';
      case NoteType.npc:
        return 'Kimlik, rolplay, bilgi katmanları ve ilişkileri tek NPC kaydında yönet.';
      case NoteType.monster:
        return 'Stat block, savunma, aksiyonlar, taktik ve loot için ayrı bölümler.';
      case NoteType.session:
        return 'Hazırlık, masa akışı, kararlar ve oturum sonrası takibi bir arada tut.';
      case NoteType.location:
        return 'Atmosfer, sakinler, olaylar, tehlikeler ve sırları mekâna bağla.';
      case NoteType.quest:
        return 'Hedef, ilerleme, ipuçları, ödül ve sonuçları görev kaydında izle.';
      case NoteType.item:
        return 'Mekanik, geçmiş, sahiplik, gizli özellik ve laneti eşyanın üzerinde tut.';
      case NoteType.organization:
        return 'Üyeler, hiyerarşi, kaynaklar, müttefikler, düşmanlar ve sırlar.';
      case NoteType.lore:
        return 'Oyuncunun bildiği, söylenti ve gerçek bilgiyi birbirinden ayır.';
      case NoteType.rule:
        return 'Kaynak kuralı, yorumunu, house rule ve örnekleri aynı yerde tut.';
      case NoteType.journal:
        return 'Olayları, kararları, keşifleri ve sonraki hedefleri kronolojik tut.';
      case NoteType.handout:
        return 'Oyuncuya verilecek içerik ile DM arka plan bilgisini ayır.';
      case NoteType.template:
        return 'Tekrar kullanılacak yapıyı, varsayılan alanları ve değişkenleri tanımla.';
    }
  }

  static List<_TypeNoteSection> sections(NoteType type) {
    switch (type) {
      case NoteType.note:
        return const [
          _TypeNoteSection(
            title: 'Not Kimliği',
            subtitle: 'Notun neyle ilgili olduğunu ve durumunu tanımla.',
            icon: Icons.note_alt_outlined,
            fields: ['Kategori', 'Durum', 'Konu', 'Özet'],
          ),
          _TypeNoteSection(
            title: 'Kaynak & Bağlantı',
            subtitle: 'Referans ve ilişkili kayıtları ayrı tut.',
            icon: Icons.link_rounded,
            fields: ['Kaynak / Referans', 'Bağlantılı Notlar', 'Anahtar Kelimeler'],
          ),
        ];
      case NoteType.npc:
        return const [
          _TypeNoteSection(
            title: 'Kimlik',
            subtitle: 'NPC’nin masada hızlı bulunacak temel bilgileri.',
            icon: Icons.badge_outlined,
            fields: ['Irk / Tür', 'Yaş', 'Meslek / Rol', 'Ünvan / Lakap', 'Konum', 'Fraksiyon', 'Durum'],
          ),
          _TypeNoteSection(
            title: 'Rolplay',
            subtitle: 'Nasıl görünür, konuşur ve davranır?',
            icon: Icons.theater_comedy_outlined,
            fields: ['Görünüş', 'Kişilik', 'Ses / Konuşma', 'İdeal', 'Bağ', 'Kusur', 'Alışkanlık'],
          ),
          _TypeNoteSection(
            title: 'Motivasyon',
            subtitle: 'Ne istiyor, neden istiyor ve ne kadar ileri gider?',
            icon: Icons.flag_outlined,
            fields: ['Motivasyon', 'Kısa Vadeli Hedef', 'Uzun Vadeli Hedef', 'Korku'],
          ),
          _TypeNoteSection(
            title: 'Bilgi Katmanları',
            subtitle: 'Oyuncu bilgisi, DM bilgisi ve yanlış bilgiyi ayır.',
            icon: Icons.lock_outline_rounded,
            fields: ['Oyuncuların Bildiği', 'DM Bilgisi', 'Sır', 'Söylenti / Yanlış Bilgi', 'İlişkiler'],
          ),
        ];
      case NoteType.monster:
        return const [
          _TypeNoteSection(
            title: 'Stat Block',
            subtitle: 'Savaşta ilk bakacağın çekirdek değerler.',
            icon: Icons.shield_outlined,
            fields: ['Boyut', 'Tür', 'Alignment', 'CR', 'Proficiency Bonus', 'AC', 'HP', 'Hit Dice', 'Hız'],
          ),
          _TypeNoteSection(
            title: 'Ability Scores',
            subtitle: 'Altı ana ability skoru.',
            icon: Icons.analytics_outlined,
            fields: ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'],
          ),
          _TypeNoteSection(
            title: 'Savunma & Duyular',
            subtitle: 'Save, skill, direnç ve algı bilgileri.',
            icon: Icons.security_outlined,
            fields: ['Saving Throws', 'Skills', 'Vulnerabilities', 'Dirençler', 'Bağışıklıklar', 'Condition Immunities', 'Duyular', 'Passive Perception', 'Languages'],
          ),
          _TypeNoteSection(
            title: 'Aksiyonlar',
            subtitle: 'Normal, bonus, reaction ve özel aksiyonlar.',
            icon: Icons.flash_on_outlined,
            fields: ['Saldırılar', 'Özellikler', 'Bonus Actions', 'Reactions', 'Legendary Actions', 'Lair Actions', 'Mythic Actions'],
          ),
          _TypeNoteSection(
            title: 'DM Kullanımı',
            subtitle: 'Savaş davranışı, kullanım notu ve ödül.',
            icon: Icons.sports_mma_outlined,
            fields: ['Savaş Taktiği', 'Kaçış / Teslim Davranışı', 'Hedef Önceliği', 'Loot'],
          ),
        ];
      case NoteType.session:
        return const [
          _TypeNoteSection(
            title: 'Oturum Bilgisi',
            subtitle: 'Kim, ne zaman, nerede?',
            icon: Icons.calendar_month_outlined,
            fields: ['Oturum No', 'Tarih', 'Oyuncular', 'Başlangıç Konumu'],
          ),
          _TypeNoteSection(
            title: 'Hazırlık',
            subtitle: 'Masaya oturmadan önce gerekli şeyler.',
            icon: Icons.fact_check_outlined,
            fields: ['Önceki Oturum Özeti', 'Açık Görevler', 'Açılış', 'Hedefler', 'Hazırlık Notları'],
          ),
          _TypeNoteSection(
            title: 'Sahneler & Karşılaşmalar',
            subtitle: 'Planlanan içerikleri ayrı takip et.',
            icon: Icons.movie_filter_outlined,
            fields: ['Sahneler', 'NPC Listesi', 'Encounter Listesi', 'Loot'],
          ),
          _TypeNoteSection(
            title: 'Masa Sonucu',
            subtitle: 'Gerçekte ne oldu ve ne değişti?',
            icon: Icons.history_edu_outlined,
            fields: ['Kararlar', 'Zaman Çizelgesi', 'Verilen Bilgiler', 'Sonraki Oturum Notları'],
          ),
        ];
      case NoteType.location:
        return const [
          _TypeNoteSection(
            title: 'Kimlik & Konum',
            subtitle: 'Mekânın dünya içindeki yeri.',
            icon: Icons.place_outlined,
            fields: ['Mekân Türü', 'Alt Tür', 'Bölge', 'Bağlı Bölge'],
          ),
          _TypeNoteSection(
            title: 'Atmosfer',
            subtitle: 'Masada mekânı nasıl hissettireceksin?',
            icon: Icons.landscape_outlined,
            fields: ['İlk İzlenim', 'Atmosfer', 'Ses / Koku / Hava', 'Harita / Referans'],
          ),
          _TypeNoteSection(
            title: 'İçerik',
            subtitle: 'NPC, fraksiyon, nokta ve olaylar.',
            icon: Icons.account_tree_outlined,
            fields: ['Önemli NPC', 'Fraksiyonlar', 'Önemli Noktalar', 'Olaylar', 'Söylentiler'],
          ),
          _TypeNoteSection(
            title: 'DM Katmanı',
            subtitle: 'Tehlike, encounter, kaynak ve gizli bilgiler.',
            icon: Icons.lock_outline_rounded,
            fields: ['Tehlikeler', 'Encounterlar', 'Kaynaklar / Loot', 'Sırlar'],
          ),
        ];
      case NoteType.quest:
        return const [
          _TypeNoteSection(
            title: 'Görev Kimliği',
            subtitle: 'Görevin türü, durumu ve kaynağı.',
            icon: Icons.assignment_outlined,
            fields: ['Görev Türü', 'Durum', 'Öncelik', 'Görevi Veren', 'Konum'],
          ),
          _TypeNoteSection(
            title: 'Hedef & İlerleme',
            subtitle: 'Yapılacakları ve ilerlemeyi takip et.',
            icon: Icons.flag_outlined,
            fields: ['Ana Hedef', 'Yan Hedefler', 'İpuçları', 'İlerleme'],
          ),
          _TypeNoteSection(
            title: 'Sonuçlar',
            subtitle: 'Ödül, başarısızlık ve gizli dönüş.',
            icon: Icons.alt_route_outlined,
            fields: ['Ödül', 'Başarısızlık Durumu', 'Gizli Gerçek', 'Twist / Sonuç'],
          ),
        ];
      case NoteType.item:
        return const [
          _TypeNoteSection(
            title: 'Eşya Bilgisi',
            subtitle: 'Tür, nadirlik ve fiziksel bilgiler.',
            icon: Icons.inventory_2_outlined,
            fields: ['Eşya Türü', 'Nadirlik', 'Değer', 'Ağırlık', 'Attunement', 'Açıklama'],
          ),
          _TypeNoteSection(
            title: 'Mekanik',
            subtitle: 'Kurallar, kullanım ve kaynaklar.',
            icon: Icons.auto_fix_high_outlined,
            fields: ['Mekanik', 'Charges / Kullanım', 'Gizli Özellik', 'Lanet'],
          ),
          _TypeNoteSection(
            title: 'Dünya Bağlantısı',
            subtitle: 'Sahiplik, bulunduğu yer ve geçmiş.',
            icon: Icons.history_edu_outlined,
            fields: ['Sahibi', 'Bulunduğu Yer', 'Geçmiş', 'Bağlantılı Notlar'],
          ),
        ];
      case NoteType.organization:
        return const [
          _TypeNoteSection(
            title: 'Kimlik',
            subtitle: 'Organizasyonun dışarıdan görünen yapısı.',
            icon: Icons.groups_outlined,
            fields: ['Organizasyon Türü', 'Kamuya Açık Yüzü', 'Amaç', 'Merkez', 'Bölge / Etki Alanı'],
          ),
          _TypeNoteSection(
            title: 'Yapı',
            subtitle: 'Liderlik, üyeler, rütbe ve kaynaklar.',
            icon: Icons.account_tree_outlined,
            fields: ['Lider', 'Önemli Üyeler', 'Rütbeler', 'Kaynaklar'],
          ),
          _TypeNoteSection(
            title: 'İlişkiler',
            subtitle: 'Müttefikler, düşmanlar ve siyasi bağlar.',
            icon: Icons.hub_outlined,
            fields: ['Müttefikler', 'Düşmanlar', 'İlişkiler'],
          ),
          _TypeNoteSection(
            title: 'DM Katmanı',
            subtitle: 'Söylenti, gerçek amaç ve gizli bilgi.',
            icon: Icons.lock_outline_rounded,
            fields: ['Söylentiler', 'Gizli Amaç', 'Sırlar'],
          ),
        ];
      case NoteType.lore:
        return const [
          _TypeNoteSection(
            title: 'Kaynak',
            subtitle: 'Bilginin türü, dönemi ve nereden geldiği.',
            icon: Icons.menu_book_outlined,
            fields: ['Kategori', 'Dönem / Çağ', 'Kaynak', 'Tarih'],
          ),
          _TypeNoteSection(
            title: 'Bilgi Katmanları',
            subtitle: 'Bilinen, söylenen ve gerçekte olan.',
            icon: Icons.layers_outlined,
            fields: ['Oyuncuların Bildiği', 'Söylenti', 'Gerçek', 'DM Açıklaması'],
          ),
          _TypeNoteSection(
            title: 'Bağlantılar',
            subtitle: 'İlgili kişi, yer, olay ve kayıtlar.',
            icon: Icons.link_rounded,
            fields: ['Bağlantılı Notlar', 'İlgili Olaylar'],
          ),
        ];
      case NoteType.rule:
        return const [
          _TypeNoteSection(
            title: 'Kaynak Kural',
            subtitle: 'Sistem, kategori ve kaynak bilgisini tut.',
            icon: Icons.gavel_outlined,
            fields: ['Sistem', 'Kategori', 'Kaynak / Sayfa', 'Kural Açıklaması'],
          ),
          _TypeNoteSection(
            title: 'Masa Yorumu',
            subtitle: 'Nasıl yorumladığını ve değiştirdiğini yaz.',
            icon: Icons.psychology_alt_outlined,
            fields: ['Yorum', 'House Rule Notu', 'Örnek', 'Edge Cases'],
          ),
        ];
      case NoteType.journal:
        return const [
          _TypeNoteSection(
            title: 'Günlük Bilgisi',
            subtitle: 'Tarih, karakter ve bağlı oturum.',
            icon: Icons.auto_stories_outlined,
            fields: ['Tarih', 'Karakter', 'Oturum', 'Konu', 'Ruh Hali'],
          ),
          _TypeNoteSection(
            title: 'Kayıt',
            subtitle: 'Olaylar, kararlar ve keşifler.',
            icon: Icons.history_edu_outlined,
            fields: ['Olaylar', 'Kararlar', 'Keşifler'],
          ),
          _TypeNoteSection(
            title: 'Sonraki Adım',
            subtitle: 'Takip edilecek hedef ve sorular.',
            icon: Icons.next_plan_outlined,
            fields: ['Hedefler', 'Takip Edilecekler', 'Sorular'],
          ),
        ];
      case NoteType.handout:
        return const [
          _TypeNoteSection(
            title: 'Teslim Bilgisi',
            subtitle: 'Kime, ne zaman ve nasıl verilecek?',
            icon: Icons.mail_outline_rounded,
            fields: ['Handout Türü', 'Alıcı', 'Görünürlük', 'Verilme Anı'],
          ),
          _TypeNoteSection(
            title: 'İçerik',
            subtitle: 'Oyuncuya görünen metin ve DM arka planı.',
            icon: Icons.article_outlined,
            fields: ['Oyuncuya Verilecek Metin', 'DM Arka Plan Notu', 'Bağlantılı Notlar'],
          ),
        ];
      case NoteType.template:
        return const [
          _TypeNoteSection(
            title: 'Şablon Kimliği',
            subtitle: 'Nerede ve hangi kayıt türünde kullanılacak?',
            icon: Icons.dashboard_customize_outlined,
            fields: ['Şablon Kategorisi', 'Hedef Not Türü', 'Açıklama'],
          ),
          _TypeNoteSection(
            title: 'Varsayılanlar',
            subtitle: 'Yeni kayıt oluşturulurken taşınacak değerler.',
            icon: Icons.tune_outlined,
            fields: ['Varsayılan Etiketler', 'Varsayılan Properties', 'Zorunlu Alanlar'],
          ),
          _TypeNoteSection(
            title: 'Değişkenler',
            subtitle: '{{date}}, {{time}}, {{title}} ve kendi değişkenlerin.',
            icon: Icons.data_object_rounded,
            fields: ['Değişkenler', 'Kullanım Notu'],
          ),
        ];
    }
  }
}

class _TypeNoteSectionCard extends StatelessWidget {
  final NoteRecord note;
  final _TypeNoteSection section;
  final bool initiallyExpanded;

  const _TypeNoteSectionCard({
    required this.note,
    required this.section,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final filled = section.fields
        .where((field) => note.properties[field]?.trim().isNotEmpty == true)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 2,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            section.icon,
            size: 18,
            color: AppColors.purple,
          ),
        ),
        title: Text(
          section.title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
        ),
        subtitle: Text(
          '${section.subtitle}${filled > 0 ? ' • $filled/${section.fields.length}' : ''}',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
          ),
        ),
        children: [
          for (final field in section.fields) ...[
            _StoredNotePropertyField(
              note: note,
              label: field,
              icon: _StructuredCreatorPageState._fieldIcon(field),
              multiline: _StructuredCreatorPageState._isLongField(field),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _StoredNotePropertyField extends StatefulWidget {
  final NoteRecord note;
  final String label;
  final IconData icon;
  final bool multiline;

  const _StoredNotePropertyField({
    required this.note,
    required this.label,
    required this.icon,
    required this.multiline,
  });

  @override
  State<_StoredNotePropertyField> createState() =>
      _StoredNotePropertyFieldState();
}

class _StoredNotePropertyFieldState
    extends State<_StoredNotePropertyField> {
  late final TextEditingController controller;
  late final FocusNode focusNode;
  String lastSaved = '';
  bool focused = false;

  @override
  void initState() {
    super.initState();
    lastSaved = widget.note.properties[widget.label] ?? '';
    controller = TextEditingController(text: lastSaved);
    focusNode = FocusNode()
      ..addListener(() {
        if (!mounted) return;
        setState(() => focused = focusNode.hasFocus);
        if (!focusNode.hasFocus) {
          _commit();
        }
      });
  }

  @override
  void didUpdateWidget(covariant _StoredNotePropertyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id ||
        oldWidget.label != widget.label) {
      final value = widget.note.properties[widget.label] ?? '';
      lastSaved = value;
      controller.text = value;
    }
  }

  void _commit() {
    final value = controller.text.trim();
    if (value == lastSaved) return;
    lastSaved = value;
    final store = VaultScope.of(context);
    if (value.isEmpty) {
      store.removeProperty(widget.note, widget.label);
    } else {
      store.addProperty(
        widget.note,
        widget.label,
        value,
        type: _propertyTypeForLabel(widget.label),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: focused
            ? AppColors.panel2
            : AppColors.bg.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused
              ? AppColors.purple.withValues(alpha: 0.72)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: widget.multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: widget.multiline ? 4 : 0),
            child: Icon(
              widget.icon,
              size: 17,
              color: focused
                  ? AppColors.purple
                  : AppColors.muted,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    color: focused
                        ? AppColors.purple
                        : AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: widget.multiline ? 2 : 1,
                  maxLines: widget.multiline ? null : 1,
                  onSubmitted: (_) => _commit(),
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    hintText: '—',
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomNotePropertiesCard extends StatelessWidget {
  final NoteRecord note;
  final List<String> keys;

  const _CustomNotePropertiesCard({
    required this.note,
    required this.keys,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 13),
        leading: const Icon(
          Icons.dashboard_customize_outlined,
          color: AppColors.gold,
        ),
        title: const Text(
          'Özel Alanlar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${keys.length} özel property',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
        children: [
          for (final key in keys) ...[
            _StoredNotePropertyField(
              note: note,
              label: key,
              icon: Icons.tune_outlined,
              multiline: true,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TypeBodyHeader extends StatelessWidget {
  final NoteType type;

  const _TypeBodyHeader({required this.type});

  @override
  Widget build(BuildContext context) {
    final meta = _bodyMeta(type);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            meta.$1,
            size: 18,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta.$2,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta.$3,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static (IconData, String, String) _bodyMeta(NoteType type) {
    switch (type) {
      case NoteType.note:
        return (Icons.edit_note_rounded, 'Ana Not', 'Detay, düşünce, alıntı, kontrol listesi ve not bağlantıları.');
      case NoteType.npc:
        return (Icons.theater_comedy_outlined, 'Rolplay & Sahne Notları', 'Replikler, oyuncu etkileşimleri ve sahne içi değişiklikler.');
      case NoteType.monster:
        return (Icons.sports_mma_outlined, 'Savaş & Kullanım Notları', 'Encounter sırasında hatırlamak istediğin özel davranışlar.');
      case NoteType.session:
        return (Icons.bolt_rounded, 'Canlı Oturum Günlüğü', 'Masada olanları, kararları ve anlık notları buraya işle.');
      case NoteType.location:
        return (Icons.explore_outlined, 'Keşif & Atmosfer Notları', 'Betimleme, oyuncu keşifleri ve mekân değişimleri.');
      case NoteType.quest:
        return (Icons.task_alt_rounded, 'İlerleme Günlüğü', 'Görevin hangi aşamada olduğunu ve sonuçlarını takip et.');
      case NoteType.item:
        return (Icons.inventory_2_outlined, 'Kullanım & Geçmiş', 'Eşyanın hikâyesi, kullanımı ve masadaki etkileri.');
      case NoteType.organization:
        return (Icons.account_tree_outlined, 'Planlar & Hareketler', 'Organizasyonun güncel hamlelerini ve ilişkilerini izle.');
      case NoteType.lore:
        return (Icons.auto_stories_outlined, 'Lore Metni', 'Uzun açıklama, kronoloji ve kaynak notlarını yaz.');
      case NoteType.rule:
        return (Icons.gavel_outlined, 'Kural Açıklaması & Örnekler', 'Detaylı yorum, senaryo ve istisnaları yaz.');
      case NoteType.journal:
        return (Icons.history_edu_outlined, 'Günlük Metni', 'Olayları kendi anlatımınla kronolojik olarak işle.');
      case NoteType.handout:
        return (Icons.mail_outline_rounded, 'Handout Gövdesi', 'Oyuncuya verilecek gerçek içeriği burada hazırla.');
      case NoteType.template:
        return (Icons.data_object_rounded, 'Şablon Gövdesi', 'Tekrar kullanılacak metin, değişken ve bölüm yapısını oluştur.');
    }
  }
}

String _propertyTypeForLabel(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('tarih')) return 'date';
  if (lower == 'ac' ||
      lower == 'hp' ||
      lower == 'str' ||
      lower == 'dex' ||
      lower == 'con' ||
      lower == 'int' ||
      lower == 'wis' ||
      lower == 'cha' ||
      lower.contains('seviye') ||
      lower.contains('cr') ||
      lower.contains('bonus')) {
    return 'number';
  }
  if (lower.contains('etiket')) return 'tags';
  return 'text';
}

void _showAddNotePropertyDialog(
  BuildContext context,
  NoteRecord note,
) {
  final store = VaultScope.of(context);
  final keyController = TextEditingController();
  final valueController = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Özel Alan Ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: keyController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Alan adı',
              hintText: 'Örn. Tehlike Seviyesi',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: valueController,
            decoration: const InputDecoration(
              labelText: 'İlk değer',
              hintText: 'İstersen boş bırak',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () {
            final key = keyController.text.trim();
            if (key.isNotEmpty) {
              store.addProperty(
                note,
                key,
                valueController.text.trim(),
                type: _propertyTypeForLabel(key),
              );
            }
            Navigator.pop(dialogContext);
          },
          child: const Text('Ekle'),
        ),
      ],
    ),
  );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor();

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final Map<String, TextEditingController> fields = {};
  final List<String> customFields = [];
  final Set<String> selectedFields = {};
  final folderController = TextEditingController(text: '/');
  final tagsController = TextEditingController();
  String visibility = 'Sadece Ben';
  String? loadedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSelected();
  }

  @override
  void didUpdateWidget(covariant _NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadSelected();
  }

  void _loadSelected() {
    final note = VaultScope.of(context).selected;
    if (note == null || loadedId == note.id) return;

    for (final controller in fields.values) {
      controller.dispose();
    }
    fields.clear();
    customFields.clear();
    selectedFields.clear();

    loadedId = note.id;
    titleController.text = note.title;
    bodyController.text = note.content;
    visibility = note.visibility;
    folderController.text = note.properties['folder'] ?? '/';
    tagsController.text = note.properties['tags'] ?? '';

    final base = _StructuredCreatorPageState._baseFields(note.type).toSet();

    for (final label in base) {
      fields[label] = TextEditingController(
        text: note.properties[label] ?? '',
      );
    }

    const reservedMetaKeys = {'folder', 'tags', 'aliases'};
    for (final entry in note.properties.entries) {
      if (!base.contains(entry.key) &&
          !reservedMetaKeys.contains(entry.key)) {
        customFields.add(entry.key);
        fields[entry.key] = TextEditingController(text: entry.value);
      }
    }

    if (note.detailFields.isNotEmpty) {
      selectedFields.addAll(
        note.detailFields.where((key) => !reservedMetaKeys.contains(key)),
      );
    } else {
      selectedFields.addAll(
        note.properties.keys.where(
          (key) => key.trim().isNotEmpty && !reservedMetaKeys.contains(key),
        ),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    folderController.dispose();
    tagsController.dispose();
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final note = store.selected;

    if (note == null) return const SizedBox.shrink();

    if (loadedId != note.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(_loadSelected);
      });
    }

    final allLabels = [
      ..._StructuredCreatorPageState._baseFields(note.type),
      ...customFields,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 52),
      children: [
        _StructuredIntro(type: note.type),
        const SizedBox(height: 18),
        _CreatorTitleField(
          controller: titleController,
          type: note.type,
          onChanged: (value) {
            note.title = value;
            note.updatedAt = DateTime.now();
            store.scheduleSave();
          },
        ),
        const SizedBox(height: 12),
        _RecordMetaCard(
          visibility: visibility,
          folderController: folderController,
          tagsController: tagsController,
          onVisibilityChanged: (value) {
            setState(() => visibility = value);
            note.visibility = value;
            note.updatedAt = DateTime.now();
            store.scheduleSave();
          },
          onFolderChanged: (value) {
            note.properties['folder'] = value.trim().isEmpty ? '/' : value.trim();
            note.updatedAt = DateTime.now();
            store.scheduleSave();
          },
          onTagsChanged: (value) {
            if (value.trim().isEmpty) {
              note.properties.remove('tags');
              note.propertyTypes.remove('tags');
            } else {
              note.properties['tags'] = value;
              note.propertyTypes['tags'] = 'tags';
            }
            note.updatedAt = DateTime.now();
            store.scheduleSave();
          },
        ),
        const SizedBox(height: 18),
        _DetailSelectorCard(
          type: note.type,
          selectedCount: selectedFields.length,
          selectedLabels: selectedFields.toList(),
          onTap: () => _openDetailSelector(note),
        ),
        if (selectedFields.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _CreatorSectionLabel(
            icon: Icons.tune_rounded,
            title: 'Seçilen Ayrıntılar',
            subtitle:
                'Yalnızca seçtiğin alanlar görünür. Ayrıntılar kartından istediğin zaman değiştirebilirsin.',
          ),
          const SizedBox(height: 10),
          for (final label in allLabels.where(selectedFields.contains)) ...[
            _CreatorField(
              label: label,
              controller: fields.putIfAbsent(
                label,
                TextEditingController.new,
              ),
              multiline: _StructuredCreatorPageState._isLongField(label),
              icon: _StructuredCreatorPageState._fieldIcon(label),
              onChanged: (value) {
                note.properties[label] = value;
                note.propertyTypes[label] =
                    _StructuredCreatorPageState._guessPropertyTypeStatic(label);
                note.updatedAt = DateTime.now();
                store.scheduleSave();
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 10),
        _AddFieldCard(onTap: _addField),
        const SizedBox(height: 20),
        const _CreatorSectionLabel(
          icon: Icons.edit_note_rounded,
          title: 'Serbest Not',
          subtitle:
              'Bağlantı, etiket, görev ve uzun notların için serbest alan.',
        ),
        const SizedBox(height: 10),
        _CreatorField(
          label: 'Serbest Not',
          controller: bodyController,
          multiline: true,
          minLines: 9,
          icon: Icons.notes_rounded,
          hint: 'Notunu buraya yaz...',
          onChanged: (value) {
            note.content = value;
            note.updatedAt = DateTime.now();
            store.scheduleSave();
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              store.storageError == null
                  ? Icons.cloud_done_outlined
                  : Icons.error_outline_rounded,
              size: 17,
              color: store.storageError == null
                  ? AppColors.green
                  : AppColors.red,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                store.storageError ??
                    (store.saving
                        ? 'Kaydediliyor…'
                        : 'Değişiklikler otomatik kaydedilir.'),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => _saveExisting(note),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          icon: const Icon(Icons.save_rounded),
          label: const Text('Değişiklikleri Kaydet'),
        ),
      ],
    );
  }

  Future<void> _addField() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Özel Alan Ekle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Alan adı',
            hintText: 'Örn. Tehlike Seviyesi',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty || fields.containsKey(value)) return;

    setState(() {
      customFields.add(value);
      fields[value] = TextEditingController();
      selectedFields.add(value);
    });
    final note = VaultScope.of(context).selected;
    if (note != null) {
      note.detailFields = selectedFields.toList();
      note.updatedAt = DateTime.now();
      VaultScope.of(context).scheduleSave();
    }
  }

  Future<void> _openDetailSelector(NoteRecord note) async {
    final available = [
      ..._StructuredCreatorPageState._baseFields(note.type),
      ...customFields,
    ];

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final draft = <String>{...selectedFields};
        var fieldQuery = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final sections = _TypeNoteSchema.sections(note.type);

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.88,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: _FantasyIcon(
                              note.type.iconAsset,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ayrıntılar',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${note.type.label} kaydında kullanacağın alanları seç.',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        onChanged: (value) {
                          setSheetState(() => fieldQuery = value.trim().toLowerCase());
                        },
                        decoration: const InputDecoration(
                          hintText: 'Alan ara...',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                            label: const Text('Temel'),
                            onPressed: () {
                              final first = sections.isEmpty
                                  ? <String>[]
                                  : sections.first.fields;
                              setSheetState(() {
                                draft
                                  ..clear()
                                  ..addAll(first);
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.select_all_rounded, size: 16),
                            label: const Text('Tümünü Seç'),
                            onPressed: () {
                              setSheetState(() {
                                draft
                                  ..clear()
                                  ..addAll(available);
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.clear_all_rounded, size: 16),
                            label: const Text('Temizle'),
                            onPressed: () => setSheetState(draft.clear),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                        children: [
                          for (final section in sections) ...[
                            _DetailSectionHeader(section: section),
                            const SizedBox(height: 7),
                            for (final label in section.fields.where(
                              (item) => fieldQuery.isEmpty ||
                                  item.toLowerCase().contains(fieldQuery),
                            ))
                              _DetailFieldChoice(
                                label: label,
                                icon: _StructuredCreatorPageState._fieldIcon(label),
                                selected: draft.contains(label),
                                onChanged: (value) {
                                  setSheetState(() {
                                    if (value) {
                                      draft.add(label);
                                    } else {
                                      draft.remove(label);
                                    }
                                  });
                                },
                              ),
                            const SizedBox(height: 14),
                          ],
                          if (customFields.isNotEmpty) ...[
                            const _CreatorSectionLabel(
                              icon: Icons.extension_outlined,
                              title: 'Kendi Alanların',
                              subtitle: 'Senin eklediğin özel alanlar.',
                            ),
                            const SizedBox(height: 7),
                            for (final label in customFields.where(
                              (item) => fieldQuery.isEmpty ||
                                  item.toLowerCase().contains(fieldQuery),
                            ))
                              _DetailFieldChoice(
                                label: label,
                                icon: _StructuredCreatorPageState._fieldIcon(label),
                                selected: draft.contains(label),
                                onChanged: (value) {
                                  setSheetState(() {
                                    if (value) {
                                      draft.add(label);
                                    } else {
                                      draft.remove(label);
                                    }
                                  });
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${draft.length} alan seçili',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('İptal'),
                          ),
                          const SizedBox(width: 7),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(
                              sheetContext,
                              <String>{...draft},
                            ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Uygula'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      selectedFields
        ..clear()
        ..addAll(result);
    });
    note.detailFields = selectedFields.toList();
    note.updatedAt = DateTime.now();
    VaultScope.of(context).scheduleSave();
  }

  Future<void> _saveExisting(NoteRecord note) async {
    final store = VaultScope.of(context);

    note.title = titleController.text.trim();
    note.content = bodyController.text;
    note.visibility = visibility;
    note.properties['folder'] = folderController.text.trim().isEmpty
        ? '/'
        : folderController.text.trim();
    if (tagsController.text.trim().isEmpty) {
      note.properties.remove('tags');
      note.propertyTypes.remove('tags');
    } else {
      note.properties['tags'] = tagsController.text.trim();
      note.propertyTypes['tags'] = 'tags';
    }
    note.detailFields = selectedFields.toList();

    // Seçili ayrıntıları kaydet. Seçimden çıkarılan hazır alanları silme;
    // veri kaybı olmasın. Kullanıcı alanı tekrar seçerse eski değeri geri gelir.
    for (final entry in fields.entries) {
      final value = entry.value.text;
      if (selectedFields.contains(entry.key) || value.trim().isNotEmpty) {
        note.properties[entry.key] = value;
        note.propertyTypes[entry.key] =
            _StructuredCreatorPageState._guessPropertyTypeStatic(entry.key);
      }
    }

    note.updatedAt = DateTime.now();
    await store.flushSave();
    store.notifyListeners();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kayıt kaydedildi.')),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _EditorToolbar({
    required this.controller,
    required this.onChanged,
  });

  void insert(String text) {
    final selection = controller.selection;
    final start =
        selection.isValid ? selection.start : controller.text.length;
    final end =
        selection.isValid ? selection.end : controller.text.length;
    final value = controller.text;
    final next =
        value.replaceRange(start, end, text);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: start + text.length,
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final tools = <(IconData, String, String)>[
      (Icons.title_rounded, 'Başlık', '## '),
      (Icons.format_bold_rounded, 'Kalın', '**metin**'),
      (Icons.format_italic_rounded, 'İtalik', '*metin*'),
      (Icons.strikethrough_s_rounded, 'Üstü Çizili', '~~metin~~'),
      (Icons.code_rounded, 'Kod', '`kod`'),
      (Icons.format_list_bulleted_rounded, 'Madde', '- '),
      (Icons.format_list_numbered_rounded, 'Numaralı', '1. '),
      (Icons.check_box_outlined, 'Görev', '- [ ] '),
      (Icons.link_rounded, 'Bağlantı', '[[Not Başlığı]]'),
      (Icons.file_download_outlined, 'Embed', '![[Not Başlığı]]'),
      (Icons.view_agenda_outlined, 'Blok ID', ' ^blok-id'),
      (Icons.tag_rounded, 'Etiket', '#etiket'),
      (Icons.lock_outline_rounded, 'DM Bloğu', ':::dm\n\n:::'),
      (Icons.horizontal_rule_rounded, 'Ayraç', '\n---\n'),
      (Icons.format_quote_rounded, 'Alıntı', '> '),
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final tool in tools)
            Tooltip(
              message: tool.$2,
              child: IconButton(
                onPressed: () {
                  if (tool.$2 == 'Bağlantı') {
                    _showLinkPicker(
                      context,
                      controller,
                      onChanged,
                    );
                  } else {
                    insert(tool.$3);
                  }
                },
                icon: Icon(tool.$1, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  final NoteRecord note;
  const _TypePicker({required this.note});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return PopupMenuButton<NoteType>(
      initialValue: note.type,
      onSelected: (type) {
        store.updateNote(note, type: type);
      },
      itemBuilder: (_) => [
        for (final type in NoteType.values)
          PopupMenuItem(
            value: type,
            child: Text(type.label),
          ),
      ],
      child: Chip(
        label: Text(note.type.label),
        avatar: const Icon(Icons.expand_more_rounded, size: 16),
      ),
    );
  }
}

class _InspectorPanel extends StatefulWidget {
  const _InspectorPanel();

  @override
  State<_InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<_InspectorPanel> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final note = store.selected;

    if (note == null) {
      return Container(
        color: const Color(0xFF0D1015),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bir not seçildiğinde özellikler, backlink ve bağlantılar burada görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0D1015),
      child: Column(
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final veryNarrow = constraints.maxWidth < 310;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.tune_rounded, size: 17),
                        label: Text(veryNarrow ? 'Öz.' : 'Özellik'),
                      ),
                      const ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.reply_all_rounded, size: 17),
                        label: Text('Geri'),
                      ),
                      const ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.link_rounded, size: 17),
                        label: Text('Link'),
                      ),
                    ],
                    selected: {tab},
                    onSelectionChanged: (values) {
                      setState(() => tab = values.first);
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: const [
                _PropertiesTab(),
                _BacklinksTab(),
                _OutgoingLinksTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertiesTab extends StatelessWidget {
  const _PropertiesTab();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final note = store.selected!;
    final tags = store.extractTags(note.content);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const _InspectorTitle('ÖZELLİKLER'),
        const SizedBox(height: 10),
        _PropertyLine('Tür', note.type.label),
        _PropertyLine('Görünürlük', note.visibility),
        _PropertyLine('Oluşturuldu', _formatDate(note.createdAt)),
        _PropertyLine('Güncellendi', _formatDate(note.updatedAt)),
        const SizedBox(height: 12),
        const _InspectorTitle('ETİKETLER'),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          const _InspectorEmpty('Henüz etiket yok')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                Chip(label: Text(tag)),
            ],
          ),
        const SizedBox(height: 14),
        const _InspectorTitle('ÖZEL ALANLAR'),
        const SizedBox(height: 8),
        if (note.properties.isEmpty)
          const _InspectorEmpty('Henüz özel alan yok')
        else
          for (final entry in note.properties.entries)
            _CustomPropertyRow(
              propertyKey: entry.key,
              value: '${entry.value}  ·  ${note.propertyTypes[entry.key] ?? 'text'}',
              onDelete: () {
                store.removeProperty(note, entry.key);
              },
            ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _addPropertyDialog(context, note),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Özellik Ekle'),
        ),
        const SizedBox(height: 16),
        const _InspectorTitle('GÖRÜNÜRLÜK'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: note.visibility,
          items: const [
            DropdownMenuItem(
              value: 'Sadece Ben',
              child: Text('Sadece Ben'),
            ),
            DropdownMenuItem(
              value: 'Sadece DM',
              child: Text('Sadece DM'),
            ),
            DropdownMenuItem(
              value: 'Tüm Kampanya',
              child: Text('Tüm Kampanya'),
            ),
            DropdownMenuItem(
              value: 'Seçili Oyuncular',
              child: Text('Seçili Oyuncular'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              store.updateNote(note, visibility: value);
            }
          },
        ),
      ],
    );
  }

  void _addPropertyDialog(
    BuildContext context,
    NoteRecord note,
  ) {
    final store = VaultScope.of(context);
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    var propertyType = 'text';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Alan Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Alan adı',
                  hintText: 'status, aliases, tarih...',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: propertyType,
                decoration: const InputDecoration(
                  labelText: 'Property türü',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'text',
                    child: Text('Text'),
                  ),
                  DropdownMenuItem(
                    value: 'number',
                    child: Text('Number'),
                  ),
                  DropdownMenuItem(
                    value: 'checkbox',
                    child: Text('Checkbox'),
                  ),
                  DropdownMenuItem(
                    value: 'date',
                    child: Text('Date'),
                  ),
                  DropdownMenuItem(
                    value: 'list',
                    child: Text('List'),
                  ),
                  DropdownMenuItem(
                    value: 'tags',
                    child: Text('Tags'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => propertyType = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(
                  labelText: 'Değer',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final key = keyController.text.trim();
                if (key.isNotEmpty) {
                  store.addProperty(
                    note,
                    key,
                    valueController.text.trim(),
                    type: propertyType,
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BacklinksTab extends StatelessWidget {
  const _BacklinksTab();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final note = store.selected!;
    final backlinks = store.backlinksFor(note);
    final unlinked = store.unlinkedMentionsFor(note);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const _InspectorTitle('LINKED MENTIONS'),
        const SizedBox(height: 6),
        Text(
          '${backlinks.length} kayıt bu nota bağlantı veriyor.',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        if (backlinks.isEmpty)
          const _InspectorEmpty('Henüz backlink yok')
        else
          for (final item in backlinks) ...[
            _InspectorNoteLink(
              note: item,
              onTap: () => store.select(item.id),
            ),
            const SizedBox(height: 7),
          ],
        const SizedBox(height: 16),
        const _InspectorTitle('UNLINKED MENTIONS'),
        const SizedBox(height: 6),
        Text(
          '${unlinked.length} kayıt not adını metin içinde bağlantısız kullanıyor.',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        if (unlinked.isEmpty)
          const _InspectorEmpty('Bağlantısız mention yok')
        else
          for (final item in unlinked) ...[
            _InspectorNoteLink(
              note: item,
              onTap: () => store.select(item.id),
            ),
            const SizedBox(height: 7),
          ],
      ],
    );
  }
}

class _OutgoingLinksTab extends StatelessWidget {
  const _OutgoingLinksTab();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final note = store.selected!;
    final raw = store.extractNoteLinks(note);
    final headings = store.headingsFor(note);
    final blocks = store.blocksFor(note);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const _InspectorTitle('OUTGOING LINKS'),
        const SizedBox(height: 6),
        Text(
          '${raw.length} bağlantı bulundu.',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        if (raw.isEmpty)
          const _InspectorEmpty('Henüz bağlantı yok')
        else
          for (final link in raw) ...[
            Builder(
              builder: (context) {
                final resolved = store.resolveLink(link);

                return Material(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: resolved != null
                        ? () => store.select(resolved.id)
                        : () {
                            final title = store.linkTarget(link);
                            if (title.isEmpty) return;
                            store.create(NoteType.note).then((created) {
                              store.updateNote(
                                created,
                                title: title,
                              );
                            });
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Row(
                        children: [
                          Icon(
                            resolved != null
                                ? Icons.link_rounded
                                : Icons.add_link_rounded,
                            size: 18,
                            color: resolved != null
                                ? AppColors.green
                                : AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              store.linkDisplay(link),
                            ),
                          ),
                          Text(
                            resolved != null
                                ? 'aç'
                                : 'oluştur',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 7),
          ],
        const SizedBox(height: 16),
        const _InspectorTitle('BAŞLIKLAR'),
        const SizedBox(height: 8),
        if (headings.isEmpty)
          const _InspectorEmpty('Başlık yok')
        else
          for (final heading in headings)
            _SmallInspectorValue(
              icon: Icons.title_rounded,
              value: heading,
            ),
        const SizedBox(height: 16),
        const _InspectorTitle('BLOKLAR'),
        const SizedBox(height: 8),
        if (blocks.isEmpty)
          const _InspectorEmpty('Blok kimliği yok')
        else
          for (final block in blocks)
            _SmallInspectorValue(
              icon: Icons.view_agenda_outlined,
              value: '^$block',
            ),
      ],
    );
  }
}

class _GraphView extends StatelessWidget {
  const _GraphView();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.notes.where((n) => !n.archived).toList();

    if (notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Grafik boş.\nNotlar arasında [[Bağlantı]] kurdukça düğümler burada oluşacak.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, 1200.0);
        final height = math.max(constraints.maxHeight, 800.0);

        return InteractiveViewer(
          minScale: 0.45,
          maxScale: 2.8,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(300),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GraphPainter(
                      notes: notes,
                      store: store,
                      textColor: Theme.of(context).colorScheme.onSurface,
                      edgeColor: Theme.of(context).colorScheme.outlineVariant,
                      accentColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.panel.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${notes.length} düğüm • '
                      '${notes.fold<int>(0, (sum, n) => sum + store.extractNoteLinks(n).length)} bağlantı',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<NoteRecord> notes;
  final VaultStore store;
  final Color textColor;
  final Color edgeColor;
  final Color accentColor;

  _GraphPainter({
    required this.notes,
    required this.store,
    required this.textColor,
    required this.edgeColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final positions = <String, Offset>{};

    for (var i = 0; i < notes.length; i++) {
      final angle = (math.pi * 2 * i / notes.length) - math.pi / 2;
      positions[notes[i].id] = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
    }

    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.2;

    for (final note in notes) {
      final from = positions[note.id]!;
      final links = store.extractNoteLinks(note);
      for (final link in links) {
        final target = store.resolveLink(link);
        if (target != null && positions[target.id] != null) {
          canvas.drawLine(
            from,
            positions[target.id]!,
            edgePaint,
          );
        }
      }
    }

    for (final note in notes) {
      final p = positions[note.id]!;
      final incoming = store.backlinksFor(note).length;
      final extra = math.min(incoming * 1.2, 8).toDouble();
      final nodePaint = Paint()
        ..color = note.bookmarked
            ? AppColors.gold
            : accentColor;
      canvas.drawCircle(p, 7 + extra, nodePaint);

      final label = note.title.trim().isEmpty
          ? 'Başlıksız'
          : note.title;
      final tp = TextPainter(
        text: TextSpan(
          text: label.length > 22
              ? '${label.substring(0, 22)}…'
              : label,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 150);

      tp.paint(
        canvas,
        Offset(
          p.dx - tp.width / 2,
          p.dy + 12,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}

class _CreateTypeCard extends StatelessWidget {
  final NoteType type;
  final VoidCallback onTap;

  const _CreateTypeCard({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FantasyIcon(type.iconAsset, size: 36),
              const SizedBox(height: 8),
              Text(
                type.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FantasyIcon extends StatelessWidget {
  final String name;
  final double size;

  const _FantasyIcon(this.name, {this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/fantasy/$name.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => Icon(
        Icons.auto_awesome_rounded,
        size: size,
      ),
    );
  }
}

class _SidebarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? count;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.panel2 : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppColors.purple
                    : AppColors.muted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (count != null)
                Text(
                  count!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarSectionTitle extends StatelessWidget {
  final String text;
  const _SidebarSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.muted,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SidebarMutedText extends StatelessWidget {
  final String text;
  const _SidebarMutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String text;
  const _FeatureChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InspectorTitle extends StatelessWidget {
  final String text;
  const _InspectorTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InspectorEmpty extends StatelessWidget {
  final String text;
  const _InspectorEmpty(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PropertyLine extends StatelessWidget {
  final String label;
  final String value;

  const _PropertyLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomPropertyRow extends StatelessWidget {
  final String propertyKey;
  final String value;
  final VoidCallback onDelete;

  const _CustomPropertyRow({
    required this.propertyKey,
    required this.value,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              propertyKey,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _InspectorNoteLink extends StatelessWidget {
  final NoteRecord note;
  final VoidCallback onTap;

  const _InspectorNoteLink({
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _FantasyIcon(note.type.iconAsset, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.title.trim().isEmpty
                      ? 'Başlıksız'
                      : note.title,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString();
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$d.$m.$y $h:$min';
}

class _AdvancedSearchPage extends StatefulWidget {
  const _AdvancedSearchPage();

  @override
  State<_AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends State<_AdvancedSearchPage> {
  final controller = TextEditingController();
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final results = store.runSearch(query);

    return Scaffold(
      appBar: AppBar(title: const Text('Gelişmiş Arama')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              hintText: 'tag:  type:  link:  task:  [property:value]',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Desteklenen operatörler: tag: • type: • path: • link: • task: • '
            'task-todo: • task-done: • [property] • [property:value] • '
            'tırnaklı ifade',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${results.length} sonuç',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          if (results.isEmpty)
            const _InspectorEmpty('Sonuç bulunamadı')
          else
            for (final note in results) ...[
              _NoteListTile(note: note),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _BookmarksPage extends StatelessWidget {
  const _BookmarksPage();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.notes
        .where((n) => n.bookmarked && !n.archived)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Yer İmleri')),
      body: notes.isEmpty
          ? const _VaultEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Yer imi yok',
              text: 'Bir notu açıp yer imi simgesine dokunduğunda burada görünür.',
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                for (final note in notes) ...[
                  _NoteListTile(note: note),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _LocalGraphPage extends StatelessWidget {
  const _LocalGraphPage();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final selected = store.selected;

    if (selected == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yerel Grafik')),
        body: const _VaultEmptyState(
          icon: Icons.hub_outlined,
          title: 'Not seçilmedi',
          text: 'Yerel grafik için önce bir not aç.',
        ),
      );
    }

    final ids = <String>{selected.id};
    ids.addAll(store.backlinksFor(selected).map((e) => e.id));
    ids.addAll(store.outgoingResolved(selected).map((e) => e.id));
    final notes = store.notes.where((n) => ids.contains(n.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Yerel Grafik • ${selected.title.trim().isEmpty ? 'Başlıksız' : selected.title}',
        ),
      ),
      body: notes.isEmpty
          ? const _VaultEmptyState(
              icon: Icons.hub_outlined,
              title: 'Bağlantı yok',
              text: 'Bu notun bağlantıları oluştuğunda yerel grafik burada görünür.',
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GraphPainter(
                      notes: notes,
                      store: store,
                      textColor: Theme.of(context).colorScheme.onSurface,
                      edgeColor: Theme.of(context).colorScheme.outlineVariant,
                      accentColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: _GraphBadge('${notes.length} düğüm'),
                ),
              ],
            ),
    );
  }
}

class _ReadingPage extends StatelessWidget {
  final String noteId;
  const _ReadingPage({required this.noteId});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    NoteRecord? note;
    for (final item in store.notes) {
      if (item.id == noteId) {
        note = item;
        break;
      }
    }

    if (note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Not bulunamadı.')),
      );
    }

    final current = note;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          current.title.trim().isEmpty ? 'Başlıksız' : current.title,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 60),
        children: [
          Text(
            current.title.trim().isEmpty ? 'Başlıksız' : current.title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          for (final line in current.content.split('\n'))
            _ReadingLine(line: line),
        ],
      ),
    );
  }
}

class _ReadingLine extends StatelessWidget {
  final String line;
  const _ReadingLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      return const SizedBox(height: 10);
    }

    if (trimmed == '---') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(),
      );
    }

    if (trimmed.startsWith('### ')) {
      return _ReadingHeading(
        text: trimmed.substring(4),
        size: 18,
      );
    }

    if (trimmed.startsWith('## ')) {
      return _ReadingHeading(
        text: trimmed.substring(3),
        size: 22,
      );
    }

    if (trimmed.startsWith('# ')) {
      return _ReadingHeading(
        text: trimmed.substring(2),
        size: 27,
      );
    }

    if (trimmed.startsWith('- [ ]')) {
      return _ReadTask(
        checked: false,
        text: trimmed.substring(5).trim(),
      );
    }

    if (trimmed.toLowerCase().startsWith('- [x]')) {
      return _ReadTask(
        checked: true,
        text: trimmed.substring(5).trim(),
      );
    }

    if (trimmed.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, right: 8),
              child: SizedBox(
                width: 6,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _LinkAwareText(
                text: trimmed.substring(2),
                compact: true,
              ),
            ),
          ],
        ),
      );
    }

    final numbered = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(trimmed);
    if (numbered != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${numbered.group(1)}.',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            Expanded(
              child: _LinkAwareText(
                text: numbered.group(2)!,
                compact: true,
              ),
            ),
          ],
        ),
      );
    }

    if (trimmed.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppColors.purple,
              width: 3,
            ),
          ),
        ),
        child: Text(
          trimmed.substring(2),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Color(0xFFD4D8E0),
          ),
        ),
      );
    }

    if (trimmed.startsWith(':::dm')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.red.withValues(alpha: 0.25),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppColors.red,
            ),
            SizedBox(width: 7),
            Text(
              'DM BLOĞU',
              style: TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return _LinkAwareText(text: line);
  }
}

class _ReadingHeading extends StatelessWidget {
  final String text;
  final double size;
  const _ReadingHeading({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReadTask extends StatelessWidget {
  final bool checked;
  final String text;
  const _ReadTask({required this.checked, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: checked, onChanged: null),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: checked
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSurface,
              decoration: checked ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkAwareText extends StatelessWidget {
  final String text;
  final bool compact;

  const _LinkAwareText({
    required this.text,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final spans = <InlineSpan>[];

    final regex = RegExp(
      r'(!)?\[\[([^\]]+)\]\]|'
      r'`([^`]+)`|'
      r'\*\*([^*]+)\*\*|'
      r'~~([^~]+)~~|'
      r'(?<!\*)\*([^*]+)\*(?!\*)',
    );

    var cursor = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
          ),
        );
      }

      final rawLink = match.group(2);
      final inlineCode = match.group(3);
      final bold = match.group(4);
      final strike = match.group(5);
      final italic = match.group(6);

      if (rawLink != null) {
        final embed = match.group(1) == '!';
        final resolved = store.resolveLink(rawLink);

        if (embed && resolved != null) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 120,
                  maxWidth: 420,
                ),
                margin: const EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 3,
                ),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.panel2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      resolved.title.trim().isEmpty
                          ? 'Başlıksız'
                          : resolved.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.purple,
                      ),
                    ),
                    if (resolved.content.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        resolved.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        } else {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                onTap: resolved == null
                    ? null
                    : () {
                        store.select(resolved.id);
                        Navigator.of(context).maybePop();
                      },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (resolved == null
                            ? AppColors.gold
                            : AppColors.purple)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    store.linkDisplay(rawLink),
                    style: TextStyle(
                      color: resolved == null
                          ? AppColors.gold
                          : AppColors.purple,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      } else if (inlineCode != null) {
        spans.add(
          TextSpan(
            text: inlineCode,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppColors.gold,
              backgroundColor: AppColors.panel2,
            ),
          ),
        );
      } else if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      } else if (strike != null) {
        spans.add(
          TextSpan(
            text: strike,
            style: const TextStyle(
              decoration: TextDecoration.lineThrough,
              color: AppColors.muted,
            ),
          ),
        );
      } else if (italic != null) {
        spans.add(
          TextSpan(
            text: italic,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
        ),
      );
    }

    final rendered = Text.rich(
      TextSpan(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15.5,
          height: 1.55,
        ),
        children: spans,
      ),
    );

    if (compact) return rendered;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: rendered,
    );
  }
}

class _LivePreviewPane extends StatelessWidget {
  final NoteRecord note;

  const _LivePreviewPane({
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final tags = store.extractTags(note.content);

    return Container(
      color: const Color(0xFF0D1015),
      child: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.green,
                ),
                SizedBox(width: 7),
                Text(
                  'CANLI ÖNİZLEME',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 50),
              children: [
                Text(
                  note.title.trim().isEmpty
                      ? 'Başlıksız'
                      : note.title,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in tags)
                        Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                for (final line in note.content.split('\n'))
                  _ReadingLine(line: line),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphBadge extends StatelessWidget {
  final String text;
  const _GraphBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _BasesPage extends StatefulWidget {
  const _BasesPage();

  @override
  State<_BasesPage> createState() => _BasesPageState();
}

class _BasesPageState extends State<_BasesPage> {
  int layout = 0;
  String query = '';
  String groupProperty = 'status';

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    var notes = store.notes.where((n) => !n.archived).toList();
    if (query.trim().isNotEmpty) {
      notes = store.runSearch(query, source: notes);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bases')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;

                final modePicker = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.table_chart_outlined, size: 16),
                        label: Text('Tablo'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.grid_view_outlined, size: 16),
                        label: Text('Kart'),
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.view_column_outlined, size: 16),
                        label: Text('Kanban'),
                      ),
                    ],
                    selected: {layout},
                    onSelectionChanged: (value) {
                      setState(() => layout = value.first);
                    },
                  ),
                );

                final search = TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'Base filtresi / arama...',
                    prefixIcon: Icon(Icons.filter_alt_outlined),
                    isDense: true,
                  ),
                );

                final groupButton = OutlinedButton.icon(
                  onPressed: () => _groupDialog(context),
                  icon: const Icon(Icons.view_column_outlined),
                  label: const Text('Group'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      modePicker,
                      const SizedBox(height: 10),
                      search,
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: groupButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    modePicker,
                    const SizedBox(width: 10),
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    groupButton,
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? const _VaultEmptyState(
                    icon: Icons.table_chart_outlined,
                    title: 'Tablo görünümü boş',
                    text: 'Notlar oluşturulduğunda burada tablo, kart ve Kanban görünümleri oluşur.',
                  )
                : layout == 0
                    ? _BaseTable(notes: notes)
                    : layout == 1
                        ? _BaseCards(notes: notes)
                        : _BaseKanban(
                            notes: notes,
                            propertyName: groupProperty,
                          ),
          ),
        ],
      ),
    );
  }

  void _groupDialog(BuildContext context) {
    final controller = TextEditingController(text: groupProperty);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kanban Group Property'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Alan adı',
            hintText: 'status',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                setState(() => groupProperty = value);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
  }
}

class _BaseTable extends StatelessWidget {
  final List<NoteRecord> notes;
  const _BaseTable({required this.notes});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Ad')),
          DataColumn(label: Text('Tür')),
          DataColumn(label: Text('Güncellendi')),
          DataColumn(label: Text('Properties')),
          DataColumn(label: Text('Link')),
        ],
        rows: [
          for (final note in notes)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                  ),
                  onTap: () => store.select(note.id),
                ),
                DataCell(Text(note.type.label)),
                DataCell(Text(_formatDate(note.updatedAt))),
                DataCell(Text('${note.properties.length}')),
                DataCell(Text('${store.extractNoteLinks(note).length}')),
              ],
            ),
        ],
      ),
    );
  }
}

class _BaseCards extends StatelessWidget {
  final List<NoteRecord> notes;
  const _BaseCards({required this.notes});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 150,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: notes.length,
      itemBuilder: (_, index) {
        final note = notes[index];
        return Material(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => store.select(note.id),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _FantasyIcon(note.type.iconAsset, size: 28),
                      const Spacer(),
                      Text(
                        note.type.label,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${note.properties.length} property • ${store.extractNoteLinks(note).length} link',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BaseKanban extends StatelessWidget {
  final List<NoteRecord> notes;
  final String propertyName;

  const _BaseKanban({
    required this.notes,
    required this.propertyName,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<NoteRecord>>{};

    for (final note in notes) {
      final raw = note.properties[propertyName];
      final group = raw == null || raw.trim().isEmpty ? 'Değersiz' : raw.trim();
      groups.putIfAbsent(group, () => []).add(note);
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in groups.entries)
          _KanbanColumn(
            title: entry.key,
            notes: entry.value,
          ),
      ],
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final List<NoteRecord> notes;

  const _KanbanColumn({
    required this.title,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${notes.length}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: AppColors.panel2,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => store.select(note.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasPage extends StatelessWidget {
  const _CanvasPage();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.notes.where((n) => !n.archived).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Canvas')),
      body: notes.isEmpty
          ? const _VaultEmptyState(
              icon: Icons.dashboard_outlined,
              title: 'Pano boş',
              text: 'Notlar oluştuğunda kartlar ve bağlantılar 2B alanda gösterilir.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final cols = math.max(2, (constraints.maxWidth / 290).floor());
                const cardWidth = 240.0;
                const cardHeight = 130.0;
                const gap = 42.0;
                final rows = (notes.length / cols).ceil();
                final canvasWidth = math.max(
                  constraints.maxWidth,
                  cols * (cardWidth + gap) + gap,
                );
                final canvasHeight = math.max(
                  constraints.maxHeight,
                  rows * (cardHeight + gap) + gap,
                );
                final positions = <String, Offset>{};

                for (var i = 0; i < notes.length; i++) {
                  final col = i % cols;
                  final row = i ~/ cols;
                  positions[notes[i].id] = Offset(
                    gap + col * (cardWidth + gap),
                    gap + row * (cardHeight + gap),
                  );
                }

                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 2.5,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(300),
                  child: SizedBox(
                    width: canvasWidth,
                    height: canvasHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CanvasPainter(
                              store: store,
                              notes: notes,
                              positions: positions,
                              cardSize: const Size(cardWidth, cardHeight),
                            ),
                          ),
                        ),
                        for (final note in notes)
                          Positioned(
                            left: positions[note.id]!.dx,
                            top: positions[note.id]!.dy,
                            width: cardWidth,
                            height: cardHeight,
                            child: Material(
                              color: AppColors.panel,
                              elevation: 2,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => store.select(note.id),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _FantasyIcon(
                                            note.type.iconAsset,
                                            size: 26,
                                          ),
                                          const Spacer(),
                                          Text(
                                            note.type.label,
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        note.title.trim().isEmpty
                                            ? 'Başlıksız'
                                            : note.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${store.extractNoteLinks(note).length} link',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final VaultStore store;
  final List<NoteRecord> notes;
  final Map<String, Offset> positions;
  final Size cardSize;

  _CanvasPainter({
    required this.store,
    required this.notes,
    required this.positions,
    required this.cardSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.4;

    for (final note in notes) {
      final start = positions[note.id];
      if (start == null) continue;

      final from = Offset(
        start.dx + cardSize.width / 2,
        start.dy + cardSize.height / 2,
      );

      for (final raw in store.extractNoteLinks(note)) {
        final target = store.resolveLink(raw);
        if (target == null) continue;
        final end = positions[target.id];
        if (end == null) continue;

        final to = Offset(
          end.dx + cardSize.width / 2,
          end.dy + cardSize.height / 2,
        );

        canvas.drawLine(from, to, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) => true;
}

class _VaultEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _VaultEmptyState({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallInspectorValue extends StatelessWidget {
  final IconData icon;
  final String value;

  const _SmallInspectorValue({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

void _showQuickSwitcher(BuildContext context) {
  final store = VaultScope.of(context);
  final controller = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        final query = controller.text.toLowerCase();
        final notes = store.notes
            .where((n) => !n.archived)
            .where((note) {
              if (query.isEmpty) return true;
              final title = note.title.toLowerCase();
              var cursor = 0;
              for (final rune in query.runes) {
                final char = String.fromCharCode(rune);
                final found = title.indexOf(char, cursor);
                if (found < 0) return false;
                cursor = found + 1;
              }
              return true;
            })
            .take(24)
            .toList();

        return AlertDialog(
          title: const Text('Hızlı Geçiş'),
          content: SizedBox(
            width: 620,
            height: 470,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Not adına göre fuzzy ara...',
                    prefixIcon: Icon(Icons.bolt_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: notes.isEmpty
                      ? Center(
                          child: TextButton.icon(
                            onPressed: () async {
                              final title = controller.text.trim();
                              if (title.isEmpty) return;
                              Navigator.pop(dialogContext);
                              final note = await store.create(NoteType.note);
                              await store.updateNote(note, title: title);
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              '"${controller.text}" adıyla not oluştur',
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final note in notes)
                              ListTile(
                                leading: _FantasyIcon(
                                  note.type.iconAsset,
                                  size: 26,
                                ),
                                title: Text(
                                  note.title.trim().isEmpty
                                      ? 'Başlıksız'
                                      : note.title,
                                ),
                                subtitle: Text(note.type.label),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  store.select(note.id);
                                },
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _showTemplates(BuildContext context) {
  final store = VaultScope.of(context);
  final templates = store.notes
      .where(
        (n) => !n.archived && n.type == NoteType.template,
      )
      .toList();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Şablonlar'),
      content: SizedBox(
        width: 620,
        height: 430,
        child: templates.isEmpty
            ? const _VaultEmptyState(
                icon: Icons.book_outlined,
                title: 'Şablon yok',
                text: 'Yeni kayıt oluştururken tür olarak Şablon seç. '
                    '{{date}}, {{time}} ve {{title}} değişkenlerini kullanabilirsin.',
              )
            : ListView(
                children: [
                  for (final template in templates)
                    ListTile(
                      leading: const Icon(Icons.book_outlined),
                      title: Text(
                        template.title.trim().isEmpty
                            ? 'Başlıksız Şablon'
                            : template.title,
                      ),
                      subtitle: Text(
                        '${template.properties.length} property',
                      ),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        store.createFromTemplate(template);
                      },
                    ),
                ],
              ),
      ),
    ),
  );
}

void _showVaultCommandPalette(BuildContext context) {
  final store = VaultScope.of(context);
  final controller = TextEditingController();

  final commands = <_PaletteCommand>[
    _PaletteCommand(
      'Yeni kayıt oluştur',
      Icons.note_add_outlined,
      () {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Yeni Kayıt'),
            content: SizedBox(
              width: 620,
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.35,
                children: [
                  for (final type in NoteType.values)
                    Material(
                      color: AppColors.panel2,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          store.create(type);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FantasyIcon(type.iconAsset, size: 34),
                            const SizedBox(height: 7),
                            Text(type.label),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    _PaletteCommand(
      'Hızlı Geçiş',
      Icons.bolt_outlined,
      () => _showQuickSwitcher(context),
    ),
    _PaletteCommand(
      'Bugünün Notunu Aç',
      Icons.calendar_today_outlined,
      () => store.createDailyNote(),
    ),
    _PaletteCommand(
      'Grafiği Aç',
      Icons.hub_outlined,
      store.showGraph,
    ),
    _PaletteCommand(
      'Gelişmiş Arama',
      Icons.search_rounded,
      () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const _AdvancedSearchPage(),
        ),
      ),
    ),
    _PaletteCommand(
      'Yer İmlerini Aç',
      Icons.bookmark_border_rounded,
      () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const _BookmarksPage(),
        ),
      ),
    ),
    _PaletteCommand(
      'Tabloları Aç',
      Icons.table_chart_outlined,
      () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const _BasesPage(),
        ),
      ),
    ),
    _PaletteCommand(
      'Panoyu Aç',
      Icons.dashboard_outlined,
      () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const _CanvasPage(),
        ),
      ),
    ),
    _PaletteCommand(
      'Şablondan Oluştur',
      Icons.book_outlined,
      () => _showTemplates(context),
    ),
  ];

  if (store.selected != null) {
    commands.add(
      _PaletteCommand(
        'Aktif Notu Sabitle / Kaldır',
        Icons.push_pin_outlined,
        () => store.togglePin(store.selected!),
      ),
    );
    commands.add(
      _PaletteCommand(
        'Aktif Notu Yer İmlerine Ekle / Kaldır',
        Icons.bookmark_border_rounded,
        () => store.toggleBookmark(store.selected!),
      ),
    );
  }

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        final query = controller.text.toLowerCase();
        final visible = commands.where((command) {
          if (query.isEmpty) return true;
          final text = command.title.toLowerCase();
          var cursor = 0;
          for (final rune in query.runes) {
            final char = String.fromCharCode(rune);
            final found = text.indexOf(char, cursor);
            if (found < 0) return false;
            cursor = found + 1;
          }
          return true;
        }).toList();

        return AlertDialog(
          title: const Text('Komut Paleti'),
          content: SizedBox(
            width: 620,
            height: 480,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Komut ara...',
                    prefixIcon: Icon(Icons.terminal_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      for (final command in visible)
                        ListTile(
                          leading: Icon(command.icon),
                          title: Text(command.title),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            command.run();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _PaletteCommand {
  final String title;
  final IconData icon;
  final VoidCallback run;

  _PaletteCommand(this.title, this.icon, this.run);
}

void _showLinkPicker(
  BuildContext context,
  TextEditingController controller,
  VoidCallback onChanged,
) {
  final store = VaultScope.of(context);
  final search = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        final q = search.text.toLowerCase();
        final notes = store.notes
            .where((n) => !n.archived)
            .where(
              (n) => q.isEmpty || n.title.toLowerCase().contains(q),
            )
            .toList();

        void insertLink(String title) {
          final text = '[[$title]]';
          final selection = controller.selection;
          final start = selection.isValid
              ? selection.start
              : controller.text.length;
          final end = selection.isValid
              ? selection.end
              : controller.text.length;
          final next = controller.text.replaceRange(start, end, text);
          controller.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(
              offset: start + text.length,
            ),
          );
          onChanged();
          Navigator.pop(dialogContext);
        }

        return AlertDialog(
          title: const Text('İç Bağlantı Ekle'),
          content: SizedBox(
            width: 600,
            height: 440,
            child: Column(
              children: [
                TextField(
                  controller: search,
                  autofocus: true,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Not ara...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: notes.isEmpty
                      ? Center(
                          child: TextButton.icon(
                            onPressed: () {
                              final title = search.text.trim();
                              if (title.isEmpty) return;
                              insertLink(title);
                            },
                            icon: const Icon(Icons.add_link_rounded),
                            label: Text(
                              '[[${search.text.trim()}]] olarak ekle',
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final note in notes)
                              ListTile(
                                leading: _FantasyIcon(
                                  note.type.iconAsset,
                                  size: 26,
                                ),
                                title: Text(
                                  note.title.trim().isEmpty
                                      ? 'Başlıksız'
                                      : note.title,
                                ),
                                subtitle: Text(note.type.label),
                                onTap: () => insertLink(
                                  note.title.trim().isEmpty
                                      ? 'Başlıksız'
                                      : note.title,
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}


// ============================================================================
// HYBRID v0.6
// Dark-fantasy tablet tasarımı + bağlantılı bilgi kasası motoru.
// Hazır kampanya içeriği YOKTUR. Dashboard yalnızca kullanıcının gerçek verisini
// gösterir. Creator alanları da boş başlar.
// ============================================================================

class HybridConfig extends ChangeNotifier {
  static const _key = 'dmpcs_hybrid_config_v06';

  bool loaded = false;
  bool showRailLabels = true;
  bool compactCards = false;
  bool showHeroStats = true;
  double cardRadius = 20;

  /// auto: ekran boyutuna göre, phone: telefon arayüzünü zorla,
  /// tablet: tablet arayüzünü zorla.
  String layoutMode = 'auto';

  // Tablet çalışma alanı tercihleri.
  bool tabletRailExpanded = true;
  bool tabletContextShelf = true;
  bool tabletSplitVault = true;
  bool tabletRecordInspector = true;
  String tabletDensity = 'balanced';
  double tabletShelfWidth = 300;

  final List<String> dashboardOrder = [
    'quick',
    'recent',
    'pinned',
    'tasks',
    'links',
    'tags',
    'bookmarks',
  ];

  final Set<String> hiddenDashboard = {};

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final map = Map<String, dynamic>.from(
          jsonDecode(raw) as Map,
        );
        showRailLabels =
            map['showRailLabels'] as bool? ?? showRailLabels;
        compactCards =
            map['compactCards'] as bool? ?? compactCards;
        showHeroStats =
            map['showHeroStats'] as bool? ?? showHeroStats;
        cardRadius =
            (map['cardRadius'] as num?)?.toDouble() ?? cardRadius;
        final savedLayoutMode = map['layoutMode']?.toString();
        if (savedLayoutMode == 'auto' ||
            savedLayoutMode == 'phone' ||
            savedLayoutMode == 'tablet') {
          layoutMode = savedLayoutMode!;
        }

        tabletRailExpanded =
            map['tabletRailExpanded'] as bool? ?? tabletRailExpanded;
        tabletContextShelf =
            map['tabletContextShelf'] as bool? ?? tabletContextShelf;
        tabletSplitVault =
            map['tabletSplitVault'] as bool? ?? tabletSplitVault;
        tabletRecordInspector =
            map['tabletRecordInspector'] as bool? ?? tabletRecordInspector;
        final savedDensity = map['tabletDensity']?.toString();
        if (savedDensity == 'compact' ||
            savedDensity == 'balanced' ||
            savedDensity == 'spacious') {
          tabletDensity = savedDensity!;
        }
        tabletShelfWidth =
            (map['tabletShelfWidth'] as num?)?.toDouble() ??
                tabletShelfWidth;

        final order = (map['dashboardOrder'] as List?)
            ?.map((e) => e.toString())
            .where(_knownModule)
            .toList();
        if (order != null && order.isNotEmpty) {
          dashboardOrder
            ..clear()
            ..addAll(order);
          for (final id in _allModules) {
            if (!dashboardOrder.contains(id)) {
              dashboardOrder.add(id);
            }
          }
        }

        final hidden = (map['hiddenDashboard'] as List?)
            ?.map((e) => e.toString())
            .where(_knownModule)
            .toSet();
        if (hidden != null) {
          hiddenDashboard
            ..clear()
            ..addAll(hidden);
        }
      }
    } catch (_) {
      // SharedPreferences veya eski ayar verisi sorunlu olsa bile
      // uygulama varsayılan ayarlarla açılmaya devam eder.
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  static const _allModules = {
    'quick',
    'recent',
    'pinned',
    'tasks',
    'links',
    'tags',
    'bookmarks',
  };

  bool _knownModule(String value) =>
      _allModules.contains(value);

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'showRailLabels': showRailLabels,
        'compactCards': compactCards,
        'showHeroStats': showHeroStats,
        'cardRadius': cardRadius,
        'layoutMode': layoutMode,
        'tabletRailExpanded': tabletRailExpanded,
        'tabletContextShelf': tabletContextShelf,
        'tabletSplitVault': tabletSplitVault,
        'tabletRecordInspector': tabletRecordInspector,
        'tabletDensity': tabletDensity,
        'tabletShelfWidth': tabletShelfWidth,
        'dashboardOrder': dashboardOrder,
        'hiddenDashboard': hiddenDashboard.toList(),
      }),
    );
  }

  Future<void> setRailLabels(bool value) async {
    showRailLabels = value;
    notifyListeners();
    await save();
  }

  Future<void> setCompact(bool value) async {
    compactCards = value;
    notifyListeners();
    await save();
  }

  Future<void> setHeroStats(bool value) async {
    showHeroStats = value;
    notifyListeners();
    await save();
  }

  Future<void> setRadius(double value) async {
    cardRadius = value;
    notifyListeners();
    await save();
  }

  Future<void> setLayoutMode(String value) async {
    if (value != 'auto' &&
        value != 'phone' &&
        value != 'tablet') {
      return;
    }
    layoutMode = value;
    notifyListeners();
    await save();
  }

  Future<void> setTabletRailExpanded(bool value) async {
    tabletRailExpanded = value;
    notifyListeners();
    await save();
  }

  Future<void> setTabletContextShelf(bool value) async {
    tabletContextShelf = value;
    notifyListeners();
    await save();
  }

  Future<void> setTabletSplitVault(bool value) async {
    tabletSplitVault = value;
    notifyListeners();
    await save();
  }

  Future<void> setTabletRecordInspector(bool value) async {
    tabletRecordInspector = value;
    notifyListeners();
    await save();
  }

  Future<void> setTabletDensity(String value) async {
    if (value != 'compact' &&
        value != 'balanced' &&
        value != 'spacious') {
      return;
    }
    tabletDensity = value;
    notifyListeners();
    await save();
  }

  Future<void> setTabletShelfWidth(double value) async {
    tabletShelfWidth = value.clamp(250.0, 380.0).toDouble();
    notifyListeners();
    await save();
  }

  double get tabletGap {
    switch (tabletDensity) {
      case 'compact':
        return 10;
      case 'spacious':
        return 20;
      default:
        return 14;
    }
  }

  EdgeInsets get tabletPagePadding {
    switch (tabletDensity) {
      case 'compact':
        return const EdgeInsets.fromLTRB(16, 8, 16, 28);
      case 'spacious':
        return const EdgeInsets.fromLTRB(30, 16, 30, 48);
      default:
        return const EdgeInsets.fromLTRB(22, 12, 22, 38);
    }
  }

  Future<void> setModuleVisible(
    String id,
    bool visible,
  ) async {
    if (visible) {
      hiddenDashboard.remove(id);
    } else {
      hiddenDashboard.add(id);
    }
    notifyListeners();
    await save();
  }

  Future<void> moveModule(
    String id,
    int delta,
  ) async {
    final index = dashboardOrder.indexOf(id);
    if (index < 0) return;
    final next = (index + delta)
        .clamp(0, dashboardOrder.length - 1)
        .toInt();
    if (next == index) return;
    dashboardOrder.removeAt(index);
    dashboardOrder.insert(next, id);
    notifyListeners();
    await save();
  }

  bool visible(String id) =>
      !hiddenDashboard.contains(id);
}

class HybridConfigScope
    extends InheritedNotifier<HybridConfig> {
  const HybridConfigScope({
    super.key,
    required HybridConfig config,
    required super.child,
  }) : super(notifier: config);

  static HybridConfig? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<
            HybridConfigScope>();
    return scope?.notifier;
  }

  static final HybridConfig _fallback = HybridConfig()
    ..loaded = true;

  static HybridConfig of(BuildContext context) {
    final config = maybeOf(context);
    return config ?? _fallback;
  }
}

class HybridShell extends StatefulWidget {
  const HybridShell({super.key});

  @override
  State<HybridShell> createState() => _HybridShellState();
}

class _HybridShellState extends State<HybridShell> {
  final config = HybridConfig();
  int index = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await config.load();
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    config.dispose();
    super.dispose();
  }

  void _openVault() {
    setState(() => index = 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!config.loaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return HybridConfigScope(
      config: config,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tablet = constraints.maxWidth >= 900;

          final pages = [
            HybridDashboard(
              onOpenVault: _openVault,
              onOpenCreator: () {
                setState(() => index = 2);
              },
            ),
            const VaultWorkspace(),
            HybridCreatorHub(
              onCreated: _openVault,
            ),
            const HybridNetworkPage(),
            const HybridCustomizePage(),
          ];

          if (!tablet) {
            return Scaffold(
              body: IndexedStack(
                index: index,
                children: pages,
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (value) {
                  setState(() => index = value);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Merkez',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.auto_stories_outlined),
                    selectedIcon: Icon(Icons.auto_stories_rounded),
                    label: 'Kasa',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome_rounded),
                    label: 'Oluştur',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.hub_outlined),
                    selectedIcon: Icon(Icons.hub_rounded),
                    label: 'Ağ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_outlined),
                    selectedIcon: Icon(Icons.tune_rounded),
                    label: 'Özelleştir',
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _HybridRail(
                    selected: index,
                    onSelected: (value) {
                      setState(() => index = value);
                    },
                  ),
                  const VerticalDivider(),
                  Expanded(
                    child: IndexedStack(
                      index: index,
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HybridRail extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _HybridRail({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final config = HybridConfigScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    const items = [
      (Icons.dashboard_rounded, 'Merkez'),
      (Icons.auto_stories_rounded, 'Kasa'),
      (Icons.auto_awesome_rounded, 'Oluştur'),
      (Icons.hub_rounded, 'Ağ'),
      (Icons.tune_rounded, 'Özelleştir'),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: config.showRailLabels ? 112 : 72,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const _FantasyIcon(
              'book_open',
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: selected == i
                    ? scheme.surfaceContainerLow
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: () => onSelected(i),
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    width: double.infinity,
                    height: config.showRailLabels ? 66 : 52,
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].$1,
                          color: selected == i
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        if (config.showRailLabels) ...[
                          const SizedBox(height: 5),
                          Text(
                            items[i].$2,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: selected == i
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                              fontWeight: selected == i
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HybridDashboard extends StatelessWidget {
  final VoidCallback onOpenVault;
  final VoidCallback onOpenCreator;

  const HybridDashboard({
    super.key,
    required this.onOpenVault,
    required this.onOpenCreator,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final config = HybridConfigScope.of(context);

    return Column(
      children: [
        _HybridTopBar(
          title: 'Kampanya Merkezi',
          subtitle:
              '${store.vaultName} • kişisel çalışma alanın',
          actions: [
            IconButton(
              tooltip: 'Kasa',
              onPressed: onOpenVault,
              icon: const Icon(Icons.auto_stories_outlined),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              42,
            ),
            children: [
              _HybridHero(
                store: store,
                config: config,
                onOpenVault: onOpenVault,
                onOpenCreator: onOpenCreator,
              ),
              const SizedBox(height: 18),
              for (final module in config.dashboardOrder)
                if (config.visible(module)) ...[
                  _DashboardModule(
                    id: module,
                    onOpenVault: onOpenVault,
                    onOpenCreator: onOpenCreator,
                  ),
                  const SizedBox(height: 18),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HybridHero extends StatelessWidget {
  final VaultStore store;
  final HybridConfig config;
  final VoidCallback onOpenVault;
  final VoidCallback onOpenCreator;

  const _HybridHero({
    required this.store,
    required this.config,
    required this.onOpenVault,
    required this.onOpenCreator,
  });

  @override
  Widget build(BuildContext context) {
    final notes =
        store.notes.where((n) => !n.archived).toList();
    final links = notes.fold<int>(
      0,
      (sum, note) =>
          sum + store.extractNoteLinks(note).length,
    );
    final tasks = notes.fold<int>(
      0,
      (sum, note) =>
          sum + store.tasksFor(note).length,
    );

    return Container(
      padding: EdgeInsets.all(
        config.compactCards ? 16 : 22,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2A2140),
            Color(0xFF171B24),
            Color(0xFF101319),
          ],
        ),
        borderRadius:
            BorderRadius.circular(config.cardRadius + 5),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const _FantasyIcon(
              'book_open',
              size: 44,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.vaultName,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'İçerik tamamen sana ait. Uygulama yalnızca araçları sağlar.',
                  style: TextStyle(
                    color: AppColors.muted,
                  ),
                ),
                if (config.showHeroStats) ...[
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _HeroMetric(
                        icon: Icons.notes_rounded,
                        text: '${notes.length} kayıt',
                      ),
                      _HeroMetric(
                        icon: Icons.link_rounded,
                        text: '$links bağlantı',
                      ),
                      _HeroMetric(
                        icon: Icons.check_box_outlined,
                        text: '$tasks görev',
                      ),
                      _HeroMetric(
                        icon: Icons.tag_rounded,
                        text:
                            '${store.allTags.length} etiket',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          if (MediaQuery.sizeOf(context).width >= 700)
            Column(
              children: [
                FilledButton.icon(
                  onPressed: onOpenCreator,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Oluştur'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onOpenVault,
                  icon:
                      const Icon(Icons.auto_stories_outlined),
                  label: const Text('Kasayı Aç'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroMetric({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.muted,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFFD5D8E0),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardModule extends StatelessWidget {
  final String id;
  final VoidCallback onOpenVault;
  final VoidCallback onOpenCreator;

  const _DashboardModule({
    required this.id,
    required this.onOpenVault,
    required this.onOpenCreator,
  });

  @override
  Widget build(BuildContext context) {
    switch (id) {
      case 'quick':
        return _QuickCreateModule(
          onOpenVault: onOpenVault,
          onOpenCreator: onOpenCreator,
        );
      case 'recent':
        return _NotesModule(
          title: 'Son Düzenlenenler',
          mode: 'recent',
          onOpenVault: onOpenVault,
        );
      case 'pinned':
        return _NotesModule(
          title: 'Sabitlenenler',
          mode: 'pinned',
          onOpenVault: onOpenVault,
        );
      case 'tasks':
        return const _TaskModule();
      case 'links':
        return const _LinkHealthModule();
      case 'tags':
        return const _TagModule();
      case 'bookmarks':
        return _NotesModule(
          title: 'Yer İmleri',
          mode: 'bookmarks',
          onOpenVault: onOpenVault,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _QuickCreateModule extends StatelessWidget {
  final VoidCallback onOpenVault;
  final VoidCallback onOpenCreator;

  const _QuickCreateModule({
    required this.onOpenVault,
    required this.onOpenCreator,
  });

  @override
  Widget build(BuildContext context) {
    final config = HybridConfigScope.of(context);
    final store = VaultScope.of(context);

    Future<void> create(NoteType type) async {
      await store.create(type);
      onOpenVault();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HybridSectionHeader(
          title: 'Hızlı Oluştur',
          actionText: 'Tümü',
          onAction: onOpenCreator,
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: config.compactCards ? 96 : 116,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _HybridQuickCard(
                icon: 'note',
                title: 'Not',
                subtitle: 'Serbest içerik',
                onTap: () => create(NoteType.note),
              ),
              _HybridQuickCard(
                icon: 'npc',
                title: 'NPC',
                subtitle: 'Detaylı veya boş',
                onTap: () => create(NoteType.npc),
              ),
              _HybridQuickCard(
                icon: 'monster',
                title: 'Canavar',
                subtitle: 'Stat + property',
                onTap: () => create(NoteType.monster),
              ),
              _HybridQuickCard(
                icon: 'session',
                title: 'Oturum',
                subtitle: 'Plan + notlar',
                onTap: () => create(NoteType.session),
              ),
              _HybridQuickCard(
                icon: 'location',
                title: 'Mekân',
                subtitle: 'Bağlantılı not yapısı',
                onTap: () => create(NoteType.location),
              ),
              _HybridQuickCard(
                icon: 'quest',
                title: 'Görev',
                subtitle: 'Task + property',
                onTap: () => create(NoteType.quest),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HybridQuickCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HybridQuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = HybridConfigScope.of(context);

    return Container(
      width: config.compactCards ? 172 : 210,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: AppColors.panel,
        borderRadius:
            BorderRadius.circular(config.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(config.cardRadius),
          child: Padding(
            padding: EdgeInsets.all(
              config.compactCards ? 11 : 14,
            ),
            child: Row(
              children: [
                _FantasyIcon(
                  icon,
                  size: config.compactCards ? 34 : 42,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesModule extends StatelessWidget {
  final String title;
  final String mode;
  final VoidCallback onOpenVault;

  const _NotesModule({
    required this.title,
    required this.mode,
    required this.onOpenVault,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    List<NoteRecord> notes;

    if (mode == 'pinned') {
      notes = store.notes
          .where((n) => n.pinned && !n.archived)
          .toList();
    } else if (mode == 'bookmarks') {
      notes = store.notes
          .where((n) => n.bookmarked && !n.archived)
          .toList();
    } else {
      notes = store.notes
          .where((n) => !n.archived)
          .toList()
        ..sort(
          (a, b) => b.updatedAt.compareTo(a.updatedAt),
        );
    }

    notes = notes.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HybridSectionHeader(
          title: title,
          actionText: 'Kasayı Aç',
          onAction: onOpenVault,
        ),
        const SizedBox(height: 9),
        if (notes.isEmpty)
          _HybridEmptyCard(
            icon: mode == 'pinned'
                ? Icons.push_pin_outlined
                : mode == 'bookmarks'
                    ? Icons.bookmark_border_rounded
                    : Icons.history_rounded,
            text: mode == 'recent'
                ? 'Henüz kayıt yok.'
                : '$title henüz boş.',
          )
        else
          for (final note in notes) ...[
            _HybridNoteRow(
              note: note,
              onTap: () {
                store.select(note.id);
                onOpenVault();
              },
            ),
            const SizedBox(height: 7),
          ],
      ],
    );
  }
}

class _TaskModule extends StatelessWidget {
  const _TaskModule();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final tasks = <String>[];

    for (final note in store.notes.where(
      (n) => !n.archived,
    )) {
      tasks.addAll(
        store.tasksFor(note).where(
              (line) =>
                  line.trimLeft().startsWith('- [ ]'),
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HybridSectionHeader(
          title: 'Açık Görevler',
        ),
        const SizedBox(height: 9),
        if (tasks.isEmpty)
          const _HybridEmptyCard(
            icon: Icons.check_box_outlined,
            text: 'Henüz açık görev yok.',
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _hybridDecoration(context),
            child: Column(
              children: [
                for (final task in tasks.take(8))
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .check_box_outline_blank_rounded,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            task
                                .replaceFirst('- [ ]', '')
                                .trim(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LinkHealthModule extends StatelessWidget {
  const _LinkHealthModule();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final active =
        store.notes.where((n) => !n.archived).toList();

    final unresolved = active.fold<int>(
      0,
      (sum, note) =>
          sum + store.unresolvedLinks(note).length,
    );

    final links = active.fold<int>(
      0,
      (sum, note) =>
          sum + store.extractNoteLinks(note).length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HybridSectionHeader(
          title: 'Bağlantı Sağlığı',
        ),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final cards = [
              _StatCard(
                icon: Icons.link_rounded,
                value: '$links',
                label: 'Toplam link',
              ),
              _StatCard(
                icon: Icons.link_off_rounded,
                value: '${store.orphanCount}',
                label: 'Bağlantısız not',
              ),
              _StatCard(
                icon: Icons.add_link_rounded,
                value: '$unresolved',
                label: 'Eksik hedef',
              ),
            ];

            if (compact) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    SizedBox(
                      width: double.infinity,
                      child: cards[i],
                    ),
                    if (i < cards.length - 1)
                      const SizedBox(height: 9),
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 9),
                Expanded(child: cards[1]),
                const SizedBox(width: 9),
                Expanded(child: cards[2]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TagModule extends StatelessWidget {
  const _TagModule();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HybridSectionHeader(
          title: 'Etiketler',
        ),
        const SizedBox(height: 9),
        if (store.allTags.isEmpty)
          const _HybridEmptyCard(
            icon: Icons.tag_rounded,
            text: 'Henüz etiket yok.',
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _hybridDecoration(context),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final tag in store.allTags)
                  ActionChip(
                    label: Text(tag),
                    onPressed: () {
                      store.setTag(tag);
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HybridNoteRow extends StatelessWidget {
  final NoteRecord note;
  final VoidCallback onTap;

  const _HybridNoteRow({
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(
        HybridConfigScope.of(context).cardRadius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          HybridConfigScope.of(context).cardRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _FantasyIcon(
                note.type.iconAsset,
                size: 31,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.trim().isEmpty
                          ? 'Başlıksız'
                          : note.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${note.type.label} • '
                      '${store.extractNoteLinks(note).length} link',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HybridEmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HybridEmptyCard({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _hybridDecoration(context),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.muted,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        HybridConfigScope.of(context).compactCards
            ? 12
            : 16,
      ),
      decoration: _hybridDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.purple,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class HybridCreatorHub extends StatelessWidget {
  final VoidCallback onCreated;

  const HybridCreatorHub({
    super.key,
    required this.onCreated,
  });

  @override
  Widget build(BuildContext context) {
    final config = HybridConfigScope.of(context);

    return Column(
      children: [
        _HybridTopBar(
          title: 'Creator Hub',
          subtitle:
              'Alanları uygulama sağlar; içerikleri sen doldurursun.',
          actions: const [],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 1300
                      ? 4
                      : constraints.maxWidth >= 850
                          ? 3
                          : 2;

              return GridView.count(
                padding: const EdgeInsets.all(20),
                crossAxisCount: columns,
                mainAxisSpacing: 11,
                crossAxisSpacing: 11,
                childAspectRatio:
                    config.compactCards ? 1.65 : 1.40,
                children: [
                  for (final type in NoteType.values)
                    _HybridCreatorCard(
                      type: type,
                      onTap: () =>
                          _openStructuredCreator(
                        context,
                        type,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openStructuredCreator(
    BuildContext context,
    NoteType type,
  ) async {
    final hybridConfig = HybridConfigScope.of(context);

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HybridConfigScope(
          config: hybridConfig,
          child: StructuredCreatorPage(
            type: type,
          ),
        ),
      ),
    );

    if (result == true) {
      onCreated();
    }
  }
}

class _HybridCreatorCard extends StatelessWidget {
  final NoteType type;
  final VoidCallback onTap;

  const _HybridCreatorCard({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final description = _creatorDescription(type);

    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(
        HybridConfigScope.of(context).cardRadius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          HybridConfigScope.of(context).cardRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _FantasyIcon(
                type.iconAsset,
                size: 43,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _creatorDescription(NoteType type) {
    switch (type) {
      case NoteType.npc:
        return 'Kimlik, görünüş, rolplay, motivasyon, sır ve özel property alanları.';
      case NoteType.monster:
        return 'CR, AC, HP, ability score, saldırı, direnç, taktik ve loot.';
      case NoteType.session:
        return 'Tarih, oyuncular, recap, sahneler, encounter, loot ve sonraki notlar.';
      case NoteType.location:
        return 'Tür, atmosfer, bölge, önemli kişiler, sırlar ve not bağlantıları.';
      case NoteType.quest:
        return 'Hedef, ödül, durum, başarısızlık koşulu ve task listesi.';
      case NoteType.item:
        return 'Tür, nadirlik, değer, mekanik, lanet ve sahibi.';
      case NoteType.organization:
        return 'Amaç, liderlik, üyeler, bölge, ilişki ve gizli bilgiler.';
      case NoteType.lore:
        return 'Tarih, kaynak, söylenti, gerçek ve bağlantılar.';
      case NoteType.rule:
        return 'Kural başlığı, kaynak, açıklama ve house-rule notları.';
      case NoteType.journal:
        return 'Serbest günlük / kronoloji kaydı.';
      case NoteType.handout:
        return 'Oyuncuya gösterilecek metin ve görünürlük.';
      case NoteType.template:
        return 'Kendi şablonunu oluştur; property ve metin yapısını sen belirle.';
      case NoteType.note:
        return 'Tamamen serbest bağlantılı not.';
    }
  }
}

class StructuredCreatorPage extends StatefulWidget {
  final NoteType type;

  const StructuredCreatorPage({
    super.key,
    required this.type,
  });

  @override
  State<StructuredCreatorPage> createState() =>
      _StructuredCreatorPageState();
}

class _StructuredCreatorPageState
    extends State<StructuredCreatorPage> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final Map<String, TextEditingController> fields = {};
  final List<String> customFields = [];
  final Set<String> selectedFields = {};
  final folderController = TextEditingController(text: '/');
  final tagsController = TextEditingController();
  String visibility = 'Sadece Ben';

  @override
  void initState() {
    super.initState();
    for (final label in _baseFields(widget.type)) {
      fields[label] = TextEditingController();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    folderController.dispose();
    tagsController.dispose();
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allLabels = [
      ..._baseFields(widget.type),
      ...customFields,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.type.label} Oluştur'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Kaydet'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tablet = constraints.maxWidth >= 900;

          final form = ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            children: [
              _StructuredIntro(type: widget.type),
              const SizedBox(height: 18),
              _CreatorTitleField(
                controller: titleController,
                type: widget.type,
              ),
              const SizedBox(height: 12),
              _RecordMetaCard(
                visibility: visibility,
                folderController: folderController,
                tagsController: tagsController,
                onVisibilityChanged: (value) {
                  setState(() => visibility = value);
                },
              ),
              const SizedBox(height: 18),
              _DetailSelectorCard(
                type: widget.type,
                selectedCount: selectedFields.length,
                selectedLabels: selectedFields.toList(),
                onTap: _openDetailSelector,
              ),
              if (selectedFields.isNotEmpty) ...[
                const SizedBox(height: 18),
                _CreatorSectionLabel(
                  icon: Icons.tune_rounded,
                  title: 'Seçilen Ayrıntılar',
                  subtitle:
                      'Yalnızca seçtiğin alanlar burada görünür. İstediğin zaman Ayrıntılar kartından değiştirebilirsin.',
                ),
                const SizedBox(height: 10),
                for (final label in allLabels.where(selectedFields.contains)) ...[
                  _CreatorField(
                    label: label,
                    controller: fields.putIfAbsent(
                      label,
                      TextEditingController.new,
                    ),
                    multiline: _isLongField(label),
                    icon: _fieldIcon(label),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 10),
              _AddFieldCard(onTap: _addField),
              const SizedBox(height: 20),
              const _CreatorSectionLabel(
                icon: Icons.edit_note_rounded,
                title: 'Serbest Not',
                subtitle:
                    'Not bağlantıları, etiketler, görevler ve uzun metinlerin için.',
              ),
              const SizedBox(height: 10),
              _CreatorField(
                label: 'Serbest Not',
                controller: bodyController,
                multiline: true,
                minLines: 9,
                icon: Icons.notes_rounded,
                hint:
                    '[[Not bağlantısı]], #etiket, - [ ] görev, başlıklar ve serbest not...',
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Kaydet ve Aç'),
              ),
            ],
          );

          if (!tablet) return form;

          return Row(
            children: [
              Expanded(child: form),
              const VerticalDivider(),
              SizedBox(
                width: 330,
                child: _CreatorPreview(
                  type: widget.type,
                  titleController: titleController,
                  fields: fields,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addField() async {
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Özel Alan Ekle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Alan adı',
            hintText: 'Örn. Tehlike Seviyesi',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (value == null ||
        value.isEmpty ||
        fields.containsKey(value)) {
      return;
    }

    setState(() {
      customFields.add(value);
      fields[value] = TextEditingController();
      selectedFields.add(value);
    });
  }

  Future<void> _openDetailSelector() async {
    final available = [
      ..._baseFields(widget.type),
      ...customFields,
    ];

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final draft = <String>{...selectedFields};
        var fieldQuery = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final sections = _TypeNoteSchema.sections(widget.type);
            final baseFieldSet = _baseFields(widget.type).toSet();

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.88,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: _FantasyIcon(
                              widget.type.iconAsset,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ayrıntılar',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${widget.type.label} kaydında kullanmak istediğin alanları seç.',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        onChanged: (value) {
                          setSheetState(() => fieldQuery = value.trim().toLowerCase());
                        },
                        decoration: const InputDecoration(
                          hintText: 'Alan ara...',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                            label: const Text('Temel'),
                            onPressed: () {
                              final first = sections.isEmpty
                                  ? <String>[]
                                  : sections.first.fields;
                              setSheetState(() {
                                draft
                                  ..clear()
                                  ..addAll(first);
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.select_all_rounded, size: 16),
                            label: const Text('Tümünü Seç'),
                            onPressed: () {
                              setSheetState(() {
                                draft
                                  ..clear()
                                  ..addAll(available);
                              });
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.clear_all_rounded, size: 16),
                            label: const Text('Temizle'),
                            onPressed: () {
                              setSheetState(draft.clear);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                        children: [
                          for (final section in sections) ...[
                            _DetailSectionHeader(section: section),
                            const SizedBox(height: 7),
                            for (final label in section.fields.where(
                              (item) => fieldQuery.isEmpty ||
                                  item.toLowerCase().contains(fieldQuery),
                            ))
                              _DetailFieldChoice(
                                label: label,
                                icon: _fieldIcon(label),
                                selected: draft.contains(label),
                                onChanged: (value) {
                                  setSheetState(() {
                                    if (value) {
                                      draft.add(label);
                                    } else {
                                      draft.remove(label);
                                    }
                                  });
                                },
                              ),
                            const SizedBox(height: 14),
                          ],
                          if (customFields.isNotEmpty) ...[
                            const _CreatorSectionLabel(
                              icon: Icons.extension_outlined,
                              title: 'Kendi Alanların',
                              subtitle: 'Senin eklediğin özel alanlar.',
                            ),
                            const SizedBox(height: 7),
                            for (final label in customFields.where(
                              (item) => fieldQuery.isEmpty ||
                                  item.toLowerCase().contains(fieldQuery),
                            ))
                              _DetailFieldChoice(
                                label: label,
                                icon: _fieldIcon(label),
                                selected: draft.contains(label),
                                onChanged: (value) {
                                  setSheetState(() {
                                    if (value) {
                                      draft.add(label);
                                    } else {
                                      draft.remove(label);
                                    }
                                  });
                                },
                              ),
                          ],
                          if (baseFieldSet.isEmpty && customFields.isEmpty)
                            const _HybridEmptyCard(
                              icon: Icons.tune_rounded,
                              text: 'Bu kayıt türünde hazır ayrıntı alanı yok. Kendi alanını ekleyebilirsin.',
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${draft.length} alan seçili',
                              style: const TextStyle(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('İptal'),
                          ),
                          const SizedBox(width: 7),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(
                              sheetContext,
                              <String>{...draft},
                            ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Uygula'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      selectedFields
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _save() async {
    final store = VaultScope.of(context);
    final note = await store.create(widget.type);
    note.title = titleController.text.trim();
    note.content = bodyController.text;
    note.visibility = visibility;
    note.properties['folder'] = folderController.text.trim().isEmpty
        ? '/'
        : folderController.text.trim();
    if (tagsController.text.trim().isNotEmpty) {
      note.properties['tags'] = tagsController.text.trim();
      note.propertyTypes['tags'] = 'tags';
    } else {
      note.properties.remove('tags');
      note.propertyTypes.remove('tags');
    }
    note.detailFields = selectedFields.toList();

    for (final entry in fields.entries) {
      final value = entry.value.text;
      if (selectedFields.contains(entry.key) || value.trim().isNotEmpty) {
        note.properties[entry.key] = value;
        note.propertyTypes[entry.key] =
            _guessPropertyType(entry.key);
      }
    }

    note.updatedAt = DateTime.now();
    await store._save();
    store.notifyListeners();

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _guessPropertyType(String label) =>
      _guessPropertyTypeStatic(label);

  static String _guessPropertyTypeStatic(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('tarih')) return 'date';
    if (lower == 'ac' ||
        lower == 'hp' ||
        lower == 'str' ||
        lower == 'dex' ||
        lower == 'con' ||
        lower == 'int' ||
        lower == 'wis' ||
        lower == 'cha' ||
        lower.contains('seviye')) {
      return 'number';
    }
    if (lower.contains('etiket')) return 'tags';
    return 'text';
  }

  static IconData _fieldIcon(String label) {
    final lower = label.toLowerCase();

    if (lower.contains('tarih')) return Icons.calendar_today_outlined;
    if (lower.contains('konum') || lower.contains('bölge') || lower.contains('merkez')) {
      return Icons.place_outlined;
    }
    if (lower.contains('ırk') || lower.contains('tür')) return Icons.category_outlined;
    if (lower.contains('yaş')) return Icons.cake_outlined;
    if (lower.contains('meslek') || lower.contains('rol')) return Icons.badge_outlined;
    if (lower.contains('görünüş')) return Icons.visibility_outlined;
    if (lower.contains('kişilik')) return Icons.psychology_outlined;
    if (lower.contains('ses') || lower.contains('konuşma')) return Icons.record_voice_over_outlined;
    if (lower.contains('motivasyon') || lower.contains('hedef') || lower.contains('amaç')) {
      return Icons.flag_outlined;
    }
    if (lower.contains('korku') || lower.contains('tehlike')) return Icons.warning_amber_rounded;
    if (lower.contains('sır') || lower.contains('gizli') || lower.contains('lanet')) {
      return Icons.lock_outline_rounded;
    }
    if (lower.contains('ilişki') || lower.contains('müttefik') || lower.contains('düşman')) {
      return Icons.hub_outlined;
    }
    if (lower == 'hp' || lower.contains('hit point')) return Icons.favorite_border_rounded;
    if (lower == 'ac') return Icons.shield_outlined;
    if (lower.contains('hız')) return Icons.speed_rounded;
    if (lower == 'str' || lower == 'dex' || lower == 'con' ||
        lower == 'int' || lower == 'wis' || lower == 'cha') {
      return Icons.analytics_outlined;
    }
    if (lower.contains('saldırı')) return Icons.flash_on_outlined;
    if (lower.contains('direnç') || lower.contains('bağışıklık')) return Icons.security_outlined;
    if (lower.contains('loot') || lower.contains('ödül') || lower.contains('değer')) {
      return Icons.inventory_2_outlined;
    }
    if (lower.contains('oyuncu') || lower.contains('üye')) return Icons.groups_outlined;
    if (lower.contains('özet') || lower.contains('açıklama')) return Icons.subject_rounded;
    if (lower.contains('sahne')) return Icons.movie_filter_outlined;
    if (lower.contains('encounter')) return Icons.sports_mma_outlined;
    if (lower.contains('kaynak')) return Icons.menu_book_outlined;
    if (lower.contains('durum')) return Icons.radio_button_checked_rounded;
    if (lower.contains('kategori')) return Icons.label_outline_rounded;
    return Icons.edit_outlined;
  }

  static bool _isLongField(String label) {
    final lower = label.toLowerCase();
    return lower.contains('açıklama') ||
        lower.contains('görünüş') ||
        lower.contains('kişilik') ||
        lower.contains('motivasyon') ||
        lower.contains('sır') ||
        lower.contains('taktik') ||
        lower.contains('özet') ||
        lower.contains('sahne') ||
        lower.contains('not') ||
        lower.contains('geçmiş') ||
        lower.contains('atmosfer') ||
        lower.contains('mekanik') ||
        lower.contains('hedef');
  }

  static List<String> _baseFields(NoteType type) {
    return _TypeNoteSchema.sections(type)
        .expand((section) => section.fields)
        .toSet()
        .toList();
  }
}


class _DetailSelectorCard extends StatelessWidget {
  final NoteType type;
  final int selectedCount;
  final List<String> selectedLabels;
  final VoidCallback onTap;

  const _DetailSelectorCard({
    required this.type,
    required this.selectedCount,
    required this.selectedLabels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = HybridConfigScope.of(context);
    final preview = selectedLabels.take(3).join(' • ');
    final extra = selectedCount > 3 ? ' +${selectedCount - 3}' : '';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(config.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(config.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF191523),
                Color(0xFF11151B),
              ],
            ),
            borderRadius: BorderRadius.circular(config.cardRadius),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.26),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Ayrıntılar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$selectedCount seçili',
                            style: const TextStyle(
                              color: AppColors.purple,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedCount == 0
                          ? '${type.label} için hangi alanları kullanacağını buradan seç.'
                          : '$preview$extra',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSectionHeader extends StatelessWidget {
  final _TypeNoteSection section;

  const _DetailSectionHeader({
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            section.icon,
            size: 18,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                section.subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailFieldChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _DetailFieldChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected
            ? AppColors.purple.withValues(alpha: 0.08)
            : AppColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 9,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? AppColors.purple
                      : AppColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: (value) => onChanged(value ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorTitleField extends StatelessWidget {
  final TextEditingController controller;
  final NoteType type;
  final ValueChanged<String>? onChanged;

  const _CreatorTitleField({
    required this.controller,
    required this.type,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(
          HybridConfigScope.of(context).cardRadius,
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.circular(13),
            ),
            child: _FantasyIcon(type.iconAsset, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
              decoration: const InputDecoration(
                hintText: 'Başlık / Ad',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordMetaCard extends StatelessWidget {
  final String visibility;
  final TextEditingController folderController;
  final TextEditingController tagsController;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<String>? onFolderChanged;
  final ValueChanged<String>? onTagsChanged;

  const _RecordMetaCard({
    required this.visibility,
    required this.folderController,
    required this.tagsController,
    required this.onVisibilityChanged,
    this.onFolderChanged,
    this.onTagsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.gold),
              SizedBox(width: 8),
              Text(
                'DÜZEN & GÖRÜNÜRLÜK',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.visibility_outlined, size: 16),
                label: Text(visibility),
                onPressed: () async {
                  final result = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    builder: (sheetContext) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final value in const [
                              'Sadece Ben',
                              'Sadece DM',
                              'Tüm Kampanya',
                              'Seçili Oyuncular',
                            ])
                              ChoiceChip(
                                label: Text(value),
                                selected: value == visibility,
                                onSelected: (_) => Navigator.pop(sheetContext, value),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (result != null) onVisibilityChanged(result);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: folderController,
                  onChanged: onFolderChanged,
                  decoration: const InputDecoration(
                    labelText: 'Klasör',
                    hintText: '/Kampanya/NPC',
                    prefixIcon: Icon(Icons.folder_outlined),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: tagsController,
                  onChanged: onTagsChanged,
                  decoration: const InputDecoration(
                    labelText: 'Etiketler',
                    hintText: 'ana, şehir, aktif',
                    prefixIcon: Icon(Icons.tag_rounded),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatorSectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CreatorSectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreatorField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool multiline;
  final int? minLines;
  final IconData icon;
  final String? hint;
  final ValueChanged<String>? onChanged;

  const _CreatorField({
    required this.label,
    required this.controller,
    required this.icon,
    this.multiline = false,
    this.minLines,
    this.hint,
    this.onChanged,
  });

  @override
  State<_CreatorField> createState() => _CreatorFieldState();
}

class _CreatorFieldState extends State<_CreatorField> {
  bool focused = false;
  late final FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode()
      ..addListener(() {
        if (!mounted) return;
        setState(() => focused = focusNode.hasFocus);
      });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  bool get _isDate => widget.label.toLowerCase().contains('tarih');

  bool get _isNumber {
    final value = widget.label.toLowerCase().trim();
    return const {
      'ac', 'hp', 'str', 'dex', 'con', 'int', 'wis', 'cha',
      'passive perception', 'proficiency bonus', 'oturum no',
    }.contains(value) || value.contains('seviye');
  }

  bool get _supportsLinks {
    final value = widget.label.toLowerCase();
    return value.contains('bağlant') ||
        value.contains('ilişki') ||
        value.contains('npc') ||
        value.contains('fraksiyon') ||
        value.contains('müttefik') ||
        value.contains('düşman') ||
        value.contains('sahibi') ||
        value.contains('lider') ||
        value.contains('görevi veren') ||
        value.contains('başlangıç konumu');
  }

  List<String> get _choices {
    final value = widget.label.toLowerCase().trim();
    if (value == 'durum') {
      return const ['Taslak', 'Aktif', 'Beklemede', 'Tamamlandı', 'Kapalı'];
    }
    if (value == 'öncelik') {
      return const ['Düşük', 'Orta', 'Yüksek', 'Kritik'];
    }
    if (value == 'nadirlik') {
      return const ['Sıradan', 'Nadir Olmayan', 'Nadir', 'Çok Nadir', 'Efsanevi', 'Eşsiz'];
    }
    if (value == 'boyut') {
      return const ['Tiny', 'Small', 'Medium', 'Large', 'Huge', 'Gargantuan'];
    }
    if (value == 'attunement') {
      return const ['Hayır', 'Evet', 'Koşullu'];
    }
    if (value == 'görünürlük') {
      return const ['Sadece Ben', 'Sadece DM', 'Tüm Kampanya', 'Seçili Oyuncular'];
    }
    return const [];
  }

  void _setValue(String value) {
    widget.controller.text = value;
    widget.controller.selection = TextSelection.collapsed(
      offset: value.length,
    );
    widget.onChanged?.call(value);
    setState(() {});
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(widget.controller.text.trim());
    final result = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (result == null) return;
    _setValue(
      '${result.year.toString().padLeft(4, '0')}-'
      '${result.month.toString().padLeft(2, '0')}-'
      '${result.day.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _pickChoice() async {
    final values = _choices;
    if (values.isEmpty) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in values)
                    ChoiceChip(
                      label: Text(item),
                      selected: widget.controller.text == item,
                      onSelected: (_) => Navigator.pop(context, item),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) _setValue(result);
  }

  void _stepNumber(int delta) {
    final current = int.tryParse(widget.controller.text.trim()) ?? 0;
    _setValue('${current + delta}');
  }

  @override
  Widget build(BuildContext context) {
    final config = HybridConfigScope.of(context);
    final hasValue = widget.controller.text.trim().isNotEmpty;

    final actions = <Widget>[];
    if (_isDate) {
      actions.add(
        IconButton(
          tooltip: 'Tarih seç',
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month_outlined, size: 19),
        ),
      );
    } else if (_choices.isNotEmpty) {
      actions.add(
        IconButton(
          tooltip: 'Seçenekler',
          onPressed: _pickChoice,
          icon: const Icon(Icons.expand_more_rounded, size: 20),
        ),
      );
    } else if (_supportsLinks) {
      actions.add(
        IconButton(
          tooltip: 'Kayıt bağlantısı ekle',
          onPressed: () => _showLinkPicker(
            context,
            widget.controller,
            () => widget.onChanged?.call(widget.controller.text),
          ),
          icon: const Icon(Icons.add_link_rounded, size: 19),
        ),
      );
    }

    if (_isNumber && !widget.multiline) {
      actions.addAll([
        IconButton(
          tooltip: 'Azalt',
          onPressed: () => _stepNumber(-1),
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        IconButton(
          tooltip: 'Artır',
          onPressed: () => _stepNumber(1),
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ]);
    }

    if (hasValue && !widget.multiline) {
      actions.add(
        IconButton(
          tooltip: 'Temizle',
          onPressed: () => _setValue(''),
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.fromLTRB(
        13,
        widget.multiline ? 11 : 8,
        actions.isEmpty ? 13 : 4,
        widget.multiline ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: focused
            ? AppColors.panel2
            : AppColors.panel.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(
          (config.cardRadius - 5)
              .clamp(10.0, 22.0)
              .toDouble(),
        ),
        border: Border.all(
          color: focused
              ? AppColors.purple.withValues(alpha: 0.82)
              : AppColors.border,
          width: focused ? 1.25 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.08),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Row(
        crossAxisAlignment: widget.multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: widget.multiline ? 4 : 0,
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: focused
                  ? AppColors.purple
                  : AppColors.muted,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    color: focused
                        ? AppColors.purple
                        : AppColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.55,
                  ),
                ),
                const SizedBox(height: 3),
                TextField(
                  controller: widget.controller,
                  focusNode: focusNode,
                  keyboardType: _isNumber
                      ? const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: false,
                        )
                      : widget.multiline
                          ? TextInputType.multiline
                          : TextInputType.text,
                  minLines: widget.multiline
                      ? (widget.minLines ?? 3)
                      : 1,
                  maxLines: widget.multiline ? null : 1,
                  onChanged: (value) {
                    widget.onChanged?.call(value);
                    if (mounted) setState(() {});
                  },
                  onTap: _choices.isNotEmpty ? _pickChoice : null,
                  readOnly: _choices.isNotEmpty,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint ??
                        (_choices.isNotEmpty
                            ? 'Seç...'
                            : widget.multiline
                                ? 'Detay ekle...'
                                : 'Değer gir...'),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 116),
              child: Wrap(
                spacing: 0,
                runSpacing: 0,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddFieldCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFieldCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.38),
            ),
            color: AppColors.purple.withValues(alpha: 0.045),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.add_rounded,
                size: 20,
                color: AppColors.purple,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Kendi Alanını Ekle',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'özel alan',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StructuredIntro extends StatelessWidget {
  final NoteType type;

  const _StructuredIntro({
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF241C31),
            Color(0xFF151922),
          ],
        ),
        borderRadius: BorderRadius.circular(
          HybridConfigScope.of(context).cardRadius,
        ),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          _FantasyIcon(
            type.iconAsset,
            size: 44,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  type.label,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Alanları ihtiyacına göre seç, doldur veya kendi alanını ekle. Kayıtlarını daha sonra diğer kayıtlarla bağlantı kurarak ilişkilendirebilirsin.',
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorPreview extends StatelessWidget {
  final NoteType type;
  final TextEditingController titleController;
  final Map<String, TextEditingController> fields;

  const _CreatorPreview({
    required this.type,
    required this.titleController,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1015),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'CANLI YAPI',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: _FantasyIcon(
              type.iconAsset,
              size: 60,
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: titleController,
            builder: (_, value, __) => Text(
              value.text.trim().isEmpty
                  ? 'Başlıksız'
                  : value.text.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final entry in fields.entries)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: entry.value,
              builder: (_, value, __) {
                if (value.text.trim().isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(value.text),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class HybridNetworkPage extends StatefulWidget {
  const HybridNetworkPage({super.key});

  @override
  State<HybridNetworkPage> createState() =>
      _HybridNetworkPageState();
}

class _HybridNetworkPageState
    extends State<HybridNetworkPage> {
  int mode = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HybridTopBar(
          title: 'Bağlantı Alanı',
          subtitle:
              'Ağ, tablolar ve pano aynı kasayı kullanır.',
          actions: const [],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            10,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.hub_outlined),
                  label: Text('Ağ'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.table_chart_outlined),
                  label: Text('Tablolar'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.dashboard_outlined),
                  label: Text('Pano'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (values) {
                setState(() => mode = values.first);
              },
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: IndexedStack(
            index: mode,
            children: const [
              _GraphView(),
              _BasesPage(),
              _CanvasPage(),
            ],
          ),
        ),
      ],
    );
  }
}

class HybridCustomizePage extends StatelessWidget {
  const HybridCustomizePage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = HybridConfigScope.of(context);
    final store = VaultScope.of(context);

    return Column(
      children: [
        const _HybridTopBar(
          title: 'Özelleştir',
          subtitle:
              'Eski tasarımı bozma; hangi parçaların görüneceğine sen karar ver.',
          actions: [],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              42,
            ),
            children: [
              _CustomizeCard(
                title: 'Kasa',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.drive_file_rename_outline,
                    ),
                    title: const Text('Kasa adı'),
                    subtitle: Text(store.vaultName),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    onTap: () =>
                        _renameVault(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.archive_outlined,
                    ),
                    title: const Text('Arşivlenenler'),
                    subtitle: Text(
                      '${store.notes.where((n) => n.archived).length} kayıt',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const HybridArchivePage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CustomizeCard(
                title: 'Veri & Yedek',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.health_and_safety_outlined),
                    title: const Text('Kasa durumu'),
                    subtitle: Text(
                      store.storageError ??
                          '${store.notes.length} kayıt • ${store.notes.where((n) => n.archived).length} arşiv',
                      style: TextStyle(
                        color: store.storageError == null
                            ? AppColors.muted
                            : AppColors.red,
                      ),
                    ),
                    trailing: store.saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy_all_outlined),
                    title: const Text('Yedeği panoya kopyala'),
                    subtitle: const Text('Tüm kasa verisini JSON olarak kopyalar.'),
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: store.exportVaultJson()),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kasa yedeği panoya kopyalandı.')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restore_page_outlined),
                    title: const Text('Panodan içe aktar'),
                    subtitle: const Text('Yedeği mevcut kasaya birleştir veya kasayı değiştir.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _importFromClipboard(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CustomizeCard(
                title: 'Görünüm',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: config.showRailLabels,
                    title: const Text(
                      'Tablet menü etiketleri',
                    ),
                    subtitle: const Text(
                      'Sol rail üzerinde ikonların altında yazı göster.',
                    ),
                    onChanged: config.setRailLabels,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: config.compactCards,
                    title:
                        const Text('Kompakt kartlar'),
                    subtitle: const Text(
                      'Dashboard ve Creator Hub daha yoğun görünür.',
                    ),
                    onChanged: config.setCompact,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: config.showHeroStats,
                    title: const Text(
                      'Dashboard istatistikleri',
                    ),
                    onChanged: config.setHeroStats,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Kart köşesi: ${config.cardRadius.round()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Slider(
                    value: config.cardRadius,
                    min: 8,
                    max: 30,
                    divisions: 11,
                    label:
                        config.cardRadius.round().toString(),
                    onChanged: (value) {
                      config.setRadius(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CustomizeCard(
                title: 'Dashboard Modülleri',
                children: [
                  for (final id
                      in config.dashboardOrder)
                    _DashboardModuleSetting(
                      id: id,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const _CustomizeCard(
                title: 'Bağlantılı Kasa Araçları',
                children: [
                  _FeatureStatus(
                    title: 'Not Bağlantıları',
                    detail:
                        '[[Not]], takma ad, başlık ve blok hedefleri',
                  ),
                  _FeatureStatus(
                    title: 'Geri Bağlantılar',
                    detail:
                        'Bağlı ve bağlantısız referanslar',
                  ),
                  _FeatureStatus(
                    title: 'Özel Alanlar',
                    detail:
                        'İstediğin alanı ve veri türünü ekleyebilirsin',
                  ),
                  _FeatureStatus(
                    title: 'Ağ / Tablolar / Pano',
                    detail:
                        'Aynı not verisinin farklı çalışma görünümleri',
                  ),
                  _FeatureStatus(
                    title: 'Şablonlar / Günlük Notlar',
                    detail:
                        'Şablon ve günlük not altyapısı',
                  ),
                  _FeatureStatus(
                    title: 'Canlı Biçimlendirme',
                    detail:
                        'Aynı editörde biçimlendirme + kaynak görünümü',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _importFromClipboard(BuildContext context) async {
    final store = VaultScope.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Panoda içe aktarılabilir veri yok.')),
      );
      return;
    }

    if (!context.mounted) return;
    final mode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yedeği içe aktar'),
        content: const Text(
          'Birleştir mevcut kayıtları korur. Değiştir mevcut kasanın yerine yedeği yükler.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'merge'),
            child: const Text('Birleştir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'replace'),
            child: const Text('Değiştir'),
          ),
        ],
      ),
    );
    if (mode == null) return;

    try {
      await store.importVaultJson(raw, merge: mode == 'merge');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kasa verisi içe aktarıldı.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('İçe aktarma başarısız'),
          content: Text('$error'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  void _renameVault(BuildContext context) {
    final store = VaultScope.of(context);
    final controller =
        TextEditingController(text: store.vaultName);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kasa Adı'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              store.renameVault(controller.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}


class HybridArchivePage extends StatelessWidget {
  const HybridArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final archived = store.notes
        .where((note) => note.archived)
        .toList()
      ..sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arşivlenenler'),
      ),
      body: archived.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 52,
                      color: AppColors.muted,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Arşiv boş',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Arşivlediğin kayıtlar burada görünür.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                32,
              ),
              itemCount: archived.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final note = archived[index];

                return Material(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: _FantasyIcon(
                        note.type.iconAsset,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      note.title.trim().isEmpty
                          ? 'Başlıksız'
                          : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${note.type.label} • ${_formatDate(note.updatedAt)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'restore') {
                          await store.restore(note);
                        } else if (value == 'delete') {
                          if (!context.mounted) return;
                          final confirm =
                              await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) =>
                                AlertDialog(
                              title:
                                  const Text('Kalıcı silinsin mi?'),
                              content: const Text(
                                'Bu kayıt geri alınamayacak şekilde silinecek.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(
                                    dialogContext,
                                    false,
                                  ),
                                  child:
                                      const Text('İptal'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(
                                    dialogContext,
                                    true,
                                  ),
                                  child:
                                      const Text('Sil'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await store.deleteForever(note);
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'restore',
                          child: ListTile(
                            dense: true,
                            contentPadding:
                                EdgeInsets.zero,
                            leading: Icon(
                              Icons.unarchive_outlined,
                            ),
                            title: Text('Arşivden çıkar'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            contentPadding:
                                EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.red,
                            ),
                            title: Text(
                              'Kalıcı sil',
                              style: TextStyle(
                                color: AppColors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DashboardModuleSetting extends StatelessWidget {
  final String id;

  const _DashboardModuleSetting({
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    final config = HybridConfigScope.of(context);
    final label = _moduleLabel(id);

    return Row(
      children: [
        IconButton(
          tooltip: 'Yukarı',
          onPressed: () => config.moveModule(id, -1),
          icon: const Icon(
            Icons.keyboard_arrow_up_rounded,
          ),
        ),
        IconButton(
          tooltip: 'Aşağı',
          onPressed: () => config.moveModule(id, 1),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
          ),
        ),
        Expanded(
          child: Text(label),
        ),
        Switch(
          value: config.visible(id),
          onChanged: (value) =>
              config.setModuleVisible(id, value),
        ),
      ],
    );
  }

  static String _moduleLabel(String id) {
    switch (id) {
      case 'quick':
        return 'Hızlı Oluştur';
      case 'recent':
        return 'Son Düzenlenenler';
      case 'pinned':
        return 'Sabitlenenler';
      case 'tasks':
        return 'Açık Görevler';
      case 'links':
        return 'Bağlantı Sağlığı';
      case 'tags':
        return 'Etiketler';
      case 'bookmarks':
        return 'Yer İmleri';
      default:
        return id;
    }
  }
}

class _CustomizeCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CustomizeCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14,
      ),
      decoration: _hybridDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _FeatureStatus extends StatelessWidget {
  final String title;
  final String detail;

  const _FeatureStatus({
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.green,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HybridTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const _HybridTopBar({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding:
          const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _HybridSectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const _HybridSectionHeader({
    required this.title,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionText!),
          ),
      ],
    );
  }
}

BoxDecoration _hybridDecoration(BuildContext context) {
  return BoxDecoration(
    color: AppColors.panel,
    borderRadius: BorderRadius.circular(
      HybridConfigScope.of(context).cardRadius,
    ),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.05),
    ),
  );
}


// ============================================================================
// CODEX UI v0.9
// Tablet-first yeni tasarım. Mevcut veri motorunu, bağlantıları, alanları,
// arşivi, yedeklemeyi ve oluşturucuları korur.
// ============================================================================

Color _codexTypeColor(NoteType type) {
  switch (type) {
    case NoteType.npc:
      return const Color(0xFF8DB7E0);
    case NoteType.monster:
      return const Color(0xFFD37979);
    case NoteType.session:
      return const Color(0xFFD5AE67);
    case NoteType.location:
      return const Color(0xFF78B99A);
    case NoteType.quest:
      return const Color(0xFFBE96D8);
    case NoteType.item:
      return const Color(0xFFD7A56D);
    case NoteType.organization:
      return const Color(0xFF7FB8B8);
    case NoteType.lore:
      return const Color(0xFF9B9ED6);
    case NoteType.rule:
      return const Color(0xFF9DB4C2);
    case NoteType.journal:
      return const Color(0xFFA5B48A);
    case NoteType.handout:
      return const Color(0xFFD09B8D);
    case NoteType.template:
      return const Color(0xFFB1A1D2);
    case NoteType.note:
      return AppColors.purple;
  }
}

IconData _codexTypeIcon(NoteType type) {
  switch (type) {
    case NoteType.note:
      return Icons.description_outlined;
    case NoteType.npc:
      return Icons.person_outline_rounded;
    case NoteType.monster:
      return Icons.pest_control_rodent_outlined;
    case NoteType.session:
      return Icons.auto_stories_outlined;
    case NoteType.location:
      return Icons.map_outlined;
    case NoteType.quest:
      return Icons.flag_outlined;
    case NoteType.item:
      return Icons.inventory_2_outlined;
    case NoteType.organization:
      return Icons.account_tree_outlined;
    case NoteType.lore:
      return Icons.history_edu_outlined;
    case NoteType.rule:
      return Icons.gavel_outlined;
    case NoteType.journal:
      return Icons.menu_book_outlined;
    case NoteType.handout:
      return Icons.mail_outline_rounded;
    case NoteType.template:
      return Icons.dashboard_customize_outlined;
  }
}

class CodexShell extends StatefulWidget {
  const CodexShell({super.key});

  @override
  State<CodexShell> createState() => _CodexShellState();
}

class _CodexShellState extends State<CodexShell> {
  final HybridConfig config = HybridConfig();
  int index = 0;

  @override
  void initState() {
    super.initState();
    config.addListener(_onConfigChanged);
    _load();
  }

  void _onConfigChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    await config.load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    config.removeListener(_onConfigChanged);
    config.dispose();
    super.dispose();
  }

  void go(int value) {
    if (value < 0 || value > 5) return;
    setState(() => index = value);
  }

  bool _useTabletLayout(BuildContext context) {
    if (config.layoutMode == 'phone') return false;
    if (config.layoutMode == 'tablet') return true;

    // Otomatik mod her build'de güncel ekran profilini yeniden okur.
    // Böylece telefon/tablet, rotasyon ve yeniden boyutlandırma anında algılanır.
    return CodexDeviceProfile.of(context).isTablet;
  }

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    if (!config.loaded || !store.loaded) {
      return const Scaffold(
        body: _CodexLoading(),
      );
    }

    if (!store.hasExternalStorage) {
      return HybridConfigScope(
        config: config,
        child: const CodexStorageSetupPage(),
      );
    }

    return HybridConfigScope(
      config: config,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tablet = _useTabletLayout(context);

          if (tablet) {
            final tabletPages = [
              CodexTabletHomePage(
                onOpenVault: () => go(1),
                onOpenForge: () => go(2),
                onOpenAtlas: () => go(3),
                onOpenTools: () => go(4),
              ),
              config.tabletSplitVault &&
                      constraints.maxWidth >= 1024
                  ? CodexTabletVaultPage(
                      onOpenForge: () => go(2),
                    )
                  : CodexVaultPage(
                      onOpenForge: () => go(2),
                    ),
              CodexForgePage(
                onCreated: () => go(1),
              ),
              const CodexAtlasPage(),
              const CodexToolsPage(),
              const CodexSettingsPage(),
            ];

            final showShelf = config.tabletContextShelf &&
                constraints.maxWidth >= 1240;
            final expandTabletRail =
                config.tabletRailExpanded &&
                constraints.maxWidth >= 900;

            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: SafeArea(
                child: Row(
                  children: [
                    _CodexTabletProRail(
                      selected: index,
                      expanded: expandTabletRail,
                      onSelected: go,
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: index,
                        children: tabletPages,
                      ),
                    ),
                    if (showShelf)
                      SizedBox(
                        width: config.tabletShelfWidth,
                        child: _CodexTabletContextShelf(
                          section: index,
                          onOpenVault: () => go(1),
                          onOpenForge: () => go(2),
                          onOpenTools: () => go(4),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          final phonePages = [
            CodexPhoneHomePage(
              onOpenVault: () => go(1),
              onOpenForge: () => go(2),
              onOpenTools: () => go(4),
            ),
            CodexPhoneVaultPage(
              onOpenForge: () => go(2),
            ),
            CodexForgePage(
              onCreated: () => go(1),
            ),
            const CodexAtlasPage(),
            const CodexToolsPage(),
            const CodexSettingsPage(),
          ];

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: IndexedStack(
              index: index,
              children: phonePages,
            ),
            bottomNavigationBar: _CodexPhoneDock(
              selected: index,
              onSelected: go,
              onMore: () => _showCodexPhoneMoreSheet(
                context,
                go: go,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CodexLoading extends StatelessWidget {
  const _CodexLoading();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _CodexAtmosphere()),
        Center(
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CodexAtmosphere extends StatelessWidget {
  const _CodexAtmosphere();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CodexAtmospherePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _CodexAtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow1 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.purple.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .82, size.height * .12),
          radius: size.width * .55,
        ),
      );

    final glow2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.gold.withValues(alpha: 0.055),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .12, size.height * .82),
          radius: size.width * .52,
        ),
      );

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg);
    canvas.drawRect(Offset.zero & size, glow1);
    canvas.drawRect(Offset.zero & size, glow2);

    final linePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.22)
      ..strokeWidth = 1;

    const spacing = 54.0;
    for (double x = 18; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        linePaint,
      );
    }
    for (double y = 18; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CodexAtmospherePainter oldDelegate) => false;
}

class _CodexPageBackdrop extends StatelessWidget {
  final Widget child;

  const _CodexPageBackdrop({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: _CodexAnimatedAtmosphere(),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _CodexRail extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _CodexRail({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = [
      (Icons.space_dashboard_outlined, 'Merkez'),
      (Icons.folder_copy_outlined, 'Kasa'),
      (Icons.auto_awesome_outlined, 'Oluştur'),
      (Icons.travel_explore_outlined, 'Ağ'),
      (Icons.construction_outlined, 'Araçlar'),
      (Icons.tune_outlined, 'Ayar'),
    ];

    return Container(
      width: 104,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: .20),
                  AppColors.gold.withValues(alpha: .14),
                ],
              ),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: scheme.primary.withValues(alpha: .22),
              ),
            ),
            child: const _FantasyIcon(
              'book_open',
              size: 34,
            ),
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < items.length; i++)
            _CodexRailItem(
              selected: selected == i,
              icon: items[i].$1,
              label: items[i].$2,
              onTap: () => onSelected(i),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'CODEX',
              style: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: .62),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexRailItem extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CodexRailItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 3, 9, 3),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: .12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 67,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: selected ? 32 : 0,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        size: 23,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodexBottomDock extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _CodexBottomDock({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    const items = [
      (Icons.space_dashboard_outlined, 'Merkez'),
      (Icons.folder_copy_outlined, 'Kasa'),
      (Icons.auto_awesome_outlined, 'Oluştur'),
      (Icons.travel_explore_outlined, 'Ağ'),
      (Icons.construction_outlined, 'Araçlar'),
      (Icons.tune_outlined, 'Ayar'),
    ];

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(12, 7, 12, 8 + bottom),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .32),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelected(i),
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                          horizontal: selected == i ? 13 : 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selected == i
                              ? (i == 2
                                  ? AppColors.gold.withValues(alpha: .17)
                                  : scheme.primary.withValues(alpha: .13))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          items[i].$1,
                          size: i == 2 ? 24 : 21,
                          color: selected == i
                              ? (i == 2
                                  ? AppColors.gold
                                  : scheme.onSurface)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: selected == i
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: selected == i
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
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

class _CodexHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const _CodexHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;

        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: TextStyle(
                color: scheme.primary,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: narrow ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: narrow ? 22 : 27,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: narrow ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(
            narrow ? 16 : 22,
            narrow ? 14 : 20,
            narrow ? 16 : 22,
            12,
          ),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: heading),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      ...actions,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _CodexIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CodexIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }
}


class CodexStorageSetupPage extends StatefulWidget {
  const CodexStorageSetupPage({super.key});

  @override
  State<CodexStorageSetupPage> createState() =>
      _CodexStorageSetupPageState();
}

class _CodexStorageSetupPageState
    extends State<CodexStorageSetupPage> {
  bool working = false;

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _CodexPageBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _CodexPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.purple.withValues(alpha: .18),
                          ),
                        ),
                        child: const Icon(
                          Icons.folder_special_outlined,
                          size: 38,
                          color: AppColors.purple,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Kayıt Konumunu Seç',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Bir klasör seç. Uygulama o klasörün içinde otomatik olarak '
                        'dmpcsnotebook klasörü oluşturacak. Kasaların, yedeklerin ve '
                        'uygulama veri kopyalarının tamamı burada tutulacak.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.bg.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Column(
                          children: [
                            _StorageStructureLine(
                              icon: Icons.folder_outlined,
                              text: 'dmpcsnotebook/',
                            ),
                            _StorageStructureLine(
                              icon: Icons.data_object_rounded,
                              text: 'index.json + app_settings.json',
                            ),
                            _StorageStructureLine(
                              icon: Icons.inventory_2_outlined,
                              text: 'vaults/<kasa>/vault.json + backup.json',
                            ),
                          ],
                        ),
                      ),
                      if (store.storageError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          store.storageError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: working
                            ? null
                            : () async {
                                setState(() => working = true);
                                final ok =
                                    await store.chooseStorageLocation();
                                if (mounted) {
                                  setState(() => working = false);
                                  if (!ok) return;
                                }
                              },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: working
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.folder_open_rounded),
                        label: Text(
                          working
                              ? 'Hazırlanıyor…'
                              : 'Kayıt Konumu Seç',
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Mevcut yerel verilerin varsa ilk kasaya otomatik taşınır.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageStructureLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StorageStructureLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CodexHomePage extends StatelessWidget {
  final VoidCallback onOpenVault;
  final VoidCallback onOpenForge;
  final VoidCallback onOpenAtlas;

  const CodexHomePage({
    super.key,
    required this.onOpenVault,
    required this.onOpenForge,
    required this.onOpenAtlas,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final active = store.notes.where((n) => !n.archived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final tasks = active.fold<int>(
      0,
      (sum, note) => sum + store.tasksFor(note).where(
        (line) => line.trimLeft().startsWith('- [ ]'),
      ).length,
    );

    final links = active.fold<int>(
      0,
      (sum, note) => sum + store.extractLinks(note.content).length,
    );

    final unresolved = active.fold<int>(
      0,
      (sum, note) => sum + store.unresolvedLinks(note).length,
    );

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _CodexHeader(
              eyebrow: 'Tool Master',
              title: store.vaultName,
              subtitle:
                  'Kampanya bilgilerini tek kasada kur, birbirine bağla ve masada hızlıca kullan.',
              actions: [
                _CodexIconButton(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Kasa değiştir',
                  onTap: () => _showCodexVaultSwitcher(context),
                ),
                const SizedBox(width: 7),
                _CodexIconButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Ara',
                  onTap: () => _codexSearch(context),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1080;
                  final content = ListView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 42),
                    children: [
                      _CodexHeroPanel(
                        noteCount: active.length,
                        linkCount: links,
                        taskCount: tasks,
                        archiveCount:
                            store.notes.where((n) => n.archived).length,
                        onOpenVault: onOpenVault,
                        onOpenForge: onOpenForge,
                      ),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                children: [
                                  _CodexRecentPanel(
                                    notes: active.take(5).toList(),
                                    onOpenVault: onOpenVault,
                                  ),
                                  const SizedBox(height: 16),
                                  _CodexForgeStrip(
                                    onOpenForge: onOpenForge,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _CodexPulsePanel(
                                    orphanCount: store.orphanCount,
                                    unresolved: unresolved,
                                    tasks: tasks,
                                    onOpenAtlas: onOpenAtlas,
                                  ),
                                  const SizedBox(height: 16),
                                  const _CodexTagPanel(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _CodexForgeStrip(onOpenForge: onOpenForge),
                        const SizedBox(height: 16),
                        _CodexRecentPanel(
                          notes: active.take(5).toList(),
                          onOpenVault: onOpenVault,
                        ),
                        const SizedBox(height: 16),
                        _CodexPulsePanel(
                          orphanCount: store.orphanCount,
                          unresolved: unresolved,
                          tasks: tasks,
                          onOpenAtlas: onOpenAtlas,
                        ),
                        const SizedBox(height: 16),
                        const _CodexTagPanel(),
                      ],
                    ],
                  );
                  return content;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodexHeroPanel extends StatelessWidget {
  final int noteCount;
  final int linkCount;
  final int taskCount;
  final int archiveCount;
  final VoidCallback onOpenVault;
  final VoidCallback onOpenForge;

  const _CodexHeroPanel({
    required this.noteCount,
    required this.linkCount,
    required this.taskCount,
    required this.archiveCount,
    required this.onOpenVault,
    required this.onOpenForge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF172128),
            AppColors.panel,
            const Color(0xFF121619),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: .18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;

          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const _FantasyIcon('book_open', size: 34),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KASA NABZI',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Dünyan büyüdükçe burası kendiliğinden anlam kazanır.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CodexMetric(value: '$noteCount', label: 'Kayıt'),
                  _CodexMetric(value: '$linkCount', label: 'Bağlantı'),
                  _CodexMetric(value: '$taskCount', label: 'Açık görev'),
                  _CodexMetric(value: '$archiveCount', label: 'Arşiv'),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onOpenForge,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF1C160C),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Yeni Kayıt'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenVault,
                icon: const Icon(Icons.folder_copy_outlined),
                label: const Text('Kasayı Aç'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                main,
                const SizedBox(height: 18),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: main),
              const SizedBox(width: 18),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _CodexMetric extends StatelessWidget {
  final String value;
  final String label;

  const _CodexMetric({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: .045),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _CodexPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appearance = CodexAppearanceScope.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(
          alpha: appearance.surfaceStyle == 'flat' ? 1 : .96,
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: scheme.outlineVariant,
        ),
        boxShadow: appearance.surfaceStyle == 'soft'
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .12
                        : .06,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ]
            : const [],
      ),
      child: child,
    );
  }
}

class _CodexPanelTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _CodexPanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );

    Widget iconBox() => Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 19,
            color: scheme.primary,
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 320;

        if (narrow && trailing != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  iconBox(),
                  const SizedBox(width: 10),
                  Expanded(child: textBlock),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
            ],
          );
        }

        return Row(
          children: [
            iconBox(),
            const SizedBox(width: 10),
            Expanded(child: textBlock),
            if (trailing != null) ...[
              const SizedBox(width: 5),
              Flexible(
                flex: 0,
                child: trailing!,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CodexRecentPanel extends StatelessWidget {
  final List<NoteRecord> notes;
  final VoidCallback onOpenVault;

  const _CodexRecentPanel({
    required this.notes,
    required this.onOpenVault,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return _CodexPanel(
      child: Column(
        children: [
          _CodexPanelTitle(
            icon: Icons.history_rounded,
            title: 'Son Çalıştıkların',
            subtitle: notes.isEmpty
                ? 'Henüz kayıt oluşturmadın.'
                : 'Son düzenlenen kayıtların.',
            trailing: TextButton(
              onPressed: onOpenVault,
              child: const Text('Tümü'),
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final note in notes) ...[
              _CodexRecentRow(
                note: note,
                onTap: () => _openCodexRecord(context, note),
              ),
              if (note.id != notes.last.id)
                const Divider(height: 1),
            ],
          ] else ...[
            const SizedBox(height: 18),
            const _CodexEmptyLine(
              icon: Icons.edit_note_outlined,
              text: 'Oluştur bölümünden ilk kaydını başlat.',
            ),
          ],
        ],
      ),
    );
  }
}

class _CodexRecentRow extends StatelessWidget {
  final NoteRecord note;
  final VoidCallback onTap;

  const _CodexRecentRow({
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final color = _codexTypeColor(note.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _codexTypeIcon(note.type),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${note.type.label} • ${store.extractLinks(note.content).length} bağlantı',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (note.pinned)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 15,
                    color: AppColors.gold,
                  ),
                ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodexForgeStrip extends StatelessWidget {
  final VoidCallback onOpenForge;

  const _CodexForgeStrip({
    required this.onOpenForge,
  });

  @override
  Widget build(BuildContext context) {
    const types = [
      NoteType.npc,
      NoteType.monster,
      NoteType.session,
      NoteType.location,
      NoteType.quest,
      NoteType.item,
    ];

    return _CodexPanel(
      child: Column(
        children: [
          _CodexPanelTitle(
            icon: Icons.auto_awesome_outlined,
            title: 'Hızlı Üretim',
            subtitle: 'En sık kullanılan kayıt türleri.',
            trailing: TextButton(
              onPressed: onOpenForge,
              child: const Text('Tümü'),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final type in types)
                  _CodexMiniType(
                    type: type,
                    onTap: () => _openCodexCreator(context, type),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexMiniType extends StatelessWidget {
  final NoteType type;
  final VoidCallback onTap;

  const _CodexMiniType({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _codexTypeColor(type);
    return Container(
      width: 116,
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: color.withValues(alpha: .065),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: color.withValues(alpha: .16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _codexTypeIcon(type),
                  color: color,
                  size: 22,
                ),
                const Spacer(),
                Text(
                  type.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodexPulsePanel extends StatelessWidget {
  final int orphanCount;
  final int unresolved;
  final int tasks;
  final VoidCallback onOpenAtlas;

  const _CodexPulsePanel({
    required this.orphanCount,
    required this.unresolved,
    required this.tasks,
    required this.onOpenAtlas,
  });

  @override
  Widget build(BuildContext context) {
    return _CodexPanel(
      child: Column(
        children: [
          _CodexPanelTitle(
            icon: Icons.monitor_heart_outlined,
            title: 'Kasa Sağlığı',
            subtitle: 'Düzen ve bağlantı göstergeleri.',
            trailing: IconButton(
              onPressed: onOpenAtlas,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
          const SizedBox(height: 13),
          _CodexPulseLine(
            icon: Icons.link_off_rounded,
            label: 'Bağlantısız',
            value: '$orphanCount',
            color: orphanCount == 0 ? AppColors.green : AppColors.gold,
          ),
          const SizedBox(height: 8),
          _CodexPulseLine(
            icon: Icons.add_link_rounded,
            label: 'Eksik hedef',
            value: '$unresolved',
            color: unresolved == 0 ? AppColors.green : AppColors.red,
          ),
          const SizedBox(height: 8),
          _CodexPulseLine(
            icon: Icons.check_box_outlined,
            label: 'Açık görev',
            value: '$tasks',
            color: AppColors.blue,
          ),
        ],
      ),
    );
  }
}

class _CodexPulseLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _CodexPulseLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: .36),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexTagPanel extends StatelessWidget {
  const _CodexTagPanel();

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.tag_rounded,
            title: 'Etiket Bulutu',
            subtitle: 'Kasanın doğal kategorileri.',
          ),
          const SizedBox(height: 12),
          if (store.allTags.isEmpty)
            const _CodexEmptyLine(
              icon: Icons.tag_outlined,
              text: 'Henüz etiket yok.',
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in store.allTags.take(12))
                  Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CodexEmptyLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CodexEmptyLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: .30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CodexVaultPage extends StatefulWidget {
  final VoidCallback onOpenForge;

  const CodexVaultPage({
    super.key,
    required this.onOpenForge,
  });

  @override
  State<CodexVaultPage> createState() => _CodexVaultPageState();
}

class _CodexVaultPageState extends State<CodexVaultPage> {
  String query = '';
  NoteType? type;
  bool grid = false;
  String quickFilter = 'all';
  String sortMode = 'updated_desc';
  String? tagFilter;
  String? folderFilter;

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);

    var notes = store.notes.where((n) => !n.archived).toList();

    if (type != null) {
      notes = notes.where((n) => n.type == type).toList();
    }

    if (tagFilter != null) {
      notes = notes.where((n) {
        final tags = <String>{
          ...store.extractTags(n.content),
          ...(n.properties['tags'] ?? '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .map((e) => e.startsWith('#') ? e : '#$e'),
        };
        return tags.contains(tagFilter);
      }).toList();
    }

    if (folderFilter != null) {
      notes = notes.where((n) {
        final folder = (n.properties['folder'] ?? '/').trim();
        final normalized = folder.startsWith('/') ? folder : '/$folder';
        return normalized == folderFilter;
      }).toList();
    }

    switch (quickFilter) {
      case 'pinned':
        notes = notes.where((n) => n.pinned).toList();
        break;
      case 'bookmarked':
        notes = notes.where((n) => n.bookmarked).toList();
        break;
      case 'tasks':
        notes = notes.where((n) => store.tasksFor(n).any(
          (line) => line.trimLeft().toLowerCase().startsWith('- [ ]'),
        )).toList();
        break;
      case 'broken':
        notes = notes.where((n) => store.unresolvedLinks(n).isNotEmpty).toList();
        break;
      case 'orphans':
        notes = notes.where((n) {
          return store.backlinksFor(n).isEmpty &&
              store.outgoingResolved(n).isEmpty;
        }).toList();
        break;
    }

    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isNotEmpty) {
      notes = notes.where((n) {
        final tags = store.extractTags(n.content).join(' ');
        final props = n.properties.entries
            .map((e) => '${e.key} ${e.value}')
            .join(' ');
        return '${n.title} ${n.content} $tags $props'
            .toLowerCase()
            .contains(cleanQuery);
      }).toList();
    }

    switch (sortMode) {
      case 'updated_asc':
        notes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case 'created_desc':
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'title':
        notes.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'type':
        notes.sort((a, b) {
          final byType = a.type.label.compareTo(b.type.label);
          if (byType != 0) return byType;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      default:
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _CodexHeader(
              eyebrow: 'KASA',
              title: 'Arşivin',
              subtitle:
                  'Notları tür, bağlantı ve içerik üzerinden bul. Burada yalnızca aktif kayıtlar görünür.',
              actions: [
                _CodexIconButton(
                  icon: grid ? Icons.view_agenda_outlined : Icons.grid_view_outlined,
                  tooltip: grid ? 'Liste görünümü' : 'Kart görünümü',
                  onTap: () => setState(() => grid = !grid),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  hintText: 'Başlık, etiket, alan veya içerik ara...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 9),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CodexFilterMenu(
                    icon: Icons.sort_rounded,
                    label: _codexSortLabel(sortMode),
                    items: const {
                      'updated_desc': 'Son düzenlenen',
                      'updated_asc': 'En eski düzenlenen',
                      'created_desc': 'Yeni oluşturulan',
                      'title': 'Başlığa göre',
                      'type': 'Türe göre',
                    },
                    onSelected: (value) =>
                        setState(() => sortMode = value),
                  ),
                  _CodexNullableFilterMenu(
                    icon: Icons.tag_rounded,
                    label: tagFilter ?? 'Etiket',
                    values: store.allTags,
                    onSelected: (value) =>
                        setState(() => tagFilter = value),
                  ),
                  _CodexNullableFilterMenu(
                    icon: Icons.folder_outlined,
                    label: folderFilter ?? 'Klasör',
                    values: store.allFolders,
                    onSelected: (value) =>
                        setState(() => folderFilter = value),
                  ),
                  if (tagFilter != null ||
                      folderFilter != null ||
                      quickFilter != 'all' ||
                      type != null)
                    ActionChip(
                      avatar: const Icon(Icons.filter_alt_off_rounded, size: 16),
                      label: const Text('Filtreleri temizle'),
                      onPressed: () {
                        setState(() {
                          type = null;
                          tagFilter = null;
                          folderFilter = null;
                          quickFilter = 'all';
                        });
                      },
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 43,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in const [
                    ('all', Icons.all_inbox_outlined, 'Tümü'),
                    ('pinned', Icons.push_pin_outlined, 'Sabit'),
                    ('bookmarked', Icons.bookmark_border_rounded, 'Yer İmi'),
                    ('tasks', Icons.check_box_outlined, 'Açık Görev'),
                    ('broken', Icons.link_off_rounded, 'Eksik Bağlantı'),
                    ('orphans', Icons.bubble_chart_outlined, 'Bağlantısız'),
                  ]) ...[
                    ChoiceChip(
                      avatar: Icon(filter.$2, size: 15),
                      label: Text(filter.$3),
                      selected: quickFilter == filter.$1,
                      onSelected: (_) =>
                          setState(() => quickFilter = filter.$1),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 47,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('Tümü'),
                    selected: type == null,
                    onSelected: (_) => setState(() => type = null),
                  ),
                  const SizedBox(width: 6),
                  for (final item in NoteType.values) ...[
                    ChoiceChip(
                      avatar: Icon(
                        _codexTypeIcon(item),
                        size: 15,
                        color: type == item
                            ? _codexTypeColor(item)
                            : AppColors.muted,
                      ),
                      label: Text(item.label),
                      selected: type == item,
                      onSelected: (_) => setState(() => type = item),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: notes.isEmpty
                  ? _CodexVaultEmpty(
                      hasFilter: query.isNotEmpty || type != null,
                      onCreate: widget.onOpenForge,
                    )
                  : grid
                      ? _CodexVaultGrid(notes: notes)
                      : _CodexVaultList(notes: notes),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodexVaultEmpty extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onCreate;

  const _CodexVaultEmpty({
    required this.hasFilter,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _CodexPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasFilter
                      ? Icons.manage_search_rounded
                      : Icons.folder_open_rounded,
                  size: 46,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 14),
                Text(
                  hasFilter ? 'Eşleşen kayıt yok' : 'Kasa henüz boş',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasFilter
                      ? 'Aramayı veya tür filtresini değiştir.'
                      : 'İlk kaydını oluşturduğunda burada görünmeye başlayacak.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
                if (!hasFilter) ...[
                  const SizedBox(height: 15),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Oluştur'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodexVaultList extends StatelessWidget {
  final List<NoteRecord> notes;

  const _CodexVaultList({
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 42),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _CodexVaultTile(note: notes[index]);
      },
    );
  }
}

class _CodexVaultTile extends StatelessWidget {
  final NoteRecord note;

  const _CodexVaultTile({
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = _codexTypeColor(note.type);
    final tags = store.extractTags(note.content);

    return Material(
      color: scheme.surfaceContainer.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: () => _openCodexRecord(context, note),
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _codexTypeIcon(note.type),
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (note.pinned) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: AppColors.gold,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 7,
                      runSpacing: 3,
                      children: [
                        Text(
                          note.type.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${store.extractLinks(note.content).length} bağlantı',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        if (tags.isNotEmpty)
                          Text(
                            tags.take(2).join(' '),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _NoteOverflowMenu(note: note),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodexVaultGrid extends StatelessWidget {
  final List<NoteRecord> notes;

  const _CodexVaultGrid({
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 42),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 330,
        mainAxisExtent: 172,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final color = _codexTypeColor(note.type);
        final store = VaultScope.of(context);

        return Material(
          color: scheme.surfaceContainer.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(21),
          child: InkWell(
            onTap: () => _openCodexRecord(context, note),
            borderRadius: BorderRadius.circular(21),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 39,
                        height: 39,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _codexTypeIcon(note.type),
                          color: color,
                          size: 19,
                        ),
                      ),
                      const Spacer(),
                      _NoteOverflowMenu(note: note),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${note.type.label} • ${store.extractLinks(note.content).length} bağlantı',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CodexForgePage extends StatelessWidget {
  final VoidCallback onCreated;

  const CodexForgePage({
    super.key,
    required this.onCreated,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <(String, String, List<NoteType>)>[
      (
        'Karakter & Varlık',
        'Masaya gelecek kişiler ve yaratıklar.',
        [NoteType.npc, NoteType.monster]
      ),
      (
        'Dünya',
        'Mekânları, örgütleri, eşyaları ve dünya bilgisini kur.',
        [NoteType.location, NoteType.organization, NoteType.item, NoteType.lore]
      ),
      (
        'Oyun Akışı',
        'Oturum, görev, günlük ve oyuncu materyallerini hazırla.',
        [NoteType.session, NoteType.quest, NoteType.journal, NoteType.handout]
      ),
      (
        'Sistem',
        'Serbest not, kural ve tekrar kullanılabilir şablonlar.',
        [NoteType.note, NoteType.rule, NoteType.template]
      ),
    ];

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            const _CodexHeader(
              eyebrow: 'OLUŞTUR',
              title: 'Kayıt Atölyesi',
              subtitle:
                  'Önce kayıt türünü seç. Hazır hikâye içeriği yok; yalnızca sana güçlü bir yapı verir.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 42),
                children: [
                  for (final group in groups) ...[
                    _CodexForgeGroup(
                      title: group.$1,
                      subtitle: group.$2,
                      types: group.$3,
                      onCreated: onCreated,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodexForgeGroup extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<NoteType> types;
  final VoidCallback onCreated;

  const _CodexForgeGroup({
    required this.title,
    required this.subtitle,
    required this.types,
    required this.onCreated,
  });

  @override
  Widget build(BuildContext context) {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 900
                  ? 4
                  : width >= 560
                      ? 2
                      : 1;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                childAspectRatio: columns == 1 ? 3.3 : 1.65,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final type in types)
                    _CodexForgeCard(
                      type: type,
                      onTap: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => StructuredCreatorPage(type: type),
                          ),
                        );
                        if (result == true) onCreated();
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CodexForgeCard extends StatelessWidget {
  final NoteType type;
  final VoidCallback onTap;

  const _CodexForgeCard({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _codexTypeColor(type);

    return Material(
      color: color.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: .16),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _codexTypeIcon(type),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _codexForgeDescription(type),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _codexForgeDescription(NoteType type) {
  switch (type) {
    case NoteType.npc:
      return 'Kimlik, rolplay, motivasyon, ilişki ve sır katmanları.';
    case NoteType.monster:
      return 'Statlar, saldırılar, taktik ve encounter bilgileri.';
    case NoteType.session:
      return 'Hazırlık, sahneler, kararlar ve masa günlüğü.';
    case NoteType.location:
      return 'Atmosfer, önemli kişiler, sırlar ve alt bölgeler.';
    case NoteType.quest:
      return 'Hedef, ilerleme, sonuç ve ödül takibi.';
    case NoteType.item:
      return 'Nadirlik, mekanik, sahibi ve gizli özellikler.';
    case NoteType.organization:
      return 'Amaç, üyeler, ilişkiler ve güç yapısı.';
    case NoteType.lore:
      return 'Tarih, söylenti, gerçek ve dünya bilgisi.';
    case NoteType.rule:
      return 'Kural, kaynak ve masa uygulama notları.';
    case NoteType.journal:
      return 'Kronoloji, kararlar ve kişisel takip.';
    case NoteType.handout:
      return 'Oyuncuya gösterilecek içerik ve görünürlük.';
    case NoteType.template:
      return 'Kendi tekrar kullanılabilir kayıt yapını kur.';
    case NoteType.note:
      return 'Tamamen serbest, bağlantılı not.';
  }
}

class CodexAtlasPage extends StatefulWidget {
  const CodexAtlasPage({super.key});

  @override
  State<CodexAtlasPage> createState() => _CodexAtlasPageState();
}

class _CodexAtlasPageState extends State<CodexAtlasPage> {
  int mode = 0;

  @override
  Widget build(BuildContext context) {
    const labels = [
      (Icons.hub_outlined, 'Ağ'),
      (Icons.table_chart_outlined, 'Tablo'),
      (Icons.dashboard_outlined, 'Pano'),
    ];

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            const _CodexHeader(
              eyebrow: 'AĞ',
              title: 'Bağlantı Alanı',
              subtitle:
                  'Aynı kayıtları üç farklı şekilde incele: ilişkiler, yapılandırılmış tablo ve serbest pano.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => mode = i),
                          borderRadius: BorderRadius.circular(13),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 170),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: mode == i
                                  ? AppColors.purple.withValues(alpha: .12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  labels[i].$1,
                                  size: 18,
                                  color: mode == i
                                      ? AppColors.purple
                                      : AppColors.muted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  labels[i].$2,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: mode == i
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.panel.withValues(alpha: .87),
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: IndexedStack(
                      index: mode,
                      children: const [
                        _GraphView(),
                        _BasesPage(),
                        _CanvasPage(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CodexSettingsPage extends StatelessWidget {
  const CodexSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final config = HybridConfigScope.of(context);

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            const _CodexHeader(
              eyebrow: 'AYARLAR',
              title: 'Çalışma Alanı',
              subtitle:
                  'Görünümü, kasayı ve güvenli yedeklerini tek yerden yönet.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 42),
                children: [
                  _CodexSettingsSection(
                    title: 'Depolama & Kasalar',
                    children: [
                      _CodexSettingsTile(
                        icon: Icons.folder_special_outlined,
                        title: 'Kayıt konumu',
                        subtitle: store.storageLabel,
                        onTap: () => _changeCodexStorageLocation(context),
                      ),
                      _CodexSettingsTile(
                        icon: Icons.swap_horiz_rounded,
                        title: 'Kasa değiştir',
                        subtitle:
                            '${store.vaultCatalog.length} kasa • Aktif: ${store.vaultName}',
                        onTap: () => _showCodexVaultSwitcher(context),
                      ),
                      _CodexSettingsTile(
                        icon: Icons.create_new_folder_outlined,
                        title: 'Yeni kasa oluştur',
                        subtitle: 'Aynı dmpcsnotebook klasörü içinde ayrı bir kasa başlat.',
                        onTap: () => _createCodexVaultDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CodexSettingsSection(
                    title: 'Kasa',
                    children: [
                      _CodexSettingsTile(
                        icon: Icons.drive_file_rename_outline,
                        title: 'Kasa adı',
                        subtitle: store.vaultName,
                        onTap: () => _codexRenameVault(context),
                      ),
                      _CodexSettingsTile(
                        icon: Icons.archive_outlined,
                        title: 'Arşivlenenler',
                        subtitle:
                            '${store.notes.where((n) => n.archived).length} kayıt',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HybridArchivePage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CodexSettingsSection(
                    title: 'Görünüm',
                    children: [
                      Builder(
                        builder: (context) {
                          final detected =
                              CodexDeviceProfile.of(context);
                          final autoActive =
                              config.layoutMode == 'auto';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.purple
                                  .withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.purple
                                    .withValues(alpha: .18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.purple
                                        .withValues(alpha: .10),
                                    borderRadius:
                                        BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    detected.isTablet
                                        ? Icons.tablet_android_rounded
                                        : Icons.smartphone_rounded,
                                    color: AppColors.purple,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Algılanan cihaz: ${detected.label}',
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        detected.detail,
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                      if (!autoActive)
                                        const Padding(
                                          padding:
                                              EdgeInsets.only(top: 3),
                                          child: Text(
                                            'Not: Manuel görünüm zorlaması aktif.',
                                            style: TextStyle(
                                              color: AppColors.gold,
                                              fontSize: 9,
                                              fontWeight:
                                                  FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (autoActive)
                                  const Chip(
                                    visualDensity:
                                        VisualDensity.compact,
                                    label: Text('OTOMATİK'),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.devices_rounded,
                          color: AppColors.purple,
                        ),
                        title: const Text(
                          'Ekran düzeni',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Otomatik seçim cihazın kısa kenarına göre telefon/tablet düzenini kullanır.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      _CodexResponsiveOptionSelector(
                        value: config.layoutMode,
                        options: const [
                          ('auto', Icons.auto_awesome_rounded, 'Otomatik'),
                          ('phone', Icons.smartphone_rounded, 'Telefon'),
                          ('tablet', Icons.tablet_android_rounded, 'Tablet'),
                        ],
                        onChanged: config.setLayoutMode,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: config.compactCards,
                        title: const Text('Kompakt alanlar'),
                        subtitle:
                            const Text('Kartları ve boşlukları biraz daha sıkı kullan.'),
                        onChanged: config.setCompact,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: config.showHeroStats,
                        title: const Text('Ana ekran göstergeleri'),
                        subtitle:
                            const Text('Kayıt, bağlantı ve görev sayılarını göster.'),
                        onChanged: config.setHeroStats,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CodexAppearanceSettingsSection(),
                  const SizedBox(height: 12),
                  _CodexSettingsSection(
                    title: 'Tablet Çalışma Alanı',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: config.tabletRailExpanded,
                        title: const Text('Geniş sol menü'),
                        subtitle: const Text(
                          'Tablet navigasyonunda ikonların yanında bölüm adlarını ve kasa bilgisini göster.',
                        ),
                        onChanged: config.setTabletRailExpanded,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: config.tabletContextShelf,
                        title: const Text('Sağ bağlam rafı'),
                        subtitle: const Text(
                          'Yeterli genişlikte görev, son kayıt, bağlantı ve hızlı işlem rafını göster.',
                        ),
                        onChanged: config.setTabletContextShelf,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: config.tabletSplitVault,
                        title: const Text('Kasa iki panelli'),
                        subtitle: const Text(
                          'Solda kayıt listesi, sağda seçili kaydın canlı önizlemesi ve bağlam bilgileri.',
                        ),
                        onChanged: config.setTabletSplitVault,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: config.tabletRecordInspector,
                        title: const Text('Editörde bilgi denetçisi'),
                        subtitle: const Text(
                          'Kayıt editörünün sağında bağlantılar, görevler, etiketler ve metadata panelini tut.',
                        ),
                        onChanged: config.setTabletRecordInspector,
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tablet yoğunluğu',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      _CodexResponsiveOptionSelector(
                        value: config.tabletDensity,
                        options: const [
                          ('compact', Icons.compress_rounded, 'Kompakt'),
                          ('balanced', Icons.view_quilt_outlined, 'Dengeli'),
                          ('spacious', Icons.open_in_full_rounded, 'Ferah'),
                        ],
                        onChanged: config.setTabletDensity,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Sağ raf genişliği',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${config.tabletShelfWidth.round()} px',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        min: 250,
                        max: 380,
                        divisions: 13,
                        value: config.tabletShelfWidth
                            .clamp(250.0, 380.0)
                            .toDouble(),
                        onChanged: config.setTabletShelfWidth,
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.purple.withValues(alpha: .18),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.tablet_android_rounded,
                              color: AppColors.purple,
                              size: 19,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Dikey tablette ana çalışma alanı korunur; sağ bağlam rafı yalnızca yeterli genişlik varsa açılır. Yatay kullanımda üç bölgeli düzen tam kapasite çalışır.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CodexSettingsSection(
                    title: 'Veri Güvenliği',
                    children: [
                      _CodexSettingsTile(
                        icon: Icons.data_object_rounded,
                        title: 'JSON Veri Merkezi',
                        subtitle:
                            'Bir .json dosyası seç, önizle, alanları eşleştir ve kasaya aktar.',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CodexJsonImportPage(),
                            ),
                          );
                        },
                      ),
                      _CodexSettingsTile(
                        icon: Icons.copy_all_outlined,
                        title: 'Yedeği panoya kopyala',
                        subtitle: 'Tüm kasa verisini JSON olarak dışarı çıkar.',
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: store.exportVaultJson()),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kasa yedeği panoya kopyalandı.'),
                            ),
                          );
                        },
                      ),
                      _CodexSettingsTile(
                        icon: Icons.restore_page_outlined,
                        title: 'Panodan içe aktar',
                        subtitle: 'Yedeği birleştir veya mevcut kasayı değiştir.',
                        onTap: () => _codexImport(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CodexSettingsSection(
                    title: 'Durum',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          store.storageError == null
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: store.storageError == null
                              ? AppColors.green
                              : AppColors.red,
                        ),
                        title: const Text('Yerel kayıt'),
                        subtitle: Text(
                          store.storageError ??
                              (store.saving
                                  ? 'Kaydediliyor…'
                                  : '${store.notes.length} kayıt güvende.'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodexSettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CodexSettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _CodexSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CodexSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 41,
        height: 41,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 19,
          color: scheme.primary,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 10.5,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}


class CodexJsonImportPage extends StatefulWidget {
  const CodexJsonImportPage({super.key});

  @override
  State<CodexJsonImportPage> createState() =>
      _CodexJsonImportPageState();
}

class _CodexJsonImportPageState
    extends State<CodexJsonImportPage> {
  dynamic decoded;
  String fileName = '';
  String rawText = '';
  String? error;

  String? titleKey;
  String? contentKey;
  String? typeKey;
  String? tagsKey;
  String? folderKey;

  bool merge = true;
  bool importing = false;

  List<Map<String, dynamic>> get rows {
    if (decoded is List) {
      return (decoded as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded as Map);

      for (final key in const [
        'notes',
        'items',
        'records',
        'data',
        'entries',
        'results',
      ]) {
        final value = map[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      return [map];
    }

    return const [];
  }

  List<String> get keys {
    final found = <String>{};
    for (final row in rows.take(25)) {
      found.addAll(row.keys);
    }
    final result = found.toList()..sort();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('JSON Veri Merkezi'),
      ),
      body: _CodexPageBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
          children: [
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.file_open_outlined,
                    title: 'Kaynak JSON',
                    subtitle:
                        'Cihazdan bir .json seç veya panodaki JSON metnini kullan.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _pickJsonFile,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('JSON Dosyası Seç'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _readClipboard,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Panodan Oku'),
                      ),
                      if (decoded != null)
                        TextButton.icon(
                          onPressed: _clear,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Temizle'),
                        ),
                    ],
                  ),
                  if (fileName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: AppColors.purple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: AppColors.red.withValues(alpha: .24),
                        ),
                      ),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (decoded != null) ...[
              const SizedBox(height: 14),
              _CodexPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CodexPanelTitle(
                      icon: Icons.visibility_outlined,
                      title: 'Önizleme',
                      subtitle:
                          '${rows.length} kayıt • ${keys.length} farklı alan bulundu.',
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      const _CodexEmptyLine(
                        icon: Icons.warning_amber_rounded,
                        text:
                            'JSON bulundu ama aktarılabilir nesne listesi görünmüyor.',
                      )
                    else
                      SizedBox(
                        height: 230,
                        child: ListView.separated(
                          itemCount: math.min(rows.length, 5),
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kayıt ${index + 1}',
                                    style: const TextStyle(
                                      color: AppColors.purple,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    const JsonEncoder.withIndent('  ')
                                        .convert(row),
                                    maxLines: 7,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CodexPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CodexPanelTitle(
                      icon: Icons.account_tree_outlined,
                      title: 'Alan Eşleştirme',
                      subtitle:
                          'Boş bırakırsan uygulama yaygın JSON alan adlarını otomatik tahmin eder.',
                    ),
                    const SizedBox(height: 13),
                    _JsonKeyPicker(
                      label: 'Başlık',
                      value: titleKey,
                      keys: keys,
                      onChanged: (value) =>
                          setState(() => titleKey = value),
                    ),
                    const SizedBox(height: 9),
                    _JsonKeyPicker(
                      label: 'Ana İçerik',
                      value: contentKey,
                      keys: keys,
                      onChanged: (value) =>
                          setState(() => contentKey = value),
                    ),
                    const SizedBox(height: 9),
                    _JsonKeyPicker(
                      label: 'Kayıt Türü',
                      value: typeKey,
                      keys: keys,
                      onChanged: (value) =>
                          setState(() => typeKey = value),
                    ),
                    const SizedBox(height: 9),
                    _JsonKeyPicker(
                      label: 'Etiketler',
                      value: tagsKey,
                      keys: keys,
                      onChanged: (value) =>
                          setState(() => tagsKey = value),
                    ),
                    const SizedBox(height: 9),
                    _JsonKeyPicker(
                      label: 'Klasör',
                      value: folderKey,
                      keys: keys,
                      onChanged: (value) =>
                          setState(() => folderKey = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CodexPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CodexPanelTitle(
                      icon: Icons.download_done_rounded,
                      title: 'Aktarım',
                      subtitle:
                          'Eşleştirmediğin JSON alanları otomatik olarak özel alanlara çevrilir.',
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.merge_type_rounded),
                          label: Text('Birleştir'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.find_replace_rounded),
                          label: Text('Değiştir'),
                        ),
                      ],
                      selected: {merge},
                      onSelectionChanged: (values) {
                        setState(() => merge = values.first);
                      },
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed:
                          rows.isEmpty || importing ? null : _import,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: importing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        importing
                            ? 'Aktarılıyor…'
                            : '${rows.length} Kaydı Kasaya Aktar',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickJsonFile() async {
    setState(() => error = null);

    try {
      const jsonType = XTypeGroup(
        label: 'JSON',
        extensions: <String>['json'],
        mimeTypes: <String>['application/json', 'text/json'],
      );

      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[jsonType],
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw const FormatException(
          'Dosya içeriği boş veya okunamadı.',
        );
      }

      final raw = utf8.decode(bytes);
      final parsed = jsonDecode(raw);

      setState(() {
        decoded = parsed;
        rawText = raw;
        fileName = file.name;
        error = null;
        _resetMapping();
      });
    } catch (e) {
      setState(() {
        error = 'JSON dosyası okunamadı: $e';
      });
    }
  }

  Future<void> _readClipboard() async {
    setState(() => error = null);

    try {
      final data =
          await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text?.trim() ?? '';

      if (raw.isEmpty) {
        throw const FormatException(
          'Panoda JSON metni yok.',
        );
      }

      final parsed = jsonDecode(raw);

      setState(() {
        decoded = parsed;
        rawText = raw;
        fileName = 'Pano JSON';
        error = null;
        _resetMapping();
      });
    } catch (e) {
      setState(() {
        error = 'Panodaki JSON okunamadı: $e';
      });
    }
  }

  void _clear() {
    setState(() {
      decoded = null;
      rawText = '';
      fileName = '';
      error = null;
      _resetMapping();
    });
  }

  void _resetMapping() {
    titleKey = null;
    contentKey = null;
    typeKey = null;
    tagsKey = null;
    folderKey = null;
  }

  Future<void> _import() async {
    final store = VaultScope.of(context);

    setState(() {
      importing = true;
      error = null;
    });

    try {
      final result = await store.importGenericJson(
        decoded,
        merge: merge,
        titleKey: titleKey,
        contentKey: contentKey,
        typeKey: typeKey,
        tagsKey: tagsKey,
        folderKey: folderKey,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('JSON Aktarıldı'),
          content: Text(
            '${result.imported} kayıt kasaya eklendi.'
            '${result.skipped > 0 ? '\n${result.skipped} satır atlandı.' : ''}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Aktarım başarısız: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => importing = false);
      }
    }
  }
}

class _JsonKeyPicker extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> keys;
  final ValueChanged<String?> onChanged;

  const _JsonKeyPicker({
    required this.label,
    required this.value,
    required this.keys,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Otomatik algıla'),
        ),
        for (final key in keys)
          DropdownMenuItem<String?>(
            value: key,
            child: Text(key),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class CodexRecordPage extends StatelessWidget {
  final String noteId;

  const CodexRecordPage({
    super.key,
    required this.noteId,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    NoteRecord? note;
    for (final item in store.notes) {
      if (item.id == noteId) {
        note = item;
        break;
      }
    }

    if (note == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kayıt')),
        body: const Center(
          child: Text('Kayıt bulunamadı.'),
        ),
      );
    }

    if (store.selectedId != note.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (store.selectedId != note!.id) {
          store.select(note.id);
        }
      });
    }

    final color = _codexTypeColor(note.type);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _codexTypeIcon(note.type),
                color: color,
                size: 18,
              ),
            ),
            Expanded(
              child: Text(
                note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _NoteOverflowMenu(note: note),
          const SizedBox(width: 4),
        ],
      ),
      body: _CodexPageBackdrop(
        child: Builder(
          builder: (context) {
            final config = HybridConfigScope.of(context);
            final tablet =
                CodexDeviceProfile.of(context).isTablet;
            final inspector = tablet &&
                config.tabletRecordInspector &&
                MediaQuery.sizeOf(context).width >= 900;

            if (!inspector) {
              return const _NoteEditor();
            }

            return Row(
              children: [
                const Expanded(
                  child: _NoteEditor(),
                ),
                SizedBox(
                  width: math.min(
                    config.tabletShelfWidth,
                    340.0,
                  ).toDouble(),
                  child: _CodexTabletRecordInspector(
                    note: note!,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _openCodexRecord(
  BuildContext context,
  NoteRecord note,
) {
  final store = VaultScope.of(context);
  store.select(note.id);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CodexRecordPage(noteId: note.id),
    ),
  );
}

Future<void> _openCodexCreator(
  BuildContext context,
  NoteType type,
) async {
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => StructuredCreatorPage(type: type),
    ),
  );
}


Future<void> _showCodexVaultSwitcher(BuildContext context) async {
  final store = VaultScope.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: SizedBox(
            height: math.min(
              MediaQuery.sizeOf(sheetContext).height * .72,
              620,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kasalar',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Her kasa kendi vault.json dosyasında saklanır.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Yeni kasa',
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _createCodexVaultDialog(context);
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: store.vaultCatalog.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final vault = store.vaultCatalog[index];
                      final active = vault.id == store.activeVaultId;

                      return Material(
                        color: active
                            ? AppColors.purple.withValues(alpha: .10)
                            : AppColors.bg.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: active || store.switchingVault
                              ? null
                              : () async {
                                  Navigator.pop(sheetContext);
                                  await store.switchVault(vault.id);
                                },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: active
                                    ? AppColors.purple.withValues(alpha: .28)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    active
                                        ? Icons.folder_special_rounded
                                        : Icons.folder_outlined,
                                    color: active
                                        ? AppColors.gold
                                        : AppColors.muted,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vault.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${vault.noteCount} kayıt${active ? ' • Aktif' : ''}',
                                        style: TextStyle(
                                          color: active
                                              ? AppColors.purple
                                              : AppColors.muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!active && store.vaultCatalog.length > 1)
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value != 'delete') return;
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text('Kasa silinsin mi?'),
                                          content: Text(
                                            '"${vault.name}" kasası ve klasörü kalıcı olarak silinecek.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: const Text('İptal'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              child: const Text('Sil'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await store.deleteVault(vault.id);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Kasayı sil'),
                                      ),
                                    ],
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.only(right: 10),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: AppColors.green,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _createCodexVaultDialog(context);
                  },
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Yeni Kasa Oluştur'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _createCodexVaultDialog(BuildContext context) async {
  final store = VaultScope.of(context);
  final controller = TextEditingController();

  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Yeni Kasa'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Kasa adı',
          hintText: 'Örn. Yeni Kampanya',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            controller.text.trim(),
          ),
          child: const Text('Oluştur'),
        ),
      ],
    ),
  );

  if (name == null || name.trim().isEmpty) return;
  await store.createVault(name);
}

Future<void> _changeCodexStorageLocation(BuildContext context) async {
  final store = VaultScope.of(context);
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Kayıt konumunu değiştir'),
      content: const Text(
        'Yeni bir klasör seçebilirsin. Seçilen klasörde daha önce oluşturulmuş '
        'bir dmpcsnotebook dizini varsa ona bağlanılır; yoksa mevcut aktif kasa '
        'yeni konuma taşınır.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Klasör Seç'),
        ),
      ],
    ),
  );

  if (confirm != true) return;
  final ok = await store.chooseStorageLocation();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Kayıt konumu hazır: ${store.storageLabel}'
            : (store.storageError ?? 'Kayıt konumu değiştirilemedi.'),
      ),
    ),
  );
}

void _codexSearch(BuildContext context) {
  final store = VaultScope.of(context);
  final controller = TextEditingController();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final q = controller.text.trim().toLowerCase();
          final results = q.isEmpty
              ? <NoteRecord>[]
              : store.notes.where((note) {
                  if (note.archived) return false;
                  final props = note.properties.entries
                      .map((e) => '${e.key} ${e.value}')
                      .join(' ');
                  return '${note.title} ${note.content} $props'
                      .toLowerCase()
                      .contains(q);
                }).take(20).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 4,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
              ),
              child: SizedBox(
                height: math.min(
                  MediaQuery.sizeOf(context).height * .72,
                  620,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Kasada ara...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: q.isEmpty
                          ? const _CodexEmptyLine(
                              icon: Icons.search_rounded,
                              text: 'Başlık, içerik veya özel alan yaz.',
                            )
                          : results.isEmpty
                              ? const _CodexEmptyLine(
                                  icon: Icons.search_off_rounded,
                                  text: 'Eşleşen kayıt yok.',
                                )
                              : ListView.separated(
                                  itemCount: results.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final note = results[index];
                                    return ListTile(
                                      leading: Icon(
                                        _codexTypeIcon(note.type),
                                        color: _codexTypeColor(note.type),
                                      ),
                                      title: Text(
                                        note.title.trim().isEmpty
                                            ? 'Başlıksız'
                                            : note.title,
                                      ),
                                      subtitle: Text(note.type.label),
                                      onTap: () {
                                        Navigator.pop(sheetContext);
                                        _openCodexRecord(context, note);
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

void _codexRenameVault(BuildContext context) {
  final store = VaultScope.of(context);
  final controller = TextEditingController(text: store.vaultName);

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Kasa adını değiştir'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Kasa adı',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () {
            store.renameVault(controller.text);
            Navigator.pop(dialogContext);
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
}

Future<void> _codexImport(BuildContext context) async {
  final store = VaultScope.of(context);
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final raw = data?.text?.trim() ?? '';

  if (raw.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Panoda içe aktarılabilir veri yok.'),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  final mode = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Yedeği içe aktar'),
      content: const Text(
        'Birleştir mevcut kayıtları korur. Değiştir mevcut kasanın yerine yedeği yükler.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('İptal'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, 'merge'),
          child: const Text('Birleştir'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, 'replace'),
          child: const Text('Değiştir'),
        ),
      ],
    ),
  );

  if (mode == null) return;

  try {
    await store.importVaultJson(raw, merge: mode == 'merge');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kasa verisi içe aktarıldı.'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İçe aktarma başarısız'),
        content: Text('$error'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}


// ============================================================================
// FINAL WORKBENCH v1.1 — DM ARAÇLARI VE GELİŞMİŞ KASA ÖZELLİKLERİ
// ============================================================================

String _codexSortLabel(String mode) {
  switch (mode) {
    case 'updated_asc':
      return 'En eski düzenlenen';
    case 'created_desc':
      return 'Yeni oluşturulan';
    case 'title':
      return 'Başlığa göre';
    case 'type':
      return 'Türe göre';
    default:
      return 'Son düzenlenen';
  }
}

class _CodexFilterMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onSelected;

  const _CodexFilterMenu({
    required this.icon,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final entry in items.entries)
          PopupMenuItem(
            value: entry.key,
            child: Text(entry.value),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 17),
          ],
        ),
      ),
    );
  }
}

class _CodexNullableFilterMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> values;
  final ValueChanged<String?> onSelected;

  const _CodexNullableFilterMenu({
    required this.icon,
    required this.label,
    required this.values,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Text('Tümü'),
        ),
        for (final value in values)
          PopupMenuItem<String?>(
            value: value,
            child: Text(value),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 17),
          ],
        ),
      ),
    );
  }
}

class CodexToolsPage extends StatefulWidget {
  const CodexToolsPage({super.key});

  @override
  State<CodexToolsPage> createState() => _CodexToolsPageState();
}

class _CodexToolsPageState extends State<CodexToolsPage> {
  final math.Random _random = math.Random();
  final TextEditingController _initiativeName = TextEditingController();
  final TextEditingController _initiativeValue = TextEditingController();
  final TextEditingController _initiativeHp = TextEditingController();
  final TextEditingController _initiativeMaxHp = TextEditingController();
  final TextEditingController _scratch = TextEditingController();
  final TextEditingController _clockName = TextEditingController();
  final TextEditingController _randomTable = TextEditingController();

  final List<_CodexInitiativeEntry> _initiative = [];
  final List<int> _rollHistory = [];
  final List<_CodexCampaignClock> _clocks = [];

  int _die = 20;
  int _diceCount = 1;
  int _modifier = 0;
  int? _lastRoll;
  int _turnIndex = 0;
  int _round = 1;
  String? _pickedRecord;
  String? _pickedTableValue;

  Timer? _sessionTimer;
  Duration _sessionElapsed = Duration.zero;
  bool _timerRunning = false;

  String? _loadedVaultId;
  bool _loadingPersistentTools = false;
  Timer? _scratchDebounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = VaultScope.of(context);
    final vaultId = store.activeVaultId ?? 'local';
    if (_loadedVaultId != vaultId && !_loadingPersistentTools) {
      _loadedVaultId = vaultId;
      _loadPersistentTools(vaultId);
    }
  }

  Future<void> _loadPersistentTools(String vaultId) async {
    _loadingPersistentTools = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _scratch.text = prefs.getString('dmpcs_scratch_$vaultId') ?? '';
      final rawClocks = prefs.getString('dmpcs_clocks_$vaultId');
      _clocks.clear();
      if (rawClocks != null && rawClocks.isNotEmpty) {
        final decoded = jsonDecode(rawClocks);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              _clocks.add(
                _CodexCampaignClock.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              );
            }
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Araç verileri kritik kasa verisi değildir; bozuk araç verisi uygulamayı durdurmaz.
    } finally {
      _loadingPersistentTools = false;
    }
  }

  Future<void> _saveScratch() async {
    final id = _loadedVaultId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dmpcs_scratch_$id', _scratch.text);
  }

  void _scheduleScratchSave() {
    _scratchDebounce?.cancel();
    _scratchDebounce = Timer(
      const Duration(milliseconds: 450),
      _saveScratch,
    );
  }

  Future<void> _saveClocks() async {
    final id = _loadedVaultId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'dmpcs_clocks_$id',
      jsonEncode(_clocks.map((e) => e.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _scratchDebounce?.cancel();
    _initiativeName.dispose();
    _initiativeValue.dispose();
    _initiativeHp.dispose();
    _initiativeMaxHp.dispose();
    _scratch.dispose();
    _clockName.dispose();
    _randomTable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final activeNotes = store.notes.where((n) => !n.archived).toList();

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            const _CodexHeader(
              eyebrow: 'ARAÇLAR',
              title: 'DM Çalışma Masası',
              subtitle:
                  'Zar, initiative, görevler, bağlantılar, sayaçlar ve masa notları tek yerde.',
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(22, 5, 22, 46),
                    children: [
                      _CodexToolLaunchGrid(store: store),
                      const SizedBox(height: 14),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _diceCard(),
                                  const SizedBox(height: 14),
                                  _timerCard(),
                                  const SizedBox(height: 14),
                                  _randomCard(activeNotes),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                children: [
                                  _initiativeCard(),
                                  const SizedBox(height: 14),
                                  _clockCard(),
                                  const SizedBox(height: 14),
                                  _scratchCard(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _diceCard(),
                        const SizedBox(height: 14),
                        _initiativeCard(),
                        const SizedBox(height: 14),
                        _timerCard(),
                        const SizedBox(height: 14),
                        _clockCard(),
                        const SizedBox(height: 14),
                        _randomCard(activeNotes),
                        const SizedBox(height: 14),
                        _scratchCard(),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diceCard() {
    const dice = [4, 6, 8, 10, 12, 20, 100];

    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.casino_outlined,
            title: 'Zar Masası',
            subtitle: 'Adet, zar türü ve bonusla hızlı atış.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in dice)
                ChoiceChip(
                  label: Text('d$value'),
                  selected: _die == value,
                  onSelected: (_) => setState(() => _die = value),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CodexStepper(
                  label: 'Adet',
                  value: _diceCount,
                  min: 1,
                  max: 20,
                  onChanged: (value) =>
                      setState(() => _diceCount = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CodexStepper(
                  label: 'Bonus',
                  value: _modifier,
                  min: -30,
                  max: 30,
                  onChanged: (value) =>
                      setState(() => _modifier = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              var total = _modifier;
              for (var i = 0; i < _diceCount; i++) {
                total += _random.nextInt(_die) + 1;
              }
              setState(() {
                _lastRoll = total;
                _rollHistory.insert(0, total);
                if (_rollHistory.length > 10) {
                  _rollHistory.removeLast();
                }
              });
            },
            icon: const Icon(Icons.casino_rounded),
            label: Text(
              _lastRoll == null
                  ? '$_diceCount d$_die ${_modifier >= 0 ? '+' : ''}$_modifier at'
                  : 'Sonuç: $_lastRoll',
            ),
          ),
          if (_rollHistory.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final value in _rollHistory)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('$value'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _initiativeCard() {
    final active = _initiative.isEmpty
        ? null
        : _initiative[_turnIndex.clamp(0, _initiative.length - 1).toInt()];

    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CodexPanelTitle(
            icon: Icons.format_list_numbered_rounded,
            title: 'Initiative & HP',
            subtitle: _initiative.isEmpty
                ? 'Savaş sırasını ve canları masada takip et.'
                : 'Tur $_round • Sıra: ${active?.name ?? '-'}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _initiativeName,
            decoration: const InputDecoration(
              labelText: 'İsim / Etiket',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _initiativeValue,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Initiative',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _initiativeHp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'HP',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _initiativeMaxHp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max HP',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addInitiative,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Sıraya ekle'),
          ),
          if (_initiative.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _initiative.length; i++)
              _CodexInitiativeRow(
                entry: _initiative[i],
                active: i == _turnIndex,
                onDamage: () {
                  setState(() {
                    _initiative[i].hp =
                        math.max(0, _initiative[i].hp - 1).toInt();
                  });
                },
                onHeal: () {
                  setState(() {
                    _initiative[i].hp = math.min(
                      _initiative[i].maxHp,
                      _initiative[i].hp + 1,
                    ).toInt();
                  });
                },
                onDelete: () {
                  setState(() {
                    _initiative.removeAt(i);
                    if (_initiative.isEmpty) {
                      _turnIndex = 0;
                      _round = 1;
                    } else {
                      _turnIndex =
                          _turnIndex.clamp(0, _initiative.length - 1).toInt();
                    }
                  });
                },
              ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _nextTurn,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Sonraki sıra'),
                  ),
                ),
                const SizedBox(width: 7),
                IconButton(
                  tooltip: 'Savaşı sıfırla',
                  onPressed: () {
                    setState(() {
                      _initiative.clear();
                      _turnIndex = 0;
                      _round = 1;
                    });
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _addInitiative() {
    final name = _initiativeName.text.trim();
    if (name.isEmpty) return;

    final initiative =
        int.tryParse(_initiativeValue.text.trim()) ?? 0;
    final hp = int.tryParse(_initiativeHp.text.trim()) ?? 1;
    final maxHp =
        int.tryParse(_initiativeMaxHp.text.trim()) ?? hp;

    setState(() {
      _initiative.add(
        _CodexInitiativeEntry(
          name: name,
          initiative: initiative,
          hp: hp.clamp(0, math.max(1, maxHp)).toInt(),
          maxHp: math.max(1, maxHp).toInt(),
        ),
      );
      _initiative.sort(
        (a, b) => b.initiative.compareTo(a.initiative),
      );
      _turnIndex = 0;
      _round = 1;
      _initiativeName.clear();
      _initiativeValue.clear();
      _initiativeHp.clear();
      _initiativeMaxHp.clear();
    });
  }

  void _nextTurn() {
    if (_initiative.isEmpty) return;
    setState(() {
      _turnIndex++;
      if (_turnIndex >= _initiative.length) {
        _turnIndex = 0;
        _round++;
      }
    });
  }

  Widget _timerCard() {
    final hours = _sessionElapsed.inHours.toString().padLeft(2, '0');
    final minutes =
        (_sessionElapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (_sessionElapsed.inSeconds % 60).toString().padLeft(2, '0');

    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.timer_outlined,
            title: 'Oturum Kronometresi',
            subtitle: 'Masa süresini kesintisiz takip et.',
          ),
          const SizedBox(height: 16),
          Text(
            '$hours:$minutes:$seconds',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggleTimer,
                  icon: Icon(
                    _timerRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _timerRunning ? 'Duraklat' : 'Başlat',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _sessionTimer?.cancel();
                  setState(() {
                    _timerRunning = false;
                    _sessionElapsed = Duration.zero;
                  });
                },
                child: const Text('Sıfırla'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _sessionTimer?.cancel();
      setState(() => _timerRunning = false);
      return;
    }

    setState(() => _timerRunning = true);
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        setState(() {
          _sessionElapsed += const Duration(seconds: 1);
        });
      },
    );
  }

  Widget _clockCard() {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.donut_large_outlined,
            title: 'Kampanya Saatleri',
            subtitle: 'Tehdit, ritüel, alarm veya ilerleme sayaçları.',
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _clockName,
                  decoration: const InputDecoration(
                    hintText: 'Saat adı',
                  ),
                ),
              ),
              const SizedBox(width: 7),
              FilledButton(
                onPressed: () {
                  final name = _clockName.text.trim();
                  if (name.isEmpty) return;
                  setState(() {
                    _clocks.add(
                      _CodexCampaignClock(
                        name: name,
                        current: 0,
                        max: 6,
                      ),
                    );
                    _clockName.clear();
                  });
                  _saveClocks();
                },
                child: const Text('Ekle'),
              ),
            ],
          ),
          if (_clocks.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _clocks.length; i++)
              _CodexClockRow(
                clock: _clocks[i],
                onMinus: () {
                  setState(() {
                    _clocks[i].current =
                        math.max(0, _clocks[i].current - 1).toInt();
                  });
                  _saveClocks();
                },
                onPlus: () {
                  setState(() {
                    _clocks[i].current =
                        math.min(_clocks[i].max, _clocks[i].current + 1).toInt();
                  });
                  _saveClocks();
                },
                onMaxChanged: (value) {
                  setState(() {
                    _clocks[i].max = value;
                    _clocks[i].current =
                        math.min(_clocks[i].current, value).toInt();
                  });
                  _saveClocks();
                },
                onDelete: () {
                  setState(() => _clocks.removeAt(i));
                  _saveClocks();
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _randomCard(List<NoteRecord> notes) {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.shuffle_rounded,
            title: 'Rastgele Seçiciler',
            subtitle: 'Kasadan kayıt veya kendi listen içinden seçim yap.',
          ),
          const SizedBox(height: 11),
          OutlinedButton.icon(
            onPressed: notes.isEmpty
                ? null
                : () {
                    final note = notes[_random.nextInt(notes.length)];
                    setState(() {
                      _pickedRecord = note.title.trim().isEmpty
                          ? 'Başlıksız'
                          : note.title;
                    });
                  },
            icon: const Icon(Icons.folder_copy_outlined),
            label: Text(
              _pickedRecord == null
                  ? 'Kasadan rastgele kayıt'
                  : 'Seçilen: $_pickedRecord',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _randomTable,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Rastgele tablo',
              hintText:
                  'Her satıra kendi seçeneğini yaz.\nHazır hikâye içeriği eklenmez.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              final rows = _randomTable.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (rows.isEmpty) return;
              setState(() {
                _pickedTableValue =
                    rows[_random.nextInt(rows.length)];
              });
            },
            icon: const Icon(Icons.shuffle_rounded),
            label: Text(
              _pickedTableValue == null
                  ? 'Listeden seç'
                  : 'Sonuç: $_pickedTableValue',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scratchCard() {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.edit_note_rounded,
            title: 'Hızlı Masa Notu',
            subtitle: 'Aktif kasaya özel geçici çalışma alanı; otomatik kaydolur.',
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _scratch,
            minLines: 7,
            maxLines: 14,
            onChanged: (_) => _scheduleScratchSave(),
            decoration: const InputDecoration(
              hintText:
                  'Masada hızlıca bakacağın şeyleri buraya yaz...',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bu alan aktif kasaya bağlı olarak cihazda saklanır.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexToolLaunchGrid extends StatelessWidget {
  final VaultStore store;

  const _CodexToolLaunchGrid({
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = store.notes.where((n) => !n.archived).toList();
    final openTasks = active.fold<int>(
      0,
      (sum, note) => sum +
          store.tasksFor(note).where(
            (line) => line.trimLeft().toLowerCase().startsWith('- [ ]'),
          ).length,
    );
    final broken = active.fold<int>(
      0,
      (sum, note) => sum + store.unresolvedLinks(note).length,
    );

    final cards = <_ToolLaunchData>[
      _ToolLaunchData(
        icon: Icons.checklist_rounded,
        title: 'Görev Merkezi',
        detail: '$openTasks açık görev',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexTaskCenterPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.link_off_rounded,
        title: 'Bağlantı Sağlığı',
        detail: '$broken eksik hedef',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexLinkHealthPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.bookmarks_outlined,
        title: 'Sabit & Yer İmleri',
        detail:
            '${active.where((n) => n.pinned || n.bookmarked).length} kayıt',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexSavedRecordsPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.folder_open_rounded,
        title: 'Etiket & Klasör',
        detail: '${store.allTags.length} etiket • ${store.allFolders.length} klasör',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexTaxonomyPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.science_outlined,
        title: 'Örnekler Laboratuvarı',
        detail: '106 özelliğin kullanım örnekleri',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexFeatureShowcasePage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.insights_outlined,
        title: 'Kasa Analizi',
        detail: 'Sağlık, tekrar, yaş, uzunluk ve boyut',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexVaultInsightsPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.library_add_check_outlined,
        title: 'Toplu İşlemler',
        detail: 'Seç, etiketle, taşı, sabitle ve arşivle',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexBulkActionsPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.draw_outlined,
        title: 'Yazım Laboratuvarı',
        detail: 'Kelime hedefi, Markdown ve metin araçları',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexWritingLabPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.hourglass_bottom_rounded,
        title: 'Oturum Yardımcıları',
        detail: 'Sayaç, sahne, spotlight ve kaynak araçları',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexSessionUtilityPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.shield_outlined,
        title: 'Savaş Paneli+',
        detail: 'AC, geçici HP, durumlar ve savaş özeti',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexCombatBoardPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.dashboard_customize_outlined,
        title: 'Üretkenlik Merkezi',
        detail: '12 hızlı kasa ve not iş akışı',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexProductivityPlusPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.query_stats_rounded,
        title: 'İstatistikler+',
        detail: '12 yeni gelişmiş kasa metriği',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexAnalyticsPlusPage(),
          ),
        ),
      ),
      _ToolLaunchData(
        icon: Icons.bolt_rounded,
        title: 'Hızlı İşlemler+',
        detail: '12 yeni metin ve kayıt işlemi',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CodexQuickActionsPlusPage(),
          ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 3.8 : 2.4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final card in cards)
              Material(
                color: scheme.surfaceContainer.withValues(alpha: .97),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: card.onTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            card.icon,
                            color: scheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                card.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ToolLaunchData {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _ToolLaunchData({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
}

class _CodexStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _CodexStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_rounded, size: 17),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _CodexInitiativeEntry {
  final String name;
  final int initiative;
  int hp;
  final int maxHp;

  _CodexInitiativeEntry({
    required this.name,
    required this.initiative,
    required this.hp,
    required this.maxHp,
  });
}

class _CodexInitiativeRow extends StatelessWidget {
  final _CodexInitiativeEntry entry;
  final bool active;
  final VoidCallback onDamage;
  final VoidCallback onHeal;
  final VoidCallback onDelete;

  const _CodexInitiativeRow({
    required this.entry,
    required this.active,
    required this.onDamage,
    required this.onHeal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      decoration: BoxDecoration(
        color: active
            ? scheme.primary.withValues(alpha: .10)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${entry.initiative}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: entry.hp <= 0
                        ? AppColors.red
                        : scheme.onSurface,
                  ),
                ),
                Text(
                  'HP ${entry.hp}/${entry.maxHp}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '-1 HP',
            visualDensity: VisualDensity.compact,
            onPressed: onDamage,
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
          ),
          IconButton(
            tooltip: '+1 HP',
            visualDensity: VisualDensity.compact,
            onPressed: onHeal,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Kaldır',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CodexCampaignClock {
  String name;
  int current;
  int max;

  _CodexCampaignClock({
    required this.name,
    required this.current,
    required this.max,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'current': current,
        'max': max,
      };

  factory _CodexCampaignClock.fromJson(Map<String, dynamic> json) {
    return _CodexCampaignClock(
      name: json['name']?.toString() ?? 'Saat',
      current: (json['current'] as num?)?.toInt() ?? 0,
      max: math.max(2, (json['max'] as num?)?.toInt() ?? 6).toInt(),
    );
  }
}

class _CodexClockRow extends StatelessWidget {
  final _CodexCampaignClock clock;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<int> onMaxChanged;
  final VoidCallback onDelete;

  const _CodexClockRow({
    required this.clock,
    required this.onMinus,
    required this.onPlus,
    required this.onMaxChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ratio =
        clock.max <= 0 ? 0.0 : clock.current / clock.max;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  clock.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<int>(
                tooltip: 'Bölüm sayısı',
                onSelected: onMaxChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 4, child: Text('4 bölüm')),
                  PopupMenuItem(value: 6, child: Text('6 bölüm')),
                  PopupMenuItem(value: 8, child: Text('8 bölüm')),
                  PopupMenuItem(value: 10, child: Text('10 bölüm')),
                  PopupMenuItem(value: 12, child: Text('12 bölüm')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  child: Text(
                    '${clock.current}/${clock.max}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: ratio.clamp(0.0, 1.0).toDouble(),
              backgroundColor: AppColors.panel2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onMinus,
                  child: const Icon(Icons.remove_rounded, size: 17),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  onPressed: onPlus,
                  child: const Icon(Icons.add_rounded, size: 17),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CodexTaskCenterPage extends StatelessWidget {
  const CodexTaskCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final tasks = <(NoteRecord, String)>[];

    for (final note in store.notes.where((n) => !n.archived)) {
      for (final line in store.tasksFor(note)) {
        tasks.add((note, line));
      }
    }

    tasks.sort((a, b) {
      final aDone = a.$2.trimLeft().toLowerCase().startsWith('- [x]');
      final bDone = b.$2.trimLeft().toLowerCase().startsWith('- [x]');
      if (aDone != bDone) return aDone ? 1 : -1;
      return b.$1.updatedAt.compareTo(a.$1.updatedAt);
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Görev Merkezi')),
      body: tasks.isEmpty
          ? const Center(
              child: _CodexEmptyLine(
                icon: Icons.check_box_outlined,
                text: 'Kasada görev satırı yok.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final note = tasks[index].$1;
                final line = tasks[index].$2;
                final done = line
                    .trimLeft()
                    .toLowerCase()
                    .startsWith('- [x]');

                return Material(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(15),
                  child: ListTile(
                    leading: Checkbox(
                      value: done,
                      onChanged: (_) =>
                          _toggleCodexTask(context, note, line),
                    ),
                    title: Text(
                      _cleanTaskText(line),
                      style: TextStyle(
                        decoration: done
                            ? TextDecoration.lineThrough
                            : null,
                        color: done
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      note.title.trim().isEmpty
                          ? 'Başlıksız'
                          : note.title,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openCodexRecord(context, note),
                  ),
                );
              },
            ),
    );
  }
}

String _cleanTaskText(String line) {
  return line
      .replaceFirst(RegExp(r'^\s*-\s*\[[ xX]\]\s*'), '')
      .trim();
}

Future<void> _toggleCodexTask(
  BuildContext context,
  NoteRecord note,
  String originalLine,
) async {
  final store = VaultScope.of(context);
  final isDone = originalLine
      .trimLeft()
      .toLowerCase()
      .startsWith('- [x]');
  final replacement = isDone
      ? originalLine.replaceFirst(
          RegExp(r'-\s*\[[xX]\]'),
          '- [ ]',
        )
      : originalLine.replaceFirst(
          RegExp(r'-\s*\[\s\]'),
          '- [x]',
        );

  await store.updateNote(
    note,
    content: note.content.replaceFirst(
      originalLine,
      replacement,
    ),
  );
}

class CodexLinkHealthPage extends StatelessWidget {
  const CodexLinkHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.notes.where((n) => !n.archived).toList();
    final broken = notes.where(
      (n) => store.unresolvedLinks(n).isNotEmpty,
    ).toList();
    final orphan = notes.where(
      (n) =>
          store.backlinksFor(n).isEmpty &&
          store.outgoingResolved(n).isEmpty,
    ).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Bağlantı Sağlığı')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CodexPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CodexPanelTitle(
                  icon: Icons.link_off_rounded,
                  title: 'Eksik Hedefler',
                  subtitle:
                      '${broken.length} kayıtta çözülemeyen bağlantı var.',
                ),
                const SizedBox(height: 9),
                if (broken.isEmpty)
                  const _CodexEmptyLine(
                    icon: Icons.check_circle_outline_rounded,
                    text: 'Eksik bağlantı yok.',
                  )
                else
                  for (final note in broken)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        note.title.trim().isEmpty
                            ? 'Başlıksız'
                            : note.title,
                      ),
                      subtitle: Text(
                        store
                            .unresolvedLinks(note)
                            .map((e) => '[[${store.linkTarget(e)}]]')
                            .join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing:
                          const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openCodexRecord(context, note),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CodexPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CodexPanelTitle(
                  icon: Icons.bubble_chart_outlined,
                  title: 'Bağlantısız Kayıtlar',
                  subtitle:
                      '${orphan.length} kayıt ağın dışında kalıyor.',
                ),
                const SizedBox(height: 9),
                if (orphan.isEmpty)
                  const _CodexEmptyLine(
                    icon: Icons.hub_outlined,
                    text: 'Tüm kayıtların en az bir bağlantısı var.',
                  )
                else
                  for (final note in orphan)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _codexTypeIcon(note.type),
                        color: _codexTypeColor(note.type),
                      ),
                      title: Text(
                        note.title.trim().isEmpty
                            ? 'Başlıksız'
                            : note.title,
                      ),
                      trailing:
                          const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openCodexRecord(context, note),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CodexSavedRecordsPage extends StatefulWidget {
  const CodexSavedRecordsPage({super.key});

  @override
  State<CodexSavedRecordsPage> createState() =>
      _CodexSavedRecordsPageState();
}

class _CodexSavedRecordsPageState
    extends State<CodexSavedRecordsPage> {
  bool bookmarks = true;

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.notes
        .where((n) =>
            !n.archived && (bookmarks ? n.bookmarked : n.pinned))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Sabit & Yer İmleri')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.bookmark_border_rounded),
                  label: Text('Yer İmleri'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.push_pin_outlined),
                  label: Text('Sabitlenenler'),
                ),
              ],
              selected: {bookmarks},
              onSelectionChanged: (values) =>
                  setState(() => bookmarks = values.first),
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: _CodexEmptyLine(
                      icon: bookmarks
                          ? Icons.bookmark_border_rounded
                          : Icons.push_pin_outlined,
                      text: bookmarks
                          ? 'Yer imi yok.'
                          : 'Sabitlenmiş kayıt yok.',
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 30),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 7),
                    itemBuilder: (context, index) =>
                        _CodexVaultTile(note: notes[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class CodexTaxonomyPage extends StatefulWidget {
  const CodexTaxonomyPage({super.key});

  @override
  State<CodexTaxonomyPage> createState() =>
      _CodexTaxonomyPageState();
}

class _CodexTaxonomyPageState extends State<CodexTaxonomyPage> {
  bool tags = true;

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final values = tags ? store.allTags : store.allFolders;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Etiket & Klasör Gezgini')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.tag_rounded),
                  label: Text('Etiketler'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.folder_outlined),
                  label: Text('Klasörler'),
                ),
              ],
              selected: {tags},
              onSelectionChanged: (values) =>
                  setState(() => tags = values.first),
            ),
          ),
          Expanded(
            child: values.isEmpty
                ? const Center(
                    child: _CodexEmptyLine(
                      icon: Icons.inventory_2_outlined,
                      text: 'Gösterilecek kategori yok.',
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 30),
                    itemCount: values.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final value = values[index];
                      final matching = store.notes.where((note) {
                        if (note.archived) return false;
                        if (tags) {
                          final set = <String>{
                            ...store.extractTags(note.content),
                            ...(note.properties['tags'] ?? '')
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .map((e) =>
                                    e.startsWith('#') ? e : '#$e'),
                          };
                          return set.contains(value);
                        }
                        final folder =
                            (note.properties['folder'] ?? '/').trim();
                        return (folder.startsWith('/')
                                ? folder
                                : '/$folder') ==
                            value;
                      }).toList();

                      return ExpansionTile(
                        leading: Icon(
                          tags
                              ? Icons.tag_rounded
                              : Icons.folder_outlined,
                          color: AppColors.purple,
                        ),
                        title: Text(value),
                        subtitle: Text(
                          '${matching.length} kayıt',
                          style: const TextStyle(
                            color: AppColors.muted,
                          ),
                        ),
                        children: [
                          for (final note in matching)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                _codexTypeIcon(note.type),
                                color: _codexTypeColor(note.type),
                              ),
                              title: Text(
                                note.title.trim().isEmpty
                                    ? 'Başlıksız'
                                    : note.title,
                              ),
                              onTap: () =>
                                  _openCodexRecord(context, note),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CodexFocusPage extends StatelessWidget {
  final String noteId;

  const CodexFocusPage({
    super.key,
    required this.noteId,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    NoteRecord? note;
    for (final item in store.notes) {
      if (item.id == noteId) {
        note = item;
        break;
      }
    }

    if (note == null) {
      return const Scaffold(
        body: Center(child: Text('Kayıt bulunamadı.')),
      );
    }

    if (store.selectedId != note.id) {
      store.select(note.id);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          note.title.trim().isEmpty ? 'Odak Modu' : note.title,
        ),
        actions: [
          IconButton(
            tooltip: 'İlişkiler',
            onPressed: () =>
                _showCodexRelatedRecords(context, note!),
            icon: const Icon(Icons.account_tree_outlined),
          ),
        ],
      ),
      body: const _NoteEditor(),
    );
  }
}

void _showCodexRelatedRecords(
  BuildContext context,
  NoteRecord note,
) {
  final store = VaultScope.of(context);
  final outgoing = store.outgoingResolved(note);
  final backlinks = store.backlinksFor(note);
  final mentions = store.unlinkedMentionsFor(note);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      Widget section(
        String title,
        IconData icon,
        List<NoteRecord> notes,
      ) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.purple),
                const SizedBox(width: 7),
                Text(
                  '$title (${notes.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (notes.isEmpty)
              const Text(
                'Yok',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                ),
              )
            else
              for (final item in notes)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _codexTypeIcon(item.type),
                    color: _codexTypeColor(item.type),
                  ),
                  title: Text(
                    item.title.trim().isEmpty
                        ? 'Başlıksız'
                        : item.title,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openCodexRecord(context, item);
                  },
                ),
            const SizedBox(height: 14),
          ],
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: SizedBox(
            height: math.min(
              MediaQuery.sizeOf(context).height * .72,
              620.0,
            ).toDouble(),
            child: ListView(
              children: [
                Text(
                  note.title.trim().isEmpty
                      ? 'İlişkili Kayıtlar'
                      : note.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                section(
                  'Giden bağlantılar',
                  Icons.arrow_outward_rounded,
                  outgoing,
                ),
                section(
                  'Geri bağlantılar',
                  Icons.keyboard_return_rounded,
                  backlinks,
                ),
                section(
                  'Bağlantısız bahsetmeler',
                  Icons.text_snippet_outlined,
                  mentions,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _showCodexRecordStats(
  BuildContext context,
  NoteRecord note,
) {
  final store = VaultScope.of(context);
  final words = note.content
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .length;
  final characters = note.content.length;
  final links = store.extractLinks(note.content).length;
  final tasks = store.tasksFor(note).length;
  final properties = note.properties.length;
  final backlinks = store.backlinksFor(note).length;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Wrap(
            runSpacing: 8,
            spacing: 8,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Kayıt İstatistikleri',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _CodexStatChip(label: 'Kelime', value: '$words'),
              _CodexStatChip(label: 'Karakter', value: '$characters'),
              _CodexStatChip(label: 'Bağlantı', value: '$links'),
              _CodexStatChip(label: 'Geri bağlantı', value: '$backlinks'),
              _CodexStatChip(label: 'Görev', value: '$tasks'),
              _CodexStatChip(label: 'Özel alan', value: '$properties'),
            ],
          ),
        ),
      );
    },
  );
}

class _CodexStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _CodexStatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MOTION WORKBENCH v1.2 — 50 YENİ ÖZELLİK + ÖRNEK LABORATUVARI
// ============================================================================

class _CodexAnimatedAtmosphere extends StatefulWidget {
  const _CodexAnimatedAtmosphere();

  @override
  State<_CodexAnimatedAtmosphere> createState() =>
      _CodexAnimatedAtmosphereState();
}

class _CodexAnimatedAtmosphereState
    extends State<_CodexAnimatedAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appearance = CodexAppearanceScope.of(context);
    _controller.duration = Duration(
      milliseconds: (18000 / appearance.motionScale).round(),
    );
    if (appearance.reduceMotion && _controller.isAnimating) {
      _controller.stop();
      _controller.value = .35;
    } else if (!appearance.reduceMotion &&
        !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appearance = CodexAppearanceScope.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          painter: _CodexMotionPainter(
            phase: _controller.value,
            background: Theme.of(context).scaffoldBackgroundColor,
            primary: scheme.primary,
            secondary: scheme.tertiary,
            grid: scheme.outlineVariant,
            showGrid: appearance.backgroundGrid,
            gridStrength: appearance.gridStrength,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _CodexMotionPainter extends CustomPainter {
  final double phase;
  final Color background;
  final Color primary;
  final Color secondary;
  final Color grid;
  final bool showGrid;
  final double gridStrength;

  const _CodexMotionPainter({
    required this.phase,
    required this.background,
    required this.primary,
    required this.secondary,
    required this.grid,
    required this.showGrid,
    required this.gridStrength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = background,
    );

    final first = Offset(
      size.width * (.72 + .12 * phase),
      size.height * (.08 + .06 * phase),
    );
    final second = Offset(
      size.width * (.10 + .08 * (1 - phase)),
      size.height * (.76 + .08 * phase),
    );

    final glow1 = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: .085),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: first,
          radius: size.width * .55,
        ),
      );

    final glow2 = Paint()
      ..shader = RadialGradient(
        colors: [
          secondary.withValues(alpha: .045),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: second,
          radius: size.width * .5,
        ),
      );

    canvas.drawRect(Offset.zero & size, glow1);
    canvas.drawRect(Offset.zero & size, glow2);

    if (!showGrid) return;

    final linePaint = Paint()
      ..color = grid.withValues(
        alpha: (.12 + .05 * phase) * gridStrength,
      )
      ..strokeWidth = 1;

    const spacing = 54.0;
    final drift = 5 * phase;

    for (double x = -spacing + drift;
        x < size.width + spacing;
        x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        linePaint,
      );
    }

    for (double y = -spacing + drift;
        y < size.height + spacing;
        y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CodexMotionPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.background != background ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.grid != grid ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.gridStrength != gridStrength;
  }
}

class _CodexEntrance extends StatelessWidget {
  final Widget child;
  final int index;

  const _CodexEntrance({
    required this.child,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final duration = Duration(
      milliseconds: 260 + math.min(index, 12).toInt() * 24,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _FeatureDemo {
  final int number;
  final String category;
  final String title;
  final String detail;
  final String example;
  final IconData icon;

  const _FeatureDemo(
    this.number,
    this.category,
    this.title,
    this.detail,
    this.example,
    this.icon,
  );
}

const _featureDemos = <_FeatureDemo>[
  _FeatureDemo(1, 'Temel', 'Araçlar ana sekmesi', 'DM araçlarını tek çalışma masasında toplar.', 'Araçlar → Zar Masası, Initiative, Görev Merkezi.', Icons.construction_outlined),
  _FeatureDemo(2, 'Temel', 'Gelişmiş zar masası', 'Zar yüzü, adet ve bonusla atış yapar.', '2d20 + 4.', Icons.casino_outlined),
  _FeatureDemo(3, 'Temel', 'Zar geçmişi', 'Son 10 sonucu tutar.', '18, 7, 23, 14.', Icons.history_rounded),
  _FeatureDemo(4, 'Savaş', 'Initiative takipçisi', 'Katılımcıları sıraya dizer.', 'Karakter A 17, Yaratık B 12.', Icons.format_list_numbered_rounded),
  _FeatureDemo(5, 'Savaş', 'Tur ve round yönetimi', 'Sonraki sıra ile round ilerler.', 'Tur 3 • Sıra 2.', Icons.skip_next_rounded),
  _FeatureDemo(6, 'Savaş', 'HP takipçisi', 'Mevcut ve maksimum HP izler.', '21 / 30 HP.', Icons.favorite_border_rounded),
  _FeatureDemo(7, 'Oturum', 'Oturum kronometresi', 'Masa süresini ölçer.', '02:14:08.', Icons.timer_outlined),
  _FeatureDemo(8, 'Oturum', 'Hızlı masa notu', 'Kasaya özel otomatik kayıtlı not alanı.', 'Sonraki sahnede haritayı aç.', Icons.edit_note_rounded),
  _FeatureDemo(9, 'Oturum', 'Kampanya saatleri', 'Bölümlü ilerleme sayaçları.', 'Alarm 4/6.', Icons.donut_large_outlined),
  _FeatureDemo(10, 'Oturum', 'Kasadan rastgele kayıt', 'Aktif kayıtlardan seçim yapar.', '42 kayıt içinden bir seçim.', Icons.shuffle_rounded),
  _FeatureDemo(11, 'Oturum', 'Kullanıcı rastgele tablosu', 'Satır listesinden rastgele seçim yapar.', 'Dört seçenekten biri.', Icons.list_alt_rounded),
  _FeatureDemo(12, 'Kasa', 'Görev Merkezi', 'Notlardaki görevleri bir araya getirir.', '- [ ] Haritayı güncelle.', Icons.checklist_rounded),
  _FeatureDemo(13, 'Kasa', 'Merkezden görev tamamlama', 'Görevi kaynağı açmadan değiştirir.', '[ ] → [x].', Icons.check_box_rounded),
  _FeatureDemo(14, 'Kasa', 'Bağlantı Sağlığı', 'Eksik linkleri ve bağlantısız kayıtları bulur.', '[[Olmayan Not]] uyarısı.', Icons.link_off_rounded),
  _FeatureDemo(15, 'Kasa', 'Sabit & Yer İmleri', 'Önemli kayıtları ayrı toplar.', 'Sık kullanılan 5 kayıt.', Icons.bookmarks_outlined),
  _FeatureDemo(16, 'Kasa', 'Etiket & Klasör Gezgini', 'Kategori içinden kayıt açar.', '#şehir → 8 kayıt.', Icons.folder_open_rounded),
  _FeatureDemo(17, 'Kasa', 'Kasa hızlı filtreleri', 'Sabit, görev ve bağlantı filtreleri.', 'Sadece açık görev içeren kayıtlar.', Icons.filter_alt_outlined),
  _FeatureDemo(18, 'Kasa', 'Gelişmiş sıralama', 'Başlık, tür ve tarihe göre sıralar.', 'A→Z.', Icons.sort_rounded),
  _FeatureDemo(19, 'Kayıt', 'Kayıt araçları', 'Link, JSON, ilişki ve istatistik araçları.', '[[Not Başlığı]] panoya kopyalanır.', Icons.more_horiz_rounded),
  _FeatureDemo(20, 'Kayıt', 'Odak Modu', 'Kaydı tam ekran editörde açar.', 'Yalnız aktif kayıt editörü.', Icons.center_focus_strong_outlined),
  _FeatureDemo(21, 'Analiz', 'Kasa sağlık puanı', 'Kasa bütünlüğünden 0–100 puan üretir.', 'Sağlık 86/100.', Icons.monitor_heart_outlined),
  _FeatureDemo(22, 'Analiz', 'Başlıksız kayıt bulucu', 'Başlığı boş kayıtları listeler.', '3 başlıksız kayıt.', Icons.title_rounded),
  _FeatureDemo(23, 'Analiz', 'Boş içerik bulucu', 'İçeriksiz kayıtları tespit eder.', '2 boş kayıt.', Icons.hourglass_empty_rounded),
  _FeatureDemo(24, 'Analiz', 'Tekrarlanan başlık bulucu', 'Aynı başlıktaki kayıtları bulur.', 'Han başlığı iki kez.', Icons.content_copy_rounded),
  _FeatureDemo(25, 'Analiz', 'Eski kayıt bulucu', 'Uzun süredir değişmeyen kayıtları gösterir.', '30+ günlük kayıtlar.', Icons.history_toggle_off_rounded),
  _FeatureDemo(26, 'Analiz', 'Uzun kayıt bulucu', 'Kelime eşiğinin üstünü listeler.', '1.500+ kelime.', Icons.subject_rounded),
  _FeatureDemo(27, 'Analiz', 'Son 24 saat görünümü', 'Yeni değişen kayıtları gösterir.', 'Bugün 7 kayıt düzenlendi.', Icons.today_outlined),
  _FeatureDemo(28, 'Analiz', 'Okuma süresi', 'Kelime sayısından süre tahmini yapar.', '820 kelime ≈ 5 dk.', Icons.schedule_outlined),
  _FeatureDemo(29, 'Analiz', 'Kasa kelime sayısı', 'Aktif kayıtların toplam kelimesini verir.', '18.420 kelime.', Icons.calculate_outlined),
  _FeatureDemo(30, 'Analiz', 'Depolama boyutu tahmini', 'JSON boyutunu hesaplar.', '312 KB.', Icons.storage_outlined),
  _FeatureDemo(31, 'Toplu', 'Çoklu kayıt seçimi', 'Birden fazla kaydı işaretler.', '12 kayıt seçili.', Icons.library_add_check_outlined),
  _FeatureDemo(32, 'Toplu', 'Toplu sabitleme', 'Seçilenleri sabitler.', '5 kayıt sabitlendi.', Icons.push_pin_outlined),
  _FeatureDemo(33, 'Toplu', 'Toplu yer imi', 'Seçilenleri yer imine ekler.', 'Oturum kayıtları işaretlendi.', Icons.bookmark_add_outlined),
  _FeatureDemo(34, 'Toplu', 'Toplu arşiv', 'Seçilenleri arşivler.', '8 görev arşivlendi.', Icons.archive_outlined),
  _FeatureDemo(35, 'Toplu', 'Toplu klasör taşıma', 'Seçilenlerin klasörünü değiştirir.', '/NPC/Şehir.', Icons.drive_file_move_outlined),
  _FeatureDemo(36, 'Toplu', 'Toplu etiket ekleme', 'Aynı etiketi çoklu ekler.', '#hazır.', Icons.new_label_outlined),
  _FeatureDemo(37, 'Toplu', 'Toplu etiket kaldırma', 'Etiketi çoklu kaldırır.', '#taslak kaldırıldı.', Icons.label_off_outlined),
  _FeatureDemo(38, 'Toplu', 'Toplu durum alanı', 'status alanını günceller.', 'status = Aktif.', Icons.flag_outlined),
  _FeatureDemo(39, 'Toplu', 'Toplu öncelik alanı', 'priority alanını ayarlar.', 'priority = Yüksek.', Icons.priority_high_rounded),
  _FeatureDemo(40, 'Toplu', 'Toplu görünürlük', 'Görünürlüğü çoklu değiştirir.', 'Sadece Ben.', Icons.visibility_outlined),
  _FeatureDemo(41, 'Yazım', 'Kelime hedefi', 'Kayıt için hedef saklar.', 'Hedef 1000 kelime.', Icons.track_changes_rounded),
  _FeatureDemo(42, 'Yazım', 'Kelime hedefi ilerlemesi', 'Hedefi animasyonlu gösterir.', '640/1000 = %64.', Icons.linear_scale_rounded),
  _FeatureDemo(43, 'Yazım', 'Markdown yardım kartı', 'Biçimlendirme örneklerini gösterir.', '**kalın**, [[Not]], - [ ] görev.', Icons.code_rounded),
  _FeatureDemo(44, 'Yazım', 'Wiki link oluşturucu', 'Doğru wiki linki üretir.', '[[Not|Kısa Ad]].', Icons.add_link_rounded),
  _FeatureDemo(45, 'Yazım', 'Görev satırı oluşturucu', 'Metni görev satırına çevirir.', '- [ ] Kapıyı kontrol et.', Icons.add_task_rounded),
  _FeatureDemo(46, 'Yazım', 'Başlık oluşturucu', 'H1–H6 Markdown başlığı üretir.', '### Sırlar.', Icons.format_size_rounded),
  _FeatureDemo(47, 'Yazım', 'Özel alan metni oluşturucu', 'Anahtar/değer satırı üretir.', 'Durum: Aktif.', Icons.tune_rounded),
  _FeatureDemo(48, 'Yazım', 'Oturum özeti oluşturucu', 'Girdileri özet iskeletine çevirir.', 'Kararlar / Keşifler / Sonraki Adımlar.', Icons.summarize_outlined),
  _FeatureDemo(49, 'Yazım', 'Metin temizleme', 'Fazla boş satırları temizler.', '5 boş satır → 1.', Icons.cleaning_services_outlined),
  _FeatureDemo(50, 'Yazım', 'Markdown dışa kopyalama', 'Kaydı Markdown olarak kopyalar.', '# Başlık + içerik.', Icons.copy_all_outlined),
  _FeatureDemo(51, 'Oturum+', 'Geri sayım', 'Belirlenen süreden sıfıra iner.', '05:00 → 00:00.', Icons.hourglass_bottom_rounded),
  _FeatureDemo(52, 'Oturum+', 'Tur zamanlayıcı & lap', 'Kronometrede tur süreleri kaydeder.', 'Lap 1 00:42.', Icons.av_timer_outlined),
  _FeatureDemo(53, 'Oturum+', 'Yazı-tura', 'İki sonuçtan birini seçer.', 'Yazı.', Icons.toll_outlined),
  _FeatureDemo(54, 'Oturum+', 'Rastgele sayı aralığı', 'Min–max arası sayı üretir.', '3–18 → 11.', Icons.numbers_rounded),
  _FeatureDemo(55, 'Oturum+', 'Yüzdelik atış', '1–100 sonucu üretir.', '%73.', Icons.percent_rounded),
  _FeatureDemo(56, 'Oturum+', 'Sahne kuyruğu', 'Sahneleri sıraya dizer.', 'Giriş → Pazarlık → Çatışma.', Icons.queue_outlined),
  _FeatureDemo(57, 'Oturum+', 'Spotlight takipçisi', 'İsimler arasında sırayla dolaşır.', 'Sıradaki: Oyuncu B.', Icons.highlight_outlined),
  _FeatureDemo(58, 'Oturum+', 'Kaynak sayaçları', 'İsim verilen sayaçları tutar.', 'İlham Puanı 2/5.', Icons.exposure_plus_1_rounded),
  _FeatureDemo(59, 'Oturum+', 'Yorgunluk seviyesi', '0–6 arası takip eder.', 'Yorgunluk 2/6.', Icons.battery_alert_outlined),
  _FeatureDemo(60, 'Oturum+', 'İlham anahtarı', 'İlhamı açık/kapalı tutar.', 'İlham ✓.', Icons.auto_awesome_outlined),
  _FeatureDemo(61, 'Savaş+', 'Geçici HP', 'Her savaşçı için temp HP tutar.', '8 geçici HP.', Icons.favorite_rounded),
  _FeatureDemo(62, 'Savaş+', 'AC takipçisi', 'Korunma değerini gösterir.', 'AC 16.', Icons.shield_outlined),
  _FeatureDemo(63, 'Savaş+', 'Durum/condition takibi', 'Serbest durum etiketi ekler.', 'Sersemlemiş, Görünmez.', Icons.local_offer_outlined),
  _FeatureDemo(64, 'Savaş+', 'Ölüm kurtarışları', '3 başarı / 3 başarısızlık izler.', '✓✓○ / ✕○○.', Icons.heart_broken_outlined),
  _FeatureDemo(65, 'Savaş+', 'Konsantrasyon', 'Açık/kapalı konsantrasyon tutar.', 'Konsantrasyon aktif.', Icons.psychology_outlined),
  _FeatureDemo(66, 'Savaş+', 'Slot/kaynak halkaları', 'Kalan kullanım sayısını izler.', '3/4 kaldı.', Icons.radio_button_checked_rounded),
  _FeatureDemo(67, 'Savaş+', 'Hızlı hasar/iyileştirme', '1, 5, 10 puanlık işlemler.', '-5 HP.', Icons.flash_on_outlined),
  _FeatureDemo(68, 'Savaş+', 'Round notu', 'Savaş boyunca kısa not tutar.', 'Round 2: kapı kapandı.', Icons.note_alt_outlined),
  _FeatureDemo(69, 'Savaş+', 'Katılımcı özeti', 'Toplam ve düşmüş sayısını gösterir.', '6 toplam • 1 düşmüş.', Icons.groups_outlined),
  _FeatureDemo(70, 'Savaş+', 'Savaş özeti kopyalama', 'HP, AC ve notları panoya yollar.', 'Tek dokunuşla recap.', Icons.summarize_rounded),

  _FeatureDemo(71, 'Tema', 'Sistem teması',
      'Cihazın açık/koyu görünümünü otomatik takip eder.',
      'Örnek: Android karanlık moda geçince uygulama da geçer.',
      Icons.brightness_auto_rounded),
  _FeatureDemo(72, 'Tema', 'Karanlık tema',
      'Koyu Codex görünümünü kalıcı olarak zorlar.',
      'Örnek: gece masası.',
      Icons.dark_mode_rounded),
  _FeatureDemo(73, 'Tema', 'Aydınlık tema',
      'Açık çalışma yüzeyi ve aydınlık Material görünümü.',
      'Örnek: gündüz tablet kullanımı.',
      Icons.light_mode_rounded),
  _FeatureDemo(74, 'Tema', '8 renk tonu',
      'Adaçayı, menekşe, mavi, camgöbeği, zümrüt, kehribar, gül ve kızıl.',
      'Örnek: ana vurgu rengini Zümrüt yap.',
      Icons.palette_outlined),
  _FeatureDemo(75, 'Tema', 'Yazı ölçeği',
      'Uygulama yazılarını %85–130 arasında ölçekler.',
      'Örnek: tablette %110.',
      Icons.text_fields_rounded),
  _FeatureDemo(76, 'Tema', 'Hareketi azalt',
      'Atmosfer hareketini durdurur.',
      'Örnek: daha sakin çalışma modu.',
      Icons.motion_photos_off_outlined),
  _FeatureDemo(77, 'Tema', 'Animasyon hızı',
      'Animasyon tercihinin hız katsayısını saklar.',
      'Örnek: %75.',
      Icons.speed_rounded),
  _FeatureDemo(78, 'Tema', 'Atmosfer ızgarası',
      'Arka plan gridini açıp kapatır.',
      'Örnek: düz arka plan.',
      Icons.grid_on_rounded),
  _FeatureDemo(79, 'Tema', 'Izgara yoğunluğu',
      'Atmosfer çizgilerinin görünürlük şiddetini ayarlar.',
      'Örnek: %50.',
      Icons.opacity_rounded),
  _FeatureDemo(80, 'Tema', 'Yumuşak yüzey',
      'Kartlarda hafif gölge ve yumuşak ayrım.',
      'Örnek: varsayılan görünüm.',
      Icons.blur_on_rounded),
  _FeatureDemo(81, 'Tema', 'Kontrast yüzey',
      'Panel sınırlarını daha belirgin tutar.',
      'Örnek: parlak ortam.',
      Icons.contrast_rounded),
  _FeatureDemo(82, 'Tema', 'Düz yüzey',
      'Gölgesiz sade panel görünümü.',
      'Örnek: minimal tablet düzeni.',
      Icons.crop_square_rounded),
  _FeatureDemo(83, 'Üretkenlik', 'Hızlı Gelen Kutusu',
      'Uzun form açmadan Not kaydı üretir.',
      'Örnek: masada tek paragraf yakala.',
      Icons.inbox_outlined),
  _FeatureDemo(84, 'Üretkenlik', 'Bugün değişenler',
      'Bugün düzenlenen kayıtları tek listede açar.',
      'Örnek: bugünkü 6 kayıt.',
      Icons.today_rounded),
  _FeatureDemo(85, 'Üretkenlik', 'Son 7 gün',
      'Hafta içinde değişen kayıtları listeler.',
      'Örnek: hazırlık haftası.',
      Icons.date_range_rounded),
  _FeatureDemo(86, 'Üretkenlik', 'Sabit kayıt özeti',
      'Sabit kayıtları üretkenlik merkezinden açar.',
      'Örnek: masanın ana referansları.',
      Icons.push_pin_outlined),
  _FeatureDemo(87, 'Üretkenlik', 'Yer imi özeti',
      'Yer imlerini hızlı listeler.',
      'Örnek: sonra okunacak notlar.',
      Icons.bookmark_border_rounded),
  _FeatureDemo(88, 'Üretkenlik', 'Günlük not kısayolu',
      'Bugünün günlük kaydını açar veya oluşturur.',
      'Örnek: 2026-10-09.',
      Icons.calendar_today_rounded),
  _FeatureDemo(89, 'Üretkenlik', 'Panodan not yakalama',
      'Panodaki metni Gelen Kutusu kaydına dönüştürür.',
      'Örnek: webden kopyalanan kısa not.',
      Icons.content_paste_rounded),
  _FeatureDemo(90, 'Üretkenlik', 'Rastgele kayıt aç',
      'Kasadaki aktif kayıtlardan birini açar.',
      'Örnek: hızlı gözden geçirme.',
      Icons.shuffle_rounded),
  _FeatureDemo(91, 'Üretkenlik', 'Kasa özeti kopyala',
      'Kasa metriklerini panoya aktarır.',
      'Örnek: aktif kayıt/etiket/klasör sayısı.',
      Icons.copy_all_outlined),
  _FeatureDemo(92, 'Üretkenlik', 'Son kayda hızlı etiket',
      'En son düzenlenen kayda metadata etiketi ekler.',
      'Örnek: #hazır.',
      Icons.label_outline_rounded),
  _FeatureDemo(93, 'Üretkenlik', 'Son kayda hızlı klasör',
      'En son düzenlenen kaydın klasörünü değiştirir.',
      'Örnek: /Hazırlık.',
      Icons.drive_file_move_outlined),
  _FeatureDemo(94, 'Üretkenlik', 'Üretkenlik hızlı metrikleri',
      'Bugün, hafta, sabit ve yer imi sayılarını birlikte gösterir.',
      'Örnek: tek bakışta çalışma durumu.',
      Icons.dashboard_customize_outlined),
  _FeatureDemo(95, 'Analiz+', 'Görev tamamlama oranı',
      'Tamamlanan görevlerin yüzdesini hesaplar.',
      'Örnek: %72.',
      Icons.task_alt_rounded),
  _FeatureDemo(96, 'Analiz+', 'Bağlantı sağlık oranı',
      'Çözülen/kırık bağlantılardan oran üretir.',
      'Örnek: %94.',
      Icons.link_rounded),
  _FeatureDemo(97, 'Analiz+', 'Toplam geri bağlantı',
      'Kasadaki çözülen geri bağlantıları toplar.',
      'Örnek: 84 geri bağlantı.',
      Icons.keyboard_return_rounded),
  _FeatureDemo(98, 'Analiz+', 'Tür dağılımı',
      'Kayıt türlerini animasyonlu oran çubuklarında gösterir.',
      'Örnek: NPC 14, Mekân 9.',
      Icons.category_outlined),
  _FeatureDemo(99, 'Analiz+', 'Klasör dağılımı',
      'Kayıtların klasörlere dağılımını gösterir.',
      'Örnek: /Dünya 18.',
      Icons.folder_outlined),
  _FeatureDemo(100, 'Analiz+', 'Etiket frekansı',
      'En sık kullanılan etiketleri sayar.',
      'Örnek: #hazır 12.',
      Icons.local_offer_outlined),
  _FeatureDemo(101, 'Analiz+', 'En uzun kayıtlar',
      'Kelime sayısına göre kayıt sıralaması.',
      'Örnek: 2.430 kelimelik not.',
      Icons.subject_rounded),
  _FeatureDemo(102, 'Analiz+', 'En yeni kayıtlar',
      'Oluşturma tarihine göre en yenileri gösterir.',
      'Örnek: bugün açılan kayıtlar.',
      Icons.fiber_new_rounded),
  _FeatureDemo(103, 'Analiz+', 'En bağlantılı kayıtlar',
      'Giden+geri ilişkisi en yüksek kayıtları sıralar.',
      'Örnek: 18 ilişkili kayıt.',
      Icons.hub_outlined),
  _FeatureDemo(104, 'Hızlı İşlem+', 'Başlık dönüştürme',
      'Büyük, küçük ve Baş Harf biçimine dönüştürür.',
      'Örnek: KAYIP TAPINAK → Kayıp Tapınak.',
      Icons.text_format_rounded),
  _FeatureDemo(105, 'Hızlı İşlem+', 'Bul & değiştir',
      'Seçili kaydın metninde tüm eşleşmeleri değiştirir.',
      'Örnek: eski terimi yeni terimle değiştir.',
      Icons.find_replace_rounded),
  _FeatureDemo(106, 'Hızlı İşlem+', 'Metin damgaları & alias',
      'Başa/sona metin, tarih, saat, ayraç, görev ve alias ekler.',
      'Örnek: 14:30 saat damgası.',
      Icons.post_add_rounded),
];

class CodexFeatureShowcasePage extends StatefulWidget {
  const CodexFeatureShowcasePage({super.key});

  @override
  State<CodexFeatureShowcasePage> createState() =>
      _CodexFeatureShowcasePageState();
}

class _CodexFeatureShowcasePageState
    extends State<CodexFeatureShowcasePage> {
  String query = '';
  String category = 'Tümü';

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      'Tümü',
      ..._featureDemos.map((e) => e.category),
    }.toList();

    final q = query.trim().toLowerCase();
    final visible = _featureDemos.where((feature) {
      final categoryMatches =
          category == 'Tümü' || feature.category == category;
      final searchMatches = q.isEmpty ||
          '${feature.title} ${feature.detail} ${feature.example}'
              .toLowerCase()
              .contains(q);
      return categoryMatches && searchMatches;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Örnekler Laboratuvarı'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${visible.length}/106',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _CodexPageBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (value) =>
                    setState(() => query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: '106 özellik içinde ara...',
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final item in categories) ...[
                    ChoiceChip(
                      label: Text(item),
                      selected: category == item,
                      onSelected: (_) =>
                          setState(() => category = item),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                itemCount: visible.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final feature = visible[index];
                  return _CodexEntrance(
                    index: index,
                    child: _FeatureDemoCard(
                      feature: feature,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureDemoCard extends StatefulWidget {
  final _FeatureDemo feature;

  const _FeatureDemoCard({
    required this.feature,
  });

  @override
  State<_FeatureDemoCard> createState() =>
      _FeatureDemoCardState();
}

class _FeatureDemoCardState extends State<_FeatureDemoCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final feature = widget.feature;

    return Material(
      color: AppColors.panel.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => setState(() => expanded = !expanded),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: expanded
                  ? AppColors.purple.withValues(alpha: .65)
                  : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      feature.icon,
                      color: AppColors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${feature.number}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          feature.category,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 2),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg.withValues(alpha: .34),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.detail,
                          style: const TextStyle(
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          feature.example,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CodexVaultInsightsPage extends StatefulWidget {
  const CodexVaultInsightsPage({super.key});

  @override
  State<CodexVaultInsightsPage> createState() =>
      _CodexVaultInsightsPageState();
}

class _CodexVaultInsightsPageState
    extends State<CodexVaultInsightsPage> {
  int staleDays = 30;
  int longWordThreshold = 1200;

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.notes.where((n) => !n.archived).toList();
    final now = DateTime.now();

    final untitled = notes.where((n) => n.title.trim().isEmpty).toList();
    final empty = notes.where((n) {
      final props = n.properties.entries.where(
        (e) => e.key != 'folder' && e.key != 'tags',
      );
      return n.content.trim().isEmpty &&
          props.every((e) => e.value.trim().isEmpty);
    }).toList();

    final byTitle = <String, List<NoteRecord>>{};
    for (final note in notes) {
      final key = note.title.trim().toLowerCase();
      if (key.isEmpty) continue;
      byTitle.putIfAbsent(key, () => []).add(note);
    }
    final duplicateGroups = byTitle.values
        .where((group) => group.length > 1)
        .toList();

    final stale = notes.where((n) {
      return now.difference(n.updatedAt).inDays >= staleDays;
    }).toList();

    int wordsFor(NoteRecord note) => note.content
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .length;

    final longNotes = notes
        .where((n) => wordsFor(n) >= longWordThreshold)
        .toList();
    final recent = notes.where((n) {
      return now.difference(n.updatedAt).inHours <= 24;
    }).toList();

    final totalWords = notes.fold<int>(
      0,
      (sum, n) => sum + wordsFor(n),
    );
    final totalReadingMinutes = math.max(1, (totalWords / 200).ceil()).toInt();
    final bytes = utf8.encode(store.exportVaultJson()).length;

    final broken = notes.fold<int>(
      0,
      (sum, n) => sum + store.unresolvedLinks(n).length,
    );
    final orphans = notes.where((n) =>
        store.backlinksFor(n).isEmpty &&
        store.outgoingResolved(n).isEmpty).length;

    final deductions = math.min(
      100,
      untitled.length * 4 +
          empty.length * 5 +
          duplicateGroups.length * 5 +
          broken * 3 +
          orphans * 2,
    ).toInt();
    final health = math.max(0, 100 - deductions).toInt();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Kasa Analizi')),
      body: _CodexPageBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InsightHealthCard(
              score: health,
              noteCount: notes.length,
              words: totalWords,
              readingMinutes: totalReadingMinutes,
              bytes: bytes,
            ),
            const SizedBox(height: 12),
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.tune_rounded,
                    title: 'Analiz Eşikleri',
                    subtitle: 'Eski ve uzun kayıt sınırlarını değiştir.',
                  ),
                  const SizedBox(height: 10),
                  Text('Eski kayıt: $staleDays gün'),
                  Slider(
                    value: staleDays.toDouble(),
                    min: 7,
                    max: 180,
                    divisions: 173,
                    onChanged: (value) =>
                        setState(() => staleDays = value.round()),
                  ),
                  Text('Uzun kayıt: $longWordThreshold kelime'),
                  Slider(
                    value: longWordThreshold.toDouble(),
                    min: 300,
                    max: 3000,
                    divisions: 27,
                    onChanged: (value) => setState(
                      () => longWordThreshold = value.round(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _InsightListSection(
              icon: Icons.title_rounded,
              title: 'Başlıksız Kayıtlar',
              detail: '${untitled.length} kayıt',
              notes: untitled,
            ),
            const SizedBox(height: 10),
            _InsightListSection(
              icon: Icons.hourglass_empty_rounded,
              title: 'Boş Kayıtlar',
              detail: '${empty.length} kayıt',
              notes: empty,
            ),
            const SizedBox(height: 10),
            _DuplicateTitleSection(groups: duplicateGroups),
            const SizedBox(height: 10),
            _InsightListSection(
              icon: Icons.history_toggle_off_rounded,
              title: 'Eski Kayıtlar',
              detail: '$staleDays+ gün • ${stale.length} kayıt',
              notes: stale,
            ),
            const SizedBox(height: 10),
            _InsightListSection(
              icon: Icons.subject_rounded,
              title: 'Uzun Kayıtlar',
              detail: '$longWordThreshold+ kelime • ${longNotes.length} kayıt',
              notes: longNotes,
            ),
            const SizedBox(height: 10),
            _InsightListSection(
              icon: Icons.today_outlined,
              title: 'Son 24 Saat',
              detail: '${recent.length} kayıt',
              notes: recent,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightHealthCard extends StatelessWidget {
  final int score;
  final int noteCount;
  final int words;
  final int readingMinutes;
  final int bytes;

  const _InsightHealthCard({
    required this.score,
    required this.noteCount,
    required this.words,
    required this.readingMinutes,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    final kb = bytes / 1024;
    return _CodexPanel(
      child: Column(
        children: [
          const _CodexPanelTitle(
            icon: Icons.monitor_heart_outlined,
            title: 'Kasa Sağlık Puanı',
            subtitle: 'Başlık, içerik ve bağlantı bütünlüğünden hesaplanır.',
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) {
              return Column(
                children: [
                  Text(
                    '${(value * 100).round()}/100',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 9,
                      value: value,
                      backgroundColor: AppColors.panel2,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _CodexStatChip(label: 'Kayıt', value: '$noteCount'),
              _CodexStatChip(label: 'Kelime', value: '$words'),
              _CodexStatChip(label: 'Okuma', value: '$readingMinutes dk'),
              _CodexStatChip(
                label: 'Yaklaşık boyut',
                value: '${kb.toStringAsFixed(1)} KB',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightListSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final List<NoteRecord> notes;

  const _InsightListSection({
    required this.icon,
    required this.title,
    required this.detail,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return _CodexPanel(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.purple),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          detail,
          style: const TextStyle(color: AppColors.muted),
        ),
        children: [
          if (notes.isEmpty)
            const _CodexEmptyLine(
              icon: Icons.check_circle_outline_rounded,
              text: 'Bu kategoride kayıt yok.',
            )
          else
            for (final note in notes.take(50))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _codexTypeIcon(note.type),
                  color: _codexTypeColor(note.type),
                ),
                title: Text(
                  note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                ),
                subtitle: Text(
                  _formatDate(note.updatedAt),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9.5,
                  ),
                ),
                onTap: () => _openCodexRecord(context, note),
              ),
        ],
      ),
    );
  }
}

class _DuplicateTitleSection extends StatelessWidget {
  final List<List<NoteRecord>> groups;

  const _DuplicateTitleSection({required this.groups});

  @override
  Widget build(BuildContext context) {
    return _CodexPanel(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: const Icon(
          Icons.content_copy_rounded,
          color: AppColors.purple,
        ),
        title: const Text(
          'Tekrarlanan Başlıklar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${groups.length} başlık grubu',
          style: const TextStyle(color: AppColors.muted),
        ),
        children: [
          if (groups.isEmpty)
            const _CodexEmptyLine(
              icon: Icons.check_circle_outline_rounded,
              text: 'Tekrarlanan başlık yok.',
            )
          else
            for (final group in groups)
              ExpansionTile(
                dense: true,
                title: Text(
                  group.first.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${group.length} kayıt'),
                children: [
                  for (final note in group)
                    ListTile(
                      dense: true,
                      title: Text(_formatDate(note.updatedAt)),
                      onTap: () => _openCodexRecord(context, note),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

class CodexBulkActionsPage extends StatefulWidget {
  const CodexBulkActionsPage({super.key});

  @override
  State<CodexBulkActionsPage> createState() =>
      _CodexBulkActionsPageState();
}

class _CodexBulkActionsPageState
    extends State<CodexBulkActionsPage> {
  final Set<String> selected = {};
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final q = query.trim().toLowerCase();
    final notes = store.notes
        .where((n) => !n.archived)
        .where((n) {
          if (q.isEmpty) return true;
          return '${n.title} ${n.content}'.toLowerCase().contains(q);
        })
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Toplu İşlemler (${selected.length})'),
        actions: [
          TextButton(
            onPressed: notes.isEmpty
                ? null
                : () {
                    setState(() {
                      if (selected.length == notes.length) {
                        selected.clear();
                      } else {
                        selected
                          ..clear()
                          ..addAll(notes.map((e) => e.id));
                      }
                    });
                  },
            child: Text(
              selected.length == notes.length ? 'Temizle' : 'Tümünü seç',
            ),
          ),
        ],
      ),
      body: _CodexPageBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Kayıt ara...',
                ),
              ),
            ),
            if (selected.isNotEmpty)
              SizedBox(
                height: 50,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.push_pin_outlined, size: 16),
                      label: const Text('Sabitle'),
                      onPressed: () => _bulkFlag(context, 'pin'),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.bookmark_add_outlined, size: 16),
                      label: const Text('Yer İmi'),
                      onPressed: () => _bulkFlag(context, 'bookmark'),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.drive_file_move_outlined, size: 16),
                      label: const Text('Klasöre Taşı'),
                      onPressed: () => _bulkTextDialog(context, 'folder'),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.new_label_outlined, size: 16),
                      label: const Text('Etiket Ekle'),
                      onPressed: () => _bulkTextDialog(context, 'add_tag'),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.label_off_outlined, size: 16),
                      label: const Text('Etiket Kaldır'),
                      onPressed: () => _bulkTextDialog(context, 'remove_tag'),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.flag_outlined, size: 16),
                      label: const Text('Durum'),
                      onPressed: () => _bulkTextDialog(context, 'status'),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.priority_high_rounded, size: 16),
                      label: const Text('Öncelik'),
                      onPressed: () => _bulkTextDialog(context, 'priority'),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Görünürlük'),
                      onPressed: () => _bulkVisibility(context),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.archive_outlined, size: 16),
                      label: const Text('Arşivle'),
                      onPressed: () => _bulkFlag(context, 'archive'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                itemCount: notes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final checked = selected.contains(note.id);
                  return Material(
                    color: checked
                        ? AppColors.purple.withValues(alpha: .09)
                        : AppColors.panel,
                    borderRadius: BorderRadius.circular(14),
                    child: CheckboxListTile(
                      value: checked,
                      onChanged: (_) {
                        setState(() {
                          if (checked) {
                            selected.remove(note.id);
                          } else {
                            selected.add(note.id);
                          }
                        });
                      },
                      secondary: Icon(
                        _codexTypeIcon(note.type),
                        color: _codexTypeColor(note.type),
                      ),
                      title: Text(
                        note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                      ),
                      subtitle: Text(
                        note.type.label,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<NoteRecord> _selectedNotes(VaultStore store) {
    return store.notes.where((n) => selected.contains(n.id)).toList();
  }

  void _bulkFlag(BuildContext context, String action) {
    final store = VaultScope.of(context);
    final notes = _selectedNotes(store);
    if (notes.isEmpty) return;

    setState(() {
      for (final note in notes) {
        if (action == 'pin') note.pinned = true;
        if (action == 'bookmark') note.bookmarked = true;
        if (action == 'archive') note.archived = true;
        note.updatedAt = DateTime.now();
      }
      selected.clear();
    });
    store.commitBulkChanges();
  }

  Future<void> _bulkTextDialog(
    BuildContext context,
    String action,
  ) async {
    final controller = TextEditingController();
    String label = 'Değer';
    if (action == 'folder') label = 'Klasör';
    if (action == 'add_tag') label = 'Eklenecek etiket';
    if (action == 'remove_tag') label = 'Kaldırılacak etiket';
    if (action == 'status') label = 'Durum';
    if (action == 'priority') label = 'Öncelik';

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: action == 'folder' ? '/Klasör/Alt Klasör' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (value == null || value.trim().isEmpty) return;
    final store = VaultScope.of(context);
    final notes = _selectedNotes(store);

    setState(() {
      for (final note in notes) {
        if (action == 'folder') {
          note.properties['folder'] = value.startsWith('/') ? value : '/$value';
          note.propertyTypes['folder'] = 'text';
        } else if (action == 'status') {
          note.properties['status'] = value;
          note.propertyTypes['status'] = 'text';
        } else if (action == 'priority') {
          note.properties['priority'] = value;
          note.propertyTypes['priority'] = 'text';
        } else {
          final tags = (note.properties['tags'] ?? '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          final clean = value.startsWith('#') ? value.substring(1) : value;
          if (action == 'add_tag') {
            final exists = tags.any(
              (e) => e.replaceFirst('#', '').toLowerCase() == clean.toLowerCase(),
            );
            if (!exists) tags.add(clean);
          } else if (action == 'remove_tag') {
            tags.removeWhere(
              (e) => e.replaceFirst('#', '').toLowerCase() == clean.toLowerCase(),
            );
          }

          if (tags.isEmpty) {
            note.properties.remove('tags');
            note.propertyTypes.remove('tags');
          } else {
            note.properties['tags'] = tags.join(', ');
            note.propertyTypes['tags'] = 'tags';
          }
        }
        note.updatedAt = DateTime.now();
      }
    });
    store.commitBulkChanges();
  }

  Future<void> _bulkVisibility(BuildContext context) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in const ['Sadece Ben', 'DM', 'Oyuncular'])
              ListTile(
                title: Text(item),
                onTap: () => Navigator.pop(sheetContext, item),
              ),
          ],
        ),
      ),
    );

    if (value == null) return;
    final store = VaultScope.of(context);
    final notes = _selectedNotes(store);
    setState(() {
      for (final note in notes) {
        note.visibility = value;
        note.updatedAt = DateTime.now();
      }
    });
    store.commitBulkChanges();
  }
}

class CodexWritingLabPage extends StatefulWidget {
  const CodexWritingLabPage({super.key});

  @override
  State<CodexWritingLabPage> createState() =>
      _CodexWritingLabPageState();
}

class _CodexWritingLabPageState
    extends State<CodexWritingLabPage> {
  String? selectedId;
  final TextEditingController _goal = TextEditingController();
  final TextEditingController _linkTitle = TextEditingController();
  final TextEditingController _linkAlias = TextEditingController();
  final TextEditingController _task = TextEditingController();
  final TextEditingController _heading = TextEditingController();
  final TextEditingController _propertyKey = TextEditingController();
  final TextEditingController _propertyValue = TextEditingController();
  final TextEditingController _recapDecisions = TextEditingController();
  final TextEditingController _recapDiscoveries = TextEditingController();
  final TextEditingController _recapNext = TextEditingController();

  int headingLevel = 2;
  String? generated;

  @override
  void dispose() {
    _goal.dispose();
    _linkTitle.dispose();
    _linkAlias.dispose();
    _task.dispose();
    _heading.dispose();
    _propertyKey.dispose();
    _propertyValue.dispose();
    _recapDecisions.dispose();
    _recapDiscoveries.dispose();
    _recapNext.dispose();
    super.dispose();
  }

  NoteRecord? _findNote(List<NoteRecord> notes, String? id) {
    if (id == null) return null;
    for (final note in notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.notes.where((n) => !n.archived).toList();
    final selected = _findNote(notes, selectedId);

    final words = selected == null
        ? 0
        : selected.content
            .trim()
            .split(RegExp(r'\s+'))
            .where((e) => e.isNotEmpty)
            .length;
    final goal = selected == null
        ? 0
        : int.tryParse(selected.properties['wordGoal'] ?? '') ?? 0;
    final progress = goal <= 0
        ? 0.0
        : (words / goal).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Yazım Laboratuvarı')),
      body: _CodexPageBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.description_outlined,
                    title: 'Aktif Kayıt',
                    subtitle: 'Kelime hedefi ve metin araçları bu kayda uygulanır.',
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedId,
                    decoration: const InputDecoration(
                      labelText: 'Kayıt seç',
                    ),
                    items: [
                      for (final note in notes)
                        DropdownMenuItem(
                          value: note.id,
                          child: Text(
                            note.title.trim().isEmpty ? 'Başlıksız' : note.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedId = value;
                        final note = _findNote(notes, value);
                        _goal.text = note?.properties['wordGoal'] ?? '';
                      });
                    },
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _goal,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Kelime hedefi',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final value = int.tryParse(_goal.text.trim());
                            if (value == null || value <= 0) {
                              selected.properties.remove('wordGoal');
                              selected.propertyTypes.remove('wordGoal');
                            } else {
                              selected.properties['wordGoal'] = '$value';
                              selected.propertyTypes['wordGoal'] = 'number';
                            }
                            selected.updatedAt = DateTime.now();
                            store.commitBulkChanges();
                            setState(() {});
                          },
                          child: const Text('Kaydet'),
                        ),
                      ],
                    ),
                    if (goal > 0) ...[
                      const SizedBox(height: 10),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 650),
                        builder: (_, value, __) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '$words / $goal kelime • %${(value * 100).round()}',
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: value,
                                  backgroundColor: AppColors.panel2,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _cleanSelectedText(store, selected),
                            icon: const Icon(Icons.cleaning_services_outlined),
                            label: const Text('Metni temizle'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final title = selected.title.trim().isEmpty
                                  ? 'Başlıksız'
                                  : selected.title.trim();
                              Clipboard.setData(
                                ClipboardData(
                                  text: '# $title\n\n${selected.content}',
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_all_outlined),
                            label: const Text('Markdown kopyala'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.code_rounded,
                    title: 'Markdown Hızlı Yardım',
                    subtitle: 'Uygulamadaki biçimlendirme işaretleri.',
                  ),
                  const SizedBox(height: 10),
                  const SelectableText(
                    '# Başlık\n'
                    '## Alt Başlık\n'
                    '**kalın**  *italik*  ~~üstü çizili~~\n'
                    '`kod`  > alıntı\n'
                    '- [ ] görev\n'
                    '[[Not]]  [[Not|Görünen Ad]]\n'
                    '#etiket  ^blok',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.gold,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.build_outlined,
                    title: 'Satır Oluşturucular',
                    subtitle: 'Wiki link, görev, başlık ve özel alan metni üret.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _linkTitle,
                    decoration: const InputDecoration(labelText: 'Wiki link hedefi'),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _linkAlias,
                    decoration: const InputDecoration(labelText: 'Görünen ad (opsiyonel)'),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _task,
                    decoration: const InputDecoration(labelText: 'Görev metni'),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heading,
                          decoration: const InputDecoration(labelText: 'Başlık metni'),
                        ),
                      ),
                      const SizedBox(width: 7),
                      DropdownButton<int>(
                        value: headingLevel,
                        items: [
                          for (var i = 1; i <= 6; i++)
                            DropdownMenuItem(value: i, child: Text('H$i')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => headingLevel = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _propertyKey,
                          decoration: const InputDecoration(labelText: 'Alan adı'),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: TextField(
                          controller: _propertyValue,
                          decoration: const InputDecoration(labelText: 'Alan değeri'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('Wiki Link'),
                        onPressed: () {
                          final title = _linkTitle.text.trim();
                          if (title.isEmpty) return;
                          final alias = _linkAlias.text.trim();
                          _showGenerated(
                            alias.isEmpty ? '[[$title]]' : '[[$title|$alias]]',
                          );
                        },
                      ),
                      ActionChip(
                        label: const Text('Görev'),
                        onPressed: () {
                          final value = _task.text.trim();
                          if (value.isEmpty) return;
                          _showGenerated('- [ ] $value');
                        },
                      ),
                      ActionChip(
                        label: const Text('Başlık'),
                        onPressed: () {
                          final value = _heading.text.trim();
                          if (value.isEmpty) return;
                          final prefix = List.filled(headingLevel, '#').join();
                          _showGenerated('$prefix $value');
                        },
                      ),
                      ActionChip(
                        label: const Text('Özel Alan'),
                        onPressed: () {
                          final key = _propertyKey.text.trim();
                          final value = _propertyValue.text.trim();
                          if (key.isEmpty) return;
                          _showGenerated('$key: $value');
                        },
                      ),
                    ],
                  ),
                  if (generated != null) ...[
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        key: ValueKey(generated),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.bg.withValues(alpha: .32),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                generated!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Kopyala',
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: generated!),
                              ),
                              icon: const Icon(Icons.copy_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.summarize_outlined,
                    title: 'Oturum Özeti Oluşturucu',
                    subtitle: 'Hazır hikâye üretmez; senin girdilerini iskelete çevirir.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _recapDecisions,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Kararlar'),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _recapDiscoveries,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Keşifler'),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _recapNext,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Sonraki adımlar'),
                  ),
                  const SizedBox(height: 9),
                  FilledButton.icon(
                    onPressed: () {
                      final result =
                          '## Kararlar\n${_recapDecisions.text.trim()}\n\n'
                          '## Keşifler\n${_recapDiscoveries.text.trim()}\n\n'
                          '## Sonraki Adımlar\n${_recapNext.text.trim()}';
                      _showGenerated(result);
                    },
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    label: const Text('Özet iskeletini oluştur'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenerated(String value) {
    setState(() => generated = value);
  }

  void _cleanSelectedText(VaultStore store, NoteRecord note) {
    final lines = note.content
        .split('\n')
        .map((e) => e.trimRight())
        .toList();
    final cleaned = <String>[];
    var blank = false;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        if (!blank) cleaned.add('');
        blank = true;
      } else {
        cleaned.add(line);
        blank = false;
      }
    }
    note.content = cleaned.join('\n').trim();
    note.updatedAt = DateTime.now();
    store.commitBulkChanges();
    setState(() {});
  }
}

class CodexSessionUtilityPage extends StatefulWidget {
  const CodexSessionUtilityPage({super.key});

  @override
  State<CodexSessionUtilityPage> createState() =>
      _CodexSessionUtilityPageState();
}

class _CodexSessionUtilityPageState
    extends State<CodexSessionUtilityPage> {
  Timer? countdownTimer;
  int countdownSeconds = 300;
  int countdownInitial = 300;
  bool countdownRunning = false;

  Timer? stopwatchTimer;
  int stopwatchSeconds = 0;
  bool stopwatchRunning = false;
  final List<int> laps = [];

  final math.Random random = math.Random();
  String? coin;
  int minRandom = 1;
  int maxRandom = 20;
  int? randomResult;
  int? percentResult;

  final TextEditingController sceneController = TextEditingController();
  final List<String> scenes = [];

  final TextEditingController spotlightController = TextEditingController();
  final List<String> spotlight = [];
  int spotlightIndex = 0;

  final TextEditingController resourceName = TextEditingController();
  final List<_CodexNamedCounter> resources = [];

  int exhaustion = 0;
  bool inspiration = false;

  @override
  void dispose() {
    countdownTimer?.cancel();
    stopwatchTimer?.cancel();
    sceneController.dispose();
    spotlightController.dispose();
    resourceName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Oturum Yardımcıları')),
      body: _CodexPageBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _countdownCard(),
            const SizedBox(height: 12),
            _stopwatchCard(),
            const SizedBox(height: 12),
            _randomCard(),
            const SizedBox(height: 12),
            _sceneCard(),
            const SizedBox(height: 12),
            _spotlightCard(),
            const SizedBox(height: 12),
            _resourceCard(),
            const SizedBox(height: 12),
            _conditionCard(),
          ],
        ),
      ),
    );
  }

  Widget _countdownCard() {
    final m = (countdownSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (countdownSeconds % 60).toString().padLeft(2, '0');
    final progress = countdownInitial <= 0
        ? 0.0
        : countdownSeconds / countdownInitial;

    return _CodexPanel(
      child: Column(
        children: [
          const _CodexPanelTitle(
            icon: Icons.hourglass_bottom_rounded,
            title: 'Geri Sayım',
            subtitle: 'Masa içi süre baskısı ve mola takibi.',
          ),
          const SizedBox(height: 13),
          AnimatedScale(
            scale: countdownRunning ? 1.04 : 1,
            duration: const Duration(milliseconds: 400),
            child: Text(
              '$m:$s',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0.0, 1.0).toDouble(),
              backgroundColor: AppColors.panel2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final seconds in const [60, 180, 300, 600])
                ActionChip(
                  label: Text('${seconds ~/ 60} dk'),
                  onPressed: () {
                    countdownTimer?.cancel();
                    setState(() {
                      countdownInitial = seconds;
                      countdownSeconds = seconds;
                      countdownRunning = false;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggleCountdown,
                  icon: Icon(
                    countdownRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(countdownRunning ? 'Duraklat' : 'Başlat'),
                ),
              ),
              const SizedBox(width: 7),
              OutlinedButton(
                onPressed: () {
                  countdownTimer?.cancel();
                  setState(() {
                    countdownSeconds = countdownInitial;
                    countdownRunning = false;
                  });
                },
                child: const Text('Sıfırla'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleCountdown() {
    if (countdownRunning) {
      countdownTimer?.cancel();
      setState(() => countdownRunning = false);
      return;
    }
    if (countdownSeconds <= 0) {
      setState(() => countdownSeconds = countdownInitial);
    }
    setState(() => countdownRunning = true);
    countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        if (countdownSeconds <= 1) {
          countdownTimer?.cancel();
          setState(() {
            countdownSeconds = 0;
            countdownRunning = false;
          });
          return;
        }
        setState(() => countdownSeconds--);
      },
    );
  }

  Widget _stopwatchCard() {
    final m = (stopwatchSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (stopwatchSeconds % 60).toString().padLeft(2, '0');

    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.av_timer_outlined,
            title: 'Tur Zamanlayıcı',
            subtitle: 'Kronometre ve lap/tur kayıtları.',
          ),
          const SizedBox(height: 13),
          Text(
            '$m:$s',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _toggleStopwatch,
                  child: Text(stopwatchRunning ? 'Duraklat' : 'Başlat'),
                ),
              ),
              const SizedBox(width: 7),
              OutlinedButton(
                onPressed: stopwatchSeconds == 0
                    ? null
                    : () => setState(() => laps.insert(0, stopwatchSeconds)),
                child: const Text('Lap'),
              ),
              const SizedBox(width: 7),
              OutlinedButton(
                onPressed: () {
                  stopwatchTimer?.cancel();
                  setState(() {
                    stopwatchRunning = false;
                    stopwatchSeconds = 0;
                    laps.clear();
                  });
                },
                child: const Text('Sıfırla'),
              ),
            ],
          ),
          if (laps.isNotEmpty) ...[
            const SizedBox(height: 9),
            for (var i = 0; i < laps.length; i++)
              Text(
                'Lap ${laps.length - i}: '
                '${(laps[i] ~/ 60).toString().padLeft(2, '0')}:'
                '${(laps[i] % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _toggleStopwatch() {
    if (stopwatchRunning) {
      stopwatchTimer?.cancel();
      setState(() => stopwatchRunning = false);
      return;
    }
    setState(() => stopwatchRunning = true);
    stopwatchTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() => stopwatchSeconds++);
      },
    );
  }

  Widget _randomCard() {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.casino_outlined,
            title: 'Hızlı Rastgele',
            subtitle: 'Yazı-tura, sayı aralığı ve yüzdelik atış.',
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() => coin = random.nextBool() ? 'Yazı' : 'Tura');
                  },
                  icon: const Icon(Icons.toll_outlined),
                  label: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      coin ?? 'Yazı-Tura',
                      key: ValueKey(coin),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => percentResult = random.nextInt(100) + 1);
                  },
                  icon: const Icon(Icons.percent_rounded),
                  label: Text(
                    percentResult == null ? 'd100' : '%$percentResult',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _CodexStepper(
                  label: 'Min',
                  value: minRandom,
                  min: -999,
                  max: maxRandom,
                  onChanged: (value) => setState(() => minRandom = value),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _CodexStepper(
                  label: 'Max',
                  value: maxRandom,
                  min: minRandom,
                  max: 999,
                  onChanged: (value) => setState(() => maxRandom = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          OutlinedButton.icon(
            onPressed: () {
              final range = maxRandom - minRandom + 1;
              if (range <= 0) return;
              setState(() {
                randomResult = minRandom + random.nextInt(range);
              });
            },
            icon: const Icon(Icons.numbers_rounded),
            label: Text(
              randomResult == null ? 'Aralıktan seç' : 'Sonuç: $randomResult',
            ),
          ),
        ],
      ),
    );
  }

  Widget _sceneCard() {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.queue_outlined,
            title: 'Sahne Kuyruğu',
            subtitle: 'Masadaki sıradaki sahneleri düzenle.',
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sceneController,
                  decoration: const InputDecoration(hintText: 'Sahne adı'),
                ),
              ),
              const SizedBox(width: 7),
              FilledButton(
                onPressed: () {
                  final value = sceneController.text.trim();
                  if (value.isEmpty) return;
                  setState(() {
                    scenes.add(value);
                    sceneController.clear();
                  });
                },
                child: const Text('Ekle'),
              ),
            ],
          ),
          if (scenes.isNotEmpty) ...[
            const SizedBox(height: 9),
            for (var i = 0; i < scenes.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 13, child: Text('${i + 1}')),
                title: Text(scenes[i]),
                trailing: IconButton(
                  onPressed: () => setState(() => scenes.removeAt(i)),
                  icon: const Icon(Icons.check_rounded),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _spotlightCard() {
    final active = spotlight.isEmpty
        ? null
        : spotlight[spotlightIndex.clamp(0, spotlight.length - 1).toInt()];

    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CodexPanelTitle(
            icon: Icons.highlight_outlined,
            title: 'Spotlight Takibi',
            subtitle: active == null
                ? 'İsimleri ekle ve sırayla ilerle.'
                : 'Şimdi: $active',
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: spotlightController,
                  decoration: const InputDecoration(hintText: 'İsim'),
                ),
              ),
              const SizedBox(width: 7),
              FilledButton(
                onPressed: () {
                  final value = spotlightController.text.trim();
                  if (value.isEmpty) return;
                  setState(() {
                    spotlight.add(value);
                    spotlightController.clear();
                  });
                },
                child: const Text('Ekle'),
              ),
            ],
          ),
          if (spotlight.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < spotlight.length; i++)
                  Chip(
                    label: Text(spotlight[i]),
                    backgroundColor: i == spotlightIndex
                        ? AppColors.purple.withValues(alpha: .14)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  spotlightIndex = (spotlightIndex + 1) % spotlight.length;
                });
              },
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Sıradaki'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resourceCard() {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.exposure_plus_1_rounded,
            title: 'Kaynak Sayaçları',
            subtitle: 'Adını sen koy; artı/eksi ile değer değiştir.',
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: resourceName,
                  decoration: const InputDecoration(hintText: 'Kaynak adı'),
                ),
              ),
              const SizedBox(width: 7),
              FilledButton(
                onPressed: () {
                  final value = resourceName.text.trim();
                  if (value.isEmpty) return;
                  setState(() {
                    resources.add(
                      _CodexNamedCounter(name: value, value: 0, max: 5),
                    );
                    resourceName.clear();
                  });
                },
                child: const Text('Ekle'),
              ),
            ],
          ),
          if (resources.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < resources.length; i++)
              _CodexCounterRow(
                counter: resources[i],
                onMinus: () => setState(() {
                  resources[i].value =
                      math.max(0, resources[i].value - 1).toInt();
                }),
                onPlus: () => setState(() {
                  resources[i].value = math.min(
                    resources[i].max,
                    resources[i].value + 1,
                  ).toInt();
                }),
                onDelete: () => setState(() => resources.removeAt(i)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _conditionCard() {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.battery_alert_outlined,
            title: 'Yorgunluk & İlham',
            subtitle: 'İki masa durumunu hızlı tut.',
          ),
          const SizedBox(height: 10),
          _CodexStepper(
            label: 'Yorgunluk',
            value: exhaustion,
            min: 0,
            max: 6,
            onChanged: (value) => setState(() => exhaustion = value),
          ),
          const SizedBox(height: 7),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: inspiration,
            title: const Text('İlham'),
            subtitle: Text(inspiration ? 'Aktif' : 'Pasif'),
            onChanged: (value) => setState(() => inspiration = value),
          ),
        ],
      ),
    );
  }
}

class _CodexNamedCounter {
  String name;
  int value;
  int max;

  _CodexNamedCounter({
    required this.name,
    required this.value,
    required this.max,
  });
}

class _CodexCounterRow extends StatelessWidget {
  final _CodexNamedCounter counter;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onDelete;

  const _CodexCounterRow({
    required this.counter,
    required this.onMinus,
    required this.onPlus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: .30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              counter.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(
            '${counter.value}/${counter.max}',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class CodexCombatBoardPage extends StatefulWidget {
  const CodexCombatBoardPage({super.key});

  @override
  State<CodexCombatBoardPage> createState() =>
      _CodexCombatBoardPageState();
}

class _CodexCombatBoardPageState
    extends State<CodexCombatBoardPage> {
  final TextEditingController name = TextEditingController();
  final TextEditingController hp = TextEditingController();
  final TextEditingController maxHp = TextEditingController();
  final TextEditingController tempHp = TextEditingController();
  final TextEditingController ac = TextEditingController();
  final TextEditingController roundNotes = TextEditingController();

  final List<_CodexCombatantPlus> combatants = [];
  int round = 1;

  @override
  void dispose() {
    name.dispose();
    hp.dispose();
    maxHp.dispose();
    tempHp.dispose();
    ac.dispose();
    roundNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final down = combatants.where((c) => c.hp <= 0).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Savaş Paneli+'),
        actions: [
          IconButton(
            tooltip: 'Savaş özetini kopyala',
            onPressed: combatants.isEmpty ? null : _copyCombatSummary,
            icon: const Icon(Icons.summarize_rounded),
          ),
        ],
      ),
      body: _CodexPageBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CodexPanelTitle(
                    icon: Icons.groups_outlined,
                    title: 'Savaş Özeti',
                    subtitle:
                        '${combatants.length} toplam • $down düşmüş • Round $round',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => setState(() => round++),
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Sonraki Round'),
                        ),
                      ),
                      const SizedBox(width: 7),
                      OutlinedButton(
                        onPressed: () => setState(() => round = 1),
                        child: const Text('Round 1'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.person_add_alt_rounded,
                    title: 'Katılımcı Ekle',
                    subtitle: 'HP, geçici HP ve AC ile savaşçı oluştur.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'İsim'),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      SizedBox(
                        width: 135,
                        child: TextField(
                          controller: hp,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'HP'),
                        ),
                      ),
                      SizedBox(
                        width: 135,
                        child: TextField(
                          controller: maxHp,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max HP'),
                        ),
                      ),
                      SizedBox(
                        width: 135,
                        child: TextField(
                          controller: tempHp,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Temp HP'),
                        ),
                      ),
                      SizedBox(
                        width: 135,
                        child: TextField(
                          controller: ac,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'AC'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _addCombatant,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Katılımcı ekle'),
                  ),
                ],
              ),
            ),
            if (combatants.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (var i = 0; i < combatants.length; i++) ...[
                _CombatantPlusCard(
                  combatant: combatants[i],
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => combatants.removeAt(i)),
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 4),
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.note_alt_outlined,
                    title: 'Round Notları',
                    subtitle: 'Savaş boyunca kısa olay notlarını tut.',
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: roundNotes,
                    minLines: 5,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: 'Round 1: ...\nRound 2: ...',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCombatant() {
    final n = name.text.trim();
    if (n.isEmpty) return;
    final currentHp = int.tryParse(hp.text.trim()) ?? 1;
    final maximum = int.tryParse(maxHp.text.trim()) ?? currentHp;
    final temporary = int.tryParse(tempHp.text.trim()) ?? 0;
    final armor = int.tryParse(ac.text.trim()) ?? 10;

    setState(() {
      combatants.add(
        _CodexCombatantPlus(
          name: n,
          hp: currentHp.clamp(0, math.max(1, maximum)).toInt(),
          maxHp: math.max(1, maximum).toInt(),
          tempHp: math.max(0, temporary).toInt(),
          ac: armor,
        ),
      );
      name.clear();
      hp.clear();
      maxHp.clear();
      tempHp.clear();
      ac.clear();
    });
  }

  void _copyCombatSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Savaş Özeti — Round $round');
    for (final c in combatants) {
      buffer.writeln(
        '${c.name}: HP ${c.hp}/${c.maxHp}, Temp ${c.tempHp}, AC ${c.ac}'
        '${c.conditions.isEmpty ? '' : ', Durum: ${c.conditions.join(', ')}'}'
        '${c.concentration ? ', Konsantrasyon' : ''}',
      );
    }
    if (roundNotes.text.trim().isNotEmpty) {
      buffer.writeln('\nRound Notları:');
      buffer.writeln(roundNotes.text.trim());
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Savaş özeti panoya kopyalandı.')),
    );
  }
}

class _CodexCombatantPlus {
  String name;
  int hp;
  int maxHp;
  int tempHp;
  int ac;
  final Set<String> conditions = {};
  int deathSuccess = 0;
  int deathFail = 0;
  bool concentration = false;
  int resourceCurrent = 4;
  int resourceMax = 4;

  _CodexCombatantPlus({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.tempHp,
    required this.ac,
  });
}

class _CombatantPlusCard extends StatefulWidget {
  final _CodexCombatantPlus combatant;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _CombatantPlusCard({
    required this.combatant,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_CombatantPlusCard> createState() =>
      _CombatantPlusCardState();
}

class _CombatantPlusCardState extends State<_CombatantPlusCard> {
  bool expanded = false;
  final TextEditingController conditionController = TextEditingController();

  @override
  void dispose() {
    conditionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.combatant;
    final scheme = Theme.of(context).colorScheme;
    final hpRatio = c.maxHp <= 0 ? 0.0 : c.hp / c.maxHp;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: c.hp <= 0
                ? AppColors.red.withValues(alpha: .55)
                : scheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => expanded = !expanded),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      'AC\n${c.ac}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: c.hp <= 0 ? AppColors.red : scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: hpRatio.clamp(0.0, 1.0).toDouble(),
                          ),
                          duration: const Duration(milliseconds: 420),
                          builder: (_, value, __) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                value: value,
                                backgroundColor: scheme.surfaceContainerLow,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'HP ${c.hp}/${c.maxHp}'
                          '${c.tempHp > 0 ? ' • Temp ${c.tempHp}' : ''}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final amount in const [1, 5, 10])
                          ActionChip(
                            label: Text('-$amount HP'),
                            onPressed: () {
                              setState(() {
                                var damage = amount;
                                if (c.tempHp > 0) {
                                  final absorbed = math.min(c.tempHp, damage).toInt();
                                  c.tempHp -= absorbed;
                                  damage -= absorbed;
                                }
                                c.hp = math.max(0, c.hp - damage).toInt();
                              });
                              widget.onChanged();
                            },
                          ),
                        for (final amount in const [1, 5, 10])
                          ActionChip(
                            label: Text('+$amount HP'),
                            onPressed: () {
                              setState(() {
                                c.hp = math.min(c.maxHp, c.hp + amount).toInt();
                              });
                              widget.onChanged();
                            },
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.favorite_rounded, size: 16),
                          label: const Text('+5 Temp'),
                          onPressed: () {
                            setState(() => c.tempHp += 5);
                            widget.onChanged();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: conditionController,
                      decoration: InputDecoration(
                        labelText: 'Durum ekle',
                        suffixIcon: IconButton(
                          onPressed: () {
                            final value = conditionController.text.trim();
                            if (value.isEmpty) return;
                            setState(() {
                              c.conditions.add(value);
                              conditionController.clear();
                            });
                            widget.onChanged();
                          },
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ),
                    ),
                    if (c.conditions.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final value in c.conditions)
                            InputChip(
                              label: Text(value),
                              onDeleted: () {
                                setState(() => c.conditions.remove(value));
                                widget.onChanged();
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: c.concentration,
                      title: const Text('Konsantrasyon'),
                      onChanged: (value) {
                        setState(() => c.concentration = value);
                        widget.onChanged();
                      },
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: _DeathSaveBlock(
                            title: 'Başarı',
                            value: c.deathSuccess,
                            onChanged: (value) {
                              setState(() => c.deathSuccess = value);
                              widget.onChanged();
                            },
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _DeathSaveBlock(
                            title: 'Başarısız',
                            value: c.deathFail,
                            onChanged: (value) {
                              setState(() => c.deathFail = value);
                              widget.onChanged();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _CodexStepper(
                      label: 'Slot/Kaynak',
                      value: c.resourceCurrent,
                      min: 0,
                      max: c.resourceMax,
                      onChanged: (value) {
                        setState(() => c.resourceCurrent = value);
                        widget.onChanged();
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Katılımcıyı kaldır'),
                    ),
                  ],
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeathSaveBlock extends StatelessWidget {
  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  const _DeathSaveBlock({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 3; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onChanged(value == i ? i - 1 : i),
                  icon: Icon(
                    i <= value
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: i <= value ? AppColors.purple : AppColors.muted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}


// ============================================================================
// ADAPTIVE UI v1.3 — TELEFON VE TABLET İÇİN AYRI ARAYÜZLER
// ============================================================================

class _CodexPhoneDock extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onMore;

  const _CodexPhoneDock({
    required this.selected,
    required this.onSelected,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final moreSelected = selected == 3 || selected == 5;

    final items = <(IconData, String, int?)>[
      (Icons.space_dashboard_outlined, 'Merkez', 0),
      (Icons.folder_copy_outlined, 'Kasa', 1),
      (Icons.auto_awesome_outlined, 'Oluştur', 2),
      (Icons.construction_outlined, 'Araçlar', 4),
      (Icons.more_horiz_rounded, 'Daha', null),
    ];

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(10, 6, 10, 8 + bottom),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .28 : .08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final isSelected = item.$3 == null
                        ? moreSelected
                        : selected == item.$3;
                    return InkWell(
                      onTap: item.$3 == null
                          ? onMore
                          : () => onSelected(item.$3!),
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 13 : 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primary.withValues(alpha: .13)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Icon(
                              item.$1,
                              size: item.$3 == 2 ? 24 : 21,
                              color: isSelected
                                  ? (item.$3 == 2
                                      ? AppColors.gold
                                      : scheme.onSurface)
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$2,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCodexPhoneMoreSheet(
  BuildContext context, {
  required ValueChanged<int> go,
}) async {
  final store = VaultScope.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Text(
                    'Daha Fazla',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              _CodexPhoneMoreTile(
                icon: Icons.travel_explore_outlined,
                title: 'Ağ / Tablo / Pano',
                subtitle: 'Bağlantı alanlarını aç.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  go(3);
                },
              ),
              _CodexPhoneMoreTile(
                icon: Icons.tune_outlined,
                title: 'Ayarlar',
                subtitle: 'Depolama, kasa ve görünüm seçenekleri.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  go(5);
                },
              ),
              _CodexPhoneMoreTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Kasa değiştir',
                subtitle: '${store.vaultCatalog.length} kasa',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCodexVaultSwitcher(context);
                },
              ),
              _CodexPhoneMoreTile(
                icon: Icons.archive_outlined,
                title: 'Arşivlenenler',
                subtitle:
                    '${store.notes.where((n) => n.archived).length} kayıt',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HybridArchivePage(),
                    ),
                  );
                },
              ),
              _CodexPhoneMoreTile(
                icon: Icons.data_object_rounded,
                title: 'JSON Veri Merkezi',
                subtitle: 'Dosyadan veri al veya alanları eşleştir.',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CodexJsonImportPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CodexPhoneMoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CodexPhoneMoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      leading: Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: scheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class CodexPhoneHomePage extends StatelessWidget {
  final VoidCallback onOpenVault;
  final VoidCallback onOpenForge;
  final VoidCallback onOpenTools;

  const CodexPhoneHomePage({
    super.key,
    required this.onOpenVault,
    required this.onOpenForge,
    required this.onOpenTools,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = store.notes.where((n) => !n.archived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final openTasks = active.fold<int>(
      0,
      (sum, note) => sum +
          store.tasksFor(note).where(
            (line) => line.trimLeft().toLowerCase().startsWith('- [ ]'),
          ).length,
    );
    final linkCount = active.fold<int>(
      0,
      (sum, note) => sum + store.extractLinks(note.content).length,
    );

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        right: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tool Master',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                      Text(
                        store.vaultName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Kasa değiştir',
                  onPressed: () =>
                      _showCodexVaultSwitcher(context),
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: 'Ara',
                  onPressed: () => _codexSearch(context),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Material(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(23),
              child: InkWell(
                onTap: onOpenForge,
                borderRadius: BorderRadius.circular(23),
                child: Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.secondary.withValues(
                          alpha: dark ? .13 : .08,
                        ),
                        scheme.surfaceContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(
                      color: scheme.secondary.withValues(
                        alpha: dark ? .26 : .18,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: scheme.secondary.withValues(alpha: dark ? .15 : .10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: scheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yeni bir şey oluştur',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'NPC, oturum, mekân, görev, eşya ve daha fazlası.',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: scheme.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.9,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _CodexPhoneMetric(
                  icon: Icons.description_outlined,
                  value: '${active.length}',
                  label: 'Aktif kayıt',
                ),
                _CodexPhoneMetric(
                  icon: Icons.link_rounded,
                  value: '$linkCount',
                  label: 'Bağlantı',
                ),
                _CodexPhoneMetric(
                  icon: Icons.check_box_outlined,
                  value: '$openTasks',
                  label: 'Açık görev',
                ),
                _CodexPhoneMetric(
                  icon: Icons.archive_outlined,
                  value:
                      '${store.notes.where((n) => n.archived).length}',
                  label: 'Arşiv',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Son Çalıştıkların',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenVault,
                  child: const Text('Tümü'),
                ),
              ],
            ),
            if (active.isEmpty)
              const _CodexEmptyLine(
                icon: Icons.edit_note_outlined,
                text: 'Henüz kayıt yok. Oluştur bölümünden başlayabilirsin.',
              )
            else
              for (final note in active.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _CodexPhoneRecentCard(
                    note: note,
                  ),
                ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CodexPhoneShortcut(
                    icon: Icons.construction_outlined,
                    label: 'DM Araçları',
                    onTap: onOpenTools,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CodexPhoneShortcut(
                    icon: Icons.folder_copy_outlined,
                    label: 'Kasayı Aç',
                    onTap: onOpenVault,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CodexPhoneMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CodexPhoneMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: .98),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .16 : .045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodexPhoneRecentCard extends StatelessWidget {
  final NoteRecord note;

  const _CodexPhoneRecentCard({
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final color = _codexTypeColor(note.type);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openCodexRecord(context, note),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _codexTypeIcon(note.type),
                  color: color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.trim().isEmpty
                          ? 'Başlıksız'
                          : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      note.type.label,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodexPhoneShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CodexPhoneShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 14,
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class CodexPhoneVaultPage extends StatefulWidget {
  final VoidCallback onOpenForge;

  const CodexPhoneVaultPage({
    super.key,
    required this.onOpenForge,
  });

  @override
  State<CodexPhoneVaultPage> createState() =>
      _CodexPhoneVaultPageState();
}

class _CodexPhoneVaultPageState
    extends State<CodexPhoneVaultPage> {
  String query = '';
  String sortMode = 'updated_desc';
  String quickFilter = 'all';
  NoteType? type;
  String? tagFilter;
  String? folderFilter;
  bool grid = false;

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    var notes = store.notes.where((n) => !n.archived).toList();

    if (type != null) {
      notes = notes.where((n) => n.type == type).toList();
    }

    if (tagFilter != null) {
      notes = notes.where((note) {
        final tags = <String>{
          ...store.extractTags(note.content),
          ...(note.properties['tags'] ?? '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .map((e) => e.startsWith('#') ? e : '#$e'),
        };
        return tags.contains(tagFilter);
      }).toList();
    }

    if (folderFilter != null) {
      notes = notes.where((note) {
        final folder = (note.properties['folder'] ?? '/').trim();
        final normalized =
            folder.startsWith('/') ? folder : '/$folder';
        return normalized == folderFilter;
      }).toList();
    }

    switch (quickFilter) {
      case 'pinned':
        notes = notes.where((n) => n.pinned).toList();
        break;
      case 'bookmarked':
        notes = notes.where((n) => n.bookmarked).toList();
        break;
      case 'tasks':
        notes = notes.where(
          (n) => store.tasksFor(n).any(
            (line) =>
                line.trimLeft().toLowerCase().startsWith('- [ ]'),
          ),
        ).toList();
        break;
      case 'broken':
        notes = notes
            .where((n) => store.unresolvedLinks(n).isNotEmpty)
            .toList();
        break;
      case 'orphans':
        notes = notes.where((n) {
          return store.backlinksFor(n).isEmpty &&
              store.outgoingResolved(n).isEmpty;
        }).toList();
        break;
    }

    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      notes = notes.where((note) {
        final props = note.properties.entries
            .map((e) => '${e.key} ${e.value}')
            .join(' ');
        return '${note.title} ${note.content} $props'
            .toLowerCase()
            .contains(q);
      }).toList();
    }

    switch (sortMode) {
      case 'updated_asc':
        notes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case 'created_desc':
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'title':
        notes.sort(
          (a, b) => a.title.toLowerCase().compareTo(
                b.title.toLowerCase(),
              ),
        );
        break;
      case 'type':
        notes.sort((a, b) {
          final byType = a.type.label.compareTo(b.type.label);
          if (byType != 0) return byType;
          return a.title.toLowerCase().compareTo(
                b.title.toLowerCase(),
              );
        });
        break;
      default:
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    final activeFilterCount = [
      if (type != null) 1,
      if (tagFilter != null) 1,
      if (folderFilter != null) 1,
      if (quickFilter != 'all') 1,
    ].length;

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        right: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Kasa',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: grid ? 'Liste' : 'Kart',
                    onPressed: () =>
                        setState(() => grid = !grid),
                    icon: Icon(
                      grid
                          ? Icons.view_agenda_outlined
                          : Icons.grid_view_outlined,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Badge(
                    isLabelVisible: activeFilterCount > 0,
                    label: Text('$activeFilterCount'),
                    child: IconButton.filledTonal(
                      tooltip: 'Filtreler',
                      onPressed: () =>
                          _showPhoneFilters(store),
                      icon: const Icon(
                        Icons.tune_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (value) =>
                    setState(() => query = value),
                decoration: const InputDecoration(
                  hintText: 'Kasada ara...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in const [
                    ('all', 'Tümü'),
                    ('pinned', 'Sabit'),
                    ('bookmarked', 'Yer İmi'),
                    ('tasks', 'Görev'),
                    ('broken', 'Eksik Link'),
                  ]) ...[
                    ChoiceChip(
                      label: Text(filter.$2),
                      selected: quickFilter == filter.$1,
                      onSelected: (_) {
                        setState(() => quickFilter = filter.$1);
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: notes.isEmpty
                  ? _CodexVaultEmpty(
                      hasFilter: q.isNotEmpty ||
                          activeFilterCount > 0,
                      onCreate: widget.onOpenForge,
                    )
                  : grid
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            28,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: .92,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: notes.length,
                          itemBuilder: (context, index) =>
                              _CodexPhoneVaultGridCard(
                            note: notes[index],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            28,
                          ),
                          itemCount: notes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 7),
                          itemBuilder: (context, index) =>
                              _CodexVaultTile(
                            note: notes[index],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhoneFilters(VaultStore store) async {
    var draftSort = sortMode;
    var draftQuick = quickFilter;
    NoteType? draftType = type;
    var draftTag = tagFilter;
    var draftFolder = folderFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  20,
                ),
                child: SizedBox(
                  height: math.min(
                    MediaQuery.sizeOf(context).height * .72,
                    620.0,
                  ).toDouble(),
                  child: ListView(
                    children: [
                      const Text(
                        'Kasa Filtreleri',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: draftSort,
                        decoration: const InputDecoration(
                          labelText: 'Sıralama',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'updated_desc',
                            child: Text('Son düzenlenen'),
                          ),
                          DropdownMenuItem(
                            value: 'updated_asc',
                            child: Text('En eski düzenlenen'),
                          ),
                          DropdownMenuItem(
                            value: 'created_desc',
                            child: Text('Yeni oluşturulan'),
                          ),
                          DropdownMenuItem(
                            value: 'title',
                            child: Text('Başlığa göre'),
                          ),
                          DropdownMenuItem(
                            value: 'type',
                            child: Text('Türe göre'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(
                              () => draftSort = value,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 9),
                      DropdownButtonFormField<NoteType?>(
                        value: draftType,
                        decoration: const InputDecoration(
                          labelText: 'Tür',
                        ),
                        items: [
                          const DropdownMenuItem<NoteType?>(
                            value: null,
                            child: Text('Tüm türler'),
                          ),
                          for (final item in NoteType.values)
                            DropdownMenuItem<NoteType?>(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) =>
                            setSheetState(
                          () => draftType = value,
                        ),
                      ),
                      const SizedBox(height: 9),
                      DropdownButtonFormField<String?>(
                        value: draftTag,
                        decoration: const InputDecoration(
                          labelText: 'Etiket',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tüm etiketler'),
                          ),
                          for (final item in store.allTags)
                            DropdownMenuItem<String?>(
                              value: item,
                              child: Text(item),
                            ),
                        ],
                        onChanged: (value) =>
                            setSheetState(
                          () => draftTag = value,
                        ),
                      ),
                      const SizedBox(height: 9),
                      DropdownButtonFormField<String?>(
                        value: draftFolder,
                        decoration: const InputDecoration(
                          labelText: 'Klasör',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tüm klasörler'),
                          ),
                          for (final item in store.allFolders)
                            DropdownMenuItem<String?>(
                              value: item,
                              child: Text(item),
                            ),
                        ],
                        onChanged: (value) =>
                            setSheetState(
                          () => draftFolder = value,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  draftSort = 'updated_desc';
                                  draftQuick = 'all';
                                  draftType = null;
                                  draftTag = null;
                                  draftFolder = null;
                                });
                              },
                              child: const Text('Temizle'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  sortMode = draftSort;
                                  quickFilter = draftQuick;
                                  type = draftType;
                                  tagFilter = draftTag;
                                  folderFilter = draftFolder;
                                });
                                Navigator.pop(sheetContext);
                              },
                              child: const Text('Uygula'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CodexPhoneVaultGridCard extends StatelessWidget {
  final NoteRecord note;

  const _CodexPhoneVaultGridCard({
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final color = _codexTypeColor(note.type);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openCodexRecord(context, note),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _codexTypeIcon(note.type),
                      color: color,
                      size: 19,
                    ),
                  ),
                  const Spacer(),
                  _NoteOverflowMenu(note: note),
                ],
              ),
              const Spacer(),
              Text(
                note.title.trim().isEmpty
                    ? 'Başlıksız'
                    : note.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                note.type.label,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodexTabletShelf extends StatelessWidget {
  final VoidCallback onOpenVault;
  final VoidCallback onOpenForge;
  final VoidCallback onOpenTools;

  const _CodexTabletShelf({
    required this.onOpenVault,
    required this.onOpenForge,
    required this.onOpenTools,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final active = store.notes.where((n) => !n.archived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final openTasks = active.fold<int>(
      0,
      (sum, note) => sum +
          store.tasksFor(note).where(
            (line) => line.trimLeft().toLowerCase().startsWith('- [ ]'),
          ).length,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: .91),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
        ),
        child: ListView(
          children: [
            const Text(
              'MASA RAFI',
              style: TextStyle(
                color: AppColors.purple,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              store.vaultName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _CodexTabletShelfMetric(
              icon: Icons.description_outlined,
              label: 'Aktif kayıt',
              value: '${active.length}',
            ),
            _CodexTabletShelfMetric(
              icon: Icons.check_box_outlined,
              label: 'Açık görev',
              value: '$openTasks',
            ),
            _CodexTabletShelfMetric(
              icon: Icons.tag_rounded,
              label: 'Etiket',
              value: '${store.allTags.length}',
            ),
            const SizedBox(height: 13),
            FilledButton.icon(
              onPressed: onOpenForge,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Yeni Kayıt'),
            ),
            const SizedBox(height: 7),
            OutlinedButton.icon(
              onPressed: onOpenTools,
              icon: const Icon(Icons.construction_outlined),
              label: const Text('DM Araçları'),
            ),
            const SizedBox(height: 7),
            OutlinedButton.icon(
              onPressed: onOpenVault,
              icon: const Icon(Icons.folder_copy_outlined),
              label: const Text('Kasayı Aç'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'SON KAYITLAR',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kasa değiştir',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      _showCodexVaultSwitcher(context),
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 19,
                  ),
                ),
              ],
            ),
            if (active.isEmpty)
              const _CodexEmptyLine(
                icon: Icons.inbox_outlined,
                text: 'Henüz kayıt yok.',
              )
            else
              for (final note in active.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _codexTypeIcon(note.type),
                    color: _codexTypeColor(note.type),
                    size: 19,
                  ),
                  title: Text(
                    note.title.trim().isEmpty
                        ? 'Başlıksız'
                        : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    note.type.label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 9,
                    ),
                  ),
                  onTap: () =>
                      _openCodexRecord(context, note),
                ),
          ],
        ),
      ),
    );
  }
}

class _CodexTabletShelfMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CodexTabletShelfMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 9.5,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}



class _CodexResponsiveOptionSelector extends StatelessWidget {
  final String value;
  final List<(String, IconData, String)> options;
  final ValueChanged<String> onChanged;

  const _CodexResponsiveOptionSelector({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final option in options)
            ChoiceChip(
              avatar: Icon(option.$2, size: 16),
              label: Text(
                option.$3,
                overflow: TextOverflow.ellipsis,
              ),
              selected: value == option.$1,
              onSelected: (_) => onChanged(option.$1),
            ),
        ],
      ),
    );
  }
}

class _CodexTabletHomeColumns extends StatelessWidget {
  final double gap;
  final List<NoteRecord> active;
  final int tasks;
  final int unresolved;
  final int orphanCount;
  final VoidCallback onOpenVault;
  final VoidCallback onOpenForge;
  final VoidCallback onOpenAtlas;
  final VoidCallback onOpenTools;

  const _CodexTabletHomeColumns({
    required this.gap,
    required this.active,
    required this.tasks,
    required this.unresolved,
    required this.orphanCount,
    required this.onOpenVault,
    required this.onOpenForge,
    required this.onOpenAtlas,
    required this.onOpenTools,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Column(
      children: [
        _CodexTabletSectionFrame(
          title: 'Son Çalışma Alanı',
          icon: Icons.history_rounded,
          actionLabel: 'Kasayı Aç',
          onAction: onOpenVault,
          child: _CodexRecentPanel(
            notes: active.take(6).toList(),
            onOpenVault: onOpenVault,
          ),
        ),
        SizedBox(height: gap),
        _CodexTabletSectionFrame(
          title: 'Kayıt Atölyesi',
          icon: Icons.auto_awesome_outlined,
          actionLabel: 'Tüm Türler',
          onAction: onOpenForge,
          child: _CodexForgeStrip(
            onOpenForge: onOpenForge,
          ),
        ),
      ],
    );

    final secondary = Column(
      children: [
        _CodexTabletQuickLaunch(
          onOpenForge: onOpenForge,
          onOpenVault: onOpenVault,
          onOpenAtlas: onOpenAtlas,
          onOpenTools: onOpenTools,
        ),
        SizedBox(height: gap),
        _CodexPulsePanel(
          orphanCount: orphanCount,
          unresolved: unresolved,
          tasks: tasks,
          onOpenAtlas: onOpenAtlas,
        ),
        SizedBox(height: gap),
        const _CodexTagPanel(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              primary,
              SizedBox(height: gap),
              secondary,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: primary,
            ),
            SizedBox(width: gap),
            Expanded(
              flex: 4,
              child: secondary,
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// TABLET PRO v1.4 — GERÇEK ÇOK PANELLİ TABLET ÇALIŞMA ALANI
// ============================================================================

class _CodexTabletProRail extends StatelessWidget {
  final int selected;
  final bool expanded;
  final ValueChanged<int> onSelected;

  const _CodexTabletProRail({
    required this.selected,
    required this.expanded,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    const items = [
      (Icons.space_dashboard_outlined, 'Merkez'),
      (Icons.folder_copy_outlined, 'Kasa'),
      (Icons.auto_awesome_outlined, 'Oluştur'),
      (Icons.travel_explore_outlined, 'Ağ'),
      (Icons.construction_outlined, 'Araçlar'),
      (Icons.tune_outlined, 'Ayarlar'),
    ];

    final width = expanded ? 190.0 : 70.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .26),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showCodexVaultSwitcher(context),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.purple.withValues(alpha: .22),
                          AppColors.gold.withValues(alpha: .10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const _FantasyIcon(
                      'book_open',
                      size: 30,
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AKTİF KASA',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            store.vaultName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: selected == i
                    ? scheme.primary.withValues(alpha: .12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => onSelected(i),
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 54,
                    child: Row(
                      mainAxisAlignment: expanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 180),
                          width: 3,
                          height: selected == i ? 28 : 0,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius:
                                BorderRadius.circular(99),
                          ),
                        ),
                        SizedBox(width: expanded ? 12 : 0),
                        Icon(
                          items[i].$1,
                          size: 22,
                          color: selected == i
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                        if (expanded) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              items[i].$2,
                              style: TextStyle(
                                fontWeight: selected == i
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: selected == i
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (expanded)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bg.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_done_outlined,
                    size: 17,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      store.saving
                          ? 'Kaydediliyor…'
                          : store.lastSavedAt == null
                              ? 'Hazır'
                              : 'Kasa güncel',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Icon(
              store.saving
                  ? Icons.sync_rounded
                  : Icons.cloud_done_outlined,
              color:
                  store.saving ? AppColors.gold : AppColors.green,
              size: 18,
            ),
        ],
      ),
    );
  }
}

class CodexTabletHomePage extends StatelessWidget {
  final VoidCallback onOpenVault;
  final VoidCallback onOpenForge;
  final VoidCallback onOpenAtlas;
  final VoidCallback onOpenTools;

  const CodexTabletHomePage({
    super.key,
    required this.onOpenVault,
    required this.onOpenForge,
    required this.onOpenAtlas,
    required this.onOpenTools,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final config = HybridConfigScope.of(context);
    final active = store.notes.where((n) => !n.archived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final tasks = active.fold<int>(
      0,
      (sum, note) => sum +
          store.tasksFor(note).where(
            (line) =>
                line.trimLeft().toLowerCase().startsWith('- [ ]'),
          ).length,
    );
    final links = active.fold<int>(
      0,
      (sum, note) => sum + store.extractLinks(note.content).length,
    );
    final unresolved = active.fold<int>(
      0,
      (sum, note) =>
          sum + store.unresolvedLinks(note).length,
    );

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _CodexHeader(
              eyebrow: 'TABLET KOMUTA MERKEZİ',
              title: store.vaultName,
              subtitle:
                  'Geniş masa düzeni: hazırlık, kayıt, ağ ve masa araçları tek bakışta.',
              actions: [
                _CodexIconButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Hızlı arama',
                  onTap: () => _codexSearch(context),
                ),
                const SizedBox(width: 7),
                _CodexIconButton(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Kasa değiştir',
                  onTap: () =>
                      _showCodexVaultSwitcher(context),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gap = config.tabletGap;
                  return ListView(
                    padding: config.tabletPagePadding,
                    children: [
                      _CodexHeroPanel(
                        noteCount: active.length,
                        linkCount: links,
                        taskCount: tasks,
                        archiveCount: store.notes
                            .where((n) => n.archived)
                            .length,
                        onOpenVault: onOpenVault,
                        onOpenForge: onOpenForge,
                      ),
                      SizedBox(height: gap),
                      _CodexTabletHomeColumns(
                        gap: gap,
                        active: active,
                        tasks: tasks,
                        unresolved: unresolved,
                        orphanCount: store.orphanCount,
                        onOpenVault: onOpenVault,
                        onOpenForge: onOpenForge,
                        onOpenAtlas: onOpenAtlas,
                        onOpenTools: onOpenTools,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodexTabletSectionFrame extends StatelessWidget {
  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  const _CodexTabletSectionFrame({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.purple),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class _CodexTabletQuickLaunch extends StatelessWidget {
  final VoidCallback onOpenForge;
  final VoidCallback onOpenVault;
  final VoidCallback onOpenAtlas;
  final VoidCallback onOpenTools;

  const _CodexTabletQuickLaunch({
    required this.onOpenForge,
    required this.onOpenVault,
    required this.onOpenAtlas,
    required this.onOpenTools,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.auto_awesome_rounded,
        'Yeni Kayıt',
        'NPC, oturum, görev…',
        onOpenForge,
      ),
      (
        Icons.folder_copy_outlined,
        'Kasa',
        'Arşivi tara',
        onOpenVault,
      ),
      (
        Icons.hub_outlined,
        'Ağ',
        'Bağlantıları gör',
        onOpenAtlas,
      ),
      (
        Icons.construction_outlined,
        'DM Araçları',
        'Masa yardımcıları',
        onOpenTools,
      ),
    ];

    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CodexPanelTitle(
            icon: Icons.bolt_rounded,
            title: 'Hızlı Başlat',
            subtitle:
                'Tablet masasından en sık kullanılan alanlara tek dokunuş.',
          ),
          const SizedBox(height: 10),
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: AppColors.bg.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  onTap: action.$4,
                  borderRadius: BorderRadius.circular(13),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(
                          action.$1,
                          color: AppColors.purple,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                action.$3,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.muted,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CodexTabletVaultPage extends StatefulWidget {
  final VoidCallback onOpenForge;

  const CodexTabletVaultPage({
    super.key,
    required this.onOpenForge,
  });

  @override
  State<CodexTabletVaultPage> createState() =>
      _CodexTabletVaultPageState();
}

class _CodexTabletVaultPageState
    extends State<CodexTabletVaultPage> {
  String query = '';
  NoteType? type;
  String quickFilter = 'all';
  String sortMode = 'updated_desc';
  String? selectedPreviewId;

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final config = HybridConfigScope.of(context);

    var notes = store.notes.where((n) => !n.archived).toList();

    if (type != null) {
      notes = notes.where((n) => n.type == type).toList();
    }

    switch (quickFilter) {
      case 'pinned':
        notes = notes.where((n) => n.pinned).toList();
        break;
      case 'bookmarked':
        notes = notes.where((n) => n.bookmarked).toList();
        break;
      case 'tasks':
        notes = notes.where((n) =>
            store.tasksFor(n).any((line) => line
                .trimLeft()
                .toLowerCase()
                .startsWith('- [ ]'))).toList();
        break;
      case 'broken':
        notes = notes
            .where((n) => store.unresolvedLinks(n).isNotEmpty)
            .toList();
        break;
    }

    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      notes = notes.where((n) {
        final props = n.properties.entries
            .map((e) => '${e.key} ${e.value}')
            .join(' ');
        return '${n.title} ${n.content} $props'
            .toLowerCase()
            .contains(q);
      }).toList();
    }

    switch (sortMode) {
      case 'title':
        notes.sort((a, b) => a.title
            .toLowerCase()
            .compareTo(b.title.toLowerCase()));
        break;
      case 'created':
        notes.sort((a, b) =>
            b.createdAt.compareTo(a.createdAt));
        break;
      case 'type':
        notes.sort((a, b) =>
            a.type.label.compareTo(b.type.label));
        break;
      default:
        notes.sort((a, b) =>
            b.updatedAt.compareTo(a.updatedAt));
    }

    NoteRecord? preview;
    if (selectedPreviewId != null) {
      for (final note in notes) {
        if (note.id == selectedPreviewId) {
          preview = note;
          break;
        }
      }
    }
    if (preview == null && notes.isNotEmpty) {
      preview = notes.first;
    }

    final listWidth = config.tabletDensity == 'compact'
        ? 330.0
        : config.tabletDensity == 'spacious'
            ? 410.0
            : 370.0;

    return _CodexPageBackdrop(
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _CodexHeader(
              eyebrow: 'KASA • TABLET İKİ PANEL',
              title: 'Arşiv Çalışma Masası',
              subtitle:
                  'Soldan kayıt seç, sağda bağlamı incele; tam editörü yalnızca gerektiğinde aç.',
              actions: [
                _CodexFilterMenu(
                  icon: Icons.sort_rounded,
                  label: _codexSortLabel(
                    sortMode == 'created'
                        ? 'created_desc'
                        : sortMode,
                  ),
                  items: const {
                    'updated_desc': 'Son düzenlenen',
                    'created': 'Yeni oluşturulan',
                    'title': 'Başlığa göre',
                    'type': 'Türe göre',
                  },
                  onSelected: (value) =>
                      setState(() => sortMode = value),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: config.tabletPagePadding,
                child: Row(
                  children: [
                    SizedBox(
                      width: listWidth,
                      child: _CodexPanel(
                        child: Column(
                          children: [
                            TextField(
                              onChanged: (value) =>
                                  setState(() => query = value),
                              decoration: const InputDecoration(
                                hintText: 'Kasada ara…',
                                prefixIcon:
                                    Icon(Icons.search_rounded),
                              ),
                            ),
                            const SizedBox(height: 9),
                            SizedBox(
                              height: 38,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final filter in const [
                                    ('all', 'Tümü'),
                                    ('pinned', 'Sabit'),
                                    ('bookmarked', 'Yer İmi'),
                                    ('tasks', 'Görev'),
                                    ('broken', 'Eksik Link'),
                                  ]) ...[
                                    ChoiceChip(
                                      label: Text(filter.$2),
                                      selected: quickFilter ==
                                          filter.$1,
                                      onSelected: (_) => setState(
                                        () => quickFilter =
                                            filter.$1,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<NoteType?>(
                              value: type,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tür filtresi',
                              ),
                              items: [
                                const DropdownMenuItem<NoteType?>(
                                  value: null,
                                  child: Text('Tüm türler'),
                                ),
                                for (final value
                                    in NoteType.values)
                                  DropdownMenuItem<NoteType?>(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => type = value),
                            ),
                            const SizedBox(height: 9),
                            Expanded(
                              child: notes.isEmpty
                                  ? _CodexVaultEmpty(
                                      hasFilter:
                                          q.isNotEmpty ||
                                              type != null ||
                                              quickFilter !=
                                                  'all',
                                      onCreate:
                                          widget.onOpenForge,
                                    )
                                  : ListView.separated(
                                      itemCount: notes.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(
                                              height: 5),
                                      itemBuilder:
                                          (context, index) {
                                        final note =
                                            notes[index];
                                        return _CodexTabletVaultListRow(
                                          note: note,
                                          selected:
                                              preview?.id ==
                                                  note.id,
                                          onTap: () =>
                                              setState(() {
                                            selectedPreviewId =
                                                note.id;
                                          }),
                                          onOpen: () =>
                                              _openCodexRecord(
                                            context,
                                            note,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: config.tabletGap),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration:
                            const Duration(milliseconds: 220),
                        child: preview == null
                            ? const _CodexTabletPreviewEmpty()
                            : _CodexTabletVaultPreview(
                                key: ValueKey(preview.id),
                                note: preview,
                              ),
                      ),
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

class _CodexTabletVaultListRow extends StatelessWidget {
  final NoteRecord note;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const _CodexTabletVaultListRow({
    required this.note,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = _codexTypeColor(note.type);
    return Material(
      color: selected
          ? AppColors.purple.withValues(alpha: .11)
          : AppColors.bg.withValues(alpha: .24),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onOpen,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? AppColors.purple.withValues(alpha: .45)
                  : AppColors.border.withValues(alpha: .7),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _codexTypeIcon(note.type),
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.trim().isEmpty
                          ? 'Başlıksız'
                          : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${note.type.label} • ${_formatDate(note.updatedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (note.pinned)
                const Icon(
                  Icons.push_pin_rounded,
                  size: 15,
                  color: AppColors.gold,
                ),
              const SizedBox(width: 3),
              IconButton(
                tooltip: 'Tam editörü aç',
                visualDensity: VisualDensity.compact,
                onPressed: onOpen,
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodexTabletPreviewEmpty extends StatelessWidget {
  const _CodexTabletPreviewEmpty();

  @override
  Widget build(BuildContext context) {
    return _CodexPanel(
      child: const Center(
        child: _CodexEmptyLine(
          icon: Icons.preview_outlined,
          text: 'Önizlemek için soldan bir kayıt seç.',
        ),
      ),
    );
  }
}

class _CodexTabletVaultPreview extends StatelessWidget {
  final NoteRecord note;

  const _CodexTabletVaultPreview({
    super.key,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = _codexTypeColor(note.type);
    final links = store.outgoingResolved(note);
    final backlinks = store.backlinksFor(note);
    final tasks = store.tasksFor(note);
    final tags = <String>{
      ...store.extractTags(note.content),
      ...(note.properties['tags'] ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e.startsWith('#') ? e : '#$e'),
    }.toList();

    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _codexTypeIcon(note.type),
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.trim().isEmpty
                          ? 'Başlıksız'
                          : note.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${note.type.label} • ${note.visibility}',
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () =>
                    _openCodexRecord(context, note),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                ),
                label: const Text('Tam Editör'),
              ),
              const SizedBox(width: 5),
              _NoteOverflowMenu(note: note),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CodexTabletMetaPill(
                icon: Icons.link_rounded,
                text: '${links.length} giden',
              ),
              _CodexTabletMetaPill(
                icon: Icons.keyboard_return_rounded,
                text: '${backlinks.length} geri',
              ),
              _CodexTabletMetaPill(
                icon: Icons.check_box_outlined,
                text: '${tasks.length} görev',
              ),
              _CodexTabletMetaPill(
                icon: Icons.tune_rounded,
                text: '${note.properties.length} alan',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                if (tags.isNotEmpty) ...[
                  const _CodexTabletPreviewHeading(
                    icon: Icons.tag_rounded,
                    title: 'Etiketler',
                  ),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final tag in tags)
                        Chip(
                          visualDensity:
                              VisualDensity.compact,
                          label: Text(tag),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                const _CodexTabletPreviewHeading(
                  icon: Icons.notes_rounded,
                  title: 'Not Önizlemesi',
                ),
                Container(
                  constraints:
                      const BoxConstraints(minHeight: 150),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color:
                        AppColors.bg.withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    note.content.trim().isEmpty
                        ? 'Bu kayıtta henüz serbest not yok.'
                        : note.content,
                    maxLines: 18,
                    style: TextStyle(
                      color: note.content.trim().isEmpty
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
                if (note.properties.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _CodexTabletPreviewHeading(
                    icon: Icons.tune_rounded,
                    title: 'Özel Alanlar',
                  ),
                  for (final entry
                      in note.properties.entries.take(12))
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (links.isNotEmpty ||
                    backlinks.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _CodexTabletPreviewHeading(
                    icon: Icons.account_tree_outlined,
                    title: 'Bağlantı Bağlamı',
                  ),
                  for (final linked in [
                    ...links.take(4),
                    ...backlinks.take(4),
                  ])
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _codexTypeIcon(linked.type),
                        color: _codexTypeColor(linked.type),
                        size: 18,
                      ),
                      title: Text(
                        linked.title.trim().isEmpty
                            ? 'Başlıksız'
                            : linked.title,
                        style:
                            const TextStyle(fontSize: 10.5),
                      ),
                      onTap: () =>
                          _openCodexRecord(context, linked),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexTabletMetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CodexTabletMetaPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: .30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.border.withValues(alpha: .8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexTabletPreviewHeading extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CodexTabletPreviewHeading({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.purple),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexTabletContextShelf extends StatelessWidget {
  final int section;
  final VoidCallback onOpenVault;
  final VoidCallback onOpenForge;
  final VoidCallback onOpenTools;

  const _CodexTabletContextShelf({
    required this.section,
    required this.onOpenVault,
    required this.onOpenForge,
    required this.onOpenTools,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final active = store.notes.where((n) => !n.archived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final openTasks = active.fold<int>(
      0,
      (sum, note) => sum +
          store.tasksFor(note).where((line) => line
              .trimLeft()
              .toLowerCase()
              .startsWith('- [ ]')).length,
    );
    final unresolved = active.fold<int>(
      0,
      (sum, note) =>
          sum + store.unresolvedLinks(note).length,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 12, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ListView(
          children: [
            Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color:
                        scheme.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    _tabletShelfIcon(section),
                    color: scheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BAĞLAM RAFI',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        _tabletShelfTitle(section),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CodexTabletShelfMetric(
              icon: Icons.description_outlined,
              label: 'Aktif kayıt',
              value: '${active.length}',
            ),
            _CodexTabletShelfMetric(
              icon: Icons.check_box_outlined,
              label: 'Açık görev',
              value: '$openTasks',
            ),
            _CodexTabletShelfMetric(
              icon: Icons.link_off_rounded,
              label: 'Eksik link',
              value: '$unresolved',
            ),
            const SizedBox(height: 12),
            if (section == 0 || section == 1) ...[
              FilledButton.icon(
                onPressed: onOpenForge,
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                ),
                label: const Text('Yeni Kayıt'),
              ),
              const SizedBox(height: 6),
            ],
            OutlinedButton.icon(
              onPressed: onOpenTools,
              icon: const Icon(
                Icons.construction_outlined,
                size: 18,
              ),
              label: const Text('DM Araçları'),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onOpenVault,
              icon: const Icon(
                Icons.folder_copy_outlined,
                size: 18,
              ),
              label: const Text('Kasayı Aç'),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              section == 4
                  ? 'MASA KISAYOLLARI'
                  : 'SON KAYITLAR',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            if (section == 4) ...[
              _CodexPhoneMoreTile(
                icon: Icons.science_outlined,
                title: 'Örnekler Laboratuvarı',
                subtitle: '106 özelliği incele',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const CodexFeatureShowcasePage(),
                  ),
                ),
              ),
              _CodexPhoneMoreTile(
                icon: Icons.insights_outlined,
                title: 'Kasa Analizi',
                subtitle: 'Sağlık ve içerik kontrolü',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const CodexVaultInsightsPage(),
                  ),
                ),
              ),
            ] else if (active.isEmpty)
              const _CodexEmptyLine(
                icon: Icons.inbox_outlined,
                text: 'Henüz kayıt yok.',
              )
            else
              for (final note in active.take(6))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _codexTypeIcon(note.type),
                    color: _codexTypeColor(note.type),
                    size: 18,
                  ),
                  title: Text(
                    note.title.trim().isEmpty
                        ? 'Başlıksız'
                        : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    note.type.label,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 8.5,
                    ),
                  ),
                  onTap: () =>
                      _openCodexRecord(context, note),
                ),
          ],
        ),
      ),
    );
  }

  IconData _tabletShelfIcon(int value) {
    switch (value) {
      case 1:
        return Icons.folder_copy_outlined;
      case 2:
        return Icons.auto_awesome_outlined;
      case 3:
        return Icons.hub_outlined;
      case 4:
        return Icons.construction_outlined;
      case 5:
        return Icons.tune_outlined;
      default:
        return Icons.space_dashboard_outlined;
    }
  }

  String _tabletShelfTitle(int value) {
    switch (value) {
      case 1:
        return 'Kasa Bağlamı';
      case 2:
        return 'Kayıt Atölyesi';
      case 3:
        return 'Ağ Bağlamı';
      case 4:
        return 'Araç Kısayolları';
      case 5:
        return 'Çalışma Alanı';
      default:
        return 'Masa Özeti';
    }
  }
}

class _CodexTabletRecordInspector extends StatelessWidget {
  final NoteRecord note;

  const _CodexTabletRecordInspector({
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final links = store.outgoingResolved(note);
    final backlinks = store.backlinksFor(note);
    final tasks = store.tasksFor(note);
    final unresolved = store.unresolvedLinks(note);
    final tags = <String>{
      ...store.extractTags(note.content),
      ...(note.properties['tags'] ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e.startsWith('#') ? e : '#$e'),
    }.toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 10, 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView(
        children: [
          const _CodexPanelTitle(
            icon: Icons.info_outline_rounded,
            title: 'Kayıt Denetçisi',
            subtitle:
                'Editörden ayrılmadan bağlamı kontrol et.',
          ),
          const SizedBox(height: 12),
          _CodexTabletShelfMetric(
            icon: Icons.arrow_outward_rounded,
            label: 'Giden bağlantı',
            value: '${links.length}',
          ),
          _CodexTabletShelfMetric(
            icon: Icons.keyboard_return_rounded,
            label: 'Geri bağlantı',
            value: '${backlinks.length}',
          ),
          _CodexTabletShelfMetric(
            icon: Icons.check_box_outlined,
            label: 'Görev',
            value: '${tasks.length}',
          ),
          _CodexTabletShelfMetric(
            icon: Icons.link_off_rounded,
            label: 'Eksik link',
            value: '${unresolved.length}',
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 11),
            const _CodexTabletPreviewHeading(
              icon: Icons.tag_rounded,
              title: 'Etiketler',
            ),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final tag in tags)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(tag),
                  ),
              ],
            ),
          ],
          if (links.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _CodexTabletPreviewHeading(
              icon: Icons.arrow_outward_rounded,
              title: 'Giden Bağlantılar',
            ),
            for (final linked in links.take(6))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _codexTypeIcon(linked.type),
                  color: _codexTypeColor(linked.type),
                  size: 17,
                ),
                title: Text(
                  linked.title.trim().isEmpty
                      ? 'Başlıksız'
                      : linked.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
                onTap: () =>
                    _openCodexRecord(context, linked),
              ),
          ],
          if (backlinks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _CodexTabletPreviewHeading(
              icon: Icons.keyboard_return_rounded,
              title: 'Geri Bağlantılar',
            ),
            for (final linked in backlinks.take(6))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _codexTypeIcon(linked.type),
                  color: _codexTypeColor(linked.type),
                  size: 17,
                ),
                title: Text(
                  linked.title.trim().isEmpty
                      ? 'Başlıksız'
                      : linked.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
                onTap: () =>
                    _openCodexRecord(context, linked),
              ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                _showCodexRecordStats(context, note),
            icon: const Icon(
              Icons.analytics_outlined,
              size: 17,
            ),
            label: const Text('Kayıt İstatistikleri'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () =>
                _showCodexRelatedRecords(context, note),
            icon: const Icon(
              Icons.account_tree_outlined,
              size: 17,
            ),
            label: const Text('Tüm İlişkiler'),
          ),
        ],
      ),
    );
  }
}


// ============================================================================
// THEME PLUS v1.5 — TEMA / RENK TONLARI + 36 YENİ ÖZELLİK
// ============================================================================

class _CodexAppearanceSettingsSection extends StatelessWidget {
  const _CodexAppearanceSettingsSection();

  @override
  Widget build(BuildContext context) {
    final appearance = CodexAppearanceScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return _CodexSettingsSection(
      title: 'Tema & Renk',
      children: [
        const SizedBox(height: 4),
        const Text(
          'Tema modu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        _CodexResponsiveOptionSelector(
          value: appearance.themeMode,
          options: const [
            ('system', Icons.brightness_auto_rounded, 'Sistem'),
            ('dark', Icons.dark_mode_rounded, 'Karanlık'),
            ('light', Icons.light_mode_rounded, 'Aydınlık'),
          ],
          onChanged: appearance.setThemeMode,
        ),
        const SizedBox(height: 14),
        const Text(
          'Renk tonu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in CodexThemePalette.accents.entries)
              Tooltip(
                message:
                    CodexThemePalette.accentLabels[entry.key] ??
                    entry.key,
                child: InkWell(
                  onTap: () => appearance.setAccent(entry.key),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: appearance.accent == entry.key
                            ? scheme.onSurface
                            : scheme.outlineVariant,
                        width: appearance.accent == entry.key ? 3 : 1,
                      ),
                    ),
                    child: appearance.accent == entry.key
                        ? Icon(
                            Icons.check_rounded,
                            color: ThemeData.estimateBrightnessForColor(
                                      entry.value,
                                    ) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Yazı ölçeği',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${(appearance.fontScale * 100).round()}%',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
        Slider(
          min: .85,
          max: 1.30,
          divisions: 9,
          value: appearance.fontScale,
          onChanged: appearance.setFontScale,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: appearance.backgroundGrid,
          title: const Text('Atmosfer ızgarası'),
          subtitle: const Text(
            'Arka plandaki hareketli çalışma alanı çizgilerini göster.',
          ),
          onChanged: appearance.setBackgroundGrid,
        ),
        if (appearance.backgroundGrid) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Izgara yoğunluğu',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${(appearance.gridStrength * 100).round()}%',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          Slider(
            min: .2,
            max: 1.8,
            divisions: 16,
            value: appearance.gridStrength,
            onChanged: appearance.setGridStrength,
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: appearance.reduceMotion,
          title: const Text('Hareketi azalt'),
          subtitle: const Text(
            'Atmosfer animasyonlarını durdurur ve geçişleri sakinleştirir.',
          ),
          onChanged: appearance.setReduceMotion,
        ),
        if (!appearance.reduceMotion) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Animasyon hızı',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${(appearance.motionScale * 100).round()}%',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          Slider(
            min: .5,
            max: 1.6,
            divisions: 11,
            value: appearance.motionScale,
            onChanged: appearance.setMotionScale,
          ),
        ],
        const SizedBox(height: 7),
        const Text(
          'Yüzey stili',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        _CodexResponsiveOptionSelector(
          value: appearance.surfaceStyle,
          options: const [
            ('soft', Icons.blur_on_rounded, 'Yumuşak'),
            ('contrast', Icons.contrast_rounded, 'Kontrast'),
            ('flat', Icons.crop_square_rounded, 'Düz'),
          ],
          onChanged: appearance.setSurfaceStyle,
        ),
      ],
    );
  }
}

class _CodexPlusMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final VoidCallback? onTap;

  const _CodexPlusMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: scheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 71-82: Üretkenlik Merkezi
class CodexProductivityPlusPage extends StatefulWidget {
  const CodexProductivityPlusPage({super.key});

  @override
  State<CodexProductivityPlusPage> createState() =>
      _CodexProductivityPlusPageState();
}

class _CodexProductivityPlusPageState
    extends State<CodexProductivityPlusPage> {
  final TextEditingController inbox = TextEditingController();
  final TextEditingController quickTag = TextEditingController();
  final TextEditingController folder = TextEditingController();

  @override
  void dispose() {
    inbox.dispose();
    quickTag.dispose();
    folder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final active = store.notes.where((n) => !n.archived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final now = DateTime.now();
    final today = active.where((n) {
      final d = n.updatedAt;
      return d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();
    final week = active.where(
      (n) => now.difference(n.updatedAt).inDays <= 7,
    ).toList();
    final pinned = active.where((n) => n.pinned).toList();
    final bookmarks = active.where((n) => n.bookmarked).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Üretkenlik Merkezi+')),
      body: _CodexPageBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.inbox_outlined,
                    title: 'Hızlı Gelen Kutusu',
                    subtitle:
                        'Uzun form açmadan doğrudan yeni bir Not kaydı oluştur.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: inbox,
                    minLines: 3,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      hintText: 'Hızlı notunu yaz…',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final value = inbox.text.trim();
                      if (value.isEmpty) return;
                      final note = await store.create(NoteType.note);
                      note.title =
                          value.split('\n').first.trim().length > 48
                              ? '${value.split('\n').first.trim().substring(0, 48)}…'
                              : value.split('\n').first.trim();
                      note.content = value;
                      note.properties['folder'] = '/Gelen Kutusu';
                      note.propertyTypes['folder'] = 'text';
                      note.updatedAt = DateTime.now();
                      store.commitBulkChanges(immediate: true);
                      inbox.clear();
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Gelen kutusuna ekle'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CodexPlusGrid(
              children: [
                _CodexPlusMetricCard(
                  icon: Icons.today_rounded,
                  title: 'Bugün değişenler',
                  value: '${today.length}',
                  detail: 'Bugün düzenlenen aktif kayıt',
                  onTap: () => _showPlusNoteList(
                    context,
                    'Bugün Değişenler',
                    today,
                  ),
                ),
                _CodexPlusMetricCard(
                  icon: Icons.date_range_rounded,
                  title: 'Son 7 gün',
                  value: '${week.length}',
                  detail: 'Bir haftada dokunulan kayıt',
                  onTap: () => _showPlusNoteList(
                    context,
                    'Son 7 Gün',
                    week,
                  ),
                ),
                _CodexPlusMetricCard(
                  icon: Icons.push_pin_outlined,
                  title: 'Sabit kayıtlar',
                  value: '${pinned.length}',
                  detail: 'Hızlı erişim için sabitlenenler',
                  onTap: () => _showPlusNoteList(
                    context,
                    'Sabit Kayıtlar',
                    pinned,
                  ),
                ),
                _CodexPlusMetricCard(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Yer imleri',
                  value: '${bookmarks.length}',
                  detail: 'Sonra dönmek için işaretlenenler',
                  onTap: () => _showPlusNoteList(
                    context,
                    'Yer İmleri',
                    bookmarks,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.flash_on_outlined,
                    title: 'Hızlı Akışlar',
                    subtitle:
                        'Günlük not, pano yakalama ve rastgele kayıt.',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          final note = await store.createDailyNote();
                          if (!context.mounted) return;
                          _openCodexRecord(context, note);
                        },
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: const Text('Günlük Not'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          final value = data?.text?.trim() ?? '';
                          if (value.isEmpty) return;
                          final note =
                              await store.create(NoteType.note);
                          note.title = 'Pano Yakalama';
                          note.content = value;
                          note.properties['folder'] = '/Gelen Kutusu';
                          note.updatedAt = DateTime.now();
                          store.commitBulkChanges(immediate: true);
                        },
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Panodan Not'),
                      ),
                      OutlinedButton.icon(
                        onPressed: active.isEmpty
                            ? null
                            : () {
                                final note = active[
                                    math.Random().nextInt(active.length)];
                                _openCodexRecord(context, note);
                              },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Rastgele Kayıt'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final summary =
                              'Kasa: ${store.vaultName}\n'
                              'Aktif kayıt: ${active.length}\n'
                              'Etiket: ${store.allTags.length}\n'
                              'Klasör: ${store.allFolders.length}\n'
                              'Arşiv: ${store.notes.where((n) => n.archived).length}';
                          Clipboard.setData(
                            ClipboardData(text: summary),
                          );
                        },
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Kasa Özeti Kopyala'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CodexPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CodexPanelTitle(
                    icon: Icons.label_outline_rounded,
                    title: 'Hızlı Etiket / Klasör',
                    subtitle:
                        'En son düzenlenen kayda tek dokunuşla metadata ekle.',
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: quickTag,
                    decoration: const InputDecoration(
                      labelText: 'Etiket',
                    ),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: folder,
                    decoration: const InputDecoration(
                      labelText: 'Klasör',
                      hintText: '/Hazırlık',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: active.isEmpty
                        ? null
                        : () {
                            final note = active.first;
                            final tag = quickTag.text.trim();
                            final folderValue = folder.text.trim();

                            if (tag.isNotEmpty) {
                              final clean =
                                  tag.startsWith('#') ? tag.substring(1) : tag;
                              final tags = (note.properties['tags'] ?? '')
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toSet();
                              tags.add(clean);
                              note.properties['tags'] = tags.join(', ');
                              note.propertyTypes['tags'] = 'tags';
                            }
                            if (folderValue.isNotEmpty) {
                              note.properties['folder'] =
                                  folderValue.startsWith('/')
                                      ? folderValue
                                      : '/$folderValue';
                              note.propertyTypes['folder'] = 'text';
                            }
                            note.updatedAt = DateTime.now();
                            store.commitBulkChanges();
                            quickTag.clear();
                            folder.clear();
                            setState(() {});
                          },
                    child: const Text('Son kayda uygula'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 83-94: İstatistikler+
class CodexAnalyticsPlusPage extends StatelessWidget {
  const CodexAnalyticsPlusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.notes.where((n) => !n.archived).toList();

    int words(NoteRecord n) => n.content
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .length;

    final totalWords =
        notes.fold<int>(0, (sum, n) => sum + words(n));
    final totalTasks =
        notes.fold<int>(0, (sum, n) => sum + store.tasksFor(n).length);
    final completedTasks = notes.fold<int>(
      0,
      (sum, n) => sum +
          store
              .tasksFor(n)
              .where((e) => e.trimLeft().toLowerCase().startsWith('- [x]'))
              .length,
    );
    final links = notes.fold<int>(
      0,
      (sum, n) => sum + store.extractLinks(n.content).length,
    );
    final broken = notes.fold<int>(
      0,
      (sum, n) => sum + store.unresolvedLinks(n).length,
    );
    final backlinks = notes.fold<int>(
      0,
      (sum, n) => sum + store.backlinksFor(n).length,
    );

    final tagCount = <String, int>{};
    final typeCount = <NoteType, int>{};
    final folderCount = <String, int>{};

    for (final n in notes) {
      typeCount[n.type] = (typeCount[n.type] ?? 0) + 1;
      final folder = n.properties['folder'] ?? '/';
      folderCount[folder] = (folderCount[folder] ?? 0) + 1;
      for (final tag in {
        ...store.extractTags(n.content),
        ...(n.properties['tags'] ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .map((e) => e.startsWith('#') ? e : '#$e'),
      }) {
        tagCount[tag] = (tagCount[tag] ?? 0) + 1;
      }
    }

    final longest = [...notes]
      ..sort((a, b) => words(b).compareTo(words(a)));
    final newest = [...notes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final mostLinked = [...notes]
      ..sort((a, b) {
        final al = store.backlinksFor(a).length +
            store.outgoingResolved(a).length;
        final bl = store.backlinksFor(b).length +
            store.outgoingResolved(b).length;
        return bl.compareTo(al);
      });

    final taskRate = totalTasks == 0
        ? 0
        : ((completedTasks / totalTasks) * 100).round();
    final linkHealth = links == 0
        ? 100
        : (((links - broken).clamp(0, links) / links) * 100).round();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('İstatistikler+')),
      body: _CodexPageBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CodexPlusGrid(
              children: [
                _CodexPlusMetricCard(
                  icon: Icons.text_fields_rounded,
                  title: 'Toplam kelime',
                  value: '$totalWords',
                  detail: 'Aktif kayıtlardaki kelime hacmi',
                ),
                _CodexPlusMetricCard(
                  icon: Icons.timer_outlined,
                  title: 'Okuma süresi',
                  value: '${math.max(1, (totalWords / 200).ceil())} dk',
                  detail: 'Yaklaşık 200 kelime/dk',
                ),
                _CodexPlusMetricCard(
                  icon: Icons.task_alt_rounded,
                  title: 'Görev tamamlama',
                  value: '%$taskRate',
                  detail: '$completedTasks / $totalTasks tamamlandı',
                ),
                _CodexPlusMetricCard(
                  icon: Icons.link_rounded,
                  title: 'Bağlantı sağlığı',
                  value: '%$linkHealth',
                  detail: '$broken kırık hedef',
                ),
                _CodexPlusMetricCard(
                  icon: Icons.keyboard_return_rounded,
                  title: 'Geri bağlantı',
                  value: '$backlinks',
                  detail: 'Toplam çözülen geri bağlantı',
                ),
                _CodexPlusMetricCard(
                  icon: Icons.tag_rounded,
                  title: 'Benzersiz etiket',
                  value: '${tagCount.length}',
                  detail: 'İçerik ve metadata etiketleri',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CodexAnalyticsDistribution(
              title: 'Tür Dağılımı',
              icon: Icons.category_outlined,
              rows: typeCount.entries
                  .map((e) => (e.key.label, e.value))
                  .toList()
                ..sort((a, b) => b.$2.compareTo(a.$2)),
            ),
            const SizedBox(height: 12),
            _CodexAnalyticsDistribution(
              title: 'Klasör Dağılımı',
              icon: Icons.folder_outlined,
              rows: folderCount.entries
                  .map((e) => (e.key, e.value))
                  .toList()
                ..sort((a, b) => b.$2.compareTo(a.$2)),
            ),
            const SizedBox(height: 12),
            _CodexAnalyticsDistribution(
              title: 'En Sık Etiketler',
              icon: Icons.local_offer_outlined,
              rows: tagCount.entries
                  .map((e) => (e.key, e.value))
                  .toList()
                ..sort((a, b) => b.$2.compareTo(a.$2)),
            ),
            const SizedBox(height: 12),
            _CodexTopNotesSection(
              title: 'En Uzun Kayıtlar',
              notes: longest.take(8).toList(),
              valueFor: (n) => '${words(n)} kelime',
            ),
            const SizedBox(height: 12),
            _CodexTopNotesSection(
              title: 'En Yeni Kayıtlar',
              notes: newest.take(8).toList(),
              valueFor: (n) => _formatDate(n.createdAt),
            ),
            const SizedBox(height: 12),
            _CodexTopNotesSection(
              title: 'En Bağlantılı Kayıtlar',
              notes: mostLinked.take(8).toList(),
              valueFor: (n) =>
                  '${store.backlinksFor(n).length + store.outgoingResolved(n).length} ilişki',
            ),
          ],
        ),
      ),
    );
  }
}

class _CodexPlusGrid extends StatelessWidget {
  final List<Widget> children;

  const _CodexPlusGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          childAspectRatio: columns == 1 ? 3.6 : 2.8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: children,
        );
      },
    );
  }
}

class _CodexAnalyticsDistribution extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, int)> rows;

  const _CodexAnalyticsDistribution({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = rows.isEmpty
        ? 1
        : rows.map((e) => e.$2).reduce((a, b) => math.max(a, b).toInt());

    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CodexPanelTitle(
            icon: icon,
            title: title,
            subtitle: '${rows.length} kategori',
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const _CodexEmptyLine(
              icon: Icons.bar_chart_rounded,
              text: 'Gösterilecek veri yok.',
            )
          else
            for (final row in rows.take(12))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${row.$2}',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: row.$2 / maxValue,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _CodexTopNotesSection extends StatelessWidget {
  final String title;
  final List<NoteRecord> notes;
  final String Function(NoteRecord) valueFor;

  const _CodexTopNotesSection({
    required this.title,
    required this.notes,
    required this.valueFor,
  });

  @override
  Widget build(BuildContext context) {
    return _CodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 7),
          if (notes.isEmpty)
            const _CodexEmptyLine(
              icon: Icons.inbox_outlined,
              text: 'Kayıt yok.',
            )
          else
            for (final note in notes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _codexTypeIcon(note.type),
                  color: _codexTypeColor(note.type),
                  size: 18,
                ),
                title: Text(
                  note.title.trim().isEmpty
                      ? 'Başlıksız'
                      : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  valueFor(note),
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
                onTap: () => _openCodexRecord(context, note),
              ),
        ],
      ),
    );
  }
}

// 95-106: Hızlı İşlemler+
class CodexQuickActionsPlusPage extends StatefulWidget {
  const CodexQuickActionsPlusPage({super.key});

  @override
  State<CodexQuickActionsPlusPage> createState() =>
      _CodexQuickActionsPlusPageState();
}

class _CodexQuickActionsPlusPageState
    extends State<CodexQuickActionsPlusPage> {
  String? selectedId;
  final TextEditingController find = TextEditingController();
  final TextEditingController replace = TextEditingController();
  final TextEditingController append = TextEditingController();
  final TextEditingController alias = TextEditingController();

  @override
  void dispose() {
    find.dispose();
    replace.dispose();
    append.dispose();
    alias.dispose();
    super.dispose();
  }

  NoteRecord? _selected(VaultStore store) {
    if (selectedId == null) return null;
    for (final n in store.notes) {
      if (n.id == selectedId) return n;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = VaultScope.of(context);
    final notes = store.notes.where((n) => !n.archived).toList();
    final note = _selected(store);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Hızlı İşlemler+')),
      body: _CodexPageBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CodexPanel(
              child: DropdownButtonFormField<String>(
                value: selectedId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'İşlem yapılacak kayıt',
                ),
                items: [
                  for (final n in notes)
                    DropdownMenuItem(
                      value: n.id,
                      child: Text(
                        n.title.trim().isEmpty
                            ? 'Başlıksız'
                            : n.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => selectedId = value),
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 12),
              _CodexPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CodexPanelTitle(
                      icon: Icons.text_format_rounded,
                      title: 'Başlık İşlemleri',
                      subtitle:
                          'Başlığı dönüştür veya tarih damgası ekle.',
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        ActionChip(
                          label: const Text('BÜYÜK HARF'),
                          onPressed: () =>
                              _setTitle(store, note, note.title.toUpperCase()),
                        ),
                        ActionChip(
                          label: const Text('küçük harf'),
                          onPressed: () =>
                              _setTitle(store, note, note.title.toLowerCase()),
                        ),
                        ActionChip(
                          label: const Text('Baş Harfler'),
                          onPressed: () => _setTitle(
                            store,
                            note,
                            _titleCase(note.title),
                          ),
                        ),
                        ActionChip(
                          label: const Text('Tarih ekle'),
                          onPressed: () {
                            final now = DateTime.now();
                            final stamp =
                                '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                            _setTitle(
                              store,
                              note,
                              '${note.title} $stamp'.trim(),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CodexPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CodexPanelTitle(
                      icon: Icons.find_replace_rounded,
                      title: 'Bul & Değiştir',
                      subtitle:
                          'Seçili kaydın serbest not metninde işlem yap.',
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: find,
                      decoration:
                          const InputDecoration(labelText: 'Bul'),
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: replace,
                      decoration:
                          const InputDecoration(labelText: 'Değiştir'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        final f = find.text;
                        if (f.isEmpty) return;
                        note.content =
                            note.content.replaceAll(f, replace.text);
                        note.updatedAt = DateTime.now();
                        store.commitBulkChanges();
                        setState(() {});
                      },
                      child: const Text('Tümünü değiştir'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CodexPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CodexPanelTitle(
                      icon: Icons.post_add_rounded,
                      title: 'Metin Ekleme',
                      subtitle:
                          'Başa/sona metin, tarih, saat veya ayraç ekle.',
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: append,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Eklenecek metin',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        ActionChip(
                          label: const Text('Başa ekle'),
                          onPressed: () =>
                              _prepend(store, note, append.text),
                        ),
                        ActionChip(
                          label: const Text('Sona ekle'),
                          onPressed: () =>
                              _append(store, note, append.text),
                        ),
                        ActionChip(
                          label: const Text('Tarih damgası'),
                          onPressed: () =>
                              _append(store, note, _dateStamp()),
                        ),
                        ActionChip(
                          label: const Text('Saat damgası'),
                          onPressed: () =>
                              _append(store, note, _timeStamp()),
                        ),
                        ActionChip(
                          label: const Text('Ayraç'),
                          onPressed: () =>
                              _append(store, note, '---'),
                        ),
                        ActionChip(
                          label: const Text('Görev satırı'),
                          onPressed: () =>
                              _append(store, note, '- [ ] '),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CodexPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CodexPanelTitle(
                      icon: Icons.alternate_email_rounded,
                      title: 'Alias & Panoya Aktarma',
                      subtitle:
                          'Alias kaydet veya kayıt metnini farklı biçimlerde kopyala.',
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: alias,
                      decoration:
                          const InputDecoration(labelText: 'Alias'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        FilledButton(
                          onPressed: () {
                            final value = alias.text.trim();
                            if (value.isEmpty) return;
                            final current =
                                (note.properties['aliases'] ?? '')
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toSet();
                            current.add(value);
                            note.properties['aliases'] =
                                current.join(', ');
                            note.propertyTypes['aliases'] = 'text';
                            note.updatedAt = DateTime.now();
                            store.commitBulkChanges();
                            alias.clear();
                            setState(() {});
                          },
                          child: const Text('Alias ekle'),
                        ),
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text:
                                  '${note.title}\n\n${note.content}',
                            ),
                          ),
                          child: const Text('Düz metin kopyala'),
                        ),
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text:
                                  '[[${note.title.trim().isEmpty ? 'Başlıksız' : note.title.trim()}]]',
                            ),
                          ),
                          child: const Text('Wiki link kopyala'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _setTitle(
    VaultStore store,
    NoteRecord note,
    String value,
  ) {
    note.title = value.trim();
    note.updatedAt = DateTime.now();
    store.commitBulkChanges();
    setState(() {});
  }

  void _append(
    VaultStore store,
    NoteRecord note,
    String value,
  ) {
    if (value.trim().isEmpty) return;
    note.content =
        '${note.content.trimRight()}${note.content.trim().isEmpty ? '' : '\n'}$value';
    note.updatedAt = DateTime.now();
    store.commitBulkChanges();
    setState(() {});
  }

  void _prepend(
    VaultStore store,
    NoteRecord note,
    String value,
  ) {
    if (value.trim().isEmpty) return;
    note.content =
        '$value${note.content.trim().isEmpty ? '' : '\n'}${note.content.trimLeft()}';
    note.updatedAt = DateTime.now();
    store.commitBulkChanges();
    setState(() {});
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  String _dateStamp() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _timeStamp() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }
}

Future<void> _showPlusNoteList(
  BuildContext context,
  String title,
  List<NoteRecord> notes,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor:
            Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text(title)),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 7),
          itemBuilder: (context, index) =>
              _CodexVaultTile(note: notes[index]),
        ),
      ),
    ),
  );
}
