// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../core/constants/firestore_collections.dart';
// import '../models/notification_model.dart';
// import 'firestore_repository.dart';

// class NotificationsRepository extends FirestoreRepository<NotificationModel> {
//   NotificationsRepository({super.db}) : super(FirestoreCollections.notifications);

//   @override
//   NotificationModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
//       NotificationModel.fromDoc(doc);

//   @override
//   Map<String, dynamic> toMap(NotificationModel item) => item.toMap();

//   Future<void> push({
//     required String title,
//     required String body,
//     required String type,
//     String branch = 'All Branches',
//   }) {
//     return add(NotificationModel(
//       id: '',
//       title: title,
//       body: body,
//       type: type,
//       branch: branch,
//       read: false,
//       createdAt: DateTime.now(),
//     ));
//   }

//   Future<void> markRead(String id) => collection.doc(id).update({'read': true});
// }