import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../config/app_theme.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

class CardCreatorScreen extends StatefulWidget {
  final String? preselectedReceiverId;
  final String? preselectedEventId;
  const CardCreatorScreen({super.key, this.preselectedReceiverId, this.preselectedEventId});
  @override
  State<CardCreatorScreen> createState() => _CardCreatorScreenState();
}

class _CardCreatorScreenState extends State<CardCreatorScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  UserModel? _receiver;
  bool _useTemplate = true;
  CardTemplateModel? _template;
  File? _customImage;
  File? _videoFile;
  File? _audioFile;
  final _messageCtrl = TextEditingController();
  Color _textColor = Colors.white;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedReceiverId != null) {
      _loadReceiver(widget.preselectedReceiverId!);
    }
  }

  Future<void> _loadReceiver(String id) async {
    final u = await FirebaseService().getUserProfile(id);
    if (!mounted || u == null) return;
    setState(() {
      _receiver = u;
      _step = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(1);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Text(
          _step == 0 ? 'Destinataire' : _step == 1 ? 'Style' : 'Personnaliser',
          style: KiwiTextStyles.titleLarge,
        ),
      ),
      body: Column(
        children: [
          _stepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _step1Receiver(),
                _step2Style(),
                _step3Personalize(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          final active = i <= _step;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active ? KiwiColors.primary : KiwiColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _step1Receiver() {
    final me = FirebaseService().getCurrentUserId();
    if (me == null) return const SizedBox.shrink();
    return StreamBuilder<List<UserModel>>(
      stream: FirebaseService().getFollowing(me),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: KiwiColors.primary));
        }
        final users = snap.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🥝', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('Aucun kiwi', style: KiwiTextStyles.titleMedium),
                const SizedBox(height: 8),
                Text('Kiwi tes amis d\'abord', style: KiwiTextStyles.bodySmall),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            final selected = _receiver?.id == u.id;
            return InkWell(
              onTap: () {
                setState(() => _receiver = u);
                _next();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? KiwiColors.primary.withOpacity(0.1) : KiwiColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? KiwiColors.primary : Colors.transparent, width: 2),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: KiwiColors.primary.withOpacity(0.15),
                      backgroundImage: u.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(u.avatarUrl) : null,
                      child: u.avatarUrl.isEmpty
                          ? Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                              style: KiwiTextStyles.titleMedium.copyWith(color: KiwiColors.primary))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.displayName, style: KiwiTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                          Text('@${u.username}', style: KiwiTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    if (selected) const Icon(Icons.check_circle_rounded, color: KiwiColors.primary),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _step2Style() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_receiver != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: KiwiColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Text('👉', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('Pour ${_receiver!.displayName}', style: KiwiTextStyles.bodyMedium),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _styleCard(
                  emoji: '🎨',
                  title: 'Template',
                  subtitle: 'Choisir un thème',
                  selected: _useTemplate,
                  onTap: () {
                    setState(() => _useTemplate = true);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _styleCard(
                  emoji: '📷',
                  title: 'Custom',
                  subtitle: 'Importer ta carte',
                  selected: !_useTemplate,
                  onTap: () async {
                    setState(() => _useTemplate = false);
                    await _pickCustomImage();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_useTemplate) Expanded(child: _templatesGrid()),
          if (!_useTemplate && _customImage != null)
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_customImage!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _next, child: const Text('Continuer →')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _styleCard({required String emoji, required String title, required String subtitle, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? KiwiColors.primary.withOpacity(0.1) : KiwiColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? KiwiColors.primary : KiwiColors.divider, width: 2),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(title, style: KiwiTextStyles.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: KiwiTextStyles.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  List<CardTemplateModel> _generateDefaultTemplates() {
    final Map<String, List<String>> categoryImageIds = {
      'anniversaire': [
        '1530108101700-1c3202720d35', '1513151233558-d860c5398176', '1464349153735-7db50ed83c84', '1527529482837-4698179dc6ce',
        '1530107973760-4b2160914092', '1558636508-e0db3814bd1d', '1513201099705-a9746e1e201f', '1512909006721-3d6018887383',
        '1508219803418-5f1f89469b50', '1512917774080-9991f1c4c750', '1566737236500-c8ac43014a67', '1514525253161-7a46d19cd819',
        '1492684223066-81342ee5ff30', '1504196606672-aef5c9cefc92', '1528495612343-9ca9f4a4de28', '1513151233558-d860c5398176',
        '1531058240690-006c446962d8', '1512474932049-78ac69eed080', '1486427944299-d1955d23e34d', '1530107973760-4b2160914092'
      ],
      'examen': [
        '1434030216411-0b793f4b4173', '1456513080510-7bf3a84b82f8', '1523240795612-9a054b0db644', '1501504905252-473c47e087f8',
        '1497633762265-9d179a990aa6', '1513258496099-48168024aec0', '1532012197267-da84d127e765', '1488190211105-8b0e65b80b4e',
        '1503676260728-1c00da094a0b', '1457369804613-52c61a468e7d', '1516321318423-f06f85e504b3', '1522202176988-66273c2fd55f',
        '1524995997946-a1c2e315a42f', '1517842645767-c639042777db', '1498243691581-b145c3f54a5a', '1434030216411-0b793f4b4173',
        '1509062522246-3755977927d7', '1456513080510-7bf3a84b82f8', '1523240795612-9a054b0db644', '1501504905252-473c47e087f8'
      ],
      'voyage': [
        '1488646953014-85cb44e25828', '1503220317375-aaad61436b1b', '1500835556837-99ac94a94552', '1469854523086-cc02fe5d8800',
        '1476514525535-ce74f4526f61', '1507525428034-b723cf961d3e', '1470071459604-3b5ec3a7fe05', '1465778893808-9b3d1b4477e1',
        '1502784444187-359ac186c5bb', '1499856871958-5b9627545d1a', '1506012787146-f92b2d7d7d96', '1433838552652-f9a46c332c40',
        '1519046904884-53103b34b206', '1530789253388-582c481c54b0', '1504150558220-074573a11005', '1488646953014-85cb44e25828',
        '1503220317375-aaad61436b1b', '1500835556837-99ac94a94552', '1469854523086-cc02fe5d8800', '1476514525535-ce74f4526f61'
      ],
      'diplôme': [
        '1523050854058-8df90110c9f1', '1523240795612-9a054b0db644', '1541339907198-e08756dedf3f', '1562774053-701939374585',
        '1509062522246-3755977927d7', '1535982330050-f1c2fb79ff78', '1522071820081-009f0129c71c', '1517245386807-bb43f82c33c4',
        '1523050854058-8df90110c9f1', '1523240795612-9a054b0db644', '1541339907198-e08756dedf3f', '1562774053-701939374585',
        '1509062522246-3755977927d7', '1535982330050-f1c2fb79ff78', '1522071820081-009f0129c71c', '1517245386807-bb43f82c33c4',
        '1523050854058-8df90110c9f1', '1523240795612-9a054b0db644', '1541339907198-e08756dedf3f', '1562774053-701939374585'
      ],
    };

    final List<CardTemplateModel> list = [];
    int order = 1;

    categoryImageIds.forEach((cat, ids) {
      for (int i = 0; i < ids.length; i++) {
        final imgId = ids[i];
        list.add(
          CardTemplateModel(
            id: 'def_${cat}_$i',
            name: '$cat ${i + 1}',
            category: cat,
            previewUrl: 'https://images.unsplash.com/photo-$imgId?auto=format&fit=crop&w=600&q=80',
            layersData: {},
            isPremium: false,
            sortOrder: order++,
          ),
        );
      }
    });

    return list;
  }

  Widget _templatesGrid() {
    return FutureBuilder<List<CardTemplateModel>>(
      future: FirebaseService().getCardTemplates(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: KiwiColors.primary));
        }
        var templates = snap.data ?? [];
        if (templates.isEmpty) {
          templates = _generateDefaultTemplates();
        }
        final Map<String, List<CardTemplateModel>> grouped = {};
        for (final t in templates) {
          grouped.putIfAbsent(t.category, () => []).add(t);
        }
        return ListView(
          children: grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: KiwiTextStyles.caption.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700),
                  ),
                ),
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: entry.value.length,
                  itemBuilder: (_, i) {
                    final t = entry.value[i];
                    final selected = _template?.id == t.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _template = t);
                        _next();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? KiwiColors.primary : Colors.transparent, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: t.previewUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: KiwiColors.divider),
                            errorWidget: (_, __, ___) => Container(color: KiwiColors.divider, child: const Icon(Icons.image_not_supported)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _step3Personalize() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: KiwiColors.primary.withOpacity(0.1),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_customImage != null)
                      Image.file(_customImage!, fit: BoxFit.cover)
                    else if (_template != null)
                      CachedNetworkImage(imageUrl: _template!.previewUrl, fit: BoxFit.cover)
                    else
                      Container(color: KiwiColors.primary.withOpacity(0.2)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _messageCtrl.text.isEmpty ? 'Ton message ici...' : _messageCtrl.text,
                            style: KiwiTextStyles.titleLarge.copyWith(color: _textColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageCtrl,
            maxLength: 200,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Écris ton message...'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _toolButton(Icons.photo_camera_rounded, 'Photo', _pickCustomImage),
              _toolButton(Icons.videocam_rounded, 'Vidéo', _pickVideo),
              _toolButton(Icons.mic_rounded, 'Audio', _pickAudio),
              _toolButton(Icons.palette_rounded, 'Couleur', _changeTextColor),
            ],
          ),
          if (_videoFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: KiwiColors.success, size: 18),
                  const SizedBox(width: 6),
                  Text('Vidéo ajoutée', style: KiwiTextStyles.bodySmall),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _videoFile = null), child: const Text('Retirer')),
                ],
              ),
            ),
          if (_audioFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.audiotrack_rounded, color: KiwiColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('Message vocal ajouté 🎙️', style: KiwiTextStyles.bodySmall),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _audioFile = null), child: const Text('Retirer')),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _confirmSend,
              child: _sending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('🥝  ENVOYER LA CARTE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: KiwiColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: KiwiColors.primary),
          ),
          const SizedBox(height: 6),
          Text(label, style: KiwiTextStyles.bodySmall),
        ],
      ),
    );
  }

  Future<void> _pickCustomImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
    if (file == null) return;
    setState(() {
      _customImage = File(file.path);
      _useTemplate = false;
    });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (file == null) return;
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      final durationSec = controller.value.duration.inSeconds;
      if (durationSec > 60) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vidéo trop longue (max 60s)')));
        }
        await controller.dispose();
        return;
      }
      await controller.dispose();
      setState(() => _videoFile = File(file.path));
    } catch (_) {
      await controller.dispose();
    }
  }

  Future<void> _pickAudio() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 120));
    if (file == null) return;
    setState(() => _audioFile = File(file.path));
  }

  void _changeTextColor() {
    final colors = [Colors.white, Colors.black, KiwiColors.primary, KiwiColors.accent, Colors.red, Colors.blueAccent];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: KiwiColors.surfaceLight, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 16, runSpacing: 16,
          children: colors.map((c) {
            return GestureDetector(
              onTap: () {
                setState(() => _textColor = c);
                Navigator.pop(context);
              },
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: KiwiColors.divider, width: 2),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmSend() async {
    if (_receiver == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis un destinataire')));
      return;
    }
    if (_customImage == null && _template == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisis un style de carte')));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Envoyer la carte ?'),
        content: Text('À ${_receiver!.displayName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
        ],
      ),
    );
    if (confirm != true) return;
    await _sendCard();
  }

  Future<void> _sendCard() async {
    setState(() => _sending = true);
    try {
      final me = FirebaseService().getCurrentUserId();
      if (me == null) throw Exception('Non connecté');
      final cardId = const Uuid().v4();
      String? imgUrl;
      String? videoUrl;
      String? audioUrl;

      if (!_useTemplate && _customImage != null) {
        imgUrl = await FirebaseService().uploadCardMedia(cardId, _customImage!, 'image');
      } else if (_useTemplate && _template != null) {
        imgUrl = _template!.previewUrl;
      }

      if (_videoFile != null) {
        videoUrl = await FirebaseService().uploadCardMedia(cardId, _videoFile!, 'video');
      }

      if (_audioFile != null) {
        audioUrl = await FirebaseService().uploadCardMedia(cardId, _audioFile!, 'audio');
      }

      final card = CardModel(
        id: cardId,
        senderId: me,
        receiverId: _receiver!.id,
        templateId: _template?.id,
        customImageUrl: imgUrl,
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        message: _messageCtrl.text.trim(),
        eventReference: widget.preselectedEventId,
        style: CardStyle(),
        isRead: false,
        isArchived: false,
        createdAt: DateTime.now(),
      );

      await FirebaseService().sendCard(card);
      if (!mounted) return;
      await _showSuccessAnimation();
      if (!mounted) return;
      context.go('/home');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carte envoyée 🥝')));
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _showSuccessAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🥝', style: TextStyle(fontSize: 90))
                .animate()
                .scale(duration: 400.ms, curve: Curves.easeOutBack)
                .then()
                .slideY(begin: 0, end: -3, duration: 800.ms, curve: Curves.easeIn)
                .fadeOut(delay: 500.ms),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}