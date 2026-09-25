import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class CardGalleryScreen extends StatefulWidget {
  const CardGalleryScreen({super.key});
  @override
  State<CardGalleryScreen> createState() => _CardGalleryScreenState();
}

class _CardGalleryScreenState extends State<CardGalleryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _gridView = true;
  final Map<String, UserModel> _userCache = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseService().getCurrentUserId();
    if (uid == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: Text('Mes souvenirs 🥝', style: KiwiTextStyles.titleLarge.copyWith(color: theme.colorScheme.onSurface)),
        actions: [
          IconButton(
            icon: Icon(_gridView ? Icons.timeline_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: KiwiColors.textSecondary,
          labelStyle: KiwiTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
          tabs: const [
            Tab(text: '📬 Reçues'),
            Tab(text: '📤 Envoyées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildList(FirebaseService().getReceivedCards(uid), true, theme),
          _buildList(FirebaseService().getSentCards(uid), false, theme),
        ],
      ),
    );
  }

  Widget _buildList(Stream<List<CardModel>> stream, bool isReceived, ThemeData theme) {
    return StreamBuilder<List<CardModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _shimmerGrid(theme);
        final cards = snap.data ?? [];
        if (cards.isEmpty) return _emptyState(isReceived, theme);
        return _gridView ? _grid(cards, isReceived, theme) : _timeline(cards, isReceived, theme);
      },
    );
  }

  Widget _emptyState(bool isReceived, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🥝', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('Pas encore de souvenirs', style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            isReceived ? 'Les cartes reçues apparaîtront ici' : 'Envoie ta première carte 🥝',
            style: KiwiTextStyles.bodySmall.copyWith(color: KiwiColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _grid(List<CardModel> cards, bool isReceived, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) {
        final c = cards[i];
        return GestureDetector(
          onTap: () => _openCard(c, isReceived, theme),
          onLongPress: () => _confirmDelete(c),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: c.customImageUrl != null && c.customImageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: c.customImageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          placeholder: (context, url) => Container(color: theme.dividerColor),
                          errorWidget: (_, __, ___) => _fallback(theme),
                        )
                      : _fallback(theme),
                ),
              ),
              if (isReceived && !c.isRead)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: KiwiColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
              if (c.videoUrl != null && c.videoUrl!.isNotEmpty)
                const Positioned(
                  bottom: 6, right: 6,
                  child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 22),
                ),
              if (c.audioUrl != null && c.audioUrl!.isNotEmpty)
                const Positioned(
                  bottom: 6, left: 6,
                  child: Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 200.ms);
      },
    );
  }

  Widget _timeline(List<CardModel> cards, bool isReceived, ThemeData theme) {
    final Map<String, List<CardModel>> groups = {};
    for (final c in cards) {
      final key = DateFormat('MMMM yyyy', 'fr_FR').format(c.createdAt);
      groups.putIfAbsent(key, () => []).add(c);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: groups.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(entry.key, style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
              ],
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 2, margin: const EdgeInsets.only(left: 4), color: theme.dividerColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: entry.value.map((c) => _timelineTile(c, isReceived, theme)).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _timelineTile(CardModel c, bool isReceived, ThemeData theme) {
    final otherId = isReceived ? c.senderId : c.receiverId;
    if (_userCache.containsKey(otherId)) {
      return _buildTileWidget(c, isReceived, _userCache[otherId], theme);
    }
    return FutureBuilder<UserModel?>(
      future: FirebaseService().getUserProfile(otherId),
      builder: (context, snap) {
        if (snap.hasData && snap.data != null) _userCache[otherId] = snap.data!;
        return _buildTileWidget(c, isReceived, snap.data, theme);
      },
    );
  }

  Widget _buildTileWidget(CardModel c, bool isReceived, UserModel? u, ThemeData theme) {
    return GestureDetector(
      onTap: () => _openCard(c, isReceived, theme),
      onLongPress: () => _confirmDelete(c),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56, height: 72,
                child: c.customImageUrl != null && c.customImageUrl!.isNotEmpty
                    ? CachedNetworkImage(imageUrl: c.customImageUrl!, fit: BoxFit.cover, memCacheWidth: 200, placeholder: (context, url) => Container(color: theme.dividerColor))
                    : _fallback(theme),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReceived ? 'De ${u?.displayName ?? "..."}' : 'À ${u?.displayName ?? "..."}',
                    style: KiwiTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(c.message.isEmpty ? '(sans message)' : c.message, style: KiwiTextStyles.bodySmall.copyWith(color: KiwiColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(DateFormat('d MMM', 'fr_FR').format(c.createdAt), style: KiwiTextStyles.caption.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(ThemeData theme) => Container(
        color: theme.colorScheme.primary.withOpacity(0.15),
        child: const Center(child: Text('📬', style: TextStyle(fontSize: 24))),
      );

  Widget _shimmerGrid(ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
      itemCount: 9,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: theme.dividerColor, highlightColor: theme.colorScheme.surface,
        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Future<void> _confirmDelete(CardModel card) async {
    final theme = Theme.of(context);
    final delete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('Supprimer la carte ?', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text('Cette action supprimera la carte définitivement de tes souvenirs.', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: KiwiColors.error))),
        ],
      ),
    );
    if (delete == true) {
      await FirebaseService().deleteCard(card.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carte supprimée 🗑️')));
    }
  }

  void _openCard(CardModel card, bool isReceived, ThemeData theme) {
    if (isReceived && !card.isRead) {
      FirebaseService().markCardAsRead(card.id);
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _CardDetailScreen(card: card, isReceived: isReceived),
      ),
    );
  }
}

class _CardDetailScreen extends StatefulWidget {
  final CardModel card;
  final bool isReceived;
  const _CardDetailScreen({required this.card, required this.isReceived});
  @override
  State<_CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<_CardDetailScreen> {
  VideoPlayerController? _videoCtrl;
  VideoPlayerController? _audioCtrl;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    if (widget.card.videoUrl != null && widget.card.videoUrl!.isNotEmpty) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.card.videoUrl!))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoCtrl?.play();
          _videoCtrl?.setLooping(true);
        });
    }
    if (widget.card.audioUrl != null && widget.card.audioUrl!.isNotEmpty) {
      _audioCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.card.audioUrl!))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    _audioCtrl?.dispose();
    super.dispose();
  }

  void _toggleAudio() {
    if (_audioCtrl == null || !_audioCtrl!.value.isInitialized) return;
    if (_audioCtrl!.value.isPlaying) {
      _audioCtrl!.pause();
      setState(() => _isPlayingAudio = false);
    } else {
      _audioCtrl!.play();
      setState(() => _isPlayingAudio = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherId = widget.isReceived ? widget.card.senderId : widget.card.receiverId;
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white), onPressed: () => Share.share('Regarde cette carte Kiwi 🥝 : ${widget.card.message}')),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_videoCtrl != null && _videoCtrl!.value.isInitialized)
                                FittedBox(fit: BoxFit.cover, child: SizedBox(width: _videoCtrl!.value.size.width, height: _videoCtrl!.value.size.height, child: VideoPlayer(_videoCtrl!)))
                              else if (widget.card.customImageUrl != null && widget.card.customImageUrl!.isNotEmpty)
                                CachedNetworkImage(imageUrl: widget.card.customImageUrl!, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey[900]))
                              else
                                Container(color: KiwiColors.primary.withOpacity(0.4)),
                              Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.5)]))),
                              if (widget.card.message.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(widget.card.message, style: KiwiTextStyles.titleLarge.copyWith(color: Colors.white), textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_audioCtrl != null) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: KiwiColors.primary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                          onPressed: _toggleAudio,
                          icon: Icon(_isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                          label: Text(_isPlayingAudio ? 'Mettre en pause' : 'Écouter le message vocal 🎙️'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FutureBuilder<UserModel?>(
                        future: FirebaseService().getUserProfile(otherId),
                        builder: (context, snap) {
                          final u = snap.data;
                          return Text('${widget.isReceived ? "De" : "À"} ${u?.displayName ?? "..."} • ${DateFormat('d MMM yyyy', 'fr_FR').format(widget.card.createdAt)}', style: KiwiTextStyles.bodyMedium.copyWith(color: Colors.white70), textAlign: TextAlign.center);
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}