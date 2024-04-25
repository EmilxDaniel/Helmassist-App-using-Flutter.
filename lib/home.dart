// import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:async';

import 'package:background_sms/background_sms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:helmet/profile_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'on_bike.dart';
import 'sos.dart';
import 'call_divert.dart';
import 'notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'noti.dart';
import 'package:flutter/services.dart';
import 'Find_bike.dart';
import 'package:telephony/telephony.dart' hide SmsStatus;
import 'package:sms_mms/sms_mms.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final FlutterLocalNotificationsPlugin overSpeed =
    FlutterLocalNotificationsPlugin();
final AudioPlayer _player = AudioPlayer();
final AudioPlayer _speedWarn = AudioPlayer();

class HomePage extends StatefulWidget {
  final String? Username;
  final String? Email;

  const HomePage({
    required this.Username,
    required this.Email,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String apiKey = 'your API key for OpenWeatherMap';
  String city = 'Kochi';
  String apiUrl =
      'https://api.openweathermap.org/data/2.5/weather?q=Kochi&appid=c43b3056bfb9b0f47f2c6ebd4f675ef0&units=metric';
  var weatherData;
  String day = '';
  String month = '';
  String date = '';
  String locationMessage = 'This is the current location';
  String lat = '';
  String long = '';
  String fast = 'Loading...';
  Telephony telephony = Telephony.instance;
  String? sosMessage;
  List<String>? sosContacts;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Position> _getcurrentloc() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Permissions not enabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('location permissions are denied forever');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> fetchSOSData() async {
    try {
      User? user = _auth.currentUser;
      String uid = user!.uid;
      DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('Users').doc(uid).get();

      setState(() {
        sosMessage = snapshot.data()?['sos_message'];
        sosContacts = List<String>.from(snapshot.data()?['sos_contacts']);
      });
    } catch (error) {
      print('Error fetching SOS data: $error');
    }
    print(sosContacts);
    print(sosMessage);
  }

  Future<void> _getSpeed() async {
    _getcurrentloc().then((value) {
      Geolocator geolocator = Geolocator();
      Geolocator.getPositionStream().listen((Position position) {
        lat = '${position.latitude}';
        long = '${position.longitude}';
        fast = position.speed.toStringAsFixed(2);
        if (double.parse(fast) > 16.67) {
          //16.67m/s == 60Km/hr
          _playSpeedWarnSound();
          noti.speedNotification(
              title: "Helmet", body: "Over Speed Warning", fln: overSpeed);
        }
        setState(() {
          locationMessage =
              'Latitude: $lat\nLongitude: $long\nSpeed: $fast m/s';
        });
      });
    });
  }

  void _liveLocation() {
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );
    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      lat = position.latitude.toString();
      long = position.longitude.toString();

      setState(() {
        locationMessage = 'Lattitude: $lat  Longitude: $long';
      });
    });
  }

  Future<void> _openMap(String lat, String long) async {
    String googleURL =
        'https://www.google.com/maps/search/?api=1&query=$lat,$long';
    await canLaunchUrlString(googleURL)
        ? await launchUrlString(googleURL)
        : throw 'could not launch $googleURL';
  }

  void smsForSosMulti(
      {required String? message, required List<String>? numbers}) async {
    for (String number in numbers!) {
      await smsForSos(message: message, number: number);
    }
  }

  smsForSos({required message, required number}) async {
    print(number + "wwwwwwwwwwwwwwwwwwwwwwwwwwwwww");
    SmsStatus res =
        await BackgroundSms.sendMessage(phoneNumber: number, message: message);
  }

  @override
  void initState() {
    noti.initializeNoti(flutterLocalNotificationsPlugin);
    noti.initializeNoti(overSpeed);
    _getSpeed();
    fetchSOSData();

    super.initState();

    fetchWeather();
    DateTime now = DateTime.now();
    day = getDayOfWeek(now.weekday);
    month = getMonth(now.month);
    date = now.day.toString();
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        if (message.address == "+917012828098" &&
            message.body == "Accident Happened") {
          smsForSosMulti(message: sosMessage, numbers: sosContacts);
        }
      },
      listenInBackground: false,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _speedWarn.dispose();
    super.dispose();
  }

  Future<void> fetchWeather() async {
    var response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      setState(() {
        weatherData = jsonDecode(response.body);
      });

      if (weatherData != null &&
          weatherData['weather'] != null &&
          weatherData['weather'].isNotEmpty) {
        var weatherMain = weatherData['weather'][0]['main'];
        if (weatherMain.toLowerCase() == 'rain') {
          _playNotificationSound();
          noti.showNotification(
              title: 'Helmet',
              body: 'Incomming rain',
              fln: flutterLocalNotificationsPlugin);

          print(weatherData['weather'][0]['main']);
        } else {
          print(weatherData['weather'][0]['main']);
        }
      }
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _player.setAsset('assets/images/voice.mp3');
      await _player.play();
    } catch (e) {
      print("Error playing notification sound: $e");
    }
  }

  Future<void> _playSpeedWarnSound() async {
    try {
      await _speedWarn.setAsset('assets/images/overspeedvoice.mp3');
      await _speedWarn.play();
    } catch (e) {
      print("Error playing notification sound: $e");
    }
  }

  String getDayOfWeek(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String getMonth(int month) {
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
        return 'August';
      case 9:
        return 'September';
      case 10:
        return 'October';
      case 11:
        return 'November';
      case 12:
        return 'December';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
              color: Colors.white,
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ProfilePage(
                            User: widget.Username, Mail: widget.Email)));
              },
              icon: Icon(Icons.account_circle))
        ],
        backgroundColor: Colors.black,
        title: Text(
          'Welcome ${widget.Username}',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(),
                  color: Colors.grey,
                ),
                margin: EdgeInsets.all(20),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '  $day, $month $date',
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(width: 90),
                        if (weatherData != null && weatherData['main'] != null)
                          Text(
                            '${weatherData['main']?['temp'] ?? 'N/A'}°C',
                            style: TextStyle(fontSize: 24, color: Colors.white),
                          ),
                      ],
                    ),
                    if (weatherData != null && weatherData['name'] != null)
                      Text(
                        '  ${weatherData['name']}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      CircularProgressIndicator(),
                    if (weatherData != null &&
                        weatherData['weather'] != null &&
                        weatherData['weather'].isNotEmpty)
                      Row(
                        children: [
                          Image.network(
                            'http://openweathermap.org/img/wn/${weatherData['weather'][0]['icon']}.png',
                            scale: 1.5,
                          ),
                          SizedBox(width: 8),
                          Text(
                            weatherData['weather'][0]['main'],
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 20),
                          Text('                           Speed: ${fast}'),
                        ],
                      ),
                  ],
                )),
            _buildFeatureButton(
              context: context,
              icon: Icons.location_on,
              label: 'Where Is My Bike',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => WhereIsMyBikePage()));
              },
            ),
            SizedBox(height: 16.0),
            _buildFeatureButton(
              context: context,
              icon: Icons.directions_bike,
              label: 'Start/StopBike',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StartStopBikePage(),
                    ));
              },
            ),
            SizedBox(height: 16.0),
            _buildFeatureButton(
              context: context,
              icon: Icons.warning,
              label: 'SOS Message',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SOSMessagePage(
                        selectedDisplayNames: [],
                        selectedPhoneNumbers: [],
                      ),
                    ));
              },
            ),
            SizedBox(height: 16.0),
            _buildFeatureButton(
              context: context,
              icon: Icons.call,
              label: 'Call Diverting',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CallDivertingPage(),
                    ));
              },
            ),
            SizedBox(height: 16.0),
            _buildFeatureButton(
                context: context,
                icon: Icons.notifications,
                label: 'Notifications',
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationsPage(),
                      ));
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
          padding: EdgeInsets.all(20.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 40.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10.0),
          ],
        ),
      ),
    );
  }
}
