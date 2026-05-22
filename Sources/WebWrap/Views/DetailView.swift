import SwiftUI

struct DetailView: View {
    @ObservedObject var state: AppState

    var body: some View {
        if let id = state.selection,
           let app = state.wrappers.first(where: { $0.id == id }) {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 16) {
                        IconView(bundleURL: app.bundleURL)
                            .frame(width: 96, height: 96)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(app.name).font(.title2).bold()
                            Text(app.url.absoluteString)
                                .foregroundStyle(.secondary).textSelection(.enabled)
                            Text(app.bundleId).font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                }
                Section {
                    HStack {
                        Button("Launch")  { state.launch(app) }
                        Button("Reveal in Finder") { state.reveal(app) }
                        Spacer()
                        Button("Delete", role: .destructive) { state.delete(app) }
                    }
                }
                if let err = state.lastError {
                    Section { Text(err).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .padding()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No wrappers yet").font(.title2).bold()
                Text("Click + to create your first one.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
