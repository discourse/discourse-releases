import Route from '@ember/routing/route';
import { service } from '@ember/service';
import CommitsData from '/data/commits.json';

export default class ChangelogRoute extends Route {
  @service router;

  beforeModel(transition) {
    const end = transition.to.params.end;

    if (!end) {
      return;
    }

    // Check if it's a valid branch or tag
    const isValidBranch = CommitsData.refs.branches[end] !== undefined;
    const isValidTag = CommitsData.refs.tags[end] !== undefined;

    if (!isValidBranch && !isValidTag) {
      this.router.transitionTo('changelog-custom', {
        queryParams: { start: null, end: end }
      });
    }
  }

  model(params) {
    return {
      start: null,
      end: params.end,
    };
  }
}
