import Foundation

// Optionale Funktionen sind bei einer frischen Installation bewusst AUS.
struct ScanPreferences: Codable, Equatable {
    var routingEnabled = false         // 07
    var tagsEnabled = false            // 08
    var redactionEnabled = false       // 10
    var remindersEnabled = false       // 12
    var presetsEnabled = false         // 14
    // Alter gemeinsamer Wert: nur noch als Migrationswert für bestehende Installationen.
    var pdfQuality: PDFQuality = .balanced // 09 (Kompatibilität)
    var scanAppearance: ScanAppearance = .automatic
    var documentPDFChoice: PDFExportChoice = .askEveryTime
    var receiptPDFChoice: PDFExportChoice = .askEveryTime
    var documentPDFQuality: PDFQuality = .balanced
    var receiptPDFQuality: PDFQuality = .balanced

    // Ohne eigene Decoder-Implementierung gingen beim App-Update die bisher
    // gespeicherten Opt-in-Schalter verloren, weil der neue Schlüssel fehlt.
    init() {}
    private enum CodingKeys: String, CodingKey {
        case routingEnabled, tagsEnabled, redactionEnabled, remindersEnabled
        case presetsEnabled, pdfQuality, scanAppearance
        case documentPDFChoice, receiptPDFChoice, documentPDFQuality, receiptPDFQuality
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        routingEnabled = try values.decodeIfPresent(Bool.self, forKey: .routingEnabled) ?? false
        tagsEnabled = try values.decodeIfPresent(Bool.self, forKey: .tagsEnabled) ?? false
        redactionEnabled = try values.decodeIfPresent(Bool.self, forKey: .redactionEnabled) ?? false
        remindersEnabled = try values.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        presetsEnabled = try values.decodeIfPresent(Bool.self, forKey: .presetsEnabled) ?? false
        let formerQuality = try values.decodeIfPresent(PDFQuality.self, forKey: .pdfQuality) ?? .balanced
        pdfQuality = formerQuality
        scanAppearance = try values.decodeIfPresent(ScanAppearance.self, forKey: .scanAppearance) ?? .automatic
        documentPDFChoice = try values.decodeIfPresent(PDFExportChoice.self, forKey: .documentPDFChoice) ?? .askEveryTime
        receiptPDFChoice = try values.decodeIfPresent(PDFExportChoice.self, forKey: .receiptPDFChoice) ?? .askEveryTime
        documentPDFQuality = try values.decodeIfPresent(PDFQuality.self, forKey: .documentPDFQuality) ?? formerQuality
        receiptPDFQuality = try values.decodeIfPresent(PDFQuality.self, forKey: .receiptPDFQuality) ?? formerQuality
    }
}

enum PDFExportChoice: String, CaseIterable, Codable, Identifiable {
    case askEveryTime = "Bei jedem Scan auswählen"
    case fixed = "Fest eingestellt"
    var id: String { rawValue }
}

enum ScanAppearance: String, CaseIterable, Codable, Identifiable {
    case automatic = "Automatisch optimiert"
    case blackWhite = "Schwarz-Weiß"
    case grayscale = "Graustufen"
    case original = "Original / Farbe"
    var id: String { rawValue }
}

enum PDFQuality: String, CaseIterable, Codable, Identifiable {
    case compact = "Kompakt"
    case balanced = "Ausgewogen"
    case original = "Hohe Qualität" // bisher gespeicherter Wert bleibt gültig
    case lossless = "Ohne JPEG-Neukomprimierung"
    var id: String { rawValue }
    var maxDimension: CGFloat {
        switch self { case .compact: return 1400; case .balanced: return 2200; case .original, .lossless: return 0 }
    }
    var compression: CGFloat {
        switch self { case .compact: return 0.58; case .balanced: return 0.82; case .original: return 0.94; case .lossless: return 1 }
    }
}

struct FilingRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var merchantContains: String
    var folderID: UUID
    var category: String = ""
}

struct ScanPreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var kind: String  // "document" / "receipt"
    var folderID: UUID? = nil
    var category: String = ""
    var filenameTemplate: String = ""
}

struct SavedRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var filename: String
    var storedFile: String
    var createdAt = Date()
    var documentDate = Date()
    var kind: String
    var issuer = ""
    var item = ""
    var total = ""
    var vat = ""
    var ocrText = ""
    var tags: [String] = []
    var category = ""
    var destination = ""
    var fingerprint = ""
    var returnDeadline: Date? = nil
    var warrantyEnd: Date? = nil
}

struct MerchantAlias: Codable, Identifiable, Equatable {
    var id = UUID()
    var seen: String
    var canonical: String
}

struct QualityWarning: Identifiable {
    var id = UUID()
    var message: String
}
