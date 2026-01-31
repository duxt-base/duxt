/// Example Duxt application demonstrating the API client.
///
/// This example shows:
/// - API configuration
/// - Making HTTP requests
/// - Model classes with JSON serialization
library;

import 'package:duxt/duxt.dart';

/// Configure the API client at app startup.
void configureApi() {
  Api.configure(
    baseUrl: 'https://api.example.com',
    headers: {'X-Custom-Header': 'value'},
  );

  // Set auth token for authenticated requests
  Api.setAuth('your-jwt-token');
}

/// Example model class with JSON serialization.
class Post {
  final String id;
  final String title;
  final String content;

  Post({required this.id, required this.title, required this.content});

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
      };

  static List<Post> fromList(List<dynamic> list) {
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }
}

/// Example API class for posts module.
///
/// Usage:
/// ```dart
/// final posts = await PostsApi.getAll();
/// final post = await PostsApi.getOne('123');
/// await PostsApi.create(Post(id: '1', title: 'Hello', content: 'World'));
/// await PostsApi.delete('123');
/// ```
class PostsApi {
  /// Fetch all posts.
  static Future<List<Post>> getAll() async {
    final data = await Api.get('/posts') as List;
    return Post.fromList(data);
  }

  /// Fetch a single post by ID.
  static Future<Post> getOne(String id) async {
    final data = await Api.get('/posts/$id') as Map<String, dynamic>;
    return Post.fromJson(data);
  }

  /// Create a new post.
  static Future<Post> create(Post post) async {
    final data =
        await Api.post('/posts', body: post.toJson()) as Map<String, dynamic>;
    return Post.fromJson(data);
  }

  /// Update an existing post.
  static Future<Post> update(String id, Post post) async {
    final data = await Api.put('/posts/$id', body: post.toJson())
        as Map<String, dynamic>;
    return Post.fromJson(data);
  }

  /// Delete a post.
  static Future<void> delete(String id) async {
    await Api.delete('/posts/$id');
  }
}

/// Example of using AsyncData for standalone async state.
Future<void> asyncDataExample() async {
  final postData = AsyncData<Post>();

  // Set loading state
  postData.setLoading();

  // Check state
  if (postData.loading) {
    print('Loading...');
  }

  // Load and set data
  try {
    final post = await PostsApi.getOne('1');
    postData.setData(post);
  } catch (e) {
    postData.setError(e);
  }

  // Check result
  if (postData.hasError) {
    print('Error: ${postData.error}');
  } else if (postData.hasData) {
    print('Post: ${postData.data!.title}');
  }
}
