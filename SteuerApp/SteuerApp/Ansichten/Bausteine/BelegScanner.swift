import SwiftUI
import UIKit
import VisionKit
import PhotosUI

/// Die Dokumentenkamera von iOS: erkennt Belegkanten, entzerrt und schneidet zu.
///
/// Es werden **alle** gescannten Seiten zurückgegeben. Wer nach einer Reise mit einem
/// Stapel Quittungen zurückkommt, scannt sie in einem Durchgang - jede Seite wird
/// anschließend zu einem eigenen Beleg.
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

/// Laedt aus der Fotomediathek ausgewählte Bilder.
///
/// Nicht jeder Beleg kommt auf Papier: Rechnungen per E-Mail landen als Bildschirmfoto in
/// der Mediathek und müssen denselben Weg nehmen können wie ein abfotografierter Kassenbon.
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

/// Belegfoto in voller Größe, zoom- und verschiebbar.
///
/// Belege sind zehn Jahre aufzubewahren. Wer nach drei Jahren nachsehen will, was auf der
/// Quittung stand, muss hineinzoomen können.
struct BelegbildAnsicht: View {

    let bild: UIImage

    @Environment(\.dismiss) private var schließen
    @State private var vergrößerung: CGFloat = 1
    @State private var letzteVergrößerung: CGFloat = 1
    @State private var versatz: CGSize = .zero
    @State private var letzterVersatz: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { fläche in
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(width: fläche.size.width, height: fläche.size.height)
                    .scaleEffect(vergrößerung)
                    .offset(versatz)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { wert in
                                vergrößerung = min(max(letzteVergrößerung * wert, 1), 6)
                            }
                            .onEnded { _ in
                                letzteVergrößerung = vergrößerung
                                if vergrößerung <= 1 { zuruecksetzen() }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { wert in
                                guard vergrößerung > 1 else { return }
                                versatz = CGSize(
                                    width: letzterVersatz.width + wert.translation.width,
                                    height: letzterVersatz.height + wert.translation.height
                                )
                            }
                            .onEnded { _ in letzterVersatz = versatz }
                    )
                    .onTapGesture(count: 2) {
                        // Doppeltippen schaltet zwischen Übersicht und Detail um.
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vergrößerung > 1 ? zuruecksetzen() : hineinzoomen()
                        }
                    }
            }
            .background(Color.black)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Beleg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schließen() }
                }
            }
        }
    }

    private func zuruecksetzen() {
        vergrößerung = 1
        letzteVergrößerung = 1
        versatz = .zero
        letzterVersatz = .zero
    }

    private func hineinzoomen() {
        vergrößerung = 3
        letzteVergrößerung = 3
    }
}

/// Teilen-Dialog für die CSV-Exporte.
struct TeilenAnsicht: UIViewControllerRepresentable {

    let dateien: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: dateien, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
