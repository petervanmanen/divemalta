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

    private fun allowedTypos(word: String) = if (word.length <= 2) 0 else if (word.length <= 5) 1 else 2

    /**
     * Typos between a query word and a name word it may be the start of: the fewest edits to turn
     * the query word into the name word or into its start of about the same length.
     */
    private fun typos(word: String, nameWord: String): Int {
        val a = word; val b = nameWord
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
        // A prefix of the name word at least as long as the query word, minus a missed letter.
        val from = maxOf(0, a.length - 1)
        return if (from <= b.length) previous.drop(from).min() else previous[b.length]
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
