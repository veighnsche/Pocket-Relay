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

  return switch (normalizedSubcommand) {
    'status' => _buildGitStatusCommand(invocation, repoScopeLabel),
    'diff' => _buildGitDiffCommand(invocation, repoScopeLabel),
    'show' => _buildGitShowCommand(invocation, repoScopeLabel),
    'log' => _buildGitLogCommand(invocation, repoScopeLabel),
    'grep' => _buildGitGrepCommand(invocation, repoScopeLabel),
    'add' => _buildGitAddCommand(invocation, repoScopeLabel),
    'restore' => _buildGitRestoreCommand(invocation, repoScopeLabel),
    'checkout' => _buildGitCheckoutCommand(invocation, repoScopeLabel),
    'switch' => _buildGitSwitchCommand(invocation, repoScopeLabel),
    'rev-parse' => _buildGitRevParseCommand(invocation, repoScopeLabel),
    'branch' => _buildGitBranchCommand(invocation, repoScopeLabel),
    'commit' => _buildGitCommitCommand(invocation, repoScopeLabel),
    'stash' => _buildGitStashCommand(invocation, repoScopeLabel),
    'fetch' => _buildGitRemoteCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Fetching remote updates',
    ),
    'pull' => _buildGitRemoteCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Pulling remote changes',
    ),
    'push' => _buildGitRemoteCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Pushing commits',
    ),
    'merge' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Merging history',
      emptyPrimaryLabel: 'Requested merge target',
    ),
    'rebase' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Rebasing commits',
      emptyPrimaryLabel: 'Current branch',
    ),
    'cherry-pick' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Applying commit',
      emptyPrimaryLabel: 'Selected commit',
    ),
    'revert' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Reverting commit',
      emptyPrimaryLabel: 'Selected commit',
    ),
    'blame' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Tracing line history',
      emptyPrimaryLabel: 'Requested file',
    ),
    'rm' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Removing tracked files',
      emptyPrimaryLabel: 'Selected paths',
    ),
    'mv' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Moving tracked files',
      emptyPrimaryLabel: 'Selected paths',
    ),
    'clean' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Cleaning untracked files',
      emptyPrimaryLabel: 'Current repository',
    ),
    'reset' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Resetting repository state',
      emptyPrimaryLabel: 'Current branch',
    ),
    _ => _buildGenericGitCommand(invocation, repoScopeLabel),
  };
}

_ParsedGitCommand _buildGitStatusCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(
    invocation.args,
    valueOptions: const <String>{
      '--untracked-files',
      '--ignored',
      '--column',
      '--ahead-behind',
    },
    shortValueOptions: const <String>{'u'},
  );
  return _ParsedGitCommand(
    subcommandLabel: 'status',
    summaryLabel: 'Checking worktree status',
    primaryLabel: _formatCompactItemList(
      targets,
      emptyLabel: 'Current repository',
    ),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitDiffCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final isStaged =
      invocation.args.contains('--staged') ||
      invocation.args.contains('--cached');
  final targets = _collectGitPositionalArgs(
    invocation.args,
    valueOptions: const <String>{
      '--diff-filter',
      '--submodule',
      '--output',
      '--word-diff-regex',
    },
    shortValueOptions: const <String>{'U'},
  );
  final primaryLabel = isStaged
      ? 'Staged changes'
      : _formatCompactItemList(targets, emptyLabel: 'Working tree changes');
  final secondaryLabel = _combineDetailLabels(<String?>[
    isStaged && targets.isNotEmpty
        ? _formatCompactItemList(targets, emptyLabel: '')
        : null,
    repoScopeLabel,
  ]);
  return _ParsedGitCommand(
    subcommandLabel: 'diff',
    summaryLabel: 'Inspecting diff',
    primaryLabel: primaryLabel,
    secondaryLabel: secondaryLabel,
  );
}

_ParsedGitCommand _buildGitShowCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(
    invocation.args,
    valueOptions: const <String>{'--format', '--pretty'},
    shortValueOptions: const <String>{'n'},
  );
  return _ParsedGitCommand(
    subcommandLabel: 'show',
    summaryLabel: 'Inspecting git object',
    primaryLabel: _formatCompactItemList(targets, emptyLabel: 'HEAD'),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitLogCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(
    invocation.args,
    valueOptions: const <String>{'--max-count', '--author', '--grep'},
    shortValueOptions: const <String>{'n'},
  );
  return _ParsedGitCommand(
    subcommandLabel: 'log',
    summaryLabel: 'Reviewing commit history',
    primaryLabel: _formatCompactItemList(targets, emptyLabel: 'Current branch'),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitGrepCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final search = _parseGitGrepArgs(invocation.args);
  if (search != null) {
    return _ParsedGitCommand(
      subcommandLabel: 'grep',
      summaryLabel: 'Searching tracked files',
      primaryLabel: search.query,
      secondaryLabel: _combineDetailLabels(<String?>[
        search.scopeTargets.isEmpty
            ? 'In tracked files'
            : 'In ${_formatCompactItemList(search.scopeTargets, emptyLabel: '')}',
        repoScopeLabel,
      ]),
    );
  }
  return _buildGenericGitCommand(invocation, repoScopeLabel);
}

_ParsedGitCommand _buildGitAddCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(
    invocation.args,
    valueOptions: const <String>{'--chmod'},
  );
  final primaryLabel =
      invocation.args.contains('-A') ||
          invocation.args.contains('--all') ||
          invocation.args.contains('-u') ||
          invocation.args.contains('--update')
      ? 'All tracked changes'
      : _formatCompactItemList(targets, emptyLabel: 'Selected paths');
  return _ParsedGitCommand(
    subcommandLabel: 'add',
    summaryLabel: 'Staging changes',
    primaryLabel: primaryLabel,
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitRestoreCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(invocation.args);
  return _ParsedGitCommand(
    subcommandLabel: 'restore',
    summaryLabel: invocation.args.contains('--staged')
        ? 'Restoring staged changes'
        : 'Restoring tracked files',
    primaryLabel: _formatCompactItemList(targets, emptyLabel: 'Selected paths'),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitCheckoutCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final separatorIndex = invocation.args.indexOf('--');
  if (separatorIndex >= 0) {
    final pathTargets = invocation.args
        .skip(separatorIndex + 1)
        .where(_isNonEmptyToken)
        .toList(growable: false);
    return _ParsedGitCommand(
      subcommandLabel: 'checkout',
      summaryLabel: 'Restoring paths',
      primaryLabel: _formatCompactItemList(
        pathTargets,
        emptyLabel: 'Selected paths',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  final targets = _collectGitPositionalArgs(
    invocation.args,
    valueOptions: const <String>{'--detach'},
    shortValueOptions: const <String>{'b', 'B'},
  );
  return _ParsedGitCommand(
    subcommandLabel: 'checkout',
    summaryLabel: 'Switching checkout target',
    primaryLabel: _formatCompactItemList(
      targets,
      emptyLabel: 'Requested target',
    ),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitSwitchCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(
    invocation.args,
    shortValueOptions: const <String>{'c', 'C'},
  );
  return _ParsedGitCommand(
    subcommandLabel: 'switch',
    summaryLabel: 'Switching branch',
    primaryLabel: _formatCompactItemList(
      targets,
      emptyLabel: 'Requested branch',
    ),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitRevParseCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(invocation.args);
  return _ParsedGitCommand(
    subcommandLabel: 'rev-parse',
    summaryLabel: 'Resolving git reference',
    primaryLabel: _formatCompactItemList(
      targets,
      emptyLabel: 'Repository state',
    ),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitBranchCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(
    invocation.args,
    shortValueOptions: const <String>{'m', 'M', 'c', 'C'},
  );
  return _ParsedGitCommand(
    subcommandLabel: 'branch',
    summaryLabel: targets.isEmpty ? 'Inspecting branches' : 'Managing branches',
    primaryLabel: _formatCompactItemList(
      targets,
      emptyLabel: 'Current repository',
    ),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitCommitCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final message = _extractGitOptionValue(
    invocation.args,
    options: const <String>{'--message'},
    shortOptions: const <String>{'m'},
  );
  return _ParsedGitCommand(
    subcommandLabel: 'commit',
    summaryLabel: 'Creating commit',
    primaryLabel: message ?? 'Staged changes',
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitStashCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(invocation.args);
  return _ParsedGitCommand(
    subcommandLabel: 'stash',
    summaryLabel: 'Managing stash',
    primaryLabel: _formatCompactItemList(
      targets,
      emptyLabel: 'Current stash state',
    ),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitRemoteCommand({
  required _ParsedGitInvocation invocation,
  required String? repoScopeLabel,
  required String summaryLabel,
}) {
  final targets = _collectGitPositionalArgs(invocation.args);
  return _ParsedGitCommand(
    subcommandLabel: invocation.subcommand ?? 'git',
    summaryLabel: summaryLabel,
    primaryLabel: _formatCompactItemList(targets, emptyLabel: 'Default remote'),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGitTargetedCommand({
  required _ParsedGitInvocation invocation,
  required String? repoScopeLabel,
  required String summaryLabel,
  required String emptyPrimaryLabel,
}) {
  final targets = _collectGitPositionalArgs(invocation.args);
  return _ParsedGitCommand(
    subcommandLabel: invocation.subcommand ?? 'git',
    summaryLabel: summaryLabel,
    primaryLabel: _formatCompactItemList(
      targets,
      emptyLabel: emptyPrimaryLabel,
    ),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitCommand _buildGenericGitCommand(
  _ParsedGitInvocation invocation,
  String? repoScopeLabel,
) {
  final targets = _collectGitPositionalArgs(invocation.args);
  return _ParsedGitCommand(
    subcommandLabel: invocation.subcommand ?? 'git',
    summaryLabel: 'Running git ${invocation.subcommand ?? ''}'.trim(),
    primaryLabel: _formatCompactItemList(
      targets,
      emptyLabel: 'Current repository',
    ),
    secondaryLabel: repoScopeLabel,
  );
}

_ParsedGitGrepSearch? _parseGitGrepArgs(List<String> args) {
  if (args.isEmpty) {
    return null;
  }

  final syntheticTokens = <String>['grep', ...args];
  final parsed = _tryParseGrepSearchCommand(syntheticTokens);
  if (parsed == null) {
    return null;
  }
  return _ParsedGitGrepSearch(
    query: parsed.query,
    scopeTargets: parsed.scopeTargets,
  );
}
