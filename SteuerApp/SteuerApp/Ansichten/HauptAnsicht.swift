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

                BelegeAnsicht(jahr: $jahr, filter: $belegfilter, aufnahme: $aufnahme)
                    .tag(SchwebendeLeiste.Bereich.belege)

                RechnungenAnsicht(jahr: $jahr)
                    .tag(SchwebendeLeiste.Bereich.rechnungen)

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
        .belegeinzug(jahr: jahr, art: $aufnahme)
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

    /// Die Navigationsleiste: oben durchsichtig, beim Scrollen mit Material.
    ///
    /// Zwei Erscheinungsbilder, und das ist der ganze Punkt. Steht die Liste am
    /// Anfang, soll der Verlauf ungebrochen durchlaufen - dort ist die Leiste
    /// durchsichtig. Sobald Inhalt darunter wandert, braucht es eine deckende
    /// Schicht, sonst schiebt sich die erste Zeile durch Uhrzeit und Titel. Genau
    /// das ist passiert, als beide Erscheinungsbilder durchsichtig waren.
    ///
    /// `scrollEdgeAppearance` gilt am oberen Anschlag, `standardAppearance` sobald
    /// gescrollt wird - iOS blendet selbst zwischen beiden über.
    private static func leistenGestalten() {
        let schrift: [NSAttributedString.Key: Any] =
            [.foregroundColor: UIColor(Stil.schrift)]
        let großeSchrift: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(Stil.schrift),
            .font: UIFont.systemFont(ofSize: 30, weight: .bold)
        ]

        let amAnschlag = UINavigationBarAppearance()
        amAnschlag.configureWithTransparentBackground()
        amAnschlag.backgroundColor = .clear
        amAnschlag.shadowColor = .clear
        amAnschlag.titleTextAttributes = schrift
        amAnschlag.largeTitleTextAttributes = großeSchrift

        let beimScrollen = UINavigationBarAppearance()
        // Das Systemmaterial ist hier genau richtig: es streut, was darunter
        // durchläuft, statt es zu verdecken - dieselbe Ebene wie die Glasflächen.
        beimScrollen.configureWithDefaultBackground()
        beimScrollen.shadowColor = UIColor(Stil.trenner)
        beimScrollen.titleTextAttributes = schrift
        beimScrollen.largeTitleTextAttributes = großeSchrift

        UINavigationBar.appearance().scrollEdgeAppearance = amAnschlag
        UINavigationBar.appearance().standardAppearance = beimScrollen
        UINavigationBar.appearance().compactAppearance = beimScrollen
    }
}

#Preview {
    HauptAnsicht()
        .modelContainer(Datenbank.vorschauContainer())
}
