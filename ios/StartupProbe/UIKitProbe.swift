import UIKit

@main
final class SpectralUIKitProbeApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let view = UIViewController()
        view.view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = "UIKit 启动成功"
        title.font = .boldSystemFont(ofSize: 25)
        title.textAlignment = .center
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false
        let subtitle = UILabel()
        subtitle.text = "无 SwiftUI / C++ / Metal 引擎\niOS " + UIDevice.current.systemVersion
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        view.view.addSubview(title)
        view.view.addSubview(subtitle)
        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: view.view.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: view.view.centerYAnchor, constant: -28),
            title.leadingAnchor.constraint(greaterThanOrEqualTo: view.view.leadingAnchor, constant: 20),
            subtitle.centerXAnchor.constraint(equalTo: view.view.centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 18),
            subtitle.leadingAnchor.constraint(greaterThanOrEqualTo: view.view.leadingAnchor, constant: 20),
        ])
        window.rootViewController = view
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
