import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        DebugLogger.log("🚀 AppDelegate: didFinishLaunchingWithOptions called")
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, 
                     configurationForConnecting connectingSceneSession: UISceneSession, 
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        DebugLogger.log("🔧 AppDelegate: configurationForConnecting called")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

// MARK: - Scene Delegate

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        DebugLogger.log("🌟 SceneDelegate: scene willConnectTo called")
        
        guard let windowScene = (scene as? UIWindowScene) else {
            DebugLogger.error("Failed to cast scene to UIWindowScene")
            return
        }
        
        DebugLogger.log("✅ Got UIWindowScene: \(windowScene)")
        
        // Create window using the modern UIWindowScene API
        window = UIWindow(windowScene: windowScene)
        DebugLogger.log("✅ Window created")
        
        let viewController = SceneViewController()
        DebugLogger.log("✅ SceneViewController created")
        
        window?.rootViewController = viewController
        DebugLogger.log("✅ Root view controller set")
        
        window?.makeKeyAndVisible()
        DebugLogger.log("✅ Window made key and visible")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        DebugLogger.log("🟢 Scene did become active")
    }
}
