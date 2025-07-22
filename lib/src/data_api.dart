import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_client/data_client.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart'; // Import the logging package

/// {@template data_api}
/// An implementation of [DataClient] that uses an [HttpClient] for
/// communication with a data resource endpoint.
///
/// This class provides concrete implementations for the data access methods
/// defined in [DataClient], handling the underlying HTTP requests and
/// managing serialization/deserialization via provided [FromJson] and [ToJson]
/// functions.
///
/// It requires the model name (e.g., 'headline', 'category') to target the
/// correct resource via the unified API endpoint.
/// {@endtemplate}
class DataApi<T> implements DataClient<T> {
  /// {@macro data_api}
  const DataApi({
    required HttpClient httpClient,
    required String modelName,
    required FromJson<T> fromJson,
    required ToJson<T> toJson,
    required Logger logger, // Injected logger
  }) : _httpClient = httpClient,
       _modelName = modelName,
       _fromJson = fromJson,
       _toJson = toJson,
       _logger = logger; // Use the injected logger

  /// The base path for the unified data API endpoint.
  static const String _basePath = '/api/v1/data';

  final HttpClient _httpClient;
  final String _modelName;
  final FromJson<T> _fromJson;
  final ToJson<T> _toJson;

  // Injected logger
  final Logger _logger;

  /// Creates a new resource item of type [T].
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation may be considered a global creation (e.g.,
  ///   by an admin), depending on the resource type [T]. Implementations
  ///   must handle the `null` case appropriately.
  /// - [item]: The resource item to create.
  ///
  /// Sends a POST request to the unified API endpoint `[_basePath]` with
  /// the serialized [item] data and the `model` query parameter set to
  /// [_modelName]. Includes the `userId` query parameter if provided.
  ///
  /// Example Request (user-scoped): `POST /api/v1/data?model=headline&userId=user123`
  /// Example Request (global): `POST /api/v1/data?model=headline`
  ///
  /// Returns a [SuccessApiResponse] containing the created item, potentially
  /// populated with server-assigned data (like an ID).
  ///
  /// Throws [HttpException] or its subtypes on underlying HTTP communication
  /// failure. Exceptions during serialization ([_toJson]) or deserialization
  /// ([_fromJson]) will also propagate. These exceptions are intended to be
  /// handled by the caller (e.g., Repository or BLoC layer).
  @override
  Future<SuccessApiResponse<T>> create({
    required T item,
    String? userId,
  }) async {
    _logger.info(
      'Creating item: $item with userId: $userId',
    ); // Log the creation attempt
    // Exceptions from _httpClient or _fromJson/_toJson are allowed to propagate.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
    };
    final responseData = await _httpClient.post<Map<String, dynamic>>(
      _basePath,
      data: _toJson(item),
      queryParameters: queryParameters,
    );
    _logger.fine('Created item response: $responseData'); // Log the response
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => _fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Reads a single resource item of type [T] by its unique [id].
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation may be considered a global read, depending
  ///   on the resource type [T]. Implementations must handle the `null` case.
  /// - [id]: The unique identifier of the resource item to read.
  ///
  /// Sends a GET request to the item-specific API endpoint `[_basePath]/{id}`
  /// with the `model` query parameter set to [_modelName]. Includes the
  /// `userId` query parameter if provided.
  ///
  /// Example Request (user-scoped): `GET /api/v1/data/some-item-id?model=category&userId=user123`
  /// Example Request (global): `GET /api/v1/data/some-item-id?model=category`
  ///
  /// Returns a [SuccessApiResponse] containing the deserialized item.
  ///
  /// Throws [HttpException] or its subtypes (e.g., [NotFoundException]) on
  /// underlying HTTP communication failure. Exceptions during deserialization
  /// ([_fromJson]) will also propagate. These exceptions are intended to be
  /// handled by the caller.
  @override
  Future<SuccessApiResponse<T>> read({
    required String id,
    String? userId,
  }) async {
    _logger.info(
      'Reading item with id: $id and userId: $userId',
    ); // Log the read attempt
    // Exceptions from _httpClient or _fromJson are allowed to propagate.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
    };
    final responseData = await _httpClient.get<Map<String, dynamic>>(
      '$_basePath/$id',
      queryParameters: queryParameters,
    );
    _logger.fine('Read item response: $responseData'); // Log the response
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => _fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Reads multiple resource items of type [T], with support for rich filtering,
  /// sorting, and pagination.
  ///
  /// - [userId]: The unique identifier of the user. If `null`, retrieves
  ///   *global* resources. If provided, retrieves resources scoped to that user.
  /// - [filter]: An optional map defining the query conditions. It is designed
  ///   to be compatible with MongoDB's query syntax. If `null` or empty, all
  ///   resources (scoped by `userId`) are returned.
  /// - [pagination]: Optional pagination parameters, including `cursor` and `limit`.
  /// - [sort]: An optional list of [SortOption] to define the sorting order.
  ///   MongoDB supports sorting by multiple fields.
  ///
  /// Sends a GET request to the unified API endpoint `[_basePath]` with the
  /// `model` query parameter set to [_modelName]. Includes the `userId` query
  /// parameter if provided, and optional pagination and sorting parameters.
  ///
  /// Example Request (user-scoped, with filter):
  /// `GET /api/v1/data?model=headline&userId=user123&filter={"status":"published"}`
  ///
  /// Returns a [SuccessApiResponse] containing a [PaginatedResponse] with the
  /// list of deserialized items and pagination details.
  ///
  /// Throws [HttpException] or its subtypes on underlying HTTP communication
  /// failure.
  @override
  Future<SuccessApiResponse<PaginatedResponse<T>>> readAll({
    String? userId,
    Map<String, dynamic>? filter,
    PaginationOptions? pagination,
    List<SortOption>? sort,
  }) async {
    _logger.info(
      'Reading all items with userId: $userId, filter: $filter, '
      'pagination: ${pagination?.props}, sort: ${sort?.map((s) => s.props)}',
    );
    // Exceptions from _httpClient are allowed to propagate.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
      if (pagination?.cursor != null) 'cursor': pagination!.cursor,
      if (pagination?.limit != null) 'limit': pagination!.limit.toString(),
      if (filter != null && filter.isNotEmpty) 'filter': jsonEncode(filter),
      if (sort != null && sort.isNotEmpty)
        'sort': sort.map((s) => '${s.field}:${s.order.name}').join(','),
    };
    final responseData = await _httpClient.get<Map<String, dynamic>>(
      _basePath,
      queryParameters: queryParameters,
    );
    _logger.fine('Read all items response: $responseData'); // Log the response
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => PaginatedResponse.fromJson(json! as Map<String, dynamic>, (
        itemJson,
      ) {
        // Add type check for robustness against malformed API responses
        if (itemJson is Map<String, dynamic>) {
          return _fromJson(itemJson);
        } else {
          throw FormatException(
            'Expected Map<String, dynamic> in paginated list but got ${itemJson?.runtimeType}',
            itemJson,
          );
        }
      }),
    );
  }

  /// Updates an existing resource item of type [T] identified by [id].
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation may be considered a global update (e.g.,
  ///   by an admin), depending on the resource type [T]. Implementations
  ///   must handle the `null` case appropriately.
  /// - [id]: The unique identifier of the resource item to update.
  /// - [item]: The updated resource item data.
  ///
  /// Sends a PUT request to the item-specific API endpoint `[_basePath]/{id}`
  /// with the serialized [item] data and the `model` query parameter set to
  /// [_modelName]. Includes the `userId` query parameter if provided.
  ///
  /// Example Request (user-scoped): `PUT /api/v1/data/some-item-id?model=category&userId=user123`
  /// Example Request (global): `PUT /api/v1/data/some-item-id?model=category`
  ///
  /// Returns a [SuccessApiResponse] containing the updated item as confirmed
  /// by the server.
  ///
  /// Throws [HttpException] or its subtypes (e.g., [NotFoundException]) on
  /// underlying HTTP communication failure. Exceptions during serialization
  /// ([_toJson]) or deserialization ([_fromJson]) will also propagate. These
  /// exceptions are intended to be handled by the caller.
  @override
  Future<SuccessApiResponse<T>> update({
    required String id,
    required T item,
    String? userId,
  }) async {
    _logger.info(
      'Updating item with id: $id and userId: $userId with item: $item',
    ); // Log the update attempt
    // Exceptions from _httpClient or _fromJson/_toJson are allowed to propagate.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
    };
    final responseData = await _httpClient.put<Map<String, dynamic>>(
      '$_basePath/$id',
      data: _toJson(item),
      queryParameters: queryParameters,
    );
    _logger.fine('Updated item response: $responseData'); // Log the response
    return SuccessApiResponse.fromJson(
      responseData,
      (json) => _fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Deletes a resource item identified by [id].
  ///
  /// - [userId]: The unique identifier of the user performing the operation.
  ///   If `null`, the operation may be considered a global delete (e.g.,
  ///   by an admin), depending on the resource type [T]. Implementations
  ///   must handle the `null` case appropriately.
  /// - [id]: The unique identifier of the resource item to delete.
  ///
  /// Sends a DELETE request to the item-specific API endpoint `[_basePath]/{id}`
  /// with the `model` query parameter set to [_modelName]. Includes the
  /// `userId` query parameter if provided.
  /// Returns `void` upon successful deletion (typically indicated by a 204
  /// No Content response).
  ///
  /// Example Request (user-scoped): `DELETE /api/v1/data/some-item-id?model=source&userId=user123`
  /// Example Request (global): `DELETE /api/v1/data/some-item-id?model=source`
  ///
  /// Throws [HttpException] or its subtypes (e.g., [NotFoundException]) on
  /// underlying HTTP communication failure. These exceptions are intended to be
  /// handled by the caller.
  @override
  Future<void> delete({required String id, String? userId}) async {
    _logger.info(
      'Deleting item with id: $id and userId: $userId',
    ); // Log the delete attempt
    // Exceptions from _httpClient are allowed to propagate.
    // We expect no content, but use <dynamic> for flexibility.
    final queryParameters = <String, dynamic>{
      'model': _modelName,
      if (userId != null) 'userId': userId,
    };
    await _httpClient.delete<dynamic>(
      '$_basePath/$id',
      queryParameters: queryParameters,
    );
    _logger.fine('Deleted item with id: $id'); // Log the deletion
  }

  @override
  Future<SuccessApiResponse<int>> count({
    String? userId,
    Map<String, dynamic>? filter,
  }) async {
    throw UnimplementedError('count has not been implemented');
  }

  @override
  Future<SuccessApiResponse<List<Map<String, dynamic>>>> aggregate({
    required List<Map<String, dynamic>> pipeline,
    String? userId,
  }) async {
    throw UnimplementedError('aggregate has not been implemented');
  }
}
