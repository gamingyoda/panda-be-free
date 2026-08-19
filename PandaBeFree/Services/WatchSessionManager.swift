import Foundation
@preconcurrency import WatchConnectivity

final class WatchSessionManager: NSObject, WCSessionDelegate, @unchecked Sendable {
    typealias StateProvider = @Sendable () async -> WatchPrinterSnapshot
    typealias CommandHandler = @Sendable (WatchPrinterCommand) async -> WatchCommandResult

    static let shared = WatchSessionManager()

    private let callbackLock = NSLock()
    private var stateProvider: StateProvider?
    private var commandHandler: CommandHandler?
    private var hasActivated = false

    private override init() {
        super.init()
    }

    func configure(
        stateProvider: @escaping StateProvider,
        commandHandler: @escaping CommandHandler
    ) {
        callbackLock.lock()
        self.stateProvider = stateProvider
        self.commandHandler = commandHandler
        callbackLock.unlock()
    }

    func activate() {
        guard WCSession.isSupported(), !hasActivated else { return }
        hasActivated = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func publish(_ snapshot: WatchPrinterSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }

        do {
            try session.updateApplicationContext(snapshot.message)
        } catch {
            // A later state update will retry. Watch delivery must not interrupt printing UI updates.
        }

        if session.isReachable {
            session.sendMessage(snapshot.message, replyHandler: nil, errorHandler: nil)
        }
    }

    private func callbacks() -> (StateProvider?, CommandHandler?) {
        callbackLock.lock()
        defer { callbackLock.unlock() }
        return (stateProvider, commandHandler)
    }

    private func sendCurrentState() async {
        let (provider, _) = callbacks()
        guard let provider else { return }
        publish(await provider())
    }

    func session(
        _: WCSession,
        activationDidCompleteWith _: WCSessionActivationState,
        error _: (any Error)?
    ) {
        Task { [weak self] in
            await self?.sendCurrentState()
        }
    }

    func sessionDidBecomeInactive(_: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(
        _: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let kind = (message[WatchMessageKey.kind] as? String).flatMap(WatchMessageKind.init(rawValue:))
        let reply = ReplyHandlerBox(replyHandler)

        switch kind {
        case .requestState:
            let (provider, _) = callbacks()
            Task {
                guard let provider else {
                    reply.call(WatchCommandResult.failed("iPhone state is unavailable").dictionary)
                    return
                }
                let snapshot = await provider()
                reply.call(snapshot.message)
            }

        case .command:
            guard let rawCommand = message[WatchMessageKey.command] as? String,
                  let command = WatchPrinterCommand(rawValue: rawCommand)
            else {
                reply.call(WatchCommandResult.failed("Unknown command").dictionary)
                return
            }

            let (provider, handler) = callbacks()
            Task {
                guard let handler else {
                    reply.call(WatchCommandResult.failed("iPhone app is not ready").dictionary)
                    return
                }

                let result = await handler(command)
                var response: [String: Any] = [:]
                if let provider {
                    let snapshot = await provider()
                    response = snapshot.message
                }
                response.merge(result.dictionary) { _, new in new }
                reply.call(response)
            }

        default:
            reply.call(WatchCommandResult.failed("Unsupported request").dictionary)
        }
    }
}

private final class ReplyHandlerBox: @unchecked Sendable {
    private let handler: ([String: Any]) -> Void

    init(_ handler: @escaping ([String: Any]) -> Void) {
        self.handler = handler
    }

    func call(_ message: [String: Any]) {
        handler(message)
    }
}
