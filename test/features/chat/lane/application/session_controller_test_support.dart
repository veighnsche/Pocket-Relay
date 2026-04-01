import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';

export 'dart:async';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/errors/pocket_error.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
export 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
export 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
export 'package:pocket_relay/src/features/chat/lane/application/chat_session_guardrail_errors.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

ConnectionProfile configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    host: 'example.com',
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

CodexAppServerThreadHistory savedConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_saved',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_saved',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
      CodexAppServerHistoryTurn(
        id: 'turn_second',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user_second',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user_second',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second prompt'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant_second',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant_second',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_second',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user_second',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second prompt'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant_second',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

CodexAppServerThreadHistory runningConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Live conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_saved',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_saved',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
      CodexAppServerHistoryTurn(
        id: 'turn_running',
        status: 'running',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user_running',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user_running',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Keep going'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant_running',
            type: 'agent_message',
            status: 'in_progress',
            raw: <String, dynamic>{
              'id': 'item_assistant_running',
              'type': 'agent_message',
              'status': 'in_progress',
              'content': <Object>[
                <String, Object?>{'text': 'Still running'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_running',
          'status': 'running',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user_running',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Keep going'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant_running',
              'type': 'agent_message',
              'status': 'in_progress',
              'content': <Object>[
                <String, Object?>{'text': 'Still running'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

CodexAppServerThreadHistory rewoundConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_before_restore_this',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_assistant_earlier',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant_earlier',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Earlier answer only'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_before_restore_this',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_assistant_earlier',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Earlier answer only'},
              ],
            },
          ],
        },
      ),
    ],
  );
}
