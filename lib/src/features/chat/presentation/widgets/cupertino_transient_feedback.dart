import 'dart:async';

import 'package:flutter/cupertino.dart';

class CupertinoTransientFeedbackPresenter {
  const CupertinoTransientFeedbackPresenter();

  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  void show({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _dismissTimer?.cancel();
    _removeActiveEntry();

    final entry = OverlayEntry(
      builder: (context) {
        return CupertinoTransientFeedbackBanner(message: message);
      },
    );
    _activeEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, () {
      if (_activeEntry == entry) {
        _activeEntry = null;
      }
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  @visibleForTesting
  static void dismissActiveEntry() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _removeActiveEntry();
  }

  static void _removeActiveEntry() {
    final entry = _activeEntry;
    _activeEntry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }
}

class CupertinoTransientFeedbackBanner extends StatelessWidget {
  const CupertinoTransientFeedbackBanner({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: CupertinoPopupSurface(
              blurSigma: 18,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xEEF5F5F7),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.info_circle_fill,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.label,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
