# CitizenNews SEO gateway

Flutter Web updates metadata in the browser, but many link-preview crawlers do not
execute Flutter JavaScript. This dependency-free Node 20+ gateway reads approved
content from Supabase public views and returns request-specific HTML before the
Flutter app starts.

It provides:

- unique canonical, Open Graph and X card tags for every public URL;
- `NewsArticle`, `ProfilePage` and `CollectionPage` JSON-LD;
- semantic server HTML for approved stories;
- correct `404` and `X-Robots-Tag` responses;
- dynamic paged sitemaps sourced from `public_news`, locations, categories and
  `public_reporters`;
- `noindex` for authentication, account, chat, reporter workspace and admin URLs.

## Environment

Set these variables in the Node/Cloud Run/Firebase Functions environment:

```text
WEB_BASE_URL=https://your-production-domain.com
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-public-publishable-or-anon-key
FLUTTER_WEB_ROOT=build/web
PORT=8080
```

Only the public Supabase key is required. The gateway deliberately queries
`public_news` and `public_reporters`; never put the service-role key here.

Build Flutter Web with the same canonical origin, then start the gateway from the
project root:

```powershell
flutter build web --release --dart-define-from-file=config.json --dart-define=WEB_BASE_URL=https://your-production-domain.com
node tool/seo_gateway/server.mjs
```

Production traffic must point to this Node service rather than directly to the
static `build/web` folder. The static `web/robots.txt` and `web/sitemap.xml` are
safe fallbacks; the gateway versions are dynamic and should be submitted in
Google Search Console as `https://your-production-domain.com/sitemap.xml`.
