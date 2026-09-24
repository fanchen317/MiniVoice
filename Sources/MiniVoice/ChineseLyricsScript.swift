import Foundation

enum ChineseLyricsScript {
    static func simplified(_ text: String) -> String {
        // Kana identifies Japanese lyrics: Chinese conversion would damage their kanji.
        guard !text.unicodeScalars.contains(where: {
            (0x3040...0x30FF).contains($0.value) || (0xFF66...0xFF9D).contains($0.value)
        }) else { return text }
        let converted = transform(text, id: "Traditional-Simplified")
        // ICU leaves these variants intact. Do not merge meaningful pronouns such as 祂/祢.
        let variants: [Character: Character] = ["妳": "你", "峯": "峰", "牀": "床", "羣": "群", "綫": "线"]
        return String(converted.map { variants[$0] ?? $0 })
    }

    static func traditional(_ text: String) -> String { transform(text, id: "Simplified-Traditional") }

    private static func transform(_ text: String, id: String) -> String {
        let value = NSMutableString(string: text)
        let fullRange = NSRange(location: 0, length: value.length)
        guard value.applyTransform(StringTransform(id), reverse: false, range: fullRange, updatedRange: nil) else { return text }
        return value as String
    }
}
