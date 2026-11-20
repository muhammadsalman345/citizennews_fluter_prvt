# CitizenNews web SEO and Google indexing

## Data flow

The database is the single source of truth. No reporter has to enter the same
SEO information twice.

| SEO output | Supabase source |
| --- | --- |
| Permanent URL | approved `public_news.slug` |
| Search/social title | `public_news.headline` |
| Search description | `public_news.summary` |
| Social preview image | `public_image_urls`, then `public_image_url` |
| Author/profile | `full_name`, `username`, `public_reporters` |
| Article dates | `published_at`, `updated_at` |
| Topic/location | category, country, region and city fields |

Only posts available through `public_news` are emitted in article HTML and the
sitemap. Draft, pending, rejected and private content must remain excluded by
the database view/RLS policy.

## What runs where

- Flutter updates title, canonical, robots, Open Graph, X Card and JSON-LD when
  users navigate inside the web app.
- `tool/seo_gateway/server.mjs` returns the same metadata and readable article
  HTML in the first HTTP response. This is the production endpoint for Google
  and social preview crawlers.
- The gateway generates `/robots.txt`, `/sitemap.xml` and paged database-backed
  sitemaps. Private routes also receive an `X-Robots-Tag: noindex` header.

Serving only the static Flutter folder is not enough for reliable per-post link
previews. Production web traffic must go through the gateway.

## Before web release

1. Choose one HTTPS production domain. Use it everywhere as `WEB_BASE_URL` and
   redirect every alternate host to it.
2. Build Flutter Web using that exact origin.
3. Deploy the Node gateway to a Node 20+ host such as Cloud Run. The included
   Dockerfile expects `build/web` to exist before the container is built.
4. Configure the public Supabase URL and publishable key. Never use a service
   role key in this public web service.
5. Confirm these responses on the production domain:
   - `/robots.txt` is plain text and references the production sitemap.
   - `/sitemap.xml` is an XML sitemap index.
   - `/news/a-real-slug` source contains that post's canonical, Open Graph tags,
     `NewsArticle` JSON-LD and readable headline/body.
   - a missing story returns HTTP 404.
   - `/account` returns `X-Robots-Tag: noindex`.

## Google Search Console

1. Add and verify a Domain property for the final domain.
2. Submit only `https://FINAL-DOMAIN/sitemap.xml` under Sitemaps.
3. Inspect the home page and a real published `/news/...` URL.
4. Run the live URL test, then request indexing for a small sample. The sitemap
   handles discovery for the rest; manual requests are not needed for every post.
5. Monitor Page indexing, HTTPS, Core Web Vitals and structured-data reports.

Indexing is Google's decision, not an instant guarantee. Unique useful content,
correct 200/404 status codes, internal links, one canonical domain and a clean
sitemap give every approved post the correct technical path to indexing.
