import Route from "@ember/routing/route";

export default class ChangelogCustomRoute extends Route {
  queryParams = {
    start: {
      refreshModel: false,
    },
    end: {
      refreshModel: false,
    },
    tab: {
      refreshModel: false,
      replace: true,
    },
    filter: {
      refreshModel: false,
      replace: true,
    },
  };
}
