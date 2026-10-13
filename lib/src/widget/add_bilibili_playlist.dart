import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/view/page/option/bilibili_account.page.dart';
import 'package:listen2/src/widget/app_style.dart';
import 'package:music_api/music_api.dart';

Future<String?> showAddBilibiliPlaylist(BuildContext context,
        {bool localOnly = false}) =>
    showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AddPlaylist(localOnly: localOnly));

enum _PlaylistSource { local, bilibili }

class _AddPlaylist extends ConsumerStatefulWidget {
  const _AddPlaylist({required this.localOnly});
  final bool localOnly;
  @override
  ConsumerState<_AddPlaylist> createState() => _AddPlaylistState();
}

class _AddPlaylistState extends ConsumerState<_AddPlaylist> {
  static const _importColor = Color(0xFF9A6845);
  var _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _source = TextEditingController();
  _PlaylistSource _selected = _PlaylistSource.local;
  bool _busy = false;
  String? _error;
  bool get _local => _selected == _PlaylistSource.local;
  Color get _color => _local ? AppStyle.accent : _importColor;

  @override
  void dispose() {
    _name.dispose();
    _source.dispose();
    super.dispose();
  }

  void _select(_PlaylistSource source) {
    if (_busy || source == _selected) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = source;
      _error = null;
      _form = GlobalKey<FormState>();
    });
  }

  String? _validateSource(String? value) {
    if (value?.trim().isEmpty ?? true) return '请输入收藏夹链接或 ID';
    try {
      parseBilibiliFavoriteId(value!);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
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
          .add(_name.text, _local ? '' : parseBilibiliFavoriteId(_source.text));
      if (mounted) Navigator.pop(context, _name.text.trim());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is FormatException
            ? error.message
            : error is BilibiliApiException
                ? error.message
                : _local
                    ? '歌单创建失败，请重试'
                    : '导入失败，请检查收藏夹链接、访问权限或网络后重试';
      });
    }
  }

  Future<void> _fromAccount() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = await Navigator.of(context).push<String>(MaterialPageRoute(
          builder: (_) =>
              const BilibiliAccountPage(returnImportedPlaylist: true)));
      if (mounted && name != null) Navigator.pop(context, name);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: AppStyle.background,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        scrollable: true,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('新增歌单'),
          const SizedBox(height: 8),
          Text(widget.localOnly ? '为这首歌，留一个新的位置。' : '从空白开始，或把收藏夹带进来。',
              style: const TextStyle(
                  fontSize: 13, color: AppStyle.muted, height: 1.6)),
        ]),
        content: SizedBox(
            width: 420,
            child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.localOnly) ...[
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _sourceCard(_PlaylistSource.local,
                                      icon: Icons.library_music_outlined,
                                      title: '本地创建',
                                      detail: '自由整理',
                                      color: AppStyle.accent)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _sourceCard(_PlaylistSource.bilibili,
                                      icon: Icons.cloud_download_outlined,
                                      title: '平台导入',
                                      detail: 'Bilibili',
                                      color: _importColor)),
                            ]),
                        const SizedBox(height: 20),
                      ],
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: _color.withOpacity(.08),
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                  _local
                                      ? Icons.album_outlined
                                      : Icons.sync_rounded,
                                  color: _color,
                                  size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        _local
                                            ? '属于你的空白唱片'
                                            : '把 Bilibili 收藏带进唱片架',
                                        style: TextStyle(
                                            color: _color,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 5),
                                    Text(
                                        _local
                                            ? '创建空白歌单，在应用内自由添加、移除歌曲。'
                                            : '导入收藏夹中的歌曲，登录所属账号后可同步收藏。',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.6,
                                            color: AppStyle.muted)),
                                  ])),
                            ]),
                      ),
                      const SizedBox(height: 20),
                      if (!_local) ...[
                        TextFormField(
                            key: const ValueKey('playlist-import-source'),
                            controller: _source,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                                labelText: '收藏夹链接或 ID',
                                hintText: '粘贴 Bilibili 链接或数字 ID',
                                helperText: '支持链接中的 fid 或 ml 收藏夹 ID',
                                helperMaxLines: 2),
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            validator: _validateSource),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                          key: const ValueKey('playlist-name'),
                          controller: _name,
                          enabled: !_busy,
                          decoration: InputDecoration(
                              labelText: '歌单名称',
                              hintText: _local ? '例如：夜晚散步' : '为导入的歌单取个名字'),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _add(),
                          validator: (value) =>
                              value?.trim().isEmpty ?? true ? '请输入歌单名称' : null),
                      const SizedBox(height: 12),
                      Text(
                          _local
                              ? '保存在本机，不会在 Bilibili 创建收藏夹。'
                              : '收藏操作会同步到 Bilibili；其他用户的收藏夹仅可查看。',
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: AppStyle.muted)),
                      if (!_local) ...[
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: _importColor),
                            onPressed: _busy ? null : _fromAccount,
                            icon: const Icon(Icons.account_circle_outlined,
                                size: 20),
                            label: const Text('从我的收藏夹选择')),
                        const SizedBox(height: 6),
                        const Text('扫码登录后，也能选择自己的私密收藏夹。',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: AppStyle.muted)),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      ],
                    ]))),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _color),
              onPressed: _busy ? null : _add,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_local ? Icons.add_rounded : Icons.download_rounded,
                      size: 18),
              label: Text(_local ? '创建本地歌单' : '导入收藏夹')),
        ],
      ));

  Widget _sourceCard(_PlaylistSource source,
      {required IconData icon,
      required String title,
      required String detail,
      required Color color}) {
    final selected = _selected == source;
    return Semantics(
        button: true,
        selected: selected,
        child: Material(
          color:
              selected ? color.withOpacity(.1) : Colors.white.withOpacity(.7),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: _busy ? null : () => _select(source),
            borderRadius: BorderRadius.circular(18),
            child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color:
                            selected ? color : AppStyle.muted.withOpacity(.15),
                        width: selected ? 1.5 : 1)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(icon, size: 24, color: color),
                        const Spacer(),
                        Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 16,
                            color: selected
                                ? color
                                : AppStyle.muted.withOpacity(.4)),
                      ]),
                      const SizedBox(height: 12),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppStyle.ink,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(detail,
                          style: TextStyle(fontSize: 12, color: color)),
                    ])),
          ),
        ));
  }
}
