/// Blog index page template (server-rendered shell + client component)
const blogIndexTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt/duxt.dart';
import 'package:duxt_ui/duxt_ui.dart';

// Server-rendered shell
class BlogPage extends StatelessComponent {
  const BlogPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 pt-24 pb-20 px-4', [
      div(classes: 'max-w-4xl mx-auto', [
        div(classes: 'text-center mb-12', [
          DBadge(label: 'Blog', color: DBadgeColor.primary),
          h1(classes: 'text-4xl font-bold text-white mt-4 mb-4', [Component.text('Latest Posts')]),
          p(classes: 'text-gray-400', [Component.text('Fullstack example with DuxtORM')]),
        ]),
        // Client-side component for fetching posts
        const BlogPosts(),
      ]),
    ]);
  }
}

// Client-only component that fetches data
@client
class BlogPosts extends StatefulComponent {
  const BlogPosts({super.key});

  @override
  State<BlogPosts> createState() => _BlogPostsState();
}

class _BlogPostsState extends State<BlogPosts> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Only fetch on client side
    if (kIsWeb) {
      _fetchPosts();
    }
  }

  Future<void> _fetchPosts() async {
    try {
      final data = await Api.get('/posts');
      setState(() {
        _posts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'API server not running';
        _loading = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    if (_loading) {
      return div(classes: 'flex justify-center py-12', [DSpinner(size: DSpinnerSize.lg)]);
    }
    if (_error != null) {
      return DAlert(title: 'Error', description: _error!, color: DAlertColor.error);
    }
    if (_posts.isEmpty) {
      return div(classes: 'text-center py-12', [
        p(classes: 'text-gray-400', [Component.text('No posts yet.')]),
      ]);
    }
    return div(classes: 'space-y-6', [
      for (final post in _posts) _postCard(post),
    ]);
  }

  Component _postCard(Map<String, dynamic> post) {
    return a(
      href: '/blog/${post['slug']}',
      classes: 'block bg-gray-800/50 rounded-xl p-6 border border-gray-700/50 hover:border-cyan-500/50 transition-colors',
      [
        h2(classes: 'text-xl font-semibold text-white mb-2', [Component.text(post['title'] ?? 'Untitled')]),
        if (post['excerpt'] != null) p(classes: 'text-gray-400 mb-4', [Component.text(post['excerpt'])]),
        span(classes: 'text-cyan-400 text-sm', [Component.text('Read more →')]),
      ],
    );
  }
}
''';

/// Blog post detail page template (dynamic route: _slug_.dart -> /blog/:slug)
const blogPostTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt/duxt.dart';
import 'package:duxt_ui/duxt_ui.dart';

// Shell component that gets the slug from route
class BlogPostPage extends StatelessComponent {
  final String slug;
  const BlogPostPage({required this.slug, super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 pt-24 pb-20 px-4', [
      div(classes: 'max-w-3xl mx-auto', [
        div(classes: 'mb-8', [
          Link(to: '/blog', child: span(classes: 'text-cyan-400 hover:text-cyan-300', [Component.text('← Back to Blog')])),
        ]),
        // Client-side component for fetching the post
        BlogPostContent(slug: slug),
      ]),
    ]);
  }
}

// Client-only component that fetches the post
@client
class BlogPostContent extends StatefulComponent {
  final String slug;
  const BlogPostContent({required this.slug, super.key});

  @override
  State<BlogPostContent> createState() => _BlogPostContentState();
}

class _BlogPostContentState extends State<BlogPostContent> {
  Map<String, dynamic>? _post;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Only fetch on client side
    if (kIsWeb) {
      _fetchPost();
    }
  }

  Future<void> _fetchPost() async {
    try {
      final data = await Api.get('/posts/${component.slug}');
      setState(() {
        _post = data['post'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Post not found or API not running';
        _loading = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    if (_loading) {
      return div(classes: 'flex justify-center py-12', [DSpinner(size: DSpinnerSize.lg)]);
    }
    if (_error != null) {
      return DAlert(title: 'Error', description: _error!, color: DAlertColor.error);
    }
    if (_post == null) {
      return DAlert(title: 'Error', description: 'Post not found', color: DAlertColor.error);
    }
    return article([
      h1(classes: 'text-4xl font-bold text-white mb-8', [Component.text(_post!['title'] ?? 'Untitled')]),
      div(classes: 'prose prose-invert max-w-none', [
        for (final line in (_post!['content'] as String? ?? '').split('\n')) _renderLine(line),
      ]),
    ]);
  }

  Component _renderLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return div(classes: 'h-4', []);
    if (t.startsWith('# ')) return h1(classes: 'text-3xl font-bold text-white mt-8 mb-4', [Component.text(t.substring(2))]);
    if (t.startsWith('## ')) return h2(classes: 'text-2xl font-semibold text-white mt-6 mb-3', [Component.text(t.substring(3))]);
    if (t.startsWith('- ')) return li(classes: 'text-gray-300 ml-4', [Component.text(t.substring(2))]);
    return p(classes: 'text-gray-300 mb-2', [Component.text(line)]);
  }
}
''';
