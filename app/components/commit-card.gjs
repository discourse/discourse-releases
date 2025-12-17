import Component from '@glimmer/component';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { htmlSafe } from '@ember/template';
import './commit-card.css';

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

export default class CommitCard extends Component {
  get commitUrl() {
    return `https://github.com/discourse/discourse/commit/${this.args.commit.hash}`;
  }

  get shortHash() {
    return this.args.commit.hash.substring(0, 7);
  }

  get formattedDate() {
    const date = new Date(this.args.commit.date);
    return date.toLocaleDateString();
  }

  get formattedTime() {
    const date = new Date(this.args.commit.date);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  get subjectWithLinks() {
    const subject = this.args.commit.subject;
    // Escape the entire text first
    const escaped = escapeHtml(subject);
    // Then replace PR references with links (now safe)
    const withLinks = escaped.replace(
      /\(#(\d+)\)/g,
      '<a href="https://github.com/discourse/discourse/pull/$1" target="_blank" class="pr-link" onclick="event.stopPropagation()">(#$1)</a>'
    );
    return htmlSafe(withLinks);
  }

  @action
  openCommit() {
    window.open(this.commitUrl, '_blank');
  }

  <template>
    <div class="commit-card" {{on "click" this.openCommit}}>
      <div class="commit-header">
        <div class="commit-author">
          <div class="author-info">
            <div class="author-name">
              {{@commit.author}}
            </div>
            <div class="commit-date">
              {{this.formattedDate}}
              at
              {{this.formattedTime}}
            </div>
          </div>
        </div>
        <div class="commit-sha">
          {{this.shortHash}}
        </div>
      </div>

      <div class="commit-message">
        {{this.subjectWithLinks}}
      </div>

      <div class="commit-footer">
        <span class="click-hint">Click to view on GitHub</span>
      </div>
    </div>
  </template>
}
