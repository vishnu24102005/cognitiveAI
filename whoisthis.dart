import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WhoIsThisPage extends StatefulWidget {
  @override
  _WhoIsThisPageState createState() => _WhoIsThisPageState();
}

class _WhoIsThisPageState extends State<WhoIsThisPage> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  String _response = '';  // To store the server response
  String _responseError = ''; // To store error messages from the server
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 tabs: one for success and one for error
  }

  // Function to pick image from gallery
  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = image;
    });
  }

  // Function to open camera and capture image
  Future<void> _pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    setState(() {
      _image = image;
    });
  }

  // Function to upload image to server
  Future<void> _uploadImage() async {
    if (_image == null) {
      _showErrorDialog('Please select an image.');
      return;
    }

    // Get the stored IP address from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    String baseUrl = prefs.getString('ip_address') ?? 'http://default.ip'; // Default IP if not set

    // Prepare the image file
    File imageFile = File(_image!.path);

    // Convert the image to base64
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);

    // Prepare the request body
    Map<String, dynamic> requestBody = {
      'image': base64Image,
    };

    try {
      // Send the request to the server
      final response = await http.post(
        Uri.parse('$baseUrl/api/match-image'), // Updated endpoint
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        // Successfully uploaded, process and store the response
        setState(() {
          _response = response.body; // Storing the server response
          _responseError = ''; // Clear any previous error
        });
      } else {
        // Server returned an error, store the error message
        setState(() {
          _responseError = 'Failed to upload data. Status code: ${response.statusCode}';
          _response = ''; // Clear any previous response
        });
      }
    } catch (e) {
      // Error during upload, store the error message
      setState(() {
        _responseError = 'Error during upload: $e';
        _response = ''; // Clear any previous response
      });
    }
  }

  // Function to show an error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Who Is This?'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Response'),
            Tab(text: 'Error'),
          ],
        ),
      ),
      body: SingleChildScrollView( // Make the page scrollable to avoid overflow issues
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Displaying the picked image
              _image != null
                  ? Image.file(File(_image!.path), height: 200, width: 200)
                  : Text('No image selected.', style: TextStyle(fontSize: 18)),

              SizedBox(height: 20),

              // Row to show camera and gallery icons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Camera Icon
                  IconButton(
                    icon: Icon(Icons.camera_alt, size: 40, color: Colors.blue),
                    onPressed: _pickImageFromCamera,
                  ),

                  SizedBox(width: 30), // Space between the two icons

                  // Gallery Icon
                  IconButton(
                    icon: Icon(Icons.photo_library, size: 40, color: Colors.green),
                    onPressed: _pickImageFromGallery,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Upload button
              ElevatedButton(
                onPressed: _uploadImage,
                child: Text('Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),

              SizedBox(height: 20),

              // TabBarView to show the server response and error
              Container(
                height: 300, // Adjust the height to your need
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Response Tab
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _response.isNotEmpty
                              ? Text('Server Response:', style: TextStyle(fontWeight: FontWeight.bold))
                              : Text('No response from the server.'),
                          SizedBox(height: 10),
                          Text(_response), // Display the response
                        ],
                      ),
                    ),

                    // Error Tab
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _responseError.isNotEmpty
                              ? Text('Error:', style: TextStyle(fontWeight: FontWeight.bold))
                              : Text('No error message.'),
                          SizedBox(height: 10),
                          Text(_responseError), // Display the error message
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}