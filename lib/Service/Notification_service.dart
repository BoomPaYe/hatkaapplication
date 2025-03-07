import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() => _instance;
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  
  NotificationService._internal();
  
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_isInitialized) {
      return;
    }
    
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final InitializationSettings initializationSettings = InitializationSettings(
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
    
    _isInitialized = true;
  }
  
  Future<void> _saveFcmToken(String token) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'fcmToken': token,
        }, SetOptions(merge: true)); // Using merge to avoid overwriting other fields
        
        print('FCM token saved successfully for user: ${currentUser.uid}');
      } catch (e) {
        print('Error saving FCM token: $e');
      }
    } else {
      print('Cannot save FCM token: No user is logged in');
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
          iOS: const DarwinNotificationDetails(),
        ),
        payload: json.encode(message.data),
      );
    }
  }
  
  // Method to show local notification
  Future<void> showLocalNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  try {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'job_application_channel',
      'Job Applications',
      channelDescription: 'Notifications for job applications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
      payload: payload,
    );
    
    print('Local notification shown successfully');
  } catch (e) {
    print('Error showing local notification: $e');
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
      
      // Save notification to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Note: For actual FCM sending, you would need a cloud function or server
      print('Notification saved to database for user $userId');
      
      // In a real implementation, you would call your server or cloud function here
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}