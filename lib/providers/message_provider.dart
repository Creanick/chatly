import 'package:chatly/models/message.dart';
import 'package:chatly/models/profile.dart';
import 'package:chatly/providers/view_state_provider.dart';
import 'package:flutter/foundation.dart';

class MessageProvider extends ViewStateProvider {
  List<Message> _messagesList = [];
  List<Message> get messagesList => _messagesList;
  final Profile receiverProfile;
  MessageProvider({@required this.receiverProfile});

  void fetchExistingMessage() {
    startInitialLoader();
    stopExecuting();
  }

  void sendMessage({@required String senderId, @required String content}) {
    if (content == null || receiverProfile == null) return;
    final Message message = Message(
      mid: DateTime.now().toIso8601String(),
      content: content,
      senderId: senderId,
      receiverId: receiverProfile.pid,
    );
    _messagesList.insert(0, message);
    stopExecuting();
  }
}
