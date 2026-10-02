import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/email_service.dart';
import '../services/service_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gmail = TextEditingController();
  final _appPassword = TextEditingController();
  final _recipient = TextEditingController();

  bool _obscure = true;
  bool _serviceEnabled = false;
  bool _forwardSms = true;
  bool _forwardCalls = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gmail.dispose();
    _appPassword.dispose();
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await AppSettings.load();
    setState(() {
      _gmail.text = s.gmailAddress;
      _appPassword.text = s.appPassword;
      _recipient.text = s.recipient;
      _serviceEnabled = s.serviceEnabled;
      _forwardSms = s.forwardSms;
      _forwardCalls = s.forwardCalls;
    });
  }

  AppSettings _current() => AppSettings(
        gmailAddress: _gmail.text,
        appPassword: _appPassword.text,
        recipient: _recipient.text,
        serviceEnabled: _serviceEnabled,
        forwardSms: _forwardSms,
        forwardCalls: _forwardCalls,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _current().save();
    _snack('✅  Settings saved');
  }

  Future<void> _toggleService(bool enable) async {
    if (!_formKey.currentState!.validate()) {
      _snack('Fix the fields above first');
      return;
    }
    setState(() => _busy = true);
    await _current().copyWith(serviceEnabled: enable).save();
    if (enable) {
      await ServiceController.start();
    } else {
      await ServiceController.stop();
    }
    setState(() {
      _serviceEnabled = enable;
      _busy = false;
    });
  }

  Future<void> _sendTest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _current().save();
      await EmailService.sendTest(_current());
      _snack('📬  Test email sent — check your inbox');
    } catch (e) {
      _snack('❌  Test failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!v.contains('@') || !v.contains('.')) return 'Invalid email';
    return null;
  }

  /// Update an SMS/Calls toggle and persist immediately.
  Future<void> _setForward({bool? sms, bool? calls}) async {
    setState(() {
      if (sms != null) _forwardSms = sms;
      if (calls != null) _forwardCalls = calls;
    });
    await _current().save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: AbsorbPointer(
        absorbing: _busy,
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              stretch: true,
              backgroundColor:
                  isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5FF),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: Colors.white,
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3D35C8), Color(0xFF6C63FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -20,
                        right: -10,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      const SafeArea(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settings',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Configure your Gmail forwarding',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Account section ────────────────────────────────
                      _sectionLabel('Gmail Account', Icons.account_circle_rounded, isDark),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _gmail,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Your Gmail address',
                          hintText: 'you@gmail.com',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _appPassword,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Gmail App Password',
                          hintText: 'xxxx xxxx xxxx xxxx',
                          prefixIcon: const Icon(Icons.key_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded),
                            color: const Color(0xFF6C63FF),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      _buildHelpCard(isDark),
                      const SizedBox(height: 24),

                      // ── Forwarding section ─────────────────────────────
                      _sectionLabel('Forwarding', Icons.forward_to_inbox_rounded, isDark),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _recipient,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Recipient email',
                          hintText: 'destination@example.com',
                          prefixIcon: Icon(Icons.send_rounded),
                        ),
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 24),

                      // ── What to forward ────────────────────────────────
                      _sectionLabel('What to forward', Icons.tune_rounded, isDark),
                      const SizedBox(height: 12),
                      _buildForwardToggle(
                        isDark,
                        title: 'Incoming SMS',
                        subtitle: 'Email every text message you receive',
                        icon: Icons.sms_rounded,
                        value: _forwardSms,
                        onChanged: (v) => _setForward(sms: v),
                      ),
                      const SizedBox(height: 10),
                      _buildForwardToggle(
                        isDark,
                        title: 'Incoming & missed calls',
                        subtitle: 'Email caller, time, type & duration',
                        icon: Icons.call_rounded,
                        value: _forwardCalls,
                        onChanged: (v) => _setForward(calls: v),
                      ),
                      const SizedBox(height: 28),

                      // ── Action buttons ─────────────────────────────────
                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Settings'),
                      ),
                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: _busy ? null : _sendTest,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF6C63FF)))
                            : const Icon(Icons.science_rounded),
                        label: const Text('Send Test Email'),
                      ),

                      const SizedBox(height: 28),

                      // ── Service toggle ─────────────────────────────────
                      _sectionLabel('Service', Icons.miscellaneous_services_rounded, isDark),
                      const SizedBox(height: 12),

                      _buildServiceTile(isDark),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark
                ? const Color(0xFF9090D0)
                : const Color(0xFF5050A0),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── Help card ─────────────────────────────────────────────────────────────
  Widget _buildHelpCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, size: 18, color: Color(0xFF6C63FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not your normal password. Enable 2-Step Verification on your Google Account, '
              'then go to Security → App passwords. Create one named "SMS Forwarder" and paste '
              'the 16-character code here.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark
                    ? const Color(0xFF9090C0)
                    : const Color(0xFF5050A0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Forward-type toggle tile (SMS / Calls) ───────────────────────────────
  Widget _buildForwardToggle(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF)
                    .withValues(alpha: value ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 20,
                color: value
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF9090B0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF9090B0)
                          : const Color(0xFF8080A0),
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: _busy ? null : onChanged),
          ],
        ),
      ),
    );
  }

  // ── Service toggle tile ──────────────────────────────────────────────────
  Widget _buildServiceTile(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (_serviceEnabled
                        ? const Color(0xFF00C896)
                        : const Color(0xFF9090B0))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _serviceEnabled
                    ? Icons.wifi_tethering_rounded
                    : Icons.wifi_tethering_off_rounded,
                color: _serviceEnabled
                    ? const Color(0xFF00C896)
                    : const Color(0xFF9090B0),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Forwarding Service',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _serviceEnabled
                        ? 'Running — forwarding SMS & calls'
                        : 'Stopped — nothing being forwarded',
                    style: TextStyle(
                      fontSize: 12,
                      color: _serviceEnabled
                          ? const Color(0xFF00C896)
                          : (isDark
                              ? const Color(0xFF9090B0)
                              : const Color(0xFF9090B0)),
                    ),
                  ),
                ],
              ),
            ),
            _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Color(0xFF6C63FF)),
                  )
                : Switch(
                    value: _serviceEnabled,
                    onChanged: _busy ? null : _toggleService,
                  ),
          ],
        ),
      ),
    );
  }
}
