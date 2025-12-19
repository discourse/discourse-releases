import { copyFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(__dirname, '..');
const DIST_DIR = join(PROJECT_ROOT, 'dist');

const indexPath = join(DIST_DIR, 'index.html');
const notFoundPath = join(DIST_DIR, '404.html');

if (existsSync(indexPath)) {
  copyFileSync(indexPath, notFoundPath);
  console.log('Created 404.html for GitHub Pages client-side routing');
} else {
  console.error('index.html not found in dist directory');
  process.exit(1);
}
