import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Register or Sign In with Email + Phone (password = phone digits).
  Future<User?> registerOrLogin({
    required String email,
    required String name,
    required String phone,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 6) {
      throw 'Phone number must have at least 6 digits.';
    }
    final password = '${cleanPhone}antigravity';

    UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await _db.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'name': name,
          'phone': phone,
          'email': email,
          'provider': 'email',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        rethrow;
      }
    }
    return credential.user;
  }

  /// Sign in with Google on Web. On native Android/iOS, fall back to Anonymous Auth since
  /// popup is unsupported and native Google Sign-in requires SHA-1 configuration.
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        final UserCredential userCredential =
            await _auth.signInWithPopup(provider);
        final user = userCredential.user!;

        // Upsert user profile in Firestore
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'photoUrl': user.photoURL ?? '',
          'provider': 'google',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return user;
      } else {
        // Fallback to anonymous sign-in for Android/iOS
        final UserCredential userCredential = await _auth.signInAnonymously();
        final user = userCredential.user!;
        
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': 'Guest User',
          'email': 'guest@kaarigar.app',
          'phone': '',
          'photoUrl': '',
          'provider': 'anonymous',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        return user;
      }
    } catch (e) {
      print('Sign-In Error: $e');
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Saves a single chat message to Firestore.
  Future<void> saveMessage(
    String uid, {
    required String role,
    required String type,
    String? text,
    Map<String, dynamic>? worker,
    Map<String, dynamic>? quote,
    bool isError = false,
    bool isSuccess = false,
  }) async {
    try {
      await _db.collection('users').doc(uid).collection('chat_history').add({
        'role': role,
        'type': type,
        'text': text,
        'worker': worker,
        'quote': quote,
        'isError': isError,
        'isSuccess': isSuccess,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  /// Fetches all messages from chat history, ordered oldest-first.
  Future<List<Map<String, dynamic>>> fetchChatHistory(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('chat_history')
          .orderBy('timestamp', descending: false)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Error fetching chat history: $e');
      return [];
    }
  }

  /// Fetches summarized session list (first user message per day) for the drawer.
  Future<List<Map<String, dynamic>>> fetchSessionSummaries(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('chat_history')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final Map<String, Map<String, dynamic>> byDay = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        final ts = data['timestamp'];
        if (ts == null || data['role'] != 'user' || data['type'] != 'text') {
          continue;
        }
        final date = (ts as Timestamp).toDate();
        final dayKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        if (!byDay.containsKey(dayKey)) {
          byDay[dayKey] = {
            'text': data['text'] ?? '',
            'date': date,
            'dayKey': dayKey,
          };
        }
      }

      final summaries = byDay.values.toList();
      summaries.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      return summaries;
    } catch (e) {
      print('Error fetching session summaries: $e');
      return [];
    }
  }

  /// Fetches a user's profile from Firestore.
  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Saves a confirmed booking to Firestore.
  Future<void> saveBooking(
    String uid, {
    required String bookingId,
    required Map<String, dynamic> worker,
    required Map<String, dynamic> quote,
    required String day,
    required String time,
    required String phone,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('bookings')
          .doc(bookingId)
          .set({
        'bookingId': bookingId,
        'worker': worker,
        'quote': quote,
        'day': day,
        'time': time,
        'phone': phone,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving booking: $e');
    }
  }

  /// Fetches all bookings for a user from Firestore.
  Future<List<Map<String, dynamic>>> fetchBookings(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('bookings')
          .orderBy('timestamp', descending: true)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Error fetching bookings: $e');
      return [];
    }
  }
}
