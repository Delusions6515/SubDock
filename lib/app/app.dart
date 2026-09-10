import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_all/webview_all.dart';

import '../l10n/generated/app_localizations.dart';
import '../runtime/backend_runtime.dart';
import '../settings/backend_env.dart';
import '../settings/subdock_config.dart';
import '../update/component_metadata_store.dart';
import '../update/component_update_checker.dart';
import '../update/component_update_service.dart';
import 'app_coordinator.dart';

const navigationBreakpoint = 600.0;

enum _AppPage { manage, runtime, logs, settings }

class SubDockApp extends StatefulWidget {
  const SubDockApp({
    super.key,
    required this.coordinator,
    this.autoStart = true,
    this.enableWebView = true,
    this.initialError,
    this.desktopWarning,
    this.onMinimize,
    this.onToggleFullscreen,
    this.onCloseToTray,
  });

  final AppCoordinator coordinator;
  final bool autoStart;
  final bool enableWebView;
  final String? initialError;
  final ValueListenable<String?>? desktopWarning;
  final Future<void> Function()? onMinimize;
  final Future<void> Function()? onToggleFullscreen;
  final Future<void> Function()? onCloseToTray;

  @override
  State<SubDockApp> createState() => _SubDockAppState();
}

class _SubDockAppState extends State<SubDockApp> {
  late final StreamSubscription<RuntimeState> _stateSubscription;
  late final StreamSubscription<RuntimeLog> _logSubscription;
  late final AppLifecycleListener _lifecycleListener;
  late RuntimeState _state;
  final _logs = <RuntimeLog>[];
  _AppPage _page = _AppPage.manage;
  BackendInfo? _info;
  String? _error;
  var _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _state = widget.coordinator.runtime.currentState;
    _error = widget.initialError;
    if (_error != null) _page = _AppPage.runtime;
    _stateSubscription = widget.coordinator.runtime.state.listen(_onState);
    _logSubscription = widget.coordinator.runtime.logs.listen(_appendLog);
    _lifecycleListener = AppLifecycleListener(
      onDetach: () => unawaited(widget.coordinator.dispose()),
    );
    widget.desktopWarning?.addListener(_onDesktopWarning);
    unawaited(_loadLogTail());
    if (widget.autoStart) unawaited(_autoStart());
  }

  @override
  void dispose() {
    widget.desktopWarning?.removeListener(_onDesktopWarning);
    _lifecycleListener.dispose();
    _stateSubscription.cancel();
    _logSubscription.cancel();
    super.dispose();
  }

  void _onDesktopWarning() {
    if (mounted) setState(() {});
  }

  Future<void> _autoStart() async {
    try {
      await widget.coordinator.start();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _page = _AppPage.runtime;
        _error = '$error';
      });
    }
  }

  void _onState(RuntimeState state) {
    if (!mounted) return;
    setState(() => _state = state);
    if (state.status == RuntimeStatus.running) unawaited(_loadInfo());
  }

  void _appendLog(RuntimeLog log) {
    if (!mounted) return;
    setState(() {
      _logs.add(log);
      if (_logs.length > 2000) _logs.removeRange(0, _logs.length - 2000);
    });
  }

  Future<void> _loadLogTail() async {
    final file = File.fromUri(
      widget.coordinator.environmentStore.directories.logs.uri.resolve(
        'backend.log',
      ),
    );
    if (!await file.exists()) return;
    final length = await file.length();
    final start = length > 64 * 1024 ? length - 64 * 1024 : 0;
    final lines = await file
        .openRead(start)
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();
    for (final line in lines) {
      _appendLog(
        RuntimeLog(
          timestamp: DateTime.now(),
          source: RuntimeLogSource.stdout,
          message: line,
        ),
      );
    }
  }

  Future<void> _loadInfo() async {
    try {
      final info = await widget.coordinator.runtime.info();
      if (mounted) setState(() => _info = info);
    } on StateError {
      // The runtime state holds the actionable failure.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _saveEnvironment(BackendEnvDocument document) async {
    if (_actionInProgress) throw StateError('已有操作正在进行');
    setState(() {
      _actionInProgress = true;
      _error = null;
    });
    try {
      await widget.coordinator.saveEnvironment(document);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
      rethrow;
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SubDock',
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Builder(builder: _buildHome),
    );
  }

  Widget _buildHome(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(l10n.manage),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.memory_outlined),
        selectedIcon: const Icon(Icons.memory),
        label: Text(l10n.runtimeStatus),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.subject_outlined),
        selectedIcon: const Icon(Icons.subject),
        label: Text(l10n.logs),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(l10n.settings),
      ),
    ];
    final pages = <Widget>[
      _ManagePage(
        state: _state,
        coordinator: widget.coordinator,
        error: _error,
        enabled: widget.enableWebView,
        onRecover: () => setState(
          () => _page = widget.coordinator.canOpenWebUi
              ? _AppPage.runtime
              : _AppPage.settings,
        ),
      ),
      _RuntimePage(
        state: _state,
        info: _info,
        error: _error,
        actionInProgress: _actionInProgress,
        onStart: () => _run(widget.coordinator.start),
        onStop: () => _run(widget.coordinator.stop),
        onRestart: () => _run(widget.coordinator.restart),
      ),
      _LogsPage(logs: _logs),
      _SettingsPage(
        environment: widget.coordinator.environment,
        configuration: widget.coordinator.configuration,
        configurationError: widget.coordinator.configurationError,
        coordinator: widget.coordinator,
        onSave: _saveEnvironment,
        onSaveConfiguration: (configuration) =>
            _run(() => widget.coordinator.saveConfiguration(configuration)),
        onResetConfiguration: () => _run(widget.coordinator.resetConfiguration),
        onRestart: () => _run(widget.coordinator.restart),
      ),
    ];
    final body = Stack(
      children: [
        for (var index = 0; index < pages.length; index++)
          Offstage(
            key: ValueKey('page-${_AppPage.values[index].name}'),
            offstage: index != _page.index,
            child: pages[index],
          ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (widget.onMinimize != null)
            IconButton(
              tooltip: '最小化',
              onPressed: () => unawaited(widget.onMinimize!()),
              icon: const Icon(Icons.minimize),
            ),
          if (widget.onToggleFullscreen != null)
            IconButton(
              tooltip: '切换全屏',
              onPressed: () => unawaited(widget.onToggleFullscreen!()),
              icon: const Icon(Icons.fullscreen),
            ),
          if (widget.onCloseToTray != null)
            IconButton(
              tooltip: '关闭到托盘',
              onPressed: () => unawaited(widget.onCloseToTray!()),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.desktopWarning?.value case final warning?)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(warning),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < navigationBreakpoint) {
                  return Column(
                    children: [
                      Expanded(child: body),
                      NavigationBar(
                        selectedIndex: _page.index,
                        onDestinationSelected: (index) =>
                            setState(() => _page = _AppPage.values[index]),
                        destinations: destinations
                            .map(
                              (destination) => NavigationDestination(
                                icon: destination.icon,
                                selectedIcon: destination.selectedIcon,
                                label: (destination.label as Text).data!,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _page.index,
                      onDestinationSelected: (index) =>
                          setState(() => _page = _AppPage.values[index]),
                      labelType: NavigationRailLabelType.all,
                      destinations: destinations,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagePage extends StatefulWidget {
  const _ManagePage({
    required this.state,
    required this.coordinator,
    required this.error,
    required this.enabled,
    required this.onRecover,
  });

  final RuntimeState state;
  final AppCoordinator coordinator;
  final String? error;
  final bool enabled;
  final VoidCallback onRecover;

  @override
  State<_ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<_ManagePage> {
  static const _maxBlobBytes = 16 * 1024 * 1024;
  static final _webView2DownloadUri = Uri.parse(
    'https://developer.microsoft.com/microsoft-edge/webview2/',
  );

  WebViewController? _controller;
  String? _webViewError;
  var _missingWebView2 = false;

  bool get _ready =>
      widget.state.status == RuntimeStatus.running &&
      widget.enabled &&
      widget.coordinator.canOpenWebUi;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureController());
  }

  @override
  void didUpdateWidget(covariant _ManagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) {
      _controller = null;
      return;
    }
    unawaited(_ensureController());
  }

  Future<void> _ensureController() async {
    if (!_ready || _controller != null) return;
    final controller = WebViewController();
    setState(() {
      _controller = controller;
      _webViewError = null;
      _missingWebView2 = false;
    });
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(onNavigationRequest: _onNavigationRequest),
      );
      await controller.addJavaScriptChannel(
        'SubDockBlob',
        onMessageReceived: (message) => unawaited(_saveBlob(message.message)),
      );
      await controller.addUserScript(
        const WebViewUserScript(source: _blobDownloadBridge),
      );
      await controller.loadRequest(widget.coordinator.webUiUri);
    } catch (error) {
      if (mounted) {
        setState(() {
          _missingWebView2 = _isMissingWebView2(error);
          _webViewError = _missingWebView2
              ? '未检测到 Microsoft Edge WebView2 Runtime。请安装后重试。'
              : '$error';
        });
      }
    }
  }

  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (_sameOrigin(uri, widget.coordinator.webUiUri)) {
      if (_isDownloadUri(uri)) {
        unawaited(_saveHttpDownload(uri));
        return NavigationDecision.prevent;
      }
      return NavigationDecision.navigate;
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      try {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw StateError('系统浏览器无法打开 $uri');
        }
      } catch (error) {
        if (mounted) setState(() => _webViewError = '$error');
      }
    }
    return NavigationDecision.prevent;
  }

  Future<void> _saveHttpDownload(Uri uri) async {
    try {
      final location = await getSaveLocation(
        suggestedName: _downloadName(uri.pathSegments.lastOrNull),
      );
      if (location == null) return;

      final client = HttpClient();
      try {
        final response = await (await client.getUrl(uri)).close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('下载失败：HTTP ${response.statusCode}', uri: uri);
        }
        final sink = File(location.path).openWrite();
        try {
          await response.forEach(sink.add);
          await sink.flush();
        } finally {
          await sink.close();
        }
      } finally {
        client.close(force: true);
      }
    } catch (error) {
      if (mounted) setState(() => _webViewError = '$error');
    }
  }

  Future<void> _saveBlob(String message) async {
    try {
      final payload = jsonDecode(message);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Blob 导出数据格式无效');
      }
      if (payload['error'] case final String error) throw StateError(error);
      final data = payload['data'];
      if (data is! String || data.length > (_maxBlobBytes * 4 ~/ 3) + 4) {
        throw const FormatException('Blob 导出超过 16 MiB 限制');
      }
      final bytes = base64Decode(data);
      if (bytes.length > _maxBlobBytes) {
        throw const FormatException('Blob 导出超过 16 MiB 限制');
      }
      final location = await getSaveLocation(
        suggestedName: _downloadName(payload['name'] as String?),
      );
      if (location == null) return;
      await File(location.path).writeAsBytes(bytes, flush: true);
    } catch (error) {
      if (mounted) setState(() => _webViewError = '$error');
    }
  }

  static bool _sameOrigin(Uri first, Uri second) =>
      first.scheme == second.scheme &&
      first.host == second.host &&
      first.port == second.port;

  bool _isMissingWebView2(Object error) {
    if (!Platform.isWindows) return false;
    final message = '$error'.toLowerCase();
    return message.contains('webview2') || message.contains('edge runtime');
  }

  Future<void> _openWebView2Download() async {
    if (!await launchUrl(
      _webView2DownloadUri,
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        setState(() => _webViewError = '系统浏览器无法打开 WebView2 下载页面');
      }
    }
  }

  bool _isDownloadUri(Uri uri) {
    final path = widget.coordinator.webUiApiUri.path;
    final prefix = path == '/' ? '' : path.replaceFirst(RegExp(r'/$'), '');
    return uri.path == '$prefix/download' ||
        uri.path.startsWith('$prefix/download/');
  }

  static String _downloadName(String? value) {
    final name = (value == null || value.isEmpty ? 'download' : value)
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return name.isEmpty || name == '.' || name == '..' ? 'download' : name;
  }

  static const _blobDownloadBridge = r'''(() => {
  document.addEventListener('click', async event => {
    if (!(event.target instanceof Element)) return;
    const link = event.target.closest('a[download]');
    if (!link || !link.href.startsWith('blob:')) return;
    event.preventDefault();
    try {
      const blob = await (await fetch(link.href)).blob();
      if (blob.size > 16 * 1024 * 1024) {
        SubDockBlob.postMessage(JSON.stringify({error: 'Blob export exceeds 16 MiB'}));
        return;
      }
      const reader = new FileReader();
      reader.onload = () => SubDockBlob.postMessage(JSON.stringify({
        name: link.download || 'download',
        data: String(reader.result).split(',', 2)[1],
      }));
      reader.readAsDataURL(blob);
    } catch (error) {
      SubDockBlob.postMessage(JSON.stringify({error: String(error)}));
    }
  }, true);
})();''';

  @override
  Widget build(BuildContext context) {
    if (widget.state.status == RuntimeStatus.starting ||
        widget.state.status == RuntimeStatus.stopping) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_ready || _controller == null) {
      final reason = widget.coordinator.environmentIssues.isNotEmpty
          ? widget.coordinator.environmentIssues.first.message
          : widget.error ?? widget.state.message ?? 'Backend 未运行';
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.web_asset_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(reason, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onRecover,
                child: Text(
                  widget.coordinator.canOpenWebUi ? '查看运行状态' : '修复配置',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _controller!)),
        if (_webViewError != null)
          Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_webViewError!),
                    if (_missingWebView2)
                      TextButton(
                        onPressed: () => unawaited(_openWebView2Download()),
                        child: const Text('打开 WebView2 官方下载页'),
                      ),
                  ],
                ),
                // The button is rendered only for the Windows runtime error
                // that has a documented user-installable remedy.
              ),
            ),
          ),
      ],
    );
  }
}

class _RuntimePage extends StatelessWidget {
  const _RuntimePage({
    required this.state,
    required this.info,
    required this.error,
    required this.actionInProgress,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
  });

  final RuntimeState state;
  final BackendInfo? info;
  final String? error;
  final bool actionInProgress;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (state.status) {
      RuntimeStatus.stopped => l10n.stopped,
      RuntimeStatus.starting => l10n.starting,
      RuntimeStatus.running => l10n.running,
      RuntimeStatus.stopping => l10n.stopping,
      RuntimeStatus.unhealthy => l10n.unhealthy,
      RuntimeStatus.crashed => l10n.crashed,
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(label, style: Theme.of(context).textTheme.headlineMedium),
        if (error ?? state.message case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        _InfoRow(label: 'Node', value: info?.nodeVersion),
        _InfoRow(label: 'Backend', value: info?.backendVersion),
        _InfoRow(label: 'Port', value: info == null ? null : '${info!.port}'),
        _InfoRow(
          label: 'HTTP-META',
          value: switch (state.httpMetaStatus) {
            HttpMetaStatus.disabled => '已禁用',
            HttpMetaStatus.unavailable =>
              '不可用${state.httpMetaMessage == null ? '' : '：${state.httpMetaMessage}'}',
            HttpMetaStatus.starting => '启动中',
            HttpMetaStatus.running =>
              '运行中，端口 ${state.httpMetaPort ?? '-'}，版本 ${state.httpMetaVersion ?? '-'}',
            HttpMetaStatus.degraded =>
              '已降级${state.httpMetaMessage == null ? '' : '：${state.httpMetaMessage}'}',
            HttpMetaStatus.stopped => '已停止',
          },
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed:
                  actionInProgress || state.status == RuntimeStatus.running
                  ? null
                  : onStart,
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.start),
            ),
            OutlinedButton.icon(
              onPressed:
                  actionInProgress || state.status == RuntimeStatus.stopped
                  ? null
                  : onStop,
              icon: const Icon(Icons.stop),
              label: Text(l10n.stop),
            ),
            OutlinedButton.icon(
              onPressed:
                  actionInProgress || state.status != RuntimeStatus.running
                  ? null
                  : onRestart,
              icon: const Icon(Icons.restart_alt),
              label: Text(l10n.restart),
            ),
          ],
        ),
      ],
    );
  }
}

class _LogsPage extends StatelessWidget {
  const _LogsPage({required this.logs});

  final List<RuntimeLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const Center(child: Text('暂无日志'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return SelectableText(
          '${log.timestamp.toIso8601String()} [${log.source.name}] ${log.message}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        );
      },
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.environment,
    required this.configuration,
    required this.configurationError,
    required this.coordinator,
    required this.onSave,
    required this.onSaveConfiguration,
    required this.onResetConfiguration,
    required this.onRestart,
  });

  final BackendEnvDocument environment;
  final SubDockConfig configuration;
  final String? configurationError;
  final AppCoordinator coordinator;
  final Future<void> Function(BackendEnvDocument document) onSave;
  final Future<void> Function(SubDockConfig configuration) onSaveConfiguration;
  final Future<void> Function() onResetConfiguration;
  final VoidCallback onRestart;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late BackendEnvDocument _document;
  late SubDockConfig _configuration;
  late final TextEditingController _raw;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _path;
  late final TextEditingController _cors;
  late final TextEditingController _configApiHost;
  late final TextEditingController _configApiPort;
  late final TextEditingController _configPath;
  late final TextEditingController _configCors;
  late final TextEditingController _metaHost;
  late final TextEditingController _metaPort;
  var _updating = false;
  var _dirty = false;
  var _configurationDirty = false;
  var _httpMetaEnabled = true;
  final _componentUpdates = <ComponentKind, ComponentUpdate>{};
  final _componentStatuses = <ComponentKind, ComponentVersionStatus>{};
  final _componentErrors = <ComponentKind, String>{};
  final _componentBusy = <ComponentKind>{};

  @override
  void initState() {
    super.initState();
    _document = widget.environment;
    _configuration = widget.configuration;
    _raw = TextEditingController();
    _host = TextEditingController();
    _port = TextEditingController();
    _path = TextEditingController();
    _cors = TextEditingController();
    _configApiHost = TextEditingController();
    _configApiPort = TextEditingController();
    _configPath = TextEditingController();
    _configCors = TextEditingController();
    _metaHost = TextEditingController();
    _metaPort = TextEditingController();
    _syncControllers();
    unawaited(_loadComponentStatuses());
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty &&
        oldWidget.environment.rawText != widget.environment.rawText) {
      _document = widget.environment;
      _syncControllers();
    }
    if (!_configurationDirty &&
        oldWidget.configuration != widget.configuration) {
      _configuration = widget.configuration;
      _syncConfigControllers();
    }
  }

  @override
  void dispose() {
    _raw.dispose();
    _host.dispose();
    _port.dispose();
    _path.dispose();
    _cors.dispose();
    _configApiHost.dispose();
    _configApiPort.dispose();
    _configPath.dispose();
    _configCors.dispose();
    _metaHost.dispose();
    _metaPort.dispose();
    super.dispose();
  }

  String _value(String key, String fallback) =>
      _document.values[key] ?? fallback;

  void _syncControllers() {
    _updating = true;
    _raw.text = _document.rawText;
    _host.text = _value(BackendEnvPolicy.host, '127.0.0.1');
    _port.text = _value(BackendEnvPolicy.port, '3001');
    _path.text = _value(BackendEnvPolicy.frontendBackendPath, '/');
    _cors.text = _value(
      BackendEnvPolicy.corsAllowedOrigins,
      BackendEnvPolicy.localOrigin(_document).origin,
    );
    _updating = false;
  }

  void _syncConfigControllers() {
    _updating = true;
    final backend = _configuration.backend;
    _configApiHost.text = backend.apiHost ?? '';
    _configApiPort.text = backend.apiPort?.toString() ?? '';
    _configPath.text = backend.frontendBackendPath ?? '';
    _configCors.text = backend.corsAllowedOrigins ?? '';
    _metaHost.text = _configuration.httpMeta.host ?? '';
    _metaPort.text = _configuration.httpMeta.port?.toString() ?? '';
    _httpMetaEnabled = _configuration.httpMeta.enabled;
    _updating = false;
  }

  String? _nullableText(String value) =>
      value.trim().isEmpty ? null : value.trim();

  int? _nullablePort(String value) =>
      value.trim().isEmpty ? null : int.tryParse(value.trim());

  void _updateConfiguration({
    SubDockBackendConfig? backend,
    SubDockHttpMetaConfig? httpMeta,
  }) {
    if (_updating) return;
    setState(() {
      _configuration = _configuration.copyWith(
        backend: backend,
        httpMeta: httpMeta,
      );
      _configurationDirty = true;
      _syncConfigControllers();
    });
  }

  String? get _configurationIssue {
    if (_configApiPort.text.trim().isNotEmpty &&
        _nullablePort(_configApiPort.text) == null) {
      return 'SubDock API Port 必须是 1-65535 的整数';
    }
    if (_metaPort.text.trim().isNotEmpty &&
        _nullablePort(_metaPort.text) == null) {
      return 'HTTP-META Port 必须是 1-65535 的整数';
    }
    try {
      SubDockConfig.fromJson(_configuration.toJson());
    } on FormatException catch (error) {
      return error.message;
    }
    return null;
  }

  void _updateConfigBackendField(String field, String value) {
    final backend = _configuration.backend;
    final parsed = _nullablePort(value);
    _updateConfiguration(
      backend: switch (field) {
        'host' => backend.copyWith(apiHost: _nullableText(value)),
        'port' => backend.copyWith(apiPort: parsed),
        'path' => backend.copyWith(frontendBackendPath: _nullableText(value)),
        _ => backend.copyWith(corsAllowedOrigins: _nullableText(value)),
      },
    );
  }

  Future<void> _saveConfiguration() async {
    final issue = _configurationIssue;
    if (issue != null) return;
    final backend = _configuration.backend;
    final externalCors =
        backend.corsAllowedOrigins != null &&
        BackendEnvPolicy.externalOrigins(
          BackendEnvDocument.parse(
            '${BackendEnvPolicy.corsAllowedOrigins}=${backend.corsAllowedOrigins}',
          ),
        ).isNotEmpty;
    final nonLoopback =
        backend.apiHost != null &&
        backend.apiHost != 'localhost' &&
        backend.apiHost != '::1' &&
        !backend.apiHost!.startsWith('127.');
    if (externalCors &&
        !await _confirm('允许外部 origin 会使其能够访问 Backend API。是否继续保存？')) {
      return;
    }
    if (nonLoopback &&
        !await _confirm('Backend 没有鉴权；非回环地址会让同一网络中的设备访问全部 API。是否继续保存？')) {
      return;
    }
    await widget.onSaveConfiguration(_configuration);
    if (!mounted) return;
    setState(() => _configurationDirty = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('SubDock 配置已保存；不会自动重启服务。')));
  }

  void _updateRaw(String value) {
    if (_updating) return;
    setState(() {
      _document = BackendEnvDocument.parse(value);
      _dirty = true;
      _syncControllers();
    });
  }

  void _updateField(String key, String value) {
    if (_updating) return;
    setState(() {
      _document = _document.withValue(key, value);
      _dirty = true;
      _syncControllers();
    });
  }

  Future<void> _save() async {
    final issues = BackendEnvPolicy.validate(_document);
    if (issues.isNotEmpty) return;
    if (BackendEnvPolicy.externalOrigins(_document).isNotEmpty &&
        !await _confirm('允许外部 origin 会使其能够访问 Backend API。是否继续保存？')) {
      return;
    }
    if (BackendEnvPolicy.hasNonLoopbackHost(_document) &&
        !await _confirm('Backend 没有鉴权；非回环地址会让同一网络中的设备访问全部 API。是否继续保存？')) {
      return;
    }
    try {
      await widget.onSave(_document);
    } on StateError {
      return;
    }
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已保存；重启 Backend 后生效。'),
        action: SnackBarAction(label: '立即重启', onPressed: widget.onRestart),
      ),
    );
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _checkComponent(ComponentKind kind) async {
    setState(() {
      _componentBusy.add(kind);
      _componentErrors.remove(kind);
    });
    try {
      final update = await widget.coordinator.checkComponent(kind);
      if (mounted) setState(() => _componentUpdates[kind] = update);
    } catch (error) {
      if (mounted) setState(() => _componentErrors[kind] = '$error');
    } finally {
      if (mounted) setState(() => _componentBusy.remove(kind));
    }
  }

  Future<void> _loadComponentStatuses() async {
    for (final kind in ComponentKind.values) {
      try {
        final status = await widget.coordinator.componentStatus(kind);
        if (mounted) setState(() => _componentStatuses[kind] = status);
      } catch (_) {
        // The check button surfaces platform or resource errors explicitly.
      }
    }
  }

  Future<void> _applyComponent(ComponentUpdate update) async {
    final kind = update.kind;
    setState(() {
      _componentBusy.add(kind);
      _componentErrors.remove(kind);
    });
    try {
      await widget.coordinator.updateComponent(update);
      if (mounted) {
        setState(() {
          _componentUpdates.remove(kind);
          _componentStatuses[kind] = ComponentVersionStatus(
            current: update.availableVersion,
            previous: update.currentVersion,
          );
          _componentErrors[kind] = '已更新到 ${update.availableVersion}';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _componentErrors[kind] = '$error');
    } finally {
      if (mounted) setState(() => _componentBusy.remove(kind));
    }
  }

  Future<void> _rollbackComponent(ComponentKind kind) async {
    setState(() {
      _componentBusy.add(kind);
      _componentErrors.remove(kind);
    });
    try {
      await widget.coordinator.rollbackComponent(kind);
      if (mounted) {
        setState(() {
          _componentUpdates.remove(kind);
          final previous = _componentStatuses[kind]?.current;
          if (previous != null) {
            _componentStatuses[kind] = ComponentVersionStatus(
              current: _componentStatuses[kind]?.previous ?? '安装包版本',
              previous: previous,
            );
          }
          _componentErrors[kind] = '已回滚到上一版本';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _componentErrors[kind] = '$error');
    } finally {
      if (mounted) setState(() => _componentBusy.remove(kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    final issues = BackendEnvPolicy.validate(_document);
    final configurationIssue = _configurationIssue;
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('SubDock 配置', style: Theme.of(context).textTheme.headlineSmall),
        if (widget.configurationError != null) ...[
          Text(
            '配置文件无效：${widget.configurationError}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _configurationDirty
                ? null
                : () => unawaited(widget.onResetConfiguration()),
            child: const Text('重置 SubDock 配置'),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('启用 HTTP-META'),
          subtitle: const Text('辅助启动失败时 Backend 仍会继续运行'),
          value: _httpMetaEnabled,
          onChanged: (value) => _updateConfiguration(
            httpMeta: _configuration.httpMeta.copyWith(enabled: value),
          ),
        ),
        _overrideField(
          controller: _configApiHost,
          label: 'Backend API Host 覆盖',
          onChanged: (value) => _updateConfigBackendField('host', value),
          onFollow: () => _updateConfiguration(
            backend: _configuration.backend.copyWith(apiHost: null),
          ),
          following: _configuration.backend.apiHost == null,
        ),
        _overrideField(
          controller: _configApiPort,
          label: 'Backend API Port 覆盖',
          keyboardType: TextInputType.number,
          onChanged: (value) => _updateConfigBackendField('port', value),
          onFollow: () => _updateConfiguration(
            backend: _configuration.backend.copyWith(apiPort: null),
          ),
          following: _configuration.backend.apiPort == null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('覆盖合并模式'),
          value:
              _configuration.backend.merge ??
              BackendEnvPolicy.isMergeEnabledFor(_document),
          onChanged: (value) => _updateConfiguration(
            backend: _configuration.backend.copyWith(merge: value),
          ),
          secondary: TextButton(
            onPressed: () => _updateConfiguration(
              backend: _configuration.backend.copyWith(merge: null),
            ),
            child: const Text('跟随 ENV'),
          ),
        ),
        _overrideField(
          controller: _configPath,
          label: 'Frontend Backend Path 覆盖',
          onChanged: (value) => _updateConfigBackendField('path', value),
          onFollow: () => _updateConfiguration(
            backend: _configuration.backend.copyWith(frontendBackendPath: null),
          ),
          following: _configuration.backend.frontendBackendPath == null,
        ),
        _overrideField(
          controller: _configCors,
          label: 'CORS Allowed Origins 覆盖',
          onChanged: (value) => _updateConfigBackendField('cors', value),
          onFollow: () => _updateConfiguration(
            backend: _configuration.backend.copyWith(corsAllowedOrigins: null),
          ),
          following: _configuration.backend.corsAllowedOrigins == null,
        ),
        _overrideField(
          controller: _metaHost,
          label: 'HTTP-META Host 覆盖',
          onChanged: (value) => _updateConfiguration(
            httpMeta: _configuration.httpMeta.copyWith(
              host: _nullableText(value),
            ),
          ),
          onFollow: () => _updateConfiguration(
            httpMeta: _configuration.httpMeta.copyWith(host: null),
          ),
          following: _configuration.httpMeta.host == null,
        ),
        _overrideField(
          controller: _metaPort,
          label: 'HTTP-META Port 覆盖',
          keyboardType: TextInputType.number,
          onChanged: (value) => _updateConfiguration(
            httpMeta: _configuration.httpMeta.copyWith(
              port: _nullablePort(value),
            ),
          ),
          onFollow: () => _updateConfiguration(
            httpMeta: _configuration.httpMeta.copyWith(port: null),
          ),
          following: _configuration.httpMeta.port == null,
        ),
        if (configurationIssue != null)
          Text(
            configurationIssue,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: configurationIssue == null && _configurationDirty
              ? _saveConfiguration
              : null,
          child: const Text('保存 SubDock 配置'),
        ),
        const Divider(height: 40),
        Text('Backend 配置', style: Theme.of(context).textTheme.headlineSmall),
        TextField(
          controller: _host,
          decoration: const InputDecoration(labelText: 'API Host'),
          onChanged: (value) => _updateField(BackendEnvPolicy.host, value),
        ),
        TextField(
          controller: _port,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'API Port'),
          onChanged: (value) => _updateField(BackendEnvPolicy.port, value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('合并模式'),
          value: BackendEnvPolicy.isMergeEnabledFor(_document),
          onChanged: (value) =>
              _updateField(BackendEnvPolicy.merge, value ? 'true' : 'false'),
        ),
        TextField(
          controller: _path,
          decoration: const InputDecoration(labelText: 'Frontend Backend Path'),
          onChanged: (value) =>
              _updateField(BackendEnvPolicy.frontendBackendPath, value),
        ),
        TextField(
          controller: _cors,
          decoration: const InputDecoration(labelText: 'CORS Allowed Origins'),
          onChanged: (value) =>
              _updateField(BackendEnvPolicy.corsAllowedOrigins, value),
        ),
        const SizedBox(height: 24),
        Text('高级原始 ENV', style: Theme.of(context).textTheme.titleMedium),
        TextField(
          controller: _raw,
          minLines: 8,
          maxLines: 16,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: _updateRaw,
        ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final issue in issues)
            Text(
              '${issue.line == null ? '' : '第 ${issue.line} 行：'}${issue.message}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: issues.isEmpty && _dirty ? _save : null,
              child: Text(l10n.save),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (final kind in ComponentKind.values)
          _ComponentCard(
            kind: kind,
            status: _componentStatuses[kind],
            update: _componentUpdates[kind],
            error: _componentErrors[kind],
            busy: _componentBusy.contains(kind),
            onCheck: () => _checkComponent(kind),
            onUpdate: _componentUpdates[kind] == null
                ? null
                : () => _applyComponent(_componentUpdates[kind]!),
            onRollback: () => _rollbackComponent(kind),
          ),
      ],
    );
  }

  Widget _overrideField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    required VoidCallback onFollow,
    required bool following,
    TextInputType? keyboardType,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          helperText: following ? '当前跟随 ENV / 默认值' : 'SubDock 覆盖值',
          suffixIcon: TextButton(
            onPressed: onFollow,
            child: const Text('跟随 ENV'),
          ),
        ),
        onChanged: onChanged,
      ),
    ],
  );
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.kind,
    required this.status,
    required this.update,
    required this.error,
    required this.busy,
    required this.onCheck,
    required this.onUpdate,
    required this.onRollback,
  });

  final ComponentKind kind;
  final ComponentVersionStatus? status;
  final ComponentUpdate? update;
  final String? error;
  final bool busy;
  final VoidCallback onCheck;
  final VoidCallback? onUpdate;
  final VoidCallback onRollback;

  @override
  Widget build(BuildContext context) {
    final name = kind == ComponentKind.backend ? 'Backend' : 'Frontend';
    final text = update == null
        ? status == null
              ? '正在读取已安装版本…'
              : '当前 ${status!.current}，上一版 ${status!.previous ?? '-'}'
        : update!.isAvailable
        ? '当前 ${update!.currentVersion}，可更新到 ${update!.availableVersion}，上一版 ${status?.previous ?? '-'}'
        : '当前 ${update!.currentVersion} 已是最新版本，上一版 ${status?.previous ?? '-'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(text),
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onCheck,
                  child: const Text('检查更新'),
                ),
                FilledButton(
                  onPressed: busy || update?.isAvailable != true
                      ? null
                      : onUpdate,
                  child: const Text('更新'),
                ),
                TextButton(
                  onPressed: busy ? null : onRollback,
                  child: const Text('回滚'),
                ),
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(child: Text(value ?? '-')),
      ],
    ),
  );
}
