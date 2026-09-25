import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  void _showContactsList(BuildContext context, String currentUserId, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Nouveau message', style: KiwiTextStyles.titleLarge.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                // On affiche les gens que tu suis pour pouvoir leur parler
                stream: FirebaseService().getFollowing(currentUserId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final users = snap.data ?? [];
                  if (users.isEmpty) return const Center(child: Text('Suis des amis pour discuter avec eux !'));
                  
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
                        title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('@${u.username}', style: TextStyle(color: KiwiColors.textSecondary, fontSize: 12)),
                        onTap: () async {
                          Navigator.pop(context); // Ferme la modal
                          // Crée la salle et navigue
                          final roomId = await FirebaseService().createOrGetChatRoom(currentUserId, u.id);
                          if (context.mounted) context.push('/chat/$roomId', extra: u);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseService().getCurrentUserId();
    
    if (uid == null) return const Scaffold(body: Center(child: Text('Erreur')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussions', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<ChatRoomModel>>(
        stream: FirebaseService().getUserChatRooms(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final rooms = snap.data ?? [];
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 60, color: theme.colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Aucun message.', style: KiwiTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text('Appuie sur le bouton en bas pour démarrer.', style: TextStyle(color: KiwiColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final room = rooms[i];
              final otherUserId = room.participants.firstWhere((p) => p != uid, orElse: () => '');
              final unread = room.unreadCounts[uid] ?? 0;

              return FutureBuilder<UserModel?>(
                future: FirebaseService().getUserProfile(otherUserId),
                builder: (context, userSnap) {
                  final user = userSnap.data;
                  if (user == null) return const SizedBox.shrink();
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: user.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(user.avatarUrl) : null,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                      child: user.avatarUrl.isEmpty ? Text(user.fruitEmoji, style: const TextStyle(fontSize: 24)) : null,
                    ),
                    title: Text(user.displayName, style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600, fontSize: 16)),
                    subtitle: Text(
                      room.lastMessage, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis, 
                      style: TextStyle(color: unread > 0 ? theme.colorScheme.onSurface : KiwiColors.textSecondary)
                    ),
                    trailing: unread > 0 
                      ? CircleAvatar(radius: 12, backgroundColor: theme.colorScheme.primary, child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))) 
                      : null,
                    onTap: () {
                      FirebaseService().markMessagesAsRead(room.id, uid);
                      context.push('/chat/${room.id}', extra: user);
                    },
                  );
                },
              );
            },
          );
        },
      ),
      // LE FAMEUX BOUTON WHATSAPP
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.message_rounded, color: Colors.white),
        onPressed: () => _showContactsList(context, uid, theme),
      ),
    );
  }
}