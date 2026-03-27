part of '../connection_workspace_controller.dart';

Future<List<ConnectionSettingsSystemTemplate>>
_loadWorkspaceReusableSystemTemplates(
  ConnectionWorkspaceController controller,
) async {
  final connections = <SavedConnection>[];
  for (final connectionId in controller._state.catalog.orderedConnectionIds) {
    try {
      connections.add(
        await controller._connectionRepository.loadConnection(connectionId),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load connection $connectionId for reusable system template: '
        '$error | $stackTrace',
      );
    }
  }

  return deriveConnectionSettingsSystemTemplates(connections);
}
