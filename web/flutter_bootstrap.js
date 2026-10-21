{{flutter_js}}
{{flutter_build_config}}

// Assets are loaded from /a/<build>/ instead of /assets/ directly; vercel.json
// rewrites that prefix back to the real files.
//
// Flutter does not put a hash in asset file names, so every build ships a file
// called assets/fonts/MaterialIcons-Regular.otf — and that font is trimmed to
// the icons the build actually uses. /assets/ used to be cached for a year as
// immutable, so a browser that had loaded an older build kept the older, more
// heavily trimmed font: icons added since (the sidebar's filled Home and
// Messages) came out as nothing, leaving an empty lime pill. A new address per
// build means a browser holding an old copy never looks it up again, and
// vercel.json now has /assets/ revalidated rather than kept for a year.
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    assetBase: "/a/" + {{flutter_service_worker_version}} + "/",
  },
});
