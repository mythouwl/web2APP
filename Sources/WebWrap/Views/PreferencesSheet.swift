import SwiftUI

struct PreferencesSheet: View {
    @ObservedObject var state: AppState
    @ObservedObject var loc: Localization
    @Binding var isPresented: Bool

    @State private var isUpdating = false
    @State private var lastResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc.t(.preferences)).font(.headline)

            Form {
                Section {
                    Picker(loc.t(.language), selection: $loc.preferred) {
                        ForEach(Localization.Language.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }
                Section(loc.t(.updateAllApps)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc.t(.updateAllDescription))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button(loc.t(.updateAllApps)) {
                                Task { await update() }
                            }
                            .disabled(isUpdating || state.wrappers.isEmpty)
                            if isUpdating {
                                ProgressView().controlSize(.small)
                                Text(loc.t(.updating)).foregroundStyle(.secondary)
                            }
                            if let r = lastResult, !isUpdating {
                                Text(r).foregroundStyle(.green)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(loc.t(.done)) { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 480)
    }

    private func update() async {
        isUpdating = true
        defer { isUpdating = false }
        let count = await state.updateAllWrappers()
        lastResult = String(format: loc.t(.updateAllSuccess), count)
    }
}
