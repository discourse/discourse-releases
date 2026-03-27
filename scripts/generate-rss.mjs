/* eslint-disable no-console */

import { XMLBuilder } from "fast-xml-parser";
import { writeFile } from "fs/promises";
import commitsData from "../data/commits.json" with { type: "json" };

const SITE_URL = "https://releases.discourse.org";

function formatRfc822Date(isoDate) {
  const date = new Date(isoDate);
  return date.toUTCString();
}

function generateRss() {
  // Get all release tags (exclude beta versions)
  const releases = [];

  for (const [tag, hash] of Object.entries(commitsData.refs.tags)) {
    // Skip beta versions
    if (tag.includes("beta")) {
      continue;
    }

    const commit = commitsData.commits[hash];
    if (!commit) {
      continue;
    }

    releases.push({
      version: tag,
      date: commit.date,
      hash,
    });
  }

  // Sort by release date descending (newest first)
  releases.sort((a, b) => new Date(b.date) - new Date(a.date));

  // Limit to most recent 50 releases
  const recentReleases = releases.slice(0, 50);

  const items = recentReleases.map((release) => {
    const link = `${SITE_URL}/changelog/${release.version}`;
    const action = release.version.includes("-latest") ? "started" : "released";
    return {
      title: `Discourse ${release.version} ${action}`,
      link,
      guid: link,
      pubDate: formatRfc822Date(release.date),
    };
  });

  const feed = {
    "?xml": { "@_version": "1.0", "@_encoding": "UTF-8" },
    rss: {
      "@_version": "2.0",
      "@_xmlns:atom": "http://www.w3.org/2005/Atom",
      channel: {
        title: "Discourse Releases",
        link: SITE_URL,
        description: "Release notifications for Discourse",
        language: "en-us",
        "atom:link": {
          "@_href": `${SITE_URL}/feed.xml`,
          "@_rel": "self",
          "@_type": "application/rss+xml",
        },
        item: items,
      },
    },
  };

  const builder = new XMLBuilder({
    ignoreAttributes: false,
    format: true,
    indentBy: "  ",
  });

  return builder.build(feed);
}

const rss = generateRss();
await writeFile("dist/feed.xml", rss);
console.log("Generated: /feed.xml");
