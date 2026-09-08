import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatelessWidget {
  const _ProbeApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: _ProbePage());
  }
}

class _ProbePage extends StatefulWidget {
  const _ProbePage();

  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  late final WebViewController _controller;
  HttpServer? _server;
  var _pageLoaded = false;
  var _navigationIntercepted = false;
  var _downloadRequested = false;
  var _blobReceived = false;
  var _started = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_server?.close(force: true));
    super.dispose();
  }

  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    if (request.url.endsWith('/intercept')) {
      _set(() => _navigationIntercepted = true);
      _completeIfReady();
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onMessage(JavaScriptMessage message) {
    switch (message.message) {
      case 'loaded':
        _set(() => _pageLoaded = true);
        unawaited(_triggerChecks());
      case 'blob:probe-blob':
        _set(() => _blobReceived = true);
        _completeIfReady();
    }
  }

  Future<void> _start() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setNavigationDelegate(
        NavigationDelegate(onNavigationRequest: _onNavigationRequest),
      );
      await _controller.addJavaScriptChannel(
        'Probe',
        onMessageReceived: _onMessage,
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      unawaited(_serve(server));
      _set(() => _started = true);
      await _controller.loadRequest(
        Uri.parse('http://${server.address.address}:${server.port}/'),
      );
    } catch (error) {
      _set(() => _error = '$error');
    }
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      if (request.uri.path == '/download') {
        _set(() => _downloadRequested = true);
        _completeIfReady();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..headers.set(
            'content-disposition',
            'attachment; filename="probe.txt"',
          )
          ..write('probe-download');
      } else {
        request.response
          ..headers.contentType = ContentType.html
          ..write(_page);
      }
      await request.response.close();
    }
  }

  Future<void> _triggerChecks() async {
    try {
      await _controller.runJavaScript(
        "document.getElementById('intercept').click()",
      );
      await _controller.runJavaScript(
        "document.getElementById('download').click()",
      );
      await _controller.runJavaScript(
        "document.getElementById('blob').click()",
      );
    } catch (error) {
      _set(() => _error = '$error');
    }
  }

  void _completeIfReady() {
    if (_pageLoaded &&
        _navigationIntercepted &&
        _downloadRequested &&
        _blobReceived) {
      debugPrint(
        'WEBVIEW_PROBE_PASS: page, navigation, HTTP download, Blob channel',
      );
    }
  }

  void _set(void Function() update) {
    if (!mounted) return;
    setState(update);
  }

  static const _page = '''<!doctype html>
<html><body>
  <button id="intercept" onclick="location.href='/intercept'">intercept</button>
  <a id="download" href="/download" download="probe.txt">download</a>
  <button id="blob" onclick="const reader = new FileReader(); reader.onload = () => Probe.postMessage('blob:' + reader.result); reader.readAsText(new Blob(['probe-blob']))">blob</button>
  <script>window.addEventListener('load', () => Probe.postMessage('loaded'));</script>
</body></html>''';

  @override
  Widget build(BuildContext context) {
    final checks = <String, bool>{
      'Merged page loaded': _pageLoaded,
      'Navigation intercepted': _navigationIntercepted,
      'HTTP download requested': _downloadRequested,
      'Blob channel received': _blobReceived,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('webview_all probe')),
      body: Column(
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          for (final check in checks.entries)
            ListTile(
              leading: Icon(check.value ? Icons.check_circle : Icons.pending),
              title: Text(check.key),
            ),
          if (!_started) const LinearProgressIndicator(),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
