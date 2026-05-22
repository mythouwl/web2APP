import SwiftUI
import UniformTypeIdentifiers

struct CreateSheet: View {
    @ObservedObject var state: AppState
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var urlText = ""
    @State private var userAgent = ""
    @State private var iconImageData: Data?
    @State private var isBuilding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Wrapper").font(.headline)

            Form {
                TextField("Name", text: $name)
                TextField("URL", text: $urlText, prompt: Text("https://example.com"))
                TextField("User-Agent (optional)", text: $userAgent)
                HStack {
                    Text("Icon:")
                    if let data = iconImageData, let img = NSImage(data: data) {
                        Image(nsImage: img).resizable().frame(width: 48, height: 48)
                    } else {
                        Text("Auto-fetched from site")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose…") { pickIcon() }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Create") { Task { await create() } }
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
