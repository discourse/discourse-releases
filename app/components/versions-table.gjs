import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn, get } from '@ember/helper';
import { ChangelogData } from '../lib/git-utils.js';
import semver from 'semver';
import VersionsTimeline from './versions-timeline.gjs';

const eq = (a, b) => a === b;

export default class VersionsTable extends Component {
  @tracked data = new ChangelogData();
  @tracked versionSupport = [];

  constructor() {
    super(...arguments);
    this.loadData();
  }

  async loadData() {
    try {
      await this.data.load();
      const supportModule = await import('/data/version-support.json');
      this.versionSupport = supportModule.default;
    } catch (error) {
      console.error('Failed to load data:', error);
    }
  }

  get versions() {
    if (!this.data.commitData) return [];

    // Get all tags and their commit info
    const versions = [];
    for (const [tagName, tagHash] of Object.entries(
      this.data.commitData.refs.tags
    )) {
      // Skip tags ending with -latest
      if (tagName.endsWith('-latest')) continue;

      // Skip beta versions
      if (tagName.includes('beta')) continue;

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

    // Use version-support.json as the source of truth
    this.versionSupport.forEach((supportEntry) => {
      // Extract the display version (with leading zeros preserved)
      const displayMatch = supportEntry.version.match(/v?(\d+\.\d+)/);
      const displayMinorKey = displayMatch ? displayMatch[1] : null;

      if (!displayMinorKey) return;

      // Normalize version for semver parsing
      // Add .0 patch version if not present, and remove leading zeros in minor
      let normalizedVersion = supportEntry.version.replace(/^v/, ''); // Remove v prefix
      if (!/\.\d+$/.test(normalizedVersion) || normalizedVersion.split('.').length === 2) {
        normalizedVersion += '.0'; // Add .0 patch version
      }
      normalizedVersion = normalizedVersion.replace(/\.0(\d)/, '.$1'); // Remove leading zeros
      const parsed = semver.coerce(normalizedVersion);

      if (!parsed) return;

      const group = {
        minorVersion: displayMinorKey,
        supportInfo: supportEntry,
        versions: [],
        latestSemver: parsed,
      };

      // If this is an upcoming or in-development version, just add the placeholder
      if (supportEntry.status === 'upcoming' || supportEntry.status === 'in-development') {
        group.versions.push({
          version: supportEntry.version,
          date: supportEntry.releaseDate,
          hash: null,
          parsed,
          isUpcoming: true,
        });
        group.headerVersion = group.versions[0];
      } else {
        // For released versions, find all matching patch versions from git
        const gitVersions = this.versions;
        const matchingVersions = gitVersions.filter((v) => {
          const vParsed = semver.coerce(v.version);
          if (!vParsed) return false;
          // Match major.minor
          return vParsed.major === parsed.major && vParsed.minor === parsed.minor;
        });

        // Add all matching versions
        matchingVersions.forEach((v) => {
          const vParsed = semver.coerce(v.version);
          group.versions.push({
            ...v,
            parsed: vParsed,
          });

          // Track latest
          if (semver.gt(vParsed, group.latestSemver)) {
            group.latestSemver = vParsed;
          }
        });

        // Sort versions by semver descending
        group.versions.sort((a, b) => semver.rcompare(a.parsed, b.parsed));

        // Find the .0 version for the group header
        const dotZeroVersion = group.versions.find((v) => {
          const match = v.version.match(/^v?\d+\.\d+\.0$/);
          return match;
        });
        group.headerVersion = dotZeroVersion || group.versions[0];

        // Override with the release date from version-support.json for consistency
        if (group.headerVersion && supportEntry.releaseDate) {
          group.headerVersion = {
            ...group.headerVersion,
            date: supportEntry.releaseDate
          };
        }
      }

      groups.push(group);
    });

    // Sort groups by latest version descending
    groups.sort((a, b) => semver.rcompare(a.latestSemver, b.latestSemver));

    return groups;
  }

  formatDate(isoString) {
    // Check if it's yyyy-mm format (no day)
    if (/^\d{4}-\d{2}$/.test(isoString)) {
      const [year, month] = isoString.split('-');
      const date = new Date(year, parseInt(month) - 1, 1);
      return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long'
      });
    }

    // Otherwise it's yyyy-mm-dd format
    const date = new Date(isoString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }

  getRelativeTime(isoString) {
    const date = new Date(isoString);
    const now = new Date();
    const diffInMs = now - date;
    const diffInDays = Math.floor(diffInMs / (1000 * 60 * 60 * 24));

    if (diffInDays === 0) {
      return 'today';
    } else if (diffInDays === 1) {
      return '1 day ago';
    } else if (diffInDays < 30) {
      return `${diffInDays} days ago`;
    } else if (diffInDays < 60) {
      return '1 month ago';
    } else if (diffInDays < 365) {
      const months = Math.floor(diffInDays / 30);
      return `${months} months ago`;
    } else if (diffInDays < 730) {
      return '1 year ago';
    } else {
      const years = Math.floor(diffInDays / 365);
      return `${years} years ago`;
    }
  }

  isPlannedDate(isoString) {
    if (!isoString) return false;

    // If it's yyyy-mm format (imprecise), always consider it "planned"
    if (/^\d{4}-\d{2}$/.test(isoString)) {
      return true;
    }

    // Otherwise it's yyyy-mm-dd format - check if it's in the future
    const date = new Date(isoString);
    const now = new Date();
    return date > now;
  }

  <template>
    <div class="versions-container">
      <div class="header">
        <h1>Discourse Changelog</h1>
        <p>Browse the release history and changes for Discourse</p>
      </div>

      {{#if this.data.isLoading}}
        <div class="loading">Loading versions...</div>
      {{else}}
        <div class="version-info">
          <p>
            Discourse releases new versions every month, which are supported with critical bug fixes and security updates for approximately two months.
            Every 6 months, one of those releases is designated as an Extended Support Release (ESR) version. This will be supported for approximately 8 months, providing an option for users who prefer less frequent updates.
          </p>
          <p>
            Below is a timeline and list of Discourse versions, their release dates, end-of-life dates, and support status. Click on a version to view its changelog.
          </p>
        </div>

        <VersionsTimeline @versions={{this.groupedVersions}} />

        <div class="versions-cards">
          {{#each this.groupedVersions as |group|}}
            <div id="version-{{group.minorVersion}}" class="version-card {{if (eq group.supportInfo.status 'upcoming') 'upcoming-version'}} {{if (eq group.supportInfo.status 'in-development') 'in-development-version'}} {{if (eq group.supportInfo.status 'active') 'active-version'}} {{if (eq group.supportInfo.status 'end-of-life') 'eol-version'}} {{if group.supportInfo.isESR 'esr-version'}}">
              <div class="card-header">
                <div class="version-title">
                  {{#if (eq group.supportInfo.status "in-development")}}
                    <a href="/changelog/latest" class="version-link">v{{group.minorVersion}}</a>
                  {{else if (eq group.supportInfo.status "upcoming")}}
                    <span class="version-name">v{{group.minorVersion}}</span>
                  {{else}}
                    <a href="/changelog/{{group.headerVersion.version}}" class="version-link">v{{group.minorVersion}}</a>
                  {{/if}}
                  {{#if group.supportInfo.isESR}}
                    <span class="esr-indicator">ESR</span>
                  {{/if}}
                </div>
                <div class="status-badge support-status-{{group.supportInfo.status}}">
                  {{#if (eq group.supportInfo.status "in-development")}}
                    Active development
                  {{else if (eq group.supportInfo.status "active")}}
                    Supported
                  {{else if (eq group.supportInfo.status "end-of-life")}}
                    End of Life
                  {{else if (eq group.supportInfo.status "upcoming")}}
                    Upcoming
                  {{/if}}
                </div>
              </div>

              <div class="card-body">
                <div class="card-row">
                  <div class="card-label">
                    {{#if (this.isPlannedDate group.headerVersion.date)}}
                      Planned release
                    {{else}}
                      Released
                    {{/if}}
                  </div>
                  <div class="card-value">
                    {{#if (eq group.supportInfo.status "in-development")}}
                      <span class="upcoming-date">{{this.formatDate group.headerVersion.date}}</span>
                    {{else if (eq group.supportInfo.status "upcoming")}}
                      <span class="upcoming-date">{{this.formatDate group.headerVersion.date}}</span>
                    {{else}}
                      <span class="relative-date">
                        {{this.getRelativeTime group.headerVersion.date}}
                        <span class="date-badge">{{this.formatDate group.headerVersion.date}}</span>
                      </span>
                    {{/if}}
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
                    {{else}}
                      <span class="muted-text">—</span>
                    {{/if}}
                  </div>
                </div>
              </div>

              {{#unless (eq group.supportInfo.status "upcoming")}}
                {{#unless (eq group.supportInfo.status "in-development")}}
                  <div class="patch-versions">
                    {{#each group.versions as |v|}}
                      <div class="patch-version-row">
                        <a href="/changelog/{{v.version}}" class="patch-version-link">{{v.version}}</a>
                        <span class="relative-date">
                          {{this.getRelativeTime v.date}}
                          <span class="date-badge">{{this.formatDate v.date}}</span>
                        </span>
                      </div>
                    {{/each}}
                  </div>
                {{/unless}}
              {{/unless}}
            </div>
          {{/each}}
        </div>
      {{/if}}
    </div>

    <style>
      .versions-container {
        max-width: 900px;
        margin: 0 auto;
        padding: 1.5rem 1rem;
      }

      .header {
        margin-bottom: 2rem;
        text-align: center;
      }

      .header h1 {
        font-size: 2.5rem;
        margin-bottom: 0.5rem;
      }

      .header p {
        color: var(--text-secondary);
        font-size: 1.1rem;
      }

      .version-info {
        background: var(--bg-card);
        border-radius: 8px;
        padding: 1.5rem;
        margin-bottom: 2rem;
        box-shadow: var(--shadow-sm);
      }

      .version-info p {
        margin: 0 0 1rem 0;
        line-height: 1.7;
        color: var(--text-primary);
      }

      .version-info p:last-child {
        margin-bottom: 0;
      }

      .loading {
        text-align: center;
        padding: 2rem;
        color: var(--text-secondary);
      }

      .versions-cards {
        display: flex;
        flex-direction: column;
        gap: 0.75rem;
      }

      .version-card {
        background: var(--bg-card);
        border-radius: 6px;
        box-shadow: var(--shadow-sm);
        overflow: hidden;
        transition: box-shadow 0.2s, transform 0.2s;
        scroll-margin-top: 20px;
      }

      .version-card:hover {
        box-shadow: var(--shadow-hover);
      }

      .version-card:target {
        box-shadow: oklch(from var(--color-active-development) l c h / 0.3) 0 4px 12px;
        transform: scale(1.01);
      }

      .card-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.75rem 1rem;
        border-bottom: 1px solid var(--border-subtle);
      }

      .version-title {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        font-size: 1.25rem;
        font-weight: 600;
      }

      .version-link {
        color: var(--text-link);
        text-decoration: none;
      }

      .version-link:hover {
        text-decoration: underline;
      }

      .version-name {
        color: var(--text-primary);
      }

      .status-badge {
        padding: 0.3rem 0.6rem;
        border-radius: 4px;
        font-size: 0.8rem;
        font-weight: 600;
        white-space: nowrap;
      }

      .card-body {
        padding: 0.75rem 1rem;
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
      }

      .card-row {
        display: flex;
        justify-content: space-between;
        align-items: center;
      }

      .card-label {
        color: var(--text-secondary);
        font-size: 0.85rem;
        font-weight: 500;
      }

      .card-value {
        font-weight: 500;
        font-size: 0.9rem;
      }

      .card-value a {
        color: var(--text-link);
        text-decoration: none;
      }

      .card-value a:hover {
        text-decoration: underline;
      }

      .muted-text {
        color: var(--text-muted);
      }

      .patch-versions {
        border-top: 1px solid var(--border-subtle);
        padding: 0.5rem 1rem;
        background: var(--bg-subtle);
      }

      .patch-version-row {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.35rem 0;
      }

      .patch-version-link {
        color: var(--text-link);
        text-decoration: none;
        font-size: 0.9rem;
      }

      .patch-version-link:hover {
        text-decoration: underline;
      }

      .version-card.eol-version .card-header {
        background: oklch(from var(--color-end-of-life) l c h / 0.15);
      }

      .version-card.eol-version {
        opacity: 0.8;
      }

      .version-card.active-version .card-header {
        background: oklch(from var(--color-supported) l c h / 0.2);
      }

      .version-card.in-development-version .card-header {
        background: oklch(from var(--color-active-development) l c h / 0.2);
      }

      .esr-indicator {
        margin-left: 0.5rem;
        display: inline-block;
        padding: 0.15rem 0.4rem;
        background: var(--color-esr);
        color: white;
        font-size: 0.7rem;
        font-weight: 600;
        border-radius: 3px;
        vertical-align: middle;
      }

      .version-card.eol-version .esr-indicator {
        background: var(--color-end-of-life);
      }

      .support-status-active {
        background: var(--color-supported);
        color: white;
      }

      .support-status-end-of-life {
        background: var(--color-end-of-life);
        color: white;
      }

      .support-status-in-development {
        background: var(--color-active-development);
        color: white;
      }

      .relative-date {
        display: flex;
        align-items: center;
        gap: 0.4rem;
        font-size: 0.9rem;
      }

      .date-badge {
        display: inline-block;
        padding: 0.1rem 0.4rem;
        background: var(--bg-subtle);
        color: var(--text-secondary);
        font-size: 0.75rem;
        border-radius: 3px;
        font-weight: normal;
      }
    </style>
  </template>
}
