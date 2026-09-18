import SwiftUI
import SwiftData

@main
struct SteuerAppApp: App {

    /// Was beim Start aus der Datenbank wurde.
    private enum Start {
        case bereit(ModelContainer)
        case fehlgeschlagen(String)
    }

    private let start: Start

    init() {
        do {
            start = .bereit(try Datenbank.container())
        } catch {
            start = .fehlgeschlagen(String(describing: error))
        }
    }

    var body: some Scene {
        WindowGroup {
            switch start {
            case .bereit(let container):
                Sperrschicht { Wurzelansicht() }
                    .modelContainer(container)
            case .fehlgeschlagen(let text):
                Startfehleransicht(text: text)
            }
        }
    }
}

/// Startbild und App übereinander - das Startbild löst sich auf, die App bleibt.
private struct Wurzelansicht: View {

    @State private var startVorbei = false

    var body: some View {
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
        // Reissleine. Das Startbild meldet sich selbst, wenn es durch ist - aber wenn
        // es das aus irgendeinem Grund nicht tut, bleibt sonst ein schwarzer
        // Bildschirm stehen, weil die App darunter auf Deckkraft 0 wartet. Ein
        // Vorspann darf die App nie festhalten; nach fünf Sekunden geht es weiter,
        // ob er fertig ist oder nicht.
        .task {
            try? await Task.sleep(for: .seconds(5))
            if !startVorbei { startVorbei = true }
        }
    }
}

/// Wenn die Datenbank nicht aufgeht, steht hier warum.
///
/// Vorher brach die App an dieser Stelle ab. Auf dem Gerät ist das ein schwarzer
/// Bildschirm ohne jeden Hinweis - und ein Fehler, den niemand melden kann, weil er
/// nichts zu melden hat.
private struct Startfehleransicht: View {

    let text: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.yellow)

                    Text("Die Datenbank ließ sich nicht öffnen")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Die App kann ohne sie nicht starten. Meist hilft es, die App "
                         + "vom Gerät zu löschen und neu zu installieren - dabei gehen "
                         + "die bereits erfassten Belege allerdings verloren.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.75))

                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
    }
}
