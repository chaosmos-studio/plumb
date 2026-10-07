// The site lives under a base path (/<game>/ on chaosmos.studio), so every link goes through here.
const base = import.meta.env.BASE_URL.endsWith("/") ? import.meta.env.BASE_URL : `${import.meta.env.BASE_URL}/`;

/** A path inside the site, like "blog/" or "", as a root-relative link with the base in front. */
export function href(path: string = ""): string {
  return `${base}${path.replace(/^\/+/, "")}`;
}

/** The same path as an absolute URL, for canonical links, sitemaps, structured data and feeds. */
export function absolute(path: string = ""): string {
  const origin = (import.meta.env.SITE ?? "https://chaosmos.studio").replace(/\/$/, "");
  return `${origin}${href(path)}`;
}

/** An absolute URL for a path that already carries the base, such as an optimised image's src. */
export function absoluteFromRoot(rootPath: string): string {
  const origin = (import.meta.env.SITE ?? "https://chaosmos.studio").replace(/\/$/, "");
  return `${origin}${rootPath.startsWith("/") ? rootPath : `/${rootPath}`}`;
}
