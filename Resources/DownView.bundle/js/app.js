/**
 * Nextpage App Main Entry
 */

class NextpageApp {
  constructor() {
    this.initialize();
  }

  initialize() {
    // Use common module for interactive checkboxes
    if (window.NextpageCommon) {
      NextpageCommon.wrapWideTables();
      NextpageCommon.setupInteractiveCheckboxes();
    }
  }
}

NextpageCommon.onDOMReady(() => {
  new NextpageApp();
});

window.NextpageApp = NextpageApp;
