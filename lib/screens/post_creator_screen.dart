import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class PostCreatorScreen extends StatefulWidget {
  const PostCreatorScreen({super.key});
  @override
  State<PostCreatorScreen> createState() => _PostCreatorScreenState();
}

class _PostCreatorScreenState extends State<PostCreatorScreen> {
  PostType _type = PostType.text;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  EventCategory _selectedCategory = EventCategory.custom;
  int _selectedBgIndex = 0;
  File? _mediaFile;
  bool _isVideo = false;
  bool _isPublishing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un moment'),
        actions: [
          TextButton(
            onPressed: _isPublishing ? null : _publish,
            child: Text(
              _isPublishing ? '...' : 'Publier',
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTypeSelector(theme),
          Expanded(
            child: _type == PostType.text ? _buildTextEditor(theme) : _buildMediaEditor(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _typeTab('✨ Texte', PostType.text, theme),
          _typeTab('📷 Média', PostType.media, theme),
        ],
      ),
    );
  }

  Widget _typeTab(String label, PostType type, ThemeData theme) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextEditor(ThemeData theme) {
    final bg = kPostBackgrounds[_selectedBgIndex];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Color(int.parse(bg.bgColor.replaceFirst('#', '0xFF'))),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_selectedCategory.emoji, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 16),
                Text(
                  _titleCtrl.text.isEmpty ? 'Ton titre ici...' : _titleCtrl.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(int.parse(bg.textColor.replaceFirst('#', '0xFF'))),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Choisis ton fond', style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: kPostBackgrounds.length,
            itemBuilder: (context, i) {
              final b = kPostBackgrounds[i];
              final selected = i == _selectedBgIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedBgIndex = i),
                child: Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Color(int.parse(b.bgColor.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: theme.colorScheme.onSurface, width: 3) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(b.emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(hintText: 'Titre du moment'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Légende...'),
        ),
        const SizedBox(height: 16),
        _buildDatePicker(theme),
        const SizedBox(height: 16),
        _buildCategoryPicker(theme),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMediaEditor(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        GestureDetector(
          onTap: _pickMedia,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              color: theme.inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(20),
              image: _mediaFile != null && !_isVideo
                  ? DecorationImage(image: FileImage(_mediaFile!), fit: BoxFit.cover)
                  : null,
            ),
            child: _mediaFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 60, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('Ajouter photo ou vidéo', style: KiwiTextStyles.titleMedium.copyWith(color: theme.colorScheme.onSurface)),
                    ],
                  )
                : _isVideo
                    ? Center(child: Text('🎬 Vidéo sélectionnée', style: KiwiTextStyles.titleMedium.copyWith(color: Colors.white)))
                    : null,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo),
                label: const Text('Photo'),
                onPressed: () => _pickMedia(video: false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.videocam),
                label: const Text('Vidéo'),
                onPressed: () => _pickMedia(video: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Titre du moment')),
        const SizedBox(height: 12),
        TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Légende...')),
        const SizedBox(height: 16),
        _buildDatePicker(theme),
        const SizedBox(height: 16),
        _buildCategoryPicker(theme),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDatePicker(ThemeData theme) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) setState(() => _selectedDate = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 20),
            const SizedBox(width: 12),
            Text('Date : ${DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDate)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPicker(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EventCategory.values.map((c) {
        final sel = c == _selectedCategory;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? theme.colorScheme.primary : theme.inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${c.emoji} ${c.label}',
              style: TextStyle(color: sel ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _pickMedia({bool? video}) async {
    final picker = ImagePicker();
    XFile? file;
    if (video == true) {
      file = await picker.pickVideo(source: ImageSource.gallery);
      if (file != null) setState(() { _mediaFile = File(file!.path); _isVideo = true; });
    } else {
      file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null) setState(() { _mediaFile = File(file!.path); _isVideo = false; });
    }
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoute un titre')));
      return;
    }
    setState(() => _isPublishing = true);
    try {
      final uid = FirebaseService().getCurrentUserId()!;
      String? mediaUrl;
      if (_type == PostType.media && _mediaFile != null) {
        mediaUrl = await FirebaseService().uploadImageToCloudinary(_mediaFile!);
      }
      final bg = kPostBackgrounds[_selectedBgIndex];
      final post = PostModel(
        id: FirebaseService().generateId(),
        userId: uid,
        postType: _type,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _selectedCategory,
        eventDate: _selectedDate,
        backgroundColor: bg.bgColor,
        textColor: bg.textColor,
        imageUrl: _type == PostType.media && !_isVideo ? mediaUrl : null,
        videoUrl: _type == PostType.media && _isVideo ? mediaUrl : null,
        likedBy: const [],
        createdAt: DateTime.now(),
      );
      await FirebaseService().createPost(post);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publié ! 🥝')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }
}