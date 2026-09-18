// Appended to this build's generated loader and buildConfig by the assembler.
// No service worker: offline here means no cloud, with local hosting available.
// Cancel only placeholder Enter's default action; Flutter still receives it.
window.addEventListener(
  "keydown",
  (event) => {
    if (
      event.key === "Enter" &&
      event.target?.localName === "flt-semantics-placeholder"
    ) {
      event.preventDefault();
    }
  },
  { capture: true, passive: false },
);

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "/local/canvaskit/",
    fontFallbackBaseUrl: "/local/assets/local_fonts/",
  },
});
