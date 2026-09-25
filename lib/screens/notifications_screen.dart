import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.new_follower:
      case NotificationType.friend_suggestion:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.card_received:
        return Icons.mail_rounded;
      case NotificationType.new_post:
        return Icons.photo_library_rounded;
      case NotificationType.new_story:
        return Icons.history_toggle_off_rounded;
      case NotificationType.post_liked:
        return Icons.favorite_rounded;
      case NotificationType.event_reminder:
      case NotificationType.event_update:
        return Icons.event_rounded;
    }
  }

  Color _colorForType(NotificationType type, ThemeData theme) {
    switch (type) {
      case NotificationType.new_follower:
      case NotificationType.friend_suggestion:
        return theme.colorScheme.primary;
      case NotificationType.card_received:
        return const Color(0xFF8B5CF6);
      case NotificationType.new_post:
        return const Color(0xFF22C55E);
      case NotificationType.new_story:
        return const Color(0xFFF59E0B);
      case NotificationType.post_liked:
        return const Color(0xFFEF4444);
      case NotificationType.event_reminder:
      case NotificationType.event_update:
        return const Color(0xFF3B82F6);
    }
  }

  void _onTap(BuildContext context, NotificationModel notif) {
    if (!notif.isRead) {
      FirebaseService().markNotificationRead(notif.id);
    }

    switch (notif.type) {
      case NotificationType.new_follower:
      case NotificationType.friend_suggestion:
      case NotificationType.post_liked:
      case NotificationType.new_post:
      case NotificationType.new_story:
        if (notif.fromUserId.isNotEmpty) {
          context.push('/profile/${notif.fromUserId}');
        }
        break;
      case NotificationType.card_received:
        context.push('/card/gallery');
        break;
      case NotificationType.event_reminder:
      case NotificationType.event_update:
        context.go('/home');
        break;
    }
  }

  String _timeLabel(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return DateFormat('d MMM', 'fr_FR').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseService().getCurrentUserId();

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Connecte-toi pour voir tes notifications')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Notifications',
          style: KiwiTextStyles.titleLarge.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: FirebaseService().getNotifications(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            );
          }

          final list = snap.data ?? [];
          if (list.isEmpty) return _empty(theme);

          final now = DateTime.now();
          final today = <NotificationModel>[];
          final yesterday = <NotificationModel>[];
          final earlier = <NotificationModel>[];

          for (final n in list) {
            final dayDiff = DateTime(now.year, now.month, now.day)
                .difference(DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day))
                .inDays;
            if (dayDiff == 0) {
              today.add(n);
            } else if (dayDiff == 1) {
              yesterday.add(n);
            } else {
              earlier.add(n);
            }
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (today.isNotEmpty) ...[
                _header('Aujourd\'hui', theme),
                ...today.map((n) => _tile(context, n, theme)),
              ],
              if (yesterday.isNotEmpty) ...[
                _header('Hier', theme),
                ...yesterday.map((n) => _tile(context, n, theme)),
              ],
              if (earlier.isNotEmpty) ...[
                _header('Plus tôt', theme),
                ...earlier.map((n) => _tile(context, n, theme)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune notification',
              style: KiwiTextStyles.titleMedium.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follows, cartes, moments et statuts\nde tes amis apparaîtront ici 🥝',
              textAlign: TextAlign.center,
              style: KiwiTextStyles.bodyMedium.copyWith(
                color: KiwiColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: KiwiColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, NotificationModel notif, ThemeData theme) {
    final color = _colorForType(notif.type, theme);
    final unread = !notif.isRead;
    final hasAvatar = notif.fromAvatarUrl.isNotEmpty;

    return InkWell(
      onTap: () => _onTap(context, notif),
      child: Container(
        color: unread
            ? theme.colorScheme.primary.withOpacity(0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withOpacity(0.15),
                  backgroundImage:
                      hasAvatar ? CachedNetworkImageProvider(notif.fromAvatarUrl) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          notif.fromFruitEmoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(_iconForType(notif.type), size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: KiwiTextStyles.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.35,
                      ),
                      children: [
                        if (notif.fromDisplayName.isNotEmpty)
                          TextSpan(
                            text: '${notif.fromDisplayName} ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        TextSpan(text: notif.body.isNotEmpty ? notif.body : notif.title),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeLabel(notif.createdAt),
                    style: KiwiTextStyles.caption.copyWith(
                      color: unread
                          ? theme.colorScheme.primary
                          : KiwiColors.textSecondary,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 8, top: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}