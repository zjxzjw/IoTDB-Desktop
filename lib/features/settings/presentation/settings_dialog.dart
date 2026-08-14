import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/providers.dart';
import '../../../core/storage/app_settings_store.dart';
import '../../../core/theme/shadcn_tokens.dart';

/// 打开应用设置对话框
Future<void> showSettingsDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _SettingsDialog(),
  );
}

class _SettingsDialog extends ConsumerWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final sidebarWidth =
        ref.watch(sidebarWidthProvider).value ?? AppSettingsStore.defaultSidebarWidth;

    return AlertDialog(
      title: const Text('设置'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '主题',
              style: TextStyle(
                fontSize: ShadTokens.fontAux,
                fontWeight: FontWeight.w600,
                color: ShadTokens.mutedForeground,
              ),
            ),
            const SizedBox(height: ShadTokens.space2),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('浅色'),
                  icon: Icon(RemixIcons.sun_line, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('深色'),
                  icon: Icon(RemixIcons.moon_line, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('跟随系统'),
                  icon: Icon(RemixIcons.computer_line, size: 16),
                ),
              ],
              selected: {themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                ref.read(themeModeProvider.notifier).setMode(
                  selection.first,
                );
              },
            ),
            const SizedBox(height: ShadTokens.space6),
            const Text(
              '界面',
              style: TextStyle(
                fontSize: ShadTokens.fontAux,
                fontWeight: FontWeight.w600,
                color: ShadTokens.mutedForeground,
              ),
            ),
            const SizedBox(height: ShadTokens.space2),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '侧边栏宽度',
                    style: TextStyle(fontSize: ShadTokens.fontBody),
                  ),
                ),
                Text(
                  '${sidebarWidth.round()}px',
                  style: const TextStyle(
                    fontSize: ShadTokens.fontAux,
                    color: ShadTokens.mutedForeground,
                  ),
                ),
                const SizedBox(width: ShadTokens.space3),
                OutlinedButton(
                  onPressed: () => ref
                      .read(sidebarWidthProvider.notifier)
                      .setWidth(AppSettingsStore.defaultSidebarWidth),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('重置'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('完成'),
        ),
      ],
    );
  }
}
