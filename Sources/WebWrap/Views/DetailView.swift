import SwiftUI

struct DetailView: View {
    @ObservedObject var state: AppState
    @EnvironmentObject var loc: Localization

    var body: some View {
        if let id = state.selection,
           let app = state.wrappers.first(where: { $0.id == id }) {
            EditDetailForm(state: state, app: app)
                .id(app.id)
                .environmentObject(loc)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 56))
                    .foregroundStyle(.tertiary)
                Text(loc.t(.noWrappersTitle))
                    .font(.title2)
                Text(loc.t(.noWrappersDescription))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct EditDetailForm: View {
    @ObservedObject var state: AppState
    let app: InstalledApp
    @EnvironmentObject var loc: Localization

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
            Section(loc.t(.settings)) {
                TextField(loc.t(.name), text: $editName)
                TextField(loc.t(.url), text: $editURL)
                TextField(loc.t(.userAgent), text: $editUA)
            }
            Section {
                HStack {
                    Button(loc.t(.launch))  { state.launch(app) }
                    Button(loc.t(.revealInFinder)) { state.reveal(app) }
                    Spacer()
                    Button(loc.t(.regenerate)) { Task { await regenerate() } }
                        .disabled(!canRegenerate || isWorking)
                    Button(loc.t(.delete), role: .destructive) { state.delete(app) }
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
