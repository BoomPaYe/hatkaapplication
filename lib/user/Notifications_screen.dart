import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Initialize FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Add this class to handle notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

    // Request permission for Firebase Messaging
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Handle incoming messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });

    // Get FCM token
    String? token = await messaging.getToken();
    print('FCM Token: $token');

    // Save token to Firestore for the current user
    if (token != null) {
      _saveFcmToken(token);
    }

    // Listen for token refreshes
    messaging.onTokenRefresh.listen((newToken) {
      _saveFcmToken(newToken);
    });
  }

  Future<void> _saveFcmToken(String token) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'fcmToken': token,
      });
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'job_application_channel',
            'Job Applications',
            channelDescription: 'Notifications for job applications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: json.encode(message.data),
      );
    }
  }

  // Method to send a notification to a specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get the user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print('User document not found');
        return;
      }

      final String? fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken == null || fcmToken.isEmpty) {
        print('FCM token not found for user');
        return;
      }

      // Prepare notification data
      final notification = {
        'title': title,
        'body': body,
        'data': data ?? {},
        'to': fcmToken,
      };

      // Save notification to Firestore
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Note: For actual FCM sending, you would need a cloud function or server
      // This is just simulating the process on the client for demo purposes
      print('Notification sent to user $userId: $notification');

      // In a real implementation, you would call your server or cloud function here
      // For testing, we'll just log the notification
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}

// Add this class for a notification screen to show all notifications
class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Notifications')),
        body: Center(child: Text('Please log in to view notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        actions: [
          IconButton(
            icon: Icon(Icons.check_circle_outline),
            onPressed: () => _markAllAsRead(currentUser.uid),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No notifications yet'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              final data = notification.data() as Map<String, dynamic>;
              final bool isRead = data['isRead'] ?? false;
              final DateTime createdAt =
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getNotificationColor(data['type']),
                  child: Icon(_getNotificationIcon(data['type']),
                      color: Colors.white),
                ),
                title: Text(
                  data['title'] ?? 'Notification',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['body'] ?? ''),
                    SizedBox(height: 4),
                    Text(
                      _formatTimestamp(createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                tileColor: isRead ? null : Colors.blue[50],
                onTap: () {
                  _markAsRead(notification.id, currentUser.uid);
                  _handleNotificationTap(data);
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'new_application':
        return Icons.person;
      case 'application_submitted':
        return Icons.check_circle;
      case 'application_status_change':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'new_application':
        return Colors.blue;
      case 'application_submitted':
        return Colors.green;
      case 'application_status_change':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _markAsRead(String notificationId, String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> _markAllAsRead(String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    final notifications = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
    setState(() {});
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final String? type = data['type'];

    if (type == 'new_application') {
      // Navigate to application details screen
      // Navigator.of(context).push(MaterialPageRoute(
      //   builder: (context) => ApplicationDetailsScreen(
      //     applicationId: data['applicationId'],
      //   ),
      // ));
    } else if (type == 'application_submitted') {
      // Navigate to my applications screen
      Navigator.of(context).pushNamed('/my-applications');
    } else if (type == 'application_status_change') {
      // Navigate to application details
      // Navigator.of(context).push(MaterialPageRoute(
      //   builder: (context) => ApplicationDetailsScreen(
      //     applicationId: data['applicationId'],
      //   ),
      // ));
    }
  }
}
