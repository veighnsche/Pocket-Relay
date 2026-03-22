import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';

bool supportsFiniteBackgroundGrace([TargetPlatform? platform]) {
  return PocketPlatformBehavior.resolve(
    platform: platform,
    isWeb: kIsWeb,
  ).supportsFiniteBackgroundGrace;
}

abstract interface class BackgroundGraceController {
  Future<void> setEnabled(bool enabled);
}

class MethodChannelBackgroundGraceController
    implements BackgroundGraceController {
  const MethodChannelBackgroundGraceController({
    MethodChannel methodChannel = const MethodChannel(
      'me.vinch.pocketrelay/background_execution',
    ),
  }) : _methodChannel = methodChannel;

  final MethodChannel _methodChannel;

  @override
  Future<void> setEnabled(bool enabled) {
    return _methodChannel.invokeMethod<void>(
      'setFiniteBackgroundTaskEnabled',
      <String, Object?>{'enabled': enabled},
    );
  }
}

class BackgroundGraceHost extends StatefulWidget {
  const BackgroundGraceHost({
    super.key,
    required this.child,
    this.keepBackgroundGraceAlive = true,
    this.backgroundGraceController =
        const MethodChannelBackgroundGraceController(),
    this.supportsBackgroundGrace,
  });

  final Widget child;
  final bool keepBackgroundGraceAlive;
  final BackgroundGraceController backgroundGraceController;
  final bool? supportsBackgroundGrace;

  @override
  State<BackgroundGraceHost> createState() => _BackgroundGraceHostState();
}

class _BackgroundGraceHostState extends State<BackgroundGraceHost>
    with WidgetsBindingObserver {
  AppLifecycleState? _appLifecycleState;
  bool _requestedBackgroundGraceEnabled = false;

  bool get _supportsBackgroundGrace {
    return widget.supportsBackgroundGrace ?? supportsFiniteBackgroundGrace();
  }

  bool get _shouldEnableBackgroundGrace {
    return _supportsBackgroundGrace &&
        widget.keepBackgroundGraceAlive &&
        _appLifecycleState != null &&
        _appLifecycleState != AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLifecycleState = WidgetsBinding.instance.lifecycleState;
    _syncBackgroundGrace();
  }

  @override
  void didUpdateWidget(covariant BackgroundGraceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundGraceController !=
            widget.backgroundGraceController &&
        _requestedBackgroundGraceEnabled) {
      unawaited(_setEnabledSafely(oldWidget.backgroundGraceController, false));
      _requestedBackgroundGraceEnabled = false;
    }
    _syncBackgroundGrace();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    _syncBackgroundGrace();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_requestedBackgroundGraceEnabled) {
      _requestedBackgroundGraceEnabled = false;
      unawaited(_setEnabledSafely(widget.backgroundGraceController, false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _syncBackgroundGrace() {
    final shouldEnableBackgroundGrace = _shouldEnableBackgroundGrace;
    if (shouldEnableBackgroundGrace == _requestedBackgroundGraceEnabled) {
      return;
    }

    _requestedBackgroundGraceEnabled = shouldEnableBackgroundGrace;
    unawaited(
      _setEnabledSafely(
        widget.backgroundGraceController,
        shouldEnableBackgroundGrace,
      ),
    );
  }

  Future<void> _setEnabledSafely(
    BackgroundGraceController controller,
    bool enabled,
  ) async {
    try {
      await controller.setEnabled(enabled);
    } catch (_) {
      // Ignore background-grace failures so the app remains usable.
    }
  }
}
