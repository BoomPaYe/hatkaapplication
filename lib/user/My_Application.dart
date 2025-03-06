import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({Key? key}) : super(key: key);

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _applications = [];
  String? _profileImageUrl;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _fetchApplications();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    if (_currentUserId.isEmpty) return;

    try {
      // Fetch user profile data to get the profile image
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (mounted && userDoc.exists) {
        setState(() {
          _profileImageUrl = userDoc.data()?['profileImageUrl'];
        });
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  Future<void> _fetchApplications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (_currentUserId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Fetch applications directly from jobApplications collection
      final applicationsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('jobApplications')
          .orderBy('submittedAt', descending: true)
          .get();

      final applications = applicationsSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _applications = applications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching applications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load applications');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
        centerTitle: true,
        actions: [
          _buildProfileAvatar(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchApplications,
            tooltip: 'Refresh applications',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchApplications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _applications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final application = _applications[index];
                      return _buildApplicationCard(application);
                    },
                  ),
                ),
    );
  }

  Widget _buildProfileAvatar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () {
          // Navigate to profile page
          Navigator.pushNamed(context, '/profile');
        },
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[200],
          backgroundImage:
              _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
          child: _profileImageUrl == null
              ? Icon(Icons.person, size: 20, color: Colors.grey[600])
              : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No job applications yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Applications you submit will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to application details screen
          Navigator.pushNamed(
            context,
            '/application-details',
            arguments: application,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompanyLogo(application),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application['jobTitle']?.toString() ?? 'Position',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          application['company']?.toString() ?? 'Company',
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(application['status'] ?? 'Applied',
                      _getStatusColor(application['status'])),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (application['jobType'] != null)
                    _buildDetailChip(application['jobType'], Colors.blue),
                  if (application['locationType'] != null)
                    _buildDetailChip(
                        application['locationType'], Colors.purple),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(application['submittedAt']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyLogo(Map<String, dynamic> application) {
    final String companyName = application['company']?.toString() ?? 'Company';
    final String? companyLogo = application['companyImageUrl']?.toString();
    final String initial =
        companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C';

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: companyLogo == null ? _getCompanyColor(companyName) : null,
        borderRadius: BorderRadius.circular(25),
      ),
      child: companyLogo != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image.network(
                companyLogo,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Color _getCompanyColor(String companyName) {
    // Generate a color based on company name
    switch (companyName.toLowerCase()) {
      case 'smart axiata':
        return Colors.green;
      case 'cellcard':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'applied':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'interview':
        return Colors.deepOrange;
      case 'offer':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';

    if (timestamp is Timestamp) {
      return 'Applied ${timeago.format(timestamp.toDate())}';
    } else if (timestamp is String) {
      // Handle string dates
      return 'Applied on $timestamp';
    }
    return '';
  }
}
