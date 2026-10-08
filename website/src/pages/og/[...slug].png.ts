import { notFound, site } from "../../site.config";
import { render } from "../../utils/og";

export const prerender = true;

// One card per page.
const pages = [
  { slug: "index", title: site.tagline, description: site.description, kicker: "Puzzle game" },
  { slug: "about", title: "Made by two", description: `The story and the team behind ${site.name}.`, kicker: "About" },
  { slug: "support", title: "Support and FAQ", description: `Answers, bug reports and feedback for ${site.name}.`, kicker: "Support" },
  { slug: "privacy", title: "Privacy policy", description: `What ${site.name} keeps on your device, and what the ads in its Android app collect.`, kicker: "Privacy" },
  { slug: "credits", title: "Credits", description: `Everything ${site.name} is built with, and the licences.`, kicker: "Credits" },
  { slug: "404", title: "Page not found", description: `${notFound.heading.join("")}.`, kicker: "404" },
];

export function getStaticPaths() {
  return pages.map(p => ({ params: { slug: p.slug }, props: p }));
}

export async function GET({ props }: { props: { title: string; description: string; kicker: string } }) {
  return render(props.title, props.description, props.kicker);
}
