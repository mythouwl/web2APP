import SwiftUI
import UniformTypeIdentifiers

struct CreateSheet: View {
    @ObservedObject var state: AppState
    @Binding var isPresented: Bool
    @EnvironmentObject var loc: Localization

    @State private var name = ""
    @State private var urlText = ""
    @State private var userAgent = ""
    @State private var iconImageData: Data?
    @State private var isBuilding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc.t(.newWrapperMenu)).font(.headline)

            Form {
                TextField(loc.t(.name), text: $name)
                TextField(loc.t(.url), text: $urlText, prompt: Text("https://example.com"))
                TextField(loc.t(.userAgent), text: $userAgent)
                HStack {
                    Text(loc.t(.icon) + ":")
                    if let data = iconImageData, let img = NSImage(data: data) {
                        Image(nsImage: img).resizable().frame(width: 48, height: 48)
                    } else {
                        Text(loc.t(.autoFetched))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(loc.t(.choose)) { pickIcon() }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(loc.t(.cancel)) { isPresented = false }
                Button(loc.t(.create)) { Task { await create() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate || isBuilding)
            }
            if isBuilding { ProgressView().controlSize(.small) }
        }
        .padding()
        .frame(width: 480)
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && URL(string: urlText)?.scheme?.hasPrefix("http") == true
    }

    private func pickIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .icns]
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url) {
            iconImageData = data
        }
    }

    private func create() async {
        guard let url = URL(string: urlText) else { return }
        isBuilding = true
        defer { isBuilding = false }
        let ua = userAgent.trimmingCharacters(in: .whitespaces).isEmpty ? nil : userAgent
        if let data = iconImageData {
            state.createWithImage(name: name, url: url, userAgent: ua, imageData: data)
        } else {
            await state.createAuto(name: name, url: url, userAgent: ua)
        }
        isPresented = false
    }
}
