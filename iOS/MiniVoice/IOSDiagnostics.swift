import Foundation
import MetricKit
import CryptoKit

/// MetricKit reports are delivered by iOS, sometimes on a later launch; no unsafe signal handler.
@MainActor
final class IOSDiagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = IOSDiagnostics()
    private let store = DiagnosticStore(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MiniVoice/diagnostics/history.json"))
    private var pending: Task<Void, Never>?
    private var started = false
    private(set) var crashCount = 0
    private(set) var storageError: String?

    func start() {
        guard !started else { return }; started = true
        MXMetricManager.shared.add(self)
        record(.event, "process started")
    }

    func record(_ kind: DiagnosticRecord.Kind, _ detail: String, id: String = UUID().uuidString) {
        let previous = pending
        let record = DiagnosticRecord(id: id, kind: kind, detail: detail)
        pending = Task {
            await previous?.value
            do {
                crashCount = try await store.append(record).crashCount
                storageError = nil
            } catch { storageError = DiagnosticRecord(kind: .failure, detail: error.localizedDescription).detail }
        }
    }

    func exportHistory() async throws -> DiagnosticHistory {
        await pending?.value
        let history = try await store.snapshot()
        if let storageError { throw NSError(domain: "MiniVoice.Diagnostics", code: 1, userInfo: [NSLocalizedDescriptionKey: "诊断记录保存失败：" + storageError]) }
        return history
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for (index, crash) in (payload.crashDiagnostics ?? []).enumerated() {
                let data = crash.jsonRepresentation()
                let detail = (try? DiagnosticRecord.metricDetail(data)) ?? "MetricKit crash diagnostic could not be decoded"
                let identity = Data("\(payload.timeStampBegin.timeIntervalSince1970)-\(payload.timeStampEnd.timeIntervalSince1970)-\(index)-".utf8) + data
                let id = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
                Task { @MainActor in self.record(.crash, detail, id: id) }
            }
            let hangs = payload.hangDiagnostics?.count ?? 0
            let cpu = payload.cpuExceptionDiagnostics?.count ?? 0
            let disk = payload.diskWriteExceptionDiagnostics?.count ?? 0
            if hangs + cpu + disk > 0 {
                Task { @MainActor in self.record(.event, "MetricKit hangs=\(hangs) cpu=\(cpu) disk=\(disk)") }
            }
        }
    }
}
