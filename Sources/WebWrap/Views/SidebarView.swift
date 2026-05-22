import SwiftUI

struct SidebarView: View {
    @ObservedObject var state: AppState
    @Binding var showCreate: Bool
    @Binding var showPreferences: Bool
    @EnvironmentObject var loc: Localization

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
            HStack(spacing: 4) {
                Button(action: { showCreate = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(loc.t(.newWrapper))

                Button(action: state.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help(loc.t(.refresh))

                Spacer()

                Button(action: { showPreferences = true }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help(loc.t(.preferences))
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
