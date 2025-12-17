import Component from '@glimmer/component';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import './commit-card.css';

export default class CommitCard extends Component {
  @action
  openCommit() {
    window.open(this.args.commit.url, '_blank');
  }

  <template>
    <div class="commit-card" {{on "click" this.openCommit}}>
      <div class="commit-header">
        <div class="commit-author">
          {{#if @commit.author.avatar}}
            <img
              src={{@commit.author.avatar}}
              alt={{@commit.author.name}}
              class="author-avatar"
            />
          {{/if}}
          <div class="author-info">
            <div class="author-name">
              {{#if @commit.author.username}}
                @{{@commit.author.username}}
              {{else}}
                {{@commit.author.name}}
              {{/if}}
            </div>
            <div class="commit-date">
              {{@commit.formattedDate}}
              at
              {{@commit.formattedTime}}
            </div>
          </div>
        </div>
        <div class="commit-sha">
          {{@commit.shortSha}}
        </div>
      </div>

      <div class="commit-message">
        {{~@commit.message~}}
      </div>

      <div class="commit-footer">
        <span class="click-hint">Click to view on GitHub</span>
      </div>
    </div>
  </template>
}
