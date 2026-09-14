import SwiftUI
import SwiftData

@main
struct SteuerAppApp: App {

    let container = Datenbank.container()

    var body: some Scene {
        WindowGroup {
            HauptAnsicht()
        }
        .modelContainer(container)
    }
}
