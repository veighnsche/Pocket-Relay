import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/workspace/models/codex_workspace_conversation_summary.dart';

abstract interface class CodexWorkspaceConversationHistoryRepository {
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  });
}

class CodexStorageConversationHistoryRepository
    implements CodexWorkspaceConversationHistoryRepository {
  CodexStorageConversationHistoryRepository({
    CodexWorkspaceConversationStorageLoader? localLoader,
    CodexWorkspaceConversationRemoteLoader? remoteLoader,
  }) : _localLoader =
           localLoader ?? LocalCodexWorkspaceConversationStorageLoader(),
       _remoteLoader =
           remoteLoader ?? SshCodexWorkspaceConversationStorageLoader();

  final CodexWorkspaceConversationStorageLoader _localLoader;
  final CodexWorkspaceConversationRemoteLoader _remoteLoader;

  @override
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final workspaceDir = profile.workspaceDir.trim();
    if (workspaceDir.isEmpty) {
      return const <CodexWorkspaceConversationSummary>[];
    }

    final snapshot = profile.connectionMode == ConnectionMode.local
        ? await _localLoader.load()
        : await _remoteLoader.load(profile: profile, secrets: secrets);
    return _CodexWorkspaceConversationHistoryParser(
      workspaceDir: workspaceDir,
      caseInsensitivePaths:
          profile.connectionMode == ConnectionMode.local && Platform.isWindows,
    ).parse(snapshot);
  }
}

abstract interface class CodexWorkspaceConversationStorageLoader {
  Future<CodexWorkspaceConversationStorageSnapshot> load();
}

abstract interface class CodexWorkspaceConversationRemoteLoader {
  Future<CodexWorkspaceConversationStorageSnapshot> load({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  });
}

class CodexWorkspaceConversationStorageSnapshot {
  const CodexWorkspaceConversationStorageSnapshot({
    required this.historyJsonl,
    required this.sessionDocuments,
  });

  final String? historyJsonl;
  final List<CodexWorkspaceConversationSessionDocument> sessionDocuments;
}

class CodexWorkspaceConversationSessionDocument {
  const CodexWorkspaceConversationSessionDocument({
    required this.path,
    required this.contents,
  });

  final String path;
  final String contents;
}

class LocalCodexWorkspaceConversationStorageLoader
    implements CodexWorkspaceConversationStorageLoader {
  const LocalCodexWorkspaceConversationStorageLoader();

  @override
  Future<CodexWorkspaceConversationStorageSnapshot> load() async {
    final codexRoot = _localCodexRoot();
    if (codexRoot == null) {
      return const CodexWorkspaceConversationStorageSnapshot(
        historyJsonl: null,
        sessionDocuments: <CodexWorkspaceConversationSessionDocument>[],
      );
    }

    final historyFile = File(_joinPath(codexRoot, 'history.jsonl'));
    final sessionsDir = Directory(_joinPath(codexRoot, 'sessions'));
    final sessionDocuments = <CodexWorkspaceConversationSessionDocument>[];
    if (await sessionsDir.exists()) {
      await for (final entity in sessionsDir.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.jsonl')) {
          continue;
        }
        try {
          sessionDocuments.add(
            CodexWorkspaceConversationSessionDocument(
              path: entity.path,
              contents: await entity.readAsString(),
            ),
          );
        } catch (_) {
          // Skip unreadable session files.
        }
      }
    }

    String? historyJsonl;
    if (await historyFile.exists()) {
      try {
        historyJsonl = await historyFile.readAsString();
      } catch (_) {
        historyJsonl = null;
      }
    }

    return CodexWorkspaceConversationStorageSnapshot(
      historyJsonl: historyJsonl,
      sessionDocuments: sessionDocuments,
    );
  }
}

class SshCodexWorkspaceConversationStorageLoader
    implements CodexWorkspaceConversationRemoteLoader {
  const SshCodexWorkspaceConversationStorageLoader();

  @override
  Future<CodexWorkspaceConversationStorageSnapshot> load({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final socket = await SSHSocket.connect(
      profile.host.trim(),
      profile.port,
      timeout: const Duration(seconds: 10),
    );
    final client = SSHClient(
      socket,
      username: profile.username.trim(),
      onVerifyHostKey: (type, fingerprint) {
        final expectedFingerprint = profile.hostFingerprint.trim();
        if (expectedFingerprint.isEmpty) {
          return true;
        }
        return normalizeFingerprint(expectedFingerprint) ==
            normalizeFingerprint(formatFingerprint(fingerprint));
      },
      identities: _buildSshIdentities(profile: profile, secrets: secrets),
      onPasswordRequest: profile.authMode == AuthMode.password
          ? () => secrets.password.trim().isEmpty ? null : secrets.password
          : null,
    );

    try {
      await client.authenticated;
      final sftp = await client.sftp();
      final codexRoot = await sftp.absolute('.codex');
      final historyJsonl = await _readRemoteFileIfPresent(
        sftp,
        _joinUnixPath(codexRoot, 'history.jsonl'),
      );
      final sessionPaths = <String>[];
      await _collectRemoteSessionFiles(
        sftp,
        _joinUnixPath(codexRoot, 'sessions'),
        into: sessionPaths,
      );
      final sessionDocuments = <CodexWorkspaceConversationSessionDocument>[];
      for (final path in sessionPaths) {
        final contents = await _readRemoteFileIfPresent(sftp, path);
        if (contents == null) {
          continue;
        }
        sessionDocuments.add(
          CodexWorkspaceConversationSessionDocument(
            path: path,
            contents: contents,
          ),
        );
      }
      sftp.close();
      return CodexWorkspaceConversationStorageSnapshot(
        historyJsonl: historyJsonl,
        sessionDocuments: sessionDocuments,
      );
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) {
        return const CodexWorkspaceConversationStorageSnapshot(
          historyJsonl: null,
          sessionDocuments: <CodexWorkspaceConversationSessionDocument>[],
        );
      }
      rethrow;
    } finally {
      client.close();
      await client.done.catchError((_) {});
    }
  }

  Future<void> _collectRemoteSessionFiles(
    SftpClient sftp,
    String directoryPath, {
    required List<String> into,
  }) async {
    List<SftpName> children;
    try {
      children = await sftp.listdir(directoryPath);
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) {
        return;
      }
      rethrow;
    }

    for (final child in children) {
      if (child.filename == '.' || child.filename == '..') {
        continue;
      }
      final childPath = _joinUnixPath(directoryPath, child.filename);
      if (child.attr.isDirectory) {
        await _collectRemoteSessionFiles(sftp, childPath, into: into);
        continue;
      }
      if (child.filename.endsWith('.jsonl')) {
        into.add(childPath);
      }
    }
  }

  Future<String?> _readRemoteFileIfPresent(SftpClient sftp, String path) async {
    try {
      final file = await sftp.open(path);
      try {
        final bytes = await file.readBytes();
        return utf8.decode(bytes, allowMalformed: true);
      } finally {
        await file.close();
      }
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) {
        return null;
      }
      rethrow;
    }
  }
}

class _CodexWorkspaceConversationHistoryParser {
  const _CodexWorkspaceConversationHistoryParser({
    required this.workspaceDir,
    required this.caseInsensitivePaths,
  });

  final String workspaceDir;
  final bool caseInsensitivePaths;

  List<CodexWorkspaceConversationSummary> parse(
    CodexWorkspaceConversationStorageSnapshot snapshot,
  ) {
    final historyBySessionId = _parseHistory(snapshot.historyJsonl);
    final matchingSessionIds = <String, _SessionMeta>{};
    for (final sessionDocument in snapshot.sessionDocuments) {
      final meta = _parseSessionMeta(sessionDocument.contents);
      if (meta == null || !_matchesWorkspace(meta.cwd)) {
        continue;
      }
      matchingSessionIds[meta.sessionId] = meta;
    }

    final summaries = <CodexWorkspaceConversationSummary>[];
    for (final entry in matchingSessionIds.entries) {
      final sessionId = entry.key;
      final meta = entry.value;
      final history = historyBySessionId[sessionId];
      summaries.add(
        CodexWorkspaceConversationSummary(
          sessionId: sessionId,
          preview: history?.preview ?? '',
          cwd: meta.cwd,
          messageCount: history?.messageCount ?? 0,
          firstPromptAt: history?.firstPromptAt,
          lastActivityAt: history?.lastPromptAt ?? meta.startedAt,
        ),
      );
    }

    summaries.sort((left, right) {
      final leftSort =
          left.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightSort =
          right.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byTime = rightSort.compareTo(leftSort);
      if (byTime != 0) {
        return byTime;
      }
      return left.sessionId.compareTo(right.sessionId);
    });
    return summaries;
  }

  Map<String, _HistoryAggregate> _parseHistory(String? historyJsonl) {
    if (historyJsonl == null || historyJsonl.trim().isEmpty) {
      return const <String, _HistoryAggregate>{};
    }

    final aggregates = <String, _HistoryAggregate>{};
    for (final line in const LineSplitter().convert(historyJsonl)) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        continue;
      }
      try {
        final json = jsonDecode(trimmedLine);
        if (json is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(json);
        final sessionId = _asTrimmedString(map['session_id']);
        final ts = map['ts'];
        final text = _asTrimmedString(map['text']);
        if (sessionId == null || ts is! num || text == null) {
          continue;
        }
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          ts.toInt() * 1000,
          isUtc: true,
        ).toLocal();
        final previous = aggregates[sessionId];
        aggregates[sessionId] = previous == null
            ? _HistoryAggregate(
                preview: text,
                firstPromptAt: timestamp,
                lastPromptAt: timestamp,
                messageCount: 1,
              )
            : _HistoryAggregate(
                preview: previous.preview,
                firstPromptAt: previous.firstPromptAt,
                lastPromptAt: timestamp.isAfter(previous.lastPromptAt)
                    ? timestamp
                    : previous.lastPromptAt,
                messageCount: previous.messageCount + 1,
              );
      } catch (_) {
        // Skip malformed history rows.
      }
    }
    return aggregates;
  }

  _SessionMeta? _parseSessionMeta(String contents) {
    for (final line in const LineSplitter().convert(contents)) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        continue;
      }
      try {
        final json = jsonDecode(trimmedLine);
        if (json is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(json);
        if (map['type'] != 'session_meta') {
          continue;
        }
        final payload = map['payload'];
        if (payload is! Map) {
          continue;
        }
        final payloadMap = Map<String, dynamic>.from(payload);
        final sessionId = _asTrimmedString(payloadMap['id']);
        final cwd = _asTrimmedString(payloadMap['cwd']);
        final startedAt = _parseIsoTimestamp(payloadMap['timestamp']);
        if (sessionId == null || cwd == null) {
          return null;
        }
        return _SessionMeta(
          sessionId: sessionId,
          cwd: cwd,
          startedAt: startedAt,
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _matchesWorkspace(String sessionCwd) {
    final normalizedWorkspace = _normalizePath(
      workspaceDir,
      caseInsensitive: caseInsensitivePaths,
    );
    final normalizedSessionCwd = _normalizePath(
      sessionCwd,
      caseInsensitive: caseInsensitivePaths,
    );
    if (normalizedWorkspace == normalizedSessionCwd) {
      return true;
    }
    return normalizedSessionCwd.startsWith('$normalizedWorkspace/');
  }

  static String? _asTrimmedString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _parseIsoTimestamp(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }
}

class _HistoryAggregate {
  const _HistoryAggregate({
    required this.preview,
    required this.firstPromptAt,
    required this.lastPromptAt,
    required this.messageCount,
  });

  final String preview;
  final DateTime firstPromptAt;
  final DateTime lastPromptAt;
  final int messageCount;
}

class _SessionMeta {
  const _SessionMeta({
    required this.sessionId,
    required this.cwd,
    required this.startedAt,
  });

  final String sessionId;
  final String cwd;
  final DateTime? startedAt;
}

List<SSHKeyPair>? _buildSshIdentities({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) {
  if (profile.authMode != AuthMode.privateKey) {
    return null;
  }

  final privateKey = secrets.privateKeyPem.trim();
  if (privateKey.isEmpty) {
    throw StateError('A private key is required for key-based SSH auth.');
  }

  final passphrase = secrets.privateKeyPassphrase.trim();
  return SSHKeyPair.fromPem(privateKey, passphrase.isEmpty ? null : passphrase);
}

String? _localCodexRoot() {
  final codexHome = Platform.environment['CODEX_HOME']?.trim();
  if (codexHome != null && codexHome.isNotEmpty) {
    return codexHome;
  }

  final userProfile = Platform.environment['USERPROFILE']?.trim();
  if (userProfile != null && userProfile.isNotEmpty) {
    return _joinPath(userProfile, '.codex');
  }

  final home = Platform.environment['HOME']?.trim();
  if (home != null && home.isNotEmpty) {
    return _joinPath(home, '.codex');
  }

  final homeDrive = Platform.environment['HOMEDRIVE']?.trim();
  final homePath = Platform.environment['HOMEPATH']?.trim();
  if (homeDrive != null &&
      homeDrive.isNotEmpty &&
      homePath != null &&
      homePath.isNotEmpty) {
    return '$homeDrive$homePath${Platform.pathSeparator}.codex';
  }
  return null;
}

String _joinPath(String base, String child) {
  final separator = Platform.pathSeparator;
  final trimmedBase = base.endsWith(separator)
      ? base.substring(0, base.length - separator.length)
      : base;
  return '$trimmedBase$separator$child';
}

String _joinUnixPath(String base, String child) {
  final trimmedBase = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  return '$trimmedBase/$child';
}

String _normalizePath(String path, {required bool caseInsensitive}) {
  var normalized = path.trim().replaceAll('\\', '/');
  while (normalized.endsWith('/') && normalized.length > 1) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return caseInsensitive ? normalized.toLowerCase() : normalized;
}
