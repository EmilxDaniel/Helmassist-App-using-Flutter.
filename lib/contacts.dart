import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:helmet/sos.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactList extends StatefulWidget {
  @override
  State<ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  List<Contact> contacts = [];
  List<Contact> filteredContacts = [];
  bool isLoading = true;
  List<String> selectedDisplayNames = [];
  List<String> selectedPhoneNumbers = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getContactPermission();
  }

  void getContactPermission() async {
    if (await Permission.contacts.isGranted) {
      fetchContacts();
    } else {
      await Permission.contacts.request();
    }
  }

  void fetchContacts() async {
    List<Contact> fetchedContacts = await ContactsService.getContacts();
    setState(() {
      contacts = fetchedContacts;
      filteredContacts = contacts;
      isLoading = false;
    });
  }

  void toggleContactSelection(Contact contact) {
    setState(() {
      if (selectedDisplayNames.contains(contact.displayName)) {
        selectedDisplayNames.remove(contact.displayName);
        if (contact.phones!.isNotEmpty) {
          selectedPhoneNumbers.remove(contact.phones!.first.value);
        }
      } else {
        selectedDisplayNames.add(contact.displayName ?? '');
        if (contact.phones!.isNotEmpty) {
          selectedPhoneNumbers.add(contact.phones!.first.value ?? '');
        } else {
          selectedPhoneNumbers.add('No phone number');
        }
      }
    });
  }

  bool isContactSelected(Contact contact) {
    return selectedDisplayNames.contains(contact.displayName);
  }

  void filterContacts(String query) {
    List<Contact> filteredList = contacts
        .where((contact) =>
            contact.displayName!.toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      filteredContacts = filteredList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          onChanged: (value) {
            filterContacts(value);
          },
          decoration: InputDecoration(
            hintText: 'Search contacts...',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                searchController.clear();
                filterContacts('');
              },
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: filteredContacts.length,
              itemBuilder: (BuildContext context, int index) {
                Contact contact = filteredContacts[index];
                bool isSelected = isContactSelected(contact);
                return ListTile(
                  title: Text(contact.displayName ?? ''),
                  subtitle: Text(contact.phones!.isNotEmpty
                      ? contact.phones!.first.value ?? ''
                      : 'No phone number'),
                  trailing: isSelected ? Icon(Icons.check) : null,
                  onTap: () {
                    toggleContactSelection(contact);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${contact.displayName ?? ""} ${isSelected ? "removed from" : "added to"} selected contacts.'),
                    ));
                  },
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SOSMessagePage(
                  selectedDisplayNames: selectedDisplayNames,
                  selectedPhoneNumbers: selectedPhoneNumbers,
                ),
              ),
            );
          },
          child: Text("Confirm"),
        ),
      ),
    );
  }
}
