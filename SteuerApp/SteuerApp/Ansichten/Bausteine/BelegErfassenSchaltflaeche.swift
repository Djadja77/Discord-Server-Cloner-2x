import SwiftUI
import PhotosUI

/// Der Einstieg ins Belegerfassen - an jeder Stelle der App derselbe.
///
/// Drei Wege, weil Belege auf drei Arten ankommen: als Stapel Papier vom Schreibtisch, als
/// Bildschirmfoto einer E-Mail-Rechnung, oder einzeln nachgetragen. Alle drei muenden in
/// denselben Entwurf.
struct BelegErfassenSchaltflaeche: View {

    let jahr: Int
    /// `true` zeigt nur das Pluszeichen - fuer die Werkzeugleiste.
    var kompakt: Bool = true

    @State private var einzelOffen = false
    @State private var scannerOffen = false
    @State private var stapelOffen = false
    @State private var fotoauswahlOffen = false
    @State private var stapelbilder: [UIImage] = []
    @State private var fotoauswahl: [PhotosPickerItem] = []

    var body: some View {
        schaltflaeche
            .sheet(isPresented: $einzelOffen) {
                BelegBearbeitenAnsicht(beleg: nil, vorgabeJahr: jahr)
            }
            // Zwei Blaetter nacheinander: das zweite wird erst beim Schliessen des ersten
            // geoeffnet - sonst verschluckt SwiftUI die zweite Praesentation.
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
            .photosPicker(
                isPresented: $fotoauswahlOffen,
                selection: $fotoauswahl,
                maxSelectionCount: 20,
                matching: .images
            )
            .onChange(of: fotoauswahl) {
                guard !fotoauswahl.isEmpty else { return }
                let ausgewaehlt = fotoauswahl
                fotoauswahl = []
                Task {
                    stapelbilder = await FotoImport.bilderLaden(aus: ausgewaehlt)
                    stapelOeffnenFallsBilder()
                }
            }
    }

    @ViewBuilder
    private var schaltflaeche: some View {
        if kompakt {
            Menu {
                menueinträge
            } label: {
                Label("Beleg erfassen", systemImage: "plus")
            }
        } else {
            Menu {
                menueinträge
            } label: {
                Label("Beleg erfassen", systemImage: "doc.viewfinder")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .menuStyle(.button)
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var menueinträge: some View {
        Button {
            scannerOffen = true
        } label: {
            Label("Belege scannen", systemImage: "doc.viewfinder")
        }

        Button {
            fotoauswahlOffen = true
        } label: {
            Label("Aus Fotomediathek", systemImage: "photo.on.rectangle")
        }

        Divider()

        Button {
            einzelOffen = true
        } label: {
            Label("Einzelnen Beleg erfassen", systemImage: "square.and.pencil")
        }
    }

    private func stapelOeffnenFallsBilder() {
        guard !stapelbilder.isEmpty else { return }
        stapelOffen = true
    }
}
