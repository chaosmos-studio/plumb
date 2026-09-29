import { getCollection } from "astro:content";
import { site } from "../../site.config";
import { render } from "../../utils/og";

export const prerender = true;

// One card per page. Posts use their own cover for og:image, so these serve the site's other pages.
const pages = [
  { slug: "index", title: site.tagline, description: site.description, kicker: "Puzzle game" },
  { slug: "blog", title: "Tips, strategy and how it's made", description: `The ${site.name} blog.`, kicker: "Blog" },
  { slug: "about", title: "Made by two", description: `The story and the team behind ${site.name}.`, kicker: "About" },
  { slug: "support", title: "Support and FAQ", description: `Answers, bug reports and feedback for ${site.name}.`, kicker: "Support" },
  { slug: "privacy", title: "Privacy policy", description: `${site.name} collects no personal data. No ads, no analytics, no accounts.`, kicker: "Privacy" },
  { slug: "credits", title: "Credits", description: `Everything ${site.name} is built with, and the licences.`, kicker: "Credits" },
  { slug: "404", title: "Page not found", description: "This page rolled away.", kicker: "404" },
];

export async function getStaticPaths() {
  const posts = await getCollection("blog");
  const tags = [...new Set(posts.flatMap(p => p.data.tags))];
  return [
    ...pages.map(p => ({ params: { slug: p.slug }, props: p })),
    ...tags.map(t => ({
      params: { slug: `blog/tags/${t.toLowerCase().replace(/\s+/g, "-")}` },
      props: { title: `${t} posts`, description: `Every ${site.name} post about ${t.toLowerCase()}.`, kicker: "Blog" },
    })),
  ];
}

export async function GET({ props }: { props: { title: string; description: string; kicker: string } }) {
  return render(props.title, props.description, props.kicker);
}
