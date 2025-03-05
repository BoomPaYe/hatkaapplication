import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Job class
class Job {
  final String id;
  final String title;
  final String company;

  Job.fromMap(Map<String, dynamic> map)
      : id = map['id'] ?? '',
        title = map['title'] ?? 'Untitled Job',
        company = map['name'] ?? map['company'] ?? 'Unknown Company';
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

  // File variable for resume
  File? _resumeFile;

  // New variable to track submission state
  bool _isSubmitting = false;

  // Cloudinary configuration - REPLACE WITH YOUR ACTUAL DETAILS
  final String cloudinaryUrl =
      'https://api.cloudinary.com/v1_1/dbo1t0quj/upload';
  final String uploadPreset = 'pdfapplication';

  late Job _jobInstance;

  @override
  void initState() {
    super.initState();
    // Convert the job map to a Job instance
    _jobInstance = Job.fromMap(widget.job);

    // Optionally pre-fill additional text with job details
    _additionalTextController.text =
        'Application for ${_jobInstance.title} at ${_jobInstance.company}';
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

  Future<void> _submitApplication() async {
    // Check if user is authenticated
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => ApplicationResultScreen(
              isSuccess: false,
              errorMessage: 'Please log in to submit an application')));
      return;
    }

    // Check if already submitting to prevent multiple submissions
    if (_isSubmitting) return;

    // Validate form
    if (!_formKey.currentState!.validate()) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => ApplicationResultScreen(
              isSuccess: false,
              errorMessage: 'Please fill in all required fields correctly')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload resume to Cloudinary
      String? resumeUrl;
      if (_resumeFile != null) {
        resumeUrl = await _uploadToCloudinary(_resumeFile!);

        if (resumeUrl == null) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) => ApplicationResultScreen(
                  isSuccess: false, errorMessage: 'Failed to upload resume')));
          return;
        }
      }

      // Submit to user's jobApplications subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('jobApplications')
          .add({
        'jobId': _jobInstance.id,
        'jobTitle': _jobInstance.title,
        'Company': _jobInstance.company,
        'fullName': _fullNameController.text,
        'email': _emailController.text,
        'additionalText': _additionalTextController.text,
        'resumeUrl': resumeUrl,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Optional: add a status field
      });

      // Navigate to success screen
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => ApplicationResultScreen(isSuccess: true)));
    } catch (e) {
      // Navigate to failure screen with error message
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => ApplicationResultScreen(
              isSuccess: false, errorMessage: e.toString())));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apply for ${_jobInstance.title}'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Applying for: ${_jobInstance.title}',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Text(
                'Company: ${_jobInstance.company}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
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
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickResume,
                child: Text('Upload Resume'),
              ),
              if (_resumeFile != null)
                Text('Resume Selected: ${_resumeFile!.path.split('/').last}'),
              SizedBox(height: 16),
              TextFormField(
                controller: _additionalTextController,
                decoration: InputDecoration(
                  labelText: 'Additional Information',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitApplication,
                child: Text('Submit Application'),
              ),
            ],
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

  const ApplicationResultScreen(
      {Key? key, required this.isSuccess, this.errorMessage})
      : super(key: key);

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
                    // Replace with your actual navigation to applications page
                    Navigator.of(context).pushNamedAndRemoveUntil(
                        '/my-applications', (route) => false);
                  } else {
                    // Typically, just pop back to previous screen
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
                child: Text('Back to user'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
