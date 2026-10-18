import Foundation

/// Builds the opt-in Medical Card QR payload.
///
/// iPhone Camera (and most stock scanners) will not open `data:` URLs — they
/// report “no usable data”. A full self-contained HTML `data:` URL is also too
/// large to scan reliably from a phone screen once CSS, bilingual labels, and
/// percent-encoding are included.
///
/// The QR therefore encodes an `https` link to the static GitHub Pages viewer
/// (`docs/mc.html`) plus a compact JSON fragment. The fragment never leaves the
/// device in an HTTP request (browsers do not send `#...` to the server), so
/// personal health details stay in the QR itself. The hosted file is only an
/// empty bilingual template.
enum MedicalCardQR {
    static let viewerURL = "https://borismak96.github.io/MedTracker/mc.html"

    /// Comfortable size for phone-to-phone scanning (around QR version 15–20).
    static let comfortableMaxUTF8Bytes = 900
    /// Stay under QR version 40-M (~2331 bytes) with a little headroom.
    static let hardMaxUTF8Bytes = 2200

    struct Card: Codable, Equatable {
        /// Display name, present only when the Name toggle is on.
        var n: String?
        /// Allergies text (empty string = included but not recorded).
        var a: String?
        /// Emergency contact, present only when the ICE toggle is on.
        var i: ICE?
        /// Medications, present only when the Medications toggle is on.
        var m: [Med]?
        /// Count of medications omitted to keep the QR scannable.
        var x: Int?

        struct ICE: Codable, Equatable {
            var n: String?
            var r: String?
            var p: String?
        }

        struct Med: Codable, Equatable {
            var n: String
            var d: String?
        }

        var hasIncludedField: Bool {
            n != nil || a != nil || i != nil || m != nil
        }
    }

    /// Full URL encoded in the QR, or `nil` when QR is off / no fields selected.
    static func qrString(for profile: UserProfile) -> String? {
        guard let card = card(from: profile) else { return nil }
        return qrString(for: card)
    }

    static func qrString(for card: Card) -> String? {
        guard card.hasIncludedField else { return nil }
        var fitted = fit(card, maxBytes: comfortableMaxUTF8Bytes)
        if let url = encodeURL(fitted), url.utf8.count <= comfortableMaxUTF8Bytes {
            return url
        }
        fitted = fit(card, maxBytes: hardMaxUTF8Bytes)
        if let url = encodeURL(fitted), url.utf8.count <= hardMaxUTF8Bytes {
            return url
        }
        return encodeURL(fitted)
    }

    /// Selected fields only. Returns `nil` when the QR is hidden or empty.
    static func card(from profile: UserProfile) -> Card? {
        guard profile.showMedicalCardQR else { return nil }

        var card = Card()
        if profile.qrIncludeName {
            card.n = clipped(profile.displayName, max: 80)
        }
        if profile.qrIncludeAllergies {
            card.a = profile.hasAllergies ? clipped(profile.trimmedAllergies, max: 280) : ""
        }
        if profile.qrIncludeICE {
            var ice = Card.ICE()
            if !profile.trimmedICEName.isEmpty { ice.n = clipped(profile.trimmedICEName, max: 80) }
            if !profile.trimmedICERelation.isEmpty { ice.r = clipped(profile.trimmedICERelation, max: 40) }
            if !profile.trimmedICEPhone.isEmpty { ice.p = clipped(profile.trimmedICEPhone, max: 32) }
            card.i = ice
        }
        if profile.qrIncludeMedications {
            card.m = profile.activeMedications.map { med in
                let dose = med.dose.trimmingCharacters(in: .whitespacesAndNewlines)
                return Card.Med(
                    n: clipped(med.name.trimmingCharacters(in: .whitespacesAndNewlines), max: 60),
                    d: dose.isEmpty ? nil : clipped(dose, max: 40)
                )
            }
        }
        return card.hasIncludedField ? card : nil
    }

    static func fragment(for card: Card) -> String? {
        guard let data = encodeJSON(card) else { return nil }
        return "1." + base64URL(data)
    }

    static func decodeCard(fromQRString string: String) -> Card? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fragment = fragmentComponent(of: trimmed) else { return nil }
        return decodeCard(fromFragment: fragment)
    }

    static func decodeCard(fromFragment fragment: String) -> Card? {
        let raw = fragment.hasPrefix("1.") ? String(fragment.dropFirst(2)) : fragment
        guard let data = decodeBase64URL(raw) else { return nil }
        return try? JSONDecoder().decode(Card.self, from: data)
    }

    // MARK: - Encoding

    private static func clipped(_ text: String, max: Int) -> String {
        guard text.count > max else { return text }
        return String(text.prefix(max - 1)) + "…"
    }

    private static func encodeURL(_ card: Card) -> String? {
        guard let fragment = fragment(for: card) else { return nil }
        return "\(viewerURL)#\(fragment)"
    }

    private static func encodeJSON(_ card: Card) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(card)
    }

    private static func fit(_ card: Card, maxBytes: Int) -> Card {
        var fitted = card
        var omitted = card.x ?? 0
        while let url = encodeURL(fitted), url.utf8.count > maxBytes, let meds = fitted.m, !meds.isEmpty {
            fitted.m = Array(meds.dropLast())
            omitted += 1
            fitted.x = omitted
        }
        return fitted
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeBase64URL(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - base64.count % 4) % 4
        if pad > 0 {
            base64.append(String(repeating: "=", count: pad))
        }
        return Data(base64Encoded: base64)
    }

    private static func fragmentComponent(of string: String) -> String? {
        if let hash = string.range(of: "#") {
            let value = String(string[hash.upperBound...])
            return value.isEmpty ? nil : value
        }
        if string.hasPrefix("1.") {
            return string
        }
        return nil
    }
}
