import SwiftUI

/// Eine einzelne Zahl mit Beschriftung.
///
/// - Note: Hülle um `Kachel` aus der Gestaltungsschicht. Sie bleibt bestehen, damit die
///   Ansichten, die sie schon benutzen, nicht alle gleichzeitig umgeschrieben werden
///   mussten - gezeichnet wird in beiden Fällen dasselbe.
struct KennzahlKachel: View {

    let titel: String
    let wert: String
    var hinweis: String? = nil
    var farbe: Color = Stil.schrift
    var symbol: String? = nil

    var body: some View {
        Kachel(beschriftung: titel, wert: wert, beischrift: hinweis,
               farbe: farbe, symbol: symbol)
    }
}

/// Zeile aus Bezeichnung und Betrag - für alle Aufstellungen in der App.
///
/// - Note: Hülle um `Postenzeile`, aus demselben Grund wie oben.
struct ZeileMitBetrag: View {

    let bezeichnung: String
    let betrag: Decimal
    var unterzeile: String? = nil
    var hervorgehoben: Bool = false
    var mitVorzeichen: Bool = false

    var body: some View {
        Postenzeile(
            bezeichnung: bezeichnung,
            betrag: betrag,
            beischrift: unterzeile,
            gewichtet: hervorgehoben,
            mitVorzeichen: mitVorzeichen,
            farbe: mitVorzeichen && betrag > 0 ? Stil.haben : nil
        )
    }
}
