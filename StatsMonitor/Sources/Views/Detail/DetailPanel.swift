import SwiftUI

extension Notification.Name {
    static let panelOpened = Notification.Name("StatsMonitorPanelOpened")
}

enum PanelID: String {
    case cpu, gpu, memory, disk, network

    var title: String {
        switch self {
        case .cpu:     "CPU"
        case .gpu:     "GPU"
        case .memory:  "Memory"
        case .disk:    "Disk"
        case .network: "Network"
        }
    }
}

struct DetailPanel<Content: View>: View {
    let id: PanelID
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailToolbar(id.title, settings: settings)
            content()
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { NotificationCenter.default.post(name: .panelOpened, object: id.rawValue) }
        .onReceive(NotificationCenter.default.publisher(for: .panelOpened)) { note in
            if note.object as? String != id.rawValue { dismiss() }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    DetailPanel(id: .cpu) {
        Text("CPU content goes here")
            .foregroundStyle(.secondary)
    }
    .environment(AppSettings())
}
