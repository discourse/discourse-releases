import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class ChangelogCustomController extends Controller {
  @tracked start = null;
  @tracked end = null;
  @tracked tab = null;
  @tracked filter = null;
  queryParams = ["start", "end", "tab", "filter"];

  @action
  updateRange(start, end) {
    this.start = start;
    this.end = end;
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
