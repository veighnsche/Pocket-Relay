import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:flutter/material.dart';

class ConnectionSheetResult {
  const ConnectionSheetResult({required this.profile, required this.secrets});

  final ConnectionProfile profile;
  final ConnectionSecrets secrets;
}

class ConnectionSheet extends StatefulWidget {
  const ConnectionSheet({
    super.key,
    required this.initialProfile,
    required this.initialSecrets,
  });

  final ConnectionProfile initialProfile;
  final ConnectionSecrets initialSecrets;

  @override
  State<ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<ConnectionSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _labelController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _workspaceController;
  late final TextEditingController _codexPathController;
  late final TextEditingController _fingerprintController;
  late final TextEditingController _passwordController;
  late final TextEditingController _privateKeyController;
  late final TextEditingController _privateKeyPassphraseController;

  late AuthMode _authMode;
  late bool _dangerouslyBypassSandbox;
  late bool _ephemeralSession;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    final secrets = widget.initialSecrets;

    _labelController = TextEditingController(text: profile.label);
    _hostController = TextEditingController(text: profile.host);
    _portController = TextEditingController(text: profile.port.toString());
    _usernameController = TextEditingController(text: profile.username);
    _workspaceController = TextEditingController(text: profile.workspaceDir);
    _codexPathController = TextEditingController(text: profile.codexPath);
    _fingerprintController = TextEditingController(
      text: profile.hostFingerprint,
    );
    _passwordController = TextEditingController(text: secrets.password);
    _privateKeyController = TextEditingController(text: secrets.privateKeyPem);
    _privateKeyPassphraseController = TextEditingController(
      text: secrets.privateKeyPassphrase,
    );

    _authMode = profile.authMode;
    _dangerouslyBypassSandbox = profile.dangerouslyBypassSandbox;
    _ephemeralSession = profile.ephemeralSession;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _workspaceController.dispose();
    _codexPathController.dispose();
    _fingerprintController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _privateKeyPassphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return Material(
      color: palette.sheetBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.dragHandle,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Remote target',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This app runs Codex on your developer box over SSH and renders the JSON stream as mobile-friendly cards.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Section(
                    title: 'Identity',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _labelController,
                          decoration: const InputDecoration(
                            labelText: 'Profile label',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _hostController,
                                decoration: const InputDecoration(
                                  labelText: 'Host',
                                  hintText: 'devbox.local',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Host is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _portController,
                                decoration: const InputDecoration(
                                  labelText: 'Port',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  final port = int.tryParse(value ?? '');
                                  if (port == null ||
                                      port < 1 ||
                                      port > 65535) {
                                    return 'Bad port';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Username is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Remote Codex',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _workspaceController,
                          decoration: const InputDecoration(
                            labelText: 'Workspace directory',
                            hintText: '/home/vince/Projects',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Workspace directory is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _codexPathController,
                          decoration: const InputDecoration(
                            labelText: 'Codex launch command',
                            hintText: 'codex or just codex-mcp',
                            helperText:
                                'Command run inside the workspace before app-server args are appended.',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Codex launch command is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fingerprintController,
                          decoration: const InputDecoration(
                            labelText: 'Host fingerprint (optional)',
                            hintText: 'aa:bb:cc:dd:...',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Authentication',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<AuthMode>(
                          segments: const [
                            ButtonSegment<AuthMode>(
                              value: AuthMode.password,
                              label: Text('Password'),
                              icon: Icon(Icons.password),
                            ),
                            ButtonSegment<AuthMode>(
                              value: AuthMode.privateKey,
                              label: Text('Private key'),
                              icon: Icon(Icons.key),
                            ),
                          ],
                          selected: <AuthMode>{_authMode},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _authMode = selection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        if (_authMode == AuthMode.password)
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'SSH password',
                            ),
                            validator: (value) {
                              if (_authMode == AuthMode.password &&
                                  (value == null || value.isEmpty)) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          )
                        else ...[
                          TextFormField(
                            controller: _privateKeyController,
                            minLines: 6,
                            maxLines: 10,
                            decoration: const InputDecoration(
                              labelText: 'Private key PEM',
                              alignLabelWithHint: true,
                            ),
                            validator: (value) {
                              if (_authMode == AuthMode.privateKey &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Private key is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _privateKeyPassphraseController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Key passphrase (optional)',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Run mode',
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          value: _dangerouslyBypassSandbox,
                          onChanged: (value) {
                            setState(() {
                              _dangerouslyBypassSandbox = value;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Dangerous full access'),
                          subtitle: const Text(
                            'Turns off the safer full-auto sandbox and gives Codex direct unsandboxed execution on the remote box.',
                          ),
                        ),
                        SwitchListTile.adaptive(
                          value: _ephemeralSession,
                          onChanged: (value) {
                            setState(() {
                              _ephemeralSession = value;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ephemeral turns'),
                          subtitle: const Text(
                            'Do not keep remote Codex session history between prompts.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    final connectionChanged = _hasConnectionChanges();
    if (connectionChanged && !_formKey.currentState!.validate()) {
      return;
    }

    final profile = widget.initialProfile.copyWith(
      label: _labelController.text.trim().isEmpty
          ? 'Developer Box'
          : _labelController.text.trim(),
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      username: _usernameController.text.trim(),
      workspaceDir: _workspaceController.text.trim(),
      codexPath: _codexPathController.text.trim(),
      authMode: _authMode,
      hostFingerprint: _fingerprintController.text.trim(),
      dangerouslyBypassSandbox: _dangerouslyBypassSandbox,
      ephemeralSession: _ephemeralSession,
    );

    final secrets = widget.initialSecrets.copyWith(
      password: _passwordController.text,
      privateKeyPem: _privateKeyController.text,
      privateKeyPassphrase: _privateKeyPassphraseController.text,
    );

    Navigator.of(
      context,
    ).pop(ConnectionSheetResult(profile: profile, secrets: secrets));
  }

  bool _hasConnectionChanges() {
    return _labelController.text.trim() != widget.initialProfile.label ||
        _hostController.text.trim() != widget.initialProfile.host ||
        _portController.text.trim() != widget.initialProfile.port.toString() ||
        _usernameController.text.trim() != widget.initialProfile.username ||
        _workspaceController.text.trim() !=
            widget.initialProfile.workspaceDir ||
        _codexPathController.text.trim() != widget.initialProfile.codexPath ||
        _fingerprintController.text.trim() !=
            widget.initialProfile.hostFingerprint ||
        _passwordController.text != widget.initialSecrets.password ||
        _privateKeyController.text != widget.initialSecrets.privateKeyPem ||
        _privateKeyPassphraseController.text !=
            widget.initialSecrets.privateKeyPassphrase ||
        _authMode != widget.initialProfile.authMode ||
        _dangerouslyBypassSandbox !=
            widget.initialProfile.dangerouslyBypassSandbox ||
        _ephemeralSession != widget.initialProfile.ephemeralSession;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
