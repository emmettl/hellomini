# hellomini.app

A dependency-free static landing page. Serve this directory with a static web server for local preview. Icons are exported from the app’s original PixelSymbol artwork. The desktop image is an unedited, clean capture of Hello Mini showing Teapot and Aquarium.

## Cloudflare Pages

Connect the emmettl/hellomini repository to Pages. Use main as the production branch, no framework, no build command, and website as the build output directory (repository root as the root directory). Add hellomini.app in the Pages project’s Custom domains screen and follow its DNS setup. The app and Swift build do not run as part of the website deployment.

The public latest-release endpoint on GitHub controls the download link. Until a release is public, the page says the first release is coming soon and links to the releases page. Network or rate-limit failures retain a usable releases link. Published assets must match the expected Hello-Mini-version-macos-arm64.zip name and the repository’s GitHub download origin.

No analytics, cookies, third-party fonts, or account system. The only browser-side external request is to GitHub for public release metadata. Reduced-motion preferences disable smooth scrolling. The page includes semantic landmarks, keyboard focus styling, a skip link, and responsive layouts.

## Updating

Edit index.html, style.css, and site.js directly; assets live in assets/. No dependencies or build step. Keep release availability accurate and avoid private paths, account details, and personal content in screenshots. The private design preview is maintained separately from the production Cloudflare Pages deployment.

## Social sharing and mobile validation

Open Graph and Twitter/X large-image tags are included directly in the HTML, with canonical https://hellomini.app/ URLs, descriptions, image alt text, PNG MIME type, and actual pixel dimensions. No unverified social account handle is claimed. The public domain must serve this page and /og.png before external social crawlers can fetch it; the owner-only preview is not a crawler validation environment.

The social image is 1733 × 908 and was created with built-in image generation. Prompt: “Polished flat monochrome brand graphic inspired by a retro 1984 Macintosh desktop. Light gray dither background, black borders, a striped window, smiling pixel Macintosh, and restrained teapot, fish, and folder motifs. Exact text: Hello Mini; A little desktop. A lot of possibility.; hellomini.app. Landscape 1.91:1, generous margins, thumbnail-readable text, no Apple logo, no additional text.”

Browser checks covered widths 320, 375, 390, 430, 768, 1024, and 1280 CSS pixels, navigation and installation anchor links, and 200% Chrome zoom down to a 320 CSS-pixel viewport. No horizontal content overflow was found. Header links have 44-pixel minimum touch targets; phone app icons use two columns. Font sizes use relative units and title bars expand with their labels. These are responsive Chromium checks, not tests on physical iOS or Android devices.
