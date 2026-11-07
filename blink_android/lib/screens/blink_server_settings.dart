import 'package:flutter/material.dart';

import '../core/blink_auth_api.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// Device-side API connection diagnostic. Blink web is normally running on
/// :5173 while NestJS API uses :3000. On a physical phone 127.0.0.1 points
/// to the phone itself, not to the developer's Windows PC.
class BlinkServerSettingsScreen extends StatefulWidget {
  const BlinkServerSettingsScreen({super.key});

  @override
  State<BlinkServerSettingsScreen> createState() =>
      _BlinkServerSettingsScreenState();
}

class _BlinkServerSettingsScreenState extends State<BlinkServerSettingsScreen> {
  late final TextEditingController _url;
  bool _testing = false;
  bool _saving = false;
  String? _message;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: BlinkAuthApi.baseUrl);
    _url.addListener(() {
      if (_verified && mounted) setState(() => _verified = false);
    });
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    if (_testing || _saving) return;
    setState(() { _testing = true; _message = null; _verified = false; });
    try {
      await BlinkAuthApi.verifyServerUrl(_url.text);
      if (mounted) setState(() {
        _verified = true;
        _message = 'Blink API reachable from this device.';
      });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (_testing || _saving) return;
    setState(() { _saving = true; _message = null; });
    try {
      final value = BlinkAuthApi.normalizeServerUrl(_url.text);
      if (value == BlinkAuthApi.baseUrl) {
        if (mounted) setState(() => _message =
            'This is already your selected Blink API server.');
        return;
      }
      // Checking API identity also prevents accidentally saving a Vite URL.
      await BlinkAuthApi.changeServerUrl(value);
      if (!mounted) return;
      // A saved JWT must never follow the user to a different server.
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Blink API updated. Sign in to the selected server.'),
      ));
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BlinkColors.canvas,
    appBar: AppBar(title: const BlinkBrandedTitle('API connection')),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const SectionHeading(
          'Connect Android to Blink',
          subtitle: 'Use the same NestJS API and database as your working web app.',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BlinkColors.orangeSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current API server', style: TextStyle(
                color: BlinkColors.orangeDark, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              SelectableText(BlinkAuthApi.baseUrl,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'NestJS API address',
            hintText: 'http://192.168.1.10:3000',
            prefixIcon: Icon(Icons.dns_outlined),
            helperText: 'Use the API server, not the React site on port 5173.',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 14),
        if (_message != null) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_message!, style: TextStyle(
            color: _verified ? const Color(0xFF21834D) : Colors.red.shade700,
            fontWeight: FontWeight.w600,
          )),
        ),
        OutlinedButton.icon(
          onPressed: _testing || _saving ? null : _test,
          icon: _testing
              ? const SizedBox(width: 17, height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.network_check_rounded),
          label: Text(_testing ? 'Checking connection...' : 'Test connection'),
        ),
        const SizedBox(height: 9),
        FilledButton.icon(
          onPressed: _testing || _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 17, height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Use this Blink API'),
        ),
        const SizedBox(height: 25),
        const Divider(),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.phone_android_rounded,
            color: BlinkColors.orange),
          title: Text('Android emulator'),
          subtitle: Text('http://10.0.2.2:3000 connects to the PC running NestJS.'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.wifi_rounded,
            color: BlinkColors.orange),
          title: Text('Physical Android phone'),
          subtitle: Text('Use your PC LAN IPv4 address, e.g. '
              'http://192.168.1.10:3000. The phone must be able to reach '
              'the PC and Windows Firewall must allow the port.'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline_rounded,
            color: BlinkColors.orange),
          title: Text('Production'),
          subtitle: Text('Use your trusted HTTPS API domain. '
              'Changing the server logs you out for security.'),
        ),
      ],
    )),
  );
}
