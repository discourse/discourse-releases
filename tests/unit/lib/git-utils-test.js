import { module, test } from "qunit";
import {
  AmbiguousRefError,
  ChangelogData,
  filterAdvisoriesByRange,
  isAffectedByAdvisory,
  UnknownRefError,
} from "discourse-releases/lib/git-utils";

module("Unit | Lib | git-utils | resolveRef", function () {
  function createChangelogData(commits, refs = {}) {
    const data = new ChangelogData();
    data.commitData = {
      commits,
      refs: {
        tags: refs.tags || {},
        branches: refs.branches || {},
      },
    };
    return data;
  }

  test("resolves tag to commit hash", function (assert) {
    const data = createChangelogData(
      { abc123def456: { subject: "commit" } },
      { tags: { "v1.0.0": "abc123def456" } }
    );

    assert.strictEqual(data.resolveRef("v1.0.0"), "abc123def456");
  });

  test("resolves branch to commit hash", function (assert) {
    const data = createChangelogData(
      { abc123def456: { subject: "commit" } },
      { branches: { main: "abc123def456" } }
    );

    assert.strictEqual(data.resolveRef("main"), "abc123def456");
  });

  test("resolves full hash to itself", function (assert) {
    const fullHash = "abc123def456abc123def456abc123def456abcd";
    const data = createChangelogData({ [fullHash]: { subject: "commit" } });

    assert.strictEqual(data.resolveRef(fullHash), fullHash);
  });

  test("resolves partial hash to full hash", function (assert) {
    const fullHash = "abc123def456abc123def456abc123def456abcd";
    const data = createChangelogData({ [fullHash]: { subject: "commit" } });

    assert.strictEqual(data.resolveRef("abc123"), fullHash);
  });

  test("throws UnknownRefError for unmatched partial hash", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "commit" },
    });

    assert.throws(
      () => data.resolveRef("xyz789"),
      UnknownRefError,
      "throws UnknownRefError for unknown partial hash"
    );
  });

  test("throws UnknownRefError for unmatched full hash", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "commit" },
    });

    const unknownFullHash = "ffffffffffffffffffffffffffffffffffffffff";
    assert.throws(
      () => data.resolveRef(unknownFullHash),
      UnknownRefError,
      "throws UnknownRefError for unknown full hash"
    );
  });

  test("UnknownRefError contains ref", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "commit" },
    });

    try {
      data.resolveRef("xyz789");
      assert.true(false, "should have thrown");
    } catch (error) {
      assert.strictEqual(error.name, "UnknownRefError");
      assert.strictEqual(error.ref, "xyz789");
      assert.true(error.message.includes("xyz789"));
    }
  });

  test("throws AmbiguousRefError when partial hash matches multiple commits", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "first" },
      abc123fff456abc123def456abc123def456abcd: { subject: "second" },
      abc123ggg456abc123def456abc123def456abcd: { subject: "third" },
    });

    assert.throws(
      () => data.resolveRef("abc123"),
      AmbiguousRefError,
      "throws AmbiguousRefError"
    );
  });

  test("AmbiguousRefError contains ref and matches", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "first" },
      abc123fff456abc123def456abc123def456abcd: { subject: "second" },
    });

    try {
      data.resolveRef("abc123");
      assert.true(false, "should have thrown");
    } catch (error) {
      assert.strictEqual(error.name, "AmbiguousRefError");
      assert.strictEqual(error.ref, "abc123");
      assert.strictEqual(error.matches.length, 2);
      assert.true(error.message.includes("abc123"));
      assert.true(error.message.includes("2 commits"));
    }
  });

  test("AmbiguousRefError message truncates long match lists", function (assert) {
    const commits = {};
    for (let i = 0; i < 10; i++) {
      const hash = `abc${i.toString().padStart(37, "0")}`;
      commits[hash] = { subject: `commit ${i}` };
    }
    const data = createChangelogData(commits);

    try {
      data.resolveRef("abc");
      assert.true(false, "should have thrown");
    } catch (error) {
      assert.true(error.message.includes("10 commits"));
      assert.true(error.message.includes("and 5 more"));
    }
  });

  test("longer partial hash resolves uniquely", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "first" },
      abc123fff456abc123def456abc123def456abcd: { subject: "second" },
    });

    assert.strictEqual(
      data.resolveRef("abc123d"),
      "abc123def456abc123def456abc123def456abcd"
    );
    assert.strictEqual(
      data.resolveRef("abc123f"),
      "abc123fff456abc123def456abc123def456abcd"
    );
  });

  test("tag takes precedence over partial hash match", function (assert) {
    const data = createChangelogData(
      {
        abc123def456abc123def456abc123def456abcd: { subject: "commit" },
        fff999def456abc123def456abc123def456abcd: { subject: "tagged" },
      },
      { tags: { abc123: "fff999def456abc123def456abc123def456abcd" } }
    );

    assert.strictEqual(
      data.resolveRef("abc123"),
      "fff999def456abc123def456abc123def456abcd"
    );
  });
});

module("Unit | Lib | git-utils | describeRef", function () {
  const HASH = "0a7a0dcffba482acdf3140335a7b80d37fac6df2";

  function createData() {
    const data = new ChangelogData();
    data.commitData = {
      commits: { [HASH]: { version: "3.4.1 +4", parents: [] } },
      refs: {
        tags: { "v2026.6.0": "1111111111111111111111111111111111111111" },
        branches: { latest: "2222222222222222222222222222222222222222" },
      },
    };
    return data;
  }

  test("splits version, distance, and hash for a partial commit hash", function (assert) {
    assert.deepEqual(createData().describeRef("0a7a0dc"), {
      name: "v3.4.1",
      distance: "+4",
      hash: "0a7a0dc",
    });
  });

  test("splits version, distance, and hash for a full commit hash", function (assert) {
    assert.deepEqual(createData().describeRef(HASH), {
      name: "v3.4.1",
      distance: "+4",
      hash: "0a7a0dc",
    });
  });

  test("shows a tag ref by name with its short hash", function (assert) {
    assert.deepEqual(createData().describeRef("v2026.6.0"), {
      name: "v2026.6.0",
      distance: null,
      hash: "1111111",
    });
  });

  test("shows a branch ref by name with its short hash", function (assert) {
    assert.deepEqual(createData().describeRef("latest"), {
      name: "latest",
      distance: null,
      hash: "2222222",
    });
  });

  test("returns an unresolvable ref as-is with no hash", function (assert) {
    assert.deepEqual(createData().describeRef("zzzzzz"), {
      name: "zzzzzz",
      distance: null,
      hash: null,
    });
  });
});

// Mirrors a real advisory: mainline fixed at 2026.6.0, backported to 2026.5/4/1.
const advisory = {
  ghsa_id: "GHSA-test",
  vulnerabilities: [
    { range: ">= 0", patched: "2026.6.0" },
    { range: ">= 2026.5.0-latest", patched: "2026.5.1" },
    { range: ">= 2026.4.0-latest", patched: "2026.4.2" },
    { range: ">= 2026.1.0-latest", patched: "2026.1.5" },
  ],
};

module("Unit | Lib | git-utils | isAffectedByAdvisory", function () {
  test("a version below its line's patch is affected", function (assert) {
    assert.true(isAffectedByAdvisory("2026.5.0", advisory));
  });

  test("a version at its line's patch is not affected", function (assert) {
    assert.false(isAffectedByAdvisory("2026.5.1", advisory));
  });

  test("a later version on a patched line is not affected", function (assert) {
    assert.false(isAffectedByAdvisory("2026.5.2", advisory));
  });

  test("the mainline patch version is not affected", function (assert) {
    assert.false(isAffectedByAdvisory("2026.6.0", advisory));
  });

  test("an in-development mainline prerelease is affected", function (assert) {
    assert.true(isAffectedByAdvisory("2026.6.0-latest.3", advisory));
  });

  test("a broad mainline entry does not mark a backported stable version as affected", function (assert) {
    assert.false(isAffectedByAdvisory("2026.5.1", advisory));
  });

  test("a version on a line the advisory never patched falls back to the mainline entry", function (assert) {
    // 2026.3 got no dedicated backport, so it falls back to the ">= 0" mainline
    // entry (patched 2026.6.0) and is still below that fix, hence affected. This
    // is what lets an old/EOL start version surface fixes resolved later.
    assert.true(isAffectedByAdvisory("2026.3.0", advisory));
  });

  test("an old EOL version with no matching line is affected via the mainline entry", function (assert) {
    assert.true(isAffectedByAdvisory("3.4.1", advisory));
  });
});

module("Unit | Lib | git-utils | filterAdvisoriesByRange", function () {
  test("lists an advisory resolved within the range", function (assert) {
    const result = filterAdvisoriesByRange([advisory], "2026.5.0", "2026.6.0");

    assert.deepEqual(
      result.map((a) => a.ghsa_id),
      ["GHSA-test"],
      "start is affected and end is patched"
    );
  });

  test("hides an advisory already backported to the start version", function (assert) {
    const result = filterAdvisoriesByRange([advisory], "2026.5.1", "2026.6.0");

    assert.deepEqual(
      result.map((a) => a.ghsa_id),
      [],
      "the fix was already present in 2026.5.1"
    );
  });

  test("hides an advisory whose fix is not yet in the end version", function (assert) {
    const result = filterAdvisoriesByRange([advisory], "2026.4.0", "2026.4.1");

    assert.deepEqual(
      result.map((a) => a.ghsa_id),
      [],
      "end is still below the 2026.4.2 patch"
    );
  });

  test("resolves an advisory on a backported stable line", function (assert) {
    const result = filterAdvisoriesByRange([advisory], "2026.4.1", "2026.4.2");

    assert.deepEqual(
      result.map((a) => a.ghsa_id),
      ["GHSA-test"],
      "the stable-line backport is recognised as the resolving version"
    );
  });

  test("returns nothing when an endpoint version is missing", function (assert) {
    assert.deepEqual(
      filterAdvisoriesByRange([advisory], null, "2026.6.0"),
      [],
      "an unresolved endpoint yields no advisories"
    );
  });
});

module("Unit | Lib | git-utils | commitVersion", function () {
  function createChangelogData(commits, refs = {}) {
    const data = new ChangelogData();
    data.commitData = {
      commits,
      refs: { tags: refs.tags || {}, branches: refs.branches || {} },
    };
    return data;
  }

  test("returns a commit's version stripped of its distance suffix", function (assert) {
    const hash = "abc123def456abc123def456abc123def456abcd";
    const data = createChangelogData(
      { [hash]: { version: "2026.6.0 +12" } },
      { tags: { "v2026.6.0": hash }, branches: { latest: hash } }
    );

    assert.strictEqual(data.commitVersion(hash), "2026.6.0", "by hash");
    assert.strictEqual(
      data.commitVersion(data.resolveRef("v2026.6.0")),
      "2026.6.0",
      "by tag"
    );
    assert.strictEqual(
      data.commitVersion(data.resolveRef("latest")),
      "2026.6.0",
      "by branch"
    );
  });

  test("returns null for an unknown hash", function (assert) {
    const data = createChangelogData({});
    assert.strictEqual(data.commitVersion("deadbeef"), null);
  });
});
