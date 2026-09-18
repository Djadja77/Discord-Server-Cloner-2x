import Foundation
import LocalAuthentication

/// Fragt das Gerät, ob der Besitzer davorsitzt.
///
/// Geprüft wird mit `deviceOwnerAuthentication` und nicht mit der rein biometrischen
/// Variante. Der Unterschied ist der, auf den es ankommt: scheitert Face ID - schlechtes
/// Licht, Maske, Sonnenbrille -, fragt iOS nach dem Gerätecode statt einen auszusperren.
/// Eine Steuer-App, aus der man sich selbst aussperren kann, wäre eine schlechte.
enum Gerätesperre {

    /// Ob das Gerät überhaupt jemanden erkennen kann.
    ///
    /// Ohne Code und ohne Biometrie gibt es nichts zu prüfen - dann bleibt die Sperre
    /// aus, statt eine Sicherheit vorzutäuschen, die es nicht gibt.
    static var verfügbar: Bool {
        var fehler: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &fehler)
    }

    /// Wie sich das Gerät ausweisen lässt - für den Text auf dem Sperrbildschirm.
    static var art: String {
        let zusammenhang = LAContext()
        _ = zusammenhang.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch zusammenhang.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Code"
        }
    }

    static var symbol: String {
        let zusammenhang = LAContext()
        _ = zusammenhang.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch zusammenhang.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock"
        }
    }

    /// Fragt nach und sagt, ob es geklappt hat.
    ///
    /// Ein Fehlschlag wird bewusst nicht weitergereicht: Abbruch durch den Nutzer,
    /// misslungene Erkennung und fehlende Berechtigung führen alle zum selben Ergebnis -
    /// es bleibt zu. Wer es nochmal versuchen will, tippt nochmal.
    static func prüfen() async -> Bool {
        let zusammenhang = LAContext()
        zusammenhang.localizedCancelTitle = "Abbrechen"
        do {
            return try await zusammenhang.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Damit deine Belege und Rechnungen nur dir gehören."
            )
        } catch {
            return false
        }
    }
}
