import 'package:chatly/helpers/timestamp_converter.dart';
import 'package:flutter/foundation.dart';

class Profile {
  final String pid;
  final DateTime createdDate;
  final String number;
  DateTime _updatedDate;
  final List<String> activeChatProfileIds;
  //nullable properties
  String _name;
  String _avatarUrl;
  DateTime _lastSeen;

  //getters
  String get name => _name;
  String get avatarUrl => _avatarUrl;
  DateTime get updatedDate => _updatedDate;
  DateTime get lastSeen => _lastSeen;

  Profile(
      {@required this.pid,
      @required this.number,
      String name,
      String avatarUrl,
      DateTime lastSeen,
      List<String> activeChatProfileIds})
      : _name = name,
        _avatarUrl = avatarUrl,
        _lastSeen = lastSeen,
        this.activeChatProfileIds = activeChatProfileIds ?? [],
        createdDate = DateTime.now(),
        _updatedDate = DateTime.now();
  Profile.fromMap(Map<String, dynamic> profileMap)
      : pid = profileMap['pid'],
        _name = profileMap['name'],
        number = profileMap['number'],
        _avatarUrl = profileMap['avatarUrl'],
        _lastSeen = timestampToDateTime(profileMap['lastSeen']),
        activeChatProfileIds = profileMap['activeChatProfileIds'] ?? [],
        createdDate = timestampToDateTime(profileMap['createdDate']),
        _updatedDate = timestampToDateTime(profileMap['updatedDate']);
  Map<String, dynamic> toMap() => ({
        "pid": pid,
        "name": _name,
        "number": number,
        "avatarUrl": _avatarUrl,
        "lastSeen": _lastSeen,
        "activeChatProfileIds": activeChatProfileIds ?? [],
        "createdDate": createdDate,
        "updatedDate": _updatedDate
      });
  void addActiveChatUser(String userId) {
    activeChatProfileIds.add(userId);
    _updatedDate = DateTime.now();
  }

  void removeActiveChatUser(int index) {
    activeChatProfileIds.removeAt(index);
    _updatedDate = DateTime.now();
  }

  void update(
      {String name,
      String avatarUrl,
      DateTime lastSeen,
      DateTime updatedDate}) {
    _name = name ?? _name;
    _avatarUrl = avatarUrl ?? _avatarUrl;
    _lastSeen = lastSeen ?? _lastSeen;
    _updatedDate = updatedDate ?? DateTime.now();
  }
}
