import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetupStatus { pending, accepted, rejected, cancelled }

class MeetupModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? senderName;
  final String? receiverName;
  final String? senderPhoto;
  final String? receiverPhoto;
  final DateTime dateTime;
  final String? location;
  final String? rate;       // host's stated rate shown at meetup time
  final MeetupStatus status;
  final DateTime timestamp;
  final String? note;       // host's own meetup notes (from their profile)
  final String? senderNote; // personal message from the requester

  MeetupModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.senderName,
    this.receiverName,
    this.senderPhoto,
    this.receiverPhoto,
    required this.dateTime,
    this.location,
    this.rate,
    this.status = MeetupStatus.pending,
    required this.timestamp,
    this.note,
    this.senderNote,
  });

  factory MeetupModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeetupModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      senderName: data['senderName'],
      receiverName: data['receiverName'],
      senderPhoto: data['senderPhoto'],
      receiverPhoto: data['receiverPhoto'],
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      location: data['location'],
      rate: data['rate'],
      status: _parseStatus(data['status'] ?? 'pending'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'],
      senderNote: data['senderNote'],
    );
  }

  static MeetupStatus _parseStatus(String status) {
    switch (status) {
      case 'accepted':
        return MeetupStatus.accepted;
      case 'rejected':
        return MeetupStatus.rejected;
      case 'cancelled':
        return MeetupStatus.cancelled;
      case 'pending':
      default:
        return MeetupStatus.pending;
    }
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'receiverId': receiverId,
        'senderName': senderName,
        'receiverName': receiverName,
        'senderPhoto': senderPhoto,
        'receiverPhoto': receiverPhoto,
        'dateTime': Timestamp.fromDate(dateTime),
        'location': location,
        'rate': rate,
        'status': status.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'note': note,
        'senderNote': senderNote,
      };
}
