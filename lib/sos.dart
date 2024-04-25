import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:helmet/contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class SOSMessagePage extends StatefulWidget {
  final List<String> selectedDisplayNames;
  final List<String> selectedPhoneNumbers;

  SOSMessagePage({
    required this.selectedDisplayNames,
    required this.selectedPhoneNumbers,
  });

  @override
  _SOSMessagePageState createState() => _SOSMessagePageState();
}

class _SOSMessagePageState extends State<SOSMessagePage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> savedDisplayNames = [];
  List<String> savedPhoneNumbers = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _retrieveSOSData();
  }

  void _retrieveSOSData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('Users').doc(user.uid).get();
      if (snapshot.exists) {
        List<String> savedPhoneNumbers =
            List<String>.from(snapshot.data()?['sos_contacts'] ?? []);
        print(savedPhoneNumbers);

        // Fetch display names corresponding to the selected phone numbers
        List<Contact> contacts = await ContactsService.getContacts();
        List<String> savedDisplayNames = [];
        for (String phoneNumber in savedPhoneNumbers) {
          Contact? contact = contacts.firstWhereOrNull((contact) =>
              contact.phones!.any((phone) => phone.value == phoneNumber));
          if (contact != null) {
            savedDisplayNames.add(contact.displayName ?? 'Unknown');
          } else {
            savedDisplayNames.add('Unknown');
          }
        }
        print(savedDisplayNames);

        setState(() {
          this.savedPhoneNumbers = savedPhoneNumbers;
          this.savedDisplayNames = savedDisplayNames;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SOS Message',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Contacts:',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8.0),
            ElevatedButton(
              onPressed: () {
                _navigateToContactList();
              },
              child: Text('Add Numbers'),
            ),
            SizedBox(height: 8.0),
            Text(
              'SOS Message:',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter SOS message',
              ),
            ),
            SizedBox(height: 16.0),
            Text(
              'Members:',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            if ((savedDisplayNames.isEmpty && savedPhoneNumbers.isEmpty) ||
                ((savedDisplayNames.isNotEmpty &&
                        savedPhoneNumbers.isNotEmpty) &&
                    (widget.selectedDisplayNames.isNotEmpty &&
                        widget.selectedPhoneNumbers.isNotEmpty)))
              Expanded(
                child: ListView.builder(
                  itemCount: widget.selectedDisplayNames.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(widget.selectedDisplayNames[index]),
                      subtitle: Text(widget.selectedPhoneNumbers[index]),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            widget.selectedDisplayNames.removeAt(index);
                            widget.selectedPhoneNumbers.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: savedDisplayNames.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(savedDisplayNames[index]),
                      subtitle: Text(savedPhoneNumbers[index]),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            savedDisplayNames.removeAt(index);
                            savedPhoneNumbers.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                _saveSOSData();
              },
              child: Text('Apply'),
            )
          ],
        ),
      ),
    );
  }

  void _navigateToContactList() async {
    final List<String>? selectedPhoneNumbers = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactList(),
      ),
    );
    if (selectedPhoneNumbers != null) {
      setState(() {
        widget.selectedPhoneNumbers.addAll(selectedPhoneNumbers);
      });
    }
  }

  void _saveSOSData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      String messageContent = _messageController.text;
      if (widget.selectedPhoneNumbers.isEmpty)
        await _firestore.collection('Users').doc(user.uid).set({
          'sos_contacts': savedPhoneNumbers,
          'sos_message': messageContent,
        }, SetOptions(merge: true));
      else
        await _firestore.collection('Users').doc(user.uid).set({
          'sos_contacts': widget.selectedPhoneNumbers,
          'sos_message': messageContent,
        }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('SOS settings saved successfully'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('User not signed in'),
      ));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
