const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

exports.onNewFollow = functions.firestore
  .document("follows/{docId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const { followerId, followingId } = data;

    try {
      const followerDoc = await db.collection("users").doc(followerId).get();
      const targetDoc = await db.collection("users").doc(followingId).get();
      if (!followerDoc.exists || !targetDoc.exists) return null;

      const follower = followerDoc.data();
      const target = targetDoc.data();

      await db.collection("notifications").add({
        userId: followingId,
        type: "new_follower",
        fromUserId: followerId,
        payload: {
          message: `${follower.displayName} t'a kiwi 🥝`,
          username: follower.username,
        },
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (target.fcmToken) {
        await messaging.send({
          token: target.fcmToken,
          notification: {
            title: "Nouveau kiwi 🥝",
            body: `${follower.displayName} t'a kiwi !`,
          },
          data: { type: "new_follower", fromUserId: followerId },
        });
      }
    } catch (e) {
      console.error("onNewFollow error:", e);
    }
    return null;
  });

exports.onCardSent = functions.firestore
  .document("cards/{cardId}")
  .onCreate(async (snap, context) => {
    const card = snap.data();
    const { senderId, receiverId } = card;

    try {
      const senderDoc = await db.collection("users").doc(senderId).get();
      const receiverDoc = await db.collection("users").doc(receiverId).get();
      if (!senderDoc.exists || !receiverDoc.exists) return null;

      const sender = senderDoc.data();
      const receiver = receiverDoc.data();

      await db.collection("notifications").add({
        userId: receiverId,
        type: "card_received",
        fromUserId: senderId,
        payload: {
          message: `${sender.displayName} t'a envoyé une carte 📬`,
          cardId: context.params.cardId,
        },
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (receiver.fcmToken) {
        await messaging.send({
          token: receiver.fcmToken,
          notification: {
            title: "Nouvelle carte 📬",
            body: `${sender.displayName} t'a envoyé une carte Kiwi !`,
          },
          data: { type: "card_received", cardId: context.params.cardId },
        });
      }
    } catch (e) {
      console.error("onCardSent error:", e);
    }
    return null;
  });

exports.onEventCreated = functions.firestore
  .document("users/{userId}/events/{eventId}")
  .onCreate(async (snap, context) => {
    const event = snap.data();
    const { userId, eventId } = context.params;

    if (!event.isPublic) return null;

    try {
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) return null;
      const user = userDoc.data();

      const followersSnap = await db
        .collection("follows")
        .where("followingId", "==", userId)
        .get();

      const batch = db.batch();
      const tokens = [];

      for (const doc of followersSnap.docs) {
        const followerId = doc.data().followerId;
        const notifRef = db.collection("notifications").doc();
        batch.set(notifRef, {
          userId: followerId,
          type: "event_update",
          fromUserId: userId,
          payload: {
            message: `${user.displayName} a ajouté un moment : ${event.title}`,
            eventId,
          },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const followerDoc = await db.collection("users").doc(followerId).get();
        if (followerDoc.exists && followerDoc.data().fcmToken) {
          tokens.push(followerDoc.data().fcmToken);
        }
      }

      await batch.commit();

      if (tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: `${user.displayName} a un nouveau moment 📅`,
            body: event.title,
          },
          data: { type: "event_update", userId, eventId },
        });
      }
    } catch (e) {
      console.error("onEventCreated error:", e);
    }
    return null;
  });

exports.dailyEventReminder = functions.pubsub
  .schedule("every day 09:00")
  .timeZone("Europe/Paris")
  .onRun(async (context) => {
    try {
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

      const usersSnap = await db.collection("users").get();

      for (const userDoc of usersSnap.docs) {
        const userId = userDoc.id;
        const eventsSnap = await db
          .collection("users")
          .doc(userId)
          .collection("events")
          .get();

        for (const evDoc of eventsSnap.docs) {
          const ev = evDoc.data();
          if (!ev.isPublic) continue;

          let target = ev.date.toDate();
          if (ev.isRecurringYearly) {
            target = new Date(now.getFullYear(), target.getMonth(), target.getDate());
            if (target < today) {
              target = new Date(now.getFullYear() + 1, target.getMonth(), target.getDate());
            }
          }

          const diffDays = Math.round((target - today) / (1000 * 60 * 60 * 24));
          if (![0, 1, 3].includes(diffDays)) continue;

          const followsSnap = await db
            .collection("follows")
            .where("followingId", "==", userId)
            .get();

          const owner = userDoc.data();
          let title;
          if (diffDays === 0) title = `🎉 C'est le jour J pour ${owner.displayName} !`;
          else if (diffDays === 1) title = `⏰ Demain : ${ev.title} de ${owner.displayName}`;
          else title = `📅 Dans 3 jours : ${ev.title} de ${owner.displayName}`;

          for (const fDoc of followsSnap.docs) {
            const followerId = fDoc.data().followerId;
            await db.collection("notifications").add({
              userId: followerId,
              type: "event_reminder",
              fromUserId: userId,
              payload: { message: title, eventId: evDoc.id, daysLeft: diffDays },
              isRead: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            const followerDoc = await db.collection("users").doc(followerId).get();
            if (followerDoc.exists && followerDoc.data().fcmToken) {
              await messaging.send({
                token: followerDoc.data().fcmToken,
                notification: {
                  title: "Kiwi 🥝",
                  body: title,
                },
                data: { type: "event_reminder", userId, eventId: evDoc.id },
              });
            }
          }
        }
      }
    } catch (e) {
      console.error("dailyEventReminder error:", e);
    }
    return null;
  });

exports.onFollowDeleted = functions.firestore
  .document("follows/{docId}")
  .onDelete(async (snap, context) => {
    return null;
  });