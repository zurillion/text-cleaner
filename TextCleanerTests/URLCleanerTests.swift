import XCTest
@testable import TextCleaner

final class URLCleanerTests: XCTestCase {

    // MARK: - Facebook group multi-permalinks reconstruction

    func testFacebookMultiPermalinksRebuild() {
        let input = "https://www.facebook.com/groups/123456/?multi_permalinks=987654321&notif_id=abc&notif_t=def&ref=ghi"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.facebook.com/groups/123456/posts/987654321/"
        )
    }

    func testFacebookMultiPermalinksCommaBundleTakesFirst() {
        // Notifications occasionally bundle several post ids; we pick the first.
        let input = "https://www.facebook.com/groups/123456/?multi_permalinks=111,222,333&ref=feed"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.facebook.com/groups/123456/posts/111/"
        )
    }

    func testFacebookPermalinkPathRebuild() {
        // The id is already on the path — we still rebuild to drop the
        // tracking junk in the query and normalise the URL form.
        let input = "https://www.facebook.com/groups/123456/permalink/987654321/?__cft__[0]=abc&__tn__=R"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.facebook.com/groups/123456/posts/987654321/"
        )
    }

    func testFacebookPostsPathRebuild() {
        let input = "https://www.facebook.com/groups/123456/posts/987654321/?ref=share&__cft__=foo"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.facebook.com/groups/123456/posts/987654321/"
        )
    }

    func testFacebookVanityGroupNameSurvives() {
        let input = "https://www.facebook.com/groups/swiftui-italia/?multi_permalinks=42&ref=feed"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.facebook.com/groups/swiftui-italia/posts/42/"
        )
    }

    func testFacebookMobileSubdomainNormalised() {
        // m.facebook.com → rebuilt as www.facebook.com.
        let input = "https://m.facebook.com/groups/123/?multi_permalinks=456&ref=feed"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.facebook.com/groups/123/posts/456/"
        )
    }

    func testFacebookGroupListPagePassesThrough() {
        // Plain group URL with no post id → reconstruction returns nil and
        // we fall through to the generic stripper, which only drops fbclid.
        let input = "https://www.facebook.com/groups/123456/?fbclid=zzz"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.facebook.com/groups/123456/"
        )
    }

    func testFacebookNonGroupURLUntouchedByRebuild() {
        // A profile / page URL has no /groups/ segment, so reconstruction
        // skips it and we just strip fbclid via the generic rules.
        let input = "https://www.facebook.com/someone/posts/12345?fbclid=zzz&__cft__[0]=abc"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.facebook.com/someone/posts/12345"
        )
    }

    // MARK: - Universal tracking strippers

    func testStripsUtmParameters() {
        let input = "https://example.com/article?utm_source=twitter&utm_medium=social&utm_campaign=spring&id=42"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://example.com/article?id=42"
        )
    }

    func testStripsAdClickIdentifiers() {
        let input = "https://example.com/path?fbclid=a&gclid=b&msclkid=c&yclid=d&keep=yes"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://example.com/path?keep=yes"
        )
    }

    func testRemovesAllParamsWhenNothingSurvives() {
        let input = "https://example.com/article?utm_source=foo&fbclid=bar"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://example.com/article"
        )
    }

    // MARK: - Host-specific rules

    func testYouTubePreservesPlaybackParamsAndStripsSi() {
        let input = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=trackme&t=42&feature=share"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42"
        )
    }

    func testTwitterStripsTrackingParams() {
        let input = "https://twitter.com/jack/status/20?s=20&t=abcdef&ref=feed"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://twitter.com/jack/status/20"
        )
    }

    func testAmazonStripsRefAndTag() {
        let input = "https://www.amazon.com/dp/B08L5VG843?ref=foo&tag=affiliate-20&pf_rd_x=bar"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "https://www.amazon.com/dp/B08L5VG843"
        )
    }

    // MARK: - Embedded URLs in surrounding text

    func testEmbeddedURLInProseIsCleanedInPlace() {
        let input = "Check this out: https://example.com/article?utm_source=foo&id=1 — cool, right?"
        XCTAssertEqual(
            URLCleaner.clean(input),
            "Check this out: https://example.com/article?id=1 — cool, right?"
        )
    }

    func testMultipleURLsAllCleaned() {
        let input = """
            First: https://a.com/x?utm_source=foo
            Second: https://b.com/y?fbclid=bar&keep=yes
            """
        XCTAssertEqual(URLCleaner.clean(input), """
            First: https://a.com/x
            Second: https://b.com/y?keep=yes
            """)
    }

    // MARK: - Pass-throughs

    func testURLWithoutTrackingIsUnchanged() {
        let input = "https://example.com/article?id=42&page=2"
        XCTAssertEqual(URLCleaner.clean(input), input)
    }

    func testPlainTextWithoutURLsIsUnchanged() {
        let input = "Hello world — no links here."
        XCTAssertEqual(URLCleaner.clean(input), input)
    }
}
