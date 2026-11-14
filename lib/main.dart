import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/settings/reader_settings.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'data/background/background_download.dart';
import 'data/background/download_notifications.dart';
import 'data/repositories/auth_controller.dart';
import 'data/repositories/download_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  // Resolve the session (from local storage, never the network) before the
  // router builds, so a user who already logged in once opens straight into
  // the library even with no connection.
  await AuthController.instance.warmUp();
  // Descargas en segundo plano (Android): el canal con el servicio, los
  // avisos de «libro listo», y retomar lo que quedara a medias.
  BackgroundDownloads.init();
  await DownloadNotifications.init(handleTaps: true);
  unawaited(DownloadManager.instance.attach());
  final direction = await ReaderSettings.loadSavedDirection();
  final theme = await ReaderSettings.loadSavedTheme();
  final audioEnabled = await ReaderSettings.loadSavedAudioEnabled();
  runApp(
    BlackReaderApp(
      initialDirection: direction,
      initialTheme: theme,
      initialAudioEnabled: audioEnabled,
    ),
  );
}

class BlackReaderApp extends StatefulWidget {
  const BlackReaderApp({
    super.key,
    required this.initialDirection,
    required this.initialTheme,
    this.initialAudioEnabled = true,
  });

  final TranslationDirection initialDirection;
  final ReaderTheme initialTheme;
  final bool initialAudioEnabled;

  @override
  State<BlackReaderApp> createState() => _BlackReaderAppState();
}

class _BlackReaderAppState extends State<BlackReaderApp> {
  late final ReaderSettings _settings = ReaderSettings(
    direction: widget.initialDirection,
    theme: widget.initialTheme,
    audioEnabled: widget.initialAudioEnabled,
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
