import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:interceptors_demo/core/dependencies/app_dependencies.dart';
import 'package:interceptors_demo/core/interceptors/cache_interceptor.dart';
import 'package:interceptors_demo/shared/theme/app_theme.dart';
import 'package:interceptors_demo/shared/widgets/shared_widgets.dart';

class PostsPage extends StatefulWidget {
  final String? postId;
  const PostsPage({super.key, this.postId});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  bool _isLoading = true;
  bool _cacheHit = false;
  List<_Post> _posts = [];
  int _loadTimeMs = 0;
  String? _selectedId;
  String? _errorMessage;

  final Dio _dio = AppDependencies.instance.dio;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.postId;
    _loadPosts();
  }

  Future<void> _loadPosts({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _cacheHit = false;
      _errorMessage = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _dio.get(
        '/posts',
        options: Options(
          extra: forceRefresh ? {'noCache': true} : null,
        ),
      );

      stopwatch.stop();

      final cacheHeader = response.headers.value('X-Cache');
      final List<dynamic> rawPosts = response.data['data'] as List<dynamic>;

      if (mounted) {
        setState(() {
          _cacheHit = cacheHeader == 'HIT';
          _loadTimeMs = stopwatch.elapsedMilliseconds;
          _isLoading = false;
          _posts = rawPosts.map((p) => _Post.fromJson(p as Map<String, dynamic>)).toList();
        });
      }
    } on DioException catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadTimeMs = stopwatch.elapsedMilliseconds;
          _errorMessage = e.error?.toString() ?? e.message ?? 'Failed to load posts';
        });
      }
    }
  }

  Future<void> _createPost(String title, String body) async {
    try {
      final response = await _dio.post(
        '/posts',
        data: {'title': title, 'body': body},
        options: Options(
          extra: {'encrypt': true}, // Demo: encrypt request body
        ),
      );

      final newPost = _Post.fromJson(response.data['data'] as Map<String, dynamic>);
      setState(() => _posts.insert(0, newPost));
      await CacheInterceptor.invalidate('/posts');
    } on DioException catch (e) {
      _showError(e.error?.toString() ?? e.message ?? 'Failed to create post');
    }
  }

  Future<void> _softDelete(String id) async {
    try {
      await _dio.delete('/posts/$id');
      setState(() => _posts.removeWhere((p) => p.id == id));
      await CacheInterceptor.invalidate('/posts');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Text('🗑️ Post soft-deleted · ', style: TextStyle(color: AppColors.textPrimary)),
                Text('DELETE → PATCH {deleted_at}', style: TextStyle(color: AppColors.warning, fontFamily: 'monospace', fontSize: 12)),
              ],
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        );
      }
    } on DioException catch (e) {
      _showError(e.error?.toString() ?? e.message ?? 'Failed to delete post');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.error)),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _AppBar(
            cacheHit: _cacheHit,
            loadTimeMs: _loadTimeMs,
            onRefresh: () => _loadPosts(forceRefresh: true),
          ),
          Expanded(
            child: Row(
              children: [
                // ─── Sidebar ────────────────────────────────────────────
                _Sidebar(currentRoute: 'posts'),

                // ─── Posts List ─────────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const _LoadingSkeleton()
                      : _errorMessage != null
                          ? _ErrorView(message: _errorMessage!, onRetry: _loadPosts)
                          : Column(
                              children: [
                                _PostsHeader(
                                  count: _posts.length,
                                  cacheHit: _cacheHit,
                                  loadTimeMs: _loadTimeMs,
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _posts.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) => _PostCard(
                                      post: _posts[i],
                                      isSelected: _selectedId == _posts[i].id,
                                      onTap: () => setState(() => _selectedId = _posts[i].id),
                                      onDelete: () => _softDelete(_posts[i].id),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),

                // ─── Detail Panel ────────────────────────────────────────
                if (_selectedId != null)
                  _DetailPanel(
                    post: _posts.firstWhere(
                      (p) => p.id == _selectedId,
                      orElse: () => _posts.first,
                    ),
                    onClose: () => setState(() => _selectedId = null),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Create Post', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TITLE', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(hintText: 'Min 3 characters'),
              ),
              const SizedBox(height: 14),
              const Text('BODY', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 6),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(hintText: 'Min 10 characters'),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '✅ ValidatorInterceptor checks title/body.\n🔐 EncryptInterceptor encrypts the body before sending.',
                  style: TextStyle(color: AppColors.accent, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final title = titleCtrl.text.trim();
              final body = bodyCtrl.text.trim();
              if (title.length < 3 || body.length < 10) {
                _showError('Title min 3 chars, body min 10 chars');
                return;
              }
              _createPost(title, body);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final bool cacheHit;
  final int loadTimeMs;
  final VoidCallback onRefresh;

  const _AppBar({
    required this.cacheHit,
    required this.loadTimeMs,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(child: Text('🔗', style: TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 10),
          const Text(
            'Interceptors Demo',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          const Text('/', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          const Text('posts', style: TextStyle(color: AppColors.accent, fontSize: 13)),
          const Spacer(),

          // Cache indicator
          if (cacheHit)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InterceptorBadge(label: 'CACHE HIT', color: AppColors.tagCache, emoji: '💾'),
            ),
          if (loadTimeMs > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${loadTimeMs}ms',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),

          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 18),
            tooltip: 'Refresh (bypass cache)',
          ),
          const _AvatarButton(),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/login'),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.accentDim,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: const Center(
          child: Text('D', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final String currentRoute;
  const _Sidebar({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SideItem('posts', '📄', 'Posts'),
      _SideItem('dashboard', '⚡', 'Interceptors'),
      _SideItem('settings', '⚙️', 'Settings'),
      _SideItem('logs', '📋', 'Logs'),
    ];

    return Container(
      width: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...items.map((item) {
            final isActive = item.id == currentRoute;
            return Tooltip(
              message: item.label,
              preferBelow: false,
              child: GestureDetector(
                onTap: () {
                  if (item.id == 'dashboard') context.go('/dashboard');
                  if (item.id == 'settings') context.go('/settings');
                  if (item.id == 'logs') context.go('/logs');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.accentDim : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? AppColors.accent.withOpacity(0.4) : Colors.transparent,
                    ),
                  ),
                  child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 18))),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SideItem {
  final String id, emoji, label;
  const _SideItem(this.id, this.emoji, this.label);
}

// ─── Posts Header ─────────────────────────────────────────────────────────────
class _PostsHeader extends StatelessWidget {
  final int count;
  final bool cacheHit;
  final int loadTimeMs;

  const _PostsHeader({required this.count, required this.cacheHit, required this.loadTimeMs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Text(
            '$count posts',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          InterceptorBadge(
            label: cacheHit ? '💾 cached' : '🌐 network',
            color: cacheHit ? AppColors.tagCache : AppColors.tagNetwork,
          ),
          const SizedBox(width: 6),
          InterceptorBadge(label: '${loadTimeMs}ms', color: loadTimeMs > 200 ? AppColors.warning : AppColors.success),
        ],
      ),
    );
  }
}

// ─── Post Card ────────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final _Post post;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentDim : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent.withOpacity(0.5) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: TextStyle(
                      color: isSelected ? AppColors.accent : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  color: AppColors.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  icon: const Icon(Icons.more_horiz, color: AppColors.textMuted, size: 16),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                          SizedBox(width: 8),
                          Text('Soft Delete', style: TextStyle(color: AppColors.error, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (v) { if (v == 'delete') onDelete(); },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  post.author,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  _formatDate(post.createdAt),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─── Detail Panel ─────────────────────────────────────────────────────────────
class _DetailPanel extends StatelessWidget {
  final _Post post;
  final VoidCallback onClose;

  const _DetailPanel({required this.post, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                const Text('POST', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const StatusDot(color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(post.author, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),
                  Text(
                    post.body,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.7),
                  ),
                  const SizedBox(height: 24),
                  // Interceptors that served this request
                  const Text('INTERCEPTORS FIRED', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _interceptorFiredRow('💾', 'CacheInterceptor', 'Respects Cache-Control / X-Cache', AppColors.tagCache),
                  _interceptorFiredRow('⚡', 'PerformanceInterceptor', 'Measures request duration', AppColors.tagPerf),
                  _interceptorFiredRow('📋', 'AppLogInterceptor', 'Logs to terminal', AppColors.tagLog),
                  _interceptorFiredRow('🗑️', 'SoftDeleteInterceptor', 'DELETE → PATCH {deleted_at}', AppColors.warning),
                  _interceptorFiredRow('🔐', 'EncryptInterceptor', 'AES-256-CBC on create post', AppColors.tagSecurity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _interceptorFiredRow(String emoji, String name, String detail, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                Text(detail, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading Skeleton ─────────────────────────────────────────────────────────
class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton();

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => Container(
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(_anim.value),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(height: 14, width: 200, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
              Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(4))),
              Container(height: 10, width: 140, decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────
class _Post {
  final String id, title, body, author;
  final DateTime createdAt;

  const _Post({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    required this.createdAt,
  });

  factory _Post.fromJson(Map<String, dynamic> json) {
    return _Post(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      author: json['author_id'] as String? ?? 'unknown',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
