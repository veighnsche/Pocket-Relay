import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    registerBackgroundExecutionChannelIfNeeded()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    registerBackgroundExecutionChannelIfNeeded()
  }

  private func registerBackgroundExecutionChannelIfNeeded() {
    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      return
    }

    BackgroundExecutionCoordinator.shared.register(with: flutterViewController)
  }
}
