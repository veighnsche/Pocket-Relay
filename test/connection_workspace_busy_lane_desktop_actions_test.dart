import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_menu_actions.dart';

void main() {
  test(
    'desktop live-lane destructive actions are disabled while the lane is busy',
    () {
      var historyCalls = 0;
      var savedConnectionCalls = 0;
      var closeCalls = 0;

      final actions = buildWorkspaceLiveLaneMenuActions(
        hasWorkspaceHistoryScope: true,
        isLaneBusy: true,
        onShowConversationHistory: () {
          historyCalls += 1;
        },
        onShowSavedConnections: () {
          savedConnectionCalls += 1;
        },
        onCloseLane: () {
          closeCalls += 1;
        },
      );

      final historyAction = actions.firstWhere(
        (action) =>
            action.label ==
            ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
      );
      final savedConnectionsAction = actions.firstWhere(
        (action) =>
            action.label == ConnectionWorkspaceCopy.savedConnectionsMenuLabel,
      );
      final closeAction = actions.firstWhere(
        (action) => action.label == ConnectionWorkspaceCopy.closeLaneAction,
      );

      expect(historyAction.isEnabled, isFalse);
      expect(savedConnectionsAction.isEnabled, isTrue);
      expect(closeAction.isEnabled, isFalse);
      expect(closeAction.isDestructive, isTrue);

      savedConnectionsAction.onSelected();
      expect(historyCalls, 0);
      expect(savedConnectionCalls, 1);
      expect(closeCalls, 0);
    },
  );
}
