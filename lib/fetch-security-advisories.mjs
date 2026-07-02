/* eslint-disable no-console */
import { mkdirSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(__dirname, "..");
const OUTPUT_PATH = join(PROJECT_ROOT, "data/security-advisories.json");

const REPO_OWNER = "discourse";
const REPO_NAME = "discourse";

function parseLinks(linkHeader) {
  if (!linkHeader) {
    return {};
  }
  const links = {};
  for (const part of linkHeader.split(",")) {
    const match = part.match(/<([^>]+)>;\s*rel="([^"]+)"/);
    if (match) {
      links[match[2]] = match[1];
    }
  }
  return links;
}

async function fetchAllAdvisories() {
  let url = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/security-advisories?state=published&per_page=100`;
  const allAdvisories = [];

  const headers = {
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  };

  if (process.env.GITHUB_TOKEN) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }

  let page = 1;
  while (url) {
    console.log(`Fetching page ${page}...`);
    const response = await fetch(url, { headers });

    if (!response.ok) {
      throw new Error(
        `Failed to fetch advisories: ${response.status} ${response.statusText}`
      );
    }

    const advisories = await response.json();
    allAdvisories.push(...advisories);
    console.log(
      `  Got ${advisories.length} advisories (total: ${allAdvisories.length})`
    );

    // Check for next page
    const links = parseLinks(response.headers.get("Link"));
    url = links.next || null;
    page++;
  }

  return allAdvisories;
}

function transformAdvisory(advisory) {
  // Per affected release line: vulnerable from `range` up to (not incl.) `patched`.
  const vulnerabilities = (advisory.vulnerabilities || []).map((v) => ({
    range: v.vulnerable_version_range || null,
    patched: v.patched_versions?.trim() || null,
  }));

  return {
    ghsa_id: advisory.ghsa_id,
    cve_id: advisory.cve_id,
    summary: advisory.summary,
    severity: advisory.severity,
    published_at: advisory.published_at,
    html_url: advisory.html_url,
    vulnerabilities,
  };
}

async function main() {
  console.log("Fetching security advisories from GitHub...\n");

  const rawAdvisories = await fetchAllAdvisories();
  const advisories = rawAdvisories.map(transformAdvisory);

  mkdirSync(dirname(OUTPUT_PATH), { recursive: true });
  writeFileSync(OUTPUT_PATH, JSON.stringify(advisories, null, 2));

  console.log(`\nWritten ${advisories.length} advisories to ${OUTPUT_PATH}`);

  // Log summary of advisories with patched versions
  const withPatched = advisories.filter((a) =>
    a.vulnerabilities.some((v) => v.patched)
  );
  console.log(`\n${withPatched.length} advisories have patched version info:`);
  for (const advisory of withPatched) {
    const patched = advisory.vulnerabilities
      .map((v) => v.patched)
      .filter(Boolean)
      .join(", ");
    console.log(`  ${advisory.ghsa_id}: ${patched}`);
  }
}

main().catch((error) => {
  console.error("Error fetching security advisories:", error);
  process.exit(1);
});
