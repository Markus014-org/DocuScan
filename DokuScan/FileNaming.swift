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

/// Heuristische Offline-Auswertung von Kassenbons. Keine sichere Belegbuchhaltung:
/// Im Zweifel bleiben Händler / Artikel leer und können in der Prüfansicht ergänzt werden.
enum ReceiptNamer {
    private static let pricePattern = #"(?<!\d)(?:\d{1,3}(?:\.\d{3})+|\d+)[,.]\d{2}(?!\d)"#
    private static let datePattern = #"\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b"#
    private static let totalWords = ["summe", "gesamt", "total", "zu zahlen", "zahlbetrag", "endbetrag", "brutto", "rechnungsbetrag"]
    private static let excludedWords = [
        "mwst", "ust", "steuer", "netto", "wechselgeld", "rückgeld", "rueckgeld",
        "barzahlung", "kartenzahlung", "girocard", "mastercard", "visa", "ec-karte",
        "gegeben", "erhalten", "trinkgeld", "rabatt", "coupon", "gutschein",
        "transaktion", "kassenbon", "quittung", "rechnung", "bon-nr",
        "artikelanzahl", "anzahl artikel", "subtotal"
    ]
    private static let merchantExcludedWords = excludedWords + [
        "beleg", "datum", "uhrzeit", "filiale", "kasse", "bediener", "kassierer",
        "tel.", "telefon", "www.", "http", "@", "ust-id", "steuernummer",
        "danke", "vielen dank", "willkommen", "besuchen sie", "auf wiedersehen",
        "strasse", "straße", "str.", "platz", "kundennummer", "tse", "kassen-id",
        "artikel", "bonnummer", "bon nr", "öffnungszeiten", "öffnungszeiten"
    ]

    /// Rückwärtskompatibel für OCR-Text ohne Positionsinformationen.
    static func parse(_ text: String) -> ReceiptFields {
        parsePages([text.components(separatedBy: .newlines)])
    }

    /// Bevorzugter Aufruf: Nutzt die Bildkoordinaten, damit Namen und rechts
    /// daneben stehende Preise wieder zu einer Bon-Zeile zusammenfinden.
    static func parse(segmentsByPage: [[OCRSegment]]) -> ReceiptFields {
        parsePages(segmentsByPage.map { reconstructedRows(from: $0) })
    }

    private static func parsePages(_ pages: [[String]]) -> ReceiptFields {
        var fields = ReceiptFields()
        let lines = pages.flatMap { $0 }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return fields }

        fields.issuer = merchant(from: pages.first ?? [])
        let text = lines.joined(separator: "\n")
        if let match = firstMatch(pattern: datePattern, text: text), match.count == 4 {
            var year = Int(match[3]) ?? 0
            if year < 100 { year += year < 70 ? 2000 : 1900 }
            let components = DateComponents(year: year, month: Int(match[2]), day: Int(match[1]))
            if let date = Calendar(identifier: .gregorian).date(from: components),
               Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date) == components {
                fields.date = date
            }
        }

        struct PricedRow {
            let name: String
            let amount: Decimal
        }
        var totals: [Decimal] = []
        var products: [PricedRow] = []
        for (index, line) in lines.enumerated() {
            // Ein Datum ist kein Preis (z. B. 15.11.2026).
            if line.range(of: datePattern, options: .regularExpression) != nil,
               !containsTotalWord(line) { continue }
            guard let found = lastMatch(pattern: pricePattern, text: line),
                  let value = amount(found) else { continue }
            let lower = line.lowercased()
            if containsTotalWord(lower) {
                totals.append(value)
                continue
            }
            if excludedWords.contains(where: { containsKeyword(lower, $0) }) { continue }

            var name = itemTitle(line)
            // Beispiel: OCR gibt "BIO KAFFEE" und in der nächsten Zeile "6,49" zurück.
            // Eine reine Preis-/Mengenzeile wird mit der vorigen Beschriftung verbunden.
            if !validItem(name), index > 0 {
                let previous = lines[index - 1]
                if lastMatch(pattern: pricePattern, text: previous) == nil,
                   !containsTotalWord(previous),
                   !excludedWords.contains(where: { containsKeyword(previous.lowercased(), $0) }) {
                    name = itemTitle(previous)
                }
            }
            if validItem(name) && value > 0 {
                products.append(PricedRow(name: String(name.prefix(55)), amount: value))
            }
        }
        if let maximum = totals.max() {
            fields.total = amountString(maximum)
        } else if let maximum = products.map(\.amount).max() {
            // Kein sicheres Gesamt-Label: maximalen gefundenen Betrag nur als Schätzung.
            fields.total = amountString(maximum)
        }
        if let maximum = products.max(by: { $0.amount < $1.amount }) {
            fields.item = maximum.name
        }

        let lower = text.lowercased()
        let has7 = lower.range(of: #"\b7\s*%"#, options: .regularExpression) != nil
        let has19 = lower.range(of: #"\b19\s*%"#, options: .regularExpression) != nil
        let has0 = lower.range(of: #"\b0\s*%"#, options: .regularExpression) != nil
        fields.vat = has7 && has19 ? "gemischt" : has7 ? "7%" : has19 ? "19%" : has0 ? "0%" : "unbekannt"
        return fields
    }

    private struct RowGroup {
        var centerY: CGFloat
        var height: CGFloat
        var parts: [OCRSegment]
    }

    private static func reconstructedRows(from segments: [OCRSegment]) -> [String] {
        let ordered = segments.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [RowGroup] = []
        for segment in ordered {
            let y = segment.boundingBox.midY
            let h = segment.boundingBox.height
            let match = rows.indices.min(by: { abs(rows[$0].centerY - y) < abs(rows[$1].centerY - y) })
            if let index = match,
               abs(rows[index].centerY - y) < max(0.009, min(0.025, max(rows[index].height, h) * 0.52)) {
                let count = CGFloat(rows[index].parts.count)
                rows[index].centerY = (rows[index].centerY * count + y) / (count + 1)
                rows[index].height = max(rows[index].height, h)
                rows[index].parts.append(segment)
            } else {
                rows.append(RowGroup(centerY: y, height: h, parts: [segment]))
            }
        }
        return rows.sorted { $0.centerY > $1.centerY }.map { row in
            row.parts.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .map(\.text).joined(separator: " ")
        }
    }

    private static func merchant(from firstPage: [String]) -> String {
        struct Candidate { let name: String; let score: Int }
        let header = firstPage.prefix(14)
        let candidates: [Candidate] = header.enumerated().compactMap { index, raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = line.lowercased()
            let cleaned = FileNaming.cleanComponent(line)
            guard cleaned.count >= 2, cleaned.count <= 55,
                  line.rangeOfCharacter(from: .letters) != nil,
                  !merchantExcludedWords.contains(where: { containsKeyword(lower, $0) }),
                  lastMatch(pattern: pricePattern, text: line) == nil,
                  line.range(of: datePattern, options: .regularExpression) == nil,
                  line.range(of: #"\b\d{4,5}\b"#, options: .regularExpression) == nil else { return nil }

            let letters = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }
            let upper = letters.filter { CharacterSet.uppercaseLetters.contains($0) }
            guard letters.count >= 2,
                  Double(line.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count) / Double(max(1, line.count)) < 0.25 else { return nil }
            var score = 25 - index * 2
            if index < 3 { score += 6 }
            if Double(upper.count) / Double(letters.count) > 0.7 { score += 6 }
            if ["gmbh", " gbr", " kg", " ag", " e.k", "ohg"].contains(where: { lower.contains($0) }) { score += 13 }
            if cleaned.split(separator: " ").count <= 4 { score += 3 }
            return Candidate(name: cleaned, score: score)
        }
        return candidates.max(by: { $0.score < $1.score })?.name ?? ""
    }

    private static func containsTotalWord(_ line: String) -> Bool {
        totalWords.contains { line.lowercased().contains($0) }
    }

    private static func containsKeyword(_ line: String, _ keyword: String) -> Bool {
        // "USt" ist ein Steuerkürzel, darf aber "Musterladen" nicht ausschließen.
        if keyword == "ust" || keyword == "tse" {
            return line.range(of: #"(?<![\p{L}])"# + keyword + #"(?![\p{L}])"#,
                              options: .regularExpression) != nil
        }
        return line.contains(keyword)
    }

    private static func itemTitle(_ line: String) -> String {
        var title = line.replacingOccurrences(of: pricePattern, with: " ", options: .regularExpression)
        title = title.replacingOccurrences(of: #"(?i)\b\d+\s*[x×]\s*$"#, with: " ", options: .regularExpression)
        title = title.replacingOccurrences(of: #"(?i)\b(?:eur|euro|stk)\b"#, with: " ", options: .regularExpression)
        return FileNaming.cleanComponent(title)
    }

    private static func validItem(_ title: String) -> Bool {
        guard title.range(of: #"[A-Za-zÄÖÜäöüß]{3,}"#, options: .regularExpression) != nil else { return false }
        let lower = title.lowercased()
        return !containsTotalWord(lower) && !excludedWords.contains(where: { containsKeyword(lower, $0) }) &&
            !["beleg", "position", "betrag", "artikel", "euro"].contains(lower)
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
        guard let decimalMark = string.lastIndex(where: { $0 == "," || $0 == "." }) else { return nil }
        let whole = string[..<decimalMark].filter { $0.isNumber }
        let cents = string[string.index(after: decimalMark)...].filter { $0.isNumber }
        guard !whole.isEmpty, cents.count == 2 else { return nil }
        return Decimal(string: "\(whole).\(cents)", locale: Locale(identifier: "en_US_POSIX"))
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
