const fs = require('fs');
const path = require('path');

const WIKI_DIR = path.resolve(__dirname, '../../../wiki');
const GUIDES_DIR = path.resolve(__dirname, '../guides');
const BRANDING_ASSETS_DIR = path.resolve(__dirname, '../../../docs/branding/assets');
const WALLPAPER_DIR = path.resolve(__dirname, '../../../config/wallpaper');
const PUBLIC_DIR = path.resolve(__dirname, '../public');

function copyRecursiveSync(src, dest) {
  if (!fs.existsSync(src)) return;
  const stats = fs.statSync(src);
  if (stats.isDirectory()) {
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    fs.readdirSync(src).forEach((childItemName) => {
      copyRecursiveSync(path.join(src, childItemName), path.join(dest, childItemName));
    });
  } else {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(src, dest);
  }
}

function syncAssets() {
  console.log('[sync-docs] Synchronizing image & branding assets to VitePress public directory...');

  if (fs.existsSync(BRANDING_ASSETS_DIR)) {
    // Copy into public/docs/branding/assets
    copyRecursiveSync(BRANDING_ASSETS_DIR, path.join(PUBLIC_DIR, 'docs/branding/assets'));
    // Copy into public/assets
    copyRecursiveSync(BRANDING_ASSETS_DIR, path.join(PUBLIC_DIR, 'assets'));
    // Copy directly into public
    const assets = fs.readdirSync(BRANDING_ASSETS_DIR);
    for (const asset of assets) {
      fs.copyFileSync(path.join(BRANDING_ASSETS_DIR, asset), path.join(PUBLIC_DIR, asset));
    }
    console.log(`[sync-docs] Synced ${assets.length} branding vector assets.`);
  }

  if (fs.existsSync(WALLPAPER_DIR)) {
    copyRecursiveSync(WALLPAPER_DIR, path.join(PUBLIC_DIR, 'config/wallpaper'));
    const wallpapers = fs.readdirSync(WALLPAPER_DIR);
    for (const wp of wallpapers) {
      fs.copyFileSync(path.join(WALLPAPER_DIR, wp), path.join(PUBLIC_DIR, wp));
    }
    console.log(`[sync-docs] Synced wallpaper assets.`);
  }
}

function syncDocs() {
  console.log('[sync-docs] Synchronizing wiki markdown files to VitePress guides...');

  if (!fs.existsSync(WIKI_DIR)) {
    console.error(`[sync-docs] Error: Source wiki directory not found at ${WIKI_DIR}`);
    process.exit(1);
  }

  if (!fs.existsSync(GUIDES_DIR)) {
    fs.mkdirSync(GUIDES_DIR, { recursive: true });
  }

  const wikiFiles = fs.readdirSync(WIKI_DIR).filter(file => file.endsWith('.md'));
  console.log(`[sync-docs] Found ${wikiFiles.length} markdown documents in wiki.`);

  let copied = 0;
  for (const file of wikiFiles) {
    // Skip GitHub Wiki specific partials
    if (file === '_Sidebar.md' || file === '_Footer.md') {
      continue;
    }

    const srcPath = path.join(WIKI_DIR, file);
    const destPath = path.join(GUIDES_DIR, file);

    let content = fs.readFileSync(srcPath, 'utf8');

    // Adapt wiki-style relative links [Label](Page-Name) -> [Label](/guides/Page-Name)
    // Avoid changing http://, https://, mailto:, #anchors, or paths already having slashes
    content = content.replace(/\[([^\]]+)\]\((?!https?:\/\/|mailto:|#|\/|\.\/)([a-zA-Z0-9_-]+)\)/g, (match, label, slug) => {
      return `[${label}](/guides/${slug})`;
    });

    // Replace links pointing to Home with /guides/Home or /
    content = content.replace(/\/guides\/Home\b/g, '/guides/Home');

    // Replace raw githubusercontent links for branding assets with local public assets
    content = content.replace(/https:\/\/raw\.githubusercontent\.com\/samuelcaldas\/windows-coreos\/master\/docs\/branding\/assets\/([a-zA-Z0-9_.-]+)/g, '/docs/branding/assets/$1');

    fs.writeFileSync(destPath, content, 'utf8');
    copied++;
  }

  console.log(`[sync-docs] Successfully synced ${copied} guide documents to ${GUIDES_DIR}.`);
}

syncAssets();
syncDocs();
