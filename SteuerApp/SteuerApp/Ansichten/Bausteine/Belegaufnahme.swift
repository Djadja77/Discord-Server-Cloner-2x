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

    @State private var aufnahmeOffen = false
    @State private var stapelOffen = false
    @State private var einzelOffen = false
    @State private var fotoauswahlOffen = false
    @State private var stapelbilder: [UIImage] = []
    @State private var fotoauswahl: [PhotosPickerItem] = []
    @State private var stapelStartet = false

    func body(content: Content) -> some View {
        content
            .onChange(of: art) { starten() }
            // Kamera und Erfassung teilen sich ein Blatt - siehe Aufnahmeblatt.
            .sheet(isPresented: $aufnahmeOffen) {
                Aufnahmeblatt(jahr: jahr)
            }
            // Aus der Mediathek geht es direkt in die Erfassung, ohne Kamera davor.
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
        case .scannen: aufnahmeOffen = true
        case .mediathek: fotoauswahlOffen = true
        case .vonHand: einzelOffen = true
        case nil: return
        }
        // Zurücksetzen, damit derselbe Weg gleich noch einmal ausgelöst werden kann.
        art = nil
    }

    /// Öffnet die Erfassung nach der Fotomediathek.
    ///
    /// Die Fotoauswahl schliesst sich noch, während hier schon das nächste Blatt
    /// kommen soll. SwiftUI verschluckt eine Präsentation, die während einer
    /// laufenden Entlassung startet, und anders als ein `sheet` bietet die
    /// Fotoauswahl kein `onDismiss`, an dem sich das sauber anhängen liesse.
    /// Deshalb der kurze Abstand - er überbrückt die Entlassungsanimation.
    /// `stapelStartet` verhindert, dass beide Auslöser doppelt öffnen.
    @MainActor
    private func stapelOeffnenFallsMöglich() {
        guard !stapelbilder.isEmpty, !stapelOffen, !stapelStartet,
              !fotoauswahlOffen, !aufnahmeOffen else { return }
        stapelStartet = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            stapelStartet = false
            stapelOffen = true
        }
    }
}

/// Ein einziges Blatt für Kamera und Erfassung.
///
/// Vorher waren das zwei Blätter: die Kamera schloss sich, und beim Schliessen
/// sollte die Erfassung aufgehen. SwiftUI verschluckt aber eine Präsentation, die
/// während einer laufenden Entlassung startet - beim ersten Scan passierte deshalb
/// nichts. Der Zustand blieb stehen und wurde erst beim nächsten Zeichnen eingelöst,
/// weshalb erst der zweite Scan den ersten Beleg zum Vorschein brachte.
///
/// Jetzt bleibt das Blatt offen und tauscht nur seinen Inhalt. Damit gibt es keine
/// zweite Präsentation mehr, die verschluckt werden könnte - und der Weg von der
/// Kamera in die Erfassung ist ohne Umweg über eine Entlassung.
private struct Aufnahmeblatt: View {

    let jahr: Int

    @State private var bilder: [UIImage] = []
    @Environment(\.dismiss) private var schließen

    var body: some View {
        if bilder.isEmpty {
            BelegScanner { gescannt in
                // Leer heisst abgebrochen oder fehlgeschlagen - dann ist hier Schluss.
                if gescannt.isEmpty { schließen() } else { bilder = gescannt }
            }
            .ignoresSafeArea()
        } else {
            StapelErfassungAnsicht(bilder: bilder, vorgabeJahr: jahr)
        }
    }
}

extension View {

    /// Hängt Kamera, Mediathek und Einzelmaske an diese Ansicht.
    func belegeinzug(jahr: Int, art: Binding<Aufnahmeart?>) -> some View {
        modifier(Belegeinzug(jahr: jahr, art: art))
    }
}
