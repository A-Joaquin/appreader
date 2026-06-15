import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which way the reader shows the text vs. the compact translation bar.
///
///  - [enToEs]: body in English, bar shows the Spanish translation (default).
///  - [esToEn]: body in Spanish, bar shows the English original (mirror mode).
///
/// The word_map is bidirectional, so tapping a word works the same in both
/// directions — only which offset pair (`orig_*` vs `trans_*`) is used for the
/// lookup vs. the highlight is swapped. See FLUTTER_DB_CONTRACT §3.
enum TranslationDirection { enToEs, esToEn }

/// Reading theme the user can pick. [system] follows the OS light/dark setting;
/// [sepia] is a warm low-strain palette that has no OS equivalent, so it's
/// modeled here rather than via Flutter's [ThemeMode]. See [AppTheme].
enum ReaderTheme { system, light, sepia, dark }

/// App-wide reading preferences: theme, reading font scale and the translation
/// direction.
///
/// Held high in the widget tree by [ReaderSettingsScope] so any screen can read
/// and mutate it. [theme] and [direction] are persisted (shared_preferences).
class ReaderSettings extends ChangeNotifier {
  ReaderSettings({
    ReaderTheme theme = ReaderTheme.system,
    double fontScale = 1.0,
    TranslationDirection direction = TranslationDirection.enToEs,
  })  : _theme = theme,
        _fontScale = fontScale,
        _direction = direction;

  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.6;
  static const double fontScaleStep = 0.1;

  static const String _directionPrefKey = 'translation_direction';
  static const String _themePrefKey = 'reader_theme';

  ReaderTheme _theme;
  double _fontScale;
  TranslationDirection _direction;

  ReaderTheme get theme => _theme;
  double get fontScale => _fontScale;
  TranslationDirection get direction => _direction;

  bool get canIncreaseFont => _fontScale < maxFontScale - 1e-9;
  bool get canDecreaseFont => _fontScale > minFontScale + 1e-9;

  set theme(ReaderTheme value) {
    if (value == _theme) return;
    _theme = value;
    notifyListeners();
    _persistTheme();
  }

  /// Cycles system → light → sepia → dark → system.
  void cycleTheme() {
    theme = switch (_theme) {
      ReaderTheme.system => ReaderTheme.light,
      ReaderTheme.light => ReaderTheme.sepia,
      ReaderTheme.sepia => ReaderTheme.dark,
      ReaderTheme.dark => ReaderTheme.system,
    };
  }

  void increaseFont() => _setFontScale(_fontScale + fontScaleStep);
  void decreaseFont() => _setFontScale(_fontScale - fontScaleStep);

  void _setFontScale(double value) {
    final clamped = value.clamp(minFontScale, maxFontScale).toDouble();
    if ((clamped - _fontScale).abs() < 1e-9) return;
    _fontScale = clamped;
    notifyListeners();
  }

  /// Flips between English→Spanish and Spanish→English, persisting the choice.
  void toggleDirection() {
    _direction = _direction == TranslationDirection.enToEs
        ? TranslationDirection.esToEn
        : TranslationDirection.enToEs;
    notifyListeners();
    _persistDirection();
  }

  Future<void> _persistDirection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_directionPrefKey, _direction.name);
  }

  Future<void> _persistTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, _theme.name);
  }

  /// Reads the saved direction (defaults to [TranslationDirection.enToEs]).
  /// Called once at startup before building [ReaderSettings].
  static Future<TranslationDirection> loadSavedDirection() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_directionPrefKey);
    for (final d in TranslationDirection.values) {
      if (d.name == saved) return d;
    }
    return TranslationDirection.enToEs;
  }

  /// Reads the saved theme (defaults to [ReaderTheme.system]).
  /// Called once at startup before building [ReaderSettings].
  static Future<ReaderTheme> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themePrefKey);
    for (final t in ReaderTheme.values) {
      if (t.name == saved) return t;
    }
    return ReaderTheme.system;
  }
}

/// Exposes the [ReaderSettings] to descendants and rebuilds dependents when it
/// changes.
class ReaderSettingsScope extends InheritedNotifier<ReaderSettings> {
  const ReaderSettingsScope({
    super.key,
    required ReaderSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static ReaderSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ReaderSettingsScope>();
    assert(scope != null, 'No ReaderSettingsScope found in context');
    return scope!.notifier!;
  }
}
