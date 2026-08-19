import Foundation
import Observation
import WatchKit
@preconcurrency import WatchConnectivity

@MainActor
@Observable
final class WatchAppModel: NSObject {
    private(set) var snapshot = WatchPrinterSnapshot.empty
    private(set) var isReachable = false
    private(set) var isSending = false
    private(set) var feedbackMessage: String?
    private(set) var feedbackIsError = false

    private var session: WCSession?

    override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else {
            showFeedback("WatchConnectivity is unavailable", isError: true)
            return
        }

        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()

        if let initial = WatchPrinterSnapshot(message: session.applicationContext) {
            snapshot = initial
        }
    }

    func requestState() {
        guard let session, session.activationState == .activated else { return }
        guard session.isReachable else {
            isReachable = false
            return
        }

        session.sendMessage(
            [WatchMessageKey.kind: WatchMessageKind.requestState.rawValue],
            replyHandler: { [weak self] message in
                guard let state = WatchPrinterSnapshot(message: message) else { return }
                Task { @MainActor in
                    self?.snapshot = state
                    self?.isReachable = true
                }
            },
            errorHandler: { [weak self] error in
                let text = error.localizedDescription
                Task { @MainActor in
                    self?.showFeedback(text, isError: true)
                }
            }
        )
    }

    func send(_ command: WatchPrinterCommand) {
        guard let session, session.activationState == .activated, session.isReachable else {
            showFeedback("Bring the paired iPhone nearby and try again", isError: true)
            return
        }

        isSending = true
        feedbackMessage = nil
        session.sendMessage(
            [
                WatchMessageKey.kind: WatchMessageKind.command.rawValue,
                WatchMessageKey.command: command.rawValue,
            ],
            replyHandler: { [weak self] message in
                let result = WatchCommandResult(message: message)
                let state = WatchPrinterSnapshot(message: message)
                Task { @MainActor in
                    if let state { self?.snapshot = state }
                    self?.isSending = false
                    self?.showFeedback(result.message, isError: !result.success)
                    WKInterfaceDevice.current().play(result.success ? .success : .failure)
                }
            },
            errorHandler: { [weak self] error in
                let text = error.localizedDescription
                Task { @MainActor in
                    self?.isSending = false
                    self?.showFeedback(text, isError: true)
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        )
    }

    func clearFeedback() {
        feedbackMessage = nil
    }

    private func apply(_ snapshot: WatchPrinterSnapshot) {
        self.snapshot = snapshot
        isReachable = WCSession.default.isReachable
    }

    private func showFeedback(_ message: String, isError: Bool) {
        feedbackMessage = message
        feedbackIsError = isError
    }
}

extension WatchAppModel: WCSessionDelegate {
    nonisolated func session(
        _: WCSession,
        activationDidCompleteWith _: WCSessionActivationState,
        error: (any Error)?
    ) {
        let errorText = error?.localizedDescription
        Task { @MainActor [weak self] in
            self?.isReachable = WCSession.default.isReachable
            if let errorText {
                self?.showFeedback(errorText, isError: true)
            } else {
                self?.requestState()
            }
        }
    }

    nonisolated func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let state = WatchPrinterSnapshot(message: applicationContext) else { return }
        Task { @MainActor [weak self] in
            self?.apply(state)
        }
    }

    nonisolated func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        guard let state = WatchPrinterSnapshot(message: message) else { return }
        Task { @MainActor [weak self] in
            self?.apply(state)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isReachable = reachable
            if reachable { self?.requestState() }
        }
    }
}
