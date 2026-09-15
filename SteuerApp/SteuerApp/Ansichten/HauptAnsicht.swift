import SwiftUI
import SwiftData

/// Die fünf Bereiche der App. Bewusst flach gehalten: Belege erfassen ist der häufigste
/// Vorgang und darf nie mehr als einen Fingertipp entfernt sein.
struct HauptAnsicht: View {

    @Environment(\.modelContext) private var kontext

    @AppStorage("ausgewaehltesJahr") private var jahr: Int = Calendar.kalender
        .component(.year, from: Date())

    var body: some View {
        TabView {
            UebersichtAnsicht(jahr: $jahr)
                .tabItem { Label("Übersicht", systemImage: "chart.pie") }

            BelegeAnsicht(jahr: $jahr)
                .tabItem { Label("Belege", systemImage: "doc.text") }

            SchätzungAnsicht(jahr: $jahr)
                .tabItem { Label("Schätzung", systemImage: "function") }

            EuerAnsicht(jahr: $jahr)
                .tabItem { Label("Auswertung", systemImage: "tablecells") }

            EinstellungenAnsicht(jahr: $jahr)
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .task { stammdatenSicherstellen() }
        // Jeder Jahreswechsel braucht einen eigenen Satz Jahresangaben - sonst landen
        // Beiträge und Vorauszahlungen des einen Jahres im anderen.
        .onChange(of: jahr) { stammdatenSicherstellen() }
    }

    private func stammdatenSicherstellen() {
        Datenbank.profilSicherstellen(in: kontext)
        Datenbank.jahresangabenSicherstellen(fuer: jahr, in: kontext)
    }
}

#Preview {
    HauptAnsicht()
        .modelContainer(Datenbank.vorschauContainer())
}
