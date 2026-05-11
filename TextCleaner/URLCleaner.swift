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

        if let items = components.queryItems, !items.isEmpty {
            let kept = items.filter { !shouldStrip(name: $0.name, host: host) }
            components.queryItems = kept.isEmpty ? nil : kept
        }

        return components.url?.absoluteString
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
            return ["ref", "_encoding", "psc", "smid", "th", "ie",
                    "sprefix", "crid", "sr", "qid", "keywords",
                    "content-id", "language", "currency", "tag",
                    "rdc", "linkcode"]
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
