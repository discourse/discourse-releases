import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import "./versions-table.css";
import VersionsData from "/data/version-support.json";
import { Calendar, Hash, Rocket, ShieldCheck } from "lucide";
import semver from "semver";
import eq from "../../helpers/eq.js";
import { ChangelogData } from "../../lib/git-utils.js";
import LucideIcon from "../lucide-icon";
import VersionsTimeline from "./timeline";

export default class VersionsTable extends Component {
  @tracked data = new ChangelogData();

  @tracked versionSupport = [];

  get versions() {
    if (!this.data.commitData) {
      return [];
    }

    // Get all tags and their commit info
    const versions = [];
    for (const [tagName, tagHash] of Object.entries(
      this.data.commitData.refs.tags
    )) {
      // Skip beta versions
      if (tagName.includes("beta")) {
        continue;
      }

      const commit = this.data.commitData.commits[tagHash];
      if (commit) {
        versions.push({
          version: tagName,
          date: commit.date,
          hash: tagHash,
        });
      }
    }

    // Sort by date descending (newest first)
    versions.sort((a, b) => new Date(b.date) - new Date(a.date));

    return versions;
  }

  get groupedVersions() {
    const groups = [];

    // These two older stable versions are not part of core's versions.json
    // But we want to show them on the releases site for now.
    const versionsWithExtras = {
      ...VersionsData,
      "3.5": {
        releaseDate: "2025-08-19",
        developmentStartDate: "2025-08-19",
        supportEndDate: "2026-01-28",
        esr: true,
        supported: false,
        released: true,
      },
      "3.4": {
        releaseDate: "2025-02-04",
        developmentStartDate: "2025-01-04",
        supportEndDate: "2025-08-19",
        esr: true,
        supported: false,
        released: true,
      },
    };
    const versions = Object.entries(versionsWithExtras);

    // Find the first released version index (for "release" tag)
    const firstReleasedIndex = versions.findIndex(([, data]) => data.released);

    // Find the first active ESR version index (for "ESR" tag)
    const firstActiveEsrIndex = versions.findIndex(
      ([, data]) => data.esr && data.released && data.supported
    );

    versions.forEach(([version, data], index) => {
      const parsed = semver.coerce(version);

      if (!parsed) {
        return;
      }

      // Compute status from released/supported flags
      let status;
      if (!data.released && data.supported) {
        status = "in-development";
      } else if (data.released && data.supported) {
        status = "active";
      } else if (data.released && !data.supported) {
        status = "end-of-life";
      } else {
        // Skip versions that are not released and not supported
        return;
      }

      // Compute tags
      const tags = [];
      if (status === "in-development") {
        tags.push("latest");
      } else if (status === "active" && index === firstReleasedIndex) {
        tags.push("release");
      }
      if (index === firstActiveEsrIndex) {
        tags.push("ESR");
      }

      const supportInfo = {
        ...data,
        version,
        status,
        tags,
      };

      const group = {
        minorVersion: version,
        supportInfo,
        versions: [],
        latestSemver: parsed,
      };

      // Find all matching git versions for this minor
      const gitVersions = this.versions;
      const matchingVersions = gitVersions.filter((v) => {
        const vParsed = semver.coerce(v.version);
        if (!vParsed) {
          return false;
        }
        return vParsed.major === parsed.major && vParsed.minor === parsed.minor;
      });

      // Add matching versions
      matchingVersions.forEach((v) => {
        const vParsed = semver.coerce(v.version);
        group.versions.push({
          ...v,
          parsed: vParsed,
        });

        if (semver.gt(vParsed, group.latestSemver)) {
          group.latestSemver = vParsed;
        }
      });

      // Sort versions by semver descending
      group.versions.sort((a, b) => semver.rcompare(a.parsed, b.parsed));

      // Set header version - always use the release date from versions data
      group.headerVersion = {
        version: `v${version}.0`,
        date: data.releaseDate,
      };

      groups.push(group);
    });

    // Sort groups by latest version descending
    groups.sort((a, b) => semver.rcompare(a.latestSemver, b.latestSemver));

    return groups;
  }

  formatDate(isoString) {
    // Check if it's yyyy-mm format (no day)
    if (/^\d{4}-\d{2}$/.test(isoString)) {
      const [year, month] = isoString.split("-");
      const date = new Date(year, parseInt(month, 10) - 1, 1);
      return date.toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
      });
    }

    // Otherwise it's yyyy-mm-dd format
    const date = new Date(isoString);
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  isPlannedDate(isoString) {
    if (!isoString) {
      return false;
    }

    // If it's yyyy-mm format (imprecise), always consider it "planned"
    if (/^\d{4}-\d{2}$/.test(isoString)) {
      return true;
    }

    // Otherwise it's yyyy-mm-dd format - check if it's in the future
    const date = new Date(isoString);
    const now = new Date();
    return date > now;
  }

  getVersionDateLabel(version) {
    if (version.includes("-latest")) {
      return "started";
    }
    return "released";
  }

  <template>
    <div class="versions-container">
      <div class="versions-page-lead">
        <h1 class="versions-page-headline">Discourse Releases</h1>
        <p class="versions-intro">
          Browse release dates, support timelines, and changelogs for every
          stable version.
        </p>
      </div>

      <VersionsTimeline @versions={{this.groupedVersions}} />

      <div class="version-info-tiles">
        <article class="version-info-tile">
          <h3 class="version-info-tile-title">
            <LucideIcon @icon={{Rocket}} @iconClass="version-info-tile-icon" />
            Latest version
          </h3>
          <p>
            Most Discourse installations track the
            <strong>latest</strong>
            version, which receives continuous updates with new features, bug
            fixes, and security patches.
          </p>
        </article>
        <article class="version-info-tile">
          <h3 class="version-info-tile-title">
            <LucideIcon @icon={{Hash}} @iconClass="version-info-tile-icon" />
            Numbered releases
          </h3>
          <p>
            Numbered releases are available for those who prefer less frequent
            changes.
          </p>
        </article>
        <article class="version-info-tile">
          <h3 class="version-info-tile-title">
            <LucideIcon @icon={{Calendar}} @iconClass="version-info-tile-icon" />
            Monthly releases
          </h3>
          <p>
            Each monthly release receives security updates for approximately two
            months.
          </p>
        </article>
        <article class="version-info-tile">
          <h3 class="version-info-tile-title">
            <LucideIcon @icon={{ShieldCheck}} @iconClass="version-info-tile-icon" />
            Extended Support Release (ESR)
          </h3>
          <p>
            Every 6 months, an ESR is designated, which receives updates for
            approximately 8 months.
          </p>
        </article>
      </div>

      <div class="versions-cards">
        {{#each this.groupedVersions as |group|}}
          <div
            id="version-{{group.minorVersion}}"
            class="version-card
              {{if
                (eq group.supportInfo.status 'in-development')
                'in-development-version'
              }}
              {{if (eq group.supportInfo.status 'active') 'active-version'}}
              {{if (eq group.supportInfo.status 'end-of-life') 'eol-version'}}"
          >
            <div class="card-header">
              <div class="version-title">
                <LinkTo
                  @route="changelog"
                  @model={{group.headerVersion.version}}
                  class="version-link"
                >v{{group.minorVersion}}</LinkTo>
                {{#each group.supportInfo.tags as |tag|}}
                  <span class="version-tag">{{tag}}</span>
                {{/each}}
              </div>
              <div
                class="status-badge support-status-{{group.supportInfo.status}}"
              >
                {{#if (eq group.supportInfo.status "in-development")}}
                  Active development
                {{else if (eq group.supportInfo.status "active")}}
                  Supported
                {{else if (eq group.supportInfo.status "end-of-life")}}
                  End of life
                {{/if}}
              </div>
            </div>

            <div class="card-body">
              <div class="card-row">
                <div class="card-label">
                  {{#if (this.isPlannedDate group.headerVersion.date)}}
                    Planned release
                  {{else}}
                    First released
                  {{/if}}
                </div>
                <div class="card-value">
                  {{this.formatDate group.headerVersion.date}}
                </div>
              </div>

              <div class="card-row">
                <div class="card-label">
                  {{#if (this.isPlannedDate group.supportInfo.supportEndDate)}}
                    Planned end of life
                  {{else}}
                    End of Life
                  {{/if}}
                </div>
                <div class="card-value">
                  {{#if group.supportInfo.supportEndDate}}
                    {{this.formatDate group.supportInfo.supportEndDate}}
                    {{#if group.supportInfo.esr}}
                      <span class="esr-note">(ESR)</span>
                    {{/if}}
                  {{else}}
                    <span class="muted-text">—</span>
                  {{/if}}
                </div>
              </div>
            </div>

            {{#if group.versions.length}}
              <div class="patch-versions">
                {{#each group.versions as |v|}}
                  <div class="patch-version-row">
                    <LinkTo
                      @route="changelog"
                      @model={{v.version}}
                      class="patch-version-link"
                    >{{v.version}}</LinkTo>
                    <span class="version-date">
                      {{this.getVersionDateLabel v.version}}
                      {{this.formatDate v.date}}
                    </span>
                  </div>
                {{/each}}
              </div>
            {{/if}}
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
