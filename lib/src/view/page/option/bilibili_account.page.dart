import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:listen2/src/provider/repo/bilibili_account.dart';
import 'package:listen2/src/provider/repo/bilibili_playlists.dart';
import 'package:listen2/src/widget/app_style.dart';
import 'package:music_api/music_api.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BilibiliAccountPage extends ConsumerStatefulWidget {
  const BilibiliAccountPage({super.key, this.trackId});
  final String? trackId;
  @override
  ConsumerState<BilibiliAccountPage> createState() =>
      _BilibiliAccountPageState();
}

class _BilibiliAccountPageState extends ConsumerState<BilibiliAccountPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _expiryTimer;
  BilibiliQrCode? _qr;
  BilibiliQrStatus _status = BilibiliQrStatus.waiting;
  List<BilibiliFavoriteFolder>? _folders;
  int? _avid;
  bool _busy = false;
  bool _polling = false;
  bool _active = true;
  int _qrGeneration = 0;
  String? _error;
  String? _message;
  DateTime? _expiresAt;
  late final BilibiliAccountClient _client;

  @override
  void initState() {
    super.initState();
    _client = ref.read(bilibiliAccountClientProvider);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final user = await ref.read(bilibiliAccountProvider.future);
        if (mounted && user != null && _folders == null) await _loadFolders();
      } catch (error) {
        _handleError(error);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _expiryTimer?.cancel();
    _client.cancelQrLogin();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active && _qr != null) unawaited(_poll());
  }

  void _handleError(Object error) {
    if (!mounted) return;
    if (error is BilibiliApiException && error.code == -101) {
      ref.read(bilibiliAccountProvider.notifier).sessionExpired();
      _folders = null;
    }
    setState(() => _error = error is BilibiliApiException
        ? error.message
        : error is FormatException
            ? error.message
            : '操作失败，请检查网络后重试');
  }

  Future<void> _generate() async {
    if (_busy) return;
    _timer?.cancel();
    _expiryTimer?.cancel();
    _client.cancelQrLogin();
    final generation = ++_qrGeneration;
    setState(() {
      _busy = true;
      _error = null;
      _qr = null;
    });
    try {
      final qr = await _client.generateQrCode();
      if (!mounted || generation != _qrGeneration) return;
      setState(() {
        _qr = qr;
        _expiresAt = DateTime.now().add(const Duration(seconds: 180));
        _status = BilibiliQrStatus.waiting;
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
      _expiryTimer = Timer(const Duration(seconds: 180), _expireQr);
    } catch (error) {
      _handleError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _expireQr() {
    if (!mounted || _status == BilibiliQrStatus.confirmed) return;
    _timer?.cancel();
    _expiryTimer?.cancel();
    _client.cancelQrLogin();
    _qrGeneration++;
    setState(() => _status = BilibiliQrStatus.expired);
  }

  Future<void> _poll() async {
    if (!_active ||
        _polling ||
        _qr == null ||
        _status == BilibiliQrStatus.expired ||
        _status == BilibiliQrStatus.confirmed) return;
    if (DateTime.now().isAfter(_expiresAt!)) {
      _expireQr();
      return;
    }
    _polling = true;
    final generation = _qrGeneration;
    try {
      final status =
          await ref.read(bilibiliAccountProvider.notifier).poll(_qr!.key);
      if (!mounted || generation != _qrGeneration) return;
      setState(() {
        _status = status;
        _error = null;
      });
      if (status == BilibiliQrStatus.confirmed ||
          status == BilibiliQrStatus.expired) {
        _timer?.cancel();
        _expiryTimer?.cancel();
      }
    } catch (error) {
      // Leave the QR visible and retry transient failures until its expiry.
      if (generation == _qrGeneration) _handleError(error);
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadFolders() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.trackId != null) {
        _avid ??= await _client.getVideoAid(widget.trackId!);
      }
      final folders = await _client.getFavoriteFolders(avid: _avid);
      if (mounted) setState(() => _folders = folders);
    } catch (error) {
      _handleError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(BilibiliFavoriteFolder folder) async {
    if (_busy || _avid == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await _client.setFavorite(_avid!, folder.id,
          saved: !folder.containsVideo);
      // Read server state after a successful write; a failed write never changes UI state.
      final folders = await _client.getFavoriteFolders(avid: _avid);
      if (mounted) {
        setState(() {
          _folders = folders;
          _message =
              folder.containsVideo ? '已从 Bilibili 收藏夹移除' : '已收藏到 Bilibili';
        });
      }
    } catch (error) {
      _handleError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createFolder() async {
    final result = await showDialog<(String, bool)>(
        context: context, builder: (_) => const _FolderDialog());
    if (result == null || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _client.createFavoriteFolder(result.$1, isPrivate: result.$2);
      final folders = await _client.getFavoriteFolders(avid: _avid);
      if (mounted) setState(() => _folders = folders);
    } catch (error) {
      _handleError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(BilibiliFavoriteFolder folder) async {
    final result = await showDialog<(String, bool)>(
        context: context,
        builder: (_) => _FolderDialog(importTitle: folder.title));
    if (result == null || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await ref
          .read(bilibiliPlaylistsProvider.notifier)
          .add(result.$1, '${folder.id}');
      if (mounted) setState(() => _message = '已导入歌单「${result.$1}」');
    } catch (error) {
      _handleError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(bilibiliAccountProvider.notifier).logout();
    } catch (_) {
      if (mounted) setState(() => _message = '已清除本机登录；服务器退出请求未完成');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _folders = null;
          _qr = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bilibiliAccountProvider, (_, next) {
      if (next.valueOrNull != null && _folders == null && !_busy) {
        unawaited(_loadFolders());
      }
    });
    final account = ref.watch(bilibiliAccountProvider);
    final user = account.valueOrNull;
    return PageSurface(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading('Bilibili 收藏夹'),
        Expanded(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            if (account.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (account.hasError) ...[
              const Text('无法检查登录状态，请检查网络后重试。'),
              TextButton(
                  onPressed: () => ref.invalidate(bilibiliAccountProvider),
                  child: const Text('重试')),
            ] else if (user == null) ...[
              const Text('登录 Bilibili',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('用 Bilibili 手机客户端扫描二维码，并在手机上确认登录。可用另一台设备扫码。'),
              const SizedBox(height: 20),
              if (_qr != null && _status != BilibiliQrStatus.expired)
                Center(
                    child: QrImageView(
                  data: _qr!.url,
                  size: 220,
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Bilibili 登录二维码',
                )),
              if (_qr != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      _status == BilibiliQrStatus.expired
                          ? '二维码已过期，请刷新'
                          : _status == BilibiliQrStatus.scanned
                              ? '已扫码，请在 Bilibili 中确认登录'
                              : '等待扫码，二维码有效期为 3 分钟',
                      textAlign: TextAlign.center),
                ),
              FilledButton.icon(
                  onPressed: _busy ? null : _generate,
                  icon: const Icon(Icons.qr_code_rounded),
                  label: Text(_qr == null ? '获取登录二维码' : '刷新二维码')),
            ] else ...[
              Text(user.name, style: Theme.of(context).textTheme.titleLarge),
              Text('UID ${user.mid}',
                  style: const TextStyle(color: AppStyle.muted)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: _busy ? null : _loadFolders,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('刷新收藏夹')),
                TextButton(
                    onPressed: _busy ? null : _logout,
                    child: const Text('退出登录')),
              ]),
              const SizedBox(height: 16),
              Text(widget.trackId == null
                  ? '选择收藏夹，导入为应用歌单。'
                  : '选择收藏夹，将这首歌收藏到 Bilibili 或取消收藏。'),
              const SizedBox(height: 12),
              if (_folders == null && !_busy)
                TextButton(
                    onPressed: _loadFolders, child: const Text('加载我的收藏夹')),
              if (_folders?.isEmpty == true) const Text('还没有收藏夹，可以先创建一个。'),
              for (final folder in _folders ?? <BilibiliFavoriteFolder>[])
                Card(
                  child: ListTile(
                    enabled: !_busy,
                    leading: Icon(folder.isPrivate
                        ? Icons.lock_outline_rounded
                        : Icons.folder_outlined),
                    title: Text(folder.title),
                    subtitle: Text(
                        '${folder.count} 个视频 · ${folder.isPrivate ? '私密' : '公开'}${widget.trackId != null && folder.containsVideo ? ' · 已收藏' : ''}'),
                    trailing: widget.trackId == null
                        ? const Icon(Icons.download_rounded)
                        : Icon(folder.containsVideo
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded),
                    onTap: () => widget.trackId == null
                        ? _import(folder)
                        : _toggle(folder),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _busy ? null : _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('新建 Bilibili 收藏夹')),
            ],
            if (_busy)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            if (_message != null)
              Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_message!)),
          ],
        )),
      ],
    ));
  }
}

class _FolderDialog extends StatefulWidget {
  const _FolderDialog({this.importTitle});
  final String? importTitle;
  @override
  State<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<_FolderDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.importTitle);
  bool _private = true;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.importTitle == null ? '新建 Bilibili 收藏夹' : '导入为歌单'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      controller: _name,
                      autofocus: true,
                      decoration: InputDecoration(
                          labelText:
                              widget.importTitle == null ? '收藏夹名称' : '应用歌单名称'),
                      validator: (value) =>
                          value?.trim().isEmpty ?? true ? '请输入名称' : null),
                  if (widget.importTitle == null)
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('私密收藏夹'),
                        value: _private,
                        onChanged: (value) => setState(() => _private = value)),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, (_name.text.trim(), _private));
                }
              },
              child: Text(widget.importTitle == null ? '创建' : '导入')),
        ],
      );
}
