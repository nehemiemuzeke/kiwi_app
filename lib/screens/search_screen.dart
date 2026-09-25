import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<UserModel> _results = [];
  List<UserModel> _suggestions = [];
  bool _loading = false;
  bool _loadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final list = await FirebaseService().getSuggestedUsers(limit: 10);
      if (!mounted) return;
      setState(() {
        _suggestions = list;
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final list = await FirebaseService().searchUsers(v.trim());
        if (!mounted) return;
        setState(() {
          _results = list;
          _loading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = _searchCtrl.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text('Rechercher', style: KiwiTextStyles.titleLarge.copyWith(color: theme.colorScheme.onSurface)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '🔍  Rechercher un kiwi...',
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: hasQuery ? _buildResults(theme) : _buildSuggestions(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_loading) return _shimmerList();
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Aucun kiwi trouvé', style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, i) => _userTile(_results[i], theme),
    );
  }

  Widget _buildSuggestions(ThemeData theme) {
    if (_loadingSuggestions) return _shimmerList();
    if (_suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥝', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Recherche tes amis', style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
          ],
        ),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'SUGGESTIONS POUR VOUS',
            style: KiwiTextStyles.caption.copyWith(color: KiwiColors.textSecondary, letterSpacing: 1.2, fontWeight: FontWeight.w700),
          ),
        ),
        ..._suggestions.map((u) => _userTile(u, theme)).toList(),
      ],
    );
  }

  Widget _userTile(UserModel user, ThemeData theme) {
    final me = FirebaseService().getCurrentUserId();
    return InkWell(
      onTap: () => context.push('/profile/${user.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
              backgroundImage: user.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(user.avatarUrl) : null,
              child: user.avatarUrl.isEmpty
                  ? Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                      style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: KiwiTextStyles.bodyLarge.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('@${user.username}', style: KiwiTextStyles.bodySmall.copyWith(color: KiwiColors.textSecondary)),
                ],
              ),
            ),
            if (me != null && me != user.id)
              StreamBuilder<bool>(
                stream: FirebaseService().isFollowingStream(me, user.id),
                builder: (context, snap) {
                  final isFollowing = snap.data ?? false;
                  return _KiwiButton(
                    isFollowing: isFollowing,
                    theme: theme,
                    onTap: () async {
                      if (isFollowing) {
                        await FirebaseService().unfollowUser(me, user.id);
                      } else {
                        await FirebaseService().followUser(me, user.id);
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _shimmerList() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFEEEEEE),
          highlightColor: const Color(0xFFFAFAFA),
          child: Row(
            children: [
              const CircleAvatar(radius: 24, backgroundColor: Colors.white),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, width: 120, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 80, color: Colors.white),
                  ],
                ),
              ),
              Container(height: 34, width: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
            ],
          ),
        ),
      ),
    );
  }
}

class _KiwiButton extends StatefulWidget {
  final bool isFollowing;
  final ThemeData theme;
  final VoidCallback onTap;
  const _KiwiButton({required this.isFollowing, required this.theme, required this.onTap});
  @override
  State<_KiwiButton> createState() => _KiwiButtonState();
}

class _KiwiButtonState extends State<_KiwiButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final following = widget.isFollowing;
    final theme = widget.theme;
    return GestureDetector(
      onTap: () {
        setState(() => _pressed = true);
        widget.onTap();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _pressed = false);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: following ? theme.dividerColor : theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          following ? '✅ Kiwied' : '🥝 Kiwi',
          style: KiwiTextStyles.bodySmall.copyWith(
            color: following ? theme.colorScheme.onSurface : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ).animate(target: _pressed ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 150.ms),
    );
  }
}