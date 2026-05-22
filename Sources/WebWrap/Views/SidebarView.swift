import SwiftUI

struct SidebarView: View {
    @ObservedObject var state: AppState
    @Binding var showCreate: Bool

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $state.selection) {
                ForEach(state.wrappers) { wrap in
                    HStack {
                        IconView(bundleURL: wrap.bundleURL)
                            .frame(width: 22, height: 22)
                        Text(wrap.name)
                    }
                    .tag(wrap.id as InstalledApp.ID?)
                }
            }
            Divider()
            HStack {
                Button(action: { showCreate = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("New wrapper")
                Spacer()
                Button(action: state.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(8)
        }
    }
}

struct IconView: View {
    let bundleURL: URL
    var body: some View {
        let img = NSWorkspace.shared.icon(forFile: bundleURL.path)
        Image(nsImage: img).resizable().interpolation(.high)
    }
}
