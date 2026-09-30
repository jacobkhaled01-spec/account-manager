import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/storage/local_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/settings/providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // معالجة استثناءات إطار العمل المعروفة في بيئة سطح المكتب (مثل حركة مؤشر الأسهم في وضع التطوير)
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('VerticalCaretMovementRun') ||
        msg.contains('editable.dart') ||
        msg.contains('isValid')) {
      return;
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final msg = error.toString();
    if (msg.contains('VerticalCaretMovementRun') ||
        msg.contains('editable.dart') ||
        msg.contains('isValid')) {
      return true;
    }
    return false;
  };

  // Initialize offline-first local storage
  await LocalStorageService.instance.init();

  runApp(
    const ProviderScope(
      child: AlQassamApp(),
    ),
  );
}

class AlQassamApp extends ConsumerWidget {
  const AlQassamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final bureauName = ref.watch(bureauNameProvider);
    final isLoggedIn = ref.watch(authStateProvider);

    return MaterialApp(
      title: bureauName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: isLoggedIn ? const HomeShell() : const LoginScreen(),
    );
  }
}
