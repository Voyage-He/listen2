import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';

Future<String?> showAddBilibiliPlaylist(BuildContext context,
        {bool localOnly = false}) =>
    showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AddBilibiliPlaylist(localOnly: localOnly));

class _AddBilibiliPlaylist extends ConsumerStatefulWidget {
  const _AddBilibiliPlaylist({required this.localOnly});
  final bool localOnly;
  @override
  ConsumerState<_AddBilibiliPlaylist> createState() =>
      _AddBilibiliPlaylistState();
}

class _AddBilibiliPlaylistState extends ConsumerState<_AddBilibiliPlaylist> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _id = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(bilibiliPlaylistsProvider.notifier)
          .add(_name.text, _id.text);
      if (mounted) Navigator.pop(context, _name.text.trim());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is FormatException
            ? error.message
            : _id.text.trim().isEmpty
                ? '歌单创建失败，请重试'
                : '添加失败，请检查收藏夹 ID、公开权限或网络后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('添加歌单'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (!widget.localOnly) ...[
                    TextFormField(
                        controller: _id,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                            labelText: 'Bilibili 收藏夹 ID（选填）',
                            helperText: '留空创建空白歌单；导入时填写链接中的 fid',
                            helperMaxLines: 2),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value?.trim().isEmpty ?? true) ||
                                RegExp(r'^[1-9][0-9]*$').hasMatch(value!.trim())
                            ? null
                            : '请输入有效的收藏夹 ID'),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      decoration: const InputDecoration(labelText: '歌单名称'),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _add(),
                      validator: (value) =>
                          value?.trim().isEmpty ?? true ? '请输入歌单名称' : null),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ]))),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
              onPressed: _busy ? null : _add,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('添加')),
        ],
      ));
}
