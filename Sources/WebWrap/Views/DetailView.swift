import SwiftUI

struct DetailView: View {
    @ObservedObject var state: AppState

    var body: some View {
        if let id = state.selection,
           let app = state.wrappers.first(where: { $0.id == id }) {
            EditDetailForm(state: state, app: app)
                .id(app.id)  // re-init @State when selection changes
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 56))
                    .foregroundStyle(.tertiary)
                Text("No wrappers yet")
                    .font(.title2)
                Text("Click + in the sidebar to create your first one.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct EditDetailForm: View {
    @ObservedObject var state: AppState
    let app: InstalledApp

    @State private var editName: String = ""
    @State private var editURL: String = ""
    @State private var editUA: String = ""
    @State private var isWorking = false

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    IconView(bundleURL: app.bundleURL)
                        .frame(width: 96, height: 96)
                    VStack(alignment: .leading) {
                        Text(app.bundleId).font(.caption).foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            }
            Section("Settings") {
                TextField("Name", text: $editName)
                TextField("URL", text: $editURL)
                TextField("User-Agent (optional)", text: $editUA)
            }
            Section {
                HStack {
                    Button("Launch")  { state.launch(app) }
                    Button("Reveal in Finder") { state.reveal(app) }
                    Spacer()
                    Button("Regenerate") { Task { await regenerate() } }
                        .disabled(!canRegenerate || isWorking)
                    Button("Delete", role: .destructive) { state.delete(app) }
                }
                if isWorking { ProgressView().controlSize(.small) }
            }
            if let err = state.lastError {
                Section { Text(err).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { hydrate() }
    }

    private var canRegenerate: Bool {
        !editName.trimmingCharacters(in: .whitespaces).isEmpty
        && URL(string: editURL)?.scheme?.hasPrefix("http") == true
    }

    private func hydrate() {
        editName = app.name
        editURL = app.url.absoluteString
        editUA = app.userAgent ?? ""
    }

    private func regenerate() async {
        guard let url = URL(string: editURL) else { return }
        isWorking = true
        defer { isWorking = false }
        let ua = editUA.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editUA
        await state.regenerate(app, newName: editName, newURL: url, newUA: ua)
    }
}
