import rss from "@astrojs/rss";
import { getCollection } from "astro:content";
import { authors, site } from "../site.config";
import { absolute } from "../utils/url";

export async function GET() {
  const posts = (await getCollection("blog")).sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf());
  return rss({
    title: `${site.name} blog`,
    description: `Tips, strategy and behind-the-scenes posts about ${site.name}.`,
    site: absolute(""),
    items: posts.map(p => ({
      title: p.data.title,
      description: p.data.description,
      pubDate: p.data.pubDate,
      link: absolute(`blog/${p.id}/`),
      categories: p.data.tags,
      author: p.data.authors.map(id => authors[id].name).join(", "),
    })),
    customData: "<language>en</language>",
  });
}
