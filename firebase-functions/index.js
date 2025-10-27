// Firebase Cloud Functions for MessageAi
// This function sends FCM push notifications when new messages are created

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const OpenAI = require('openai');
const { toFile } = require('openai/uploads');

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
 * Returns: detected language, full translation, word-by-word translations, slang/idioms, and cultural context
 * Uses OpenAI GPT-4o with structured outputs for consistent parsing
 */
exports.analyzeMessage = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { messageText, targetLanguage, fluentLanguage, userCountry } = data;

  if (!messageText || !targetLanguage || !fluentLanguage) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'messageText, targetLanguage, and fluentLanguage are required'
    );
  }

  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `You are a language translation assistant. Analyze the given message and provide:
1. Detected language (ISO 639-1 code like 'en', 'es', 'fr')
2. Full translation of the message into ${targetLanguage}
3. Word-by-word or phrase-by-phrase translations into ${fluentLanguage}
4. Detailed explanation of the full sentence meaning/context
5. Any slang, idioms, or cultural expressions found in the message
6. Detected country/region if applicable (e.g., 'MX' for Mexican Spanish, 'ES' for Spain Spanish)

For wordTranslations array:
- Break down the message into meaningful words/phrases
- Provide startIndex and endIndex for each word in the original text
- Include part of speech (noun, verb, adjective, etc.)
- Add brief context explaining usage
- Preserve order from the original message

For slangAndIdioms array:
- Identify any colloquial expressions, slang, idioms, or cultural references
- Explain their literal vs. actual meaning
- Provide context for when they're used${userCountry ? `\n- Consider the user's region (${userCountry}) for relevance` : ''}`,
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
              detectedCountry: {
                type: 'string',
                description: 'Detected country/region code if applicable (e.g., MX, ES, AR)',
              },
              fullTranslation: {
                type: 'string',
                description: `Full message translation in ${targetLanguage}`,
              },
              sentenceExplanation: {
                type: 'string',
                description: 'Detailed explanation of the full sentence meaning, context, and usage',
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
              slangAndIdioms: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    phrase: {
                      type: 'string',
                      description: 'The slang or idiomatic expression',
                    },
                    literalMeaning: {
                      type: 'string',
                      description: 'Word-for-word literal translation',
                    },
                    actualMeaning: {
                      type: 'string',
                      description: 'What it actually means in context',
                    },
                    culturalContext: {
                      type: 'string',
                      description: 'Cultural background and when it is typically used',
                    },
                  },
                  required: ['phrase', 'literalMeaning', 'actualMeaning', 'culturalContext'],
                  additionalProperties: false,
                },
              },
            },
            required: ['detectedLanguage', 'detectedCountry', 'fullTranslation', 'sentenceExplanation', 'wordTranslations', 'slangAndIdioms'],
            additionalProperties: false,
          },
        },
      },
    });

    const result = JSON.parse(completion.choices[0].message.content);

    console.log(`Analyzed message in ${result.detectedLanguage} (${result.detectedCountry}) with ${result.wordTranslations.length} translations and ${result.slangAndIdioms.length} slang/idioms`);

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
      model: 'gpt-4o-mini',
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

/**
 * Generate AI Response - For AI Pal chat conversations
 * Takes conversation messages and generates contextual responses
 */
exports.generateAIResponse = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { messages, targetLanguage } = data;

  if (!messages || !Array.isArray(messages) || messages.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'messages array is required');
  }

  if (!targetLanguage) {
    throw new functions.https.HttpsError('invalid-argument', 'targetLanguage is required');
  }

  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: messages,
      temperature: 0.8,
      max_tokens: 200,
    });

    const response = completion.choices[0]?.message?.content || '';

    return { response };
  } catch (error) {
    console.error('Error generating AI response:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Schedule AI Messages - Pub/Sub function that runs hourly
 * Sends scheduled messages to users at 11 AM and 7 PM in their local timezone
 */
exports.scheduleAIMessages = functions.pubsub
  .schedule('0 * * * *') // Run every hour
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      const now = new Date();
      const currentHour = now.getUTCHours();

      console.log(`Running scheduled AI messages check at UTC hour: ${currentHour}`);

      // Query users who have AI pal set up
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('aiPersonaType', '!=', null)
        .where('aiPalConversationId', '!=', null)
        .get();

      console.log(`Found ${usersSnapshot.size} users with AI pals`);

      const promises = [];

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const userId = userDoc.id;

        // For simplicity, we'll assume all users are in a timezone offset
        // In production, you'd store user timezone in their profile
        // For now, let's send to everyone at specific UTC hours
        // 11 AM EST = 16:00 UTC, 7 PM EST = 00:00 UTC
        // Adjust based on your user base

        // Check if it's time for morning message (assume 11 AM local = 16:00 UTC for EST)
        if (currentHour === 16) {
          promises.push(sendScheduledAIMessage(userId, userData, 'morning'));
        }
        // Check if it's time for evening message (assume 7 PM local = 00:00 UTC for EST)
        else if (currentHour === 0) {
          promises.push(sendScheduledAIMessage(userId, userData, 'evening'));
        }
      }

      await Promise.allSettled(promises);
      console.log('✅ Scheduled AI messages processing complete');

      return null;
    } catch (error) {
      console.error('❌ Error in scheduleAIMessages:', error);
      throw error;
    }
  });

/**
 * Helper function to send scheduled AI message
 */
async function sendScheduledAIMessage(userId, userData, messageType) {
  try {
    const { aiPersonaType, aiPersonaCustom, targetLanguage, aiPalConversationId, displayName } = userData;

    if (!targetLanguage || !aiPalConversationId) {
      console.log(`Skipping user ${userId}: missing required fields`);
      return;
    }

    // Check for recent messages to avoid spamming
    const recentMessages = await admin.firestore()
      .collection('conversations')
      .doc(aiPalConversationId)
      .collection('messages')
      .where('senderId', '==', 'ai-pal-system')
      .orderBy('timestamp', 'desc')
      .limit(1)
      .get();

    if (!recentMessages.empty) {
      const lastMessage = recentMessages.docs[0].data();
      const hoursSinceLastMessage = (Date.now() - lastMessage.timestamp.toMillis()) / (1000 * 60 * 60);

      // Don't send if last AI message was less than 6 hours ago
      if (hoursSinceLastMessage < 6) {
        console.log(`Skipping user ${userId}: last AI message was ${hoursSinceLastMessage.toFixed(1)} hours ago`);
        return;
      }
    }

    // Get conversation history
    const historySnapshot = await admin.firestore()
      .collection('conversations')
      .doc(aiPalConversationId)
      .collection('messages')
      .orderBy('timestamp', 'desc')
      .limit(5)
      .get();

    const history = historySnapshot.docs.map(doc => doc.data()).reverse();

    // Build persona system prompt
    const personaPrompts = {
      bro: 'You are a friendly bro helping your buddy learn a new language. Keep it casual, supportive, and fun.',
      sis: 'You are a supportive sister-figure helping your friend learn a new language. Be warm, encouraging, and understanding.',
      boyfriend: 'You are a caring boyfriend helping your partner learn a new language. Be sweet, romantic, and encouraging.',
      girlfriend: 'You are an affectionate girlfriend helping your partner learn a new language. Be playful, warm, and supportive.',
      teacher: 'You are a patient and knowledgeable language teacher. Be educational, clear, and encouraging.',
      ai: 'You are a helpful AI assistant for language learning. Be clear, informative, and supportive.',
      custom: aiPersonaCustom || 'You are a personalized AI companion helping someone learn a new language.',
    };

    const systemPrompt = personaPrompts[aiPersonaType] || personaPrompts.ai;

    // Build messages for OpenAI
    const messages = [
      { role: 'system', content: systemPrompt },
    ];

    const prompt = messageType === 'morning'
      ? `Generate a friendly conversation starter message for late morning (around 11 AM). Ask how they're doing or share something interesting to practice ${targetLanguage}. Keep it short (1-2 sentences). Use emojis. Respond ONLY in ${targetLanguage}.`
      : `Generate an evening message (around 7 PM) that teaches something new about ${targetLanguage}. Could be a useful phrase, cultural tip, or interesting vocabulary. Keep it engaging and not too formal (2-3 sentences max). Use emojis. Respond ONLY in ${targetLanguage}.`;

    // Add recent history context
    if (history.length > 0) {
      messages.push({ role: 'system', content: 'Previous conversation context:' });
      for (const msg of history.slice(-3)) {
        const role = msg.senderId === 'ai-pal-system' ? 'assistant' : 'user';
        messages.push({ role, content: msg.content });
      }
    }

    messages.push({ role: 'user', content: prompt });

    // Generate message
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: messages,
      temperature: 0.8,
      max_tokens: 150,
    });

    const aiMessage = completion.choices[0]?.message?.content || '';

    if (!aiMessage) {
      console.error(`Failed to generate message for user ${userId}`);
      return;
    }

    // Save message to Firestore
    const messageId = admin.firestore().collection('conversations').doc().id;
    const messageData = {
      id: messageId,
      conversationId: aiPalConversationId,
      senderId: 'ai-pal-system',
      senderName: getAIPalName(aiPersonaType),
      content: aiMessage,
      type: 'text',
      status: 'sent',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      readBy: [],
      deliveredToUsers: [],
    };

    await admin.firestore()
      .collection('conversations')
      .doc(aiPalConversationId)
      .collection('messages')
      .doc(messageId)
      .set(messageData);

    // Update conversation
    await admin.firestore()
      .collection('conversations')
      .doc(aiPalConversationId)
      .update({
        lastMessage: aiMessage,
        lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageSenderId: 'ai-pal-system',
        [`unreadCount.${userId}`]: admin.firestore.FieldValue.increment(1),
      });

    console.log(`✅ Sent ${messageType} message to user ${userId}`);

    // Send push notification
    const fcmToken = userData.fcmToken;
    if (fcmToken) {
      try {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: getAIPalName(aiPersonaType),
            body: aiMessage.length > 100 ? aiMessage.substring(0, 100) + '...' : aiMessage,
          },
          data: {
            conversationId: aiPalConversationId,
            messageId: messageId,
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
        });
        console.log(`✅ Sent push notification to user ${userId}`);
      } catch (error) {
        console.error(`❌ Failed to send push notification to user ${userId}:`, error);
      }
    }

  } catch (error) {
    console.error(`❌ Error sending scheduled message to user ${userId}:`, error);
  }
}

/**
 * Helper function to get AI pal display name based on persona
 */
function getAIPalName(personaType) {
  const names = {
    bro: 'Your AI Bro',
    sis: 'Your AI Sis',
    boyfriend: 'Your AI Boyfriend',
    girlfriend: 'Your AI Girlfriend',
    teacher: 'Your AI Teacher',
    ai: 'AI Pal',
    custom: 'AI Pal',
  };
  return names[personaType] || 'AI Pal';
}

/**
 * Generate TTS Audio - Convert text to speech using OpenAI gpt-4o-mini-tts
 * Returns base64-encoded MP3 audio data for client-side caching
 */
exports.generateTTS = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { text, language, voice } = data;

  if (!text) {
    throw new functions.https.HttpsError('invalid-argument', 'text is required');
  }

  if (!voice) {
    throw new functions.https.HttpsError('invalid-argument', 'voice is required');
  }

  // Validate voice
  const validVoices = ['alloy', 'ash', 'ballad', 'coral', 'echo', 'fable', 'onyx', 'nova', 'sage', 'shimmer', 'verse'];
  if (!validVoices.includes(voice)) {
    throw new functions.https.HttpsError('invalid-argument', `Invalid voice. Must be one of: ${validVoices.join(', ')}`);
  }

  try {
    console.log(`🎤 Generating TTS for text (${text.length} chars) in language ${language || 'unknown'} with voice ${voice}`);

    const response = await openai.audio.speech.create({
      model: 'gpt-4o-mini-tts',
      voice: voice,
      input: text,
      response_format: 'mp3',
    });

    // Convert response to buffer
    const buffer = Buffer.from(await response.arrayBuffer());

    // Convert to base64 for transmission
    const base64Audio = buffer.toString('base64');

    console.log(`✅ Generated TTS audio: ${buffer.length} bytes (${base64Audio.length} base64 chars)`);

    return {
      audioData: base64Audio,
      voice: voice,
    };
  } catch (error) {
    console.error('❌ Error generating TTS:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Transcribe Audio - Convert audio to text using OpenAI gpt-4o-mini-transcribe
 * Accepts base64-encoded audio data and returns transcription with detected language
 */
exports.transcribeAudio = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { audioData, messageId, conversationId, targetLanguage } = data;

  if (!audioData) {
    throw new functions.https.HttpsError('invalid-argument', 'audioData (base64) is required');
  }

  if (!messageId || !conversationId) {
    throw new functions.https.HttpsError('invalid-argument', 'messageId and conversationId are required');
  }

  try {
    console.log(`🎧 Transcribing audio for message ${messageId} (${audioData.length} base64 chars)`);

    // Convert base64 to buffer
    const buffer = Buffer.from(audioData, 'base64');

    // Transcribe using Whisper via OpenAI
    // toFile creates a File-like object that works in Node.js
    const transcription = await openai.audio.transcriptions.create({
      file: await toFile(buffer, 'audio.m4a'),
      model: 'whisper-1',
      response_format: 'verbose_json',
      language: undefined, // Auto-detect
    });

    const transcribedText = transcription.text;
    const detectedLanguage = transcription.language || 'en';

    console.log(`✅ Transcription complete: "${transcribedText.substring(0, 50)}..." (language: ${detectedLanguage})`);

    // Now analyze the transcription for word-by-word translations
    let wordTranslationsJSON = null;
    if (targetLanguage && targetLanguage !== detectedLanguage) {
      console.log(`🌍 Analyzing transcription for translations (${detectedLanguage} → ${targetLanguage})`);

      const analysisResponse = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: `You are a language learning assistant. Translate the following text from ${detectedLanguage} to ${targetLanguage} and provide word-by-word translations with parts of speech.

Return a JSON object with this structure:
{
  "translatedText": "full translation",
  "wordTranslations": [
    {
      "originalWord": "word",
      "translation": "translation",
      "partOfSpeech": "noun/verb/adj/etc",
      "startIndex": 0,
      "endIndex": 4,
      "context": "brief usage context"
    }
  ]
}`
          },
          {
            role: 'user',
            content: transcribedText
          }
        ],
        response_format: { type: 'json_object' }
      });

      const analysis = JSON.parse(analysisResponse.choices[0].message.content);
      wordTranslationsJSON = JSON.stringify(analysis.wordTranslations);

      console.log(`✅ Analysis complete with ${analysis.wordTranslations.length} word translations`);

      // Update Firestore with transcription and translations
      await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          audioTranscription: transcribedText,
          audioTranscriptionLanguage: detectedLanguage,
          audioTranscriptionJSON: wordTranslationsJSON,
          translatedText: analysis.translatedText,
          detectedLanguage: detectedLanguage,
          isTranscriptionReady: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    } else {
      // No translation needed, just update with transcription
      await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          audioTranscription: transcribedText,
          audioTranscriptionLanguage: detectedLanguage,
          isTranscriptionReady: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }

    return {
      transcription: transcribedText,
      detectedLanguage: detectedLanguage,
      wordTranslationsJSON: wordTranslationsJSON,
    };
  } catch (error) {
    console.error('❌ Error transcribing audio:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
