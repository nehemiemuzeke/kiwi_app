import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static const String _cloudinaryCloudName = 'r1favlgd';
  static const String _cloudinaryUploadPreset = 'avt93t6e';

  String? getCurrentUserId() => _auth.currentUser?.uid;
  User? getCurrentUser() => _auth.currentUser;

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required String fruitEmoji,
    required String fruitPersonality,
  }) async {
    final taken = await isUsernameTaken(username);
    if (taken) {
      throw FirebaseAuthException(
        code: 'username-taken',
        message: 'Ce nom d\'utilisateur est déjà pris',
      );
    }
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = UserModel(
      id: cred.user!.uid,
      displayName: displayName,
      username: username.toLowerCase(),
      email: email,
      avatarUrl: '',
      bio: '',
      fruitEmoji: fruitEmoji,
      fruitPersonality: fruitPersonality,
      fcmToken: '',
      followersCount: 0,
      followingCount: 0,
      createdAt: DateTime.now(),
    );
    await createUserProfile(cred.user!.uid, user);
    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    await _ensureUserProfile(userCred.user!, googleUser.displayName ?? 'User');
    return userCred;
  }

  Future<UserCredential?> signInWithApple() async {
    final appleCred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCred.identityToken,
      accessToken: appleCred.authorizationCode,
    );
    final userCred = await _auth.signInWithCredential(oauthCredential);
    final name = '${appleCred.givenName ?? ''} ${appleCred.familyName ?? ''}'
        .trim();
    await _ensureUserProfile(
      userCred.user!,
      name.isEmpty ? 'User Apple' : name,
    );
    return userCred;
  }

  Future<void> _ensureUserProfile(User user, String fallbackName) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) return;
    var username = (user.email?.split('@').first ??
            'user_${user.uid.substring(0, 6)}')
        .toLowerCase();
    username = username.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    var finalUsername = username;
    var counter = 1;
    while (await isUsernameTaken(finalUsername)) {
      finalUsername = '$username$counter';
      counter++;
    }
    final newUser = UserModel(
      id: user.uid,
      displayName: user.displayName ?? fallbackName,
      username: finalUsername,
      email: user.email ?? '',
      avatarUrl: user.photoURL ?? '',
      bio: '',
      fruitEmoji: '🥝',
      fruitPersonality: 'Original et surprenant',
      fcmToken: '',
      followersCount: 0,
      followingCount: 0,
      createdAt: DateTime.now(),
    );
    await createUserProfile(user.uid, newUser);
  }

  Future<void> signOut() async {
    final uid = getCurrentUserId();
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).set(
          {'fcmToken': ''},
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> createUserProfile(String userId, UserModel user) {
    return _db.collection('users').doc(userId).set(
          user.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Stream<UserModel?> getUserProfileStream(String userId) {
    return _db.collection('users').doc(userId).snapshots().map(
          (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
        );
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) {
    return _db.collection('users').doc(userId).set(
          data,
          SetOptions(merge: true),
        );
  }

  Future<String> uploadAvatar(String userId, File file) async {
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    if (response.statusCode != 200) throw Exception('Erreur d\'envoi photo');
    final resData = await response.stream.bytesToString();
    final jsonMap = jsonDecode(resData);
    final downloadUrl = jsonMap['secure_url'] as String;
    await updateUserProfile(userId, {'avatarUrl': downloadUrl});
    return downloadUrl;
  }

  Future<String> uploadImageToCloudinary(File file) async {
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    if (response.statusCode != 200) throw Exception('Erreur d\'envoi');
    final resData = await response.stream.bytesToString();
    final jsonMap = jsonDecode(resData);
    return jsonMap['secure_url'] as String;
  }

  Future<String> uploadCardMedia(String cardId, File file, String type) async {
    final resourceType =
        (type == 'video' || type == 'audio') ? 'video' : 'image';
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/$resourceType/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    if (response.statusCode != 200) throw Exception('Erreur envoi média');
    final resData = await response.stream.bytesToString();
    final jsonMap = jsonDecode(resData);
    return jsonMap['secure_url'] as String;
  }

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    try {
      final byUsername = await _db
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: q)
          .where('username', isLessThan: '${q}z')
          .limit(20)
          .get();
      final byName = await _db
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: q)
          .where('displayNameLower', isLessThan: '${q}z')
          .limit(20)
          .get();
      final Map<String, UserModel> map = {};
      for (final d in byUsername.docs) {
        map[d.id] = UserModel.fromFirestore(d);
      }
      for (final d in byName.docs) {
        map[d.id] = UserModel.fromFirestore(d);
      }
      final me = getCurrentUserId();
      return map.values.where((u) => u.id != me).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UserModel>> getSuggestedUsers({int limit = 15}) async {
    final me = getCurrentUserId();
    try {
      final snap = await _db
          .collection('users')
          .orderBy('followersCount', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map(UserModel.fromFirestore)
          .where((u) => u.id != me)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isUsernameTaken(String username) async {
    final snap = await _db
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> followUser(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) return;
    final id = '${currentUserId}_$targetUserId';
    
    await _db.collection('follows').doc(id).set({
      'followerId': currentUserId,
      'followingId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    await _db.collection('users').doc(currentUserId).set(
      {'followingCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    
    await _db.collection('users').doc(targetUserId).set(
      {'followersCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );

    // 🔔 NOTIFICATION AUTOMATIQUE AU FOLLOW
    await notifyNewFollower(
      targetUserId: targetUserId,
      followerId: currentUserId,
    );
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final id = '${currentUserId}_$targetUserId';
    final doc = await _db.collection('follows').doc(id).get();
    if (!doc.exists) return;
    await _db.collection('follows').doc(id).delete();
    await _db.collection('users').doc(currentUserId).set(
      {'followingCount': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );
    await _db.collection('users').doc(targetUserId).set(
      {'followersCount': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );
  }

  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final doc =
        await _db.collection('follows').doc('${currentUserId}_$targetUserId').get();
    return doc.exists;
  }

  Stream<bool> isFollowingStream(String currentUserId, String targetUserId) {
    return _db
        .collection('follows')
        .doc('${currentUserId}_$targetUserId')
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<List<UserModel>> getFollowers(String userId) {
    return _db
        .collection('follows')
        .where('followingId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs.map((d) => d['followerId'] as String).toList();
      return _fetchUsersByIds(ids);
    });
  }

  Stream<List<UserModel>> getFollowing(String userId) {
    return _db
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs.map((d) => d['followingId'] as String).toList();
      return _fetchUsersByIds(ids);
    });
  }

  Future<List<UserModel>> _fetchUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<UserModel> result = [];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      result.addAll(snap.docs.map(UserModel.fromFirestore));
    }
    return result;
  }

  Future<void> addEvent(String userId, EventModel event) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('events')
        .add(event.toMap());
  }

  Future<void> updateEvent(
      String userId, String eventId, Map<String, dynamic> data) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('events')
        .doc(eventId)
        .update(data);
  }

  Future<void> deleteEvent(String userId, String eventId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('events')
        .doc(eventId)
        .delete();
  }

  Stream<List<EventModel>> getUserEvents(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('events')
        .orderBy('date')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => EventModel.fromFirestore(d, userId)).toList());
  }

  Stream<List<EventModel>> getFollowingEvents(String currentUserId) async* {
    final followsStream = _db
        .collection('follows')
        .where('followerId', isEqualTo: currentUserId)
        .snapshots();
    await for (final snap in followsStream) {
      final ids = snap.docs.map((d) => d['followingId'] as String).toList();
      ids.add(currentUserId);
      final List<EventModel> all = [];
      for (final uid in ids) {
        final ev = await _db
            .collection('users')
            .doc(uid)
            .collection('events')
            .where('isPublic', isEqualTo: true)
            .get();
        all.addAll(ev.docs.map((d) => EventModel.fromFirestore(d, uid)));
      }
      all.sort((a, b) => a.date.compareTo(b.date));
      yield all;
    }
  }

  Stream<List<EventModel>> getUpcomingEvents(String currentUserId,
      {int limit = 10}) {
    return getFollowingEvents(currentUserId).map((events) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final upcoming = events.where((e) {
        final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
        return !eventDate.isBefore(today);
      }).toList();
      upcoming.sort((a, b) => a.date.compareTo(b.date));
      return upcoming.take(limit).toList();
    });
  }

  Future<List<CardTemplateModel>> getCardTemplates({String? category}) async {
    Query q = _db.collection('cardTemplates').orderBy('sortOrder');
    if (category != null) q = q.where('category', isEqualTo: category);
    final snap = await q.get();
    return snap.docs.map((d) => CardTemplateModel.fromFirestore(d)).toList();
  }

  Future<void> sendCard(CardModel card) async {
    await _db.collection('cards').doc(card.id).set(card.toMap());
    
    // 🔔 NOTIFICATION AUTOMATIQUE (Carte)
    await notifyCardReceived(
      receiverId: card.receiverId,
      senderId: card.senderId,
      cardId: card.id,
    );
  }

  Future<void> deleteCard(String cardId) {
    return _db.collection('cards').doc(cardId).delete();
  }

  Stream<List<CardModel>> getReceivedCards(String userId) {
    return _db
        .collection('cards')
        .where('receiverId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CardModel.fromFirestore(d)).toList());
  }

  Stream<List<CardModel>> getSentCards(String userId) {
    return _db
        .collection('cards')
        .where('senderId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CardModel.fromFirestore(d)).toList());
  }

  Future<void> markCardAsRead(String cardId) {
    return _db.collection('cards').doc(cardId).update({'isRead': true});
  }

  Stream<int> getUnreadCardCount(String userId) {
    return _db
        .collection('cards')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> createStory(StoryModel story) async {
    await _db.collection('stories').doc(story.id).set(story.toMap());
    
    // 🔔 NOTIFICATION AUTOMATIQUE (Statut)
    notifyFollowersNewStory(authorId: story.userId);
  }

  Future<void> markStoryViewed(String storyId, String userId) {
    return _db.collection('stories').doc(storyId).update({
      'viewedBy': FieldValue.arrayUnion([userId]),
    });
  }

  Stream<List<StoryModel>> getFeedStories(String currentUserId) async* {
    final followsSnap = _db
        .collection('follows')
        .where('followerId', isEqualTo: currentUserId)
        .snapshots();
    await for (final snap in followsSnap) {
      final ids = snap.docs.map((d) => d['followingId'] as String).toList();
      ids.add(currentUserId);
      final now = DateTime.now();
      final List<StoryModel> all = [];
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final st =
            await _db.collection('stories').where('userId', whereIn: chunk).get();
        for (final d in st.docs) {
          final s = StoryModel.fromFirestore(d);
          if (s.expiresAt.isAfter(now)) all.add(s);
        }
      }
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      yield all;
    }
  }

  Future<void> createPost(PostModel post) async {
    await _db.collection('posts').doc(post.id).set(post.toMap());
    
    // 🔔 NOTIFICATION AUTOMATIQUE (Post)
    notifyFollowersNewPost(
      authorId: post.userId,
      postTitle: post.title,
      postId: post.id,
    );
  }

  Stream<List<PostModel>> getUserPosts(String userId) {
    return _db
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PostModel.fromFirestore(d)).toList());
  }

  Future<void> toggleLikePost(String postId, String userId) async {
    final ref = _db.collection('posts').doc(postId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    final liked = List<String>.from(data['likedBy'] ?? []);
    
    if (liked.contains(userId)) {
      await ref.update({
        'likedBy': FieldValue.arrayRemove([userId])
      });
    } else {
      await ref.update({
        'likedBy': FieldValue.arrayUnion([userId])
      });
      
      // 🔔 NOTIFICATION AUTOMATIQUE (Like)
      final authorId = data['userId'] as String?;
      final title = data['title'] as String?;
      if (authorId != null) {
        notifyPostLiked(
          postAuthorId: authorId,
          likerId: userId,
          postTitle: title,
        );
      }
    }
  }

  Stream<List<PostModel>> getFeedPosts(String currentUserId) async* {
    final followsSnap = _db
        .collection('follows')
        .where('followerId', isEqualTo: currentUserId)
        .snapshots();
    await for (final snap in followsSnap) {
      final ids = snap.docs.map((d) => d['followingId'] as String).toList();
      ids.add(currentUserId);
      final List<PostModel> all = [];
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final ps =
            await _db.collection('posts').where('userId', whereIn: chunk).get();
        all.addAll(ps.docs.map(PostModel.fromFirestore));
      }
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      yield all;
    }
  }

  Future<void> saveEventFromPost(
      String currentUserId, PostModel post, UserModel author) async {
    final event = EventModel(
      id: '',
      userId: currentUserId,
      title: '${post.title} (de ${author.displayName})',
      date: post.eventDate,
      category: post.category,
      isPublic: false,
      isRecurringYearly: false,
      createdAt: DateTime.now(),
    );
    await addEvent(currentUserId, event);
  }

  Future<void> initFCM(String userId) async {
    try {
      await _fcm.requestPermission();
      final token = await _fcm.getToken();
      if (token != null) {
        await updateUserProfile(userId, {'fcmToken': token});
      }
      _fcm.onTokenRefresh.listen((t) {
        updateUserProfile(userId, {'fcmToken': t});
      });
    } catch (_) {}
  }

  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => NotificationModel.fromFirestore(d)).toList());
  }

  Future<void> markNotificationRead(String notifId) {
    return _db
        .collection('notifications')
        .doc(notifId)
        .update({'isRead': true});
  }

  Stream<int> getUnreadNotifCount(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // =====================================================
  // 💬 COMMENTAIRES
  // =====================================================

  Future<void> addComment(CommentModel comment) async {
    await _db.collection('comments').doc(comment.id).set(comment.toMap());
    await _db.collection('posts').doc(comment.postId).set(
      {'commentsCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  Future<void> deleteComment(String commentId, String postId) async {
    await _db.collection('comments').doc(commentId).delete();
    await _db.collection('posts').doc(postId).set(
      {'commentsCount': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );
  }

  Stream<List<CommentModel>> getPostComments(String postId) {
    return _db
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => CommentModel.fromFirestore(d)).toList());
  }

  Future<void> toggleLikeComment(String commentId, String userId) async {
    final ref = _db.collection('comments').doc(commentId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    final liked = List<String>.from(data['likedBy'] ?? []);
    if (liked.contains(userId)) {
      await ref.update({'likedBy': FieldValue.arrayRemove([userId])});
    } else {
      await ref.update({'likedBy': FieldValue.arrayUnion([userId])});
    }
  }

  // =====================================================
  // 🔄 PARTAGE / REPARTAGE
  // =====================================================

  Future<void> sharePost(PostModel originalPost, String currentUserId) async {
    final newId = generateId();
    final shared = PostModel(
      id: newId,
      userId: currentUserId,
      postType: originalPost.postType,
      title: originalPost.title,
      description: originalPost.description,
      category: originalPost.category,
      eventDate: originalPost.eventDate,
      backgroundColor: originalPost.backgroundColor,
      textColor: originalPost.textColor,
      imageUrl: originalPost.imageUrl,
      videoUrl: originalPost.videoUrl,
      likedBy: const [],
      commentsCount: 0,
      sharesCount: 0,
      originalPostId: originalPost.id,
      originalAuthorId: originalPost.userId,
      originalAuthorName: '', // sera rempli plus tard si tu veux
      createdAt: DateTime.now(),
    );
    await _db.collection('posts').doc(newId).set(shared.toMap());
    await _db.collection('posts').doc(originalPost.id).set(
      {'sharesCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  // =====================================================
  // 🗑️ POSTS : SUPPRESSION (NOUVEAU)
  // =====================================================
  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  // =====================================================
  // 💬 MESSAGERIE INSTANTANÉE (CHAT - NOUVEAU)
  // =====================================================
  
  Future<String> createOrGetChatRoom(String user1, String user2) async {
    final participants = [user1, user2]..sort(); // Tri alphabétique pour un ID unique
    final roomId = '${participants[0]}_${participants[1]}';
    
    final doc = await _db.collection('chats').doc(roomId).get();
    if (!doc.exists) {
      await _db.collection('chats').doc(roomId).set({
        'participants': participants,
        'lastMessage': 'Nouvelle conversation',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': {user1: 0, user2: 0},
      });
    }
    return roomId;
  }

  Stream<List<ChatRoomModel>> getUserChatRooms(String userId) {
    return _db.collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatRoomModel.fromFirestore(doc)).toList());
  }

  Stream<List<MessageModel>> getChatMessages(String roomId) {
    return _db.collection('chats').doc(roomId).collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  Future<void> sendMessage(String roomId, String senderId, String text, {MessageType type = MessageType.text, String? mediaUrl}) async {
    final msgId = generateId();
    final msg = MessageModel(
      id: msgId, roomId: roomId, senderId: senderId,
      text: text, type: type, mediaUrl: mediaUrl, createdAt: DateTime.now(),
    );
    
    await _db.collection('chats').doc(roomId).collection('messages').doc(msgId).set(msg.toMap());
    
    final roomDoc = await _db.collection('chats').doc(roomId).get();
    final participants = List<String>.from(roomDoc.data()?['participants'] ?? []);
    final receiverId = participants.firstWhere((p) => p != senderId, orElse: () => '');
    
    await _db.collection('chats').doc(roomId).update({
      'lastMessage': type == MessageType.text ? text : (type == MessageType.image ? '📷 Image' : '🎥 Vidéo'),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });
  }

  Future<void> markMessagesAsRead(String roomId, String userId) async {
    await _db.collection('chats').doc(roomId).update({
      'unreadCounts.$userId': 0,
    });
  }

  String generateId() => const Uuid().v4();

  // =====================================================
  // NOTIFICATIONS AUTOMATIQUES (CREATION DANS FIRESTORE)
  // =====================================================

  Future<void> _createNotification({
    required String toUserId,
    required NotificationType type,
    required String fromUserId,
    required String title,
    required String body,
    String? fromDisplayName,
    String? fromAvatarUrl,
    String? fromFruitEmoji,
    Map<String, dynamic>? extraPayload,
  }) async {
    if (toUserId.isEmpty) return;
    if (fromUserId.isNotEmpty && fromUserId == toUserId) return;

    try {
      await _db.collection('notifications').add({
        'userId': toUserId,
        'type': type.value,
        'fromUserId': fromUserId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'payload': {
          'title': title,
          'body': body,
          'fromDisplayName': fromDisplayName ?? '',
          'fromAvatarUrl': fromAvatarUrl ?? '',
          'fromFruitEmoji': fromFruitEmoji ?? '🥝',
          if (extraPayload != null) ...extraPayload,
        },
      });
    } catch (_) {}
  }

  Future<UserModel?> _safeGetUser(String userId) async {
    try {
      return await getUserProfile(userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> notifyNewFollower({
    required String targetUserId,
    required String followerId,
  }) async {
    final follower = await _safeGetUser(followerId);
    if (follower == null) return;

    await _createNotification(
      toUserId: targetUserId,
      type: NotificationType.new_follower,
      fromUserId: followerId,
      title: 'Nouveau Kiwi 🥝',
      body: 'a commencé à te suivre',
      fromDisplayName: follower.displayName,
      fromAvatarUrl: follower.avatarUrl,
      fromFruitEmoji: follower.fruitEmoji,
    );
  }

  Future<void> notifyFollowersNewPost({
    required String authorId,
    required String postTitle,
    String? postId,
  }) async {
    final author = await _safeGetUser(authorId);
    if (author == null) return;

    final snap = await _db
        .collection('follows')
        .where('followingId', isEqualTo: authorId)
        .get();

    for (final doc in snap.docs) {
      final followerId = doc.data()['followerId'] as String?;
      if (followerId == null) continue;

      await _createNotification(
        toUserId: followerId,
        type: NotificationType.new_post,
        fromUserId: authorId,
        title: 'Nouveau moment 🥝',
        body: 'a publié « $postTitle »',
        fromDisplayName: author.displayName,
        fromAvatarUrl: author.avatarUrl,
        fromFruitEmoji: author.fruitEmoji,
        extraPayload: postId != null ? {'postId': postId} : null,
      );
    }
  }

  Future<void> notifyFollowersNewStory({
    required String authorId,
  }) async {
    final author = await _safeGetUser(authorId);
    if (author == null) return;

    final snap = await _db
        .collection('follows')
        .where('followingId', isEqualTo: authorId)
        .get();

    for (final doc in snap.docs) {
      final followerId = doc.data()['followerId'] as String?;
      if (followerId == null) continue;

      await _createNotification(
        toUserId: followerId,
        type: NotificationType.new_story,
        fromUserId: authorId,
        title: 'Nouveau statut',
        body: 'a ajouté un statut',
        fromDisplayName: author.displayName,
        fromAvatarUrl: author.avatarUrl,
        fromFruitEmoji: author.fruitEmoji,
      );
    }
  }

  Future<void> notifyCardReceived({
    required String receiverId,
    required String senderId,
    String? cardId,
  }) async {
    final sender = await _safeGetUser(senderId);
    if (sender == null) return;

    await _createNotification(
      toUserId: receiverId,
      type: NotificationType.card_received,
      fromUserId: senderId,
      title: 'Carte spéciale 💌',
      body: 't\'a envoyé une carte Kiwi',
      fromDisplayName: sender.displayName,
      fromAvatarUrl: sender.avatarUrl,
      fromFruitEmoji: sender.fruitEmoji,
      extraPayload: cardId != null ? {'cardId': cardId} : null,
    );
  }

  Future<void> notifyFriendSuggestion({
    required String toUserId,
    required UserModel suggestedUser,
  }) async {
    await _createNotification(
      toUserId: toUserId,
      type: NotificationType.friend_suggestion,
      fromUserId: suggestedUser.id,
      title: 'Suggestion pour toi',
      body: 'Découvre ${suggestedUser.displayName} (@${suggestedUser.username})',
      fromDisplayName: suggestedUser.displayName,
      fromAvatarUrl: suggestedUser.avatarUrl,
      fromFruitEmoji: suggestedUser.fruitEmoji,
    );
  }

  Future<void> notifyPostLiked({
    required String postAuthorId,
    required String likerId,
    String? postTitle,
  }) async {
    final liker = await _safeGetUser(likerId);
    if (liker == null) return;

    await _createNotification(
      toUserId: postAuthorId,
      type: NotificationType.post_liked,
      fromUserId: likerId,
      title: 'Nouveau kiwi 🥝',
      body: postTitle != null && postTitle.isNotEmpty
          ? 'a aimé ton moment « $postTitle »'
          : 'a aimé ton moment',
      fromDisplayName: liker.displayName,
      fromAvatarUrl: liker.avatarUrl,
      fromFruitEmoji: liker.fruitEmoji,
    );
  }
}