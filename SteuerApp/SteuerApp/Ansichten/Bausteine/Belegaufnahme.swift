import SwiftUI
import PhotosUI

/// Auf welchem Weg ein Beleg hereinkommt.
enum Aufnahmeart: Int, Identifiable {
    case scannen, mediathek, vonHand
    var id: Int { rawValue }
}

/// Der Belegeinzug - hängt die Blätter für Kamera, Mediathek und Einzelmaske an eine
/// Ansicht und öffnet das passende, sobald `art` gesetzt wird.
///
/// Als Modifikator und nicht als eigene Ansicht: ein Blatt an einer Ansicht ohne
/// Ausdehnung präsentiert nicht zuverlässig. So hängen sie an der Wurzel der App, die
/// den ganzen Bildschirm füllt - und bleiben offen, wenn der Bereich darunter wechselt.
struct Belegeinzug: ViewModifier {

    let jahr: Int
    @Binding var art: Aufnahmeart?

    @State private var scannerOffen = false
    @State private var stapelOffen = false
    @State private var einzelOffen = false
    @State private var fotoauswahlOffen = false
    @State private var stapelbilder: [UIImage] = []
    @State private var fotoauswahl: [PhotosPickerItem] = []
    @State private var stapelStartet = false

    func body(content: Content) -> some View {
        content
            .onChange(of: art) { starten() }
            // Zwei Blätter nacheinander: das zweite wird erst beim Schließen des
            // ersten geöffnet - sonst verschluckt SwiftUI die zweite Präsentation.
            .sheet(isPresented: $scannerOffen, onDismiss: stapelOeffnenFallsBilder) {
                BelegScanner { bilder in
                    stapelbilder = bilder
                    scannerOffen = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $stapelOffen, onDismiss: { stapelbilder = [] }) {
                StapelErfassungAnsicht(bilder: stapelbilder, vorgabeJahr: jahr)
            }
            .sheet(isPresented: $einzelOffen) {
                BelegBearbeitenAnsicht(beleg: nil, vorgabeJahr: jahr)
            }
            .photosPicker(
                isPresented: $fotoauswahlOffen,
                selection: $fotoauswahl,
                maxSelectionCount: 20,
                matching: .images
            )
            .onChange(of: fotoauswahl) {
                guard !fotoauswahl.isEmpty else { return }
                let ausgewählt = fotoauswahl
                fotoauswahl = []
                Task {
                    stapelbilder = await FotoImport.bilderLaden(aus: ausgewählt)
                    stapelOeffnenFallsMöglich()
                }
            }
            // Die Fotoauswahl hat kein onDismiss wie ein sheet. Beide Wege - Laden
            // fertig und Auswahl geschlossen - können in beliebiger Reihenfolge
            // eintreffen, deshalb prüft jeder von ihnen denselben Zustand.
            .onChange(of: fotoauswahlOffen) { stapelOeffnenFallsMöglich() }
    }

    private func starten() {
        switch art {
        case .scannen: scannerOffen = true
        case .mediathek: fotoauswahlOffen = true
        case .vonHand: einzelOffen = true
        case nil: return
        }
        // Zurücksetzen, damit derselbe Weg gleich noch einmal ausgelöst werden kann.
        art = nil
    }

    /// Nach dem Scanner: dessen `onDismiss` feuert erst, wenn das Blatt weg ist.
    private func stapelOeffnenFallsBilder() {
        guard !stapelbilder.isEmpty else { return }
        stapelOffen = true
    }

    /// Nach der Fotomediathek.
    ///
    /// Hier lag der Fehler, wegen dem sich über die Mediathek kein Beleg anlegen
    /// liess: die Erfassung wurde geöffnet, während sich die Fotoauswahl noch
    /// schloss. SwiftUI verschluckt eine Präsentation, die während einer laufenden
    /// Entlassung startet - das Blatt kam nie, und es sah aus, als passiere nichts.
    ///
    /// Beim Scanner löst `onDismiss` das sauber. Die Fotoauswahl bietet kein
    /// `onDismiss`, deshalb der kurze Abstand: er überbrückt die Entlassungs-
    /// animation. `stapelStartet` verhindert, dass beide Auslöser doppelt öffnen.
    @MainActor
    private func stapelOeffnenFallsMöglich() {
        guard !stapelbilder.isEmpty, !stapelOffen, !stapelStartet,
              !fotoauswahlOffen, !scannerOffen else { return }
        stapelStartet = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            stapelStartet = false
            stapelOffen = true
        }
    }
}

extension View {

    /// Hängt Kamera, Mediathek und Einzelmaske an diese Ansicht.
    func belegeinzug(jahr: Int, art: Binding<Aufnahmeart?>) -> some View {
        modifier(Belegeinzug(jahr: jahr, art: art))
    }
}
