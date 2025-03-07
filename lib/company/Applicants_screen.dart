import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApplicantScreen extends StatefulWidget {
  const ApplicantScreen({Key? key}) : super(key: key);

  @override
  State<ApplicantScreen> createState() => _ApplicantScreenState();
}

class _ApplicantScreenState extends State<ApplicantScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _applicants = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchApplicants();
  }

  Future<void> _fetchApplicants() async {
    try {
      // Get the current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'You must be logged in to view applicants';
          _isLoading = false;
        });
        return;
      }

      // Get the current user's ID
      final String userId = currentUser.uid;
      
      // Get posts created by the current user
      // Based on your database structure, we need to identify posts by the current user
      // This could be by matching the email or by checking a field that identifies the poster
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData == null) {
        setState(() {
          _errorMessage = 'Could not retrieve user data';
          _isLoading = false;
        });
        return;
      }
      
      // Get user's email to match with post owners
      final userEmail = userData['email'];
      
      // Get all posts that belong to the current user
      // This assumes there's a postId field in your applications collection
      // that can be used to identify which post the application is for
      final applications = await _firestore
          .collection('users')
          .doc(userId)
          .collection('applications')
          .get();
      
      List<Map<String, dynamic>> applicantsList = [];
      
      for (var applicationDoc in applications.docs) {
        final applicationData = applicationDoc.data();
        
        applicantsList.add({
          'id': applicationData['applicantId'] ?? 'Unknown ID',
          'name': applicationData['applicantName'] ?? 'Unknown',
          'email': applicationData['applicantEmail'] ?? 'No email',
          'profileImage': applicationData['profileImage'] ?? '',
          'applyingFor': applicationData['jobTitle'] ?? 'Unknown Position',
          'applicationId': applicationDoc.id,
          'location': applicationData['location'] ?? 'Unknown',
          'status': applicationData['status'] ?? 'pending',
          'submittedAt': applicationData['submittedAt'] ?? '',
          'resumeUrl': applicationData['resumeUrl'] ?? '',
          // Add other relevant data as needed
        });
      }

      setState(() {
        _applicants = applicantsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load applicants: ${e.toString()}';
        _isLoading = false;
      });
      print('Error fetching applicants: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Applicants', style: TextStyle(fontSize: 16)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _applicants.isEmpty
                  ? const Center(child: Text('No applicants found'))
                  : ListView.builder(
                      itemCount: _applicants.length,
                      itemBuilder: (context, index) {
                        final applicant = _applicants[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Profile image
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: applicant['profileImage'] != null && 
                                                  applicant['profileImage'] != ''
                                      ? NetworkImage(applicant['profileImage'])
                                      : null,
                                  child: applicant['profileImage'] == null || 
                                         applicant['profileImage'] == ''
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                // Applicant details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        applicant['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        applicant['email'],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Location: ${applicant['location']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            'Apply For:', 
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              applicant['applyingFor'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Status:',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: applicant['status'] == 'pending'
                                                  ? Colors.amber.shade100
                                                  : applicant['status'] == 'accepted'
                                                      ? Colors.green.shade100
                                                      : Colors.red.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              applicant['status'] ?? 'pending',
                                              style: TextStyle(
                                                color: applicant['status'] == 'pending'
                                                    ? Colors.amber.shade800
                                                    : applicant['status'] == 'accepted'
                                                        ? Colors.green.shade800
                                                        : Colors.red.shade800,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // View application button
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  onPressed: () {
                                    // Navigate to application details
                                    // You could implement this to show a dialog or navigate to a detail screen
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}