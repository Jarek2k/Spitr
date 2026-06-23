//
//  LocalizationCatalogTests.swift
//  SpitrTests
//
//  Guards the String Catalogs so a forgotten translation can never ship: every
//  entry must be translated into every supported language, and no translation
//  may drop or alter a format specifier (%@ …) — that would crash at runtime.
//
//  These read the source catalogs directly (via #filePath), so they fail in CI
//  the moment someone adds a string without filling in all languages. The
//  companion Scripts/check_localization.py additionally catches code strings
//  that were never added to the catalog at all.
//

import Testing
import Foundation

struct LocalizationCatalogTests {

    /// Languages every catalog entry must provide (besides the German source).
    static let requiredLanguages = ["en", "fr", "es", "it", "pl"]

    // MARK: Loading

    private func catalogURL(_ name: String) -> URL {
        // SpitrTests/LocalizationCatalogTests.swift → repo root → Spitr/<name>
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Spitr")
            .appending(path: name)
    }

    private func loadStrings(_ name: String) throws -> (source: String, strings: [String: Any]) {
        let data = try Data(contentsOf: catalogURL(name))
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let source = try #require(root["sourceLanguage"] as? String)
        let strings = try #require(root["strings"] as? [String: Any])
        return (source, strings)
    }

    private func value(_ entry: Any, _ lang: String) -> String? {
        guard let entry = entry as? [String: Any],
              let locs = entry["localizations"] as? [String: Any],
              let unit = (locs[lang] as? [String: Any])?["stringUnit"] as? [String: Any],
              (unit["state"] as? String) == "translated",
              let value = unit["value"] as? String, !value.isEmpty
        else { return nil }
        return value
    }

    /// All format specifiers (e.g. %@, %lld) in order, so translations must keep
    /// the same placeholders or the runtime substitution crashes / corrupts text.
    private func specifiers(_ s: String) -> [String] {
        // swiftlint:disable:next force_try — constant, provably-valid literal pattern (test code)
        let regex = try! NSRegularExpression(pattern: "%([0-9$]*)(@|lld|ld|d|f|lf)")
        let range = NSRange(s.startIndex..., in: s)
        return regex.matches(in: s, range: range).map { (s as NSString).substring(with: $0.range) }
    }

    // MARK: Tests

    @Test func uiCatalogIsFullyTranslated() throws {
        let (source, strings) = try loadStrings("Localizable.xcstrings")
        #expect(source == "de")

        var problems: [String] = []
        for (key, entry) in strings {
            // German is the source language and lives verbatim as the key, so it
            // needs no localization — only the target languages must be present.
            for lang in Self.requiredLanguages {
                guard let translation = value(entry, lang) else {
                    problems.append("• [\(lang)] fehlt: \"\(key)\"")
                    continue
                }
                if specifiers(translation) != specifiers(key) {
                    problems.append("• [\(lang)] Format-Specifier weichen ab: \"\(key)\" → \"\(translation)\"")
                }
            }
        }
        #expect(problems.isEmpty, "Lokalisierungs-Lücken (\(problems.count)):\n\(problems.joined(separator: "\n"))")
    }

    @Test func infoPlistCatalogIsFullyTranslated() throws {
        let (source, strings) = try loadStrings("InfoPlist.xcstrings")
        #expect(source == "de")

        // Here the key is an Info.plist key name, so German is an explicit
        // translation too — every language including de must be present.
        let required = ["de"] + Self.requiredLanguages
        var problems: [String] = []
        for (key, entry) in strings {
            for lang in required where value(entry, lang) == nil {
                problems.append("• [\(lang)] fehlt: \(key)")
            }
        }
        #expect(problems.isEmpty, "Info.plist-Lücken (\(problems.count)):\n\(problems.joined(separator: "\n"))")
    }
}
