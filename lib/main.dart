import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/settings/reader_settings.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_controller.dart';

const _supabaseUrl = 'https://ewyiuywiyykekoearvlo.supabase.co';
const _supabasePublishableKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV3eWl1eXdpeXlrZWtvZWFydmxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0NTAyMTcsImV4cCI6MjA5NjAyNjIxN30.faabc5HgHW9lX_YBePvmPV1e-FJGu55EXCyytbs3rLk';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  // Touch the singleton so it subscribes to auth changes before the router
  // builds and starts evaluating redirects.
  AuthController.instance;
  final direction = await ReaderSettings.loadSavedDirection();
  final theme = await ReaderSettings.loadSavedTheme();
  runApp(BlackReaderApp(initialDirection: direction, initialTheme: theme));
}

class BlackReaderApp extends StatefulWidget {
  const BlackReaderApp({
    super.key,
    required this.initialDirection,
    required this.initialTheme,
  });

  final TranslationDirection initialDirection;
  final ReaderTheme initialTheme;

  @override
  State<BlackReaderApp> createState() => _BlackReaderAppState();
}

class _BlackReaderAppState extends State<BlackReaderApp> {
  late final ReaderSettings _settings = ReaderSettings(
    direction: widget.initialDirection,
    theme: widget.initialTheme,
  );

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsScope(
      settings: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => MaterialApp.router(
          title: 'BlackReader',
          debugShowCheckedModeBanner: false,
          // Sepia has no OS equivalent, so it rides the "light" slot and we
          // force themeMode to light when it's picked. system/light/dark behave
          // as usual against the (softened) light & dark palettes.
          theme: _settings.theme == ReaderTheme.sepia
              ? AppTheme.sepia
              : AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: switch (_settings.theme) {
            ReaderTheme.system => ThemeMode.system,
            ReaderTheme.light => ThemeMode.light,
            ReaderTheme.sepia => ThemeMode.light,
            ReaderTheme.dark => ThemeMode.dark,
          },
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
