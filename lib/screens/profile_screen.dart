import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../config/theme_provider.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late String _viewedUserId;
  late bool _isOwnProfile;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    final me = FirebaseService().getCurrentUserId() ?? '';
    _viewedUserId = widget.userId ?? me;
    _isOwnProfile = _viewedUserId == me;
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: StreamBuilder<UserModel?>(
        stream: FirebaseService().getUserProfileStream(_viewedUserId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
          }
          final user = snap.data;
          if (user == null) return const Center(child: Text('Profil introuvable'));
          
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  title: Text(user.username, style: KiwiTextStyles.titleLarge.copyWith(color: theme.colorScheme.onSurface)),
                  leading: widget.userId != null
                      ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())
                      : const SizedBox.shrink(),
                  actions: [
                    if (_isOwnProfile) ...[
                      // BOUTON DE NOTIFICATIONS
                      StreamBuilder<int>(
                        stream: FirebaseService().getUnreadNotifCount(_viewedUserId),
                        builder: (context, notifSnap) {
                          final unreadCount = notifSnap.data ?? 0;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_none_rounded, size: 28),
                                onPressed: () {
                                  // Navigue vers l'écran des notifications (à créer)
                                  context.push('/notifications');
                                },
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 8,
                                  top: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      // BOUTON PARAMÈTRES
                      IconButton(
                        icon: const Icon(Icons.menu_rounded, size: 28), // Icône menu burger style Instagram
                        onPressed: _showSettings,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
                SliverToBoxAdapter(child: _buildHeader(user, theme)),
                SliverToBoxAdapter(child: _buildActionButtons(user, theme)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabCtrl,
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: KiwiColors.textSecondary,
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on_rounded)),
                        Tab(icon: Icon(Icons.event_note_rounded)),
                      ],
                    ),
                    theme.scaffoldBackgroundColor,
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildPostsGrid(theme),
                _buildEventsList(theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserModel user, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                    backgroundImage: user.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(user.avatarUrl) : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                            style: KiwiTextStyles.displayLarge.copyWith(color: theme.colorScheme.primary))
                        : null,
                  ),
                  Positioned(
                    bottom: -4, left: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                      child: Text(user.fruitEmoji, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  if (_isOwnProfile)
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: _changeAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.surface, width: 2)),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                ],
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              _statBox('Moments', user.followersCount + user.followingCount, theme, () {}),
              _statBox('Kiwis', user.followersCount, theme, () => _showFollowList('Abonnés')),
              _statBox('Kiwied', user.followingCount, theme, () => _showFollowList('Abonnements')),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(user.fruitPersonality, style: KiwiTextStyles.caption.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                ),
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(user.bio, style: KiwiTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurface)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, int count, ThemeData theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text('$count', style: KiwiTextStyles.titleLarge.copyWith(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: KiwiTextStyles.bodySmall.copyWith(color: KiwiColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(UserModel user, ThemeData theme) {
    if (_isOwnProfile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _editProfile(user, theme),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Modifier le profil', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Partager le profil', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }
    
    final me = FirebaseService().getCurrentUserId();
    if (me == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<bool>(
              stream: FirebaseService().isFollowingStream(me, _viewedUserId),
              builder: (context, snap) {
                final isFollowing = snap.data ?? false;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? theme.dividerColor : theme.colorScheme.primary,
                    foregroundColor: isFollowing ? theme.colorScheme.onSurface : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (isFollowing) {
                      await FirebaseService().unfollowUser(me, _viewedUserId);
                    } else {
                      await FirebaseService().followUser(me, _viewedUserId);
                    }
                  },
                  child: Text(isFollowing ? '✅  Kiwied' : '🥝  Suivre', style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.push('/card/create', extra: {'receiverId': _viewedUserId}),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Message', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid(ThemeData theme) {
    return StreamBuilder<List<PostModel>>(
      stream: FirebaseService().getUserPosts(_viewedUserId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📷', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text('Aucun moment partagé', style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final p = posts[i];
            return Container(
              decoration: BoxDecoration(color: Color(int.parse(p.backgroundColor.replaceFirst('#', '0xFF')))),
              child: p.imageUrl != null
                  ? CachedNetworkImage(imageUrl: p.imageUrl!, fit: BoxFit.cover)
                  : Center(child: Text(p.category.emoji, style: const TextStyle(fontSize: 32))),
            );
          },
        );
      },
    );
  }

  Widget _buildEventsList(ThemeData theme) {
    return StreamBuilder<List<EventModel>>(
      stream: FirebaseService().getUserEvents(_viewedUserId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
        var events = snap.data ?? [];
        if (!_isOwnProfile) events = events.where((e) => e.isPublic).toList();
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📅', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text('Aucun événement', style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: events.length,
          itemBuilder: (context, i) {
            final e = events[i];
            return ListTile(
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(e.category.emoji, style: const TextStyle(fontSize: 24))),
              ),
              title: Text(e.title, style: KiwiTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
              subtitle: Text(DateFormat('d MMMM yyyy', 'fr_FR').format(e.date), style: KiwiTextStyles.caption.copyWith(color: KiwiColors.textSecondary)),
              trailing: _isOwnProfile
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: KiwiColors.error),
                      onPressed: () => FirebaseService().deleteEvent(_viewedUserId, e.id),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (file == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mise à jour de la photo...')));
    try {
      await FirebaseService().uploadAvatar(_viewedUserId, File(file.path));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo mise à jour ✅')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: KiwiColors.error));
    }
  }

  void _editProfile(UserModel user, ThemeData theme) {
    final nameCtrl = TextEditingController(text: user.displayName);
    final bioCtrl = TextEditingController(text: user.bio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Modifier le profil', style: KiwiTextStyles.titleLarge.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(height: 20),
              TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nom complet')),
              const SizedBox(height: 12),
              TextField(controller: bioCtrl, maxLines: 3, maxLength: 150, decoration: const InputDecoration(hintText: 'Bio')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseService().updateUserProfile(_viewedUserId, {
                    'displayName': nameCtrl.text.trim(),
                    'displayNameLower': nameCtrl.text.trim().toLowerCase(),
                    'bio': bioCtrl.text.trim(),
                  });
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFollowList(String title) {
    final theme = Theme.of(context);
    final stream = title == 'Abonnés' 
        ? FirebaseService().getFollowers(_viewedUserId) 
        : FirebaseService().getFollowing(_viewedUserId);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.7,
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(title, style: KiwiTextStyles.titleLarge.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: stream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
                  final users = snap.data ?? [];
                  if (users.isEmpty) return Center(child: Text('Aucun $title', style: KiwiTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurface)));
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, i) {
                      final u = users[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: u.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(u.avatarUrl) : null,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                          child: u.avatarUrl.isEmpty ? Text(u.fruitEmoji) : null,
                        ),
                        title: Text(u.displayName, style: KiwiTextStyles.bodyMedium.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
                        subtitle: Text('@${u.username}', style: KiwiTextStyles.caption.copyWith(color: KiwiColors.textSecondary)),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.push('/profile/${u.id}');
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // NOUVEAU MENU DES PARAMÈTRES (STYLE INSTAGRAM)
  // ==========================================
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final themeState = ref.watch(themeProvider);
            final theme = Theme.of(context);
            
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
                title: Text('Paramètres et activité', style: KiwiTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              ),
              body: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  // SECTION: VOTRE COMPTE
                  _buildSectionTitle('Votre compte', theme),
                  _buildSettingsTile(
                    theme: theme,
                    icon: Icons.account_circle_outlined,
                    title: 'Espace Comptes',
                    subtitle: 'Mot de passe, sécurité, informations personnelles',
                    onTap: () {},
                  ),
                  
                  Divider(color: theme.dividerColor, thickness: 8),

                  // SECTION: UTILISATION & APPARENCE (Thème intégré ici)
                  _buildSectionTitle('Affichage et interface', theme),
                  _buildSettingsTile(
                    theme: theme,
                    icon: themeState.mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                    title: 'Mode sombre',
                    trailing: CupertinoSwitch(
                      value: themeState.mode == ThemeMode.dark,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) => ref.read(themeProvider.notifier).toggleMode(val),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Couleur du thème', style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: KiwiColors.themeOptions.map((c) {
                            final isSelected = themeState.primaryColor.value == c.value;
                            return GestureDetector(
                              onTap: () => ref.read(themeProvider.notifier).setPrimaryColor(c),
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: c, 
                                  shape: BoxShape.circle, 
                                  border: isSelected ? Border.all(color: theme.colorScheme.onSurface, width: 3) : null
                                ),
                                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  Divider(color: theme.dividerColor, thickness: 8),

                  // SECTION: INTERACTION
                  _buildSectionTitle('Interactions', theme),
                  _buildSettingsTile(
                    theme: theme,
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    onTap: () => context.push('/notifications'),
                  ),
                  _buildSettingsTile(
                    theme: theme,
                    icon: Icons.lock_outline_rounded,
                    title: 'Confidentialité du compte',
                    trailing: Text('Public', style: TextStyle(color: KiwiColors.textSecondary, fontSize: 14)),
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    theme: theme,
                    icon: Icons.block_flipped,
                    title: 'Bloqué',
                    onTap: () {},
                  ),

                  Divider(color: theme.dividerColor, thickness: 8),

                  // SECTION: APPLICATION
                  _buildSectionTitle('Votre application', theme),
                  _buildSettingsTile(
                    theme: theme,
                    icon: Icons.language,
                    title: 'Langue et traduction',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    theme: theme,
                    icon: Icons.help_outline_rounded,
                    title: 'Aide',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    theme: theme,
                    icon: Icons.info_outline_rounded,
                    title: 'À propos',
                    onTap: () {},
                  ),

                  Divider(color: theme.dividerColor, thickness: 8),

                  // SECTION: DÉCONNEXION
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Connexion', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () {},
                          child: Text('Ajouter un compte', style: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 24),
                        InkWell(
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await FirebaseService().signOut();
                            if (mounted) context.go('/auth');
                          },
                          child: const Text('Se déconnecter', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // Helper pour les titres de section (style Instagram)
  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: KiwiColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper pour les tuiles de paramètres
  Widget _buildSettingsTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: theme.colorScheme.onSurface, size: 28),
      title: Text(title, style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13, color: KiwiColors.textSecondary)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: KiwiColors.textSecondary),
      onTap: onTap,
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _color;
  _SliverAppBarDelegate(this._tabBar, this._color);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: _color, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}