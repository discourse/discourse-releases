import Component from '@glimmer/component';
import { service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { GitHubAPI } from '../lib/github-api';
import CommitCard from './commit-card';

export default class CommitViewer extends Component {
  @service router;
  @tracked commits = [];
  @tracked isLoading = false;
  @tracked error = null;
  @tracked startCommit = '';
  @tracked endCommit = '';

  githubAPI = new GitHubAPI();

  constructor() {
    super(...arguments);
    this.loadQueryParams();
  }

  loadQueryParams() {
    const queryParams = this.router.currentRoute.queryParams;
    this.startCommit = queryParams.start || 'beta';
    this.endCommit = queryParams.end || '';

    if (this.startCommit) {
      this.fetchCommits();
    }
  }

  @action
  updateStartCommit(event) {
    this.startCommit = event.target.value;
    this.updateQueryParams();
  }

  @action
  updateEndCommit(event) {
    this.endCommit = event.target.value;
    this.updateQueryParams();
  }

  @action
  async fetchCommits() {
    if (!this.startCommit.trim()) {
      this.error = 'Start commit/tag is required';
      return;
    }

    this.isLoading = true;
    this.error = null;
    this.commits = [];

    try {
      const rawCommits = await this.githubAPI.getCommitsBetween(
        this.startCommit.trim(),
        this.endCommit.trim() || 'HEAD'
      );

      this.commits = rawCommits.map((commit) =>
        this.githubAPI.formatCommit(commit)
      );
    } catch (error) {
      this.error = `Failed to fetch commits: ${error.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  updateQueryParams() {
    const queryParams = {};
    if (this.startCommit) queryParams.start = this.startCommit;
    if (this.endCommit) queryParams.end = this.endCommit;

    this.router.transitionTo({ queryParams });
  }

  get formattedCommitCount() {
    return this.commits.length === 1
      ? '1 commit'
      : `${this.commits.length} commits`;
  }

  <template>
    <div class="commit-viewer">
      <div class="header">
        <h1>Discourse Commit Viewer</h1>
        <p>View commits between two commit hashes in the Discourse repository</p>
      </div>

      <div class="form-section">
        <div class="input-group">
          <label for="start-commit">Start Commit/Tag:</label>
          <input
            id="start-commit"
            type="text"
            value={{this.startCommit}}
            placeholder="e.g., latest, v3.0.0, abc123de..."
            {{on "input" this.updateStartCommit}}
          />
          <small class="input-help">Use 'latest' for the most recent Discourse
            release</small>
        </div>

        <div class="input-group">
          <label for="end-commit">End Commit/Tag (optional):</label>
          <input
            id="end-commit"
            type="text"
            value={{this.endCommit}}
            placeholder="e.g., HEAD, main, def456gh... (defaults to HEAD)"
            {{on "input" this.updateEndCommit}}
          />
          <small class="input-help">Defaults to HEAD (latest main branch commit)</small>
        </div>

        <button
          type="button"
          class="fetch-button"
          disabled={{this.isLoading}}
          {{on "click" this.fetchCommits}}
        >
          {{#if this.isLoading}}
            Loading...
          {{else}}
            Fetch Commits
          {{/if}}
        </button>
      </div>

      {{#if this.error}}
        <div class="error">
          {{this.error}}
        </div>
      {{/if}}

      {{#if this.commits.length}}
        <div class="results-header">
          <h2>{{this.formattedCommitCount}} found</h2>
        </div>

        <div class="commits-list">
          {{#each this.commits as |commit|}}
            <CommitCard @commit={{commit}} />
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
