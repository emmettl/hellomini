# hellomini.app

A dependency-free static landing page. Serve this directory with a static web server for local preview. Icons are exported from the app’s original PixelSymbol artwork. The desktop image is an unedited, clean capture of Hello Mini showing Teapot and Aquarium.

## Cloudflare Pages

Connect the emmettl/hellomini repository to Pages. Use main as the production branch, no framework, no build command, and website as the build output directory (repository root as the root directory). Add hellomini.app in the Pages project’s Custom domains screen and follow its DNS setup. The app and Swift build do not run as part of the website deployment.

The public latest-release endpoint on GitHub controls the download link. Until a release is public, the page says the first release is coming soon and links to the releases page. Network or rate-limit failures retain a usable releases link. Published assets must match the expected Hello-Mini-version-macos-arm64.zip name and the repository’s GitHub download origin.

No analytics, cookies, third-party fonts, or account system. The only browser-side external request is to GitHub for public release metadata. Reduced-motion preferences disable smooth scrolling. The page includes semantic landmarks, keyboard focus styling, a skip link, and responsive layouts.

## Updating

Edit index.html, style.css, and site.js directly; assets live in assets/. No dependencies or build step. Keep release availability accurate and avoid private paths, account details, and personal content in screenshots. The private design preview is maintained separately from the production Cloudflare Pages deployment.
