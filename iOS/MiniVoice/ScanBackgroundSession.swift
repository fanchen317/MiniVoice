import BackgroundTasks
import UIKit
import UserNotifications

/// Owns system execution and presentation; the library remains the source of scan truth.
@MainActor
final class ScanBackgroundSession: NSObject, UNUserNotificationCenterDelegate {
    private let identifier = (Bundle.main.bundleIdentifier ?? "com.xcosmos.MiniVoice.ios") + ".scan.progress"
    private var token: UUID?
    private var continued: BGTask?
    private var fallback = UIBackgroundTaskIdentifier.invalid
    private var expire: (() -> Void)?
    private var completed = 0, total = 0
    private var detail = "正在查找音乐文件"
    private var lastUpdate = Date.distantPast
    private var lastNotice = Date.distantPast
    private var registered = false
    private var lastResult = false
    var onOpen: (() -> Void)?
    private(set) var execution = "前台扫描"

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        if #available(iOS 26.0, *) {
            registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { [weak self] task in
                Task { @MainActor in self?.attach(task) }
            }
        }
    }

    func begin(_ generation: UUID, userInitiated: Bool, expiration: @escaping () -> Void) {
        finish(success: false, notify: false)
        token = generation; expire = expiration; completed = 0; total = 0; detail = "正在查找音乐文件"
        lastUpdate = .distantPast; lastNotice = .distantPast; lastResult = false
        execution = "前台扫描；后台时间不足时暂停，返回后继续"
        fallback = UIApplication.shared.beginBackgroundTask(withName: "MiniVoice music scan") { [weak self] in
            Task { @MainActor in
                guard let self, self.token == generation, self.continued == nil else { return }
                let expire = self.expire; self.finish(success: false, notify: true, message: "扫描已暂停，返回应用继续"); expire?()
            }
        }
        if #available(iOS 26.0, *), userInitiated, registered,
           UIApplication.shared.applicationState == .active {
            let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "扫描音乐库", subtitle: detail)
            request.strategy = .fail
            do {
                try BGTaskScheduler.shared.submit(request)
                execution = "正在申请后台扫描"
            } catch {
                execution = "系统暂未允许持续后台扫描，返回应用可继续"
                IOSDiagnostics.shared.record(.failure, "continued scan submission: \(error.localizedDescription)")
            }
        }
    }

    @available(iOS 26.0, *)
    private func attach(_ task: BGTask) {
        guard let task = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: false); return }
        guard token != nil else { task.setTaskCompleted(success: lastResult); return }
        if continued === task { return }
        continued?.setTaskCompleted(success: false)
        IOSDiagnostics.shared.record(.event, "continued scan attached")
        continued = task; execution = "可后台扫描；可在系统实时活动中查看或停止"
        if fallback != .invalid { UIApplication.shared.endBackgroundTask(fallback); fallback = .invalid }
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                guard let self, self.continued === task else { return }
                let expire = self.expire; self.finish(success: false, notify: true, message: "扫描已停止，返回应用可继续"); expire?()
            }
        }
        update(completed: completed, total: total, detail: detail, force: true)
    }

    func update(completed: Int, total: Int, detail: String, force: Bool = false) {
        self.completed = completed; self.total = total; self.detail = detail
        guard force || Date().timeIntervalSince(lastUpdate) >= 0.5 || total > 0 && completed == total else { return }
        lastUpdate = Date()
        if continued == nil, UIApplication.shared.applicationState != .active, Date().timeIntervalSince(lastNotice) >= 5, let generation = token {
            lastNotice = Date()
            Task { [weak self] in
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                guard let self, self.token == generation, settings.authorizationStatus == .authorized else { return }
                let content = UNMutableNotificationContent(); content.title = "正在扫描音乐库"
                content.body = total > 0 ? "已处理 \(completed) / \(total) 首，点按查看" : "已发现 \(completed) 首，正在查找"
                content.userInfo = ["scan": true]
                try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "library-scan-progress", content: content, trigger: nil))
            }
        }
        if #available(iOS 26.0, *), let task = continued as? BGContinuedProcessingTask {
            // During discovery the total is unknown; don't invent a percentage.
            task.progress.totalUnitCount = total > 0 ? Int64(total + 1) : -1
            task.progress.completedUnitCount = total > 0 ? Int64(completed) : 0
            task.updateTitle("扫描音乐库", subtitle: total > 0 ? "已处理 \(completed) / \(total) 首" : "已发现 \(completed) 首，正在查找")
        }
    }

    func finish(success: Bool, notify: Bool, message: String? = nil) {
        guard token != nil else { return }
        token = nil; expire = nil; lastResult = success
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["library-scan-progress"])
        if let task = continued {
            if #available(iOS 26.0, *), let task = task as? BGContinuedProcessingTask, success {
                task.progress.completedUnitCount = task.progress.totalUnitCount
                task.updateTitle("音乐库扫描完成", subtitle: "已处理 \(completed) 首歌曲")
            }
            task.setTaskCompleted(success: success); continued = nil
        }
        if #available(iOS 26.0, *) { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier) }
        if fallback != .invalid { UIApplication.shared.endBackgroundTask(fallback); fallback = .invalid }
        execution = message ?? (success ? "扫描完成" : "扫描已停止")
        if notify, UIApplication.shared.applicationState != .active {
            let content = UNMutableNotificationContent(); content.title = success ? "音乐库扫描完成" : "音乐库扫描已暂停"
            content.body = message ?? "已处理 \(completed) 首歌曲，点按查看"; content.userInfo = ["scan": true]
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "library-scan-result", content: content, trigger: nil))
        }
    }

    func requestNotifications() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.content.userInfo["scan"] as? Bool == true else { return }
        await MainActor.run { onOpen?() }
    }
}
