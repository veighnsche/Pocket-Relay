part of 'chat_work_log_item_projector.dart';

_ParsedGitCommand _buildGitSupportCommand(
  _ParsedGitInvocation invocation, {
  required String? repoScopeLabel,
  required String normalizedSubcommand,
}) {
  return switch (normalizedSubcommand) {
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
    _ => _buildGenericGitCommand(invocation, repoScopeLabel),
  };
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
