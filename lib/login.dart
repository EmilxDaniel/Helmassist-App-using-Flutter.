import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:helmet/home.dart';
// import 'package:helmet/splash.dart';
import 'signup.dart';
import 'reusable_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class login_page extends StatefulWidget {
  const login_page({Key? key}) : super(key: key);

  @override
  _login_pageState createState() => _login_pageState();
}

class _login_pageState extends State<login_page> {
  TextEditingController _emailTextController = TextEditingController();
  TextEditingController _passwordTextController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Login',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
          Colors.grey.shade800,
          Colors.grey.shade700,
          Colors.grey.shade600,
          Colors.grey.shade500,
          Colors.grey.shade400,
        ], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SingleChildScrollView(
          child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).size.height * 0.1, 20, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  logoImage('assets/images/helmet.jpg'),
                  SizedBox(
                    height: 30,
                  ),
                  reusableTextField('Enter Email', Icons.mail_outline, false,
                      _emailTextController),
                  SizedBox(
                    height: 20,
                  ),
                  reusableTextField('Enter Password', Icons.lock_outline, true,
                      _passwordTextController),
                  SizedBox(
                    height: 30,
                  ),
                  signinSignupButton(context, true, () {
                    FirebaseAuth.instance
                        .signInWithEmailAndPassword(
                            email: _emailTextController.text,
                            password: _passwordTextController.text)
                        .then((value) async {
                      try {
                        QuerySnapshot querySnapshot = await FirebaseFirestore
                            .instance
                            .collection('Users')
                            .where('email',
                                isEqualTo: _emailTextController.text)
                            .get();
                        if (querySnapshot.docs.isNotEmpty) {
                          creatuser(context);
                          var userData = querySnapshot.docs.first.data()
                              as Map<String, dynamic>;
                          var username = userData['userName'];
                          print('$username');

                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HomePage(
                                        Username: username,
                                        Email: _emailTextController.text,
                                      )));
                        } else {
                          print('User not found');
                        }
                      } catch (e) {
                        print('Error: $e');
                      }
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Wrong credentials'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    });
                  }),
                  SizedBox(
                    height: 10,
                  ),
                  rowtext(context)
                ],
              )),
        ),
      ),
    );
  }

  Row rowtext(context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('Don\'t have an account?',
            style: TextStyle(color: Colors.black)),
        GestureDetector(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => signin_screen()));
          },
          child: Text(
            ' Sign Up',
            style: TextStyle(color: Colors.white),
          ),
        )
      ],
    );
  }

  Future<void> creatuser(BuildContext context) async {
    final SharedPreferences shp = await SharedPreferences.getInstance();
    await shp.setString('email', _emailTextController.text);
    await shp.setString('pass', _passwordTextController.text);
  }
}
