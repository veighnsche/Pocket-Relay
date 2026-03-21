part of 'chat_work_log_item_projector.dart';

_ParsedGitCommand? _buildGitMutationCommand(
  _ParsedGitInvocation invocation, {
  required String? repoScopeLabel,
  required String normalizedSubcommand,
}) {
  return switch (normalizedSubcommand) {
    'add' => _buildGitAddCommand(invocation, repoScopeLabel),
    'restore' => _buildGitRestoreCommand(invocation, repoScopeLabel),
    'checkout' => _buildGitCheckoutCommand(invocation, repoScopeLabel),
    'switch' => _buildGitSwitchCommand(invocation, repoScopeLabel),
    'branch' => _buildGitBranchCommand(invocation, repoScopeLabel),
    'commit' => _buildGitCommitCommand(invocation, repoScopeLabel),
    'stash' => _buildGitStashCommand(invocation, repoScopeLabel),
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
    _ => null,
  };
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
