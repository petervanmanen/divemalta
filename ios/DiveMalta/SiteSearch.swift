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

    /// The site a dive's title names ("Cirkewwa right arch", "ghar lapsi finger reef"), out of
    /// `candidates` ordered nearest first; nil when it names none of them. Used to tell apart sites
    /// close to each other. The site with the most of its name in the title wins, then the one with
    /// the fewest name words missing, then the nearest ("Cirkewwa" names four sites).
    static func site(namedIn title: String, among candidates: [DiveSite]) -> DiveSite? {
        let titleWords = normalize(title).split(separator: " ").map(String.init)
        guard !titleWords.isEmpty else { return nil }
        var best: (site: DiveSite, found: Int, missing: Int)?
        for site in candidates {
            let nameWords = normalize(site.name).split(separator: " ").map(String.init)
            let found = nameWords.filter { word in
                titleWords.contains { wholeWordTypos(word, $0) <= allowedTypos(word) }
            }
            // "reef" or "cave" alone in a title doesn't name a site.
            guard found.contains(where: { !genericWords.contains($0) }) else { continue }
            let missing = nameWords.count - found.count
            if best == nil || found.count > best!.found || (found.count == best!.found && missing < best!.missing) {
                best = (site, found.count, missing)
            }
        }
        return best?.site
    }

    /// Words in many site names, which don't say which site is meant on their own.
    private static let genericWords: Set<String> = [
        "reef", "cave", "caves", "point", "bay", "arch", "rock", "tunnel", "wreck", "statue", "beach",
        "pool", "boat", "tug", "left", "right", "north", "south", "east", "west", "outer", "the", "of",
        "and", "il", "ta", "tal", "tax", "ix", "ir", "l", "mv", "mt", "hms", "ss", "st",
    ]

    private static func allowedTypos(_ word: String) -> Int {
        word.count <= 2 ? 0 : word.count <= 5 ? 1 : 2
    }

    /// Typos between a query word and a name word it may be the start of: the fewest edits to turn
    /// the query word into the name word or into its start of about the same length.
    private static func typos(_ word: String, _ nameWord: String) -> Int {
        let previous = distances(word, nameWord)
        // A prefix of the name word at least as long as the query word, minus a missed letter.
        let from = max(0, word.count - 1)
        return from < previous.count ? previous[from...].min()! : previous.last!
    }

    /// Typos between two whole words.
    private static func wholeWordTypos(_ a: String, _ b: String) -> Int {
        distances(a, b).last!
    }

    /// The typos between `word` and each start of `other` (index = its length).
    private static func distances(_ word: String, _ other: String) -> [Int] {
        let a = Array(word), b = Array(other)
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
        return previous
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
