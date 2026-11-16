import Foundation

// Linux-kompatibler Regressionstest für die unveränderte OCR-Parser-Implementierung.
// iOS-spezifische Bildmodelle werden durch kleine kompatible Typen ersetzt.
struct UserFacingError: Error { let message: String }
struct OCRSegment {
    let text: String
    let boundingBox: CGRect
}
struct ReceiptFields {
    var issuer = ""
    var item = ""
    var date = Date()
    var total = "0,00"
    var vat = "19%"
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fputs("FEHLER: \(message)\n", stderr); exit(1) }
}
let receipt = """
REWE MARKT GmbH
Filiale 102
Milch 1,49
BIO KAFFEE 6,49
Gesamt 7,98
19% MwSt
"""
let fields = ReceiptNamer.parse(receipt)
check(fields.issuer.uppercased().contains("REWE"), "Händler nicht erkannt")
check(fields.item.uppercased().contains("KAFFEE"), "Teuerste Artikelposition falsch")
check(fields.total == "7,98", "Gesamtbetrag falsch")

let text2 = """
EINKAUFSLADEN
Kaffee, gemahlen
9,99
Wasser 0,99
Summe 10,98
"""
let fields2 = ReceiptNamer.parse(text2)
check(fields2.item.localizedCaseInsensitiveContains("kaffee"), "Artikel aus vorheriger Zeile fehlt")
check(fields2.total == "10,98", "Summe nicht gefunden")

let segments = [
    OCRSegment(text: "MARKT", boundingBox: CGRect(x:0.1, y:0.9, width:0.5, height:0.02)),
    OCRSegment(text: "Schokolade", boundingBox: CGRect(x:0.10, y:0.7, width:0.4, height:0.025)),
    OCRSegment(text: "4,99", boundingBox: CGRect(x:0.82, y:0.7, width:0.12, height:0.025)),
    OCRSegment(text: "Keks", boundingBox: CGRect(x:0.1, y:0.6, width:0.4, height:0.025)),
    OCRSegment(text: "1,99", boundingBox: CGRect(x:0.82, y:0.6, width:0.12, height:0.025)),
    OCRSegment(text: "Gesamt 6,98", boundingBox: CGRect(x:0.10, y:0.4, width:0.80, height:0.025))
]
let fields3 = ReceiptNamer.parse(segmentsByPage: [segments])
check(fields3.item.localizedCaseInsensitiveContains("schokolade"), "Artikelpreis in eigener OCR-Spalte nicht erkannt")
print("OK: 3 Parser-/Beleg-Regressionstests bestanden")
