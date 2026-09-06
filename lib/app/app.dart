import 'dart:async';

import 'package:flutter/material.dart';

import '../runtime/backend_runtime.dart';

class SubDockApp extends StatefulWidget {
  const SubDockApp({super.key, required this.runtime});

  final BackendRuntime runtime;

  @override
  State<SubDockApp> createState() => _SubDockAppState();
}

class _SubDockAppState extends State<SubDockApp> {
  late final StreamSubscription<RuntimeState> _stateSubscription;
  late final AppLifecycleListener _lifecycleListener;
  RuntimeState _state = RuntimeState(
    status: RuntimeStatus.stopped,
    changedAt: DateTime.now(),
  );
  BackendInfo? _info;
  var _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _stateSubscription = widget.runtime.state.listen(_onState);
    _lifecycleListener = AppLifecycleListener(
      onDetach: () => unawaited(widget.runtime.stop()),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _stateSubscription.cancel();
    super.dispose();
  }

  void _onState(RuntimeState state) {
    if (!mounted) return;
    setState(() => _state = state);
    if (state.status == RuntimeStatus.running) {
      unawaited(_loadInfo());
    }
  }

  Future<void> _loadInfo() async {
    try {
      final info = await widget.runtime.info();
      if (mounted) setState(() => _info = info);
    } on StateError {
      // The state stream already carries the startup or health failure.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SubDock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('SubDock')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backend Status',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(_statusIcon, color: _statusColor(context)),
                        const SizedBox(width: 8),
                        Text(
                          _statusLabel,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    if (_state.message != null) ...[
                      const SizedBox(height: 8),
                      Text(_state.message!),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(),
                    ),
                    _InfoRow(label: 'Node Version', value: _info?.nodeVersion),
                    _InfoRow(
                      label: 'Backend Version',
                      value: _info?.backendVersion,
                    ),
                    _InfoRow(
                      label: 'Port',
                      value: _info == null ? null : '${_info!.port}',
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _canStart
                              ? () => _run(widget.runtime.start)
                              : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _canStop
                              ? () => _run(widget.runtime.stop)
                              : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _canRestart
                              ? () => _run(widget.runtime.restart)
                              : null,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Restart'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _canStart =>
      !_actionInProgress &&
      (_state.status == RuntimeStatus.stopped ||
          _state.status == RuntimeStatus.crashed);

  bool get _canStop =>
      !_actionInProgress &&
      _state.status != RuntimeStatus.stopped &&
      _state.status != RuntimeStatus.stopping;

  bool get _canRestart =>
      !_actionInProgress &&
      (_state.status == RuntimeStatus.running ||
          _state.status == RuntimeStatus.unhealthy);

  IconData get _statusIcon => switch (_state.status) {
    RuntimeStatus.running => Icons.check_circle,
    RuntimeStatus.unhealthy || RuntimeStatus.crashed => Icons.error,
    RuntimeStatus.starting || RuntimeStatus.stopping => Icons.pending,
    RuntimeStatus.stopped => Icons.pause_circle,
  };

  Color _statusColor(BuildContext context) => switch (_state.status) {
    RuntimeStatus.running => Colors.green,
    RuntimeStatus.unhealthy ||
    RuntimeStatus.crashed => Theme.of(context).colorScheme.error,
    RuntimeStatus.starting || RuntimeStatus.stopping => Colors.orange,
    RuntimeStatus.stopped => Theme.of(context).colorScheme.outline,
  };

  String get _statusLabel => switch (_state.status) {
    RuntimeStatus.stopped => 'Stopped',
    RuntimeStatus.starting => 'Starting',
    RuntimeStatus.running => 'Running',
    RuntimeStatus.stopping => 'Stopping',
    RuntimeStatus.unhealthy => 'Unhealthy',
    RuntimeStatus.crashed => 'Crashed',
  };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label)),
          Expanded(child: Text(value ?? '-')),
        ],
      ),
    );
  }
}
