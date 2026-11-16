import Foundation
import UIKit

enum ScanKind: String {
    case document
    case receipt
}

struct SavedFolder: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var bookmark: Data
}

enum FavoriteKind: String, Codable {
    case folder
    case share
    case email
}

struct FavoriteDestination: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: FavoriteKind
    var label: String
    var folderID: UUID? = nil
    var email: String? = nil
}

struct OCRSegment {
    let text: String
    /// Vision-Koordinaten: Ursprung unten links, 0...1.
    let boundingBox: CGRect
}

struct ScannedPage: Identifiable {
    var id = UUID()
    var image: UIImage
    var segments: [OCRSegment] = []
    var ocrManuallyCorrected = false
    var recognizedText: String { segments.map(\.text).joined(separator: "\n") }
}

struct ReceiptFields {
    var issuer = ""
    var item = ""
    var date = Date()
    var total = "0,00"
    var vat = "19%"
}

struct FolderSnapshot {
    let nextNumber: Int
    let lastName: String?
}

struct UserFacingError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}
