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

// Page copy. The pages hold layout only, so another game's site changes words here, not markup.
// A heading given as [plain, accent] sets its last words in the accent colour.

export const home = {
  eyebrow: "A calm marble puzzle for Android and the web",
  title: ["Plumb: roll every marble ", "home"],
  lede: "Tilt the board and every marble rolls at once. Each one has to drop into the hole of its own colour, and square pits swallow any that wander. One swipe, a whole chain of consequences.",
  facts: ["Free", "No ads", "No timers", "Plays offline"],
  heroShot: "plumb-level-in-play",
  watch: { eyebrow: "Watch", title: "Forty seconds of Plumb", lede: "A few levels, the hint, three stars, and one left for you to solve." },
  how: {
    title: "Look. Tilt. Drop.",
    steps: [
      { image: "plumb-step-start", title: "Look", body: "Every marble sits on a paper board with walls, holes and, later, pits. Find where each one needs to go." },
      { image: "plumb-step-tilt", title: "Tilt", body: "Swipe to tilt the board. Every marble rolls at once, until a wall, the edge or another marble stops it." },
      { image: "plumb-step-home", title: "Drop", body: "A marble that rolls over a hole of its own colour drops in. Get them all home in as few moves as you can." },
    ],
    link: { href: "blog/how-to-play-plumb/", label: "Read the full guide to playing Plumb" },
  },
  featuresTitle: "Simple rules, surprisingly deep",
  final: { title: "Ready to roll?", lede: "Plumb is free on Google Play, with no ads and nothing to sign up for." },
} as const;

// The phone screenshots on the home page, in order; files in src/assets/shots/.
export const shots = [
  { image: "plumb-title-screen", alt: "Plumb's title screen with a seesaw of marbles and the Play button" },
  { image: "plumb-level-in-play", alt: "A Plumb level in play: marbles, walls and coloured holes on a paper board" },
  { image: "plumb-hint-preview", alt: "Plumb's hint showing ghost marbles and dotted trails for the next tilt" },
  { image: "plumb-level-solved", alt: "A solved Plumb level with three gold stars" },
  { image: "plumb-level-select", alt: "Plumb's level grid with stars earned on the first levels" },
] as const;

export const blogPage = {
  title: "Blog: tips, strategy and how Plumb is made",
  description: "Guides, strategy and behind-the-scenes posts about Plumb, the calm marble puzzle game: how to play, how to get three stars, and how the levels are made.",
  heading: ["Tips, strategy and ", "how it's made"],
  lede: "How to play, how to find the perfect route, and what goes into a puzzle game built by a two-person team.",
} as const;

export const about = {
  title: "About Plumb and the team behind it",
  description: "Plumb is a calm marble puzzle made by a two-person team: Shravan Goswami, and Claude Opus 5.5, an AI model by Anthropic. How the game was made and why.",
  heading: ["A small game about ", "gravity"],
  lede: "Plumb is a calm logic puzzle. You tilt a board, every marble rolls at once, and each one has to find the hole of its own colour. It is free, it plays offline, and it has no ads, no timers and no lives.",
  sections: [
    {
      heading: "Why we made it",
      paragraphs: [
        "Most puzzle games ask you to move one thing at a time. Plumb moves everything at once. That one twist turns four swipe directions into a surprisingly deep game: every tilt is a small chain of consequences, and the fun is in reading the board before you make it.",
        "We wanted a game that respects your time and attention. No energy bars, no countdowns, no ads between levels. Just a board, some marbles, and a moment of \"oh, that's how.\"",
      ],
    },
    {
      heading: "How it is built",
      paragraphs: [
        "Every level is generated by a program and then proven solvable by another program, a solver that tries every possible sequence of tilts and records the shortest one. That shortest route is the level's par, and it is how the stars are scored. The levels are ordered so that each one is at least as hard as the one before, and no two levels are near-copies of each other, even turned or mirrored. The tests check all of that again on every build.",
        "The art, the sounds and the music are made in code, not bought or downloaded. The game is written in GDScript with the Godot Engine, and the same code runs on Android and in your browser.",
      ],
    },
  ],
  teamNote: "Shravan decides what the game is, plays every build and has the final say. Claude writes most of the code, the level generator and solver, the art and sound pipelines and this website, in conversation with Shravan in Claude Code.",
  facts: [
    ["Developer", "Shravan Goswami, with Claude Opus 5.5"],
    ["Genre", "Logic puzzle"],
    ["Platforms", "Android (Google Play), web browser"],
    ["Price", "Free, no ads, no in-app purchases"],
    ["Engine", "Godot Engine"],
  ],
} as const;

export const privacy = {
  description: "Plumb's privacy policy: the game collects no personal data, has no ads, no analytics and no accounts, and keeps your progress on your own device.",
  stores: ["the stars you have earned on each level, which is also how levels unlock;", "your sound, music and vibration settings."],
  permissions: "The Android app asks for one permission: vibration, so a tap can buzz lightly when vibration is switched on. It asks for no location, camera, microphone, contacts, files or network access.",
  audience: "Plumb is suitable for everyone. Because the app collects no data from anyone, it collects none from children.",
} as const;

// The credits page's sections after the team, mirroring the game's CREDITS.md and credits.gd.
export const credits = [
  {
    title: "In the game",
    items: [
      { name: "Godot Engine", detail: "The game engine, MIT licence", href: "https://godotengine.org/license/" },
      { name: "Outfit", detail: "Typeface by the Outfit Project Authors, SIL Open Font License 1.1. Used as two static weights with overlapping contours merged.", href: "https://github.com/Outfitio/Outfit-Fonts" },
      { name: "Sound and music", detail: "Every sound effect and the ambient music loop are synthesised in code for this game. None are third-party.", href: "" },
      { name: "Art and levels", detail: "Drawn and generated in code, and every level proven solvable by the game's own solver.", href: "" },
    ],
  },
  {
    title: "On this website",
    items: [
      { name: "Astro", detail: "The site framework, MIT licence", href: "https://astro.build/" },
      { name: "Pagefind", detail: "Search that runs in your browser, MIT licence", href: "https://pagefind.app/" },
      { name: "Giscus", detail: "Comments and feedback on GitHub Discussions, MIT licence", href: "https://giscus.app/" },
      { name: "Outfit", detail: "Served from Fontsource, SIL Open Font License 1.1", href: "https://fontsource.org/fonts/outfit" },
    ],
  },
] as const;

export const notFound = { heading: ["This page rolled ", "away"], description: "This page rolled away. Head back to the Plumb home page, the blog or support." } as const;

// Colours for the generated social cards, from the light palette in styles/theme.css.
export const ogColours = { bg: "#f4efe7", ink: "#2f333d", muted: "#7d766a", accent: "#ff6b6b", orbs: ["#ff6b6b", "#3bb8a9", "#ffb627"] } as const;
