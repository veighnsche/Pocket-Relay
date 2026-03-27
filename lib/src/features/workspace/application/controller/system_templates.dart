part of '../connection_workspace_controller.dart';

Future<List<ConnectionSettingsSystemTemplate>>
_loadWorkspaceReusableSystemTemplates(
  ConnectionWorkspaceController controller,
) async {
  final systems = <SavedSystem>[];
  for (final systemId in controller._state.systemCatalog.orderedSystemIds) {
    try {
      systems.add(await controller._connectionRepository.loadSystem(systemId));
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load system $systemId for reusable system template: '
        '$error | $stackTrace',
      );
    }
  }

  return deriveConnectionSettingsSystemTemplatesFromSystems(systems);
}
