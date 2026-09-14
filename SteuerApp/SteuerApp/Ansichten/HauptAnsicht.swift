import SwiftUI
import SwiftData

/// Die fuenf Bereiche der App. Bewusst flach gehalten: Belege erfassen ist der haeufigste
/// Vorgang und darf nie mehr als einen Fingertipp entfernt sein.
struct HauptAnsicht: View {

    @Environment(\.modelContext) private var kontext

    @AppStorage("ausgewaehltesJahr") private var jahr: Int = Calendar.kalender
        .component(.year, from: Date())

    var body: some View {
        TabView {
            UebersichtAnsicht(jahr: $jahr)
                .tabItem { Label("Uebersicht", systemImage: "chart.pie") }

            BelegeAnsicht(jahr: $jahr)
                .tabItem { Label("Belege", systemImage: "doc.text") }

            SchaetzungAnsicht(jahr: $jahr)
                .tabItem { Label("Schaetzung", systemImage: "function") }

            EuerAnsicht(jahr: $jahr)
                .tabItem { Label("Auswertung", systemImage: "tablecells") }

            EinstellungenAnsicht()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .task { Datenbank.profilSicherstellen(in: kontext) }
    }
}

#Preview {
    HauptAnsicht()
        .modelContainer(Datenbank.vorschauContainer())
}
