import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🚀 AppDelegate: didFinishLaunchingWithOptions called")
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, 
                     configurationForConnecting connectingSceneSession: UISceneSession, 
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("🔧 AppDelegate: configurationForConnecting called")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

// MARK: - Scene Delegate

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("🌟 SceneDelegate: scene willConnectTo called")
        
        guard let windowScene = (scene as? UIWindowScene) else {
            print("❌ Failed to cast scene to UIWindowScene")
            return
        }
        
        print("✅ Got UIWindowScene: \(windowScene)")
        
        // Create window using the modern UIWindowScene API
        window = UIWindow(windowScene: windowScene)
        print("✅ Window created")
        
        let viewController = ModeContainerViewController()
        print("✅ ModeContainerViewController created")

        window?.rootViewController = viewController
        print("✅ Root view controller set")
        
        window?.makeKeyAndVisible()
        print("✅ Window made key and visible")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("🟢 Scene did become active")
    }
}

