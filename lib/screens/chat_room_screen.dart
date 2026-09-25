import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final UserModel otherUser;
  const ChatRoomScreen({super.key, required this.roomId, required this.otherUser});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _ctrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _attachmentIcon(Icons.image, Colors.purple, 'Photo', () => _sendMedia(isVideo: false)),
            _attachmentIcon(Icons.videocam, Colors.pink, 'Vidéo', () => _sendMedia(isVideo: true)),
            _attachmentIcon(Icons.camera_alt, Colors.green, 'Caméra', () => _sendMedia(isVideo: false, fromCamera: true)),
          ],
        ),
      ),
    );
  }

  Widget _attachmentIcon(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _sendMedia({required bool isVideo, bool fromCamera = false}) async {
    final picker = ImagePicker();
    final XFile? file = isVideo 
        ? await picker.pickVideo(source: fromCamera ? ImageSource.camera : ImageSource.gallery)
        : await picker.pickImage(source: fromCamera ? ImageSource.camera : ImageSource.gallery, imageQuality: 80);
        
    if (file == null) return;
    
    setState(() => _isSending = true);
    final uid = FirebaseService().getCurrentUserId()!;
    
    try {
      final url = isVideo 
          ? await FirebaseService().uploadCardMedia(FirebaseService().generateId(), File(file.path), 'video')
          : await FirebaseService().uploadImageToCloudinary(File(file.path));
          
      await FirebaseService().sendMessage(widget.roomId, uid, '', type: isVideo ? MessageType.video : MessageType.image, mediaUrl: url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'envoi')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _sendText() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    final uid = FirebaseService().getCurrentUserId()!;
    FirebaseService().sendMessage(widget.roomId, uid, t);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseService().getCurrentUserId();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101010) : const Color(0xFFEFEFEF), // Fond style WhatsApp
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherUser.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(widget.otherUser.avatarUrl) : null,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: widget.otherUser.avatarUrl.isEmpty ? Text(widget.otherUser.fruitEmoji, style: const TextStyle(fontSize: 16)) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.otherUser.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: FirebaseService().getChatMessages(widget.roomId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final msgs = snap.data ?? [];
                
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final isMe = m.senderId == uid;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? theme.colorScheme.primary : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: _buildMessageContent(m, isMe, theme),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isSending)
            const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: theme.scaffoldBackgroundColor,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary, size: 28),
                    onPressed: _showAttachmentMenu,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(MessageModel m, bool isMe, ThemeData theme) {
    if (m.type == MessageType.image || m.type == MessageType.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CachedNetworkImage(
                  imageUrl: m.mediaUrl!,
                  placeholder: (context, url) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                ),
                if (m.type == MessageType.video)
                  const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.play_arrow, color: Colors.white)),
              ],
            ),
          ),
          if (m.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(m.text, style: TextStyle(color: isMe ? Colors.white : theme.colorScheme.onSurface)),
            ),
        ],
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        m.text,
        style: TextStyle(color: isMe ? Colors.white : theme.colorScheme.onSurface, fontSize: 15),
      ),
    );
  }
}