import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserModel> signUp(String email, String password, String displayName) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final now = DateTime.now();
    final user = UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      coupleId: '',
      fcmToken: '',
      createdAt: now,
    );
    await _db.collection('users').doc(uid).set(user.toMap());
    return user;
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  /// update()는 문서가 없으면 예외를 던지고, 호출부가 이를 삼켜 토큰이 조용히
  /// 유실된다. 토큰이 없으면 Cloud Function이 푸시를 아예 보내지 않으므로 merge로 쓴다.
  Future<void> updateFcmToken(String uid, String token) {
    return _db.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }
}
