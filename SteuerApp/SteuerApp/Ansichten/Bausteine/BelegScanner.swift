import SwiftUI
import UIKit
import VisionKit
import PhotosUI

/// Die Dokumentenkamera von iOS: erkennt Belegkanten, entzerrt und schneidet zu.
///
/// Es werden **alle** gescannten Seiten zurueckgegeben. Wer nach einer Reise mit einem
/// Stapel Quittungen zurueckkommt, scannt sie in einem Durchgang - jede Seite wird
/// anschliessend zu einem eigenen Beleg.
struct BelegScanner: UIViewControllerRepresentable {

    var fertig: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let kamera = VNDocumentCameraViewController()
        kamera.delegate = context.coordinator
        return kamera
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(fertig: fertig) }

    final class Koordinator: NSObject, VNDocumentCameraViewControllerDelegate {

        let fertig: ([UIImage]) -> Void

        init(fertig: @escaping ([UIImage]) -> Void) {
            self.fertig = fertig
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            fertig((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            fertig([])
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            fertig([])
        }
    }
}

/// Laedt aus der Fotomediathek ausgewaehlte Bilder.
///
/// Nicht jeder Beleg kommt auf Papier: Rechnungen per E-Mail landen als Bildschirmfoto in
/// der Mediathek und muessen denselben Weg nehmen koennen wie ein abfotografierter Kassenbon.
enum FotoImport {

    static func bilderLaden(aus eintraege: [PhotosPickerItem]) async -> [UIImage] {
        var bilder: [UIImage] = []
        for eintrag in eintraege {
            guard let daten = try? await eintrag.loadTransferable(type: Data.self),
                  let bild = UIImage(data: daten) else { continue }
            bilder.append(bild)
        }
        return bilder
    }
}

/// Belegfoto in voller Groesse, zoom- und verschiebbar.
///
/// Belege sind zehn Jahre aufzubewahren. Wer nach drei Jahren nachsehen will, was auf der
/// Quittung stand, muss hineinzoomen koennen.
struct BelegbildAnsicht: View {

    let bild: UIImage

    @Environment(\.dismiss) private var schliessen
    @State private var vergroesserung: CGFloat = 1
    @State private var letzteVergroesserung: CGFloat = 1
    @State private var versatz: CGSize = .zero
    @State private var letzterVersatz: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { flaeche in
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(width: flaeche.size.width, height: flaeche.size.height)
                    .scaleEffect(vergroesserung)
                    .offset(versatz)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { wert in
                                vergroesserung = min(max(letzteVergroesserung * wert, 1), 6)
                            }
                            .onEnded { _ in
                                letzteVergroesserung = vergroesserung
                                if vergroesserung <= 1 { zuruecksetzen() }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { wert in
                                guard vergroesserung > 1 else { return }
                                versatz = CGSize(
                                    width: letzterVersatz.width + wert.translation.width,
                                    height: letzterVersatz.height + wert.translation.height
                                )
                            }
                            .onEnded { _ in letzterVersatz = versatz }
                    )
                    .onTapGesture(count: 2) {
                        // Doppeltippen schaltet zwischen Uebersicht und Detail um.
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vergroesserung > 1 ? zuruecksetzen() : hineinzoomen()
                        }
                    }
            }
            .background(Color.black)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Beleg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }

    private func zuruecksetzen() {
        vergroesserung = 1
        letzteVergroesserung = 1
        versatz = .zero
        letzterVersatz = .zero
    }

    private func hineinzoomen() {
        vergroesserung = 3
        letzteVergroesserung = 3
    }
}

/// Teilen-Dialog fuer die CSV-Exporte.
struct TeilenAnsicht: UIViewControllerRepresentable {

    let dateien: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: dateien, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
