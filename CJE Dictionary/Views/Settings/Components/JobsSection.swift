import SwiftUI

struct JobsSection: View {
    let snapshots: [DictionaryJobSnapshot]
    let onRetry: (DictionaryID) -> Void

    var body: some View {
        Section("Jobs") {
            if snapshots.isEmpty {
                Text("No active jobs")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshots, id: \.id) { snapshot in
                    HStack {
                        Text(snapshot.id.rawValue)
                        Spacer()

                        if case .failed = snapshot.state {
                            Button {
                                onRetry(snapshot.id)
                            } label: {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(stateLabel(snapshot.state))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func stateLabel(_ state: DictionaryJobState) -> String {
        switch state {
        case .queued:
            return "Queued"
        case .downloading(let progress):
            return "Downloading \(Int(progress.fractionCompleted * 100))%"
        case .downloaded:
            return "Downloaded"
        case .installing:
            return "Installing"
        case .installed:
            return "Installed"
        case .failed(let message):
            return "Failed: \(message)"
        case .cancelled:
            return "Cancelled"
        }
    }
}
