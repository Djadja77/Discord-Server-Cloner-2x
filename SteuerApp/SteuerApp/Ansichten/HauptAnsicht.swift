import SwiftUI
import SwiftData

/// Die vier Bereiche der App, dazu das Scannen in der Mitte der Leiste.
///
/// Die Reihenfolge folgt der Häufigkeit: **Stand** beantwortet die Frage, wegen der
/// man die App öffnet; **Belege** ist die Liste; **Steuer** fasst Schätzung und
/// Auswertung zusammen, beides Jahresarbeit; **Mehr** hält die Stammdaten. Das
/// Scannen liegt zwischen Belegen und Steuer, also unter dem Daumen.
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

    @State private var bereich: SchwebendeLeiste.Bereich = .stand
    @State private var belegfilter: BelegeAnsicht.Filter = .alle
    @State private var aufnahme: Aufnahmeart?

    init() {
        Self.leistenGestalten()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $bereich) {
                StandAnsicht(jahr: $jahr, bereich: $bereich, belegfilter: $belegfilter)
                    .tag(SchwebendeLeiste.Bereich.stand)

                BelegeAnsicht(jahr: $jahr, filter: $belegfilter)
                    .tag(SchwebendeLeiste.Bereich.belege)

                SteuerAnsicht(jahr: $jahr)
                    .tag(SchwebendeLeiste.Bereich.steuer)

                EinstellungenAnsicht(jahr: $jahr)
                    .tag(SchwebendeLeiste.Bereich.mehr)
            }

            SchwebendeLeiste(
                auswahl: $bereich,
                scannen: { aufnahme = .scannen },
                ausMediathek: { aufnahme = .mediathek },
                vonHand: { aufnahme = .vonHand }
            )
            .padding(.bottom, 6)
        }
        // Der Einzug hängt an der Wurzel, nicht an einem Bereich: sonst schlösse sich
        // die Kamera, sobald der Bereich darunter wechselt.
        .background { Belegaufnahme(jahr: jahr, art: $aufnahme) }
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
