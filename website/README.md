# Website maintenance

[hellomini.app](https://hellomini.app) is the public landing page. It is a dependency-free static site: edit `index.html`, `style.css`, and `site.js`, with assets in `assets/` and the social card in `og.png`.

## Production deployment

Cloudflare Pages project **hellomini** connects to `emmettl/hellomini` and deploys automatically from `main`:

| Setting | Value |
| --- | --- |
| Framework | None |
| Build command | Empty |
| Repository root | Default |
| Output directory | `website` |
| Custom domain | `hellomini.app` |
| Pages hostname | `hellomini.pages.dev` |

The custom domain and HTTPS are active. Pages manages the apex CNAME to `hellomini.pages.dev`. App compilation and public app releases are separate from website deployment. The private design preview is also separate from production.

## Local preview

From the repository root:

```sh
python3 -m http.server 8765 --directory website
```

Open `http://localhost:8765`. No package installation or build step is needed.

## Download link

`site.js` reads GitHub's public latest stable release endpoint. The published ZIP must match `Hello-Mini-version-macos-arm64.zip`; its URL must belong to this repository’s GitHub release download origin. The button updates automatically after a stable release is published.

If there is no public release, the page says the first release is coming soon. Network or rate-limit failures retain a usable link to the releases page. Drafts and prereleases are not offered as the latest stable download.

## Assets and social sharing

Icons come from the app's original `PixelSymbol` artwork. `assets/desktop.png` is an unedited capture of Hello Mini showing Teapot and Aquarium with demonstration content. Avoid private paths, project names, and Scrapbook contents in replacement screenshots.

Open Graph and Twitter/X large-image tags are in the static HTML. They use canonical `https://hellomini.app/` URLs, descriptions, alt text, PNG MIME type, and actual image dimensions. The original generated social card is **1733 × 908**. When replacing it, update both the asset and its metadata. Verify `/og.png` is publicly accessible over HTTPS; an owner-only preview cannot validate external crawler access.

## Validation

Check navigation and installation links, the current public download, missing images, and horizontal overflow. Responsive Chromium checks have covered widths 320, 375, 390, 430, 768, 1024, and 1280 CSS pixels, plus 200% browser zoom. These checks do not substitute for testing on physical iOS or Android devices.

Keep header touch targets at least 44 pixels high, use relative font sizes, and allow title bars and labels to wrap. The site includes semantic landmarks, keyboard focus styles, and a skip link. Reduced Motion disables smooth scrolling.

There are no analytics, cookies, third-party fonts, or account system in the site code. Its only browser-side external request is to GitHub for public release metadata.
