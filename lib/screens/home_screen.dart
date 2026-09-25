import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:photo_view/photo_view.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import 'search_screen.dart';
import 'card_gallery_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _pages = const [
    _HomeFeed(),
    SearchScreen(),
    SizedBox.shrink(),
    CardGalleryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 2) {
            context.push('/post/create');
            return;
          }
          setState(() => _currentIndex = i);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Search'),
          BottomNavigationBarItem(icon: _CreateFabIcon(theme.colorScheme.primary), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.mail_rounded), label: 'Gallery'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}

class _CreateFabIcon extends StatelessWidget {
  final Color color;
  const _CreateFabIcon(this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
    );
  }
}

class _HomeFeed extends StatefulWidget {
  const _HomeFeed();
  @override
  State<_HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<_HomeFeed> {
  final Map<String, UserModel> _userCache = {};
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final uid = FirebaseService().getCurrentUserId();
    if (uid != null) {
      final u = await FirebaseService().getUserProfile(uid);
      if (mounted) setState(() => _currentUser = u);
    }
  }

  Future<UserModel?> _getUser(String id) async {
    if (_userCache.containsKey(id)) return _userCache[id];
    final u = await FirebaseService().getUserProfile(id);
    if (u != null) _userCache[id] = u;
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseService().getCurrentUserId();
    if (uid == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🥝', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Text('Kiwi', style: KiwiTextStyles.titleLarge.copyWith(color: theme.colorScheme.onSurface)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => context.push('/post/create'),
          ),
          // BOUTON CHAT MESSAGERIE
          IconButton(
            icon: const Icon(Icons.send_rounded), // Style Instagram DM
            onPressed: () => context.push('/chat_list'),
          ),
          // BOUTON NOTIFICATIONS
          StreamBuilder<int>(
            stream: FirebaseService().getUnreadNotifCount(uid),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.favorite_border_rounded), onPressed: () => context.push('/notifications')),
                  if (count > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: KiwiColors.error, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildStoriesSection(uid, theme)),
            SliverToBoxAdapter(child: Divider(color: theme.dividerColor, height: 1)),
            _buildPostsFeed(uid, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesSection(String uid, ThemeData theme) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: StreamBuilder<List<StoryModel>>(
        stream: FirebaseService().getFeedStories(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return _shimmerStories();
          final stories = snap.data ?? [];
          final Map<String, List<StoryModel>> userStories = {};
          for (final s in stories) {
            userStories.putIfAbsent(s.userId, () => []).add(s);
          }
          final usersIds = userStories.keys.toList();
          usersIds.remove(uid);
          
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: usersIds.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return _buildMyStoryThumb(uid, userStories[uid] ?? [], theme);
              final storyUserId = usersIds[i - 1];
              final userSts = userStories[storyUserId]!;
              final allViewed = userSts.every((s) => s.viewedBy.contains(uid));
              return FutureBuilder<UserModel?>(
                future: _getUser(storyUserId),
                builder: (context, uSnap) {
                  final u = uSnap.data;
                  if (u == null) return const SizedBox.shrink();
                  return _buildStoryThumb(u, userSts, allViewed, theme);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMyStoryThumb(String uid, List<StoryModel> myStories, ThemeData theme) {
    final hasStory = myStories.isNotEmpty;
    return GestureDetector(
      onTap: () {
        if (hasStory) _viewStories(myStories, _currentUser);
        else context.push('/post/create');
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: hasStory ? Border.all(color: KiwiColors.dividerLight, width: 2) : null),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                      backgroundImage: _currentUser?.avatarUrl.isNotEmpty == true ? CachedNetworkImageProvider(_currentUser!.avatarUrl) : null,
                      child: _currentUser?.avatarUrl.isEmpty == true ? Text(_currentUser!.fruitEmoji, style: const TextStyle(fontSize: 28)) : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.surface, width: 2)),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Mon statut', style: KiwiTextStyles.caption.copyWith(color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryThumb(UserModel u, List<StoryModel> stories, bool allViewed, ThemeData theme) {
    return GestureDetector(
      onTap: () => _viewStories(stories, u),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: allViewed ? null : LinearGradient(colors: [KiwiColors.accent, theme.colorScheme.primary], begin: Alignment.topRight, end: Alignment.bottomLeft),
                border: allViewed ? Border.all(color: KiwiColors.textSecondary.withOpacity(0.3), width: 2) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                      backgroundImage: u.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(u.avatarUrl) : null,
                      child: u.avatarUrl.isEmpty ? Text(u.fruitEmoji, style: const TextStyle(fontSize: 24)) : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(u.displayName.split(' ').first, style: KiwiTextStyles.caption.copyWith(color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsFeed(String uid, ThemeData theme) {
    return StreamBuilder<List<PostModel>>(
      stream: FirebaseService().getFeedPosts(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())));
        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Text('🔍', style: TextStyle(fontSize: 50)),
                  const SizedBox(height: 16),
                  Text('Rien à voir ici !', style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Text('Suis tes amis pour voir leurs moments', style: KiwiTextStyles.bodyMedium.copyWith(color: KiwiColors.textSecondary), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        return SliverList(delegate: SliverChildBuilderDelegate((context, i) => _buildPostCard(posts[i], uid, theme), childCount: posts.length));
      },
    );
  }

  Widget _buildPostCard(PostModel post, String currentUserId, ThemeData theme) {
    return FutureBuilder<UserModel?>(
      future: _getUser(post.userId),
      builder: (context, snap) {
        final author = snap.data;
        if (author == null) return const SizedBox.shrink();
        final isLiked = post.isLikedBy(currentUserId);
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.isShared)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.repeat_rounded, size: 16, color: KiwiColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('${author.displayName} a reposté', style: KiwiTextStyles.caption),
                    ],
                  ),
                ),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: author.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(author.avatarUrl) : null,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  child: author.avatarUrl.isEmpty ? Text(author.fruitEmoji) : null,
                ),
                title: Text(author.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('@${author.username}', style: KiwiTextStyles.caption),
                trailing: post.userId == currentUserId 
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (val) {
                        if (val == 'delete') FirebaseService().deletePost(post.id);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
                      ],
                    )
                  : null,
                onTap: () => context.push('/profile/${author.id}'),
              ),
              GestureDetector(
                onDoubleTap: () => FirebaseService().toggleLikePost(post.id, currentUserId),
                child: post.postType == PostType.media && post.imageUrl != null
                    ? CachedNetworkImage(imageUrl: post.imageUrl!, fit: BoxFit.cover, width: double.infinity, height: 400)
                    : Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 300, maxHeight: 400),
                        decoration: BoxDecoration(color: Color(int.parse(post.backgroundColor.replaceFirst('#', '0xFF')))),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(post.category.emoji, style: const TextStyle(fontSize: 60)),
                              const SizedBox(height: 16),
                              Text(post.title, style: KiwiTextStyles.displayMedium.copyWith(color: Color(int.parse(post.textColor.replaceFirst('#', '0xFF')))), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Opacity(opacity: isLiked ? 1.0 : 0.4, child: Text('🥝', style: TextStyle(fontSize: isLiked ? 28 : 24))),
                      onPressed: () => FirebaseService().toggleLikePost(post.id, currentUserId),
                    ),
                    Text('${post.likesCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 26),
                      onPressed: () => context.push('/post/${post.id}/comments'),
                    ),
                    Text('${post.commentsCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.send_outlined, size: 26),
                      onPressed: () async {
                        await FirebaseService().sharePost(post, currentUserId);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reposté sur ton profil !')));
                      },
                    ),
                    Text('${post.sharesCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                  ],
                ),
              ),
              if (post.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 8),
                  child: RichText(
                    text: TextSpan(
                      style: KiwiTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
                      children: [
                        TextSpan(text: '${author.username} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: post.description),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
                child: Text('Il y a ${_formatTime(post.createdAt)}', style: KiwiTextStyles.caption),
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewStories(List<StoryModel> stories, UserModel? user) {
    if (user == null || stories.isEmpty) return;
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _StoryViewer(stories: stories, user: user),
    );
  }

  Widget _shimmerStories() => ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
            child: Container(width: 64, height: 64, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          ),
        ),
      );

  String _formatTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'l\'instant';
  }
}

class _StoryViewer extends StatefulWidget {
  final List<StoryModel> stories;
  final UserModel user;
  const _StoryViewer({required this.stories, required this.user});
  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late AnimationController _animCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    // Durée augmentée à 12 secondes pour laisser le temps de lire
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _animCtrl.forward();
    _animCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _nextStory();
    });
    _markViewed();
  }

  void _markViewed() {
    final uid = FirebaseService().getCurrentUserId();
    if (uid != null && !widget.stories[_currentIndex].viewedBy.contains(uid)) {
      FirebaseService().markStoryViewed(widget.stories[_currentIndex].id, uid);
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _animCtrl.forward(from: 0);
      _markViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _animCtrl.forward(from: 0);
      _markViewed();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) _prevStory();
          else _nextStory();
        },
        onLongPressDown: (_) => _animCtrl.stop(),
        onLongPressUp: () => _animCtrl.forward(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(), // Désactive le swipe manuel pour ne pas gêner le zoom
              itemCount: widget.stories.length,
              itemBuilder: (context, i) {
                final s = widget.stories[i];
                if (s.imageUrl != null) {
                  return PhotoView(
                    imageProvider: CachedNetworkImageProvider(s.imageUrl!),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    backgroundDecoration: const BoxDecoration(color: Colors.black),
                    scaleStateChangedCallback: (state) {
                      // Met en pause l'animation pendant le zoom
                      if (state == PhotoViewScaleState.zoomedIn) _animCtrl.stop();
                      else _animCtrl.forward();
                    },
                  );
                }
                return Container(
                  color: Color(int.parse(s.backgroundColor.replaceFirst('#', '0xFF'))),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(s.content, textAlign: TextAlign.center, style: TextStyle(color: Color(int.parse(s.textColor.replaceFirst('#', '0xFF'))), fontSize: 32, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
            // BARRES DE PROGRESSION
            Positioned(
              top: 50, left: 10, right: 10,
              child: Row(
                children: widget.stories.map((s) {
                  final i = widget.stories.indexOf(s);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedBuilder(
                        animation: _animCtrl,
                        builder: (context, child) {
                          double value = 0;
                          if (i < _currentIndex) value = 1;
                          else if (i == _currentIndex) value = _animCtrl.value;
                          return LinearProgressIndicator(value: value, backgroundColor: Colors.white38, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 3);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // EN-TÊTE USER
            Positioned(
              top: 70, left: 16, right: 16,
              child: Row(
                children: [
                  CircleAvatar(radius: 18, backgroundImage: widget.user.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(widget.user.avatarUrl) : null, backgroundColor: Colors.grey, child: widget.user.avatarUrl.isEmpty ? Text(widget.user.fruitEmoji, style: const TextStyle(fontSize: 16)) : null),
                  const SizedBox(width: 10),
                  Text(widget.user.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}