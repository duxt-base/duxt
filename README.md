# Duxt

A meta-framework for [Jaspr](https://jaspr.dev) with module-based architecture, file-based routing, and scaffold generators.

## Features

- **Module-Based Architecture** - Organize code by feature
- **File-Based Routing** - Pages auto-generate routes
- **Simple API Client** - Static `Api` class for HTTP calls
- **SPA State Management** - `DuxtState` mixin for loading/error handling
- **Scaffold Generator** - Full CRUD generation
- **Tailwind CSS** - Built-in integration

## Installation

```bash
dart pub global activate duxt
```

## Quick Start

```bash
duxt create my-app
cd my-app
dart pub get
duxt dev
```

## Project Structure

```
my-app/
├── lib/
│   ├── posts/                   # Module
│   │   ├── pages/
│   │   │   ├── index.dart       # /posts
│   │   │   └── [id].dart        # /posts/:id
│   │   ├── components/
│   │   │   └── post_card.dart
│   │   ├── model.dart
│   │   └── api.dart
│   ├── shared/
│   │   └── layouts/
│   │       └── default.dart
│   └── app.dart
└── web/
    └── index.html
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `duxt create <name>` | Create new project |
| `duxt dev [--port]` | Start dev server |
| `duxt build` | Build for production |
| `duxt start [--port]` | Start production server |
| `duxt g <type> <name>` | Generate file |
| `duxt scaffold <name>` | Generate full CRUD module |

## Generators

```bash
# Generate module
duxt g module posts

# Generate page
duxt g page posts/[id]

# Generate component
duxt g component posts/card title:String

# Generate model
duxt g model posts title:String content:String

# Full CRUD scaffold
duxt scaffold posts title:String content:String author:String
```

**Type shortcuts:** `p`=page, `c`=component, `m`=model, `a`=api, `l`=layout

## Api Class

```dart
import 'package:duxt/duxt.dart';

// Configure once
Api.configure(baseUrl: 'https://api.example.com');
Api.setAuth('your-token');

// Use anywhere
final posts = await Api.get('/posts');
final post = await Api.post('/posts', body: {'title': 'Hello'});
await Api.put('/posts/1', body: {'title': 'Updated'});
await Api.delete('/posts/1');
```

## Module Api Pattern

```dart
// lib/posts/api.dart
class PostsApi {
  static Future<List<Post>> getAll() =>
    Api.get('/posts').then((data) => Post.fromList(data));

  static Future<Post> getOne(String id) =>
    Api.get('/posts/$id').then(Post.fromJson);

  static Future<Post> create(Post post) =>
    Api.post('/posts', body: post.toJson()).then(Post.fromJson);
}
```

## DuxtState (SPA)

```dart
class _PostsState extends DuxtState<PostsPage, List<Post>> {
  @override
  Future<List<Post>> load() => PostsApi.getAll();

  @override
  Component buildLoading() => div([text('Loading...')]);

  @override
  Component buildError(Object e) => div([text('Error: $e')]);

  @override
  Component buildData(List<Post> posts) => PostList(posts: posts);
}
```

## Requirements

- Dart SDK ^3.0.0
- Jaspr ^0.22.1

## License

MIT
