import 'package:dio/dio.dart';

import '../models/gateway_models.dart';
import 'local_database.dart';
import 'secure_store.dart';

class GatewayApi {
  GatewayApi({
    required SecureStore secureStore,
    required LocalDatabase database,
  }) : _secureStore = secureStore,
       _database = database {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skip_auth'] != true) {
            final token = await _secureStore.accessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final shouldRefresh =
              error.response?.statusCode == 401 &&
              error.requestOptions.extra['token_retry'] != true &&
              error.requestOptions.extra['skip_auth'] != true;
          if (!shouldRefresh) {
            handler.next(error);
            return;
          }

          final refreshed = await _refreshToken();
          if (!refreshed) {
            await _database.logSecurity(
              'token expired',
              'Access token expired and refresh failed.',
            );
            await _secureStore.clearSession();
            handler.next(error);
            return;
          }

          final request = error.requestOptions;
          request.extra['token_retry'] = true;
          final token = await _secureStore.accessToken();
          request.headers['Authorization'] = 'Bearer $token';
          try {
            final response = await _dio.fetch<dynamic>(request);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  static const backendLegacyModeMessage =
      'Backend legacy API mode aktif. Menggunakan /api/predict/.';

  final SecureStore _secureStore;
  final LocalDatabase _database;
  final Dio _dio = Dio();
  String _baseUrl = '';

  void configure(String baseUrl) {
    _baseUrl = _normalizeBaseUrl(baseUrl);
    _dio.options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    );
  }

  Future<Map<String, dynamic>> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login/',
      data: {'username': username, 'password': password},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> setActiveUser(String deviceName) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/device/set-active-user/',
      data: {'device_name': deviceName},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> predict(SensorPayload payload) async {
    final predictError = payload.validatePredictReady();
    if (predictError != null) {
      throw StateError(predictError);
    }

    final apiKey = await _secureStore.legacyApiKey();
    if (apiKey.isEmpty) {
      throw StateError('API key belum diatur. Masukkan API key di Setelan.');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/predict/',
      data: payload.toPredictJson(),
      options: Options(
        headers: {'X-API-KEY': apiKey, 'Content-Type': 'application/json'},
        extra: {'skip_auth': true},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<bool> _refreshToken() async {
    final refresh = await _secureStore.refreshToken();
    if (refresh == null || refresh.isEmpty || _baseUrl.isEmpty) return false;

    try {
      final response = await Dio(BaseOptions(baseUrl: _baseUrl))
          .post<Map<String, dynamic>>(
            '/auth/refresh/',
            data: {'refresh': refresh},
          );
      final access = response.data?['access']?.toString();
      if (access == null || access.isEmpty) return false;
      await _secureStore.saveAccessToken(access);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String readableError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.response?.statusCode == 404) return backendLegacyModeMessage;
      return error.message ?? 'Network error.';
    }
    return error.toString();
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
