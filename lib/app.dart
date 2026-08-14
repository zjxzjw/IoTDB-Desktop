import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_shell.dart';

class IotdbDesktopApp extends StatelessWidget {
  const IotdbDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
        return MaterialApp(
          title: 'IoTDB Desktop',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(brightness: Brightness.light),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: themeMode,
          home: const HomeShell(),
        );
      },
    );
  }
}
