import { spawnSync } from 'child_process';
import { mkdir, mkdirSync } from 'fs';

const REPO_DIR = 'tmp/discourse-repo';

function runOrFail(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: REPO_DIR,
    ...options,
  });

  if (result.error) {
    throw new Error(`Failed to execute ${command}: ${result.error.message}`);
  }

  if (result.status !== 0) {
    const stderr = result.stderr?.toString('utf-8') || '';
    const stdout = result.stdout?.toString('utf-8') || '';
    throw new Error(
      `Command '${command} ${args.join(' ')}' exited with code ${result.status}\n` +
        `stderr: ${stderr}\n` +
        `stdout: ${stdout}`,
    );
  }

  return result;
}

const ORIGIN = 'https://github.com/discourse/discourse';
const FETCH_REFSPECS = [
  '+refs/heads/main:refs/heads/main',
  '+refs/heads/latest:refs/heads/latest',
  '+refs/heads/stable:refs/heads/stable',
  '+refs/heads/version/*:refs/heads/version/*',
  '+refs/tags/*:refs/tags/*',
];

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
const SUBJECT = '%s';

const PRETTY_FORMAT = `--pretty=format:${COMMIT_HASH}${FIELD_SEP}${AUTHOR_NAME}${FIELD_SEP}${SUBJECT}${RECORD_SEP}`;

const result = runOrFail('git', ['log', PRETTY_FORMAT, 'v3.4.0..main']);

const stdoutString = result.stdout.toString('utf-8').trim();

console.log('Raw commit log output:', stdoutString);
