import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/lane_header/presentation/chat_lane_header_projector.dart';

void main() {
  const projector = ChatLaneHeaderProjector();

  test('uses the saved profile label as the title', () {
    final header = projector.project(
      profile: _remoteProfile(),
      metadata: const CodexSessionHeaderMetadata(),
      isConfigured: true,
    );

    expect(header.title, 'Dev Box');
    expect(header.subtitle, 'devbox.local');
  });

  test('falls back to Codex when the profile label is blank', () {
    final header = projector.project(
      profile: _remoteProfile().copyWith(label: '   '),
      metadata: const CodexSessionHeaderMetadata(),
      isConfigured: true,
    );

    expect(header.title, 'Codex');
  });

  test('keeps remote host info and appends live model and effort', () {
    final header = projector.project(
      profile: _remoteProfile(),
      metadata: const CodexSessionHeaderMetadata(
        model: 'gpt-5.4',
        reasoningEffort: 'high',
      ),
      isConfigured: true,
    );

    expect(header.subtitle, 'devbox.local · gpt-5.4 · high effort');
  });

  test('uses local Codex descriptor for local lanes', () {
    final header = projector.project(
      profile: _remoteProfile().copyWith(
        connectionMode: ConnectionMode.local,
        host: '',
        username: '',
      ),
      metadata: const CodexSessionHeaderMetadata(model: 'gpt-5.4-mini'),
      isConfigured: true,
    );

    expect(header.subtitle, 'local Codex · gpt-5.4-mini');
  });

  test(
    'shows waiting state when configured but Codex has no runtime metadata yet',
    () {
      final header = projector.project(
        profile: ConnectionProfile.defaults().copyWith(
          label: 'Local Lane',
          connectionMode: ConnectionMode.local,
          workspaceDir: '/workspace',
          codexPath: 'codex',
        ),
        metadata: const CodexSessionHeaderMetadata(),
        isConfigured: true,
      );

      expect(header.subtitle, 'local Codex');
    },
  );

  test('shows configuration guidance when the profile is not ready', () {
    final header = projector.project(
      profile: ConnectionProfile.defaults().copyWith(label: 'Dev Box'),
      metadata: const CodexSessionHeaderMetadata(model: 'gpt-5.4'),
      isConfigured: false,
    );

    expect(header.subtitle, 'Configure Codex');
  });
}

ConnectionProfile _remoteProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
  );
}
