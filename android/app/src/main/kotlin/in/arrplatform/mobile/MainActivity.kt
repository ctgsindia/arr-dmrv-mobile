package in.arrplatform.mobile

import io.flutter.embedding.android.FlutterActivity

/**
 * Main Android entry point for the ARR DMRV Flutter app.
 * FlutterActivity handles all engine lifecycle and plugin registration.
 * No custom platform channels needed in Phase 1 — everything is handled
 * by flutter plugins (geolocator, camera, drift, etc.).
 */
class MainActivity: FlutterActivity()
