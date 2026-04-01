import SwiftUI

struct RecordingWidgetView: View {
    static func panelSize(for state: RecordingWorkflowState) -> CGSize {
        switch state {
        case .idle:
            return CGSize(width: 1, height: 1)
        case .recording:
            return CGSize(width: 560, height: 122)
        case .transcribing:
            return CGSize(width: 364, height: 74)
        case .success:
            return CGSize(width: 560, height: 112)
        case .error:
            return CGSize(width: 500, height: 88)
        }
    }

    @EnvironmentObject private var controller: AppController

    var body: some View {
        let panelSize = Self.panelSize(for: controller.workflowState)

        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.03),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: 0.9)

            content
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .shadow(color: .black.opacity(0.14), radius: 24, x: 0, y: 16)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.workflowState {
        case .idle:
            EmptyView()
        case .recording:
            recordingLayout
        case .transcribing:
            transcribingLayout
        case .success:
            successLayout
        case .error:
            errorLayout
        }
    }

    private var recordingLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Text(recordingMetadata)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 12)

                Text(formattedDuration(controller.elapsedTime))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Button {
                    Task {
                        await controller.stopRecording()
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.44, blue: 0.4))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }

            MinimalWaveform(level: controller.meterLevel)
        }
    }

    private var transcribingLayout: some View {
        ProcessingLine()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var successLayout: some View {
        Text(successText)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var errorLayout: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(red: 1.0, green: 0.43, blue: 0.38))
                .frame(width: 7, height: 7)

            Text(controller.widgetMessage)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var recordingMetadata: String {
        [
            controller.settings.selectedLanguage.code.uppercased(),
            compactModelName,
            compactMicrophoneName,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    private var compactModelName: String {
        switch currentModel {
        case .gpt4oTranscribe:
            return "GPT-4o Transcribe"
        case .gpt4oMiniTranscribeSnapshot:
            return "GPT-4o Mini Transcribe"
        case .voxtralMiniLatest:
            return "Voxtral Mini Latest"
        }
    }

    private var compactMicrophoneName: String {
        let name = controller.selectedMicrophoneName
        guard name.hasPrefix("Default ("), name.hasSuffix(")") else {
            return name
        }

        return String(name.dropFirst("Default (".count).dropLast())
    }

    private var successText: String {
        let preview = controller.lastTranscriptPreview
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? controller.widgetMessage : preview
    }

    private var currentModel: TranscriptionModel {
        controller.lastResultModel ?? controller.settings.selectedModel
    }

    private var horizontalPadding: CGFloat {
        switch controller.workflowState {
        case .recording:
            return 22
        case .transcribing:
            return 28
        case .success, .error:
            return 20
        case .idle:
            return 0
        }
    }

    private var verticalPadding: CGFloat {
        switch controller.workflowState {
        case .recording:
            return 18
        case .transcribing:
            return 18
        case .success:
            return 18
        case .error:
            return 16
        case .idle:
            return 0
        }
    }

    private var statusTint: Color {
        switch controller.workflowState {
        case .idle:
            return Color.white.opacity(0.7)
        case .recording:
            return Color(red: 1.0, green: 0.43, blue: 0.38)
        case .transcribing:
            return Color(red: 0.62, green: 0.77, blue: 1.0)
        case .success:
            return Color.green.opacity(0.82)
        case .error:
            return Color.red.opacity(0.82)
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.24),
                statusTint.opacity(0.16),
                Color.white.opacity(0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

private struct MinimalWaveform: View {
    let level: Double

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<30, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(barStyle(for: index))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }

    private var activeBars: Int {
        max(2, Int((level * 30).rounded(.up)))
    }

    private func barHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [10, 14, 18, 24, 14, 20, 28, 16, 10, 18, 26, 14, 10, 16, 22, 28, 14, 10, 14, 22, 26, 18, 10, 14, 20, 24, 16, 10, 16, 22]
        let base = pattern[index % pattern.count]
        let multiplier = 0.42 + CGFloat(level * 0.7)
        return base * multiplier
    }

    private func barStyle(for index: Int) -> AnyShapeStyle {
        if index < activeBars {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.86),
                        Color(red: 1.0, green: 0.56, blue: 0.48).opacity(0.88),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        return AnyShapeStyle(Color.white.opacity(0.12))
    }
}

private struct ProcessingLine: View {
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let segmentWidth = max(76, width * 0.26)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 4)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.92),
                                Color.white.opacity(0.18),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: segmentWidth, height: 4)
                    .offset(x: isAnimating ? width - segmentWidth : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 18)
        .clipped()
        .onAppear {
            guard !isAnimating else {
                return
            }

            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
