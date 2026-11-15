import Foundation

/// Die Vorschläge sind OCR-Heuristiken, keine garantierte Rechnungsanalyse.
enum FileNaming {
    static func documentName(from text: String, date: Date = Date()) -> String {
        let prefix = format(date, pattern: "yyMMdd")
        let first = text.components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: .whitespaces) }
            .map(cleanComponent)
            .first { $0.count >= 3 && $0.rangeOfCharacter(from: .letters) != nil && !isGeneric($0) }
            ?? "Dokument"
        return "\(prefix)_\(first)"
    }

    static func receiptName(number: Int, fields: ReceiptFields) -> String {
        let serial = String(format: "%03d", number)
        let issuer = cleanComponent(fields.issuer)
        let item = cleanComponent(fields.item)
        let date = format(fields.date, pattern: "dd.MM.yyyy")
        let total = fields.total.trimmingCharacters(in: .whitespacesAndNewlines)
        let vat = fields.vat.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(serial)_\(issuer.isEmpty ? "Firma" : issuer)_\(item.isEmpty ? "Position" : item)_\(date)_(\(total.isEmpty ? "0,00" : total) - \(vat.isEmpty ? "unbekannt" : vat))"
    }

    static func filename(_ editableName: String) throws -> String {
        var name = editableName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.lowercased().hasSuffix(".pdf") { name = String(name.dropLast(4)) }
        name = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
        guard !name.isEmpty, name != ".", name != ".." else {
            throw UserFacingError(message: "Bitte einen gültigen Dateinamen eingeben.")
        }
        return String(name.prefix(180)) + ".pdf"
    }

    static func format(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    static func cleanComponent(_ input: String) -> String {
        let allowed = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "- äöüÄÖÜß"))
        let filtered = String(input.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " })
        return filtered.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isGeneric(_ input: String) -> Bool {
        ["rechnung", "quittung", "kassenbon", "beleg", "datum", "seite", "www", "steuer", "ust"].contains(input.lowercased())
    }
}

/// Ermittelt wahrscheinlichen Aussteller, teuerste Einzelposition, Datum, Bruttosumme und USt.
/// Alle Felder sind vor dem Speichern frei korrigierbar.
enum ReceiptNamer {
    private static let pricePattern = #"(?:\d{1,3}(?:\.\d{3})*|\d+),\d{2}"#
    private static let datePattern = #"\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b"#

    static func parse(_ text: String) -> ReceiptFields {
        var fields = ReceiptFields()
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let candidates = lines.prefix(8).filter { line in
            line.rangeOfCharacter(from: .letters) != nil &&
            !["rechnung", "kassenbon", "quittung", "beleg", "datum", "filiale", "tel.", "telefon", "www.", "ust-id"].contains(where: { line.lowercased().contains($0) }) &&
            line.count < 65
        }
        if let issuer = candidates.first { fields.issuer = FileNaming.cleanComponent(issuer) }

        if let match = firstMatch(pattern: datePattern, text: text), match.count == 4 {
            var year = Int(match[3]) ?? 0
            if year < 100 { year += year < 70 ? 2000 : 1900 }
            var components = DateComponents()
            components.day = Int(match[1])
            components.month = Int(match[2])
            components.year = year
            if let date = Calendar(identifier: .gregorian).date(from: components) { fields.date = date }
        }

        struct PriceLine { let text: String; let amount: Decimal }
        let priceLines: [PriceLine] = lines.compactMap { line in
            guard let value = lastMatch(pattern: pricePattern, text: line), let decimal = amount(value) else { return nil }
            return PriceLine(text: line, amount: decimal)
        }
        let totalWords = ["summe", "gesamt", "total", "betrag", "zu zahlen", "brutto", "endbetrag"]
        let totalLines = priceLines.filter { line in totalWords.contains(where: { line.text.lowercased().contains($0) }) }
        if let best = (totalLines.isEmpty ? priceLines : totalLines).max(by: { $0.amount < $1.amount }) {
            fields.total = amountString(best.amount)
        }
        let itemLines = priceLines.filter { line in
            let lower = line.text.lowercased()
            return line.text.rangeOfCharacter(from: .letters) != nil &&
                !totalWords.contains(where: { lower.contains($0) }) &&
                !["mwst", "ust", "steuer", "wechselgeld", "bar", "ec-karte", "visa", "mastercard"].contains(where: { lower.contains($0) })
        }
        if let mostExpensive = itemLines.max(by: { $0.amount < $1.amount }) {
            let title = mostExpensive.text.replacingOccurrences(of: pricePattern, with: "", options: .regularExpression)
            let cleaned = FileNaming.cleanComponent(title)
            if !cleaned.isEmpty { fields.item = String(cleaned.prefix(55)) }
        } else if lines.count > 2 {
            fields.item = "Beleg"
        }

        let lower = text.lowercased()
        let has7 = lower.range(of: #"\b7\s*%"#, options: .regularExpression) != nil
        let has19 = lower.range(of: #"\b19\s*%"#, options: .regularExpression) != nil
        let has0 = lower.range(of: #"\b0\s*%"#, options: .regularExpression) != nil
        fields.vat = has7 && has19 ? "gemischt" : has7 ? "7%" : has19 ? "19%" : has0 ? "0%" : "unbekannt"
        return fields
    }

    private static func firstMatch(pattern: String, text: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let match = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func lastMatch(pattern: String, text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let match = re.matches(in: text, range: NSRange(text.startIndex..., in: text)).last,
              let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }

    private static func amount(_ string: String) -> Decimal? {
        Decimal(string: string.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func amountString(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: decimal as NSDecimalNumber) ?? "0,00"
    }
}
