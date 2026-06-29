import Foundation

#if canImport(UIKit)
import UIKit

@MainActor
final class ConsentManager {
    /// Indicates whether the host app currently has a visible presenter and active UI for consent.
    /// - Returns: `true` when the consent alert can be presented immediately.
    func canPresentConsent() -> Bool {
        topViewController() != nil && UIApplication.shared.applicationState == .active
    }

    /// Presents the consent dialog on the current top-most view controller.
    /// - Parameter copy: The user-facing consent strings to display in the alert.
    /// - Returns: `true` when the user accepts logging, otherwise `false`.
    func requestConsent(copy: ConsentCopy) async -> Bool {
        guard canPresentConsent(), let presenter = topViewController() else {
            return false
        }

        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: copy.title,
                message: copy.message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: copy.declineButtonTitle, style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            alert.addAction(UIAlertAction(title: copy.acceptButtonTitle, style: .default) { _ in
                continuation.resume(returning: true)
            })
            presenter.present(alert, animated: true)
        }
    }

    /// Walks common container hierarchies so the consent sheet appears from the visible screen.
    /// - Parameter root: The current root or container view controller to inspect.
    /// - Returns: The top-most visible view controller that can present the consent alert.
    private func topViewController(
        from root: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = root as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = root as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
}
#else
@MainActor
final class ConsentManager {
    /// Non-UIKit targets cannot present consent, so foreground prompting is unavailable.
    /// - Returns: Always `false` on non-UIKit platforms.
    func canPresentConsent() -> Bool {
        false
    }

    /// Non-UIKit targets cannot present consent, so logging is rejected by default.
    /// - Parameter copy: The user-facing consent strings that would be shown on UIKit targets.
    /// - Returns: Always `false` on non-UIKit platforms.
    func requestConsent(copy: ConsentCopy) async -> Bool {
        false
    }
}
#endif
