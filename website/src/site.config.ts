// Everything about this game the website needs. The layouts, SEO and pages read only this file (and the
// blog content), so another game's site is this file, its palette in styles/theme.css, its motif, and
// its posts.

export const site = {
  name: "Plumb",
  wordmark: "plumb",
  tagline: "Roll every marble home",
  // Meta description for the home page: under 160 characters, the game in one breath.
  description:
    "Plumb is a calm marble puzzle game: tilt the board, every marble rolls at once, and each must drop into the hole of its own colour. Free on Android.",
  keywords: ["marble puzzle", "tilt puzzle", "logic puzzle game", "gravity puzzle", "offline puzzle game", "brain teaser"],
  url: "https://shravangoswami.com/plumb/",
  playPath: "play/",
  storeUrl: "https://play.google.com/store/apps/details?id=com.shravangoswami.plumb",
  packageId: "com.shravangoswami.plumb",
  genre: "Puzzle",
  platforms: ["Android", "Web browser"],
  launched: "2026-10-01",
  email: "contact@shravangoswami.com",
  locale: "en_US",
  themeStorageKey: "plumb-theme",
  themeColor: { light: "#f4efe7", dark: "#1b1d22" },
  searchPlaceholder: "Search tips, rules and posts...",
  // Paste the content of Search Console's HTML tag here once the property is added.
  googleSiteVerification: "",
  giscus: {
    repo: "shravanngoswamii/comments",
    repoId: "R_kgDOQ90dlg",
    category: "Announcements",
    categoryId: "DIC_kwDOQ90dls4C1NXa",
  },
} as const;

export const nav = [
  { href: "blog/", label: "Blog" },
  { href: "about/", label: "About" },
  { href: "support/", label: "Support" },
] as const;

export interface Person {
  readonly id: string;
  readonly name: string;
  readonly role: string;
  readonly bio: string;
  readonly avatar: string;
  readonly url: string;
  readonly links: readonly { readonly label: string; readonly href: string; readonly icon: string }[];
}

// The team behind the three 2026 puzzle games: a person and an AI model, credited as they worked.
export const team: readonly Person[] = [
  {
    id: "shravan",
    name: "Shravan Goswami",
    role: "Game designer and developer",
    bio: "Shravan designs and ships small, calm games and apps. He sets the direction, plays every build, and decides what stays in.",
    avatar: "https://github.com/shravanngoswamii.png",
    url: "https://shravangoswami.com/",
    links: [
      { label: "Website", href: "https://shravangoswami.com/", icon: "globe" },
      { label: "GitHub", href: "https://github.com/shravanngoswamii", icon: "github" },
      { label: "LinkedIn", href: "https://www.linkedin.com/in/shravangoswami/", icon: "linkedin" },
      { label: "Sponsor", href: "https://github.com/sponsors/shravanngoswamii", icon: "heart" },
    ],
  },
  {
    id: "claude",
    name: "Claude Opus 5.5",
    role: "AI co-developer",
    bio: "Claude is an AI model made by Anthropic. It wrote the game's code, the level generator and solver, the art and sound pipelines, and this website, working with Shravan in Claude Code.",
    avatar: "claude",
    url: "https://www.anthropic.com/claude",
    links: [{ label: "About Claude", href: "https://www.anthropic.com/claude", icon: "globe" }],
  },
];

export const authors = Object.fromEntries(team.map(p => [p.id, p])) as Record<string, Person>;

export const features = [
  { title: "One swipe moves everything", body: "Tilt the board and every marble rolls at once, until a wall, the edge or another marble stops it." },
  { title: "Each colour has its home", body: "A marble drops into a hole of its own colour the moment it rolls over one. Plan the route before you tip." },
  { title: "Watch out for pits", body: "Square pits swallow any marble. Undo is always one tap away, so every mistake is a lesson, not a loss." },
  { title: "A hint that shows, not tells", body: "Stuck? The hint previews your next tilt on the board: ghost marbles, dotted trails and where each one lands." },
  { title: "Stars for the perfect route", body: "Every level is solved by a computer to find the fewest moves. Match that par for three stars." },
  { title: "Calm by design", body: "No timers, no lives, no energy. Play offline, at your own pace, with sound, music and vibration you control." },
] as const;

export const faq = [
  {
    q: "How do I play Plumb?",
    a: "Swipe up, down, left or right to tilt the board. Every marble rolls in that direction until something stops it. A marble that rolls over a hole of its own colour drops in. Get every marble home to clear the level.",
  },
  {
    q: "Is Plumb free?",
    a: "Yes. Plumb is free on Google Play and you can also play it in your web browser.",
  },
  {
    q: "Does Plumb need an internet connection?",
    a: "No. The Android app plays completely offline. Your progress is saved on your device.",
  },
  {
    q: "What does par mean, and how do I get three stars?",
    a: "Par is the fewest moves that clear a level, found by a solver that checks every possible move. Clear a level in par for three stars; a few moves over still earns one or two.",
  },
  {
    q: "What does the hint do?",
    a: "The hint shows your best next tilt right on the board: ghost marbles where each marble will stop, trails along the way, and a ring on any marble that would fall into a pit.",
  },
  {
    q: "Is every level solvable?",
    a: "Yes. Every level is generated and then proven solvable by a solver before it ships, and the tests check every level again on every build.",
  },
  {
    q: "Does Plumb have ads or collect my data?",
    a: "Plumb has no ads, no analytics and no accounts, and collects no personal data. See the privacy policy for the details.",
  },
] as const;

// Videos shown on the site, with what search engines need to index them.
export const videos = [
  {
    id: "trailer",
    title: "Plumb gameplay trailer",
    description: "Tilt the board, roll every marble home: a short look at Plumb's levels, hint and stars.",
    src: "videos/plumb-trailer.mp4",
    poster: "videos/plumb-trailer.jpg",
    duration: "PT39S",
    uploadDate: "2026-09-30",
    width: 1920,
    height: 1080,
  },
] as const;

export const builtWith = ["Godot Engine", "GDScript", "Astro", "Pagefind", "Giscus"] as const;
