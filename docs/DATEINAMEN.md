# Beispielbelege – Namenskonvention

Die vom Nutzer bereitgestellte Abbildung zeigt fortlaufend nummerierte PDF-Dateien
mit Firmenname, Artikel, Datum, Gesamtbetrag und Steuerangabe. Aus Datenschutzgründen
wird die Abbildung **nicht** in das öffentliche GitHub-Projekt übernommen.

Die folgenden Beispiele sind **synthetisch** und illustrieren nur die Struktur:

- `008_Geschaeft_Bilder_08.01.2026 (10,29 - 19%).pdf`
- `009_Supermarkt_Lebensmittel_07.01.2026 (41,32 - gemischt).pdf`
- `010_Grosshandel_Sekt_10.01.2026 (19,03 - 19%).pdf`
- `011_Haushaltsladen_Geschirr_09.01.2026 (191,54 - 19%).pdf`
- `012_Baumarkt_Filzgleiter_10.01.2026 (9,30 - 19%).pdf`
- `013_Metzgerei_Mett_10.01.2026 (8,00 - 7%).pdf`

DokuScan orientiert sich an der **ausdrücklich beschriebenen** Schreibweise:

`017_Firma_Beschreibung_14.11.2026_(41,32 - 19%).pdf`

Gegenüber manchen Beispielen sind die Trennzeichen konsistent: Vor der Klammer
steht wie gewünscht ein Unterstrich. DokuScan erzeugt selbst keine zusätzlichen
`.pdf`-Endungen bei bereits eingegebener Endung.

Die nächste Nummer wird nur aus PDF-Dateien im gewählten Ordner ermittelt,
deren Name mit **mindestens drei Ziffern und Unterstrich** beginnt. Maßgeblich
ist die größte Nummer, nicht das Dateidatum. Nach `999` verwendet die App
`1000` (keine Rücksetzung), um keine Nummer zu wiederholen.

Die Auswertung aus OCR ist eine **plausible Vorbelegung**, kein maschinell
validierter Rechnungsdatensatz. Die Felder können geprüft und manuell
angepasst werden; besonders wichtig sind die teuerste Position und eine
mögliche gemischte Mehrwertsteuer.
