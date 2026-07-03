import DotsEngine
import Testing

@Suite("ArticleExtractor")
struct ArticleExtractorTests {
    private static let page = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Fallback Title — Example</title>
      <meta property="og:title" content="Attention &amp; Focus">
      <meta property="og:site_name" content="Example Blog">
      <meta content="Jane Doe" name="author">
      <script>var tracking = "junk";</script>
      <style>body { color: red; }</style>
    </head>
    <body>
      <nav><a href="/">Home</a><a href="/about">About</a></nav>
      <header><h1>Site Banner</h1></header>
      <article class="post">
        <h1>Attention &amp; Focus</h1>
        <p>Deep work beats shallow work&#8230;</p>
        <h2>Why it matters</h2>
        <p>It&#39;s the difference between <em>doing</em> and dabbling.</p>
        <ul>
          <li>Guard the morning</li>
          <li>Batch the rest</li>
        </ul>
        <blockquote><p>The mind is a muscle.</p></blockquote>
        <figure><img src="x.png"><figcaption>ignore me</figcaption></figure>
      </article>
      <aside>Related links</aside>
      <footer>&copy; 2026 Example</footer>
      <script>more.junk()</script>
    </body>
    </html>
    """

    @Test("Extracts metadata and structured text from a realistic page")
    func realisticPage() {
        let extraction = ArticleExtractor.extract(html: Self.page)

        #expect(extraction.title == "Attention & Focus")
        #expect(extraction.author == "Jane Doe")
        #expect(extraction.site == "Example Blog")

        #expect(extraction.text.contains("# Attention & Focus"))
        #expect(extraction.text.contains("## Why it matters"))
        #expect(extraction.text.contains("- Guard the morning"))
        #expect(extraction.text.contains("- Batch the rest"))
        #expect(extraction.text.contains("> The mind is a muscle."))
        #expect(extraction.text.contains("Deep work beats shallow work\u{2026}"))
        #expect(extraction.text.contains("It's the difference between doing and dabbling."))
    }

    @Test("Junk blocks never leak into the text")
    func junkStripped() {
        let text = ArticleExtractor.extract(html: Self.page).text

        #expect(!text.contains("Site Banner"))
        #expect(!text.contains("Home"))
        #expect(!text.contains("tracking"))
        #expect(!text.contains("color: red"))
        #expect(!text.contains("Related links"))
        #expect(!text.contains("ignore me"))
    }

    @Test("Reads meta tags with either attribute order and either quote style")
    func metaAttributeOrders() {
        let propertyFirst = ArticleExtractor.extract(
            html: #"<head><meta property="og:title" content="First"></head><body>x</body>"#
        )
        #expect(propertyFirst.title == "First")

        let contentFirst = ArticleExtractor.extract(
            html: #"<head><meta content="Second" property="og:title"></head><body>x</body>"#
        )
        #expect(contentFirst.title == "Second")

        let singleQuoted = ArticleExtractor.extract(
            html: "<head><meta name='author' content='Ada Lovelace'></head><body>x</body>"
        )
        #expect(singleQuoted.author == "Ada Lovelace")
    }

    @Test("Falls back to the title tag when og:title is absent")
    func titleFallback() {
        let extraction = ArticleExtractor.extract(
            html: "<html><head><title>Plain &amp; Simple</title></head><body>Hello</body></html>"
        )

        #expect(extraction.title == "Plain & Simple")
    }

    @Test("Decodes decimal and hex numeric entities")
    func numericEntities() {
        let text = ArticleExtractor.extract(
            html: "<body><p>A&#8212;B and C&#x2014;D and quote&#39;s</p></body>"
        ).text

        #expect(text == "A\u{2014}B and C\u{2014}D and quote's")
    }

    @Test("Escaped markup in prose survives tag stripping as text")
    func escapedMarkupSurvives() {
        let text = ArticleExtractor.extract(
            html: "<body><p>Wrap it in a &lt;div&gt; element.</p></body>"
        ).text

        #expect(text == "Wrap it in a <div> element.")
    }

    @Test("Falls back to main, then body, then the whole document")
    func scopeFallbacks() {
        let main = ArticleExtractor.extract(html: "<body><nav>Menu</nav><main><p>Main text.</p></main></body>")
        #expect(main.text == "Main text.")

        let body = ArticleExtractor.extract(html: "<html><body><p>Body text.</p><footer>Junk</footer></body></html>")
        #expect(body.text == "Body text.")

        let bare = ArticleExtractor.extract(html: "<p>Bare text.</p>")
        #expect(bare.text == "Bare text.")
    }
}
