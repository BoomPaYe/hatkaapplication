import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationCompanyScreen extends StatefulWidget {
  const NotificationCompanyScreen({Key? key}) : super(key: key);

  @override
  _NotificationCompanyScreenState createState() => _NotificationCompanyScreenState();
}

class _NotificationCompanyScreenState extends State<NotificationCompanyScreen> {
  bool _isLoading = false;
  List<String> _userPostIds = [];
  final int _batchSize = 10; // Firestore whereIn limit
  int _currentBatchIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _fetchUserPostIds();
  }
  
  Future<void> _fetchUserPostIds() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userPostsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: currentUser.uid)
          .get();
      
      setState(() {
        _userPostIds = userPostsSnapshot.docs.map((doc) => doc.id).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  List<List<String>> _getBatches(List<String> items, int batchSize) {
    List<List<String>> batches = [];
    for (var i = 0; i < items.length; i += batchSize) {
      batches.add(
        items.sublist(
          i, 
          i + batchSize < items.length ? i + batchSize : items.length
        )
      );
    }
    return batches;
  }
  
  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to view notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => _markAllAsRead(),
            tooltip: 'Mark all as read',
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationsList(User currentUser) {
    if (_userPostIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    // Split post IDs into batches to handle Firestore's 'whereIn' limitation
    final batches = _getBatches(_userPostIds, _batchSize);
    
    if (batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('postId', whereIn: batches[_currentBatchIndex])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No notifications yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _isLoading = true;
            });
            await _fetchUserPostIds();
            setState(() {
              _isLoading = false;
            });
          },
          child: ListView.separated(
            itemCount: snapshot.data!.docs.length + (batches.length > 1 ? 1 : 0),
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              // Add a "Load More" button if there are more batches
              if (batches.length > 1 && index == snapshot.data!.docs.length) {
                return ListTile(
                  title: const Text('Load more notifications'),
                  trailing: const Icon(Icons.arrow_downward),
                  onTap: () {
                    setState(() {
                      _currentBatchIndex = (_currentBatchIndex + 1) % batches.length;
                    });
                  },
                );
              }
              
              if (index >= snapshot.data!.docs.length) {
                return const SizedBox.shrink();
              }
              
              final notification = snapshot.data!.docs[index];
              final data = notification.data() as Map<String, dynamic>;
              final bool isRead = data['isRead'] ?? false;
              final DateTime createdAt = 
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  
              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _deleteNotification(notification.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notification deleted'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          // Implement undo functionality if needed
                        },
                      ),
                    ),
                  );
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty
                        ? Colors.transparent
                        : _getCategoryColor(data['category'] ?? 'application'),
                    backgroundImage: data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty
                        ? NetworkImage(data['profileImageUrl'])
                        : null,
                    child: data['profileImageUrl'] == null || data['profileImageUrl'].toString().isEmpty
                        ? Icon(_getCategoryIcon(data['category'] ?? 'application'), color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    data['title'] ?? 'New Application',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['body'] ?? 'Someone applied to your job post'),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  tileColor: isRead ? null : Colors.blue[50],
                  onTap: () {
                    _markAsRead(notification.id);
                    _handleNotificationTap(data);
                  },
                  trailing: isRead 
                      ? null 
                      : const Icon(Icons.circle, color: Colors.blue, size: 12),
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'application':
        return Icons.assignment;
      case 'interview':
        return Icons.event;
      case 'message':
        return Icons.message;
      case 'update':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'application':
        return Colors.green;
      case 'interview':
        return Colors.purple;
      case 'message':
        return Colors.orange;
      case 'update':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Get all batches
      final batches = _getBatches(_userPostIds, _batchSize);
      
      // Process each batch
      for (final batch in batches) {
        final notifications = await FirebaseFirestore.instance
            .collection('notifications')
            .where('postId', whereIn: batch)
            .where('isRead', isEqualTo: false)
            .get();
            
        final writeBatch = FirebaseFirestore.instance.batch();
        
        for (final doc in notifications.docs) {
          writeBatch.update(doc.reference, {'isRead': true});
        }
        
        await writeBatch.commit();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final String? applicationId = data['applicationId'];
    final String? postId = data['postId'];
    final String category = data['category']?.toLowerCase() ?? 'application';

    switch (category) {
      case 'application':
        if (applicationId != null) {
          Navigator.of(context).pushNamed(
            '/application-details', 
            arguments: {'applicationId': applicationId, 'postId': postId}
          );
        } else if (postId != null) {
          Navigator.of(context).pushNamed('/post-applications', arguments: postId);
        }
        break;
      case 'interview':
        if (applicationId != null) {
          Navigator.of(context).pushNamed(
            '/interview-schedule', 
            arguments: {'applicationId': applicationId}
          );
        }
        break;
      case 'message':
        final String? senderId = data['senderId'];
        if (senderId != null) {
          Navigator.of(context).pushNamed('/chat', arguments: senderId);
        } else {
          Navigator.of(context).pushNamed('/messages');
        }
        break;
      default:
        // Just mark as read with no action
        break;
    }
  }
}