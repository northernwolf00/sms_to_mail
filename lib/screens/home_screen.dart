import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_settings.dart';
import '../models/sms_log_entry.dart';
import '../services/log_service.dart';
import '../services/service_controller.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _fmt = DateFormat('MMM d, HH:mm:ss');
  List<SmsLogEntry> _log = [];
  bool _running = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    // The log is written from other isolates; poll to keep the UI fresh.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final log = await LogService.getAll();
    final running = await ServiceController.isRunning;
    if (!mounted) return;
    setState(() {
      _log = log;
      _running = running;
    });
  }

  Future<void> _toggleService() async {
    final settings = await AppSettings.load();
    if (_running) {
      await ServiceController.stop();
      await settings.copyWith(serviceEnabled: false).save();
    } else {
      if (!settings.isValid) {
        _snack('Configure Gmail settings first.');
        return;
      }
      await ServiceController.start();
      await settings.copyWith(serviceEnabled: true).save();
    }
    await _refresh();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _statusColor(DeliveryStatus s) => switch (s) {
        DeliveryStatus.sent => Colors.green,
        DeliveryStatus.queued => Colors.orange,
        DeliveryStatus.failed => Colors.red,
      };

  IconData _statusIcon(DeliveryStatus s) => switch (s) {
        DeliveryStatus.sent => Icons.check_circle,
        DeliveryStatus.queued => Icons.schedule,
        DeliveryStatus.failed => Icons.error,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS to Gmail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Status card ----
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _running ? Icons.cloud_done : Icons.cloud_off,
                    color: _running ? Colors.green : Colors.grey,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _running ? 'Service running' : 'Service stopped',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          _running
                              ? 'Forwarding incoming SMS in the background'
                              : 'Incoming SMS are not being forwarded',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(value: _running, onChanged: (_) => _toggleService()),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Recent forwards',
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await LogService.clear();
                    _refresh();
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),

          // ---- Log list ----
          Expanded(
            child: _log.isEmpty
                ? const Center(child: Text('No forwarded messages yet'))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      itemCount: _log.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = _log[i];
                        return ListTile(
                          leading: Icon(_statusIcon(e.status),
                              color: _statusColor(e.status)),
                          title: Text(e.sender,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${_fmt.format(e.receivedAt)}  •  ${e.status.label}'
                                '${e.error != null ? '\n${e.error}' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: _statusColor(e.status)),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
