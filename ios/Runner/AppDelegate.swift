import Flutter
import UIKit

final class BackgroundExecutionCoordinator {
  static let shared = BackgroundExecutionCoordinator()

  private init() {}

  private var finiteBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  private weak var flutterViewController: FlutterViewController?
  private var backgroundExecutionChannel: FlutterMethodChannel?

  func register(with flutterViewController: FlutterViewController) {
    guard self.flutterViewController !== flutterViewController else {
      return
    }

    backgroundExecutionChannel?.setMethodCallHandler(nil)

    let channel = FlutterMethodChannel(
      name: "me.vinch.pocketrelay/background_execution",
      binaryMessenger: flutterViewController.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleBackgroundExecutionCall(call, result: result)
    }

    self.flutterViewController = flutterViewController
    backgroundExecutionChannel = channel
  }

  private func handleBackgroundExecutionCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard call.method == "setFiniteBackgroundTaskEnabled" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let enabled = arguments["enabled"] as? Bool
    else {
      result(
        FlutterError(
          code: "invalid-arguments",
          message: "Expected a boolean enabled flag.",
          details: nil
        )
      )
      return
    }

    if enabled {
      beginFiniteBackgroundTaskIfNeeded()
    } else {
      endFiniteBackgroundTaskIfNeeded()
    }
    result(nil)
  }

  private func beginFiniteBackgroundTaskIfNeeded() {
    guard finiteBackgroundTask == .invalid else {
      return
    }

    finiteBackgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "PocketRelayLiveTurn"
    ) { [weak self] in
      self?.endFiniteBackgroundTaskIfNeeded()
    }
  }

  private func endFiniteBackgroundTaskIfNeeded() {
    guard finiteBackgroundTask != .invalid else {
      return
    }

    let task = finiteBackgroundTask
    finiteBackgroundTask = .invalid
    UIApplication.shared.endBackgroundTask(task)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
