part of 'chat_empty_state_body.dart';

extension on ChatEmptyStateBody {
  Widget _buildMobileShell(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeroIcon(context, desktop: false),
          const SizedBox(height: 18),
          Text(
            isConfigured
                ? 'Remote Codex, ready to continue'
                : 'Remote Codex, ready when you are',
            textAlign: TextAlign.center,
            style: _titleStyle(context, desktop: false),
          ),
          const SizedBox(height: 10),
          Text(
            isConfigured
                ? 'Send the next prompt below. Pocket Relay keeps the remote session readable and keeps approvals in the same flow.'
                : 'Configure one remote workspace, then keep prompts, approvals, and live output readable from your phone.',
            textAlign: TextAlign.center,
            style: _bodyStyle(context),
          ),
          if (!isConfigured) ...[
            const SizedBox(height: 20),
            _buildConfigureButton(desktop: false, fullWidth: true),
          ],
          if (supplementalContent != null) ...[
            const SizedBox(height: 20),
            supplementalContent!,
          ],
          const SizedBox(height: 22),
          _buildDetailsPanel(context, items: _mobileDetails(), maxWidth: 520),
        ],
      ),
    );

    return _buildShell(context, content);
  }

  List<_EmptyStateDetail> _mobileDetails() {
    if (isConfigured) {
      return const <_EmptyStateDetail>[
        _EmptyStateDetail(
          title: 'Next prompt',
          body: 'Resume the remote session from the composer below.',
          materialIcon: Icons.send_outlined,
        ),
        _EmptyStateDetail(
          title: 'Live transcript',
          body:
              'Commands, edits, and replies land in order while the turn runs.',
          materialIcon: Icons.view_stream_outlined,
        ),
        _EmptyStateDetail(
          title: 'Interruptions',
          body:
              'Approve commands or answer follow-up requests without leaving the session.',
          materialIcon: Icons.fact_check_outlined,
        ),
      ];
    }

    return const <_EmptyStateDetail>[
      _EmptyStateDetail(
        title: 'Connect once',
        body:
            'Point Pocket Relay at your SSH workspace and keep it ready for the next prompt.',
        materialIcon: Icons.link_rounded,
      ),
      _EmptyStateDetail(
        title: 'Read the live turn',
        body:
            'Commands, edits, and replies stay in one scroll instead of a terminal wall.',
        materialIcon: Icons.menu_book_outlined,
      ),
      _EmptyStateDetail(
        title: 'Handle interruptions',
        body: 'Approvals and follow-up forms stay in the same flow.',
        materialIcon: Icons.pending_actions_outlined,
      ),
    ];
  }
}
