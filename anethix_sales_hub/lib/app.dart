import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';

class AnethixSalesHubApp extends ConsumerStatefulWidget {
  const AnethixSalesHubApp({super.key});

  @override
  ConsumerState<AnethixSalesHubApp> createState() => _AnethixSalesHubAppState();
}

class _AnethixSalesHubAppState extends ConsumerState<AnethixSalesHubApp> {
  late final NotificationService _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = NotificationService(
      navigatorKey: rootNavigatorKey,
      messengerKey: rootMessengerKey,
    );
    // Deferred past the first frame: the permission prompt should land on a
    // rendered app, and a notification tap needs a router to navigate with.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifications.initialize();
    });
  }

  @override
  void dispose() {
    _notifications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        // Keep layout predictable regardless of the device font-size setting.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.25,
            ),
          ),
          child: _MobileFrame(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Holds the app to a phone-sized column on the web.
///
/// The UI is designed for a phone, so on a desktop browser it is centred in a
/// 480px column instead of being stretched across the window. Everything the
/// router puts on screen — pages, dialogs, bottom sheets, snackbars — sits
/// inside this frame, because it wraps the navigator itself.
///
/// On Android (and any narrow window) this is a no-op: the child is returned
/// untouched, so the phone build is byte-for-byte the layout it always was.
class _MobileFrame extends StatelessWidget {
  const _MobileFrame({required this.child});

  static const double _maxWidth = 480;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= _maxWidth) return child;

        final scheme = Theme.of(context).colorScheme;
        return ColoredBox(
          // The gutter either side of the phone column.
          color: Color.alphaBlend(
            scheme.surfaceTint.withValues(alpha: 0.04),
            scheme.surfaceContainerHighest,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              // A Material ancestor keeps ink splashes and elevation painting
              // correctly inside the column.
              child: Material(color: scheme.surface, child: child),
            ),
          ),
        );
      },
    );
  }
}
