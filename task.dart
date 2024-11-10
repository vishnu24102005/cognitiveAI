import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For converting data to/from JSON

class ViewTasksPage extends StatefulWidget {
  @override
  _ViewTasksPageState createState() => _ViewTasksPageState();
}

class _ViewTasksPageState extends State<ViewTasksPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = []; // List to store messages
  late String serverIp; // Variable to store the server IP

  @override
  void initState() {
    super.initState();
    _loadServerIp(); // Load server IP on page initialization
  }

  // Function to load server IP from SharedPreferences
  Future<void> _loadServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      serverIp = prefs.getString('ip_address') ?? 'http://192.168.0.179:5000'; // Default IP if not set
    });
  }

  // Function to handle sending a message and getting a response from the server
  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) {
      return;
    }

    // User's message
    String userMessage = _messageController.text;

    setState(() {
      _messages.add({
        'sender': 'user',
        'message': userMessage,
      });
    });

    // Clear the text field after sending the message
    _messageController.clear();

    // Get the bot's response from the server
    await _getBotResponse(userMessage);
  }

  // Function to get the bot's response from the server
  Future<void> _getBotResponse(String userMessage) async {
    String response = 'Sorry, I did not understand that.';

    try {
      // Send the user's message to the server
      final uri = Uri.parse('$serverIp/api/process-input'); // Updated with your endpoint
      final responseFromServer = await http.post(
        uri,
        body: json.encode({'text': userMessage}), // Sending message in JSON format
        headers: {'Content-Type': 'application/json'},
      );

      if (responseFromServer.statusCode == 200) {
        // If the response is successful, parse the JSON and get the bot's reply
        final data = json.decode(responseFromServer.body);
        response = data['response'] ?? 'Sorry, no response from the server.';
      } else {
        response = 'Failed to communicate with the server.';
      }
    } catch (e) {
      response = 'Error: $e';
    }

    // Add the bot's response to the chat
    setState(() {
      _messages.add({
        'sender': 'bot',
        'message': response,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Chatbot'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ListTile(
                  title: Align(
                    alignment: message['sender'] == 'user'
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: message['sender'] == 'user'
                            ? Colors.blue[100]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        message['message']!,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(width: 1),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
