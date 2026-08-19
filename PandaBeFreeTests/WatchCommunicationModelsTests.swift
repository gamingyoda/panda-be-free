import Foundation
@testable import PandaBeFree
import Testing

@Suite("Apple Watch Communication Models")
struct WatchCommunicationModelsTests {
    @Test("Printer snapshot survives a WatchConnectivity dictionary round trip")
    func snapshotRoundTrip() throws {
        let original = WatchPrinterSnapshot(
            isConfigured: true,
            isConnected: true,
            printerName: "A1 mini",
            status: .printing,
            progress: 42,
            remainingMinutes: 83,
            jobName: "Benchy",
            layerNum: 150,
            totalLayers: 300,
            nozzleTemp: 220,
            nozzleTargetTemp: 220,
            bedTemp: 60,
            bedTargetTemp: 60,
            chamberTemp: 28,
            lastUpdated: Date(timeIntervalSince1970: 1_000_000)
        )

        let decoded = try #require(WatchPrinterSnapshot(message: original.message))
        #expect(decoded == original)
        #expect(decoded.canPause)
        #expect(decoded.canStop)
        #expect(!decoded.canResume)
        #expect(decoded.formattedRemainingTime == "1h 23m")
    }

    @Test("Snapshot clamps invalid progress and time values")
    func snapshotClampsValues() throws {
        let decoded = try #require(WatchPrinterSnapshot(message: [
            WatchMessageKey.isConfigured: true,
            WatchMessageKey.progress: 150,
            WatchMessageKey.remainingMinutes: -5,
            WatchMessageKey.layerNum: -1,
            WatchMessageKey.totalLayers: -1,
        ]))

        #expect(decoded.progress == 100)
        #expect(decoded.remainingMinutes == 0)
        #expect(decoded.layerNum == 0)
        #expect(decoded.totalLayers == 0)
    }

    @Test("Command response dictionary preserves result")
    func commandResultRoundTrip() {
        let original = WatchCommandResult.succeeded("Command sent")
        let decoded = WatchCommandResult(message: original.dictionary)
        #expect(decoded == original)
    }
}
