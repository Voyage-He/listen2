import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:listen2/src/widget/app_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/playlist_backup.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';

class Option extends ConsumerStatefulWidget {
  const Option({super.key});

  @override
  ConsumerState<Option> createState() => _OptionState();
}

class _OptionState extends ConsumerState<Option> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<String?> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await operation();
      if (mounted) setState(() => _message = message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = '备份操作失败，请检查文件后重试。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _exportBackup() async {
    final bytes = PlaylistBackup.encode(
        ref.read(playlistIdsNotifierProvider('favorite')));
    // On iOS/Android the native document picker writes these bytes itself.
    final path = await FilePicker.platform.saveFile(
      fileName: 'listen2.back',
      bytes: bytes,
    );
    if (path == null) return null;
    if (!Platform.isIOS && !Platform.isAndroid) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return '收藏备份已导出';
  }

  Future<String?> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return null;
    final file = result.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final favorites = PlaylistBackup.decode(bytes);
    if (!mounted) return null;
    ref.read(playlistIdsNotifierProvider('favorite').notifier).set(favorites);
    return '收藏备份已导入';
  }

  @override
  Widget build(BuildContext context) => PageSurface(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading('设置'),
          Expanded(
              child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                Text('音乐与备份', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('保存你的收藏，换设备也能继续聆听。',
                    style: TextStyle(color: AppStyle.muted, fontSize: 14)),
                const SizedBox(height: 24),
                _backupTile(Icons.upload_rounded, '导出收藏备份', '将我喜欢的音乐保存到文件',
                    () => _run(_exportBackup)),
                const SizedBox(height: 12),
                _backupTile(Icons.download_rounded, '导入收藏备份', '用备份文件替换当前收藏',
                    () => _run(_importBackup)),
                if (_busy)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator())),
                if (_message != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(_message!,
                          style: Theme.of(context).textTheme.bodyLarge)),
              ])),
        ],
      ));

  Widget _backupTile(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
            enabled: !_busy,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: Icon(icon, color: AppStyle.accent),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap),
      );
}
