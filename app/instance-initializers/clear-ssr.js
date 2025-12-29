export default {
  name: 'clear-ssr',

  initialize(instance) {
    var originalDidCreateRootView = instance.didCreateRootView;

    instance.didCreateRootView = function () {
      if (!import.meta.env.SSR) {
        document.querySelector(instance.rootElement).innerHTML = '';
      }
      originalDidCreateRootView.apply(instance, arguments);
    };
  },
};