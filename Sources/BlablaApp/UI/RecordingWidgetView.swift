import SwiftUI

struct RecordingWidgetView: View {
    static let pillSize = CGSize(width: 360, height: 52)
    // The panel is larger than the pill so the shadow is never clipped by the window bounds.
    static let shadowMargin: CGFloat = 24
    static let panelSize = CGSize(
        width: pillSize.width + shadowMargin * 2,
        height: pillSize.height + shadowMargin * 2
    )

    @EnvironmentObject private var controller: AppController

    var body: some View {
        content
            .padding(.horizontal, 16)
            .frame(width: Self.pillSize.width, height: Self.pillSize.height)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
            .frame(width: Self.panelSize.width, height: Self.panelSize.height)
            .animation(.snappy(duration: 0.25), value: controller.workflowState)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.workflowState {
        case .idle:
            EmptyView()
        case .recording:
            recordingLayout
                .transition(.opacity)
        case .transcribing:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Transcribing…")
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
            }
            .transition(.opacity)
        case .success:
            successLayout
                .transition(.opacity)
        case .error:
            HStack(spacing: 10) {
                statusRow(
                    symbol: "exclamationmark.triangle.fill",
                    tint: .orange,
                    title: controller.widgetMessage,
                    detail: nil
                )
                if controller.canRetry {
                    pillButton("Retry") {
                        await controller.retryLastRecording()
                    }
                    .help("Transcribe the same recording again")
                }
            }
            .transition(.opacity)
        }
    }

    private var recordingLayout: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)
                .symbolEffect(.pulse)

            Text("Listening")
                .font(.system(size: 13, weight: .semibold))

            VoiceWaveform(level: controller.meterLevel)

            Text(formattedDuration(controller.elapsedTime))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await controller.cancelRecording()
                }
            } label: {
                Text("esc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Cancel and discard the recording")

            pillButton("Done") {
                await controller.stopRecording()
            }
            .help("Finish and transcribe (\(controller.settings.startShortcut.displayString))")
        }
    }

    @ViewBuilder
    private var successLayout: some View {
        if let outcome = controller.lastInsertOutcome {
            let isInserted = if case .inserted = outcome { true } else { false }
            statusRow(
                symbol: isInserted ? "checkmark.circle.fill" : "doc.on.clipboard.fill",
                tint: isInserted ? .green : .blue,
                title: outcome.title,
                detail: outcome.detail ?? transcriptPreview
            )
        }
    }

    private func pillButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Color.primary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func statusRow(symbol: String, tint: Color, title: String, detail: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(detail == nil ? 2 : 1)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var transcriptPreview: String? {
        let preview = controller.lastTranscriptPreview
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? nil : preview
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds.rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
