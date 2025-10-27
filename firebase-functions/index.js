// Firebase Cloud Functions for MessageAi
// This function sends FCM push notifications when new messages are created

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const OpenAI = require('openai');

admin.initializeApp();

// Initialize OpenAI with API key from Firebase config
// Set via: firebase functions:config:set openai.key="your-api-key"
const openai = new OpenAI({
  apiKey: functions.config().openai?.key || process.env.OPENAI_API_KEY,
});

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
    console.log('📥 Fetching FCM tokens for recipients:', recipientIds);

    // Fetch FCM tokens
    const tokens = [];
    for (const userId of recipientIds) {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        console.log(`User ${userId}: fcmToken = ${userData.fcmToken ? 'EXISTS' : 'MISSING'}`);
        if (userData.fcmToken) {
          tokens.push(userData.fcmToken);
        }
      } else {
        console.log(`User ${userId}: document does not exist`);
      }
    }

    console.log(`📱 Found ${tokens.length} FCM tokens`);

    if (tokens.length === 0) {
      console.error('❌ No FCM tokens found for recipients');
      return { success: false, message: 'No FCM tokens found' };
    }

    // Send notification
    const message = {
      notification: {
        title: title || 'New Message',
        body: body || '',
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

    console.log('📤 Sending notification to FCM...');
    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(`✅ Success: ${response.successCount}, Failed: ${response.failureCount}`);

    // Log failures
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error(`❌ Failed to send to token ${idx}:`, resp.error);
        }
      });
    }

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('❌ Error in sendNotificationHTTP:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Analyze Message - Unified translation function
 * Returns: detected language, full translation, and word-by-word translations
 * Uses OpenAI GPT-4o with structured outputs for consistent parsing
 */
exports.analyzeMessage = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { messageText, targetLanguage, fluentLanguage } = data;

  if (!messageText || !targetLanguage || !fluentLanguage) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'messageText, targetLanguage, and fluentLanguage are required'
    );
  }

  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-5-mini-2025-08-07',
      messages: [
        {
          role: 'system',
          content: `You are a language translation assistant. Analyze the given message and provide:
1. Detected language (ISO 639-1 code like 'en', 'es', 'fr')
2. Full translation of the message into ${targetLanguage}
3. Word-by-word or phrase-by-phrase translations into ${fluentLanguage}

For wordTranslations array:
- Break down the message into meaningful words/phrases
- Provide startIndex and endIndex for each word in the original text
- Include part of speech (noun, verb, adjective, etc.)
- Add brief context explaining usage
- Preserve order from the original message`,
        },
        {
          role: 'user',
          content: `Message to analyze: "${messageText}"`,
        },
      ],
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'message_analysis',
          strict: true,
          schema: {
            type: 'object',
            properties: {
              detectedLanguage: {
                type: 'string',
                description: 'ISO 639-1 language code',
              },
              fullTranslation: {
                type: 'string',
                description: `Full message translation in ${targetLanguage}`,
              },
              wordTranslations: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    originalWord: {
                      type: 'string',
                      description: 'The original word or phrase',
                    },
                    translation: {
                      type: 'string',
                      description: `Translation in ${fluentLanguage}`,
                    },
                    partOfSpeech: {
                      type: 'string',
                      description: 'Part of speech (noun, verb, adjective, etc.)',
                    },
                    startIndex: {
                      type: 'integer',
                      description: 'Start index in original text',
                    },
                    endIndex: {
                      type: 'integer',
                      description: 'End index in original text',
                    },
                    context: {
                      type: 'string',
                      description: 'Brief explanation of usage',
                    },
                  },
                  required: ['originalWord', 'translation', 'partOfSpeech', 'startIndex', 'endIndex', 'context'],
                  additionalProperties: false,
                },
              },
            },
            required: ['detectedLanguage', 'fullTranslation', 'wordTranslations'],
            additionalProperties: false,
          },
        },
      },
    });

    const result = JSON.parse(completion.choices[0].message.content);

    console.log(`Analyzed message in ${result.detectedLanguage} with ${result.wordTranslations.length} translations`);

    return result;
  } catch (error) {
    console.error('Error in analyzeMessage:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Expand Word Context - Detailed word breakdown
 * Provides: etymology, conjugation, multiple meanings, example sentences
 * Called when user taps expand arrow on translation popover
 */
exports.expandWordContext = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { word, sourceLanguage, targetLanguage } = data;

  if (!word || !sourceLanguage || !targetLanguage) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'word, sourceLanguage, and targetLanguage are required'
    );
  }

  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-5-mini-2025-08-07',
      messages: [
        {
          role: 'system',
          content: `You are an expert language teacher providing detailed word analysis. For the given word in ${sourceLanguage}, provide:
1. Word breakdown (root, grammatical form, conjugation/declension details)
2. Colloquial meaning if different from literal
3. Multiple common meanings with context for when each is used
4. 2-3 simple example sentences in ${sourceLanguage} with ${targetLanguage} translations

Be educational and clear. Focus on practical usage.`,
        },
        {
          role: 'user',
          content: `Analyze this word: "${word}"`,
        },
      ],
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'word_context',
          strict: true,
          schema: {
            type: 'object',
            properties: {
              wordBreakdown: {
                type: 'object',
                properties: {
                  root: {
                    type: 'string',
                    description: 'Root word or stem',
                  },
                  form: {
                    type: 'string',
                    description: 'Grammatical form (e.g., past participle, plural, etc.)',
                  },
                  conjugation: {
                    type: 'string',
                    description: 'Conjugation or declension details if applicable',
                  },
                },
                required: ['root', 'form', 'conjugation'],
                additionalProperties: false,
              },
              colloquialMeaning: {
                type: 'string',
                description: 'Colloquial or contextual meaning if different from literal',
              },
              multipleMeanings: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    meaning: {
                      type: 'string',
                      description: 'A different meaning of the word',
                    },
                    context: {
                      type: 'string',
                      description: 'When this meaning is typically used',
                    },
                  },
                  required: ['meaning', 'context'],
                  additionalProperties: false,
                },
              },
              exampleSentences: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    original: {
                      type: 'string',
                      description: `Sentence in ${sourceLanguage}`,
                    },
                    translation: {
                      type: 'string',
                      description: `Translation in ${targetLanguage}`,
                    },
                  },
                  required: ['original', 'translation'],
                  additionalProperties: false,
                },
              },
            },
            required: ['wordBreakdown', 'colloquialMeaning', 'multipleMeanings', 'exampleSentences'],
            additionalProperties: false,
          },
        },
      },
    });

    const result = JSON.parse(completion.choices[0].message.content);

    console.log(`Expanded context for word: ${word}`);

    return result;
  } catch (error) {
    console.error('Error in expandWordContext:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
