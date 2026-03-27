part of 'work_log_group_surface.dart';

class _WorkLogRowShell extends StatelessWidget {
  const _WorkLogRowShell({
    required this.icon,
    required this.accent,
    this.label,
    this.title,
    this.titleWidget,
    this.titleMonospace = false,
    this.statusBadge,
    this.onTap,
    this.details = const <Widget>[],
  });

  final IconData icon;
  final Color accent;
  final String? label;
  final String? title;
  final Widget? titleWidget;
  final bool titleMonospace;
  final Widget? statusBadge;
  final VoidCallback? onTap;
  final List<Widget> details;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    final body = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusBadge != null) ...[
                  statusBadge!,
                  const SizedBox(height: 5),
                ],
                if (label != null) ...[
                  Text(
                    label!,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                if (titleWidget != null)
                  titleWidget!
                else if (title != null)
                  Text(
                    title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cards.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      height: 1.15,
                      fontFamily: titleMonospace ? 'monospace' : null,
                    ),
                  ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  ...details.indexed.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 2),
                      child: entry.$2,
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final tap = onTap;
    if (tap == null) {
      return body;
    }

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: PocketRadii.circular(PocketRadii.sm),
          onTap: tap,
          child: body,
        ),
      ),
    );
  }
}

Widget? _specialCommandStatusBadge({
  required ThemeData theme,
  required bool isRunning,
  required int? exitCode,
}) {
  if (isRunning) {
    return TranscriptBadge(
      label: 'running',
      color: tealAccent(theme.brightness),
    );
  }
  if (exitCode != null && exitCode != 0) {
    return TranscriptBadge(
      label: 'exit $exitCode',
      color: redAccent(theme.brightness),
    );
  }
  return null;
}
