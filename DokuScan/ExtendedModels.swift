import Foundation

// Optionale Funktionen sind bei einer frischen Installation bewusst AUS.
struct ScanPreferences: Codable, Equatable {
    var routingEnabled = false         // 07
    var tagsEnabled = false            // 08
    var redactionEnabled = false       // 10
    var remindersEnabled = false       // 12
    var presetsEnabled = false         // 14
    var pdfQuality: PDFQuality = .balanced // 09
}

enum PDFQuality: String, CaseIterable, Codable, Identifiable {
    case compact = "Kompakt"
    case balanced = "Ausgewogen"
    case original = "Hohe Qualität"
    var id: String { rawValue }
    var maxDimension: CGFloat {
        switch self { case .compact: return 1400; case .balanced: return 2200; case .original: return 0 }
    }
    var compression: CGFloat {
        switch self { case .compact: return 0.58; case .balanced: return 0.82; case .original: return 1 }
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
