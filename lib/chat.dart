import 'dart:collection';

import 'package:characters/characters.dart';
import 'package:neurobrock2/api.dart';
import 'package:neurobrock2/constants.dart';

class History {
  static const maxSize = 50;

  final Queue<Message> messages = Queue();

  @override
  String toString() => messages.toSet().fold(
      basePrompt,
      (previousValue, element) => '$previousValue${switch (element.role) {
            MessageRoles.user => 'Запроc: ${element.content}',
            _ => 'Ответ: ${element.content}'
          }}\n');

  void _add(Message m) {
    var m_ = m;
    if (m.content.length > Message.maxLength) {
      m_ = Message(
          role: m.role,
          content: m.content.characters.take(Message.maxLength).string);
    }

    if (messages.length > maxSize) {
      messages.removeFirst();
    }

    messages.add(m_);
  }

  void store(String content) {
    final m = Message(role: MessageRoles.user, content: content);
    _add(m);
  }

  Future<void> generate(String input) async {
    final request = Message(role: MessageRoles.user, content: input);
    _add(request);

    final prompt = '${toString()}Ответ: ';
    final generated = await generatePhrase(prompt);
    final response = Message(role: MessageRoles.bot, content: generated);
    _add(response);
  }

  Message? get last => messages.lastOrNull;
}

enum MessageRoles { user, bot }

class Message {
  static const maxLength = 200;

  final MessageRoles role;
  final String content;

  const Message({required this.role, required this.content});

  @override
  operator ==(Object other) =>
      other is Message && other.content == content && other.role == role;

  @override
  int get hashCode => Object.hashAll([role, content]);
}
