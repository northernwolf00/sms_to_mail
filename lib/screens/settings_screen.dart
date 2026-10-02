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
    });
  }

  AppSettings _current() => AppSettings(
        gmailAddress: _gmail.text,
        appPassword: _appPassword.text,
        recipient: _recipient.text,
        serviceEnabled: _serviceEnabled,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _current().save();
    _snack('Settings saved');
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
      _snack('Test email sent — check your inbox');
    } catch (e) {
      _snack('Test failed: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _gmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Your Gmail address',
                  hintText: 'you@gmail.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_circle),
                ),
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _appPassword,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Gmail App Password (16 chars)',
                  hintText: 'abcd efgh ijkl mnop',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              const _AppPasswordHelp(),
              const SizedBox(height: 16),

              TextFormField(
                controller: _recipient,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Recipient email',
                  hintText: 'where to forward (can be the same Gmail)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.forward_to_inbox),
                ),
                validator: _emailValidator,
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Save settings'),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _busy ? null : _sendTest,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Send test email'),
              ),
              const Divider(height: 40),

              SwitchListTile(
                title: const Text('Forwarding service'),
                subtitle: Text(_serviceEnabled
                    ? 'Running — forwarding incoming SMS'
                    : 'Stopped'),
                value: _serviceEnabled,
                onChanged: _busy ? null : _toggleService,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline help explaining how to create a Gmail App Password.
class _AppPasswordHelp extends StatelessWidget {
  const _AppPasswordHelp();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Not your normal password. Enable 2-Step Verification, then: '
              'Google Account → Security → 2-Step Verification → App passwords. '
              'Create one named "SMS Forwarder" and paste the 16-char code here. '
              'It is stored only on this device — fine for personal sideload use.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
