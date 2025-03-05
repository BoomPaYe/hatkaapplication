import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Modify Job class to accept a map
class Job {
  final String id;
  final String title;
  final String company;

  Job.fromMap(Map<String, dynamic> map)
      : id = map['id'] ?? '',
        title = map['title'] ?? 'Untitled Job',
        company = map['companyName'] ?? map['company'] ?? 'Unknown Company';
}

class JobApplicationForm extends StatefulWidget {
  // Change to accept Map<String, dynamic>
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
  final TextEditingController _additionalTextController = TextEditingController();
  
  // File variable for resume
  File? _resumeFile;

  // New variable to track submission state
  bool _isSubmitting = false;

  // Cloudinary configuration - REPLACE WITH YOUR ACTUAL DETAILS
  final String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dbo1t0quj/upload';
  final String uploadPreset = 'pdfapplication';

  late Job _jobInstance;

  @override
  void initState() {
    super.initState();
    // Convert the job map to a Job instance
    _jobInstance = Job.fromMap(widget.job);

    // Optionally pre-fill additional text with job details
    _additionalTextController.text = 'Application for ${_jobInstance.title} at ${_jobInstance.company}';
  }

  Future<String?> _uploadToCloudinary(File file) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'resumes'; // Optional: organize uploads in a folder
      
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path)
      );

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to submit an application')),
      );
      return;
    }

    // Check if already submitting to prevent multiple submissions
    if (_isSubmitting) return;

    // Validate form
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    // Check if all required fields are filled
    if (_fullNameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload resume')),
          );
          setState(() {
            _isSubmitting = false;
          });
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
        'jobCompany': _jobInstance.company,
        'fullName': _fullNameController.text,
        'email': _emailController.text,
        'additionalText': _additionalTextController.text,
        'resumeUrl': resumeUrl,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Optional: add a status field
      });

      // Show success dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Application submitted successfully!')),
      );

      // Navigate back to previous screen
      Navigator.pop(context);
    } catch (e) {
      // Show detailed error
      print('Submission error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit application: $e')),
      );
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
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
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