import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UploadPage extends StatefulWidget {
  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

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

  // Function to upload image and details to server
  Future<void> _uploadData() async {
    if (_image == null) {
      // If no image is selected, show an error message
      _showErrorDialog('Please select an image.');
      return;
    }

    String name = _nameController.text.trim();
    String relation = _relationController.text.trim();
    String description = _descriptionController.text.trim();

    if (name.isEmpty || relation.isEmpty || description.isEmpty) {
      // If any of the fields are empty, show an error message
      _showErrorDialog('Please fill in all the details.');
      return;
    }

    // Get the stored IP address
    final prefs = await SharedPreferences.getInstance();
    String baseUrl = prefs.getString('ip_address') ?? 'http://default.ip'; // Use default if not set

    // Prepare the image file
    File imageFile = File(_image!.path);

    // Convert the image to base64
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);

    // Prepare the request body
    Map<String, dynamic> requestBody = {
      'image': base64Image,
      'name': name,
      'relation': relation,
      'description': description,
    };

    try {
      // Send the request to the server
      final response = await http.post(
        Uri.parse('$baseUrl/api/store-image'), // Adjust the URL for your endpoint
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        // Successfully uploaded, show a success message
        _showSuccessDialog('Upload successful!');
      } else {
        // Server returned an error, show an error message
        _showErrorDialog('Failed to upload data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Error during upload, show an error message
      _showErrorDialog('Error during upload: $e');
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

  // Function to show a success dialog
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen after success
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
        title: Text('Upload Image'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
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

            // Show text fields only if an image is selected
            if (_image != null) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 10),

              TextField(
                controller: _relationController,
                decoration: InputDecoration(
                  labelText: 'Relation',
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 10),

              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 20),

              // Upload button
              ElevatedButton(
                onPressed: _uploadData,
                child: Text('Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}