package nl.petervanmanen.divemalta

import java.text.Normalizer

/**
 * Typo-tolerant search over the dive sites, for the map's search bar and the site list. Same rules
 * as SiteSearch.swift on iOS.
 *
 * Names and query are compared without accents, case and punctuation ("ghar lapsi" finds Għar
 * Lapsi, "zurrieq" Żurrieq), every query word must match a word of the name, as its start or with a
 * typo or two ("cirkewa", "um el farud"), and a site type finds its sites ("wreck").
 */
object SiteSearch {
    fun results(query: String, sites: List<DiveSite>): List<DiveSite> {
        val words = normalize(query).split(" ").filter { it.isNotEmpty() }
        if (words.isEmpty()) return sites
        return sites.mapNotNull { site -> score(words, site)?.let { site to it } }
            .sortedWith(compareByDescending<Pair<DiveSite, Int>> { it.second }.thenBy { it.first.name })
            .map { it.first }
    }

    /** Higher is better; null = no match. */
    private fun score(query: List<String>, site: DiveSite): Int? {
        val name = normalize(site.name)
        val joined = query.joinToString(" ")
        if (name == joined) return 1100
        if (name.startsWith(joined)) return 1000
        val nameWords = name.split(" ")
        // Typed without spaces ("umelfaroud") or with them where the name has none.
        val compact = query.joinToString("")
        if (compact.length >= 3 && name.replace(" ", "").contains(compact)) return 900

        var total = 0
        var startsAtFirstWord = false
        for ((i, word) in query.withIndex()) {
            val best = nameWords.indices.map { it to typos(word, nameWords[it]) }.minByOrNull { it.second }
            if (best == null || best.second > allowedTypos(word)) {
                // Not in the name: maybe the type ("wreck", "caves").
                val type = site.type ?: return null
                if (typos(word, normalize(type)) > allowedTypos(word)) return null
                total += 1
                continue
            }
            if (i == 0 && best.first == 0) startsAtFirstWord = true
            total += best.second
        }
        return 800 - total * 100 + if (startsAtFirstWord) 50 else 0
    }

    /**
     * The site a dive's title names ("Cirkewwa right arch", "ghar lapsi finger reef"), out of
     * [candidates] ordered nearest first; null when it names none of them. Used to tell apart sites
     * close to each other. The site with the most of its name in the title wins, then the one with
     * the fewest name words missing, then the nearest ("Cirkewwa" names four sites).
     */
    fun siteNamedIn(title: String, candidates: List<DiveSite>): DiveSite? {
        val titleWords = normalize(title).split(" ").filter { it.isNotEmpty() }
        if (titleWords.isEmpty()) return null
        var best: DiveSite? = null
        var bestFound = 0
        var bestMissing = 0
        for (site in candidates) {
            val nameWords = normalize(site.name).split(" ")
            val found = nameWords.filter { word -> titleWords.any { wholeWordTypos(word, it) <= allowedTypos(word) } }
            // "reef" or "cave" alone in a title doesn't name a site.
            if (found.none { it !in genericWords }) continue
            val missing = nameWords.size - found.size
            if (best == null || found.size > bestFound || (found.size == bestFound && missing < bestMissing)) {
                best = site; bestFound = found.size; bestMissing = missing
            }
        }
        return best
    }

    /** Words in many site names, which don't say which site is meant on their own. */
    private val genericWords = setOf(
        "reef", "cave", "caves", "point", "bay", "arch", "rock", "tunnel", "wreck", "statue", "beach",
        "pool", "boat", "tug", "left", "right", "north", "south", "east", "west", "outer", "the", "of",
        "and", "il", "ta", "tal", "tax", "ix", "ir", "l", "mv", "mt", "hms", "ss", "st",
    )

    private fun allowedTypos(word: String) = if (word.length <= 2) 0 else if (word.length <= 5) 1 else 2

    /**
     * Typos between a query word and a name word it may be the start of: the fewest edits to turn
     * the query word into the name word or into its start of about the same length.
     */
    private fun typos(word: String, nameWord: String): Int {
        val previous = distances(word, nameWord)
        // A prefix of the name word at least as long as the query word, minus a missed letter.
        val from = maxOf(0, word.length - 1)
        return if (from < previous.size) previous.drop(from).min() else previous.last()
    }

    /** Typos between two whole words. */
    private fun wholeWordTypos(a: String, b: String) = distances(a, b).last()

    /** The typos between [word] and each start of [other] (index = its length). */
    private fun distances(word: String, other: String): IntArray {
        val a = word; val b = other
        // Damerau-Levenshtein (optimal string alignment), keeping the whole last row so any prefix
        // of the name word can be the target.
        var previous2 = IntArray(0)
        var previous = IntArray(b.length + 1) { it }
        for (i in 1..a.length) {
            val row = IntArray(b.length + 1).also { it[0] = i }
            for (j in 1..b.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                row[j] = minOf(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + cost)
                if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
                    row[j] = minOf(row[j], previous2[j - 2] + 1)
                }
            }
            previous2 = previous
            previous = row
        }
        return previous
    }

    /** Lowercase, without accents (ħ → h, ż → z), apostrophes dropped and other punctuation as spaces. */
    fun normalize(text: String): String {
        val folded = Normalizer.normalize(text.lowercase().replace("ħ", "h"), Normalizer.Form.NFD)
            .replace(Regex("\\p{M}"), "")
            .replace("'", "").replace("’", "")
        return folded.map { if (it.isLetterOrDigit()) it else ' ' }.joinToString("")
            .split(" ").filter { it.isNotEmpty() }.joinToString(" ")
    }
}
