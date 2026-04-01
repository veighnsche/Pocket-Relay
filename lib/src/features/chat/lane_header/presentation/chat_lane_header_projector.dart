import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';

class ChatLaneHeaderProjector {
  const ChatLaneHeaderProjector();

  ChatHeaderContract project({
    required ConnectionProfile profile,
    required CodexSessionHeaderMetadata metadata,
    required bool isConfigured,
  }) {
    final title = _title(profile);
    final subtitle = _subtitle(
      profile: profile,
      metadata: metadata,
      isConfigured: isConfigured,
    );
    return ChatHeaderContract(title: title, subtitle: subtitle);
  }

  String _title(ConnectionProfile profile) {
    final normalizedLabel = profile.label.trim();
    if (normalizedLabel.isEmpty) {
      return agentAdapterLabel(profile.agentAdapter);
    }
    return normalizedLabel;
  }

  String _subtitle({
    required ConnectionProfile profile,
    required CodexSessionHeaderMetadata metadata,
    required bool isConfigured,
  }) {
    if (!isConfigured) {
      return 'Configure ${agentAdapterLabel(profile.agentAdapter)}';
    }

    final segments = <String>[
      ..._connectionDescriptor(profile),
      ..._runtimeDescriptor(metadata),
    ];
    if (segments.isEmpty) {
      return 'Waiting for ${agentAdapterLabel(profile.agentAdapter)} session';
    }
    return segments.join(' · ');
  }

  List<String> _connectionDescriptor(ConnectionProfile profile) {
    return switch (profile.connectionMode) {
      ConnectionMode.remote => switch (profile.host.trim()) {
        final host when host.isNotEmpty => <String>[host],
        _ => const <String>[],
      },
      ConnectionMode.local => <String>[
        localConnectionLabelForAgentAdapter(profile.agentAdapter),
      ],
    };
  }

  List<String> _runtimeDescriptor(CodexSessionHeaderMetadata metadata) {
    final model = metadata.model?.trim();
    if (model == null || model.isEmpty) {
      return const <String>[];
    }

    final segments = <String>[model];
    final effort = _formatReasoningEffort(metadata.reasoningEffort);
    if (effort != null) {
      segments.add(effort);
    }
    return segments;
  }

  String? _formatReasoningEffort(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      'none' => 'no effort',
      'minimal' => 'minimal effort',
      'low' => 'low effort',
      'medium' => 'medium effort',
      'high' => 'high effort',
      'xhigh' => 'xhigh effort',
      _ => normalized,
    };
  }
}
