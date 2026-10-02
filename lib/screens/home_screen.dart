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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _fmt = DateFormat('MMM d, HH:mm');
  List<SmsLogEntry> _log = [];
  bool _running = false;
  bool _toggling = false;
  Timer? _poll;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulseCtrl.dispose();
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
    setState(() => _toggling = true);
    if (_running) {
      await ServiceController.stop();
      await settings.copyWith(serviceEnabled: false).save();
    } else {
      if (!settings.isValid) {
        _snack('Configure Gmail settings first ⚙️');
        setState(() => _toggling = false);
        return;
      }
      await ServiceController.start();
      await settings.copyWith(serviceEnabled: true).save();
    }
    await _refresh();
    setState(() => _toggling = false);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Status helpers ──────────────────────────────────────────────────────
  Color _statusColor(DeliveryStatus s) => switch (s) {
        DeliveryStatus.sent => const Color(0xFF00C896),
        DeliveryStatus.queued => const Color(0xFFFFB74D),
        DeliveryStatus.failed => const Color(0xFFFF5C72),
      };

  /// Leading icon: call entries show a call-type glyph, SMS show the SMS icon.
  IconData _leadingIcon(SmsLogEntry e) {
    if (!e.isCall) return Icons.sms_rounded;
    return switch (e.callType) {
      'missed' => Icons.call_missed_rounded,
      'rejected' => Icons.call_end_rounded,
      'incoming' => Icons.call_received_rounded,
      'voiceMail' => Icons.voicemail_rounded,
      _ => Icons.call_rounded,
    };
  }

  String _statusLabel(DeliveryStatus s) => switch (s) {
        DeliveryStatus.sent => 'Sent',
        DeliveryStatus.queued => 'Queued',
        DeliveryStatus.failed => 'Failed',
      };

  // ── Stats from log ───────────────────────────────────────────────────────
  int get _sentCount =>
      _log.where((e) => e.status == DeliveryStatus.sent).length;
  int get _failedCount =>
      _log.where((e) => e.status == DeliveryStatus.failed).length;
  int get _queuedCount =>
      _log.where((e) => e.status == DeliveryStatus.queued).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor:
                isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5FF),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroBanner(isDark),
              stretchModes: const [StretchMode.blurBackground],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Settings',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                    _refresh();
                  },
                ),
              ),
            ],
          ),

          // ── Status / Toggle Card ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _buildStatusCard(isDark),
            ),
          ),

          // ── Stats Row ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _buildStatsRow(isDark),
            ),
          ),

          // ── Log Header ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Recent Forwards',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_log.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_log.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_log.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        await LogService.clear();
                        _refresh();
                      },
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5C72),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Log List ─────────────────────────────────────────────────────
          _log.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(isDark),
                )
              : SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  sliver: SliverList.separated(
                    itemCount: _log.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildLogCard(_log[i], isDark),
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ── Hero banner ──────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3D35C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // decorative circles
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: 60,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.forward_to_inbox_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SMS to Gmail',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'SMS & Call Forwarder',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status card ──────────────────────────────────────────────────────────
  Widget _buildStatusCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // animated status dot + icon
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Opacity(
              opacity: _running ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (_running
                        ? const Color(0xFF00C896)
                        : const Color(0xFF9090B0))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _running
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                color: _running
                    ? const Color(0xFF00C896)
                    : const Color(0xFF9090B0),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _running ? 'Service Running' : 'Service Stopped',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _running
                      ? 'Forwarding incoming SMS & calls to Gmail'
                      : 'Tap to start forwarding SMS & calls',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF9090B0)
                        : const Color(0xFF6060A0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _toggling
              ? const SizedBox(
                  width: 40,
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF6C63FF)),
                    ),
                  ),
                )
              : Switch(value: _running, onChanged: (_) => _toggleService()),
        ],
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────
  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        _statChip('Sent', _sentCount, const Color(0xFF00C896), isDark),
        const SizedBox(width: 10),
        _statChip('Queued', _queuedCount, const Color(0xFFFFB74D), isDark),
        const SizedBox(width: 10),
        _statChip('Failed', _failedCount, const Color(0xFFFF5C72), isDark),
      ],
    );
  }

  Widget _statChip(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF9090B0)
                    : const Color(0xFF8080A0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Log card ─────────────────────────────────────────────────────────────
  Widget _buildLogCard(SmsLogEntry e, bool isDark) {
    final color = _statusColor(e.status);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // colored status pill
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_leadingIcon(e), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.sender,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmt.format(e.receivedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF6060A0)
                              : const Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFFB0B0D0)
                          : const Color(0xFF505070),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (e.error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      e.error!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFF5C72),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(e.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.inbox_rounded,
                color: Color(0xFF6C63FF), size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF3A3A5A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Forwarded SMS & calls will appear here',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? const Color(0xFF6060A0)
                  : const Color(0xFF9090B0),
            ),
          ),
        ],
      ),
    );
  }
}
