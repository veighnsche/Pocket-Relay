import 'package:flutter/cupertino.dart';

class CupertinoEmptyState extends StatelessWidget {
  const CupertinoEmptyState({
    super.key,
    required this.isConfigured,
    required this.onConfigure,
  });

  final bool isConfigured;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: CupertinoPopupSurface(
                  blurSigma: 18,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xF1F6F6F8),
                      borderRadius: BorderRadius.all(Radius.circular(28)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey5.resolveFrom(
                                context,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              CupertinoIcons.rectangle_stack_badge_person_crop,
                              size: 30,
                              color: CupertinoColors.activeBlue.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Remote Codex, tuned for iPhone',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.label,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isConfigured
                                ? 'Send a prompt below. Pocket Relay keeps your remote Codex session running and turns the live stream into readable phone-sized cards.'
                                : 'Start by configuring an SSH target. After that, Pocket Relay keeps a remote Codex session open and makes the interaction readable on mobile.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              _ChecklistPill('SSH into the dev box'),
                              _ChecklistPill('Keep Codex app-server live'),
                              _ChecklistPill('Handle approvals and user input'),
                              _ChecklistPill('Show commands and answers as cards'),
                            ],
                          ),
                          if (!isConfigured) ...[
                            const SizedBox(height: 22),
                            CupertinoButton.filled(
                              onPressed: onConfigure,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.settings, size: 18),
                                  SizedBox(width: 8),
                                  Text('Configure remote'),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChecklistPill extends StatelessWidget {
  const _ChecklistPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.label,
          ),
        ),
      ),
    );
  }
}
