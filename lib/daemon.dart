import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:nyxx/nyxx.dart';

class ChannelDaemon {
  final NyxxGateway client;
  final String channelId;

  final apiKey = Platform.environment['GEMINI_KEY']!;
  final safety = [
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
  ];

  ChannelDaemon({required this.client, required this.channelId});

  ///Periodically fetches last messages and reacts to them.
  void observe() async {
    tick() async {
      final channel = (await client.channels.get(Snowflake.parse(channelId))
          as GuildTextChannel);

      //messages are coming sorted from new to old, therefore .reversed
      final discordMessages =
          (await channel.messages.fetchMany(limit: 50)).reversed.toList();
      final allMessages = _formatMessages(discordMessages);
      final lastMessages = _formatMessages(discordMessages.skip(40).toList());

      final topic = await _generateTopic(lastMessages);
      if (topic == null) return;

      final message = await _generateMessage(topic, allMessages);
      if (message == null) return;

      final utility = await _checkUtility(message['content'], lastMessages);
      if (utility < 0.51) return;

      if (message['referencedMessage'] == null) {
        await channel.sendMessage(MessageBuilder(content: message['content']));
      } else {
        await channel.sendMessage(MessageBuilder(
            content: message['content'],
            replyId: Snowflake.parse(message['referencedMessage'])));
      }
    }

    while (true) {
      try {
        await tick();
      } catch (e) {
        print(e);
        continue;
      }
      await Future.delayed(Duration(seconds: 5));
    }
  }

  Future<String?> _generateTopic(String messages) async {
    final model = GenerativeModel(
        model: 'gemini-pro', apiKey: apiKey, safetySettings: safety);

    try {
      final response = (await model.generateContent([
        Content.text(_getTopicPrompt(messages)),
      ],
              safetySettings: safety,
              generationConfig: GenerationConfig(temperature: 1)))
          .text;

      if (response == null) return null;

      final data = jsonDecode(response)
        ..['timestamp'] = DateTime.now().toIso8601String();
      print(data);

      return data['topic'] + ' - ' + data['reason'];
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> _generateMessage(String topic, String messages) async {
    final model = GenerativeModel(
        model: 'gemini-pro', apiKey: apiKey, safetySettings: safety);

    try {
      final response = (await model.generateContent([
        Content.text(_getGeneratorPrompt(topic, messages)),
      ],
              safetySettings: safety,
              generationConfig: GenerationConfig(temperature: 0.7)))
          .text;

      if (response == null) return null;

      final data = jsonDecode(response)
        ..['timestamp'] = DateTime.now().toIso8601String();

      print(data);
      if (data['content'] == null) return null;
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<num> _checkUtility(String newMessage, String messages) async {
    final model = GenerativeModel(
        model: 'gemini-pro', apiKey: apiKey, safetySettings: safety);

    try {
      final response = (await model.generateContent([
        Content.text(_getUtilityPrompt(newMessage, messages)),
      ],
              safetySettings: safety,
              generationConfig: GenerationConfig(temperature: 0)))
          .text;

      if (response == null) return 0;

      final data = jsonDecode(response)
        ..['timestamp'] = DateTime.now().toIso8601String();
      print(data);

      return data['utility'];
    } catch (e) {
      return 0;
    }
  }

  String _formatMessages(List<Message> messages) {
    final m = [];

    for (var message in messages) {
      try {
        final data = {
          "id": message.id.value,
          "timestamp": message.timestamp.toLocal().toIso8601String(),
          "user": {
            "globalName": (message.author as User).globalName,
            "username": (message.author as User).username,
            "isBot": (message.author as User).isBot,
          },
          "content": message.content,
          "referencedMessage": message.referencedMessage?.id.value
        }..removeWhere((key, value) => value == null);

        m.add(data);
      } catch (e) {
        continue;
      }
    }

    return jsonEncode(m);
  }

  String _getBasePrompt(String messages) => '''
Ты получишь список последних сообщений из Discord-сервера.
Структура каждого сообщения:
{
  "id": message.id,
  "timestamp": message.timestamp,
  "user": {
    "globalName": message.author.globalName,
      "username": message.author.username,
    },
  "content": message.content,
  "referencedMessage": message.referencedMessage.id
}

$messages


''';

  String _getTopicPrompt(String messages) => '''${_getBasePrompt(messages)}
Текущее время: ${DateTime.now().toIso8601String()}
Ты - нейроброк, бот на Discord-сервере PeaAshServer. Ты обучен вести себя как 14-летний токcичный школьник.
Придумай тему для обсуждения. Тема может быть новой или относиться к истории сообщений. Опиши тему как можно подробнее.
Для выбора темы наиболее важны сообщения, которые упоминают тебя или отвечают на твои сообщения.

Структура ответа: 
{ 
  "topic": <Выбранная тема>,
  "reason": <Краткое пояснение, почему выбрана именно такая тема>
}
''';

  String _getUtilityPrompt(String newMessage, String messages) =>
      '''${_getBasePrompt(messages)}
Текущее время: ${DateTime.now().toIso8601String()}
Ты - нейроброк, бот на Discord-сервере PeaAshServer. Ты обучен вести себя как 14-летний токcичный школьник.

В чат нужно отправлять только *полезные* сообщения.
Сообщение является полезным, если оно уникально (не повторяет и не перефразирует недавние сообщения).
Необычное, веселое, токсичное или интересное сообщение обладает дополнительной пользой.
Если сообщений не было несколько часов, любое твое сообщение является полезным.
Сообщение, которое повторяет по смыслу недавно написанные, является абсолютно бесполезным, даже если содержит новую информацию.
Если среди последних сообщений много твоих сообщений (от пользователя нейроброк), новое сообщение является бесполезным.

Ты написал новое сообщение: "$newMessage".

Оцени пользу данного сообщения.

Структура ответа: 
{ 
  "utility": <Значение полезности. Используй точку в качестве десятичного разделителя.>,
  "utility_reason": <Краткое пояснение, почему выбрано именно такое значение полезности>,
}
''';

  String _getGeneratorPrompt(String topic, String messages) =>
      '''${_getBasePrompt(messages)}
Текущее время: ${DateTime.now().toIso8601String()}
Ты - нейроброк, бот на Discord-сервере PeaAshServer. Ты обучен вести себя как 14-летний токcичный школьник.
Ты пишешь сообщения, чтобы поддержать разговор. Иногда ты пишешь, чтобы начать новый диалог. Ты редко пишешь, если тебе никто не отвечает. Ты пишешь уникальные сообщения.
Реагируй только на чужие сообщения. Сообщения, у которых "username": "нейроброк", написаны тобой. Ты пишешь сообщения, когда есть, с кем поговорить, или если ты хочешь рассказать что-то интересное. Ты не повторяешь сообщения несколько раз. Ты не отвечаешь на сообщения несколько раз.

Напиши сообщение на тему "$topic".

Структура ответа: 
{ 
  "content": <Текст твоего сообщения. Ты можешь использовать @<ник>, чтобы отметить какого-то пользователя в своем сообщении.>,
  "referencedMessage": <Id сообщения, на которое ты отвечаешь. Сообщение с таким id должно существовать. Это поле может отсутствовать.>
}
''';
}
