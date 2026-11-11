import SwiftUI

@main
struct AquaLogApp: App {
    @StateObject private var store = AquariumStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
