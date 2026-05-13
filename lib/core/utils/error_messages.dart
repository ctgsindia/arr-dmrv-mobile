/// @file error_messages.dart
/// @description Human-readable error message resolver.
library;

import '../services/api_service.dart';
import '../services/gps_service.dart';
import 'package:dio/dio.dart';

String resolveError(Object error) {
  if (error is OfflineException) return 'No internet connection. Your data will sync when online.';
  if (error is GpsPermissionException) return error.message;
  if (error is GpsTimeoutException) return 'GPS signal is weak. Move outdoors and try again.';
  if (error is ApiException) {
    return switch (error.code) {
      'VALIDATION_ERROR'      => 'Please check all required fields.',
      'DUPLICATE_FOUND'       => 'A duplicate record already exists.',
      'CONTROL_PLOT_MISMATCH' => 'Control plot does not meet VM0047 stdDiff < 0.25 requirement.',
      'NOT_FOUND'             => 'Record not found.',
      'UNAUTHORIZED'          => 'Session expired. Please log in again.',
      _                       => error.message,
    };
  }
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionError || DioExceptionType.unknown => 'Cannot reach server. Check your connection.',
      DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout => 'Request timed out.',
      _ => error.message ?? 'Network error.',
    };
  }
  return error.toString();
}
