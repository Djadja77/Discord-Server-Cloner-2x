import SwiftUI
import SwiftData

@main
struct SteuerAppApp: App {

    let container = Datenbank.container()

    @State private var startVorbei = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Bewusst von Anfang an eingehängt, nicht erst nach der Animation: so
                // lädt SwiftData seinen Speicher, während das Startbild läuft, und die
                // App steht sofort, wenn es sich auflöst.
                HauptAnsicht()
                    .opacity(startVorbei ? 1 : 0)

                if !startVorbei {
                    Startbild { startVorbei = true }
                        .zIndex(1)
                }
            }
        }
        .modelContainer(container)
    }
}
