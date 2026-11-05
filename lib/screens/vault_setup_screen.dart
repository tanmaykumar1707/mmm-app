import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/vault_provider.dart';
import '../services/vault_encryption.dart';
import '../services/state_provider.dart';
import '../utils/constants.dart';

class VaultSetupScreen extends StatefulWidget {
  final bool isNewSetup; // false = needs token (new device)
  const VaultSetupScreen({super.key, this.isNewSetup = true});
  @override
  State<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends State<VaultSetupScreen> {
  String? _generatedToken;
  bool _confirmed = false;
  bool _loading = false;
  bool _tokenCopied = false;
  final _tokenCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showWipeConfirm = false;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _generateToken() {
    setState(() => _generatedToken = VaultEncryptionService.generateToken());
  }

  Future<void> _proceed(VaultProvider vp) async {
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm you have saved the token')));
      return;
    }
    setState(() => _loading = true);
    final displayName = context.read<StateProvider>().myDisplayName ?? 'Me';
    await vp.setupVault(_generatedToken!, ownerName: displayName);
    setState(() => _loading = false);
  }

  Future<void> _unlock(VaultProvider vp) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await vp.unlockWithToken(_tokenCtrl.text.trim().toUpperCase());
    setState(() => _loading = false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid token — could not decrypt vault data'),
          backgroundColor: kDanger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.read<VaultProvider>();
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: widget.isNewSetup ? _buildSetup(vp) : _buildEnterToken(vp),
        ),
      ),
    );
  }

  // ── First-time setup ───────────────────────────────────────────────────────
  Widget _buildSetup(VaultProvider vp) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kPrimary, Color(0xFF7C3AED)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
      ),
      const SizedBox(height: 20),
      const Text('Set Up Your Vault', style: TextStyle(
        fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w800, color: kTextDark)),
      const SizedBox(height: 8),
      const Text('Your vault uses end-to-end encryption. A security token is '
        'generated and used to encrypt your data. We never store it.',
        style: TextStyle(fontSize: 13, color: kTextMid, height: 1.5)),

      const SizedBox(height: 28),

      // Step 1: Generate
      _StepCard(
        step: '1',
        title: 'Generate Your Security Token',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'This token is the only key to your vault. '
            'Store it somewhere safe — a password manager, written note, or printed copy.',
            style: TextStyle(fontSize: 12, color: kTextMid, height: 1.5)),
          const SizedBox(height: 14),
          if (_generatedToken == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.vpn_key_rounded),
                label: const Text('Generate Token'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _generateToken,
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('YOUR TOKEN', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5, color: kPrimary)),
                const SizedBox(height: 8),
                Text(_formatToken(_generatedToken!),
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    letterSpacing: 2, color: kTextDark, fontFamily: 'monospace')),
                const SizedBox(height: 10),
                Row(children: [
                  OutlinedButton.icon(
                    icon: Icon(_tokenCopied ? Icons.check : Icons.copy_rounded, size: 14),
                    label: Text(_tokenCopied ? 'Copied!' : 'Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimary,
                      side: const BorderSide(color: kPrimary),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _generatedToken!));
                      setState(() => _tokenCopied = true);
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _generateToken,
                    child: const Text('Regenerate'),
                  ),
                ]),
              ]),
            ),
          ],
        ]),
      ),

      if (_generatedToken != null) ...[
        const SizedBox(height: 14),

        // Step 2: Confirm
        _StepCard(
          step: '2',
          title: 'Save & Confirm',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kWarn.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kWarn.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: kWarn, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'If you lose this token, your vault data cannot be recovered.',
                  style: TextStyle(fontSize: 11, color: kTextMid))),
              ]),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              activeColor: kPrimary,
              title: const Text(
                'I have saved my token in a safe place',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _confirmed ? kPrimary : kTextLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : () => _proceed(vp),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Create Vault', style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ],
    ]);
  }

  // ── Enter token (new device / reinstall) ───────────────────────────────────
  Widget _buildEnterToken(VaultProvider vp) {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.lock_open_rounded, color: kPrimary, size: 28),
        ),
        const SizedBox(height: 20),
        const Text('Enter Your Vault Token', style: TextStyle(
          fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.w800, color: kTextDark)),
        const SizedBox(height: 8),
        const Text('Your vault was set up on another device. Enter your security token to restore access.',
          style: TextStyle(fontSize: 13, color: kTextMid, height: 1.5)),
        const SizedBox(height: 28),

        TextFormField(
          controller: _tokenCtrl,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'Security Token',
            hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 2)),
          ),
          validator: (v) => (v == null || v.trim().length < 24) ? 'Enter your 24-character token' : null,
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _loading ? null : () => _unlock(vp),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Unlock Vault', style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),

        const SizedBox(height: 20),
        // Forgot token / wipe
        if (!_showWipeConfirm)
          Center(child: TextButton(
            onPressed: () => setState(() => _showWipeConfirm = true),
            child: const Text('Forgot token? Wipe vault data', style: TextStyle(color: kDanger)),
          ))
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kDanger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kDanger.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('⚠ Wipe Vault Data', style: TextStyle(fontWeight: FontWeight.w700, color: kDanger)),
              const SizedBox(height: 6),
              const Text('This permanently deletes all vault data. It cannot be undone.',
                style: TextStyle(fontSize: 12, color: kTextMid)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => setState(() => _showWipeConfirm = false),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
                  onPressed: () => vp.wipeVault(),
                  child: const Text('Wipe'),
                )),
              ]),
            ]),
          ),
      ]),
    );
  }

  String _formatToken(String t) {
    final buf = StringBuffer();
    for (int i = 0; i < t.length; i++) {
      if (i > 0 && i % 6 == 0) buf.write('-');
      buf.write(t[i]);
    }
    return buf.toString();
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final Widget child;
  const _StepCard({required this.step, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(color: kPrimary, shape: BoxShape.circle),
          child: Center(child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  );
}
