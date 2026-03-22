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

abstract interface class NotificationPermissionController {
  Future<bool> isGranted();

  Future<bool> requestPermission();
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

class MethodChannelNotificationPermissionController
    implements NotificationPermissionController {
  const MethodChannelNotificationPermissionController({
    MethodChannel methodChannel = const MethodChannel(
      'me.vinch.pocketrelay/background_execution',
    ),
  }) : _methodChannel = methodChannel;

  final MethodChannel _methodChannel;

  @override
  Future<bool> isGranted() async {
    return await _methodChannel.invokeMethod<bool>(
          'notificationsPermissionGranted',
        ) ??
        true;
  }

  @override
  Future<bool> requestPermission() async {
    return await _methodChannel.invokeMethod<bool>(
          'requestNotificationPermission',
        ) ??
        false;
  }
}

class ForegroundServiceHost extends StatefulWidget {
  const ForegroundServiceHost({
    super.key,
    required this.child,
    this.keepForegroundServiceRunning = true,
    this.foregroundServiceController =
        const MethodChannelForegroundServiceController(),
    this.notificationPermissionController =
        const MethodChannelNotificationPermissionController(),
    this.supportsForegroundService,
  });

  final Widget child;
  final bool keepForegroundServiceRunning;
  final ForegroundServiceController foregroundServiceController;
  final NotificationPermissionController notificationPermissionController;
  final bool? supportsForegroundService;

  @override
  State<ForegroundServiceHost> createState() => _ForegroundServiceHostState();
}

class _ForegroundServiceHostState extends State<ForegroundServiceHost>
    with WidgetsBindingObserver {
  bool _requestedForegroundServiceEnabled = false;
  bool _isRequestingNotificationPermission = false;
  bool _notificationPermissionDeniedForCurrentRequest = false;
  int _notificationPermissionRequestEpoch = 0;

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
    WidgetsBinding.instance.addObserver(this);
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
    if (oldWidget.notificationPermissionController !=
        widget.notificationPermissionController) {
      _notificationPermissionRequestEpoch += 1;
      _isRequestingNotificationPermission = false;
      _notificationPermissionDeniedForCurrentRequest = false;
    }
    _syncForegroundService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_requestedForegroundServiceEnabled) {
      _requestedForegroundServiceEnabled = false;
      unawaited(_setEnabledSafely(widget.foregroundServiceController, false));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_notificationPermissionDeniedForCurrentRequest) {
      return;
    }

    _notificationPermissionDeniedForCurrentRequest = false;
    _syncForegroundService();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _syncForegroundService() {
    final shouldEnableForegroundService = _shouldEnableForegroundService;
    if (!shouldEnableForegroundService) {
      _notificationPermissionRequestEpoch += 1;
      _isRequestingNotificationPermission = false;
      _notificationPermissionDeniedForCurrentRequest = false;
      if (!_requestedForegroundServiceEnabled) {
        return;
      }

      _requestedForegroundServiceEnabled = false;
      unawaited(_setEnabledSafely(widget.foregroundServiceController, false));
      return;
    }

    if (_requestedForegroundServiceEnabled ||
        _isRequestingNotificationPermission ||
        _notificationPermissionDeniedForCurrentRequest) {
      return;
    }

    _isRequestingNotificationPermission = true;
    final requestEpoch = ++_notificationPermissionRequestEpoch;
    unawaited(_requestNotificationPermissionAndEnable(requestEpoch));
  }

  Future<void> _requestNotificationPermissionAndEnable(int requestEpoch) async {
    try {
      var notificationPermissionGranted =
          await _isNotificationPermissionGrantedSafely();
      if (!notificationPermissionGranted) {
        notificationPermissionGranted =
            await _requestNotificationPermissionSafely();
      }

      if (!mounted || requestEpoch != _notificationPermissionRequestEpoch) {
        return;
      }
      if (!notificationPermissionGranted) {
        _notificationPermissionDeniedForCurrentRequest = true;
        return;
      }
      if (_requestedForegroundServiceEnabled ||
          !_shouldEnableForegroundService) {
        return;
      }

      _requestedForegroundServiceEnabled = true;
      await _setEnabledSafely(widget.foregroundServiceController, true);
    } finally {
      if (mounted && requestEpoch == _notificationPermissionRequestEpoch) {
        _isRequestingNotificationPermission = false;
      }
    }
  }

  Future<bool> _isNotificationPermissionGrantedSafely() async {
    try {
      return await widget.notificationPermissionController.isGranted();
    } catch (_) {
      return true;
    }
  }

  Future<bool> _requestNotificationPermissionSafely() async {
    try {
      return await widget.notificationPermissionController.requestPermission();
    } catch (_) {
      return true;
    }
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
