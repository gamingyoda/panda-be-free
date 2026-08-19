import SwiftUI

struct WatchDashboardView: View {
    @Bindable var model: WatchAppModel
    @State private var showStopConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if !model.snapshot.isConfigured {
                    ContentUnavailableView(
                        "Printer Not Configured",
                        systemImage: "printer",
                        description: Text("Complete setup in PandaBeFree on your iPhone.")
                    )
                } else {
                    dashboard
                }
            }
            .navigationTitle(model.snapshot.printerName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.send(.refresh)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isSending || !model.isReachable)
                }
            }
        }
        .task {
            model.requestState()
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 12) {
                connectionBadge
                progressSection
                detailSection

                if model.snapshot.canPause || model.snapshot.canResume || model.snapshot.canStop {
                    controls
                }

                if model.isSending {
                    ProgressView("Sending…")
                        .font(.caption2)
                }

                if let feedback = model.feedbackMessage {
                    Text(feedback)
                        .font(.caption2)
                        .foregroundStyle(model.feedbackIsError ? .red : .green)
                        .multilineTextAlignment(.center)
                        .onTapGesture { model.clearFeedback() }
                }

                if let updated = model.snapshot.lastUpdated {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var connectionBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(model.snapshot.isConnected ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(model.snapshot.isConnected ? "Live" : "Cached")
                .font(.caption2.weight(.semibold))
            Spacer()
            Text(model.snapshot.status.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(statusColor)
        }
    }

    private var progressSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.tertiary, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: Double(model.snapshot.progress) / 100)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(model.snapshot.progress)%")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.snapshot.jobName.isEmpty ? "3D Print" : model.snapshot.jobName)
                    .font(.headline)
                    .lineLimit(2)
                Label(model.snapshot.formattedRemainingTime, systemImage: "clock")
                    .font(.caption)
                if model.snapshot.totalLayers > 0 {
                    Label(
                        "\(model.snapshot.layerNum)/\(model.snapshot.totalLayers)",
                        systemImage: "square.3.layers.3d"
                    )
                    .font(.caption)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var detailSection: some View {
        VStack(spacing: 5) {
            temperatureRow("Nozzle", current: model.snapshot.nozzleTemp, target: model.snapshot.nozzleTargetTemp)
            temperatureRow("Bed", current: model.snapshot.bedTemp, target: model.snapshot.bedTargetTemp)
            if let chamber = model.snapshot.chamberTemp, chamber > 0 {
                temperatureRow("Chamber", current: chamber, target: nil)
            }
        }
        .padding(9)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if model.snapshot.canPause {
                    Button {
                        model.send(.pause)
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.yellow)
                }

                if model.snapshot.canResume {
                    Button {
                        model.send(.resume)
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.green)
                }
            }

            if model.snapshot.canStop {
                Button(role: .destructive) {
                    showStopConfirmation = true
                } label: {
                    Label("Stop Print", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)
                .confirmationDialog("Stop this print?", isPresented: $showStopConfirmation) {
                    Button("Stop Print", role: .destructive) {
                        model.send(.stop)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This cancels the current print and cannot be undone.")
                }
            }
        }
        .disabled(model.isSending || !model.isReachable)
    }

    private func temperatureRow(_ label: String, current: Int?, target: Int?) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            if let current {
                Text(target.map { "\(current)/\($0)°C" } ?? "\(current)°C")
                    .font(.caption.monospacedDigit())
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var statusColor: Color {
        switch model.snapshot.status {
        case .printing: .blue
        case .preparing: .orange
        case .paused: .yellow
        case .issue, .cancelled: .red
        case .completed: .green
        case .idle: .secondary
        }
    }
}

#Preview {
    let model = WatchAppModel()
    WatchDashboardView(model: model)
}
