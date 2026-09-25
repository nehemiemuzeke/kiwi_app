import 'package:cloud_firestore/cloud_firestore.dart';

enum EventCategory {
  birthday,
  exam,
  travel,
  wedding,
  graduation,
  concert,
  holiday,
  sport,
  meeting,
  custom,
}

extension EventCategoryX on EventCategory {
  String get emoji {
    switch (this) {
      case EventCategory.birthday:
        return '🎂';
      case EventCategory.exam:
        return '📚';
      case EventCategory.travel:
        return '✈️';
      case EventCategory.wedding:
        return '💍';
      case EventCategory.graduation:
        return '🎓';
      case EventCategory.concert:
        return '🎵';
      case EventCategory.holiday:
        return '🎄';
      case EventCategory.sport:
        return '🏆';
      case EventCategory.meeting:
        return '📋';
      case EventCategory.custom:
        return '⭐';
    }
  }

  String get label {
    switch (this) {
      case EventCategory.birthday:
        return 'Anniversaire';
      case EventCategory.exam:
        return 'Examen';
      case EventCategory.travel:
        return 'Voyage';
      case EventCategory.wedding:
        return 'Mariage';
      case EventCategory.graduation:
        return 'Diplôme';
      case EventCategory.concert:
        return 'Concert';
      case EventCategory.holiday:
        return 'Fêtes';
      case EventCategory.sport:
        return 'Sport';
      case EventCategory.meeting:
        return 'Rendez-vous';
      case EventCategory.custom:
        return 'Autre';
    }
  }

  String get value => name;

  static EventCategory fromString(String? s) {
    return EventCategory.values.firstWhere(
      (e) => e.name == s,
      orElse: () => EventCategory.custom,
    );
  }
}

enum NotificationType {
  new_follower,
  event_reminder,
  card_received,
  event_update,
  post_liked,
  new_post,
  new_story,
  friend_suggestion,
}

extension NotificationTypeX on NotificationType {
  String get value => name;

  static NotificationType fromString(String? s) {
    return NotificationType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => NotificationType.event_update,
    );
  }
}

class FruitAvatar {
  final String emoji;
  final String name;
  final String personality;
  const FruitAvatar({
    required this.emoji,
    required this.name,
    required this.personality,
  });
}

const List<FruitAvatar> kFruitAvatars = [
  FruitAvatar(emoji: '🥝', name: 'Kiwi', personality: 'Original et surprenant'),
  FruitAvatar(emoji: '🍓', name: 'Fraise', personality: 'Doux et attentionné'),
  FruitAvatar(emoji: '🍎', name: 'Pomme', personality: 'Simple et sincère'),
  FruitAvatar(emoji: '🍌', name: 'Banane', personality: 'Optimiste et joyeux'),
  FruitAvatar(emoji: '🍊', name: 'Orange', personality: 'Énergique et créatif'),
  FruitAvatar(emoji: '🍋', name: 'Citron', personality: 'Vif et piquant'),
  FruitAvatar(emoji: '🍇', name: 'Raisin', personality: 'Sociable et festif'),
  FruitAvatar(emoji: '🍉', name: 'Pastèque', personality: 'Rafraîchissant et généreux'),
  FruitAvatar(emoji: '🍑', name: 'Pêche', personality: 'Tendre et romantique'),
  FruitAvatar(emoji: '🍒', name: 'Cerise', personality: 'Passionné et unique'),
  FruitAvatar(emoji: '🍍', name: 'Ananas', personality: 'Exotique et audacieux'),
  FruitAvatar(emoji: '🥭', name: 'Mangue', personality: 'Chaleureux et solaire'),
  FruitAvatar(emoji: '🍏', name: 'Pomme verte', personality: 'Frais et curieux'),
  FruitAvatar(emoji: '🫐', name: 'Myrtille', personality: 'Discret et profond'),
  FruitAvatar(emoji: '🍈', name: 'Melon', personality: 'Doux et paisible'),
];

class UserModel {
  final String id;
  final String displayName;
  final String username;
  final String email;
  final String avatarUrl;
  final String bio;
  final String fruitEmoji;
  final String fruitPersonality;
  final String fcmToken;
  final int followersCount;
  final int followingCount;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.displayName,
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.bio,
    this.fruitEmoji = '🥝',
    this.fruitPersonality = 'Original et surprenant',
    required this.fcmToken,
    required this.followersCount,
    required this.followingCount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(),
        'username': username,
        'email': email,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'fruitEmoji': fruitEmoji,
        'fruitPersonality': fruitPersonality,
        'fcmToken': fcmToken,
        'followersCount': followersCount,
        'followingCount': followingCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      displayName: map['displayName'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      bio: map['bio'] ?? '',
      fruitEmoji: map['fruitEmoji'] ?? '🥝',
      fruitPersonality: map['fruitPersonality'] ?? 'Original et surprenant',
      fcmToken: map['fcmToken'] ?? '',
      followersCount: (map['followersCount'] ?? 0) as int,
      followingCount: (map['followingCount'] ?? 0) as int,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  UserModel copyWith({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    String? fruitEmoji,
    String? fruitPersonality,
    String? fcmToken,
    int? followersCount,
    int? followingCount,
  }) {
    return UserModel(
      id: id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      fruitEmoji: fruitEmoji ?? this.fruitEmoji,
      fruitPersonality: fruitPersonality ?? this.fruitPersonality,
      fcmToken: fcmToken ?? this.fcmToken,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      createdAt: createdAt,
    );
  }
}

class EventModel {
  final String id;
  final String userId;
  final String title;
  final DateTime date;
  final EventCategory category;
  final bool isPublic;
  final bool isRecurringYearly;
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.date,
    required this.category,
    required this.isPublic,
    required this.isRecurringYearly,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'date': Timestamp.fromDate(date),
        'category': category.value,
        'isPublic': isPublic,
        'isRecurringYearly': isRecurringYearly,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory EventModel.fromMap(
      String id, String userId, Map<String, dynamic> map) {
    return EventModel(
      id: id,
      userId: userId,
      title: map['title'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: EventCategoryX.fromString(map['category']),
      isPublic: map['isPublic'] ?? true,
      isRecurringYearly: map['isRecurringYearly'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory EventModel.fromFirestore(DocumentSnapshot doc, String userId) {
    return EventModel.fromMap(
        doc.id, userId, doc.data() as Map<String, dynamic>);
  }

  EventModel copyWith({
    String? title,
    DateTime? date,
    EventCategory? category,
    bool? isPublic,
    bool? isRecurringYearly,
  }) {
    return EventModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      date: date ?? this.date,
      category: category ?? this.category,
      isPublic: isPublic ?? this.isPublic,
      isRecurringYearly: isRecurringYearly ?? this.isRecurringYearly,
      createdAt: createdAt,
    );
  }
}

class CardStyle {
  final String theme;
  final String fontFamily;
  final String colorScheme;
  final String backgroundEffect;
  CardStyle({
    this.theme = 'default',
    this.fontFamily = 'Poppins',
    this.colorScheme = 'green',
    this.backgroundEffect = 'none',
  });
  Map<String, dynamic> toMap() => {
        'theme': theme,
        'fontFamily': fontFamily,
        'colorScheme': colorScheme,
        'backgroundEffect': backgroundEffect
      };
  factory CardStyle.fromMap(Map<String, dynamic>? map) {
    if (map == null) return CardStyle();
    return CardStyle(
      theme: map['theme'] ?? 'default',
      fontFamily: map['fontFamily'] ?? 'Poppins',
      colorScheme: map['colorScheme'] ?? 'green',
      backgroundEffect: map['backgroundEffect'] ?? 'none',
    );
  }
}

class CardModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? templateId;
  final String? customImageUrl;
  final String? videoUrl;
  final String? audioUrl;
  final String message;
  final String? eventReference;
  final CardStyle style;
  final bool isRead;
  final bool isArchived;
  final DateTime createdAt;

  CardModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.templateId,
    this.customImageUrl,
    this.videoUrl,
    this.audioUrl,
    required this.message,
    this.eventReference,
    required this.style,
    required this.isRead,
    required this.isArchived,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'receiverId': receiverId,
        'templateId': templateId,
        'customImageUrl': customImageUrl,
        'videoUrl': videoUrl,
        'audioUrl': audioUrl,
        'message': message,
        'eventReference': eventReference,
        'style': style.toMap(),
        'isRead': isRead,
        'isArchived': isArchived,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory CardModel.fromMap(String id, Map<String, dynamic> map) {
    return CardModel(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      templateId: map['templateId'],
      customImageUrl: map['customImageUrl'],
      videoUrl: map['videoUrl'],
      audioUrl: map['audioUrl'],
      message: map['message'] ?? '',
      eventReference: map['eventReference'],
      style: CardStyle.fromMap(map['style'] as Map<String, dynamic>?),
      isRead: map['isRead'] ?? false,
      isArchived: map['isArchived'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory CardModel.fromFirestore(DocumentSnapshot doc) {
    return CardModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }
}

class CardTemplateModel {
  final String id;
  final String name;
  final String category;
  final String previewUrl;
  final Map<String, dynamic> layersData;
  final bool isPremium;
  final int sortOrder;

  CardTemplateModel({
    required this.id,
    required this.name,
    required this.category,
    required this.previewUrl,
    required this.layersData,
    required this.isPremium,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'previewUrl': previewUrl,
        'layersData': layersData,
        'isPremium': isPremium,
        'sortOrder': sortOrder,
      };

  factory CardTemplateModel.fromMap(String id, Map<String, dynamic> map) {
    return CardTemplateModel(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? 'custom',
      previewUrl: map['previewUrl'] ?? '',
      layersData: Map<String, dynamic>.from(map['layersData'] ?? {}),
      isPremium: map['isPremium'] ?? false,
      sortOrder: (map['sortOrder'] ?? 0) as int,
    );
  }

  factory CardTemplateModel.fromFirestore(DocumentSnapshot doc) {
    return CardTemplateModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String fromUserId;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.fromUserId,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  String get title => (payload['title'] as String?) ?? '';
  String get body => (payload['body'] as String?) ?? '';
  String get fromDisplayName => (payload['fromDisplayName'] as String?) ?? '';
  String get fromAvatarUrl => (payload['fromAvatarUrl'] as String?) ?? '';
  String get fromFruitEmoji => (payload['fromFruitEmoji'] as String?) ?? '🥝';

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': type.value,
        'fromUserId': fromUserId,
        'payload': payload,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      type: NotificationTypeX.fromString(map['type']),
      fromUserId: map['fromUserId'] ?? '',
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    return NotificationModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }
}

class StoryModel {
  final String id;
  final String userId;
  final String content;
  final String? imageUrl;
  final String backgroundColor;
  final String textColor;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;

  StoryModel({
    required this.id,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.backgroundColor,
    required this.textColor,
    required this.createdAt,
    required this.expiresAt,
    required this.viewedBy,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'content': content,
        'imageUrl': imageUrl,
        'backgroundColor': backgroundColor,
        'textColor': textColor,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'viewedBy': viewedBy,
      };

  factory StoryModel.fromMap(String id, Map<String, dynamic> map) {
    return StoryModel(
      id: id,
      userId: map['userId'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      backgroundColor: map['backgroundColor'] ?? '#8AC926',
      textColor: map['textColor'] ?? '#FFFFFF',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 24)),
      viewedBy: List<String>.from(map['viewedBy'] ?? []),
    );
  }

  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    return StoryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get remainingTime => expiresAt.difference(DateTime.now());
}

// =================================================================
// 📦 EXTENSION DES MODÈLES : POSTS ENRICHIS & COMMENTAIRES
// =================================================================

enum PostType { text, media }

extension PostTypeX on PostType {
  String get value => name;
  static PostType fromString(String? s) {
    return PostType.values.firstWhere((e) => e.name == s, orElse: () => PostType.text);
  }
}

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userDisplayName;
  final String userAvatarUrl;
  final String userFruitEmoji;
  final String text;
  final String? audioUrl;
  final String? parentCommentId; // pour les réponses
  final List<String> likedBy;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userDisplayName,
    required this.userAvatarUrl,
    required this.userFruitEmoji,
    required this.text,
    this.audioUrl,
    this.parentCommentId,
    required this.likedBy,
    required this.createdAt,
  });

  int get likesCount => likedBy.length;
  bool isLikedBy(String uid) => likedBy.contains(uid);

  Map<String, dynamic> toMap() => {
        'postId': postId,
        'userId': userId,
        'userDisplayName': userDisplayName,
        'userAvatarUrl': userAvatarUrl,
        'userFruitEmoji': userFruitEmoji,
        'text': text,
        'audioUrl': audioUrl,
        'parentCommentId': parentCommentId,
        'likedBy': likedBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userDisplayName: map['userDisplayName'] ?? '',
      userAvatarUrl: map['userAvatarUrl'] ?? '',
      userFruitEmoji: map['userFruitEmoji'] ?? '🥝',
      text: map['text'] ?? '',
      audioUrl: map['audioUrl'],
      parentCommentId: map['parentCommentId'],
      likedBy: List<String>.from(map['likedBy'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class PostModel {
  final String id;
  final String userId;
  final PostType postType;
  final String title;
  final String description;
  final EventCategory category;
  final DateTime eventDate;
  final String backgroundColor;
  final String textColor;
  final String? imageUrl;
  final String? videoUrl;
  final List<String> likedBy;
  final int commentsCount;
  final int sharesCount;
  final String? originalPostId;      // Pour repartage
  final String? originalAuthorId;    // Pour repartage
  final String? originalAuthorName;  // Pour repartage
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.userId,
    this.postType = PostType.text,
    required this.title,
    required this.description,
    required this.category,
    required this.eventDate,
    required this.backgroundColor,
    required this.textColor,
    this.imageUrl,
    this.videoUrl,
    required this.likedBy,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.originalPostId,
    this.originalAuthorId,
    this.originalAuthorName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'postType': postType.value,
        'title': title,
        'description': description,
        'category': category.value,
        'eventDate': Timestamp.fromDate(eventDate),
        'backgroundColor': backgroundColor,
        'textColor': textColor,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'likedBy': likedBy,
        'commentsCount': commentsCount,
        'sharesCount': sharesCount,
        'originalPostId': originalPostId,
        'originalAuthorId': originalAuthorId,
        'originalAuthorName': originalAuthorName,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    return PostModel(
      id: id,
      userId: map['userId'] ?? '',
      postType: PostTypeX.fromString(map['postType']),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: EventCategoryX.fromString(map['category']),
      eventDate: (map['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      backgroundColor: map['backgroundColor'] ?? '#8AC926',
      textColor: map['textColor'] ?? '#FFFFFF',
      imageUrl: map['imageUrl'],
      videoUrl: map['videoUrl'],
      likedBy: List<String>.from(map['likedBy'] ?? []),
      commentsCount: (map['commentsCount'] ?? 0) as int,
      sharesCount: (map['sharesCount'] ?? 0) as int,
      originalPostId: map['originalPostId'],
      originalAuthorId: map['originalAuthorId'],
      originalAuthorName: map['originalAuthorName'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    return PostModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  int get likesCount => likedBy.length;
  bool isLikedBy(String userId) => likedBy.contains(userId);
  bool get isShared => originalPostId != null;
}

class PostBackgroundPreset {
  final String name;
  final String bgColor;
  final String textColor;
  final String emoji;
  const PostBackgroundPreset({
    required this.name,
    required this.bgColor,
    required this.textColor,
    required this.emoji,
  });
}

const List<PostBackgroundPreset> kPostBackgrounds = [
  PostBackgroundPreset(name: 'Kiwi', bgColor: '#8AC926', textColor: '#FFFFFF', emoji: '🥝'),
  PostBackgroundPreset(name: 'Sunset', bgColor: '#FF6B6B', textColor: '#FFFFFF', emoji: '🌅'),
  PostBackgroundPreset(name: 'Ocean', bgColor: '#4D96FF', textColor: '#FFFFFF', emoji: '🌊'),
  PostBackgroundPreset(name: 'Purple', bgColor: '#9D4EDD', textColor: '#FFFFFF', emoji: '💜'),
  PostBackgroundPreset(name: 'Gold', bgColor: '#FFB703', textColor: '#000000', emoji: '⭐'),
  PostBackgroundPreset(name: 'Emerald', bgColor: '#06D6A0', textColor: '#FFFFFF', emoji: '💚'),
  PostBackgroundPreset(name: 'Rose', bgColor: '#F72585', textColor: '#FFFFFF', emoji: '🌸'),
  PostBackgroundPreset(name: 'Dark', bgColor: '#1A1A2E', textColor: '#FAFAFA', emoji: '🌙'),
  PostBackgroundPreset(name: 'Cream', bgColor: '#FFF3B0', textColor: '#1A1A2E', emoji: '☀️'),
];

// =================================================================
// 📦 EXTENSION DES MODÈLES (NOUVEAU) : MESSAGERIE INSTANTANÉE (CHAT)
// =================================================================

enum MessageType { text, image, video }

extension MessageTypeX on MessageType {
  String get value => name;
  static MessageType fromString(String? s) {
    return MessageType.values.firstWhere((e) => e.name == s, orElse: () => MessageType.text);
  }
}

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;

  ChatRoomModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCounts,
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
    );
  }
}

class MessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String text;
  final MessageType type;
  final String? mediaUrl;
  final DateTime createdAt;

  MessageModel({
    required this.id, 
    required this.roomId, 
    required this.senderId,
    required this.text, 
    required this.type, 
    this.mediaUrl, 
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'roomId': roomId, 
        'senderId': senderId, 
        'text': text,
        'type': type.value, 
        'mediaUrl': mediaUrl,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      type: MessageTypeX.fromString(data['type']),
      mediaUrl: data['mediaUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}