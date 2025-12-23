export default {
  initialize(owner){
    owner.lookup('service:router').on('routeDidChange', () => {
      if(!window.FastBoot){
        window.scrollTo(0,0);
      }
    });
  }
}