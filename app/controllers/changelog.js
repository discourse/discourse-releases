import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ChangelogController extends Controller {
  @service router;

  @tracked tab = null;
  @tracked filter = null;
  queryParams = ["tab", "filter"];

  get start() {
    return this.model.start;
  }

  get end() {
    return this.model.end;
  }

  @action
  updateRange(start, end) {
    if (start) {
      // If a start value is provided, use custom route
      this.router.transitionTo("changelog-custom", {
        queryParams: { start, end },
      });
    } else {
      // Otherwise use the standard changelog route
      this.router.transitionTo("changelog", end);
    }
  }

  @action
  updateTab(tab) {
    this.tab = tab === "all" ? null : tab.toLowerCase();
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value || null;
  }
}
