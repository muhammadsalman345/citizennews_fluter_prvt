import { createReadStream, existsSync, readFileSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, resolve, sep } from 'node:path';

const port = Number(process.env.PORT || 8080);
const siteUrl = (process.env.WEB_BASE_URL || 'https://vocal-territory-415310.web.app')
  .replace(/\/+$/, '');
const supabaseUrl = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
const supabaseKey = process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY || '';
const webRoot = resolve(process.env.FLUTTER_WEB_ROOT || 'build/web');
const indexPath = resolve(webRoot, 'index.html');
const defaultImage = `${siteUrl}/images/citizennews-og-default.png`;
const logo = `${siteUrl}/icons/Icon-512.png`;

const publicStatic = new Map([
  ['/', ['CitizenNews | Verified Local News', 'Discover verified local news, breaking stories and trusted citizen reporting from communities around the world.']],
  ['/latest', ['Latest News | CitizenNews', 'Read the latest verified stories on CitizenNews.']],
  ['/trending', ['Trending News | CitizenNews', 'See the stories readers are following now.']],
  ['/world', ['World News | CitizenNews', 'Explore verified citizen reporting from around the world.']],
  ['/explore', ['Explore Local News | CitizenNews', 'Find verified news by country, region, city and category.']],
  ['/reporters', ['Top Citizen Reporters | CitizenNews', 'Discover trusted CitizenNews reporters and their stories.']],
  ['/about', ['About CitizenNews', 'Learn how CitizenNews supports verified citizen reporting.']],
  ['/contact', ['Contact CitizenNews', 'Contact the CitizenNews support and editorial teams.']],
  ['/privacy', ['Privacy Policy | CitizenNews', 'Read the CitizenNews privacy policy.']],
  ['/terms', ['Terms of Service | CitizenNews', 'Read the CitizenNews terms of service.']],
  ['/community-guidelines', ['Community Guidelines | CitizenNews', 'Read the CitizenNews community standards.']],
  ['/editorial-policy', ['Editorial Policy | CitizenNews', 'Read the CitizenNews editorial and verification policy.']],
  ['/corrections-policy', ['Corrections Policy | CitizenNews', 'Learn how CitizenNews corrects published reports.']],
  ['/content-removal', ['Content Removal Policy | CitizenNews', 'Read the CitizenNews content removal process.']],
  ['/copyright', ['Copyright Policy | CitizenNews', 'Read the CitizenNews copyright policy.']],
]);
const privatePrefixes = [
  '/account', '/admin', '/analytics', '/appeals', '/comments', '/dashboard',
  '/following', '/forgot-password', '/login', '/messages', '/my-stories',
  '/otp', '/points', '/profile', '/report-news', '/reset-password', '/saved',
  '/search', '/settings', '/signup', '/verification', '/wallet', '/welcome',
];
const publicPrefixes = ['/news/', '/reporter/', '/country/', '/region/', '/city/', '/category/'];

const mimeTypes = {
  '.css': 'text/css; charset=utf-8', '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon', '.jpeg': 'image/jpeg', '.jpg': 'image/jpeg',
  '.js': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8', '.png': 'image/png',
  '.svg': 'image/svg+xml', '.txt': 'text/plain; charset=utf-8',
  '.wasm': 'application/wasm', '.webp': 'image/webp', '.xml': 'application/xml; charset=utf-8',
};

const esc = (value = '') => String(value).replace(/[&<>"']/g, (char) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
})[char]);
const xml = (value = '') => String(value).replace(/[<>&"']/g, (char) => ({
  '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;',
})[char]);
const clean = (value, max = 300) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
const absolute = (value) => {
  const path = clean(value, 2000);
  if (/^https?:\/\//i.test(path)) return path;
  return `${siteUrl}${path.startsWith('/') ? path : `/${path}`}`;
};
const jsonLd = (value) => JSON.stringify(value).replace(/</g, '\\u003c').replace(/-->/g, '--\\u003e');

function isPrivate(path) {
  return privatePrefixes.some((prefix) => path === prefix || path.startsWith(`${prefix}/`));
}

function isPublic(path) {
  return publicStatic.has(path) || publicPrefixes.some((prefix) => path.startsWith(prefix));
}

function headers(res, path) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(self), geolocation=(self), microphone=()');
  if (!path.includes('.') && !isPublic(path)) {
    res.setHeader('X-Robots-Tag', 'noindex, nofollow, noarchive');
  }
}

async function rest(table, params = {}) {
  if (!supabaseUrl || !supabaseKey) return [];
  const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== '') url.searchParams.set(key, value);
  }
  const response = await fetch(url, {
    headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` },
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) throw new Error(`Supabase ${table} request failed (${response.status})`);
  return response.json();
}

async function countRows(table, filters = {}) {
  if (!supabaseUrl || !supabaseKey) return 0;
  const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
  url.searchParams.set('select', 'id');
  url.searchParams.set('limit', '1');
  for (const [key, value] of Object.entries(filters)) url.searchParams.set(key, value);
  const response = await fetch(url, {
    headers: {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      Prefer: 'count=exact',
      Range: '0-0',
    },
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) throw new Error(`Supabase ${table} count failed (${response.status})`);
  return Number(response.headers.get('content-range')?.split('/').pop() || 0);
}

function baseSchema() {
  return {
    '@context': 'https://schema.org', '@type': 'Organization', name: 'CitizenNews',
    url: `${siteUrl}/`, logo, description: 'Verified local news and trusted citizen reporting.',
  };
}

function metadata({ title, description, path, type = 'website', image = defaultImage,
  imageAlt, robots = 'index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1',
  author, publishedAt, modifiedAt, schemas = [baseSchema()], bodyHtml = '' }) {
  const canonical = absolute(path);
  const safeTitle = clean(title, 120) || 'CitizenNews';
  const safeDescription = clean(description, 320) || 'Verified local news and trusted citizen reporting.';
  const safeImage = absolute(image || defaultImage);
  const tags = [
    `<title>${esc(safeTitle)}</title>`,
    `<link rel="canonical" href="${esc(canonical)}">`,
    `<meta name="description" content="${esc(safeDescription)}">`,
    `<meta name="robots" content="${esc(robots)}">`,
    `<meta name="googlebot" content="${esc(robots)}">`,
    author ? `<meta name="author" content="${esc(author)}">` : '',
    '<meta property="og:site_name" content="CitizenNews">',
    `<meta property="og:type" content="${esc(type)}">`,
    '<meta property="og:locale" content="en_US">',
    `<meta property="og:title" content="${esc(safeTitle)}">`,
    `<meta property="og:description" content="${esc(safeDescription)}">`,
    `<meta property="og:url" content="${esc(canonical)}">`,
    `<meta property="og:image" content="${esc(safeImage)}">`,
    `<meta property="og:image:secure_url" content="${esc(safeImage)}">`,
    `<meta property="og:image:alt" content="${esc(imageAlt || safeTitle)}">`,
    '<meta name="twitter:card" content="summary_large_image">',
    `<meta name="twitter:title" content="${esc(safeTitle)}">`,
    `<meta name="twitter:description" content="${esc(safeDescription)}">`,
    `<meta name="twitter:image" content="${esc(safeImage)}">`,
    `<meta name="twitter:image:alt" content="${esc(imageAlt || safeTitle)}">`,
    publishedAt ? `<meta property="article:published_time" content="${esc(publishedAt)}">` : '',
    modifiedAt ? `<meta property="article:modified_time" content="${esc(modifiedAt)}">` : '',
    author && type === 'article' ? `<meta property="article:author" content="${esc(author)}">` : '',
    ...schemas.map((schema) => `<script type="application/ld+json" data-citizennews-seo>${jsonLd(schema)}</script>`),
  ].filter(Boolean).join('\n  ');
  return { tags, bodyHtml: bodyHtml || `<main><h1>${esc(safeTitle)}</h1><p>${esc(safeDescription)}</p></main>` };
}

function bodyText(body) {
  const values = [];
  const walk = (node) => {
    if (!node) return;
    if (typeof node === 'string') values.push(node);
    else if (Array.isArray(node)) node.forEach(walk);
    else if (typeof node === 'object') {
      if (typeof node.text === 'string') values.push(node.text);
      if (node.content) walk(node.content);
    }
  };
  walk(body);
  return clean(values.join(' '), 12000);
}

async function routeMetadata(path) {
  if (isPrivate(path)) return metadata({
    title: 'CitizenNews', description: 'Secure CitizenNews account page.', path,
    robots: 'noindex, nofollow, noarchive', schemas: [],
  });
  const staticPage = publicStatic.get(path);
  if (staticPage) {
    const schemas = path === '/' ? [baseSchema(), {
      '@context': 'https://schema.org', '@type': 'WebSite', name: 'CitizenNews', url: `${siteUrl}/`,
    }] : [baseSchema()];
    return metadata({ title: staticPage[0], description: staticPage[1], path, schemas });
  }

  const articleMatch = path.match(/^\/news\/([^/]+)$/);
  if (articleMatch) {
    const slug = decodeURIComponent(articleMatch[1]);
    const rows = await rest('public_news', { select: '*', slug: `eq.${slug}`, limit: '1' });
    const post = rows[0];
    if (!post) return null;
    const title = clean(post.headline, 120);
    const description = clean(post.summary, 320);
    const images = Array.isArray(post.public_image_urls) && post.public_image_urls.length
      ? post.public_image_urls.map(absolute)
      : [absolute(post.public_image_url || defaultImage)];
    const canonical = `${siteUrl}/news/${encodeURIComponent(post.slug)}`;
    const reporterUrl = post.username ? `${siteUrl}/reporter/${encodeURIComponent(post.username)}` : undefined;
    const schema = {
      '@context': 'https://schema.org', '@type': 'NewsArticle', '@id': `${canonical}#article`,
      mainEntityOfPage: { '@type': 'WebPage', '@id': canonical }, url: canonical,
      headline: title, description, image: images,
      ...(post.published_at ? { datePublished: post.published_at } : {}),
      ...(post.updated_at ? { dateModified: post.updated_at } : {}),
      author: { '@type': 'Person', name: post.full_name || 'Citizen reporter', ...(reporterUrl ? { url: reporterUrl } : {}) },
      publisher: { '@type': 'Organization', name: 'CitizenNews', url: `${siteUrl}/`, logo: { '@type': 'ImageObject', url: logo } },
      ...(post.category ? { articleSection: post.category } : {}),
      ...(post.city ? { contentLocation: { '@type': 'City', name: post.city } } : {}),
      isAccessibleForFree: true,
    };
    const storyText = bodyText(post.body);
    const articleBody = `<article><header><h1>${esc(title)}</h1><p>${esc(description)}</p><p>By ${esc(post.full_name || 'Citizen reporter')}${post.published_at ? ` · <time datetime="${esc(post.published_at)}">${esc(new Date(post.published_at).toLocaleDateString('en-US'))}</time>` : ''}</p></header>${images[0] ? `<img src="${esc(images[0])}" alt="${esc(title)}">` : ''}${storyText ? `<p>${esc(storyText)}</p>` : ''}</article>`;
    return metadata({ title: `${title} | CitizenNews`, description, path, type: 'article',
      image: images[0], imageAlt: title, author: post.full_name || 'Citizen reporter',
      publishedAt: post.published_at, modifiedAt: post.updated_at, schemas: [schema], bodyHtml: articleBody });
  }

  const reporterMatch = path.match(/^\/reporter\/([^/]+)$/);
  if (reporterMatch) {
    const username = decodeURIComponent(reporterMatch[1]).replace(/^@/, '');
    const rows = await rest('public_reporters', {
      select: 'id,full_name,username,avatar_url,bio', username: `eq.${username}`, limit: '1',
    });
    const reporter = rows[0];
    if (!reporter) return null;
    const title = `${reporter.full_name} (@${reporter.username}) | CitizenNews`;
    const description = clean(reporter.bio, 320) || `Read verified local reports published by ${reporter.full_name} on CitizenNews.`;
    const url = `${siteUrl}/reporter/${encodeURIComponent(reporter.username)}`;
    const schema = {
      '@context': 'https://schema.org', '@type': 'ProfilePage', '@id': `${url}#profile`, url,
      name: `${reporter.full_name} on CitizenNews`, description,
      mainEntity: { '@type': 'Person', name: reporter.full_name, alternateName: `@${reporter.username}`,
        url, ...(reporter.avatar_url ? { image: reporter.avatar_url } : {}) },
    };
    return metadata({ title, description, path, type: 'profile', image: reporter.avatar_url || defaultImage,
      imageAlt: `${reporter.full_name} on CitizenNews`, author: reporter.full_name, schemas: [schema] });
  }

  const scoped = [
    { regex: /^\/country\/([^/]+)$/, table: 'countries', label: 'Country', slugGroup: 1 },
    { regex: /^\/region\/([^/]+)\/([^/]+)$/, table: 'regions', label: 'Region', countryGroup: 1, slugGroup: 2 },
    { regex: /^\/city\/([^/]+)\/([^/]+)$/, table: 'cities', label: 'City', countryGroup: 1, slugGroup: 2 },
    { regex: /^\/category\/([^/]+)$/, table: 'categories', label: 'Category', slugGroup: 1 },
  ].find((entry) => entry.regex.test(path));
  if (scoped) {
    const match = path.match(scoped.regex);
    const slug = decodeURIComponent(match[scoped.slugGroup]);
    const country = scoped.countryGroup ? decodeURIComponent(match[scoped.countryGroup]) : '';
    const rows = await rest(scoped.table, {
      select: country ? 'name,slug,countries!inner(slug)' : 'name,slug',
      slug: `eq.${slug}`,
      ...(country ? { 'countries.slug': `eq.${country}` } : {}),
      limit: '1',
    });
    const row = rows[0];
    if (!row) return null;
    const title = `${row.name} News | CitizenNews`;
    const description = `Read verified local and breaking ${scoped.label.toLowerCase()} news for ${row.name} on CitizenNews.`;
    return metadata({ title, description, path, schemas: [{
      '@context': 'https://schema.org', '@type': 'CollectionPage', name: title,
      description, url: absolute(path), isPartOf: { '@type': 'WebSite', name: 'CitizenNews', url: `${siteUrl}/` },
    }] });
  }
  return null;
}

function renderIndex(seo) {
  if (!existsSync(indexPath)) throw new Error(`Flutter web build not found at ${indexPath}`);
  let html = readFileSync(indexPath, 'utf8');
  html = html.replace(/<!-- CITIZENNEWS_SEO_START -->[\s\S]*?<!-- CITIZENNEWS_SEO_END -->/, `<!-- CITIZENNEWS_SEO_START -->\n  ${seo.tags}\n  <!-- CITIZENNEWS_SEO_END -->`);
  const prerender = `<div id="citizennews-prerender" style="max-width:900px;margin:32px auto;padding:24px;font:16px/1.6 Arial,sans-serif;color:#101828">${seo.bodyHtml}</div><script>window.addEventListener('flutter-first-frame',()=>document.getElementById('citizennews-prerender')?.remove(),{once:true});</script>`;
  return html.replace('<!-- CITIZENNEWS_PRERENDER -->', prerender);
}

const sitemapEntries = {
  news: { table: 'public_news', select: 'id,slug,updated_at,published_at', path: (r) => `/news/${encodeURIComponent(r.slug)}`, lastmod: (r) => r.updated_at || r.published_at },
  countries: { table: 'countries', select: 'id,slug', filters: { active: 'eq.true' }, path: (r) => `/country/${encodeURIComponent(r.slug)}` },
  regions: { table: 'regions', select: 'id,slug,countries!inner(slug)', path: (r) => `/region/${encodeURIComponent(r.countries.slug)}/${encodeURIComponent(r.slug)}` },
  cities: { table: 'cities', select: 'id,slug,countries!inner(slug)', filters: { active: 'eq.true' }, path: (r) => `/city/${encodeURIComponent(r.countries.slug)}/${encodeURIComponent(r.slug)}` },
  categories: { table: 'categories', select: 'id,slug', filters: { active: 'eq.true' }, path: (r) => `/category/${encodeURIComponent(r.slug)}` },
  reporters: { table: 'public_reporters', select: 'id,username', path: (r) => `/reporter/${encodeURIComponent(r.username)}` },
};
const staticPaths = [...publicStatic.keys()];

function urlset(rows) {
  return `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${rows.map((row) => `<url><loc>${xml(siteUrl + row.path)}</loc>${row.lastmod ? `<lastmod>${xml(new Date(row.lastmod).toISOString())}</lastmod>` : ''}</url>`).join('')}</urlset>`;
}

async function sitemapIndex() {
  const paths = ['/sitemaps/static/0.xml'];
  for (const [kind, entry] of Object.entries(sitemapEntries)) {
    const count = await countRows(entry.table, entry.filters || {});
    for (let page = 0; page < Math.ceil(count / 1000); page += 1) paths.push(`/sitemaps/${kind}/${page}.xml`);
  }
  return `<?xml version="1.0" encoding="UTF-8"?><sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${paths.map((path) => `<sitemap><loc>${xml(siteUrl + path)}</loc></sitemap>`).join('')}</sitemapindex>`;
}

async function sitemapPage(kind, page) {
  if (kind === 'static' && page === 0) return urlset(staticPaths.map((path) => ({ path })));
  const entry = sitemapEntries[kind];
  if (!entry || !Number.isInteger(page) || page < 0) return null;
  const rows = await rest(entry.table, {
    select: entry.select, ...(entry.filters || {}), order: 'id.asc', offset: String(page * 1000), limit: '1000',
  });
  return urlset(rows.map((row) => ({ path: entry.path(row), lastmod: entry.lastmod?.(row) })));
}

function serveFile(res, requestPath) {
  let decoded;
  try { decoded = decodeURIComponent(requestPath); } catch { return false; }
  const candidate = resolve(webRoot, `.${decoded}`);
  if (candidate !== webRoot && !candidate.startsWith(`${webRoot}${sep}`)) return false;
  if (!existsSync(candidate) || !statSync(candidate).isFile()) return false;
  res.statusCode = 200;
  res.setHeader('Content-Type', mimeTypes[extname(candidate).toLowerCase()] || 'application/octet-stream');
  res.setHeader('Cache-Control', decoded === '/flutter_service_worker.js' ? 'no-cache' : 'public, max-age=31536000, immutable');
  createReadStream(candidate).pipe(res);
  return true;
}

createServer(async (req, res) => {
  const url = new URL(req.url || '/', siteUrl);
  const path = url.pathname.replace(/\/+$/, '') || '/';
  headers(res, path);
  try {
    if (path === '/robots.txt') {
      res.setHeader('Content-Type', 'text/plain; charset=utf-8');
      res.end(`User-agent: *\nAllow: /\n${privatePrefixes.map((value) => `Disallow: ${value}`).join('\n')}\n\nSitemap: ${siteUrl}/sitemap.xml\n`);
      return;
    }
    if (path === '/sitemap.xml') {
      res.setHeader('Content-Type', 'application/xml; charset=utf-8');
      res.end(await sitemapIndex());
      return;
    }
    const sitemapMatch = path.match(/^\/sitemaps\/([a-z]+)\/(\d+)\.xml$/);
    if (sitemapMatch) {
      const content = await sitemapPage(sitemapMatch[1], Number(sitemapMatch[2]));
      if (!content) { res.statusCode = 404; res.end('Not found'); return; }
      res.setHeader('Content-Type', 'application/xml; charset=utf-8');
      res.end(content);
      return;
    }
    if (path.includes('.') && serveFile(res, path)) return;
    const seo = await routeMetadata(path);
    if (!seo) {
      res.statusCode = 404;
      res.setHeader('X-Robots-Tag', 'noindex, nofollow, noarchive');
      const notFound = metadata({ title: 'Page not found | CitizenNews', description: 'The requested CitizenNews page could not be found.', path,
        robots: 'noindex, nofollow, noarchive', schemas: [] });
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.end(renderIndex(notFound));
      return;
    }
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', isPrivate(path) ? 'no-store' : 'public, max-age=60, s-maxage=300, stale-while-revalidate=600');
    res.end(renderIndex(seo));
  } catch (error) {
    console.error(error);
    res.statusCode = 503;
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.end('CitizenNews is temporarily unavailable.');
  }
}).listen(port, () => console.log(`CitizenNews SEO gateway listening on http://localhost:${port}`));
