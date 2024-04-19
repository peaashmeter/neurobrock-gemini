import 'dart:math';

import 'package:neurobrock/chat.dart' hide Message;
import 'package:neurobrock/constants.dart';
import 'package:neurobrock/secret/credentials.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

//Here are the words to trigger the bot in chat
const triggers = [selfName, 'бравл', 'brawl', 'геншин', 'чжун ли'];

void main(List<String> arguments) async {
  const token = botToken;

  final history = History();

  final invokeCommand = ChatCommand("neurobrock", "Позвать нейроброка",
      (ChatContext context, [String? query]) async {
    try {
      await context.respond(MessageBuilder(content: 'Нейроброк думает...'),
          level: ResponseLevel.hint);

      await history.generate(
          author: formatAuthor(context.user), content: query ?? selfName);
      final phrase = history.last?.content.toString();
      await context.respond(MessageBuilder(content: phrase));
    } catch (e) {
      print(e);
    }
  });

  final commands = CommandsPlugin(
      prefix: mentionOr(
    (_) => '/',
  ));
  commands.addCommand(invokeCommand);

  final client = await Nyxx.connectGateway(
    token, // Replace this with your bot's token
    GatewayIntents(GatewayIntents.allUnprivileged.value +
        GatewayIntents.messageContent.value),
    options: GatewayClientOptions(plugins: [logging, cliIntegration, commands]),
  );

  final bot = await client.users.fetchCurrentUser();

  client.onReady.listen((ReadyEvent e) {
    print("Ready!");
  });

  //Listen to all incoming messages
  client.onMessageCreate.listen((MessageCreateEvent e) async {
    try {
      //This is needed to prevent an endless loop of bots replying to each other
      //(if you have more than one)
      if ((e.message.author is! User) || (e.message.author as User).isBot) {
        return;
      }

      if (checkIfBotTriggered(bot, e.message, triggers)) {
        await history.generate(
            author: formatAuthor(e.message.author), content: e.message.content);
        final phrase = history.last?.content.toString();

        final messageBuilder =
            MessageBuilder(content: phrase, replyId: e.message.id);

        //Logging
        print('Боту написали: ${e.message.content}\n');
        print('Бот ответил: $phrase \n\n');

        e.message.channel.sendMessage(messageBuilder);
      }
      //the bot didn't trigger, store the message to feed context
      else {
        history.store(
            author: formatAuthor(e.message.author), content: e.message.content);
      }
    } catch (e) {
      print(e);
    }
  });
}

String formatAuthor(MessageAuthor author) {
  String? displayName;
  if (author is User) {
    displayName = author.globalName ?? '';
  }
  final username = author.username;

  if (displayName == null) return '($username)';
  return '($username, $displayName)';
}

bool checkIfBotTriggered(User bot, Message message, List<String> triggers) {
  if (Random().nextInt(100) == 0) return true;

  if (message.referencedMessage?.author.id == bot.id) {
    return true;
  }

  if (message.mentions.contains(bot)) {
    return true;
  }

  for (var t in triggers) {
    if (message.content.toLowerCase().contains(t)) {
      return true;
    }
  }
  return false;
}
