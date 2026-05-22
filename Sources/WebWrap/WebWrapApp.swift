import SwiftUI

@main
struct WebWrapApp: App {
    @StateObject private var state = AppState()
    @StateObject private var loc = Localization()
    @State private var showCreate = false
    @State private var showPreferences = false

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(state: state,
                            showCreate: $showCreate,
                            showPreferences: $showPreferences)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            } detail: {
                DetailView(state: state)
            }
            .environmentObject(loc)
            .frame(minWidth: 720, minHeight: 480)
            .task { state.refresh() }
            .sheet(isPresented: $showCreate) {
                CreateSheet(state: state, isPresented: $showCreate)
                    .environmentObject(loc)
            }
            .sheet(isPresented: $showPreferences) {
                PreferencesSheet(state: state, loc: loc, isPresented: $showPreferences)
            }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(loc.t(.newWrapperMenu)) { showCreate = true }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .appInfo) {
                Button(loc.t(.preferences) + "…") { showPreferences = true }
                    .keyboardShortcut(",")
            }
        }
    }
}
