const fs = require('fs');
const path = require('path');

const WIKI_DIR = path.resolve(__dirname, '../../../wiki');
const GUIDES_DIR = path.resolve(__dirname, '../guides');

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
    // Avoid changing http://, https://, #anchors, or paths already having slashes
    content = content.replace(/\[([^\]]+)\]\((?!https?:\/\/|mailto:|#|\/|\.\/)([a-zA-Z0-9_-]+)\)/g, (match, label, slug) => {
      return `[${label}](/guides/${slug})`;
    });

    // Replace links pointing to Home with /guides/Home or /
    content = content.replace(/\/guides\/Home\b/g, '/guides/Home');

    fs.writeFileSync(destPath, content, 'utf8');
    copied++;
  }

  console.log(`[sync-docs] Successfully synced ${copied} guide documents to ${GUIDES_DIR}.`);
}

syncDocs();
