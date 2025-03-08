import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hatka/company/PDFViewer_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'ImprovedPDF.dart';

class JobDetailScreen extends StatefulWidget {
  final String postId;
  
  const JobDetailScreen({
    Key? key, 
    required this.postId
  }) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _jobData;
  List<Map<String, dynamic>> _applicants = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadJobDetails();
  }

  // Debug function to print Firestore documents
  void _printDebugData(String message, dynamic data) {
    debugPrint('DEBUG: $message');
    debugPrint('DEBUG DATA: $data');
  }

  // Load job details and applicants
  // Updated _loadJobDetails method in the _JobDetailScreenState class
Future<void> _loadJobDetails() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    debugPrint('Attempting to load job with ID: ${widget.postId}');
    
    // Fetch job details
    final jobDoc = await _firestore.collection('posts').doc(widget.postId).get();
    
    if (!jobDoc.exists) {
      debugPrint('Job document does not exist!');
      setState(() {
        _errorMessage = 'Job not found';
        _isLoading = false;
      });
      return;
    }
    
    final jobData = jobDoc.data() as Map<String, dynamic>;
    debugPrint('Job data loaded successfully: ${jobData['title']}');
    
    // Store the job data
    setState(() {
      _jobData = jobData;
    });
    
    // Get current user ID
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('No current user found');
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Fetch applicants from user's applications subcollection
    debugPrint('Fetching applications for postId: ${widget.postId}');
    final applicantsSnapshot = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('applications')
        .where('postId', isEqualTo: widget.postId)
        .get();
    
    debugPrint('Found ${applicantsSnapshot.docs.length} applications');
    
    List<Map<String, dynamic>> applicantsList = [];
    
    for (var doc in applicantsSnapshot.docs) {
      final applicantData = doc.data();
      debugPrint('Processing application: ${doc.id}');
      
      // Create the applicant data format consistent with your ApplicantScreen
      applicantsList.add({
        'id': applicantData['applicantId'] ?? 'Unknown ID',
        'profile': {
          'name': applicantData['applicantName'] ?? 'Unknown',
          'email': applicantData['applicantEmail'] ?? 'No email',
          'profileImage': applicantData['profileImage'] ?? '',
        },
        'applicationDate': applicantData['submittedAt'],
        'status': applicantData['status'] ?? 'pending',
        'resumeUrl': applicantData['resumeUrl'] ?? '',
        'additionalText': applicantData['additionalText'] ?? '',
        'applyingFor': applicantData['jobTitle'] ?? 'Unknown Position',
        'location': applicantData['location'] ?? 'Unknown',
        'applicationId': doc.id,
      });
    }
    
    debugPrint('Processed ${applicantsList.length} applicants');
    
    setState(() {
      _applicants = applicantsList;
      _isLoading = false;
    });
    
  } catch (e) {
    debugPrint('Error loading data: $e');
    setState(() {
      _errorMessage = 'Error loading data: $e';
      _isLoading = false;
    });
  }
}

  String _formatDate(dynamic date) {
    if (date == null) return 'Date unknown';
    
    if (date is Timestamp) {
      return DateFormat('MMMM dd, yyyy at h:mm a').format(date.toDate());
    } else if (date is String) {
      // Try to parse the string date
      try {
        final dateTime = DateTime.parse(date);
        return DateFormat('MMMM dd, yyyy at h:mm a').format(dateTime);
      } catch (e) {
        return date;
      }
    }
    
    return date.toString();
  }

Future<void> _downloadAndOpenPDF(String url) async {
  if (mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImprovedPDFScreen(
          pdfUrl: url,
          isLocalFile: false,
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadJobDetails,
                child: const Text('Try Again'),
              )
            ],
          ),
        ),
      );
    }
    
    if (_jobData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: const Center(child: Text('No job data available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Indicator
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _jobData!['isActive'] == true 
                          ? Colors.green[100] 
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _jobData!['isActive'] == true ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: _jobData!['isActive'] == true 
                            ? Colors.green[800] 
                            : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Title
                Text(
                  _jobData!['title'] ?? 'No Title',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Category
                Row(
                  children: [
                    const Icon(Icons.category, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Category: ${_jobData!['category'] ?? 'Not specified'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Location: ${_jobData!['location'] ?? 'Not specified'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Salary
                Row(
                  children: [
                    const Icon(Icons.attach_money, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Salary: \$${_jobData!['salary'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Job Type Chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // Internship Type
                    if (_jobData!['internshipType'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3478F6),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          _jobData!['internshipType'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    // Workspace Type
                    if (_jobData!['workspaceType'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3478F6),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          _jobData!['workspaceType'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Description
                const Text(
                  'Job Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _jobData!['description'] ?? 'No description provided',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Dates
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created: ${_formatDate(_jobData!['createdAt'])}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last Updated: ${_formatDate(_jobData!['updatedAt'] ?? _jobData!['createdAt'])}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Applicants Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Applicants',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_applicants.length} ${_applicants.length == 1 ? 'applicant' : 'applicants'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _applicants.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'No applicants yet for this position',
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: _applicants.length,
  itemBuilder: (context, index) {
    final applicant = _applicants[index];
    final profile = applicant['profile'] ?? {};
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Applicant Name and Avatar
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: profile['profileImage'] != null && 
                                  profile['profileImage'] != ''
                      ? NetworkImage(profile['profileImage'])
                      : null,
                  child: profile['profileImage'] == null || 
                         profile['profileImage'] == ''
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile['name'] ?? 'Applicant',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (profile['email'] != null)
                        Text(
                          profile['email'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(applicant['status']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _capitalizeFirst(applicant['status'] ?? 'pending'),
                    style: TextStyle(
                      color: _getStatusColor(applicant['status']) == Colors.green[100] ? 
                          Colors.green[800] : 
                          Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Application Details
            Text(
              'Location: ${applicant['location'] ?? 'Unknown'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 8),
            
            if (applicant['applicationDate'] != null)
              Text(
                'Applied on: ${_formatDate(applicant['applicationDate'])}',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Resume Button
                if (applicant['resumeUrl'] != null && applicant['resumeUrl'] != '')
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
  // Call the downloadAndOpenPDF method with the resume URL
  _downloadAndOpenPDF(applicant['resumeUrl']);
},
                        icon: const Icon(Icons.description),
                        label: const Text('Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                
                // Contact Button
                if (profile['email'] != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Implement contact functionality
                          debugPrint('Contacting: ${profile['email']}');
                        },
                        icon: const Icon(Icons.email),
                        label: const Text('Contact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Additional Info
            if (applicant['additionalText'] != null && applicant['additionalText'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Information:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        applicant['additionalText'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Action buttons to accept/reject the applicant
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      // Implement rejection logic
                      try {
                        final currentUser = _auth.currentUser;
                        if (currentUser != null) {
                          await _firestore
                              .collection('users')
                              .doc(currentUser.uid)
                              .collection('applications')
                              .doc(applicant['applicationId'])
                              .update({'status': 'rejected'});
                          
                          // Refresh the applicants list
                          _loadJobDetails();
                        }
                      } catch (e) {
                        debugPrint('Error rejecting applicant: $e');
                      }
                    },
                    child: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      // Implement acceptance logic
                      try {
                        final currentUser = _auth.currentUser;
                        if (currentUser != null) {
                          await _firestore
                              .collection('users')
                              .doc(currentUser.uid)
                              .collection('applications')
                              .doc(applicant['applicationId'])
                              .update({'status': 'accepted'});
                          
                          // Refresh the applicants list
                          _loadJobDetails();
                        }
                      } catch (e) {
                        debugPrint('Error accepting applicant: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method to capitalize first letter
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
  
  // Helper method to get color based on status
  Color _getStatusColor(String? status) {
    switch(status?.toLowerCase()) {
      case 'approved':
        return Colors.green[100]!;
      case 'rejected':
        return Colors.red[100]!;
      case 'pending':
        return Colors.orange[100]!;
      default:
        return Colors.blue[100]!;
    }
  }
}