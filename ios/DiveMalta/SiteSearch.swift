import Foundation

/// Typo-tolerant search over the dive sites, for the map's search bar and the site list. Same rules
/// as SiteSearch.kt on Android.
///
/// Names and query are compared without accents, case and punctuation ("ghar lapsi" finds Għar
/// Lapsi, "zurrieq" Żurrieq), every query word must match a word of the name, as its start or with a
/// typo or two ("cirkewa", "um el farud"), and a site type finds its sites ("wreck").
enum SiteSearch {
    static func results(_ query: String, in sites: [DiveSite]) -> [DiveSite] {
        let words = normalize(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return sites }
        return sites
            .compactMap { site in score(words, site).map { (site, $0) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name < $1.0.name }
            .map(\.0)
    }

    /// Higher is better; nil = no match.
    private static func score(_ query: [String], _ site: DiveSite) -> Int? {
        let name = normalize(site.name)
        let joined = query.joined(separator: " ")
        if name == joined { return 1100 }
        if name.hasPrefix(joined) { return 1000 }
        let nameWords = name.split(separator: " ").map(String.init)
        // Typed without spaces ("umelfaroud") or with them where the name has none.
        let compact = query.joined()
        if compact.count >= 3, name.replacingOccurrences(of: " ", with: "").contains(compact) { return 900 }

        var total = 0
        var startsAtFirstWord = false
        for (i, word) in query.enumerated() {
            guard let best = nameWords.indices.map({ (j: $0, typos: typos(word, nameWords[$0])) })
                .min(by: { $0.typos < $1.typos }), best.typos <= allowedTypos(word)
            else {
                // Not in the name: maybe the type ("wreck", "caves").
                guard let type = site.type, typos(word, normalize(type)) <= allowedTypos(word) else { return nil }
                total += 1
                continue
            }
            if i == 0 && best.j == 0 { startsAtFirstWord = true }
            total += best.typos
        }
        return 800 - total * 100 + (startsAtFirstWord ? 50 : 0)
    }

    private static func allowedTypos(_ word: String) -> Int {
        word.count <= 2 ? 0 : word.count <= 5 ? 1 : 2
    }

    /// Typos between a query word and a name word it may be the start of: the fewest edits to turn
    /// the query word into the name word or into its start of about the same length.
    private static func typos(_ word: String, _ nameWord: String) -> Int {
        let a = Array(word), b = Array(nameWord)
        // Damerau-Levenshtein (optimal string alignment), keeping the whole last row so any prefix
        // of the name word can be the target.
        var previous2 = [Int](), previous = Array(0...b.count)
        for i in 1...a.count {
            var row = [i] + [Int](repeating: 0, count: b.count)
            for j in stride(from: 1, through: b.count, by: 1) {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                row[j] = min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    row[j] = min(row[j], previous2[j - 2] + 1)
                }
            }
            previous2 = previous
            previous = row
        }
        // A prefix of the name word at least as long as the query word, minus a missed letter.
        let from = max(0, a.count - 1)
        return from <= b.count ? previous[from...].min()! : previous[b.count]
    }

    /// Lowercase, without accents (ħ → h, ż → z), apostrophes dropped and other punctuation as spaces.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "ħ", with: "h")   // a letter of its own, not h with an accent
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
        let spaced = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }
}
