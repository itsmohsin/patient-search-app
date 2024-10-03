import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Search by ID
  Future<QuerySnapshot<Map<String, dynamic>>> searchById(String id) async {
    return await _db.collection('patientsdata')
      .where('id', isEqualTo: id)
      .get();
  }

  // Search by Name
  Future<QuerySnapshot<Map<String, dynamic>>> searchByName(String name) async {
    return await _db.collection('patientsdata')
      .where('fullName', isEqualTo: name)
      .get();
  }

  // Search by Phone
  Future<QuerySnapshot<Map<String, dynamic>>> searchByPhone(String phone) async {
    return await _db.collection('patientsdata')
      .where('phoneNo', isEqualTo: phone)
      .get();
  }
}
