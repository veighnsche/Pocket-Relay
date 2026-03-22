import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';

bool supportsActiveTurnForegroundService([TargetPlatform? platform]) {
  return PocketPlatformBehavior.resolve(
    platform: platform,
    isWeb: kIsWeb,
  ).supportsActiveTurnForegroundService;
}

abstract interface class ForegroundServiceController {
  Future<void> setEnabled(bool enabled);
}

class MethodChannelForegroundServiceController
    implements ForegroundServiceController {
  const MethodChannelForegroundServiceController({
    MethodChannel methodChannel = const MethodChannel(
      'me.vinch.pocketrelay/background_execution',
    ),
  }) : _methodChannel = methodChannel;

  final MethodChannel _methodChannel;

  @override
  Future<void> setEnabled(bool enabled) {
    return _methodChannel.invokeMethod<void>(
      'setActiveTurnForegroundServiceEnabled',
      <String, Object?>{'enabled': enabled},
    );
  }
}

class ForegroundServiceHost extends StatefulWidget {
  const ForegroundServiceHost({
    super.key,
    required this.child,
    this.keepForegroundServiceRunning = true,
    this.foregroundServiceController =
        const MethodChannelForegroundServiceController(),
    this.supportsForegroundService,
  });

  final Widget child;
  final bool keepForegroundServiceRunning;
  final ForegroundServiceController foregroundServiceController;
  final bool? supportsForegroundService;

  @override
  State<ForegroundServiceHost> createState() => _ForegroundServiceHostState();
}

class _ForegroundServiceHostState extends State<ForegroundServiceHost> {
  bool _requestedForegroundServiceEnabled = false;

  bool get _supportsForegroundService {
    return widget.supportsForegroundService ??
        supportsActiveTurnForegroundService();
  }

  bool get _shouldEnableForegroundService {
    return _supportsForegroundService && widget.keepForegroundServiceRunning;
  }

  @override
  void initState() {
    super.initState();
    _syncForegroundService();
  }

  @override
  void didUpdateWidget(covariant ForegroundServiceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foregroundServiceController !=
            widget.foregroundServiceController &&
        _requestedForegroundServiceEnabled) {
      unawaited(
        _setEnabledSafely(oldWidget.foregroundServiceController, false),
      );
      _requestedForegroundServiceEnabled = false;
    }
    _syncForegroundService();
  }

  @override
  void dispose() {
    if (_requestedForegroundServiceEnabled) {
      _requestedForegroundServiceEnabled = false;
      unawaited(_setEnabledSafely(widget.foregroundServiceController, false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _syncForegroundService() {
    final shouldEnableForegroundService = _shouldEnableForegroundService;
    if (shouldEnableForegroundService == _requestedForegroundServiceEnabled) {
      return;
    }

    _requestedForegroundServiceEnabled = shouldEnableForegroundService;
    unawaited(
      _setEnabledSafely(
        widget.foregroundServiceController,
        shouldEnableForegroundService,
      ),
    );
  }

  Future<void> _setEnabledSafely(
    ForegroundServiceController controller,
    bool enabled,
  ) async {
    try {
      await controller.setEnabled(enabled);
    } catch (_) {
      // Ignore foreground-service failures so the app remains usable.
    }
  }
}
