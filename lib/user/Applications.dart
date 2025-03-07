import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hatka/user/Notifications_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Job class with updated fields including location
class Job {
  final String id;
  final String title;
  final String company;
  final String companyId;
  final String postId;
  final String location;

  Job.fromMap(Map<String, dynamic> map)
      : id = map['id'] ?? '',
        title = map['title'] ?? 'Untitled Job',
        company = map['name'] ?? 'Loading...',
        companyId = map['userId'] ??
            map['companyId'] ??
            '', // Try both userId and companyId
        postId = map['postId'] ?? map['id'] ?? '',
        location = map['location'] ?? 'Remote';

  // Method to create a new Job with updated company and location
  Job copyWith({String? company, String? location}) {
    return Job.fromMap({
      'id': this.id,
      'title': this.title,
      'company': company ?? this.company,
      'companyId': this.companyId,
      'postId': this.postId,
      'location': location ?? this.location,
    });
  }
}

// Job Application Form
class JobApplicationForm extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobApplicationForm({Key? key, required this.job}) : super(key: key);

  @override
  _JobApplicationFormState createState() => _JobApplicationFormState();
}

class _JobApplicationFormState extends State<JobApplicationForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _additionalTextController =
      TextEditingController();

  // File variables for resume and cover letter
  File? _resumeFile;

  // Company name from users collection
  String _companyName = 'Loading...';
  String _jobLocation = 'Remote';
  String? _companyProfileImageUrl;

  // New variable to track submission state
  bool _isSubmitting = false;
  bool _isLoading = true;

  // Cloudinary configuration
  final String cloudinaryUrl =
      'https://api.cloudinary.com/v1_1/dbo1t0quj/upload';
  final String uploadPreset = 'pdfapplication';

  late Job _jobInstance;

  @override
  void initState() {
    super.initState();
    // Convert the job map to a Job instance
    _jobInstance = Job.fromMap(widget.job);

    print("Job data received: ${widget.job}");
    print("Company ID from job data: ${widget.job['companyId']}");
    print("userId from job: ${widget.job['userId']}");
    print(
        "Job instance created: id=${_jobInstance.id}, postId=${_jobInstance.postId}, companyId=${_jobInstance.companyId}");

    if (_jobInstance.id.isEmpty && _jobInstance.postId.isEmpty) {
      // Show an error dialog or toast
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Invalid job data received. Please try again.')));
        // Navigate back after a short delay
        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pop();
        });
      });
    }

    // Fetch company name and profile image from users collection
    _fetchCompanyData();

    // Fetch job location from posts collection
    _fetchJobLocation();

    // Pre-fill email with current user's email if available
    _prefillUserData();
  }

  Future<void> _fetchCompanyData() async {
    try {
      // Try both userId and companyId fields
      String companyId = _jobInstance.companyId;

      print("Job data received: ${widget.job}");
      print("Company ID from job instance: $companyId");

      if (companyId.isNotEmpty) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(companyId)
            .get();

        print("Document exists: ${docSnapshot.exists}");
        if (docSnapshot.exists) {
          final data = docSnapshot.data();
          print("Company data: $data");

          setState(() {
            _companyName = data?['name'] ?? 'Unknown Company';
            _companyProfileImageUrl = data?['profileImage'];
            _jobInstance = _jobInstance.copyWith(company: _companyName);
            print("Updated company name: $_companyName");
            print("Updated profile image: $_companyProfileImageUrl");
          });
        } else {
          print("Company document not found");
          setState(() {
            _companyName = 'Unknown Company';
          });
        }
      } else {
        print("Company ID is empty");
        setState(() {
          _companyName = 'Unknown Company';
        });
      }
    } catch (e) {
      print('Error fetching company data: $e');
      setState(() {
        _companyName = 'Unknown Company';
      });
    }
  }

  Future<void> _fetchJobLocation() async {
    try {
      String postId = _jobInstance.postId.isNotEmpty
          ? _jobInstance.postId
          : _jobInstance.id;

      if (postId.isNotEmpty) {
        final postSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .get();

        if (postSnapshot.exists) {
          setState(() {
            _jobLocation = postSnapshot.data()?['location'] ?? 'Remote';
            // Update the job instance with the fetched location
            _jobInstance = _jobInstance.copyWith(location: _jobLocation);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching job location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _prefillUserData() async {
    // Get current user
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Set email from authentication
      setState(() {
        _emailController.text = currentUser.email ?? '';
      });

      // Try to get user's full name from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _fullNameController.text = userDoc.data()?['fullName'] ?? '';
          });
        }
      } catch (e) {
        print('Error fetching user profile: $e');
      }
    }
  }

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] =
          'resumes'; // Optional: organize uploads in a folder

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseString = await response.stream.bytesToString();
        final responseData = json.decode(responseString);

        // Return the secure URL of the uploaded file
        return responseData['secure_url'];
      } else {
        // Print response body for debugging
        final responseString = await response.stream.bytesToString();
        print('Cloudinary upload failed: $responseString');
        return null;
      }
    } catch (e) {
      print('Cloudinary upload error: $e');
      return null;
    }
  }

  Future<void> _pickResume() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _resumeFile = File(result.files.single.path!);
      });
    }
  }

  // Modify your _submitApplication method in _JobApplicationFormState class
Future<void> _submitApplication() async {
  // Existing auth check
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to submit an application')));
    return;
  }

  // Validate form
  if (!_formKey.currentState!.validate()) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill in all required fields correctly')));
    return;
  }

  // Debug information
  print(
      "Job instance: ${_jobInstance.id}, postId: ${_jobInstance.postId}, companyId: ${_jobInstance.companyId}");

  // Determine the best ID to use for the post reference
  // Try postId first, then fall back to id if needed
  String postId = '';
  if (_jobInstance.postId.isNotEmpty) {
    postId = _jobInstance.postId;
  } else if (_jobInstance.id.isNotEmpty) {
    postId = _jobInstance.id;
  }

  if (postId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Invalid job posting. Please try again later.')));
    return;
  }

  // Check if resume is uploaded
  if (_resumeFile == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Please upload your resume')));
    return;
  }

  setState(() {
    _isSubmitting = true;
  });

  try {
    // Upload resume to Cloudinary
    String? resumeUrl = await _uploadToCloudinary(_resumeFile!);

    if (resumeUrl == null) {
      throw Exception('Failed to upload resume');
    }

    // Get post reference from posts collection
    DocumentReference postRef =
        FirebaseFirestore.instance.collection('posts').doc(postId);

    // Print for debugging
    print("Submitting application with postId: $postId");

    // Get company ID and application details
    String companyId = _jobInstance.companyId;
    String applicationId = '';

    // Submit to user's jobApplications subcollection
    DocumentReference applicationRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('jobApplications')
        .add({
      'jobTitle': _jobInstance.title,
      'company': _companyName,
      'companyImageUrl': _companyProfileImageUrl,
      'location': _jobLocation,
      'postId': postId,
      'applicantId': currentUser.uid,
      'postRef': postRef,
      'fullName': _fullNameController.text,
      'email': _emailController.text,
      'additionalText': _additionalTextController.text,
      'resumeUrl': resumeUrl,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    applicationId = applicationRef.id;

    // Add application to company's applications subcollection
    if (companyId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(companyId)
          .collection('applications')
          .add({
        'jobTitle': _jobInstance.title,
        'location': _jobLocation,
        'postId': postId,
        'postRef': postRef,
        'applicantId': currentUser.uid,
        'applicantName': _fullNameController.text,
        'applicantEmail': _emailController.text,
        'additionalText': _additionalTextController.text,
        'resumeUrl': resumeUrl,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Get applicant details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      String applicantName = _fullNameController.text;
      String? applicantProfileImage = userDoc.data()?['profileImage'];

      // Send notification to company
      await NotificationService().sendNotificationToUser(
        userId: companyId,
        title: 'New Job Application',
        body: '$applicantName has applied for ${_jobInstance.title}',
        data: {
          'type': 'new_application',
          'postId': postId,
          'applicationId': applicationId,
          'applicantId': currentUser.uid,
          'applicantName': applicantName,
          'applicantImage': applicantProfileImage,
          'jobTitle': _jobInstance.title,
        },
      );

      // Add notification to company's notifications collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(companyId)
          .collection('notifications')
          .add({
        'title': 'New Job Application',
        'body': '$applicantName has applied for ${_jobInstance.title}',
        'type': 'new_application',
        'postId': postId,
        'applicationId': applicationId,
        'applicantId': currentUser.uid,
        'applicantName': applicantName,
        'applicantImage': applicantProfileImage,
        'jobTitle': _jobInstance.title,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Send confirmation notification to applicant
    await NotificationService().sendNotificationToUser(
      userId: currentUser.uid,
      title: 'Application Submitted',
      body: 'Your application for ${_jobInstance.title} at $_companyName has been submitted successfully!',
      data: {
        'type': 'application_submitted',
        'postId': postId,
        'applicationId': applicationId,
        'jobTitle': _jobInstance.title,
        'company': _companyName,
      },
    );

    // Add notification to user's notifications collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .add({
      'title': 'Application Submitted',
      'body': 'Your application for ${_jobInstance.title} at $_companyName has been submitted successfully!',
      'type': 'application_submitted',
      'postId': postId,
      'applicationId': applicationId,
      'jobTitle': _jobInstance.title,
      'company': _companyName,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Show local notification
    await _showApplicationSubmittedNotification();

    // Navigate to success screen
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => ApplicationResultScreen(isSuccess: true)));
  } catch (e) {
    print('Error submitting application: $e');
    // Show error in snackbar
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));

    setState(() {
      _isSubmitting = false;
    });
  }
}

Future<void> _showApplicationSubmittedNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'job_application_channel',
    'Job Applications',
    channelDescription: 'Notifications for job applications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );
  
  const NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(),
  );
  
  try {
    await flutterLocalNotificationsPlugin.show(
      0,
      'Application Submitted',
      'Your application for ${_jobInstance.title} has been submitted successfully!',
      platformDetails,
    );
    print('Notification shown successfully');
  } catch (e) {
    print('Error showing notification: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apply for Job'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Job details with company logo
                      Card(
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Company Profile Image
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                  image: _companyProfileImageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                              _companyProfileImageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _companyProfileImageUrl == null
                                    ? Icon(Icons.business,
                                        size: 30, color: Colors.grey[500])
                                    : null,
                              ),
                              SizedBox(width: 16),
                              // Job details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _jobInstance.title,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _companyName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            size: 16, color: Colors.grey[600]),
                                        SizedBox(width: 4),
                                        Text(
                                          _jobLocation,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Full Name Field
                      Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),

                      // Email Field
                      Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          // Basic email validation
                          final emailRegex =
                              RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),

                      // Resume Upload Section
                      Text(
                        'Upload Resume and Cover Letter',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Be sure to include an updated resume',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: _pickResume,
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.attach_file,
                                size: 32,
                                color: Colors.blue,
                              ),
                              SizedBox(height: 8),
                              Text(
                                _resumeFile != null
                                    ? _resumeFile!.path.split('/').last
                                    : 'Upload Resume and Cover Letter',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Additional Text Field
                      Text(
                        'Add text',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _additionalTextController,
                        decoration: InputDecoration(
                          hintText: 'Write something here...',
                          contentPadding: EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        maxLines: 8,
                      ),
                      SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitApplication,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSubmitting
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  'Submit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// Application Result Screen
class ApplicationResultScreen extends StatelessWidget {
  final bool isSuccess;
  final String? errorMessage;

  const ApplicationResultScreen({
    Key? key,
    required this.isSuccess,
    this.errorMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Circular icon based on success/failure
              CircleAvatar(
                radius: 60,
                backgroundColor: isSuccess ? Colors.blue : Colors.red,
                child: Icon(
                  isSuccess ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 80,
                ),
              ),
              SizedBox(height: 24),

              // Title based on success/failure
              Text(
                isSuccess
                    ? 'Congratulations!'
                    : 'Application Submission Failed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.blue : Colors.red,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),

              // Description text
              Text(
                isSuccess
                    ? 'Your application has been successfully sent!\nYou can check your application on the menu profile.'
                    : 'Unable to submit your application.\n${errorMessage ?? 'Please try again later.'}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),

              // Action buttons
              ElevatedButton(
                onPressed: () {
                  // Navigate to My Applications or dismiss
                  if (isSuccess) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                        '/my-applications', (route) => false);
                  } else {
                    // Just pop back to previous screen
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess ? Colors.blue : Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  isSuccess ? 'Go to My Applications' : 'Try Again',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Always allow cancelling/going back
                  Navigator.of(context).pop();
                },
                child: Text('Back to Main Page'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
