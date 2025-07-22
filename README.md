# data_api

![coverage: xx%](https://img.shields.io/badge/coverage-94-green)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: PolyForm Free Trial](https://img.shields.io/badge/License-PolyForm%20Free%20Trial-blue)](https://polyformproject.org/licenses/free-trial/1.0.0)

A generic Dart package providing a concrete implementation of the `DataClient<T>` abstract class for interacting with data resource endpoints via HTTP. It leverages the `http_client` package for underlying HTTP communication and error handling.

## Getting Started

Add this package to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  data_api:
    git:
      url: https://github.com/flutter-news-app-full-source-code/data-api.git
      # ref: <specific_tag_or_commit> # Optional: Pin to a specific version
  http_client:
    git:
      url: https://github.com/flutter-news-app-full-source-code/http-client.git
      # ref: <specific_tag_or_commit>
```

Then run `dart pub get` or `flutter pub get`.

## Features

*   Provides a concrete implementation of the `DataClient<T>` abstract class.
*   Implements data access methods (`create`, `read`, `update`) returning `Future<SuccessApiResponse<T>>`.
*   Implements a unified `readAll` method returning `Future<SuccessApiResponse<PaginatedResponse<T>>>`.
*   Implements `delete` returning `Future<void>`.
*   Requires an instance of `HttpClient` for making HTTP requests.
*   Configurable with the `modelName` (identifying the resource) and `fromJson`/`toJson` functions for the specific model `T`.
*   Supports rich, document-style querying (`filter`), multi-field sorting (`sort`), and cursor-based pagination (`pagination`).
*   Propagates `HttpException` errors from the underlying `HttpClient`.
*   Serializes complex query objects (`filter`, `sort`) into URL parameters for transport.
*   Includes comprehensive unit tests with 100% coverage.

## Usage

1.  **Define your Model:** Create a class representing the data structure for your API resource. Include `fromJson` and `toJson` methods/functions.

    ```dart
    class MyModel {
      const MyModel({required this.id, required this.name});

      final String id;
      final String name;

      // Factory constructor for deserialization
      factory MyModel.fromJson(Map<String, dynamic> json) {
        return MyModel(
          id: json['id'] as String,
          name: json['name'] as String,
        );
      }

      // Method for serialization
      Map<String, dynamic> toJson() {
        return {
          'id': id,
          'name': name,
        };
      }
    }
    ```

2.  **Instantiate `HttpClient`:** Set up your HTTP client (refer to `http_client` documentation).

    ```dart
    // Example setup (replace with your actual implementation)
    Future<String?> _myTokenProvider() async => 'your_auth_token';

    final httpClient = HttpClient(
      baseUrl: 'https://api.yourapp.com/v1',
      tokenProvider: _myTokenProvider,
    );
    ```

3.  **Instantiate `DataApi`:** Create an instance specific to your model, providing the `modelName` used in the unified API endpoint.

    ```dart
    final myModelApi = DataApi<MyModel>(
      httpClient: httpClient,
      modelName: 'my-models', // The name identifying this resource in the API
      fromJson: MyModel.fromJson, // Reference to your fromJson factory/function
      toJson: (model) => model.toJson(), // Reference to your toJson method/function
    );
    ```

4.  **Perform CRUD Operations:**

    ```dart
    try {
      // Create
      final newModelData = MyModel(id: '', name: 'New Item'); // ID might be ignored by API
      // Example: Create a new item (global)
      final createResponseGlobal = await myModelApi.create(item: newModelData);
      final createdModelGlobal = createResponseGlobal.data; // Access data from envelope
      print('Created (Global): ${createdModelGlobal.id}');

      // Example: Create a new item for a specific user
      const userId = 'some-user-id'; // Replace with actual user ID
      final createResponseUser = await myModelApi.create(
        item: newModelData.copyWith(id: ''), // Ensure new ID for user-scoped
        userId: userId,
      );
      final createdModelUser = createResponseUser.data; // Access data from envelope
      print('Created (User $userId): ${createdModelUser.id}');

      // Read All with filtering, sorting, and pagination
      final filter = {'status': 'published', 'category': 'tech'};
      final sort = [SortOption('publishDate', SortOrder.desc)];
      final pagination = PaginationOptions(limit: 10);

      final readAllResponse = await myModelApi.readAll(
        userId: userId,
        filter: filter,
        sort: sort,
        pagination: pagination,
      );
      final paginatedModels = readAllResponse.data;
      print('Found ${paginatedModels.items.length} models matching query.');
      if (paginatedModels.hasMore) {
        print('More items available. Next cursor: ${paginatedModels.cursor}');
      }

      // Read One
      if (paginatedModels.items.isNotEmpty) {
        final firstModelId = paginatedModels.items.first.id;
        // Example: Read one item by ID (global)
        final readResponseGlobal = await myModelApi.read(id: firstModelId);
        final fetchedModelGlobal = readResponseGlobal.data; // Access data from envelope
        print('Fetched (Global): ${fetchedModelGlobal.name}');

        // Update
        final updatedData = MyModel(id: firstModelId, name: 'Updated Name');
        // Example: Update an item (global)
        final updateResponseGlobal = await myModelApi.update(
          id: firstModelId,
          item: updatedData,
        );
        final updatedModelGlobal = updateResponseGlobal.data; // Access data from envelope
        print('Updated (Global): ${updatedModelGlobal.name}');

        // Delete (no change in return type)
        // Example: Delete an item (global)
        await myModelApi.delete(id: firstModelId);
        print('Deleted model with ID (Global): $firstModelId');

        // Example: Delete an item for a specific user
        // (Assuming the user has an item with this ID)
        // await myModelApi.delete(id: firstModelId, userId: userId);
        // print('Deleted model with ID (User $userId): $firstModelId');
      }
    } on HttpException catch (e) {
      // Handle specific HTTP errors from http_client
      print('API Error: $e');
      if (e is NotFoundException) {
        // Handle 404 specifically
      }
      // ... other specific exception types
    } catch (e) {
      // Handle other potential errors (e.g., FormatException during deserialization)
      print('An unexpected error occurred: $e');
    }
    ```

## 🔑 Licensing

This package is source-available and licensed under the [PolyForm Free Trial 1.0.0](LICENSE). Please review the terms before use.

For commercial licensing options that grant the right to build and distribute unlimited applications, please visit the main [**Flutter News App - Full Source Code Toolkit**](https://github.com/flutter-news-app-full-source-code) organization.
