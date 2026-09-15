import SwiftUI
import SwiftData

/// Die fünf Bereiche der App. Bewusst flach gehalten: Belege erfassen ist der häufigste
/// Vorgang und darf nie mehr als einen Fingertipp entfernt sein.
///
/// Die Systemleiste am unteren Rand blenden `aufGrund()` und `alsListe()` aus - sie
/// sitzen innerhalb der Navigation, wo `toolbar(.hidden, for: .tabBar)` zuverlässig
/// greift. An ihrer Stelle schwebt `SchwebendeLeiste` über dem Inhalt.
///
/// Der `TabView` bleibt darunter trotzdem bestehen - er hält jeden Bereich am Leben,
/// sodass ein Wechsel hin und zurück den Scrollstand und offene Masken nicht verwirft.
struct HauptAnsicht: View {

    @Environment(\.modelContext) private var kontext

    @AppStorage("ausgewaehltesJahr") private var jahr: Int = Calendar.kalender
        .component(.year, from: Date())

    @State private var bereich: SchwebendeLeiste.Bereich = .übersicht

    init() {
        Self.leistenGestalten()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $bereich) {
                UebersichtAnsicht(jahr: $jahr)
                    .tag(SchwebendeLeiste.Bereich.übersicht)

                BelegeAnsicht(jahr: $jahr)
                    .tag(SchwebendeLeiste.Bereich.belege)

                SchätzungAnsicht(jahr: $jahr)
                    .tag(SchwebendeLeiste.Bereich.schätzung)

                EuerAnsicht(jahr: $jahr)
                    .tag(SchwebendeLeiste.Bereich.auswertung)

                EinstellungenAnsicht(jahr: $jahr)
                    .tag(SchwebendeLeiste.Bereich.profil)
            }

            SchwebendeLeiste(auswahl: $bereich)
                .padding(.bottom, 6)
        }
        .ignoresSafeArea(.keyboard)
        .tint(Stil.akzent)
        .task { stammdatenSicherstellen() }
        // Jeder Jahreswechsel braucht einen eigenen Satz Jahresangaben - sonst landen
        // Beiträge und Vorauszahlungen des einen Jahres im anderen.
        .onChange(of: jahr) { stammdatenSicherstellen() }
    }

    private func stammdatenSicherstellen() {
        Datenbank.profilSicherstellen(in: kontext)
        Datenbank.jahresangabenSicherstellen(fuer: jahr, in: kontext)
    }

    /// Die Navigationsleiste durchsichtig machen.
    ///
    /// SwiftUI bietet dafür keinen eigenen Weg - ohne diesen Umweg über UIKit legt sich
    /// ein grauer Streifen über den Verlauf und bricht die Glasebene auf.
    private static func leistenGestalten() {
        let navileiste = UINavigationBarAppearance()
        navileiste.configureWithTransparentBackground()
        navileiste.backgroundColor = .clear
        navileiste.shadowColor = .clear
        navileiste.titleTextAttributes = [.foregroundColor: UIColor(Stil.schrift)]
        navileiste.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Stil.schrift),
            .font: UIFont.systemFont(ofSize: 30, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navileiste
        UINavigationBar.appearance().scrollEdgeAppearance = navileiste
        UINavigationBar.appearance().compactAppearance = navileiste
    }
}

#Preview {
    HauptAnsicht()
        .modelContainer(Datenbank.vorschauContainer())
}
