import SwiftUI

@main
struct WebWrapApp: App {
    @StateObject private var state = AppState()
    @State private var showCreate = false

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(state: state, showCreate: $showCreate)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            } detail: {
                DetailView(state: state)
            }
            .frame(minWidth: 720, minHeight: 480)
            .task { state.refresh() }
            .sheet(isPresented: $showCreate) {
                CreateSheet(state: state, isPresented: $showCreate)
            }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Wrapper…") { showCreate = true }
                    .keyboardShortcut("n")
            }
        }
    }
}
