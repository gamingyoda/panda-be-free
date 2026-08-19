import Foundation

enum WatchMessageKey {
    static let kind = "kind"
    static let command = "command"
    static let success = "success"
    static let message = "message"
    static let isConfigured = "isConfigured"
    static let isConnected = "isConnected"
    static let printerName = "printerName"
    static let status = "status"
    static let progress = "progress"
    static let remainingMinutes = "remainingMinutes"
    static let jobName = "jobName"
    static let layerNum = "layerNum"
    static let totalLayers = "totalLayers"
    static let nozzleTemp = "nozzleTemp"
    static let nozzleTargetTemp = "nozzleTargetTemp"
    static let bedTemp = "bedTemp"
    static let bedTargetTemp = "bedTargetTemp"
    static let chamberTemp = "chamberTemp"
    static let lastUpdated = "lastUpdated"
}

enum WatchMessageKind: String, Sendable {
    case state
    case requestState
    case command
    case response
}

enum WatchPrinterCommand: String, Sendable {
    case pause
    case resume
    case stop
    case refresh
}

enum WatchPrinterStatus: String, Sendable {
    case preparing = "starting"
    case printing
    case paused
    case issue
    case completed
    case cancelled
    case idle

    var label: String {
        switch self {
        case .preparing: "Preparing"
        case .printing: "Printing"
        case .paused: "Paused"
        case .issue: "Issue"
        case .completed: "Complete"
        case .cancelled: "Cancelled"
        case .idle: "Idle"
        }
    }
}

struct WatchPrinterSnapshot: Equatable, Sendable {
    var isConfigured: Bool
    var isConnected: Bool
    var printerName: String
    var status: WatchPrinterStatus
    var progress: Int
    var remainingMinutes: Int
    var jobName: String
    var layerNum: Int
    var totalLayers: Int
    var nozzleTemp: Int?
    var nozzleTargetTemp: Int?
    var bedTemp: Int?
    var bedTargetTemp: Int?
    var chamberTemp: Int?
    var lastUpdated: Date?

    static let empty = WatchPrinterSnapshot(
        isConfigured: false,
        isConnected: false,
        printerName: "3D Printer",
        status: .idle,
        progress: 0,
        remainingMinutes: 0,
        jobName: "",
        layerNum: 0,
        totalLayers: 0
    )

    init(
        isConfigured: Bool,
        isConnected: Bool,
        printerName: String,
        status: WatchPrinterStatus,
        progress: Int,
        remainingMinutes: Int,
        jobName: String,
        layerNum: Int,
        totalLayers: Int,
        nozzleTemp: Int? = nil,
        nozzleTargetTemp: Int? = nil,
        bedTemp: Int? = nil,
        bedTargetTemp: Int? = nil,
        chamberTemp: Int? = nil,
        lastUpdated: Date? = nil
    ) {
        self.isConfigured = isConfigured
        self.isConnected = isConnected
        self.printerName = printerName
        self.status = status
        self.progress = max(0, min(100, progress))
        self.remainingMinutes = max(0, remainingMinutes)
        self.jobName = jobName
        self.layerNum = max(0, layerNum)
        self.totalLayers = max(0, totalLayers)
        self.nozzleTemp = nozzleTemp
        self.nozzleTargetTemp = nozzleTargetTemp
        self.bedTemp = bedTemp
        self.bedTargetTemp = bedTargetTemp
        self.chamberTemp = chamberTemp
        self.lastUpdated = lastUpdated
    }

    init?(message: [String: Any]) {
        guard message[WatchMessageKey.isConfigured] != nil else { return nil }

        isConfigured = Self.bool(message[WatchMessageKey.isConfigured])
        isConnected = Self.bool(message[WatchMessageKey.isConnected])
        printerName = Self.string(message[WatchMessageKey.printerName], default: "3D Printer")
        status = WatchPrinterStatus(
            rawValue: Self.string(message[WatchMessageKey.status], default: WatchPrinterStatus.idle.rawValue)
        ) ?? .idle
        progress = max(0, min(100, Self.int(message[WatchMessageKey.progress])))
        remainingMinutes = max(0, Self.int(message[WatchMessageKey.remainingMinutes]))
        jobName = Self.string(message[WatchMessageKey.jobName])
        layerNum = max(0, Self.int(message[WatchMessageKey.layerNum]))
        totalLayers = max(0, Self.int(message[WatchMessageKey.totalLayers]))
        nozzleTemp = Self.optionalInt(message[WatchMessageKey.nozzleTemp])
        nozzleTargetTemp = Self.optionalInt(message[WatchMessageKey.nozzleTargetTemp])
        bedTemp = Self.optionalInt(message[WatchMessageKey.bedTemp])
        bedTargetTemp = Self.optionalInt(message[WatchMessageKey.bedTargetTemp])
        chamberTemp = Self.optionalInt(message[WatchMessageKey.chamberTemp])

        if let timestamp = message[WatchMessageKey.lastUpdated] as? TimeInterval {
            lastUpdated = Date(timeIntervalSince1970: timestamp)
        } else if let number = message[WatchMessageKey.lastUpdated] as? NSNumber {
            lastUpdated = Date(timeIntervalSince1970: number.doubleValue)
        } else {
            lastUpdated = nil
        }
    }

    var message: [String: Any] {
        var value: [String: Any] = [
            WatchMessageKey.kind: WatchMessageKind.state.rawValue,
            WatchMessageKey.isConfigured: isConfigured,
            WatchMessageKey.isConnected: isConnected,
            WatchMessageKey.printerName: printerName,
            WatchMessageKey.status: status.rawValue,
            WatchMessageKey.progress: progress,
            WatchMessageKey.remainingMinutes: remainingMinutes,
            WatchMessageKey.jobName: jobName,
            WatchMessageKey.layerNum: layerNum,
            WatchMessageKey.totalLayers: totalLayers,
        ]

        if let nozzleTemp { value[WatchMessageKey.nozzleTemp] = nozzleTemp }
        if let nozzleTargetTemp { value[WatchMessageKey.nozzleTargetTemp] = nozzleTargetTemp }
        if let bedTemp { value[WatchMessageKey.bedTemp] = bedTemp }
        if let bedTargetTemp { value[WatchMessageKey.bedTargetTemp] = bedTargetTemp }
        if let chamberTemp { value[WatchMessageKey.chamberTemp] = chamberTemp }
        if let lastUpdated { value[WatchMessageKey.lastUpdated] = lastUpdated.timeIntervalSince1970 }
        return value
    }

    var canPause: Bool {
        isConfigured && status == .printing
    }

    var canResume: Bool {
        isConfigured && status == .paused
    }

    var canStop: Bool {
        isConfigured && [.preparing, .printing, .paused].contains(status)
    }

    var formattedRemainingTime: String {
        guard remainingMinutes > 0 else { return "<1m" }
        let hours = remainingMinutes / 60
        let minutes = remainingMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private static func string(_ value: Any?, default defaultValue: String = "") -> String {
        value as? String ?? defaultValue
    }

    private static func int(_ value: Any?) -> Int {
        optionalInt(value) ?? 0
    }

    private static func optionalInt(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return false
    }
}

struct WatchCommandResult: Equatable, Sendable {
    let success: Bool
    let message: String

    static func succeeded(_ message: String) -> WatchCommandResult {
        WatchCommandResult(success: true, message: message)
    }

    static func failed(_ message: String) -> WatchCommandResult {
        WatchCommandResult(success: false, message: message)
    }

    init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }

    init(message: [String: Any]) {
        if let success = message[WatchMessageKey.success] as? Bool {
            self.success = success
        } else if let success = message[WatchMessageKey.success] as? NSNumber {
            self.success = success.boolValue
        } else {
            self.success = false
        }
        self.message = message[WatchMessageKey.message] as? String ?? "No response"
    }

    var dictionary: [String: Any] {
        [
            WatchMessageKey.kind: WatchMessageKind.response.rawValue,
            WatchMessageKey.success: success,
            WatchMessageKey.message: message,
        ]
    }
}
