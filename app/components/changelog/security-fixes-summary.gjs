import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import "./security-fixes-summary.css";
import { ShieldAlert } from "lucide";
import LucideIcon from "../lucide-icon";

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
        <span class="summary-icon" aria-hidden="true">
          <LucideIcon
            @icon={{ShieldAlert}}
            @size={{24}}
            @iconClass="summary-icon-lucide"
          />
        </span>
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
