import Foundation
import LocalAuthentication
import Observation
import DevotionCore

/// Face ID / 密码锁。开启后，每次 App 回到前台都需要验证。
@Observable
@MainActor
final class AppLock {
    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    /// 每次上锁后只自动弹出一次验证；用户取消后需手动点「解锁」，避免反复弹窗。
    private var shouldAutoPrompt = false

    func lock() {
        isLocked = true
        shouldAutoPrompt = true
    }

    func autoUnlockIfNeeded(language: Language) async {
        guard isLocked, shouldAutoPrompt else { return }
        shouldAutoPrompt = false
        await unlock(language: language)
    }

    func unlock(language: Language) async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // 设备没有设置锁屏密码，无法验证。为免把用户锁在 App 外面，直接解锁。
            isLocked = false
            return
        }
        do {
            let reason = language.pick("解锁你的灵修笔记", "Unlock your devotion journal")
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if success {
                isLocked = false
            }
        } catch {
            // 用户取消或验证失败：保持锁定，可以再点「解锁」重试
        }
    }

    /// 设备是否可以使用 Face ID / Touch ID / 密码验证。
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static func methodName(_ language: Language) -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return language.pick("密码", "Passcode")
        }
    }

    /// 开启锁之前先验证一次，确认本人且设备支持。
    static func confirmIdentity(language: Language) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        let reason = language.pick("开启 App 锁", "Turn on app lock")
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
