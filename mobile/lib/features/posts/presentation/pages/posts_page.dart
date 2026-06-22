import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  bool _isOnline = true;
  bool _cacheHit = false;
  List<_Post> _posts = [];
  int _loadTimeMs = 0;
  String? _selectedId;

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
    });

    final stopwatch = Stopwatch()..start();

    // Simulate cache hit on repeat load
    final bool hitCache = !forceRefresh && _posts.isNotEmpty;
    await Future.delayed(Duration(milliseconds: hitCache ? 45 : 620));

    stopwatch.stop();

    if (mounted) {
      setState(() {
        _cacheHit = hitCache;
        _loadTimeMs = stopwatch.elapsedMilliseconds;
        _isLoading = false;
        _posts = _mockPosts;
      });
    }
  }

  void _softDelete(String id) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Delete post?', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will soft-delete the post — it will be marked with deleted_at and hidden from all responses.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningDim,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Text('🗑️', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SoftDeleteInterceptor: DELETE → PATCH {deleted_at: now}',
                      style: TextStyle(color: AppColors.warning, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _posts.removeWhere((p) => p.id == id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Text('🗑️ Post soft-deleted · ', style: TextStyle(color: AppColors.textPrimary)),
                      Text('deleted_at set', style: TextStyle(color: AppColors.warning, fontFamily: 'monospace', fontSize: 12)),
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
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          NetworkBanner(isOnline: _isOnline),
          _AppBar(
            isOnline: _isOnline,
            cacheHit: _cacheHit,
            loadTimeMs: _loadTimeMs,
            onRefresh: () => _loadPosts(forceRefresh: true),
            onToggleNetwork: () => setState(() => _isOnline = !_isOnline),
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
                  '✅ ValidatorInterceptor will check title (min 3) and body (min 10) before sending',
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
              final newPost = _Post(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleCtrl.text.isEmpty ? 'New Post' : titleCtrl.text,
                body: bodyCtrl.text.isEmpty ? 'Post content goes here.' : bodyCtrl.text,
                author: 'demo@example.com',
                createdAt: DateTime.now(),
                tags: ['new'],
              );
              setState(() => _posts.insert(0, newPost));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final bool isOnline;
  final bool cacheHit;
  final int loadTimeMs;
  final VoidCallback onRefresh;
  final VoidCallback onToggleNetwork;

  const _AppBar({
    required this.isOnline,
    required this.cacheHit,
    required this.loadTimeMs,
    required this.onRefresh,
    required this.onToggleNetwork,
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

          // Toggle network (demo)
          Tooltip(
            message: isOnline ? 'Simulate offline' : 'Restore connection',
            child: IconButton(
              onPressed: onToggleNetwork,
              icon: Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? AppColors.success : AppColors.error,
                size: 18,
              ),
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
                ...post.tags.map((t) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: InterceptorBadge(label: t, color: AppColors.textMuted),
                )),
              ],
            ),
          ],
        ),
      ),
    );
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
                  _interceptorFiredRow('💾', 'CacheInterceptor', 'X-Cache: HIT', AppColors.tagCache),
                  _interceptorFiredRow('⚡', 'PerformanceInterceptor', '45ms · ✓ fast', AppColors.tagPerf),
                  _interceptorFiredRow('📋', 'LogInterceptor', 'GET /posts/${post.id} 200', AppColors.tagLog),
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
  final List<String> tags;

  const _Post({required this.id, required this.title, required this.body, required this.author, required this.createdAt, required this.tags});
}

final _mockPosts = [
  _Post(id: '1', title: 'Network Interceptor Deep Dive', body: 'Learn how connectivity_plus detects network state before every request, preventing silent failures when the device is offline. We explore the full ConnectivityResult enum and edge cases like VPN connections.', author: 'demo@example.com', createdAt: DateTime.now().subtract(const Duration(hours: 2)), tags: ['network', 'dio']),
  _Post(id: '2', title: 'Auth Token Refresh Strategy', body: 'The AuthInterceptor silently refreshes expired tokens using a refresh token stored in FlutterSecureStorage. Parallel 401 requests are queued and retried after a single refresh — preventing a refresh storm.', author: 'demo@example.com', createdAt: DateTime.now().subtract(const Duration(hours: 5)), tags: ['auth', 'jwt']),
  _Post(id: '3', title: 'AES-256 Request Encryption', body: 'Sensitive endpoints encrypt their JSON body using AES-256-CBC before transmission. The key is stored in secure storage and rotated periodically. A random IV per request prevents identical payloads from producing the same ciphertext.', author: 'demo@example.com', createdAt: DateTime.now().subtract(const Duration(days: 1)), tags: ['security', 'aes']),
  _Post(id: '4', title: 'Hive Cache with TTL', body: 'The CacheInterceptor stores GET responses in Hive with configurable TTL. It reads Cache-Control: max-age from server responses and respects them. Cache invalidation is triggered automatically after mutations.', author: 'demo@example.com', createdAt: DateTime.now().subtract(const Duration(days: 2)), tags: ['cache', 'hive']),
  _Post(id: '5', title: 'Soft Delete vs Hard Delete', body: 'The SoftDeleteInterceptor transforms DELETE into PATCH {deleted_at: now}. Response filtering removes soft-deleted records from all GET responses transparently. Hard deletes require an explicit extra flag.', author: 'demo@example.com', createdAt: DateTime.now().subtract(const Duration(days: 3)), tags: ['soft-delete']),
  _Post(id: '6', title: 'BLoC + StateInterceptor Bridge', body: 'The StateInterceptor connects the Dio network layer to a global NetworkCubit. Every request emits NetworkLoading; every response emits NetworkSuccess or NetworkError. UI widgets subscribe to this stream for loading overlays.', author: 'demo@example.com', createdAt: DateTime.now().subtract(const Duration(days: 4)), tags: ['bloc', 'state']),
];
