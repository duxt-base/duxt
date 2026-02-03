/// Blog tutorial index page template - guides users through scaffolding their blog
const blogTutorialIndexTemplate = r'''
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

/// Interactive tutorial page that guides users through building their blog
/// with the scaffold command rather than providing predefined modules.
class BlogPage extends StatelessComponent {
  const BlogPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 py-20 px-4', [
      div(classes: 'max-w-4xl mx-auto', [
        // Header
        div(classes: 'text-center mb-16', [
          span(
            classes: 'inline-block px-4 py-1 text-sm font-medium bg-cyan-900/50 text-cyan-300 rounded-full mb-4',
            [Component.text('Interactive Tutorial')],
          ),
          h1(classes: 'text-5xl font-bold text-white mb-4', [
            Component.text('Build Your Blog'),
          ]),
          p(classes: 'text-xl text-gray-400 max-w-2xl mx-auto', [
            Component.text('Follow these steps to create a full-featured blog with Duxt. Each command generates production-ready code with models, APIs, and UI components.'),
          ]),
        ]),

        // Tutorial Steps
        _TutorialStep(
          number: 1,
          title: 'Generate Category Module',
          command: 'duxt scaffold categories name:string slug:string description:text color:string --orm',
          description: 'Create categories to organize your blog posts. This generates the model, API routes, and admin pages for managing categories.',
          tips: ['Categories have a HasMany relation to posts', 'The slug is used for SEO-friendly URLs'],
        ),

        _TutorialStep(
          number: 2,
          title: 'Generate Tag Module',
          command: 'duxt scaffold tags name:string slug:string color:string --orm',
          description: 'Create tags for flexible post labeling. Tags use a many-to-many relationship with posts through a pivot table.',
          tips: ['Each post can have multiple tags', 'Tags are great for cross-category discovery'],
        ),

        _TutorialStep(
          number: 3,
          title: 'Generate Post Module',
          command: 'duxt scaffold posts title:string slug:string content:text excerpt:text featured_image:image published:bool publish_date:datetime category:belongsTo:Category tags:toMany:Tag --orm',
          description: 'Create the main post model with all the fields you need: rich content, featured images, publishing controls, and relations to categories and tags.',
          tips: [
            'belongsTo:Category creates a foreign key relation',
            'toMany:Tag creates a pivot table automatically',
            'Use --no-api flag for SSR-only (no REST endpoints)',
          ],
        ),

        _TutorialStep(
          number: 4,
          title: 'Generate Comment Module (Optional)',
          command: 'duxt scaffold comments content:text author_name:string author_email:email approved:bool post:belongsTo:Post --orm',
          description: 'Add a commenting system with moderation support. Comments belong to posts and can be approved/rejected before display.',
          tips: ['Email validation is handled in the UI', 'approved defaults to false for moderation'],
        ),

        _TutorialStep(
          number: 5,
          title: 'Start Development Server',
          command: 'duxt dev',
          description: 'Launch the development server with hot reload. Your blog models are registered, database tables are created, and API endpoints are ready.',
          tips: ['Hot reload updates both frontend and backend', 'Check the Dev Tools overlay for build status'],
        ),

        // What's Next
        div(classes: 'mt-16 p-8 bg-gray-800/30 rounded-2xl border border-gray-700/50', [
          h2(classes: 'text-2xl font-bold text-white mb-4', [Component.text("What's Generated")]),
          div(classes: 'grid md:grid-cols-2 gap-6', [
            _FeatureCard(
              icon: '📁',
              title: 'Models',
              description: 'lib/models/*.dart - Entity classes with schema, relations, and query helpers',
            ),
            _FeatureCard(
              icon: '🔌',
              title: 'API Routes',
              description: 'server/api/*.dart - RESTful endpoints with CRUD operations',
            ),
            _FeatureCard(
              icon: '📄',
              title: 'Pages',
              description: 'lib/*/pages/*.dart - List, detail, and form pages with data loading',
            ),
            _FeatureCard(
              icon: '🧩',
              title: 'Components',
              description: 'lib/*/components/*.dart - Reusable cards and forms for each model',
            ),
          ]),
        ]),

        // Footer
        div(classes: 'mt-12 text-center', [
          p(classes: 'text-gray-500 text-sm', [
            Component.text('Generated models work with '),
            span(classes: 'text-cyan-400', [Component.text('DuxtORM')]),
            Component.text(' - ActiveRecord-style database operations for Dart'),
          ]),
        ]),
      ]),
    ]);
  }
}

class _TutorialStep extends StatelessComponent {
  final int number;
  final String title;
  final String command;
  final String description;
  final List<String> tips;

  const _TutorialStep({
    required this.number,
    required this.title,
    required this.command,
    required this.description,
    this.tips = const [],
    super.key,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'mb-10 relative', [
      // Step container
      div(classes: 'p-6 bg-gray-800/50 rounded-xl border border-gray-700/50 hover:border-cyan-500/30 transition-colors', [
        // Step header
        div(classes: 'flex items-start gap-4 mb-4', [
          // Number badge
          div(
            classes: 'flex-shrink-0 w-10 h-10 rounded-full bg-gradient-to-br from-cyan-500 to-blue-600 flex items-center justify-center text-white font-bold text-lg shadow-lg shadow-cyan-500/25',
            [Component.text('$number')],
          ),
          div(classes: 'flex-1', [
            h3(classes: 'text-xl font-semibold text-white mb-2', [Component.text(title)]),
            p(classes: 'text-gray-400', [Component.text(description)]),
          ]),
        ]),

        // Command block
        div(classes: 'mt-4 bg-gray-900/80 rounded-lg overflow-hidden', [
          div(classes: 'flex items-center justify-between px-4 py-2 bg-gray-900 border-b border-gray-700/50', [
            span(classes: 'text-xs text-gray-500 font-mono', [Component.text('Terminal')]),
            button(
              classes: 'text-xs text-gray-400 hover:text-cyan-400 transition-colors',
              [Component.text('Copy')],
            ),
          ]),
          pre(classes: 'p-4 overflow-x-auto', [
            code(classes: 'text-sm text-green-400 font-mono whitespace-pre-wrap', [
              Component.text(command),
            ]),
          ]),
        ]),

        // Tips
        if (tips.isNotEmpty)
          div(classes: 'mt-4 space-y-2', [
            for (final tip in tips)
              div(classes: 'flex items-start gap-2 text-sm', [
                span(classes: 'text-cyan-400 mt-0.5', [Component.text('•')]),
                span(classes: 'text-gray-400', [Component.text(tip)]),
              ]),
          ]),
      ]),
    ]);
  }
}

class _FeatureCard extends StatelessComponent {
  final String icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'flex gap-3', [
      span(classes: 'text-2xl', [Component.text(icon)]),
      div([
        h4(classes: 'font-medium text-white', [Component.text(title)]),
        p(classes: 'text-sm text-gray-400', [Component.text(description)]),
      ]),
    ]);
  }
}
''';

/// Blog index page template (SSR with AsyncStatelessComponent)
/// This is used when the user has already scaffolded their blog and wants
/// a working blog listing page.
const blogIndexTemplate = r'''
import 'package:jaspr/server.dart';
import 'package:jaspr/dom.dart';
import 'package:duxt_ui/duxt_ui.dart';

// Import models for SSR data fetching
import '../../models/post.dart';

/// Blog listing page - renders posts on the server using AsyncStatelessComponent
class BlogPage extends AsyncStatelessComponent {
  const BlogPage({super.key});

  @override
  Future<Component> build(BuildContext context) async {
    // Fetch posts from database on the server
    final posts = await Post.findAll(publishedOnly: true, withCategory: true, withTags: true);

    // Return the rendered component (no loading state needed - server waits for data)
    return _buildContent(posts.map((p) => p.toJson()).toList());
  }

  Component _buildContent(List<Map<String, dynamic>> posts) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 pt-24 pb-20 px-4', [
      div(classes: 'max-w-4xl mx-auto', [
        div(classes: 'text-center mb-12', [
          DBadge(label: 'Blog', color: DBadgeColor.primary),
          h1(classes: 'text-4xl font-bold text-white mt-4 mb-4', [Component.text('Latest Posts')]),
          p(classes: 'text-gray-400', [Component.text('Fullstack example with DuxtORM')]),
        ]),
        if (posts.isEmpty)
          div(classes: 'text-center py-12', [
            p(classes: 'text-gray-400', [Component.text('No posts yet.')]),
          ])
        else
          div(classes: 'space-y-6', [
            for (final post in posts) _postCard(post),
          ]),
      ]),
    ]);
  }

  Component _postCard(Map<String, dynamic> post) {
    final category = post['category'] as Map<String, dynamic>?;
    final tags = post['tags'] as List<dynamic>? ?? [];

    return a(
      href: '/blog/${post['slug']}',
      classes: 'block bg-gray-800/50 rounded-xl p-6 border border-gray-700/50 hover:border-cyan-500/50 transition-colors',
      [
        // Featured image
        if (post['featuredImage'] != null)
          div(classes: 'mb-4 rounded-lg overflow-hidden', [
            img(src: post['featuredImage'], classes: 'w-full h-48 object-cover'),
          ]),

        // Category badge
        if (category != null)
          div(classes: 'mb-3', [
            span(
              classes: 'inline-block px-2 py-1 text-xs font-medium bg-cyan-900/50 text-cyan-300 rounded',
              [Component.text(category['name'] ?? '')],
            ),
          ]),

        // Title and excerpt
        h2(classes: 'text-xl font-semibold text-white mb-2', [Component.text(post['title'] ?? 'Untitled')]),
        if (post['excerpt'] != null) p(classes: 'text-gray-400 mb-4', [Component.text(post['excerpt'])]),

        // Tags
        if (tags.isNotEmpty)
          div(classes: 'flex flex-wrap gap-2 mb-4', [
            for (final tag in tags)
              span(
                classes: 'px-2 py-1 text-xs rounded bg-gray-700/50 text-gray-300',
                [Component.text(tag['name'] ?? '')],
              ),
          ]),

        span(classes: 'text-cyan-400 text-sm', [Component.text('Read more →')]),
      ],
    );
  }
}
''';

/// Blog post detail page template (SSR with AsyncStatelessComponent)
const blogPostTemplate = r'''
import 'package:jaspr/server.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:duxt_ui/duxt_ui.dart';

// Import models for SSR data fetching
import '../../models/post.dart';

/// Blog post detail page - renders post on the server using AsyncStatelessComponent
class BlogPostPage extends AsyncStatelessComponent {
  final String slug;
  const BlogPostPage({required this.slug, super.key});

  @override
  Future<Component> build(BuildContext context) async {
    // Fetch post from database on the server with relations
    final post = await Post.findBySlug(slug, withCategory: true, withTags: true);

    // Return the rendered component
    return _buildContent(post?.toJson());
  }

  Component _buildContent(Map<String, dynamic>? post) {
    return div(classes: 'min-h-screen bg-gradient-to-b from-gray-900 to-gray-950 pt-24 pb-20 px-4', [
      div(classes: 'max-w-3xl mx-auto', [
        div(classes: 'mb-8', [
          Link(to: '/blog', child: span(classes: 'text-cyan-400 hover:text-cyan-300', [Component.text('← Back to Blog')])),
        ]),
        if (post == null)
          DAlert(title: 'Error', description: 'Post not found', color: DAlertColor.error)
        else
          _buildPost(post),
      ]),
    ]);
  }

  Component _buildPost(Map<String, dynamic> post) {
    final category = post['category'] as Map<String, dynamic>?;
    final tags = post['tags'] as List<dynamic>? ?? [];

    return article([
      // Featured image
      if (post['featuredImage'] != null)
        div(classes: 'mb-8 rounded-xl overflow-hidden', [
          img(src: post['featuredImage'], classes: 'w-full max-h-96 object-cover'),
        ]),

      // Category
      if (category != null)
        div(classes: 'mb-4', [
          span(
            classes: 'inline-block px-3 py-1 text-sm font-medium bg-cyan-900/50 text-cyan-300 rounded-full',
            [Component.text(category['name'] ?? '')],
          ),
        ]),

      // Title
      h1(classes: 'text-4xl font-bold text-white mb-4', [Component.text(post['title'] ?? 'Untitled')]),

      // Tags
      if (tags.isNotEmpty)
        div(classes: 'flex flex-wrap gap-2 mb-8', [
          for (final tag in tags)
            span(
              classes: 'px-3 py-1 text-sm rounded-full bg-gray-700/50 text-gray-300',
              [Component.text(tag['name'] ?? '')],
            ),
        ]),

      // Content
      div(classes: 'prose prose-invert max-w-none', [
        for (final line in (post['content'] as String? ?? '').split('\n')) _renderLine(line),
      ]),
    ]);
  }

  Component _renderLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return div(classes: 'h-4', []);
    if (t.startsWith('# ')) return h1(classes: 'text-3xl font-bold text-white mt-8 mb-4', [Component.text(t.substring(2))]);
    if (t.startsWith('## ')) return h2(classes: 'text-2xl font-semibold text-white mt-6 mb-3', [Component.text(t.substring(3))]);
    if (t.startsWith('### ')) return h3(classes: 'text-xl font-semibold text-white mt-4 mb-2', [Component.text(t.substring(4))]);
    if (t.startsWith('- ')) return li(classes: 'text-gray-300 ml-4', [Component.text(t.substring(2))]);
    return p(classes: 'text-gray-300 mb-2', [Component.text(line)]);
  }
}
''';
