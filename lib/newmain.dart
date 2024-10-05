import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // Make sure to generate this file using Firebase CLI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  runApp(PatientSearchApp());
}

class PatientSearchApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Patient Search with OTP Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          return PatientSearchScreen(); // Show patient search screen after login
        } else {
          return LoginScreen(); // Show login screen if not authenticated
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String verificationId = '';
  bool isOtpSent = false;

  Future<void> verifyPhoneNumber() async {
    String phone = '+${_phoneController.text.trim()}';
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieve or instant verification
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          isOtpSent = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error occurred')));
      },
      codeSent: (String verId, int? resendToken) {
        setState(() {
          verificationId = verId;
          isOtpSent = true;
        });
      },
      codeAutoRetrievalTimeout: (String verId) {
        setState(() {
          verificationId = verId;
        });
      },
    );
  }

  Future<void> signInWithOtp() async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: _otpController.text.trim(),
    );

    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() {
        isOtpSent = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid OTP')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login with OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Enter phone number (+ country code)',
              ),
            ),
            if (isOtpSent)
              TextField(
                controller: _otpController,
                decoration: InputDecoration(labelText: 'Enter OTP'),
              ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: isOtpSent ? signInWithOtp : verifyPhoneNumber,
              child: Text(isOtpSent ? 'Verify OTP' : 'Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}

// Patient Search Screen (same as before)
class PatientSearchScreen extends StatefulWidget {
  @override
  _PatientSearchScreenState createState() => _PatientSearchScreenState();
}

class _PatientSearchScreenState extends State<PatientSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>>? patientsData;
  String? errorMessage;

  Future<void> searchPatient() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        errorMessage = "Please enter an ID, name, or phone number to search.";
        patientsData = null;
      });
      return;
    }

    try {
      QuerySnapshot snapshot;

      // Search by ID
      snapshot = await FirebaseFirestore.instance
          .collection('patientsdata')
          .where('id', isEqualTo: query)
          .get();

      if (snapshot.docs.isNotEmpty) {
        patientsData = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      } else {
        // Search by fullName
        snapshot = await FirebaseFirestore.instance
            .collection('patientsdata')
            .where('fullName', isEqualTo: query)
            .get();

        if (snapshot.docs.isNotEmpty) {
          patientsData = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        } else {
          // Search by phoneNo
          snapshot = await FirebaseFirestore.instance
              .collection('patientsdata')
              .where('phoneNo', isEqualTo: int.tryParse(query))
              .get();

          if (snapshot.docs.isNotEmpty) {
            patientsData = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          } else {
            setState(() {
              errorMessage = "No results found for '$query'.";
              patientsData = null;
            });
          }
        }
      }

      setState(() {
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching data: $e";
        patientsData = null;
      });
    }
  }

  String _getLastVisitInfo(Timestamp? lastVisitedOn) {
    if (lastVisitedOn == null) return 'No visit record';

    DateTime lastVisitedDate = lastVisitedOn.toDate();
    DateTime now = DateTime.now();
    Duration difference = now.difference(lastVisitedDate);

    if (difference.inDays <= 45) {
      return '${difference.inDays} days ago';
    } else {
      return 'Visited on: ${lastVisitedDate.toLocal()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Search'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Enter ID, Name, or Phone Number',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: searchPatient,
                ),
              ),
              onSubmitted: (value) => searchPatient(),
            ),
            SizedBox(height: 16.0),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            if (patientsData != null && patientsData!.isNotEmpty) ...[
              SizedBox(height: 16.0),
              Text('Search Results:', style: TextStyle(fontSize: 20)),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: patientsData!.length,
                itemBuilder: (context, index) {
                  final patient = patientsData![index];
                  return ListTile(
                    title: Text(patient['fullName']),
                    subtitle: Text(
                      'ID: ${patient['id']}, Phone: ${patient['phoneNo']}, Last Visited: ${_getLastVisitInfo(patient['lastVisitedOn'])}\n'
                      'Consulted Doctors: ${patient['consultedDoctors']?.join(', ') ?? "N/A"}',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PatientDetailScreen(patient: patient),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PatientDetailScreen extends StatelessWidget {
  final Map<String, dynamic> patient;

  PatientDetailScreen({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${patient['id']}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Name: ${patient['fullName']}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Phone: ${patient['phoneNo']}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Last Visited: ${patient['lastVisitedOn'] != null ? patient['lastVisitedOn'].toDate().toLocal().toString() : 'No record'}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Consulted Doctors: ${patient['consultedDoctors']?.join(', ') ?? "N/A"}', style: TextStyle(fontSize: 18)),
            // Add more details if needed
          ],
        ),
      ),
    );
  }
}
