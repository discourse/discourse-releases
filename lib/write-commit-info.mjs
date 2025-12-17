import { execaSync, execa } from 'execa';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

// Get project root directory
const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(__dirname, '..');
const REPO_DIR = join(PROJECT_ROOT, 'tmp/discourse-repo');
const BASE_TAG = 'v3.4.0';
const BATCH_SIZE = 100; // Process this many commits in parallel

function runOrFail(command, args, options = {}) {
  return execaSync(command, args, {
    cwd: REPO_DIR,
    ...options,
  });
}

async function runAsync(command, args, options = {}) {
  const result = await execa(command, args, {
    cwd: REPO_DIR,
    ...options,
  });
  return result.stdout;
}

const ORIGIN = 'https://github.com/discourse/discourse';
const FETCH_REFSPECS = [
  '+refs/heads/main:refs/heads/main',
  '+refs/heads/latest:refs/heads/latest',
  '+refs/heads/stable:refs/heads/stable',
  '+refs/heads/version/*:refs/heads/version/*',
  '+refs/tags/*:refs/tags/*',
];

async function main() {
  // if(!existsSync("tmp/discourse-repo")){
  mkdirSync(REPO_DIR, { recursive: true });

  runOrFail('git', ['init', '--bare', '.']);
  runOrFail('git', [
    'fetch',
    ORIGIN,
    '--prune',
    '--filter=tree:0',
    "--refmap=''",
    ...FETCH_REFSPECS,
  ]);

  // Generate an array of commit objects, by looking at the log between `v3.4.0` and `main`
  const FIELD_SEP = '%x1f';
  const RECORD_SEP = '%x1e';
  const COMMIT_HASH = '%H';
  const AUTHOR_NAME = '%an';
  const COMMIT_DATE = '%cI'; // ISO 8601 format
  const SUBJECT = '%s';

  const PRETTY_FORMAT = `--pretty=format:${COMMIT_HASH}${FIELD_SEP}${AUTHOR_NAME}${FIELD_SEP}${COMMIT_DATE}${FIELD_SEP}${SUBJECT}${RECORD_SEP}`;

  const result = runOrFail('git', ['log', PRETTY_FORMAT, `${BASE_TAG}..main`]);

  const stdoutString = result.stdout.trim();

  // Parse the commit records
  const records = stdoutString
    .split(String.fromCharCode(0x1e))
    .filter((record) => record.trim().length > 0);

  // First, parse all the commit records
  const commits = records.map((record) => {
    const fields = record.split(String.fromCharCode(0x1f));
    return {
      commitIndex: 0, // Will be filled in below
      hash: fields[0]?.trim() || '',
      author: fields[1]?.trim() || '',
      date: fields[2]?.trim() || '',
      subject: fields[3]?.trim() || '',
    };
  });

  // Calculate commit indices and version numbers for each commit in parallel batches
  console.log(`Processing ${commits.length} commits in batches of ${BATCH_SIZE}...`);

  async function processCommit(commit) {
    // Calculate commit index
    const countOutput = await runAsync('git', [
      'rev-list',
      '--count',
      `${BASE_TAG}..${commit.hash}`,
    ]);
    commit.commitIndex = parseInt(countOutput, 10);

    // Calculate version using git describe
    const describeOutput = await runAsync('git', [
      'describe',
      '--match',
      'v[0-9]*',
      '--',
      commit.hash,
    ]);
    // Strip 'v' prefix and reformat '-123-g<hash>' to ' +123'
    commit.version = describeOutput
      .replace(/^v/, '')
      .replace(/-(\d+)-g[a-f0-9]+$/, ' +$1');
  }

  // Process commits in batches
  for (let i = 0; i < commits.length; i += BATCH_SIZE) {
    const batch = commits.slice(i, i + BATCH_SIZE);
    console.log(
      `Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(commits.length / BATCH_SIZE)}...`,
    );
    await Promise.all(batch.map(processCommit));
  }

  // Reverse the array so commits are ordered from oldest to newest (from BASE_TAG to main)
  commits.reverse();

  console.log(`Processed ${commits.length} commits from ${BASE_TAG} to main`);

  // Write to JSON file
  const outputPath = join(PROJECT_ROOT, 'data/commits.json');
  mkdirSync(join(PROJECT_ROOT, 'data'), { recursive: true });
  writeFileSync(outputPath, JSON.stringify(commits, null, 2));

  console.log(`Written commit data to ${outputPath}`);
}

main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
