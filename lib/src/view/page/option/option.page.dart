import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/playlist_backup.dart';
import 'package:listen2/src/provider/repo/playlist_tracks_id.dart';
import 'package:listen2/src/widget/button/button.dart';

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
        setState(() =>
            _message = 'Backup failed. Please check the file and try again.');
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
    return 'Backup exported';
  }

  Future<String?> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return null;
    final file = result.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final favorites = PlaylistBackup.decode(bytes);
    if (!mounted) return null;
    ref.read(playlistIdsNotifierProvider('favorite').notifier).set(favorites);
    return 'Backup imported';
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Button(
            onTap: () => Navigator.of(context).pop(),
            child: const Text('return'),
          ),
          Button(
            disabled: _busy,
            onTap: () => _run(_exportBackup),
            child: const Text('export backup'),
          ),
          Button(
            disabled: _busy,
            onTap: () => _run(_importBackup),
            child: const Text('import backup'),
          ),
          if (_message != null) Text(_message!),
        ],
      );
}
