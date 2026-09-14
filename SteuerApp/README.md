# Steuer – iOS-App für Selbständige und Freiberufler

Eine SwiftUI-App, die Belege sammelt, daraus die Einnahmen-Überschuss-Rechnung aufstellt und
laufend schätzt, wie viel Geld für das Finanzamt zurückgelegt werden muss.

Gebaut für den Fall, der im Alltag am meisten weh tut: Man verdient das Jahr über gut, legt zu
wenig zurück, und im Herbst kommt der Bescheid. Die App beantwortet jederzeit die eine Frage,
die dabei zählt – **wie viel von dem Geld auf dem Konto gehört mir eigentlich?**

## Funktionsumfang

**Belege erfassen**
- Beleg mit der Dokumentenkamera abfotografieren; Kanten werden erkannt und entzerrt
- Texterkennung schlägt Betrag und Datum vor – als Vorschlag, der überschrieben werden kann
- 26 Kategorien in der Gliederung der Anlage EÜR, jeweils mit Hinweis auf die EÜR-Zeile
- Umsatzsteuersatz je Beleg (0 %, 7 %, 19 %)
- betrieblicher Anteil für gemischt genutzte Kosten wie Telefon oder Fahrzeug
- Suche, Monatsgruppierung, Filter nach Einnahmen, Ausgaben und fehlenden Belegfotos

**Auswerten**
- Einnahmen-Überschuss-Rechnung nach § 4 Abs. 3 EStG, nach Kategorien aufgeschlüsselt
- Umsatzsteuer-Voranmeldung monatlich oder vierteljährlich, mit Zahllast je Zeitraum
- CSV-Export von Belegliste und Jahresauswertung für Excel oder die Steuerberatung

**Schätzen**
- Einkommensteuer nach § 32a EStG, Grund- und Splittingtarif
- Solidaritätszuschlag mit Freigrenze und Milderungszone
- Kirchensteuer 8 % / 9 %
- Gewerbesteuer inklusive Anrechnung nach § 35 EStG (für Gewerbetreibende)
- Vorsorgeaufwendungen als Sonderausgaben – für Selbständige der größte Abzugsposten
- Rücklagenquote und offener Betrag nach Abzug geleisteter Vorauszahlungen
- jeder Zwischenschritt einzeln sichtbar, damit die Zahl nachvollziehbar bleibt

## Bauen

```bash
open SteuerApp/SteuerApp.xcodeproj
```

- Xcode 16 oder neuer (das Projekt nutzt dateisystem-synchronisierte Gruppen)
- iOS 17.0 als Mindestversion (SwiftData, `ContentUnavailableView`)
- keine externen Abhängigkeiten

Vor dem ersten Start in den Zielangaben eine eigene Bundle-ID und ein Signaturteam eintragen.
Die Dokumentenkamera und die Texterkennung laufen nur auf einem echten Gerät, alles andere
funktioniert im Simulator.

Tests:

```bash
xcodebuild test -project SteuerApp/SteuerApp.xcodeproj \
  -scheme SteuerApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Aufbau

```
SteuerApp/
├── Modell/          SwiftData-Objekte: Beleg, Steuerprofil, Kategorien, Steuersätze
├── Steuerlogik/     reine Rechenlogik, ohne SwiftUI und ohne Datenbank
├── Ansichten/       SwiftUI-Oberfläche, fünf Bereiche
└── Dienste/         Formatierung, Belegarchiv, CSV-Export, Texterkennung
```

Die Steuerlogik hängt von keiner Ansicht und keiner Datenbank ab. Sie nimmt Zahlen entgegen und
gibt Zahlen zurück – deshalb ist sie vollständig durch Tests abgedeckt, und deshalb lässt sich
ein Rechenweg prüfen, ohne die App zu starten.

Geldbeträge sind durchgehend `Decimal`. `Double` kommt nur innerhalb der Tarifpolynome vor,
wo § 32a EStG ohnehin auf volle Euro abrundet.

## Steuerliche Grundlagen

Hinterlegt sind die Veranlagungszeiträume **2024, 2025 und 2026**. Alle jahresabhängigen
Werte stehen in einer einzigen Datei: `Steuerlogik/Steuerjahr.swift`.

### Ein neues Jahr ergänzen

Einen weiteren `Steuerjahr`-Eintrag anlegen und in `Steuerjahr.alle` aufnehmen. Der Rest der App
zieht automatisch nach. Nötig sind die Werte aus § 32a Abs. 1 EStG, die Freigrenze des
Solidaritätszuschlags und die Höchstbeträge der Vorsorgeaufwendungen.

`SteuerjahrKonsistenzTests` prüft danach jeden Eintrag gegen die Eckwerte, die der Gesetzgeber
dem Tarif zugrunde legt: Der Grenzsteuersatz beträgt am Ende der ersten Progressionszone exakt
23,97 % und am Ende der zweiten exakt 42 %, und der Sockelbetrag der dritten Zone ist die Steuer
am Ende der zweiten. Diese Bedingungen verknüpfen die Tarifkonstanten miteinander – ein
Zahlendreher verletzt sie sofort. Das ist genau der Fehler, der beim jährlichen Nachtragen am
wahrscheinlichsten ist.

### Stand der Prüfung

| Jahr | Grundfreibetrag | Status |
|------|-----------------|--------|
| 2024 | 11.784 € | intern konsistent, **nicht** gegen die amtliche Grundtabelle abgeglichen |
| 2025 | 12.096 € | gegen die amtliche Grundtabelle geprüft |
| 2026 | 12.348 € | intern konsistent, **nicht** gegen die amtliche Grundtabelle abgeglichen |

Alle drei Jahre erfüllen die oben genannten gesetzlichen Eckwerte exakt. Für 2025 stimmen die
Ergebnisse zusätzlich mit veröffentlichten Werten der Einkommensteuer-Grundtabelle überein.
Für 2024 und 2026 steht dieser Abgleich noch aus – die App weist in der Übersicht und in der
Schätzung sichtbar darauf hin, und `amtlichGeprueft` im jeweiligen `Steuerjahr` schaltet den
Hinweis ab, sobald die Werte geprüft sind.

### Bewusste Vereinfachungen

Die App bildet die häufigen Fälle ab, nicht jede Besonderheit. Nicht berücksichtigt sind:

- Kinderfreibeträge und die Günstigerprüfung gegen das Kindergeld
- Verlustvor- und -rückträge zwischen den Jahren
- Progressionsvorbehalt bei Lohnersatzleistungen
- Abgeltungsteuer auf Kapitalerträge
- die zumutbare Belastung bei außergewöhnlichen Belastungen (bitte vorab abziehen)
- Abschreibungen werden erfasst, aber nicht aus Anschaffungsdaten berechnet
- bei der Kirchensteuer wird die Einkommensteuer ohne Kinderfreibeträge angesetzt

Zwei Punkte, bei denen die App bewusst anders rechnet als das amtliche Formular:

- **Nettomethode in der EÜR.** Umsatzsteuer und Vorsteuer bleiben aus der Gewinnermittlung
  heraus, weil sie wirtschaftlich durchlaufende Posten sind. Das Ergebnis entspricht der
  Bruttomethode, ist unterjährig aber aussagekräftiger. Beim Übertragen in die Anlage EÜR sind
  Umsatzsteuer und Vorsteuer wieder zu ergänzen.
- **Ist-Versteuerung.** Maßgeblich ist das erfasste Belegdatum. Wer nach vereinbarten Entgelten
  versteuert, trägt das Rechnungsdatum ein.

Korrekt abgebildet sind dagegen einige Details, die häufig untergehen: Bewirtungskosten sind nur
zu 70 % Betriebsausgabe, während die Vorsteuer voll abziehbar bleibt. Die Gewerbesteuer-
Anrechnung ist auf das 3,8-fache des Messbetrags **und** auf die tatsächlich gezahlte Steuer
gedeckelt. Und die Gesamtbelastung setzt die volle Gewerbesteuer an, nicht nur die Restbelastung –
sonst würde die Anrechnung doppelt gutgeschrieben.

## Datenschutz

Alle Daten bleiben auf dem Gerät. Die App verschickt nichts, meldet nichts und bindet keine
fremden Dienste ein. Belege und Texterkennung werden lokal verarbeitet. Belegfotos liegen als
Dateien in „Application Support“ und sind damit vom Geräte-Backup erfasst; die Datenbank
selbst bleibt dadurch klein.

## Haftungsausschluss

Diese App ist ein Rechenwerkzeug und ersetzt keine Steuerberatung. Die Schätzung ist eine
Schätzung. Verbindlich ist allein der Bescheid des Finanzamts.
