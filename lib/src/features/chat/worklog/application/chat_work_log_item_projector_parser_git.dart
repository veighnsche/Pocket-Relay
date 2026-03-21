part of 'chat_work_log_item_projector.dart';

_ParsedGitInvocation? _parseGitInvocation(List<String> tokens) {
  if (tokens.isEmpty) {
    return null;
  }

  var index = 1;
  String? repoPath;
  String? gitDir;
  String? workTree;

  while (index < tokens.length) {
    final token = tokens[index];
    final normalizedToken = token.toLowerCase();

    if (!token.startsWith('-') || token == '-') {
      break;
    }

    if (token == '-C') {
      if (index + 1 >= tokens.length) {
        return null;
      }
      repoPath = tokens[index + 1];
      index += 2;
      continue;
    }
    if (token.startsWith('-C') && token.length > 2) {
      repoPath = token.substring(2);
      index++;
      continue;
    }

    if (token == '-c') {
      if (index + 1 >= tokens.length) {
        return null;
      }
      index += 2;
      continue;
    }
    if (token.startsWith('-c') && token.length > 2) {
      index++;
      continue;
    }

    if (normalizedToken == '--git-dir') {
      if (index + 1 >= tokens.length) {
        return null;
      }
      gitDir = tokens[index + 1];
      index += 2;
      continue;
    }
    if (normalizedToken.startsWith('--git-dir=')) {
      gitDir = token.substring('--git-dir='.length);
      index++;
      continue;
    }

    if (normalizedToken == '--work-tree') {
      if (index + 1 >= tokens.length) {
        return null;
      }
      workTree = tokens[index + 1];
      index += 2;
      continue;
    }
    if (normalizedToken.startsWith('--work-tree=')) {
      workTree = token.substring('--work-tree='.length);
      index++;
      continue;
    }

    if (normalizedToken == '--namespace' ||
        normalizedToken == '--super-prefix' ||
        normalizedToken == '--config-env' ||
        normalizedToken == '--exec-path') {
      if (index + 1 >= tokens.length) {
        return null;
      }
      index += 2;
      continue;
    }
    if (normalizedToken.startsWith('--namespace=') ||
        normalizedToken.startsWith('--super-prefix=') ||
        normalizedToken.startsWith('--config-env=') ||
        normalizedToken.startsWith('--exec-path=')) {
      index++;
      continue;
    }

    index++;
  }

  final subcommand = index < tokens.length ? tokens[index] : null;
  final args = index < tokens.length
      ? tokens.sublist(index + 1)
      : const <String>[];

  return _ParsedGitInvocation(
    subcommand: subcommand,
    args: args,
    repoPath: repoPath,
    gitDir: gitDir,
    workTree: workTree,
  );
}

_ParsedGitCommand _buildParsedGitCommand(_ParsedGitInvocation invocation) {
  final subcommand = invocation.subcommand;
  final normalizedSubcommand = subcommand?.toLowerCase();
  final repoScopeLabel = _gitScopeLabel(invocation);

  if (normalizedSubcommand == null || normalizedSubcommand.isEmpty) {
    return _ParsedGitCommand(
      subcommandLabel: 'git',
      summaryLabel: 'Running git',
      primaryLabel: repoScopeLabel ?? 'Repository command',
    );
  }

  final historyCommand = _buildGitHistoryCommand(
    invocation,
    repoScopeLabel: repoScopeLabel,
    normalizedSubcommand: normalizedSubcommand,
  );
  if (historyCommand != null) {
    return historyCommand;
  }

  final mutationCommand = _buildGitMutationCommand(
    invocation,
    repoScopeLabel: repoScopeLabel,
    normalizedSubcommand: normalizedSubcommand,
  );
  if (mutationCommand != null) {
    return mutationCommand;
  }

  return _buildGitSupportCommand(
    invocation,
    repoScopeLabel: repoScopeLabel,
    normalizedSubcommand: normalizedSubcommand,
  );
}
