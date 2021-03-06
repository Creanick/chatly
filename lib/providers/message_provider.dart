import 'dart:async';
import 'package:chatly/helpers/failure.dart';
import 'package:chatly/helpers/view_response.dart';
import 'package:chatly/models/message.dart';
import 'package:chatly/models/profile.dart';
import 'package:chatly/providers/view_state_provider.dart';
import 'package:chatly/service/messages_service.dart';
import 'package:chatly/service_locator.dart';
import 'package:flutter/foundation.dart';

class MessageProvider extends ViewStateProvider {
  MessagesService _messagesService = locator<MessagesService>();
  List<Message> _messagesList = [];
  List<Message> get messagesList => _messagesList;
  final Profile senderProfile;
  final Profile receiverProfile;
  StreamSubscription<Message> latestMessageStreamSubscription;
  bool _isActive = false;
  List<Message> _seenableMessages = [];
  Map<String, StreamSubscription<Message>> _outgoingMessagesSubscriptions = {};

  void cancelAllOutgoingMessagesSubscription() {
    _outgoingMessagesSubscriptions.forEach((id, sub) {
      sub?.cancel();
    });
    _outgoingMessagesSubscriptions.clear();
  }

  Message findOutgoingMessage(String mid) {
    for (int i = 0; i < _messagesList.length; i++) {
      final message = _messagesList[i];
      if (isIncomingMessage(message)) return null;
      if (message.mid == mid) return message;
    }
    return null;
  }

  List<Message> findNonSeenOutgoingMessages() {
    final List<Message> messages = [];
    for (int i = 0; i < _messagesList.length; i++) {
      final message = _messagesList[i];
      if (isIncomingMessage(message) ||
          message.messageStatus == MessageStatus.seen) return messages;
      messages.add(message);
    }
    return messages;
  }

  void removeOutgoingMessageSubscription(Message message) {
    if (_outgoingMessagesSubscriptions.isEmpty) return;
    final StreamSubscription<Message> removedMessageSubscription =
        _outgoingMessagesSubscriptions.remove(message.mid);
    removedMessageSubscription?.cancel();
  }

  handleOutgoingMessageStatus(Message outgoingMessage) {
    if (outgoingMessage == null) {
      removeOutgoingMessageSubscription(outgoingMessage);
    }
    //update the status of message
    final Message getMatchedMessage = findOutgoingMessage(outgoingMessage.mid);
    if (getMatchedMessage == null) {
      removeOutgoingMessageSubscription(outgoingMessage);
    }
    getMatchedMessage.updateStatus(outgoingMessage.messageStatus);
    stopExecuting();
    if (outgoingMessage.messageStatus == MessageStatus.seen) {
      findNonSeenOutgoingMessages()
          .forEach((message) => message.updateStatus(MessageStatus.seen));
      stopExecuting();
      removeOutgoingMessageSubscription(outgoingMessage);
    }
  }

  void addOutgoingMessageSubscription(Message message) {
    if (isIncomingMessage(message) ||
        message.messageStatus == MessageStatus.seen) return;
    final Stream<Message> outgoingMessageStream =
        _messagesService.getMessageStream(message);
    _outgoingMessagesSubscriptions[message.mid] =
        outgoingMessageStream.listen(handleOutgoingMessageStatus);
  }

  void seenAllSeenableMessages() {
    for (int i = 0; i < _seenableMessages.length; i++) {
      final seenableMessage = _seenableMessages.removeAt(i);
      if (seenableMessage == null ||
          seenableMessage.messageStatus == MessageStatus.seen) continue;
      seenableMessage.updateStatus(MessageStatus.seen);
      _messagesService.changeMessageStatus(message: seenableMessage);
      stopExecuting();
    }
  }

  activate() {
    _isActive = true;
    if (_seenableMessages.isNotEmpty) {
      seenAllSeenableMessages();
    }
  }

  deactivate() {
    _isActive = false;
  }

  void cancelMessageSubscription() {
    if (latestMessageStreamSubscription != null) {
      latestMessageStreamSubscription.cancel();
      latestMessageStreamSubscription = null;
    }
  }

  bool isIncomingMessage(Message message) {
    return message.senderId == receiverProfile.pid;
  }

  bool get isExecutable =>
      _messagesService != null &&
      senderProfile != null &&
      receiverProfile != null;
  MessageProvider(
      {@required this.senderProfile, @required this.receiverProfile}) {
    if (!isExecutable) return;
    latestMessageStreamSubscription = _messagesService
        .getLatestMessage(
            senderId: senderProfile.pid, receiverId: receiverProfile.pid)
        .listen(handleLatestMessage);
  }

  void handleIncomingMessageStatusChange(Message message) {
    if (!isIncomingMessage(message) ||
        message.messageStatus == MessageStatus.seen) return;
    if (message.messageStatus == MessageStatus.sent) {
      if (_isActive) {
        message.updateStatus(MessageStatus.seen);
      } else {
        message.updateStatus(MessageStatus.delivered);
      }
      _messagesService.changeMessageStatus(message: message);
    }
    if (message.messageStatus == MessageStatus.delivered) {
      _seenableMessages.add(message);
    }
  }

  void handleLatestMessage(Message latestMessage) {
    if (latestMessage == null) return;
    if (isIncomingMessage(latestMessage)) {
      _messagesList.insert(0, latestMessage);
      handleIncomingMessageStatusChange(latestMessage);
      stopExecuting();
    }
  }

  Future<void> fetchExistingMessage({bool byPass = false}) async {
    if (!isExecutable) {
      throw Failure.internal(
          "Message provider is not executable on fetching existing message");
    }
    if (byPass) return stopExecuting();
    try {
      startInitialLoader();
      _messagesList = await _messagesService.fetchAllMessage(
          senderId: senderProfile.pid, receiverId: receiverProfile.pid);
      for (int i = 0; i < _messagesList.length; i++) {
        final message = _messagesList[i];
        if (message == null) continue;
        handleIncomingMessageStatusChange(message);
      }
      findNonSeenOutgoingMessages().forEach((message) {
        if (message == null) return;
        addOutgoingMessageSubscription(message);
      });
      stopExecuting();
    } on Failure catch (failure) {
      _messagesList = [];
      stopExecuting();
      print(failure);
    }
  }

  Future<ViewResponse<void>> sendMessage({@required String content}) async {
    if (!isExecutable || content == null)
      return FailureViewResponse(Failure.internal("Some dependencies missing"));
    final Message message = Message(
      mid: _messagesService.getNewMessageId(),
      content: content,
      senderId: senderProfile.pid,
      receiverId: receiverProfile.pid,
    );
    try {
      _messagesList.insert(0, message);
      addOutgoingMessageSubscription(message);
      startExecuting();
      await _messagesService.sendMessageToServer(message);
      stopExecuting();
      return ViewResponse("Sending message successful");
    } on Failure catch (failure) {
      _messagesList.removeAt(0);
      stopExecuting();
      return FailureViewResponse(failure);
    }
  }

  @override
  void dispose() {
    cancelMessageSubscription();
    cancelAllOutgoingMessagesSubscription();
    super.dispose();
  }
}
