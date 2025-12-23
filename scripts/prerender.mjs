import { readFile, writeFile, mkdir } from 'fs/promises';
import SimpleDOM from 'simple-dom/dist/commonjs/es5/index.js';
import { join } from 'path';
import Module from 'node:module';
// import { globSync } from 'glob';

const require = Module.createRequire(import.meta.url);

global.FastBoot = {
  require(thing) {
    require(thing);
  },
};

import Result from './result.mjs';

globalThis.window = globalThis;

const { default: App } = await import('../dist-ssr/app.mjs');
const wrapperHTML = await readFile('dist/index.html', 'utf8');

let instance = App.create({
  autoboot: false,
  modulePrefix: 'discourse-changelog',
});

async function preRender(path) {
  console.log(`Rendering ${path}`);
  try {
    const result = await render(path, instance);

    result._finalizeHTML();
    await mkdir(join('dist', path), { recursive: true });
    await writeFile(join('dist', path, 'index.html'), await result.html());
  } catch (e) {
    console.error(`Error Rendering path: ${e.message}`);
    throw e;
  }
}

function buildBootOptions() {
  let doc = new SimpleDOM.Document();
  let rootElement = doc.body;
  return {
    isBrowser: false,
    document: doc,
    rootElement,
    shouldRender: true,
  };
}

async function render(url, instance) {
  let bootOptions = buildBootOptions();
  await instance.visit(url, bootOptions);
  return new Result(bootOptions.document, wrapperHTML, {});
}

const routesToPrerender = [
  '/',
  '/changelog/custom',
  '/changelog/latest',
];

for (let path of routesToPrerender) {
  await preRender(path);
}