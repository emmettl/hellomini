'use strict';
// Only offer a direct download once GitHub exposes a published release.
// Draft releases remain private and cannot accidentally become broken download links.
(async () => {
  const button = document.querySelector('#download');
  const status = document.querySelector('#release-status');
  try {
    const response = await fetch('https://api.github.com/repos/emmettl/hellomini/releases/latest', {
      headers: { Accept: 'application/vnd.github+json' },
      signal: AbortSignal.timeout(5000)
    });
    if (response.status === 404) {
      button.replaceChildren(document.createTextNode('Follow the first release ↗'));
      status.textContent = 'First release coming soon · macOS 26+ · Apple silicon';
      return;
    }
    if (!response.ok) return;
    const release = await response.json();
    const asset = release.assets?.find(item => /^Hello-Mini-\d+\.\d+\.\d+-macos-arm64\.zip$/.test(item.name));
    if (!asset || release.draft || release.prerelease) return;
    const url = new URL(asset.browser_download_url);
    if (url.origin !== 'https://github.com' || !url.pathname.startsWith('/emmettl/hellomini/releases/download/')) return;
    button.href = url.href;
    button.textContent = 'Download for Mac ↓';
    status.textContent = `${release.tag_name} · macOS 26+ · Apple silicon`;
  } catch {
    // A useful release-page link remains available when GitHub cannot be reached.
  }
})();
