import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var finiteBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var backgroundExecutionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    registerBackgroundExecutionChannel()
    return didFinishLaunching
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func registerBackgroundExecutionChannel() {
    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "me.vinch.pocketrelay/background_execution",
      binaryMessenger: flutterViewController.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleBackgroundExecutionCall(call, result: result)
    }
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
