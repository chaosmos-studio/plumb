// schema.org structured data, so search engines know this is a free Android game with a video, a FAQ and
// the people behind it. Kept in one place so every page describes the game the same way.
import { faq as faqItems, site, team, videos, type Person } from "../site.config";
import { absolute } from "./url";

export function person(p: Person) {
  return p.avatar === "claude"
    ? { "@type": "SoftwareApplication", name: p.name, applicationCategory: "AI model", url: p.url, creator: { "@type": "Organization", name: "Anthropic", url: "https://www.anthropic.com/" } }
    : { "@type": "Person", name: p.name, url: p.url, image: p.avatar, jobTitle: p.role, sameAs: p.links.map(l => l.href) };
}

export function game(screenshots: string[] = []) {
  return {
    "@context": "https://schema.org",
    "@type": ["VideoGame", "MobileApplication"],
    name: site.name,
    description: site.description,
    url: absolute(""),
    image: absolute("og/index.png"),
    screenshot: screenshots,
    genre: site.genre,
    gamePlatform: site.platforms,
    operatingSystem: "Android",
    applicationCategory: "GameApplication",
    applicationSubCategory: "Puzzle game",
    inLanguage: "en",
    isAccessibleForFree: true,
    offers: { "@type": "Offer", price: "0", priceCurrency: "USD", availability: "https://schema.org/InStock", url: site.storeUrl },
    downloadUrl: site.storeUrl,
    installUrl: site.storeUrl,
    author: team.map(person),
    creator: team.map(person),
    publisher: { "@type": "Organization", name: "Chaosmos", url: "https://chaosmos.studio/" },
    datePublished: site.launched,
    keywords: site.keywords.join(", "),
  };
}

export function video(id: string) {
  const v = videos.find(x => x.id === id);
  if (!v) return null;
  return {
    "@context": "https://schema.org",
    "@type": "VideoObject",
    name: v.title,
    description: v.description,
    thumbnailUrl: [absolute(v.poster)],
    uploadDate: v.uploadDate,
    duration: v.duration,
    contentUrl: absolute(v.src),
    width: v.width,
    height: v.height,
    publisher: { "@type": "Person", name: "Shravan Goswami" },
  };
}

export function breadcrumbs(trail: { label: string; path: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [{ label: "Home", path: "" }, ...trail].map((t, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: t.label,
      item: absolute(t.path),
    })),
  };
}

export function faq(items: readonly { q: string; a: string }[] = faqItems) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map(i => ({ "@type": "Question", name: i.q, acceptedAnswer: { "@type": "Answer", text: i.a } })),
  };
}
