import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Debug.log("🚀 AppDelegate: didFinishLaunchingWithOptions called")
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, 
                     configurationForConnecting connectingSceneSession: UISceneSession, 
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        Debug.log("🔧 AppDelegate: configurationForConnecting called")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

// MARK: - Scene Delegate

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        Debug.log("🌟 SceneDelegate: scene willConnectTo called")
        
        guard let windowScene = (scene as? UIWindowScene) else {
            Debug.log("❌ Failed to cast scene to UIWindowScene")
            return
        }
        
        Debug.log("✅ Got UIWindowScene: \(windowScene)")
        
        // Create window using the modern UIWindowScene API
        window = UIWindow(windowScene: windowScene)
        Debug.log("✅ Window created")
        
        let viewController = SceneViewController()
        Debug.log("✅ SceneViewController created")
        
        window?.rootViewController = viewController
        Debug.log("✅ Root view controller set")
        
        window?.makeKeyAndVisible()
        Debug.log("✅ Window made key and visible")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        Debug.log("🟢 Scene did become active")
    }
}

