import 'dart:async';
import 'dart:io';

import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';

abstract interface class WorkspaceConversationHistoryRepository {
  /// Loads authoritative conversation history from the configured agent adapter.
  ///
  /// Pocket Relay must not replace this with an app-owned local history store,
  /// because users can create and continue conversations outside this app.
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  });
}

@Deprecated('Use WorkspaceConversationHistoryRepository instead.')
typedef CodexWorkspaceConversationHistoryRepository =
    WorkspaceConversationHistoryRepository;

final class CodexWorkspaceConversationHistoryUnpinnedHostKeyException
    implements Exception {
  const CodexWorkspaceConversationHistoryUnpinnedHostKeyException({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
  });

  final String host;
  final int port;
  final String keyType;
  final String fingerprint;

  @override
  String toString() {
    return 'Host key not pinned for $host:$port ($keyType $fingerprint).';
  }
}

typedef AgentAdapterClientFactory = AgentAdapterClient Function();

class AgentAdapterConversationHistoryRepository
    implements WorkspaceConversationHistoryRepository {
  const AgentAdapterConversationHistoryRepository({
    this.clientFactory,
    this.pageSize = 100,
  });

  final AgentAdapterClientFactory? clientFactory;
  final int pageSize;

  @override
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    // Conversation discovery comes from the upstream agent adapter itself. The
    // app only displays upstream truth; it does not maintain its own
    // historical catalog.
    final workspaceDir = profile.workspaceDir.trim();
    if (workspaceDir.isEmpty) {
      return const <CodexWorkspaceConversationSummary>[];
    }

    final client =
        clientFactory?.call() ??
        createDefaultAgentAdapterClient(profile: profile, ownerId: ownerId);
    StreamSubscription<CodexAppServerEvent>? eventsSubscription;
    CodexAppServerUnpinnedHostKeyEvent? unpinnedHostKeyEvent;
    try {
      eventsSubscription = client.events.listen((event) {
        if (event is CodexAppServerUnpinnedHostKeyEvent) {
          unpinnedHostKeyEvent = event;
        }
      });
      await client.connect(profile: profile, secrets: secrets);
      final threads = await _loadAllThreads(client);
      final matchingThreads = threads.where(
        (thread) => _matchesWorkspace(
          workspaceDir: workspaceDir,
          threadCwd: thread.cwd,
          caseInsensitivePaths:
              profile.connectionMode == ConnectionMode.local &&
              Platform.isWindows,
        ),
      );

      final conversations = <CodexWorkspaceConversationSummary>[];
      for (final thread in matchingThreads) {
        final detailedThread = await client.readThreadWithTurns(
          threadId: thread.id,
        );
        final promptCount = detailedThread.promptCount ?? 0;
        if (promptCount <= 0) {
          continue;
        }
        conversations.add(
          CodexWorkspaceConversationSummary(
            threadId: thread.id,
            preview: detailedThread.name?.trim().isNotEmpty == true
                ? detailedThread.name!
                : detailedThread.preview,
            cwd: detailedThread.cwd ?? thread.cwd ?? workspaceDir,
            promptCount: promptCount,
            firstPromptAt: detailedThread.createdAt ?? thread.createdAt,
            lastActivityAt: detailedThread.updatedAt ?? thread.updatedAt,
          ),
        );
      }

      conversations.sort((left, right) {
        final leftSort =
            left.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightSort =
            right.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final byTime = rightSort.compareTo(leftSort);
        if (byTime != 0) {
          return byTime;
        }
        return left.normalizedThreadId.compareTo(right.normalizedThreadId);
      });
      return conversations;
    } catch (error) {
      await Future<void>.microtask(() {});
      if (unpinnedHostKeyEvent case final event?) {
        throw CodexWorkspaceConversationHistoryUnpinnedHostKeyException(
          host: event.host,
          port: event.port,
          keyType: event.keyType,
          fingerprint: event.fingerprint,
        );
      }
      rethrow;
    } finally {
      await eventsSubscription?.cancel();
      await client.dispose();
    }
  }

  Future<List<CodexAppServerThreadSummary>> _loadAllThreads(
    AgentAdapterClient client,
  ) async {
    final threads = <CodexAppServerThreadSummary>[];
    String? cursor;
    do {
      final page = await client.listThreads(cursor: cursor, limit: pageSize);
      threads.addAll(page.threads);
      cursor = page.nextCursor;
    } while (cursor != null && cursor.isNotEmpty);
    return threads;
  }

  static bool _matchesWorkspace({
    required String workspaceDir,
    required String? threadCwd,
    required bool caseInsensitivePaths,
  }) {
    final effectiveThreadCwd = threadCwd?.trim();
    if (effectiveThreadCwd == null || effectiveThreadCwd.isEmpty) {
      return false;
    }
    final normalizedWorkspace = _normalizePath(
      workspaceDir,
      caseInsensitive: caseInsensitivePaths,
    );
    final normalizedThreadCwd = _normalizePath(
      effectiveThreadCwd,
      caseInsensitive: caseInsensitivePaths,
    );
    if (normalizedWorkspace == normalizedThreadCwd) {
      return true;
    }
    return normalizedThreadCwd.startsWith('$normalizedWorkspace/');
  }

  static String _normalizePath(String path, {required bool caseInsensitive}) {
    var normalized = path.trim().replaceAll('\\', '/');
    while (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return caseInsensitive ? normalized.toLowerCase() : normalized;
  }
}

@Deprecated('Use AgentAdapterConversationHistoryRepository instead.')
typedef CodexAppServerConversationHistoryRepository =
    AgentAdapterConversationHistoryRepository;
