import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import "./security-fixes-summary.css";

export default class SecurityFixesSummary extends Component {
  @tracked isExpanded = false;

  toggleExpanded = () => {
    this.isExpanded = !this.isExpanded;
  };

  get count() {
    return this.args.advisories?.length || 0;
  }

  get label() {
    return this.count === 1 ? "1 security fix" : `${this.count} security fixes`;
  }

  getCveDisplay(advisory) {
    return advisory.cve_id || "(CVE Pending)";
  }

  <template>
    <div class="security-fixes-summary {{if this.isExpanded 'expanded'}}">
      <button
        type="button"
        class="summary-header"
        {{on "click" this.toggleExpanded}}
      >
        <div class="summary-icon">
          <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
            <path
              d="M12 2L4 5v6.09c0 5.05 3.41 9.76 8 10.91 4.59-1.15 8-5.86 8-10.91V5l-8-3zm-1 6h2v2h-2V8zm0 4h2v6h-2v-6z"
            />
          </svg>
        </div>
        <span class="summary-label">{{this.label}}</span>
        <span class="expand-toggle">{{if this.isExpanded "Hide" "Show"}}</span>
      </button>

      {{#if this.isExpanded}}
        <ul class="advisories-list">
          {{#each @advisories as |advisory|}}
            <li class="advisory-item">
              <span class="advisory-cve">{{this.getCveDisplay advisory}}</span>
              <span class="advisory-title">{{advisory.summary}}</span>
              <a
                href={{advisory.html_url}}
                target="_blank"
                rel="noopener noreferrer"
                class="advisory-link"
              >details</a>
            </li>
          {{/each}}
        </ul>
      {{/if}}
    </div>
  </template>
}
