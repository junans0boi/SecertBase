{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Keep the CanvasKit fallback font request on the same origin as the app.
    // This avoids making app startup depend on fonts.gstatic.com being reachable.
    fontFallbackBaseUrl: 'fonts/',
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
