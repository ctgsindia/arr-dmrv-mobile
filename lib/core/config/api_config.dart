/// @file api_config.dart
/// @description Multi-environment API configuration for ARR DMRV.
///   flutter run --dart-define=ENV=local       # http://localhost:3001/api/v1
///   flutter run --dart-define=ENV=ngrok       # ngrok tunnel
///   flutter run --dart-define=ENV=production  # production server
library;

class ApiConfig {
  ApiConfig._();

  static const String env = String.fromEnvironment('ENV', defaultValue: 'production');

  static const String _ngrokUrl = String.fromEnvironment(
    'NGROK_URL',
    defaultValue: 'https://arr-dmrv.ngrok-free.dev',
  );

  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (override.isNotEmpty) return override;
    return switch (env) {
      'local'      => 'http://localhost:3001/api/v1',
      'ngrok'      => '$_ngrokUrl/api/v1',
      'staging'    => 'https://staging.arr-dmrv.in/api/v1',
      _            => 'https://app.arr-dmrv.in/api/v1',
    };
  }

  static bool get isNgrok => env == 'ngrok' || baseUrl.contains('ngrok');

  static String get envLabel => switch (env) {
    'local'   => 'LOCAL',
    'ngrok'   => 'NGROK',
    'staging' => 'STAGING',
    _         => 'PROD',
  };

  // ─── Endpoints ─────────────────────────────────────────────────────────────
  static const String login          = '/auth/login';
  static const String refresh        = '/auth/refresh';
  static const String me             = '/me';
  static const String programmes     = '/programmes';
  static const String species        = '/species';
  static const String photoUpload    = '/photos/upload';

  static String strata(String programmeId) => '/programmes/$programmeId/strata';
  static String samplingPlots(String programmeId) => '/programmes/$programmeId/sampling-plots';
  static String plotTrees(String plotId) => '/sampling-plots/$plotId/trees';
  static String treeMeasurements(String treeId) => '/trees/$treeId/measurements';
  static String treeSurvival(String treeId) => '/trees/$treeId/survival';
  static String biomassCompute(String programmeId) => '/programmes/$programmeId/biomass/compute';
  static String biomassHistory(String programmeId) => '/programmes/$programmeId/biomass';
  static String compliance(String programmeId) => '/programmes/$programmeId/compliance';
  static String participants(String programmeId) => '/programmes/$programmeId/participants';
}
