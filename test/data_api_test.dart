//
// ignore_for_file: inference_failure_on_collection_literal, inference_failure_on_function_invocation, lines_longer_than_80_chars, prefer_constructors_over_static_methods, avoid_equals_and_hash_code_on_mutable_classes

import 'package:core/core.dart';
import 'package:data_api/data_api.dart';
import 'package:http_client/http_client.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// --- Mock HttpClient ---
class MockHttpClient extends Mock implements HttpClient {}

// --- Mock Logger ---
class MockLogger extends Mock implements Logger {}

const testUserId = 'user-456'; // Added test user ID

// --- Helper to create a standard success envelope ---
Map<String, dynamic> _createSuccessEnvelope(dynamic data) {
  return {
    'data': data,
    'metadata': {
      'requestId': 'test-request-id',
      'timestamp': DateTime.now().toIso8601String(),
    },
  };
}

// --- Helper to create a standard paginated response map ---
Map<String, dynamic> _createPaginatedResponseMap(
  List<dynamic> items, {
  String? cursor,
  bool hasMore = false,
}) {
  return {'items': items, 'cursor': cursor, 'hasMore': hasMore};
}

// --- Mock Functions for Error Simulation ---
_TestModel _mockFromJsonThrows(Map<String, dynamic> json) =>
    throw Exception('fromJson failed');
Map<String, dynamic> _mockToJsonThrows(_TestModel item) =>
    throw Exception('toJson failed');

// --- Dummy Model for Testing ---
class _TestModel {
  const _TestModel({required this.id, required this.name});

  final String id;
  final String name;

  static _TestModel fromJson(Map<String, dynamic> json) {
    if (json['id'] == null || json['name'] == null) {
      throw const FormatException(
        'Missing required fields in JSON for _TestModel',
      );
    }
    return _TestModel(id: json['id'] as String, name: json['name'] as String);
  }

  static Map<String, dynamic> toJson(_TestModel item) {
    return {'id': item.id, 'name': item.name};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TestModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => '_TestModel(id: $id, name: $name)';
}

void main() {
  // Register fallbacks for argument matchers used in stubs/verification
  // This prevents errors if matchers are used before specific values
  setUpAll(() {
    registerFallbackValue({});
    registerFallbackValue('');
    registerFallbackValue(SortOrder.asc);
    registerFallbackValue(MockLogger()); // Register MockLogger as fallback
    registerFallbackValue(const PaginationOptions()); // New
    registerFallbackValue(const SortOption('')); // New
  });

  group('DataApi', () {
    late HttpClient mockHttpClient;
    late MockLogger mockLogger; // Declare mockLogger
    late DataApi<_TestModel> dataApi;
    late DataApi<_TestModel> dataApiFromJsonThrows;
    late DataApi<_TestModel> dataApiToJsonThrows;

    const testModelName = 'test-model'; // Added model name for tests
    const testBasePath = '/api/v1/data'; // Unified base path
    const testId = 'item-123';
    const testModel = _TestModel(id: testId, name: 'Test Name');
    final testModelJson = _TestModel.toJson(testModel);
    final testModelList = [testModel];
    const mockSortBy = 'name';
    const mockSortOrder = SortOrder.desc;
    final testModelListJson = [testModelJson];
    final genericException = Exception('Something unexpected happened');

    final testUserScopedQueryParams = {
      'model': testModelName,
      'userId': testUserId,
    };

    // Pre-create enveloped responses for convenience
    final successEnvelopeSingle = _createSuccessEnvelope(testModelJson);
    // final successEnvelopePaginated = _createSuccessEnvelope(
    //   _createPaginatedResponseMap(testModelListJson),
    // );

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockLogger = MockLogger(); // Initialize mockLogger
      dataApi = DataApi<_TestModel>(
        httpClient: mockHttpClient,
        modelName: testModelName,
        fromJson: _TestModel.fromJson,
        toJson: _TestModel.toJson,
        logger: mockLogger, // Pass mockLogger
      );
      dataApiFromJsonThrows = DataApi<_TestModel>(
        httpClient: mockHttpClient,
        modelName: testModelName,
        fromJson: _mockFromJsonThrows,
        toJson: _TestModel.toJson,
        logger: mockLogger, // Pass mockLogger
      );
      dataApiToJsonThrows = DataApi<_TestModel>(
        httpClient: mockHttpClient,
        modelName: testModelName,
        fromJson: _TestModel.fromJson,
        toJson: _mockToJsonThrows,
        logger: mockLogger, // Pass mockLogger
      );
    });

    // --- Create Tests ---
    group('create', () {
      // Helper to stub successful post
      // Helper to stub successful post returning an envelope
      void stubPostSuccess({Map<String, dynamic>? queryParameters}) {
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testBasePath, // Use base path
            data: testModelJson,
            queryParameters: queryParameters ?? {'model': testModelName},
          ),
        ).thenAnswer((_) async => successEnvelopeSingle);
      }

      // Helper to stub failed post
      void stubPostFailure(
        Exception exception, {
        Map<String, dynamic>? queryParameters,
      }) {
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testBasePath, // Use base path
            data: testModelJson,
            queryParameters: queryParameters ?? {'model': testModelName},
          ),
        ).thenThrow(exception);
      }

      test(
        'should call httpClient.post and return deserialized model on success',
        () async {
          stubPostSuccess();
          final result = await dataApi.create(item: testModel);
          expect(result, isA<SuccessApiResponse<_TestModel>>());
          expect(result.data, equals(testModel));
          verify(
            () => mockHttpClient.post<Map<String, dynamic>>(
              testBasePath, // Verify base path
              data: testModelJson,
              queryParameters: {'model': testModelName}, // Verify query param
            ),
          ).called(1);
        },
      );

      test(
        'should call httpClient.post with userId and return deserialized model on success',
        () async {
          stubPostSuccess(queryParameters: testUserScopedQueryParams);
          final result = await dataApi.create(
            item: testModel,
            userId: testUserId,
          );
          expect(result, isA<SuccessApiResponse<_TestModel>>());
          expect(result.data, equals(testModel));
          verify(
            () => mockHttpClient.post<Map<String, dynamic>>(
              testBasePath, // Verify base path
              data: testModelJson,
              queryParameters: testUserScopedQueryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test('should throw HttpException when httpClient.post fails', () async {
        const exception = BadRequestException('Invalid data');
        stubPostFailure(exception);
        expect(
          () => dataApi.create(item: testModel),
          throwsA(isA<BadRequestException>()),
        );
        verify(
          () => mockHttpClient.post<Map<String, dynamic>>(
            testBasePath, // Verify base path
            data: testModelJson,
            queryParameters: {'model': testModelName}, // Verify query param
          ),
        ).called(1);
      });

      test(
        'should throw HttpException when httpClient.post fails with userId',
        () async {
          const exception = BadRequestException('Invalid data');
          stubPostFailure(
            exception,
            queryParameters: testUserScopedQueryParams,
          );
          expect(
            () => dataApi.create(item: testModel, userId: testUserId),
            throwsA(isA<BadRequestException>()),
          );
          verify(
            () => mockHttpClient.post<Map<String, dynamic>>(
              testBasePath, // Verify base path
              data: testModelJson,
              queryParameters: testUserScopedQueryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test('should throw generic Exception when toJson fails', () async {
        // No stubbing needed as http client is not called
        expect(
          () => dataApiToJsonThrows.create(item: testModel),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              'Exception: toJson failed',
            ),
          ),
        );
        verifyNever(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'), // Match any query
          ),
        );
      });

      // New test: generic exception from http client
      test(
        'should throw generic Exception when httpClient.post throws generic',
        () async {
          final exception = genericException;
          stubPostFailure(exception);
          expect(
            () => dataApi.create(item: testModel),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.post<Map<String, dynamic>>(
              testBasePath, // Verify base path
              data: testModelJson,
              queryParameters: {'model': testModelName}, // Verify query param
            ),
          ).called(1);
        },
      );
    });

    // --- Read Tests ---
    group('read', () {
      const path = '$testBasePath/$testId'; // Use base path
      final queryParams = {'model': testModelName}; // Add model query param

      final userScopedQueryParams = {
        'model': testModelName,
        'userId': testUserId,
      };

      // Helper to stub successful get returning an envelope
      void stubGetSuccess({Map<String, dynamic>? queryParameters}) {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            path,
            queryParameters: queryParameters ?? queryParams,
          ),
        ).thenAnswer((_) async => successEnvelopeSingle);
      }

      void stubGetFailure(
        Exception exception, {
        Map<String, dynamic>? queryParameters,
      }) {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            path,
            queryParameters: queryParameters ?? queryParams,
          ),
        ).thenThrow(exception);
      }

      test(
        'should call httpClient.get and return deserialized model on success',
        () async {
          stubGetSuccess();
          final result = await dataApi.read(id: testId);
          expect(result, isA<SuccessApiResponse<_TestModel>>());
          expect(result.data, equals(testModel));
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              path,
              queryParameters: queryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test(
        'should call httpClient.get with userId and return deserialized model on success',
        () async {
          stubGetSuccess(queryParameters: userScopedQueryParams);
          final result = await dataApi.read(id: testId, userId: testUserId);
          expect(result, isA<SuccessApiResponse<_TestModel>>());
          expect(result.data, equals(testModel));
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              path,
              queryParameters: userScopedQueryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test('should throw HttpException when httpClient.get fails', () async {
        const exception = NotFoundException('Item not found');
        stubGetFailure(exception);
        expect(
          () => dataApi.read(id: testId),
          throwsA(isA<NotFoundException>()),
        );
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            path,
            queryParameters: queryParams, // Verify query param
          ),
        ).called(1);
      });

      test(
        'should throw HttpException when httpClient.get fails with userId',
        () async {
          const exception = NotFoundException('Item not found');
          stubGetFailure(exception, queryParameters: userScopedQueryParams);
          expect(
            () => dataApi.read(id: testId, userId: testUserId),
            throwsA(isA<NotFoundException>()),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              path,
              queryParameters: userScopedQueryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test('should throw generic Exception when fromJson fails', () async {
        // Stub needs to return the envelope, even if fromJson will fail
        stubGetSuccess();
        expect(
          () => dataApiFromJsonThrows.read(id: testId),
          throwsA(isA<CheckedFromJsonException>()),
        );
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            path,
            queryParameters: queryParams, // Verify query param
          ),
        ).called(1);
      });

      // New test: generic exception from http client
      test(
        'should throw generic Exception when httpClient.get throws generic',
        () async {
          final exception = genericException;
          stubGetFailure(exception);
          expect(
            () => dataApi.read(id: testId),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              path,
              queryParameters: queryParams, // Verify query param
            ),
          ).called(1);
        },
      );
    });

    // --- ReadAll Tests ---
    group('readAll', () {
      final baseQueryParams = {'model': testModelName}; // Base query
      final userScopedQueryParams = {
        'model': testModelName,
        'userId': testUserId,
      };

      // Updated helper to return enveloped paginated response
      void stubGetAllSuccess({
        required Map<String, dynamic> queryParameters,
        List<dynamic> items = const [],
        bool hasMore = false,
        String? cursor,
      }) {
        final paginatedData = _createPaginatedResponseMap(
          items,
          hasMore: hasMore,
          cursor: cursor,
        );
        final envelope = _createSuccessEnvelope(paginatedData);
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testBasePath, // Use base path
            queryParameters: queryParameters,
          ),
        ).thenAnswer((_) async => envelope);
      }

      // Updated helper for failure, still expects Map
      void stubGetAllFailure({
        required Exception exception,
        required Map<String, dynamic> queryParameters, // Now required
      }) {
        when(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testBasePath, // Use base path
            queryParameters: queryParameters,
          ),
        ).thenThrow(exception);
      }

      test('should call httpClient.get with model query and return list '
          'on success', () async {
        stubGetAllSuccess(
          items: testModelListJson,
          queryParameters: baseQueryParams, // Use base query
        );
        final result = await dataApi.readAll();
        expect(
          result,
          isA<SuccessApiResponse<PaginatedResponse<_TestModel>>>(),
        );
        expect(result.data.items, equals(testModelList));
        expect(result.data.hasMore, isFalse);
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testBasePath, // Verify base path
            queryParameters: baseQueryParams, // Verify base query
          ),
        ).called(1);
      });

      test('should call httpClient.get with userId and return list '
          'on success', () async {
        stubGetAllSuccess(
          items: testModelListJson,
          queryParameters: userScopedQueryParams, // Use user-scoped query
        );
        final result = await dataApi.readAll(userId: testUserId);
        expect(
          result,
          isA<SuccessApiResponse<PaginatedResponse<_TestModel>>>(),
        );
        expect(result.data.items, equals(testModelList));
        expect(result.data.hasMore, isFalse);
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testBasePath, // Verify base path
            queryParameters: userScopedQueryParams, // Verify user-scoped query
          ),
        ).called(1);
      });

      // New test for pagination parameters
      test(
        'should call httpClient.get with model, pagination, and sorting query and return list '
        'on success',
        () async {
          const cursor = 'item-100';
          const limit = 10;
          const paginationOptions = PaginationOptions(
            cursor: cursor,
            limit: limit,
          );
          final sortOptions = [const SortOption(mockSortBy, mockSortOrder)];
          final queryParams = <String, dynamic>{
            ...baseQueryParams,
            'cursor': cursor,
            'limit': limit.toString(),
            'sort': '$mockSortBy:${mockSortOrder.name}',
          };
          stubGetAllSuccess(
            items: testModelListJson,
            queryParameters: queryParams,
            hasMore: true,
          );
          final result = await dataApi.readAll(
            pagination: paginationOptions,
            sort: sortOptions,
          );
          expect(
            result,
            isA<SuccessApiResponse<PaginatedResponse<_TestModel>>>(),
          );
          expect(result.data.items, equals(testModelList));
          expect(result.data.hasMore, isTrue);
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testBasePath, // Verify base path
              queryParameters: queryParams, // Verify combined query
            ),
          ).called(1);
        },
      );

      test(
        'should call httpClient.get with filter and return list on success',
        () async {
          final filter = {'status': 'active', 'tags': 'tech'};
          final queryParams = <String, dynamic>{
            ...baseQueryParams,
            'filter': '{"status":"active","tags":"tech"}',
          };
          stubGetAllSuccess(
            items: testModelListJson,
            queryParameters: queryParams,
          );

          final result = await dataApi.readAll(filter: filter);

          expect(
            result,
            isA<SuccessApiResponse<PaginatedResponse<_TestModel>>>(),
          );
          expect(result.data.items, equals(testModelList));
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testBasePath,
              queryParameters: queryParams,
            ),
          ).called(1);
        },
      );

      test(
        'should call httpClient.get with userId, pagination, and sorting query and return list '
        'on success',
        () async {
          const cursor = 'item-100';
          const limit = 10;
          const paginationOptions = PaginationOptions(
            cursor: cursor,
            limit: limit,
          );
          final sortOptions = [const SortOption(mockSortBy, mockSortOrder)];
          final queryParams = <String, dynamic>{
            ...userScopedQueryParams,
            'cursor': cursor,
            'limit': limit.toString(),
            'sort': '$mockSortBy:${mockSortOrder.name}',
          };
          stubGetAllSuccess(
            items: testModelListJson,
            queryParameters: queryParams,
            hasMore: true,
          );
          final result = await dataApi.readAll(
            userId: testUserId,
            pagination: paginationOptions,
            sort: sortOptions,
          );
          expect(
            result,
            isA<SuccessApiResponse<PaginatedResponse<_TestModel>>>(),
          );
          expect(result.data.items, equals(testModelList));
          expect(result.data.hasMore, isTrue);
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testBasePath, // Verify base path
              queryParameters: queryParams, // Verify combined query
            ),
          ).called(1);
        },
      );

      test('should throw HttpException when httpClient.get fails', () async {
        const exception = ServerException('Server error');
        stubGetAllFailure(
          exception: exception,
          queryParameters: baseQueryParams,
        );
        expect(() => dataApi.readAll(), throwsA(isA<ServerException>()));
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>(
            testBasePath, // Verify base path
            queryParameters: baseQueryParams, // Verify base query
          ),
        ).called(1);
      });

      test(
        'should throw HttpException when httpClient.get fails with userId',
        () async {
          const exception = ServerException('Server error');
          stubGetAllFailure(
            exception: exception,
            queryParameters: userScopedQueryParams,
          );
          expect(
            () => dataApi.readAll(userId: testUserId),
            throwsA(isA<ServerException>()),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testBasePath, // Verify base path
              queryParameters:
                  userScopedQueryParams, // Verify user-scoped query
            ),
          ).called(1);
        },
      );

      test(
        'should throw FormatException when list item is not a Map',
        () async {
          // Stub needs to return envelope with malformed paginated data inside
          final malformedPaginatedData = _createPaginatedResponseMap([
            testModelJson,
            123,
          ]);
          final envelopeWithMalformedData = _createSuccessEnvelope(
            malformedPaginatedData,
          );
          when(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testBasePath, // Use base path
              queryParameters: baseQueryParams, // Use base query
            ),
          ).thenAnswer((_) async => envelopeWithMalformedData);

          expect(
            () => dataApi.readAll(),
            throwsA(isA<CheckedFromJsonException>()),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testBasePath, // Verify base path
              queryParameters: baseQueryParams, // Verify base query
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when fromJson fails during mapping',
        () async {
          // Stub needs to return a valid envelope, failure happens in fromJson
          stubGetAllSuccess(
            items: testModelListJson,
            queryParameters: baseQueryParams, // Use base query
          );
          expect(
            () => dataApiFromJsonThrows.readAll(),
            throwsA(isA<CheckedFromJsonException>()),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testBasePath, // Verify base path
              queryParameters: baseQueryParams, // Verify base query
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when httpClient throws generic error',
        () async {
          final exception = genericException;
          stubGetAllFailure(
            exception: exception,
            queryParameters: baseQueryParams,
          );
          expect(
            () => dataApi.readAll(),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.get<Map<String, dynamic>>(
              testBasePath, // Verify base path
              queryParameters: baseQueryParams, // Verify base query
            ),
          ).called(1);
        },
      );
    });

    // --- Update Tests ---
    group('update', () {
      const path = '$testBasePath/$testId'; // Use base path
      final queryParams = {'model': testModelName}; // Add model query param
      const updatedModel = _TestModel(id: testId, name: 'Updated Name');
      final updatedModelJson = _TestModel.toJson(updatedModel);
      final successEnvelopeUpdated = _createSuccessEnvelope(updatedModelJson);

      final userScopedQueryParams = {
        'model': testModelName,
        'userId': testUserId,
      };

      // Helper to stub successful put returning an envelope
      void stubPutSuccess({Map<String, dynamic>? queryParameters}) {
        when(
          () => mockHttpClient.put<Map<String, dynamic>>(
            path,
            data: updatedModelJson,
            queryParameters: queryParameters ?? queryParams,
          ),
        ).thenAnswer((_) async => successEnvelopeUpdated);
      }

      test(
        'should call httpClient.put and return deserialized model on success',
        () async {
          stubPutSuccess();
          final result = await dataApi.update(id: testId, item: updatedModel);
          expect(result, isA<SuccessApiResponse<_TestModel>>());
          expect(result.data, equals(updatedModel));
          verify(
            () => mockHttpClient.put<Map<String, dynamic>>(
              path,
              data: updatedModelJson,
              queryParameters: queryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test(
        'should call httpClient.put with userId and return deserialized model on success',
        () async {
          stubPutSuccess(queryParameters: userScopedQueryParams);
          final result = await dataApi.update(
            id: testId,
            item: updatedModel,
            userId: testUserId,
          );
          expect(result, isA<SuccessApiResponse<_TestModel>>());
          expect(result.data, equals(updatedModel));
          verify(
            () => mockHttpClient.put<Map<String, dynamic>>(
              path,
              data: updatedModelJson,
              queryParameters: userScopedQueryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test('should throw HttpException when httpClient.put fails', () async {
        const exception = UnauthorizedException('Auth failed');
        // Stub with the original model being sent, as that's what update receives
        when(
          () => mockHttpClient.put<Map<String, dynamic>>(
            path,
            data: testModelJson,
            queryParameters: queryParams, // Add query param
          ),
        ).thenThrow(exception);

        expect(
          () => dataApi.update(id: testId, item: testModel),
          throwsA(isA<UnauthorizedException>()),
        );
        verify(
          () => mockHttpClient.put<Map<String, dynamic>>(
            path,
            data: testModelJson,
            queryParameters: queryParams, // Verify query param
          ),
        ).called(1);
      });

      test(
        'should throw HttpException when httpClient.put fails with userId',
        () async {
          const exception = UnauthorizedException('Auth failed');
          // Stub with the original model being sent
          when(
            () => mockHttpClient.put<Map<String, dynamic>>(
              path,
              data: testModelJson,
              queryParameters: userScopedQueryParams, // Add query param
            ),
          ).thenThrow(exception);

          expect(
            () =>
                dataApi.update(id: testId, item: testModel, userId: testUserId),
            throwsA(isA<UnauthorizedException>()),
          );
          verify(
            () => mockHttpClient.put<Map<String, dynamic>>(
              path,
              data: testModelJson,
              queryParameters: userScopedQueryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test('should throw generic Exception when toJson fails', () async {
        // No stubbing needed
        expect(
          () => dataApiToJsonThrows.update(id: testId, item: testModel),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              'Exception: toJson failed',
            ),
          ),
        );
        verifyNever(
          () => mockHttpClient.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'), // Match any query
          ),
        );
      });

      // New test: generic exception from http client
      test(
        'should throw generic Exception when httpClient.put throws generic',
        () async {
          final exception = genericException;
          // Stub with the original model being sent
          when(
            () => mockHttpClient.put<Map<String, dynamic>>(
              path,
              data: testModelJson,
              queryParameters: queryParams, // Add query param
            ),
          ).thenThrow(exception);

          expect(
            () => dataApi.update(id: testId, item: testModel),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.put<Map<String, dynamic>>(
              path,
              data: testModelJson,
              queryParameters: queryParams, // Verify query param
            ),
          ).called(1);
        },
      );
    });

    // --- Delete Tests ---
    group('delete', () {
      const path = '$testBasePath/$testId'; // Use base path
      final queryParams = {'model': testModelName}; // Add model query param

      final userScopedQueryParams = {
        'model': testModelName,
        'userId': testUserId,
      };

      void stubDeleteSuccess({Map<String, dynamic>? queryParameters}) {
        when(
          () => mockHttpClient.delete<dynamic>(
            path,
            queryParameters: queryParameters ?? queryParams,
          ),
        ).thenAnswer((_) async => null);
      }

      void stubDeleteFailure(
        Exception exception, {
        Map<String, dynamic>? queryParameters,
      }) {
        when(
          () => mockHttpClient.delete<dynamic>(
            path,
            queryParameters: queryParameters ?? queryParams,
          ),
        ).thenThrow(exception);
      }

      test(
        'should call httpClient.delete and complete normally on success',
        () async {
          stubDeleteSuccess();
          await dataApi.delete(id: testId);
          verify(
            () => mockHttpClient.delete<dynamic>(
              path,
              queryParameters: queryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test(
        'should call httpClient.delete with userId and complete normally on success',
        () async {
          stubDeleteSuccess(queryParameters: userScopedQueryParams);
          await dataApi.delete(id: testId, userId: testUserId);
          verify(
            () => mockHttpClient.delete<dynamic>(
              path,
              queryParameters: userScopedQueryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test('should throw HttpException when httpClient.delete fails', () async {
        const exception = ForbiddenException('Permission denied');
        stubDeleteFailure(exception);
        expect(
          () => dataApi.delete(id: testId),
          throwsA(isA<ForbiddenException>()),
        );
        verify(
          () => mockHttpClient.delete<dynamic>(
            path,
            queryParameters: queryParams, // Verify query param
          ),
        ).called(1);
      });

      test(
        'should throw HttpException when httpClient.delete fails with userId',
        () async {
          const exception = ForbiddenException('Permission denied');
          stubDeleteFailure(exception, queryParameters: userScopedQueryParams);
          expect(
            () => dataApi.delete(id: testId, userId: testUserId),
            throwsA(isA<ForbiddenException>()),
          );
          verify(
            () => mockHttpClient.delete<dynamic>(
              path,
              queryParameters: userScopedQueryParams, // Verify query param
            ),
          ).called(1);
        },
      );

      test(
        'should throw generic Exception when httpClient.delete throws generic error',
        () async {
          final exception = genericException;
          stubDeleteFailure(exception);
          expect(
            () => dataApi.delete(id: testId),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Something unexpected happened',
              ),
            ),
          );
          verify(
            () => mockHttpClient.delete<dynamic>(
              path,
              queryParameters: queryParams, // Verify query param
            ),
          ).called(1);
        },
      );
    });
  });
}
