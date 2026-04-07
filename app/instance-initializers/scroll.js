export default {
  initialize(owner) {
    const router = owner.lookup("service:router");
    let previousRoute;

    router.on("routeDidChange", (transition) => {
      const currentRoute = transition.to?.name;

      if (!import.meta.env.SSR && currentRoute !== previousRoute) {
        window.scrollTo(0, 0);
      }

      previousRoute = currentRoute;
    });
  },
};
