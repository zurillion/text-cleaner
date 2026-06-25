import Foundation

/// Strips tracking parameters from URLs while preserving the parts that
/// actually identify a resource (path, fragment, content-bearing query
/// parameters like YouTube's `v=` or Twitter's status path).
///
/// The cleaner detects URLs anywhere in the input string with `NSDataDetector`
/// and rewrites each one in place, so it works equally well on a clipboard
/// containing just a URL or a message with an embedded URL.
enum URLCleaner {

    // MARK: - Public

    static func clean(_ input: String) -> String {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else {
            return input
        }

        let ns = input as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = detector.matches(in: input, options: [], range: fullRange)
        guard !matches.isEmpty else { return input }

        var result = ""
        result.reserveCapacity(input.count)
        var cursor = 0

        for match in matches {
            if match.range.location > cursor {
                let chunk = ns.substring(with: NSRange(
                    location: cursor,
                    length: match.range.location - cursor
                ))
                result.append(chunk)
            }
            let original = ns.substring(with: match.range)
            result.append(cleanSingle(original) ?? original)
            cursor = match.range.location + match.range.length
        }

        if cursor < ns.length {
            let tail = ns.substring(with: NSRange(
                location: cursor,
                length: ns.length - cursor
            ))
            result.append(tail)
        }
        return result
    }

    // MARK: - Per-URL cleaning

    private static func cleanSingle(_ urlString: String) -> String? {
        guard var components = URLComponents(string: urlString),
              let host = components.host?.lowercased(),
              !host.isEmpty
        else { return nil }

        // Facebook group "multi-permalinks" feed links bury the post id in
        // a query parameter instead of the path. Rebuild the canonical
        // direct link before generic stripping — this is purely
        // reconstructive (the id is already in hand), no network needed.
        if let rebuilt = reconstructFacebookGroupPost(components, host: host) {
            return rebuilt
        }

        // Amazon product pages canonicalise to `/dp/<ASIN>` regardless of
        // how the user reached them. The slug prefix
        // (/Pacchetti-Compatibile-Motorhead-…) and the /ref=sr_1_7 path
        // suffix are decoration/tracking that Amazon's router ignores, so
        // we can safely drop everything but the ASIN and rebuild a clean,
        // shareable URL.
        if let canonical = canonicalAmazonProductURL(components, host: host) {
            return canonical
        }

        if let items = components.queryItems, !items.isEmpty {
            let kept = items.filter { !shouldStrip(name: $0.name, host: host) }
            components.queryItems = kept.isEmpty ? nil : kept
        }

        return components.url?.absoluteString
    }

    // MARK: - Amazon product page canonicalisation

    /// Collapses any Amazon product URL to its canonical `/dp/<ASIN>`
    /// form, dropping the readable slug, any `/ref=…` tracking suffix on
    /// the path, and every query parameter. Recognised input shapes:
    ///   /dp/ASIN[/…]
    ///   /<slug>/dp/ASIN[/…]
    ///   /gp/product/ASIN[/…]
    ///   /gp/aw/d/ASIN[/…]            (mobile-style)
    /// Returns nil for any URL that isn't on an Amazon host or where the
    /// ASIN slot doesn't look like a valid 10-char alphanumeric ASIN; the
    /// caller then falls back to generic per-host query stripping (which
    /// still cleans non-product pages like search results).
    private static func canonicalAmazonProductURL(
        _ components: URLComponents,
        host: String
    ) -> String? {
        guard host.contains("amazon.") else { return nil }

        let parts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        var asin: String?
        if let idx = parts.firstIndex(of: "dp"), idx + 1 < parts.count {
            asin = parts[idx + 1]
        } else if let idx = parts.firstIndex(of: "gp"),
                  idx + 2 < parts.count,
                  parts[idx + 1] == "product" {
            asin = parts[idx + 2]
        } else if let idx = parts.firstIndex(of: "gp"),
                  idx + 3 < parts.count,
                  parts[idx + 1] == "aw",
                  parts[idx + 2] == "d" {
            asin = parts[idx + 3]
        }

        guard let asin = asin, isLikelyASIN(asin) else { return nil }

        var canonical = URLComponents()
        canonical.scheme = components.scheme ?? "https"
        canonical.host = components.host
        canonical.path = "/dp/\(asin)"
        return canonical.url?.absoluteString
    }

    /// ASINs are exactly 10 ASCII alphanumeric characters. Be strict so a
    /// /dp/<something-else> URL (which shouldn't happen, but we don't
    /// want to corrupt) is left alone for the generic path.
    private static func isLikelyASIN(_ s: String) -> Bool {
        guard s.count == 10 else { return false }
        return s.unicodeScalars.allSatisfy { scalar in
            let v = scalar.value
            return (v >= 48 && v <= 57)   // 0-9
                || (v >= 65 && v <= 90)   // A-Z
                || (v >= 97 && v <= 122)  // a-z
        }
    }

    // MARK: - Facebook group post reconstruction

    /// Turns a Facebook group feed/notification link such as
    ///   facebook.com/groups/GROUP/?multi_permalinks=POST&notif_id=…&ref=…
    /// into the canonical direct link
    ///   https://www.facebook.com/groups/GROUP/posts/POST/
    ///
    /// The post id comes from `multi_permalinks` when present, otherwise
    /// from an existing `/permalink/ID` or `/posts/ID` path segment. All
    /// tracking junk in the query string is discarded by virtue of
    /// rebuilding the URL from scratch. Returns nil when the URL isn't a
    /// Facebook group post, so the caller falls back to generic cleaning.
    private static func reconstructFacebookGroupPost(
        _ components: URLComponents,
        host: String
    ) -> String? {
        guard host == "facebook.com" || host.hasSuffix(".facebook.com") else {
            return nil
        }

        guard let groupID = pathComponent(after: "groups", in: components.path) else {
            return nil
        }

        let postID = multiPermalinkPostID(in: components)
            ?? pathComponent(after: "permalink", in: components.path)
            ?? pathComponent(after: "posts", in: components.path)

        guard let post = postID, !post.isEmpty else { return nil }

        return "https://www.facebook.com/groups/\(groupID)/posts/\(post)/"
    }

    /// Reads the `multi_permalinks` (or singular `multi_permalink`) query
    /// value. The parameter can carry several comma-separated ids when the
    /// source notification bundled multiple posts; we take the first.
    private static func multiPermalinkPostID(in components: URLComponents) -> String? {
        guard let value = components.queryItems?.first(where: {
            $0.name.lowercased().hasPrefix("multi_permalink")
        })?.value, !value.isEmpty else {
            return nil
        }
        let first = value.split(separator: ",").first.map(String.init) ?? value
        return first.isEmpty ? nil : first
    }

    /// Returns the path segment immediately following `marker`, e.g. the
    /// group id in `/groups/123456/` for marker "groups". Empty segments
    /// (from leading/trailing/double slashes) are ignored.
    private static func pathComponent(after marker: String, in path: String) -> String? {
        let parts = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard let idx = parts.firstIndex(of: marker), idx + 1 < parts.count else {
            return nil
        }
        return parts[idx + 1]
    }

    private static func shouldStrip(name: String, host: String) -> Bool {
        let lower = name.lowercased()

        if universalExact.contains(lower) { return true }

        for prefix in universalPrefixes {
            if lower.hasPrefix(prefix) { return true }
        }

        if let domainParams = domainRules(for: host),
           domainParams.contains(lower) {
            return true
        }

        return false
    }

    // MARK: - Universal rules
    //
    // All sets/prefixes below are compared in lowercase.

    private static let universalExact: Set<String> = [
        // Ad platform click identifiers
        "fbclid",
        "gclid", "gclsrc", "dclid", "gbraid", "wbraid",
        "msclkid", "yclid", "twclid", "ttclid",
        "epik",         // Pinterest
        "sccid",        // Snapchat
        "li_fat_id",    // LinkedIn
        "obclid",       // Outbrain

        // Analytics
        "_gl", "_ga", "ga_source",
        "icid", "s_cid",

        // Email campaign IDs not caught by mc_/_hs/__hs prefixes
        "mkt_tok",
        "elqtrack", "elqtrackid", "elqaid", "elqat", "elqcampaignid",
        "hsctatracking",

        // Generic referer trackers
        "ref_src", "ref_url",
    ]

    private static let universalPrefixes: [String] = [
        "__mk_",       // Amazon localised marketplace marker
        "utm_",        // Google Analytics + everyone
        "__cft__",     // Facebook cookie/click fingerprint
        "__tn__",      // Facebook navigation tag
        "__eep__",     // Facebook
        "fb_",         // Facebook generic (fb_action_*, fb_source, …)
        "mc_",         // Mailchimp
        "_hs",         // Hubspot (_hsenc, _hsmi)
        "__hs",        // Hubspot (__hssc, __hstc, __hsfp)
        "pf_rd_",      // Amazon "promo from referrer destination"
        "pd_rd_",      // Amazon "product detail referrer destination"
        "spm_",        // Alibaba super-position model
        "vero_",       // Vero
        "trk_",        // LinkedIn (also see domain-specific)
        "sc_",         // Snapchat extension params
        "wt_",         // Webtrekk
        "pk_",         // Piwik
        "matomo_",     // Matomo (rebranded Piwik)
    ]

    // MARK: - Host-specific rules

    private static func domainRules(for host: String) -> Set<String>? {
        if matches(host, any: "twitter.com", "x.com") {
            return ["s", "t", "ref"]
        }
        if matches(host, any: "youtube.com") || host == "youtu.be" {
            // Preserve v, list, index, t (timestamp), start, end.
            return ["si", "feature", "ab_channel", "pp", "src_vid",
                    "themerefresh"]
        }
        if matches(host, any: "instagram.com") {
            return ["igshid", "igsh", "ig_rid"]
        }
        if matches(host, any: "linkedin.com") {
            return ["trackingid", "lipi", "licu", "midtoken", "midsig",
                    "originalsubdomain", "trk", "trkinfo", "refid"]
        }
        if matches(host, any: "tiktok.com") {
            return ["_t", "_r"]
        }
        if matches(host, any: "spotify.com") {
            return ["si"]
        }
        if matches(host, any: "reddit.com") {
            // utm_* already covered universally; Reddit also uses share_id.
            return ["share_id"]
        }
        if host.contains("amazon.") {
            // `dib` / `dib_tag` are the long encrypted breadcrumb tokens
            // Amazon adds when you arrive from search; pure tracking, no
            // semantic content. Locale params (`__mk_*`) come in via
            // accidental copy from a localised search results page.
            return ["ref", "_encoding", "psc", "smid", "th", "ie",
                    "sprefix", "crid", "sr", "qid", "keywords",
                    "content-id", "language", "currency", "tag",
                    "rdc", "linkcode", "dib", "dib_tag"]
        }
        return nil
    }

    private static func matches(_ host: String, any domains: String...) -> Bool {
        for domain in domains {
            if host == domain || host.hasSuffix("." + domain) { return true }
        }
        return false
    }
}
