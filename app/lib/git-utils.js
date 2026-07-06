import { tracked } from "@glimmer/tracking";
import CommitsData from "/data/commits.json";
import NewFeaturesData from "/data/new-features.json";
import SecurityAdvisoriesData from "/data/security-advisories.json";
import semver from "semver";

export class AmbiguousRefError extends Error {
  constructor(ref, matches) {
    const shortMatches = matches.slice(0, 5).map((h) => h.slice(0, 12));
    const moreCount = matches.length - 5;
    const matchList =
      moreCount > 0
        ? `${shortMatches.join(", ")} and ${moreCount} more`
        : shortMatches.join(", ");

    super(
      `Ambiguous ref '${ref}' matches ${matches.length} commits: ${matchList}. Use more characters to be specific.`
    );
    this.name = "AmbiguousRefError";
    this.ref = ref;
    this.matches = matches;
  }
}

export class UnknownRefError extends Error {
  constructor(ref) {
    super(`Unknown ref '${ref}'. No matching tag, branch, or commit found.`);
    this.name = "UnknownRefError";
    this.ref = ref;
  }
}

export class ChangelogData {
  @tracked commitData = CommitsData;
  @tracked newFeatures = NewFeaturesData;
  @tracked securityAdvisories = SecurityAdvisoriesData;

  get baseTag() {
    return this.commitData?.baseTag || "";
  }

  get defaultStartRef() {
    return this.sortedTags[0]?.value || "";
  }

  get defaultEndRef() {
    return "latest";
  }

  get totalCommits() {
    return this.commitData ? Object.keys(this.commitData.commits).length : 0;
  }

  get branches() {
    if (!this.commitData) {
      return [];
    }
    return Object.keys(this.commitData.refs.branches).map((branch) => ({
      value: branch,
      label: branch,
    }));
  }

  get sortedTags() {
    if (!this.commitData) {
      return [];
    }

    // Sort tags in descending order
    const tags = Object.keys(this.commitData.refs.tags).sort((a, b) => {
      const aNormalized = normalizeVersion(a);
      const bNormalized = normalizeVersion(b);

      const aVersion = semver.valid(aNormalized);
      const bVersion = semver.valid(bNormalized);

      if (aVersion && bVersion) {
        return semver.rcompare(aVersion, bVersion);
      }

      // If semver parsing fails, fall back to string comparison
      return b.localeCompare(a);
    });

    return tags.map((tag) => ({ value: tag, label: tag }));
  }

  get provisionalVersions() {
    return Object.keys(this.commitData.provisionalVersions).map((version) => ({
      value: version,
      label: version,
    }));
  }

  get sortedRefs() {
    if (!this.commitData) {
      return [];
    }

    const refs = [];

    // Add branches first
    this.branches.forEach((branch) => {
      refs.push({ ...branch, type: "branch" });
    });

    // Add tags
    this.sortedTags.forEach((tag) => {
      refs.push({ ...tag, type: "tag" });
    });

    return refs;
  }

  // Get the previous version tag from a given ref
  // Traverses git history to find the most recent tag in the parent commits
  getPreviousVersion(ref) {
    if (!this.commitData) {
      return null;
    }

    // Resolve the ref to a commit hash
    const commitHash = this.resolveRef(ref);
    if (!this.commitData.commits[commitHash]) {
      return null;
    }

    // Get all parent commits (including the ref itself)
    const parentCommits = this.traverseParents(commitHash);

    if (parentCommits.size === 0) {
      return null;
    }

    // Only consider tags from sortedTags
    let validTagValues = this.sortedTags.map((t) => t.value);
    validTagValues = validTagValues.filter(
      (tag) => !tag.match(/-latest\.\d+$/) && tag !== ref
    );

    // Find all valid tags that point to parent commits
    const matchingTags = [];
    for (const tagName of validTagValues) {
      const tagHash = this.commitData.refs.tags[tagName];
      if (tagHash && parentCommits.has(tagHash)) {
        matchingTags.push(tagName);
      }
    }

    if (matchingTags.length === 0) {
      return null;
    }

    // sortedTags is already sorted, so just return the first match
    // (since we iterate validTagValues in sorted order, matchingTags is also sorted)
    return matchingTags[0];
  }

  // Resolve a ref (tag/branch/hash) to a commit hash
  resolveRef(ref) {
    if (!this.commitData) {
      return ref;
    }

    // Check if it's a tag
    if (this.commitData.refs.tags[ref]) {
      return this.commitData.refs.tags[ref];
    }

    // Check if it's a branch
    if (this.commitData.refs.branches[ref]) {
      return this.commitData.refs.branches[ref];
    }

    // Check if it's a partial hash
    if (ref.length < 40) {
      const matches = Object.keys(this.commitData.commits).filter((h) =>
        h.startsWith(ref)
      );

      if (matches.length > 1) {
        throw new AmbiguousRefError(ref, matches);
      }

      if (matches.length === 0) {
        throw new UnknownRefError(ref);
      }

      return matches[0];
    }

    // Full hash - verify it exists
    if (!this.commitData.commits[ref]) {
      throw new UnknownRefError(ref);
    }

    return ref;
  }

  // A commit's nearest-tag version without the "+N" distance suffix.
  commitVersion(hash) {
    const version = hash && this.commitData?.commits[hash]?.version;
    return version ? version.replace(/\s*\+\d+$/, "") : null;
  }

  // Structured label for a ref, so the UI can style the parts separately.
  // Returns { name, distance, hash }:
  //   - name: the tag/branch name, or a bare hash's nearest-tag version ("v3.4.1")
  //   - distance: the "+N" commits-since-tag suffix for a bare hash, else null
  //   - hash: the resolved commit's short hash, shown for every ref
  describeRef(ref) {
    if (!this.commitData || !ref) {
      return { name: ref, distance: null, hash: null };
    }

    let hash;
    try {
      hash = this.resolveRef(ref);
    } catch {
      // Unresolvable or ambiguous ref: show it verbatim, without a hash.
      return { name: ref, distance: null, hash: null };
    }

    const shortHash = hash.substring(0, 7);

    // Named refs (tags/branches) display by their name.
    if (this.commitData.refs.tags[ref] || this.commitData.refs.branches[ref]) {
      return { name: ref, distance: null, hash: shortHash };
    }

    // Bare commit hash: show its nearest-tag version, splitting the "+N"
    // distance off so it can be de-emphasised in the UI.
    const version = this.commitData.commits[hash]?.version;
    if (!version) {
      return { name: shortHash, distance: null, hash: null };
    }

    const distanceMatch = version.match(/\s*(\+\d+)$/);
    return {
      name: `v${version.replace(/\s*\+\d+$/, "")}`,
      distance: distanceMatch ? distanceMatch[1] : null,
      hash: shortHash,
    };
  }

  // Iterative traversal to find all commits reachable from a given commit
  traverseParents(commitHash) {
    if (!this.commitData) {
      return new Set();
    }

    const visited = new Set();
    const queue = [commitHash];

    while (queue.length > 0) {
      const currentHash = queue.shift();

      // Skip if already visited or not in our dataset
      if (
        !currentHash ||
        visited.has(currentHash) ||
        !this.commitData.commits[currentHash]
      ) {
        continue;
      }

      visited.add(currentHash);
      const commit = this.commitData.commits[currentHash];

      // Add parents to queue
      if (commit.parents) {
        commit.parents.forEach((parentHash) => {
          if (!visited.has(parentHash)) {
            queue.push(parentHash);
          }
        });
      }
    }

    return visited;
  }

  // Get commits between two refs
  getCommitsBetween(startRef, endRef) {
    if (!this.commitData) {
      return [];
    }

    // Resolve refs to commit hashes
    const startHash = this.resolveRef(startRef);
    const endHash = this.resolveRef(endRef);

    // Build set of all commits reachable from startRef (exclusive set)
    const reachableFromStart = this.traverseParents(startHash);

    // Build set of all commits reachable from endRef (inclusive set)
    const reachableFromEnd = this.traverseParents(endHash);

    // Difference: commits in endRef but not in startRef
    const betweenSet = new Set(
      [...reachableFromEnd].filter((hash) => !reachableFromStart.has(hash))
    );

    // Convert to commit objects
    return [...betweenSet]
      .map((hash) => this.commitData.commits[hash])
      .filter((c) => c);
  }
}

// Normalize version tags to proper semver format
// v3.5.0.beta1 -> v3.5.0-beta.1
export function normalizeVersion(version) {
  return version.replace(/\.beta(\d+)$/, "-beta.$1");
}

// Parse a version string to a semver object, handling beta notation
export function parseVersion(version) {
  const normalized = normalizeVersion(version);
  return semver.parse(normalized);
}

export const COMMIT_TYPES = [
  { key: "FEATURE", label: "Feature", color: "#27ae60", prefix: "FEATURE" },
  { key: "FIX", label: "Fix", color: "#c0392b", prefix: "FIX" },
  { key: "PERF", label: "Performance", color: "#8e44ad", prefix: "PERF" },
  { key: "UX", label: "UX", color: "#2980b9", prefix: "UX" },
  { key: "A11Y", label: "Accessibility", color: "#16a085", prefix: "A11Y" },
  { key: "SECURITY", label: "Security", color: "#d35400", prefix: "SECURITY" },
  {
    key: "TRANSLATIONS",
    label: "Translations",
    color: "#e91e63",
    prefix: "I18N",
  },
  { key: "DEV", label: "Dev", color: "#7f8c8d", prefix: "DEV" },
  { key: "DEPS", label: "Dependencies", color: "#7f8c8d", prefix: "DEPS" },
  { key: "OTHER", label: "Other", color: "#95a5a6" },
];

// Extract commit type from subject
export function getCommitType(subject) {
  for (const type of COMMIT_TYPES) {
    if (type.prefix && subject.startsWith(`${type.prefix}:`)) {
      return type.key;
    }
  }

  // Handle legacy formats
  if (subject.startsWith("Update translations")) {
    return "TRANSLATIONS";
  }
  if (subject.startsWith("Build(deps")) {
    return "DEPS";
  }

  return "OTHER";
}

// Sort commits by date
export function sortCommitsByDate(commits, direction = "desc") {
  return [...commits].sort((a, b) => {
    const dateA = new Date(a.date);
    const dateB = new Date(b.date);
    return direction === "desc" ? dateB - dateA : dateA - dateB;
  });
}

// Count commits by type
export function countCommitsByType(commits) {
  const counts = {};
  COMMIT_TYPES.forEach((type) => (counts[type.key] = 0));

  commits.forEach((commit) => {
    const type = getCommitType(commit.subject);
    if (type && counts[type] !== undefined) {
      counts[type]++;
    } else {
      counts["OTHER"]++;
    }
  });

  return counts;
}

// Filter commits by type and/or search term
export function filterCommits(commits, { type, searchTerm } = {}) {
  let filtered = commits;

  if (type && type !== "all") {
    filtered = filtered.filter((commit) => {
      const commitType = getCommitType(commit.subject) || "OTHER";
      return commitType === type;
    });
  }

  if (searchTerm?.trim()) {
    const term = searchTerm.toLowerCase();
    filtered = filtered.filter((commit) =>
      commit.subject.toLowerCase().includes(term)
    );
  }

  return filtered;
}

// Get version range from commits
function getVersionRange(commits) {
  if (!commits.length) {
    return { newest: null, oldest: null };
  }
  const sorted = sortCommitsByDate(commits, "desc");
  return {
    newest: parseVersion(sorted[0].version?.replace(/\s*\+\d+$/, "")),
    oldest: parseVersion(sorted.at(-1).version?.replace(/\s*\+\d+$/, "")),
  };
}

// Check if a version falls within a range (exclusive start, inclusive end)
function versionInRange(version, oldest, newest) {
  const parsed = parseVersion(version);
  if (!parsed || !newest || !oldest) {
    return false;
  }
  return semver.gt(parsed, oldest) && semver.lte(parsed, newest);
}

// Filter features that fall within a commit range
export function filterFeaturesByCommits(features, commits, resolveRef) {
  if (!commits.length || !features.length) {
    return [];
  }

  const commitHashes = new Set(commits.map((c) => c.hash));
  const { newest, oldest } = getVersionRange(commits);

  return features.filter((feature) => {
    const discourseVersion = feature.discourse_version;
    if (!discourseVersion) {
      return false;
    }

    if (discourseVersion.match(/\d+\.\d+\.\d+/)) {
      return versionInRange(discourseVersion, oldest, newest);
    } else {
      const fullCommitHash = resolveRef(discourseVersion);
      return commitHashes.has(fullCommitHash);
    }
  });
}

function sameMonthlyRelease(a, b) {
  return a.major === b.major && a.minor === b.minor;
}

// GitHub range ("comma" = AND, ".betaN" shorthand) to a semver range string.
function normalizeRange(range) {
  if (!range) {
    return null;
  }
  return range.replace(/,\s*/g, " ").replace(/\.beta(\d+)/g, "-beta.$1");
}

// Each advisory entry describes one release line. Prefer the entry for the
// target's own line, so a backport-fixed version escapes a broad ">= 0".
// If the target's line has no entry (e.g. an EOL line that never received a
// backport), fall back to the unscoped mainline entries so the version is still
// matched by their range.
export function isAffectedByAdvisory(version, advisory) {
  const target = typeof version === "string" ? parseVersion(version) : version;
  if (!target) {
    return false;
  }

  const entries = (advisory.vulnerabilities || [])
    .map((vuln) => ({
      patched: vuln.patched ? parseVersion(vuln.patched) : null,
      range: normalizeRange(vuln.range),
    }))
    .filter((entry) => entry.patched);

  // Entries whose patched version shares the target's release line.
  const lineEntries = entries.filter((entry) =>
    sameMonthlyRelease(entry.patched, target)
  );
  const applicable = lineEntries.length ? lineEntries : entries;

  return applicable.some((entry) => {
    const introduced =
      !entry.range ||
      semver.satisfies(target, entry.range, { includePrerelease: true });
    return introduced && semver.lt(target, entry.patched);
  });
}

// Advisories resolved within the range: start affected, end not.
export function filterAdvisoriesByRange(advisories, startVersion, endVersion) {
  if (!advisories.length || !startVersion || !endVersion) {
    return [];
  }

  return advisories.filter(
    (advisory) =>
      isAffectedByAdvisory(startVersion, advisory) &&
      !isAffectedByAdvisory(endVersion, advisory)
  );
}
