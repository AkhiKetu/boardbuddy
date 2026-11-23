import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  final FirebaseFirestore _firestore;

  UserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Ensure a signed-in user has a Firestore profile.
  Future<void> ensureProfile(User user) async {
    final uid = user.uid;
    final email = user.email;
    final displayName = user.displayName?.trim();

    if (email == null || email.isEmpty) {
      throw StateError('User email is missing.');
    }

    if (displayName == null || displayName.length < 2) {
      throw StateError('User display name is missing.');
    }

    // Match the maximum name length in our security rules.
    final name = displayName.length > 100
        ? displayName.substring(0, 100)
        : displayName;

    final profileRef = _firestore.collection('users').doc(uid);

    // Read from the server to check whether
    // this profile has already been created.
    final snapshot = await profileRef.get(
      const GetOptions(source: Source.server),
    );

    // Never overwrite an existing profile or
    // reset its creation timestamp.
    if (snapshot.exists) {
      return;
    }

    // Create the profile for this Firebase UID.
    await profileRef.set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
