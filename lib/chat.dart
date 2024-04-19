import 'dart:collection';

import 'package:characters/characters.dart';
import 'package:neurobrock/api.dart';
import 'package:neurobrock/constants.dart';

class History {
  static const maxSize = 50;

  final Queue<Message> messages = Queue();

  @override
  String toString() => messages.toSet().fold(
      basePrompt,
      (previousValue, element) => '$previousValue${switch (element.role) {
            MessageRoles.user => '${element.author}: ${element.content}',
            _ => '$selfName: ${element.content}'
          }}\n');

  void _add(Message m) {
    var m_ = m;
    if (m.content.length > Message.maxLength) {
      m_ = Message(
          role: m.role,
          author: m.author,
          content: m.content.characters.take(Message.maxLength).string);
    }

    if (messages.length > maxSize) {
      messages.removeFirst();
    }

    messages.add(m_);
  }

  void store({required String content, required String author}) {
    final m =
        Message(role: MessageRoles.user, author: author, content: content);
    _add(m);
  }

  Future<void> generate(
      {required String content, required String author}) async {
    final request =
        Message(role: MessageRoles.user, author: author, content: content);
    _add(request);

    final prompt = '${toString()}Ответ: ';
    final generated = await generatePhrase(prompt);
    final response =
        Message(role: MessageRoles.bot, author: author, content: generated);
    _add(response);
  }

  Message? get last => messages.lastOrNull;
}

enum MessageRoles { user, bot }

class Message {
  static const maxLength = 200;

  final MessageRoles role;
  final String author;
  final String content;

  const Message(
      {required this.role, required this.content, required this.author});

  @override
  operator ==(Object other) =>
      other is Message && other.content == content && other.role == role;

  @override
  int get hashCode => Object.hashAll([role, content]);
}
