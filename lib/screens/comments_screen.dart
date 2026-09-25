import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  const CommentsScreen({super.key, required this.postId});
  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _ctrl = TextEditingController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  String? _replyToCommentId;
  String? _replyToName;
  bool _isRecording = false;
  String? _recordPath;

  @override
  void dispose() {
    _ctrl.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission micro requise')));
      return;
    }
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      _recordPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: _recordPath!);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopAndSendAudio() async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Envoi de l\'audio...')));
    try {
      final url = await FirebaseService().uploadCardMedia('audio', File(path), 'audio');
      await _sendComment(audioUrl: url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur envoi audio')));
    }
  }

  Future<void> _sendComment({String? audioUrl}) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && audioUrl == null) return;
    final uid = FirebaseService().getCurrentUserId()!;
    final user = await FirebaseService().getUserProfile(uid);
    if (user == null) return;

    final c = CommentModel(
      id: FirebaseService().generateId(),
      postId: widget.postId,
      userId: uid,
      userDisplayName: user.displayName,
      userAvatarUrl: user.avatarUrl,
      userFruitEmoji: user.fruitEmoji,
      text: _replyToName != null && text.isNotEmpty ? '@$_replyToName $text' : text,
      audioUrl: audioUrl,
      parentCommentId: _replyToCommentId,
      likedBy: const [],
      createdAt: DateTime.now(),
    );
    await FirebaseService().addComment(c);
    _ctrl.clear();
    setState(() { _replyToCommentId = null; _replyToName = null; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commentaires'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: FirebaseService().getPostComments(widget.postId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final all = snap.data ?? [];
                if (all.isEmpty) return Center(child: Text('Sois le premier à commenter !', style: KiwiTextStyles.bodyMedium));
                
                final parents = all.where((c) => c.parentCommentId == null).toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: parents.length,
                  itemBuilder: (context, i) {
                    final c = parents[i];
                    final replies = all.where((r) => r.parentCommentId == c.id).toList();
                    return _buildComment(c, replies, theme);
                  },
                );
              },
            ),
          ),
          if (_replyToName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Text('Réponse à @$_replyToName', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() { _replyToCommentId = null; _replyToName = null; })),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border(top: BorderSide(color: theme.dividerColor))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: _isRecording ? '🎙 Enregistrement...' : 'Écris un commentaire...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onLongPress: _startRecording,
                    onLongPressUp: _stopAndSendAudio,
                    child: CircleAvatar(
                      backgroundColor: _isRecording ? Colors.red : theme.colorScheme.primary,
                      child: Icon(_isRecording ? Icons.mic : Icons.mic_none, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: theme.colorScheme.primary),
                    onPressed: () => _sendComment(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(CommentModel c, List<CommentModel> replies, ThemeData theme, {bool isReply = false}) {
    final me = FirebaseService().getCurrentUserId();
    final isLiked = c.isLikedBy(me ?? '');
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 40 : 0, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundImage: c.userAvatarUrl.isNotEmpty ? CachedNetworkImageProvider(c.userAvatarUrl) : null,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                child: c.userAvatarUrl.isEmpty ? Text(c.userFruitEmoji, style: const TextStyle(fontSize: 14)) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.userDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    if (c.text.isNotEmpty) Text(c.text, style: KiwiTextStyles.bodyMedium),
                    if (c.audioUrl != null)
                      GestureDetector(
                        onTap: () => _player.play(UrlSource(c.audioUrl!)),
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.play_arrow, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 4),
                            Text('Note vocale', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('il y a ${_time(c.createdAt)}', style: KiwiTextStyles.caption),
                        const SizedBox(width: 12),
                        if (c.likesCount > 0) Text('${c.likesCount} kiwi${c.likesCount > 1 ? 's' : ''}', style: KiwiTextStyles.caption),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(() { _replyToCommentId = c.parentCommentId ?? c.id; _replyToName = c.userDisplayName; }),
                          child: Text('Répondre', style: KiwiTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Text(isLiked ? '🥝' : '🤍', style: TextStyle(fontSize: isLiked ? 20 : 16)),
                onPressed: () => FirebaseService().toggleLikeComment(c.id, me ?? ''),
              ),
            ],
          ),
          ...replies.map((r) => _buildComment(r, const [], theme, isReply: true)),
        ],
      ),
    );
  }

  String _time(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "1m";
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }
}