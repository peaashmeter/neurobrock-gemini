import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:nyxx/nyxx.dart';

///Watches a channel in the guild to emulate 'response willingness' value.
class ChannelDaemon {
  static const _basePrompt = '''
Ты - нейроброк, обычный участник дискорд-сервера PeaAshServer. Ты пишешь сообщения, чтобы поддержать разговор. Иногда ты пишешь, чтобы начать новый диалог. Ты редко пишешь, если тебе никто не отвечает. Ты пишешь уникальные сообщения.

Ты получишь список последних сообщений из чата.
Структура каждого сообщения:
{
  "id": message.id,
  "timestamp": message.timestamp,
  "user": {
    "globalName": message.author.globalName,
      "username": message.author.username,
      "isBot": message.author.isBot,
    },
  "content": message.content,
  "referencedMessage": message.referencedMessage.id
}

''';

  final _generatorPrompt = '''$_basePrompt
Текущее время: ${DateTime.now().toIso8601String()}
Реагируй только на чужие сообщения. Сообщения, у которых "username": "нейроброк", написаны тобой. Ты пишешь сообщения, когда есть, с кем поговорить, или если ты хочешь рассказать что-то интересное.
Оцени свое желание написать новое сообщение по шкале от 0 до 1, где 0 - отсутствие желания, а 1 - максимальное желание. 

Структура ответа: 
{
  "value": <Значение. Используй точку в качестве десятичного разделителя>,
  "reason": <Краткое пояснение, почему выбрано именно такое значение>,
  "content": <Текст твоего ответа. Ты можешь использовать @<ник>, чтобы отметить какого-то пользователя в своем сообщении.>,
  "referencedMessage": <Id сообщения, на которое ты отвечаешь. Это поле может отсутствовать.>
}
''';

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
    generate() async {
      final channel = (await client.channels.get(Snowflake.parse(channelId))
          as GuildTextChannel);
      final messages =
          _formatMessages(await channel.messages.fetchMany(limit: 50));

      print('\n$messages');

      await _generateMessage(messages, channel);
    }

    while (true) {
      await generate();
      await Future.delayed(Duration(seconds: 5));
    }
  }

  Future<void> _generateMessage(
      String messages, GuildTextChannel channel) async {
    final model = GenerativeModel(
        model: 'gemini-pro', apiKey: apiKey, safetySettings: safety);

    try {
      final response = (await model.generateContent([
        Content.text(_generatorPrompt + messages),
      ],
              safetySettings: safety,
              generationConfig: GenerationConfig(temperature: 0.7)))
          .text;

      if (response == null) return;

      final data = jsonDecode(response)
        ..['timestamp'] = DateTime.now().toIso8601String();
      print(data);

      if (data['message'] == null || data['value'] < 0.5) return;

      if (data['referencedMessage'] == null) {
        await channel.sendMessage(MessageBuilder(content: data['content']));
      } else {
        await channel.sendMessage(MessageBuilder(
            content: data['content'],
            replyId: Snowflake.parse(data['referencedMessage'])));
      }
    } catch (e) {
      return;
    }
  }

  String _formatMessages(List<Message> messages) {
    final m = [];

    //messages are coming sorted from new to old, therefore .reversed
    for (var message in messages.reversed) {
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
}
