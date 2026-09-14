import SwiftUI
import UIKit
import VisionKit

/// Die Dokumentenkamera von iOS: erkennt Belegkanten, entzerrt und schneidet zu.
///
/// Gescannt wird immer nur eine Seite - ein Beleg ist ein Beleg. Mehrseitige Rechnungen
/// gehoeren als PDF ins Belegarchiv des Steuerberaters, nicht in diese App.
struct BelegScanner: UIViewControllerRepresentable {

    var fertig: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let kamera = VNDocumentCameraViewController()
        kamera.delegate = context.coordinator
        return kamera
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(fertig: fertig) }

    final class Koordinator: NSObject, VNDocumentCameraViewControllerDelegate {

        let fertig: (UIImage?) -> Void

        init(fertig: @escaping (UIImage?) -> Void) {
            self.fertig = fertig
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            fertig(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            fertig(nil)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            fertig(nil)
        }
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
