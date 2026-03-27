import 'package:pocket_relay/src/core/models/connection_models.dart';

class ConnectionSettingsSystemTemplate {
  const ConnectionSettingsSystemTemplate({
    required this.id,
    required this.profile,
    required this.secrets,
  });

  final String id;
  final ConnectionProfile profile;
  final ConnectionSecrets secrets;

  ConnectionSettingsSystemTemplate copyWith({
    String? id,
    ConnectionProfile? profile,
    ConnectionSecrets? secrets,
  }) {
    return ConnectionSettingsSystemTemplate(
      id: id ?? this.id,
      profile: profile ?? this.profile,
      secrets: secrets ?? this.secrets,
    );
  }
}
