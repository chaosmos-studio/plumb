// Checks the built site (dist/) for the SEO basics on every page, so a regression fails loudly instead of
// quietly costing search traffic. Run after `npm run build`: `npm run check`.
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, relative } from "node:path";

const dist = new URL("../dist/", import.meta.url).pathname;
const base = (process.env.BASE_PATH || "/" + JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")).name.replace(/-website$/, "") + "/").replace(/\/?$/, "/");
// Paths served by something other than this build, such as the game's own web export.
const external = [`${base}play/`];
// The pages the Android app and its Play listing link to. Google Play's Payments policy forbids leading Play
// users to payment outside Play, so these render with sponsor={false} and must link to no payment page.
const playLinked = ["privacy/index.html", "support/index.html"];
const payment = /github\.com\/sponsors|patreon\.com|ko-fi\.com|buymeacoffee\.com|paypal\.(com|me)|liberapay\.com|opencollective\.com/i;
const problems = [];
const warnings = [];

function pages(dir) {
  return readdirSync(dir).flatMap(name => {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) return name === "_astro" || name === "pagefind" ? [] : pages(p);
    return name.endsWith(".html") ? [p] : [];
  });
}

// Lengths are what a reader sees, so HTML entities count as the one character they stand for.
function text(html) {
  return html.replace(/&(#\d+|#x[\da-f]+|\w+);/gi, "_");
}

function attr(tag, name) {
  const m = tag.match(new RegExp(`${name}="([^"]*)"`));
  return m ? m[1] : null;
}

const htmlFiles = pages(dist);
const sitemap = readFileSync(join(dist, "sitemap-0.xml"), "utf8");

for (const file of htmlFiles) {
  const rel = relative(dist, file);
  const html = readFileSync(file, "utf8");
  const noindex = /<meta name="robots" content="noindex/.test(html);
  const title = text((html.match(/<title>([^<]*)<\/title>/) || [])[1] || "");
  const desc = text(attr(html.match(/<meta name="description"[^>]*>/)?.[0] ?? "", "content") || "");
  if (!title) problems.push(`${rel}: no <title>`);
  else if (title.length > 65) warnings.push(`${rel}: title is ${title.length} characters (aim for 60 or fewer)`);
  if (desc.length < 70 || desc.length > 170) problems.push(`${rel}: description is ${desc.length} characters (want 70 to 170)`);
  if (!/<link rel="canonical" href="https:\/\//.test(html)) problems.push(`${rel}: no absolute canonical link`);
  if (!/<meta property="og:image" content="https:\/\//.test(html)) problems.push(`${rel}: no absolute og:image`);
  const h1s = (html.match(/<h1[\s>]/g) || []).length;
  if (h1s !== 1) problems.push(`${rel}: ${h1s} h1 elements (want exactly 1)`);
  for (const img of html.match(/<img\b[^>]*>/g) || []) {
    const alt = attr(img, "alt");
    if (alt === null) problems.push(`${rel}: an image has no alt attribute: ${img.slice(0, 90)}`);
    else if (alt === "" && !/brand-icon/.test(img)) warnings.push(`${rel}: an image has empty alt (fine only if decorative)`);
    if (!attr(img, "width") || !attr(img, "height")) warnings.push(`${rel}: an image has no width/height, which shifts layout`);
  }
  for (const block of html.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g) || []) {
    try {
      JSON.parse(block.replace(/^<script[^>]*>/, "").replace(/<\/script>$/, ""));
    } catch {
      problems.push(`${rel}: a JSON-LD block does not parse`);
    }
  }
  if (!noindex) {
    const canonical = attr(html.match(/<link rel="canonical"[^>]*>/)?.[0] ?? "", "href");
    if (canonical && !sitemap.includes(`<loc>${canonical}</loc>`) && !rel.startsWith("og/")) problems.push(`${rel}: canonical ${canonical} is not in the sitemap`);
  }
  const noSponsor = /<body[^>]*data-sponsor="off"/.test(html);
  if (playLinked.includes(rel) && !noSponsor) problems.push(`${rel}: the Play listing links here, so it must render with sponsor={false}`);
  if (noSponsor && payment.test(html)) problems.push(`${rel}: links to a payment page (${html.match(payment)[0]}), which a page Play links to must not`);
  // Internal links must resolve to a built file.
  for (const a of html.match(/href="(\/[^"#?]*)/g) || []) {
    const path = a.slice(6);
    if (!path.startsWith(base) || external.some(e => path.startsWith(e))) continue;
    const local = join(dist, path.slice(base.length));
    const ok = existsSync(local) && (statSync(local).isFile() || existsSync(join(local, "index.html")));
    if (!ok) problems.push(`${rel}: broken internal link ${path}`);
  }
  // Links within a page, such as the table of contents, must land on an element with that id.
  for (const [, id] of html.matchAll(/href="#([^"]+)"/g)) {
    if (!html.includes(`id="${id}"`)) problems.push(`${rel}: link to #${id} has no target on the page`);
  }
}

for (const f of ["robots.txt", "sitemap-index.xml", "sitemap-images.xml", "manifest.webmanifest", "pagefind/pagefind.js"]) {
  if (!existsSync(join(dist, f))) problems.push(`missing ${f}`);
}

for (const w of [...new Set(warnings)]) console.log(`warn: ${w}`);
for (const p of problems) console.log(`FAIL: ${p}`);
console.log(`${htmlFiles.length} pages checked, ${problems.length} problem(s), ${new Set(warnings).size} warning(s)`);
process.exit(problems.length ? 1 : 0);
