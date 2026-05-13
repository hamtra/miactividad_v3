{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    // HTML renderer: imágenes Firebase Storage sin restricciones CORS de canvas
    const appRunner = await engineInitializer.initializeEngine({
      renderer: 'html',
    });
    await appRunner.runApp();
  }
});
