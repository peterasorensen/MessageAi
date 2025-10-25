// Firebase Cloud Functions for MessageAi
// This function sends FCM push notifications when new messages are created

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function to send push notifications
 * Triggered when a new document is created in the "notifications" collection
 * Note: Using onRequest instead of Firestore trigger to avoid multi-region issues
 */
exports.sendPushNotificationTrigger = functions.https.onRequest(async (req, res) => {
  // This is now an HTTP endpoint that can be called directly
  // We'll use the sendNotificationHTTP callable function instead
  res.status(200).send('Use sendNotificationHTTP callable function instead');
});

/**
 * Alternative: Firestore trigger (may have region issues)
 * Keeping this commented out for reference
 */
/*
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notification = snap.data();

      // Check if already sent
      if (notification.sent) {
        console.log('Notification already sent, skipping');
        return null;
      }

      const recipientIds = notification.recipientIds || [];
      const title = notification.title || 'New Message';
      const body = notification.body || '';
      const conversationId = notification.conversationId;
      const messageId = notification.messageId;

      console.log(`Sending notification to ${recipientIds.length} recipients`);

      // Fetch FCM tokens for all recipients
      const tokens = [];
      for (const userId of recipientIds) {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.fcmToken) {
            tokens.push(userData.fcmToken);
          }
        }
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for recipients');
        // Mark as sent even if no tokens (to avoid retry)
        await snap.ref.update({ sent: true, sentAt: admin.firestore.FieldValue.serverTimestamp() });
        return null;
      }

      console.log(`Found ${tokens.length} FCM tokens`);

      // Prepare FCM message payload
      const message = {
        notification: {
          title: title,
          body: body,
          sound: 'default',
        },
        data: {
          conversationId: conversationId,
          messageId: messageId,
          type: 'new_message',
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
              'content-available': 1, // Enable background notification
            },
          },
        },
        tokens: tokens,
      };

      // Send notification via FCM
      const response = await admin.messaging().sendEachForMulticast(message);

      console.log(`Successfully sent ${response.successCount} notifications`);
      console.log(`Failed to send ${response.failureCount} notifications`);

      // Log any failures
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Failed to send to token ${tokens[idx]}:`, resp.error);
          }
        });
      }

      // Mark notification as sent
      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      });

      return null;
    } catch (error) {
      console.error('Error sending push notification:', error);
      // Mark as sent to avoid infinite retry
      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error.message,
      });
      return null;
    }
  });
*/

/**
 * HTTP-triggered function for direct notification sending
 * Call this endpoint from your iOS app if you prefer HTTP requests over Firestore triggers
 */
exports.sendNotificationHTTP = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { recipientIds, title, body, conversationId, messageId } = data;

  if (!recipientIds || !Array.isArray(recipientIds) || recipientIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'recipientIds is required');
  }

  try {
    // Fetch FCM tokens
    const tokens = [];
    for (const userId of recipientIds) {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData.fcmToken) {
          tokens.push(userData.fcmToken);
        }
      }
    }

    if (tokens.length === 0) {
      return { success: false, message: 'No FCM tokens found' };
    }

    // Send notification
    const message = {
      notification: {
        title: title || 'New Message',
        body: body || '',
        sound: 'default',
      },
      data: {
        conversationId: conversationId || '',
        messageId: messageId || '',
        type: 'new_message',
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: 'default',
            'content-available': 1,
          },
        },
      },
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('Error in sendNotificationHTTP:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
