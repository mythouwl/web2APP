import SwiftUI

struct SidebarView: View {
    @ObservedObject var state: AppState
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
            HStack {
                Spacer()
                Button(action: { showPreferences = true }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help(loc.t(.preferences))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
