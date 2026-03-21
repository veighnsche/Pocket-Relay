part of 'chat_work_log_item_projector.dart';

_ParsedGitCommand? _buildGitHistoryCommand(
  _ParsedGitInvocation invocation, {
  required String? repoScopeLabel,
  required String normalizedSubcommand,
}) {
  return switch (normalizedSubcommand) {
    'status' => _buildGitStatusCommand(invocation, repoScopeLabel),
    'diff' => _buildGitDiffCommand(invocation, repoScopeLabel),
    'show' => _buildGitShowCommand(invocation, repoScopeLabel),
    'log' => _buildGitLogCommand(invocation, repoScopeLabel),
    'grep' => _buildGitGrepCommand(invocation, repoScopeLabel),
    'rev-parse' => _buildGitRevParseCommand(invocation, repoScopeLabel),
    'blame' => _buildGitTargetedCommand(
      invocation: invocation,
      repoScopeLabel: repoScopeLabel,
      summaryLabel: 'Tracing line history',
      emptyPrimaryLabel: 'Requested file',
    ),
    _ => null,
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
