import 'dart:math';

import 'package:neurobrock/daemon.dart';
import 'package:neurobrock/secret/credentials.dart';
import 'package:nyxx/nyxx.dart';

const channelToWatch = '912041808446488647';

void main(List<String> arguments) async {
  const token = botToken;

  final client = await Nyxx.connectGateway(
    token,
    GatewayIntents(GatewayIntents.allUnprivileged.value +
        GatewayIntents.messageContent.value),
    options: GatewayClientOptions(plugins: [logging, cliIntegration]),
  );
  client.onReady.listen((_) =>
      ChannelDaemon(client: client, channelId: channelToWatch).observe());
}

String formatAuthor(MessageAuthor author) {
  String? displayName;
  if (author is User) {
    displayName = author.globalName ?? '';
  }
  final username = author.username;

  if (displayName == null) return username;
  return '$displayName ($username)';
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
