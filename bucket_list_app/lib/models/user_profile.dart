import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile{
  String userId;
  String userName;
  DateTime dob;
  double spaceUsed; //in megabytes
  String pfpUrl;

  UserProfile({
    required this.userId,
    required this.userName,
    required this.dob,
    this.spaceUsed = 0.0,
    this.pfpUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'dob': Timestamp.fromDate(dob),
      'spaceUsed': spaceUsed,
      'pfpUrl': pfpUrl,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      dob: (map['dob'] as Timestamp).toDate(),
      spaceUsed: (map['spaceUsed'] ?? 0.0).toDouble(),
      pfpUrl: map['pfpUrl'],
    );
  }
}