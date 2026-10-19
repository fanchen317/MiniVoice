import Foundation
import NaturalLanguage

enum LyricLanguage {
    static func code(_ input: String) -> String {
        let value=input.trimmingCharacters(in:.whitespacesAndNewlines).lowercased().replacingOccurrences(of:"_",with:"-")
        if value.isEmpty || value=="auto" { return "auto" }
        let primary=String(value.split(separator:"-").first ?? "auto")
        return ["cmn":"zh","nb":"no","nn":"no","fil":"tl","iw":"he" ][primary] ?? primary
    }
    static func hasKana(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3040...0x30ff).contains($0.value) || (0xff66...0xff9d).contains($0.value) }
    }
    static func hasHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0xac00...0xd7af).contains($0.value) || (0x1100...0x11ff).contains($0.value) }
    }
    static func normalized(_ text: String, language: String) -> [Character] {
        var text=text.precomposedStringWithCompatibilityMapping
        // Chinese character conversion must never rewrite Japanese kanji.
        if ["zh","yue"].contains(language), !hasKana(text), !hasHangul(text) {
            text=text.applyingTransform(StringTransform("Traditional-Simplified"), reverse:false) ?? text
        }
        text=text.folding(options:[.caseInsensitive,.widthInsensitive],locale:Locale(identifier:"en_US_POSIX"))
        return Array(text.filter { $0.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) } })
    }
    static func windowLanguage(_ text: String, fallback: String) -> String {
        if hasKana(text) { return "ja" }
        if hasHangul(text) { return "ko" }
        let han=text.unicodeScalars.filter { (0x3400...0x9fff).contains($0.value) }.count
        if han>0 { return fallback=="auto" ? "auto" : fallback=="ja" ? "ja" : "zh" }
        // Short interjections are ambiguous: keep the acoustic language.
        guard text.split(whereSeparator: { $0.isWhitespace }).count>=3 else { return fallback }
        let recognizer=NLLanguageRecognizer()
        recognizer.processString(text)
        guard let (language,score)=recognizer.languageHypotheses(withMaximum:1).first,score>=0.8 else { return fallback }
        let allowed:Set<String>=["en","fr","es","de","it","pt","ru","ar","hi","th","tr","vi","nl","pl","uk","he","id","sv","da","fi","el","ro","hu","cs","bn","ta","te"]
        let code=language.rawValue
        return allowed.contains(code) ? code : fallback
    }
}
