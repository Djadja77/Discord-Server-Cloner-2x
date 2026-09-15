import SwiftUI
import PhotosUI

/// Der Einstieg ins Belegerfassen - an jeder Stelle der App derselbe.
///
/// Drei Wege, weil Belege auf drei Arten ankommen: als Stapel Papier vom Schreibtisch, als
/// Bildschirmfoto einer E-Mail-Rechnung, oder einzeln nachgetragen. Alle drei muenden in
/// denselben Entwurf.
struct BelegErfassenSchaltfläche: View {

    let jahr: Int
    /// `true` zeigt nur das Pluszeichen - für die Werkzeugleiste.
    var kompakt: Bool = true

    @State private var einzelOffen = false
    @State private var scannerOffen = false
    @State private var stapelOffen = false
    @State private var fotoauswahlOffen = false
    @State private var stapelbilder: [UIImage] = []
    @State private var fotoauswahl: [PhotosPickerItem] = []

    var body: some View {
        schaltfläche
            .sheet(isPresented: $einzelOffen) {
                BelegBearbeitenAnsicht(beleg: nil, vorgabeJahr: jahr)
            }
            // Zwei Blaetter nacheinander: das zweite wird erst beim Schließen des ersten
            // geöffnet - sonst verschluckt SwiftUI die zweite Präsentation.
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
                let ausgewählt = fotoauswahl
                fotoauswahl = []
                Task {
                    stapelbilder = await FotoImport.bilderLaden(aus: ausgewählt)
                    stapelOeffnenFallsBilder()
                }
            }
    }

    @ViewBuilder
    private var schaltfläche: some View {
        if kompakt {
            Menu {
                menueinträge
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Stil.schrift)
                    .frame(width: 40, height: 40)
                    .background(Stil.glas, in: Circle())
                    .overlay(Circle().strokeBorder(Stil.kanteFein, lineWidth: 0.9))
            }
            .accessibilityLabel("Beleg erfassen")
        } else {
            Menu {
                menueinträge
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.viewfinder")
                    Text("Beleg erfassen")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Stil.akzent, in: Capsule())
                .overlay(Capsule().strokeBorder(Stil.kante, lineWidth: 1))
            }
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
