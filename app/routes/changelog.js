import Route from '@ember/routing/route';
import { service } from '@ember/service';

export default class ChangelogRoute extends Route {
  @service router;

  async beforeModel(transition) {
    const end = transition.to.params.end;

    // If the end parameter looks like a commit hash (40 chars or partial hash without 'v'),
    // redirect to custom route
    if (end && !end.startsWith('v') && !end.includes('latest') && !end.includes('main') && !end.includes('stable')) {
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
