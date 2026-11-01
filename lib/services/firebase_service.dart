import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_state.dart';

class FirebaseService {
  static final _auth = FirebaseAuth.instance;
  static final _db   = FirebaseDatabase.instance;
  static final _gsi  = GoogleSignIn();

  static Stream<User?> get authStream => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;
  static String? get uid => _auth.currentUser?.uid;

  static Future<void> signInWithGoogle() async {
    final ga = await _gsi.signIn();
    if (ga == null) return;
    final cred = GoogleAuthProvider.credential(
      accessToken: (await ga.authentication).accessToken,
      idToken: (await ga.authentication).idToken,
    );
    await _auth.signInWithCredential(cred);
  }

  static Future<void> signOut() async {
    await _gsi.signOut();
    await _auth.signOut();
  }

  static Future<void> saveProfile(String uid, String email, String displayName) async {
    await _db.ref('profiles/$uid').set({'email': email, 'displayName': displayName});
  }

  static DatabaseReference userDataRef(String uid) => _db.ref('userData/$uid');

  static Future<void> saveState(String uid, AppState state) async {
    await _db.ref('userData/$uid').set(state.toMap());
  }

  static Stream<AppState> watchState(String uid) {
    return _db.ref('userData/$uid').onValue.map((event) {
      if (event.snapshot.exists) {
        return AppState.fromMap(Map<String, dynamic>.from(event.snapshot.value as Map));
      }
      return AppState.empty();
    });
  }

  static Future<List<Map<String, String>>> getSharedWorkspaces(String myUid) async {
    final snap = await _db.ref('receivedAccess/$myUid').get();
    if (!snap.exists) return [];
    final results = <Map<String, String>>[];
    for (final child in snap.children) {
      final profileSnap = await _db.ref('profiles/${child.key}').get();
      if (profileSnap.exists) {
        final profile = Map<String, dynamic>.from(profileSnap.value as Map);
        results.add({
          'uid': child.key!,
          'email': profile['email'] ?? '',
          'displayName': profile['displayName'] ?? '',
        });
      }
    }
    return results;
  }

  static Future<void> grantAccess(String myUid, String targetEmail) async {
    final profilesSnap = await _db.ref('profiles').get();
    if (!profilesSnap.exists) throw Exception('User not found');
    String? targetUid;
    Map<String, dynamic>? targetProfile;
    for (final child in profilesSnap.children) {
      final p = Map<String, dynamic>.from(child.value as Map);
      if ((p['email'] ?? '').toString().toLowerCase() == targetEmail.toLowerCase()) {
        targetUid = child.key;
        targetProfile = p;
        break;
      }
    }
    if (targetUid == null) throw Exception('User not found. They must sign in to MMM first.');
    if (targetUid == myUid) throw Exception('Cannot grant access to yourself.');
    await _db.ref('shares/$myUid/grantedTo/$targetUid').set(targetProfile);
    await _db.ref('receivedAccess/$targetUid/$myUid').set(true);
  }

  static Future<List<Map<String, dynamic>>> getGrantedAccesses(String myUid) async {
    final snap = await _db.ref('shares/$myUid/grantedTo').get();
    if (!snap.exists) return [];
    return snap.children.map((c) {
      final m = Map<String, dynamic>.from(c.value as Map);
      return {'uid': c.key, ...m};
    }).toList();
  }

  static Future<void> revokeAccess(String myUid, String targetUid) async {
    await _db.ref('shares/$myUid/grantedTo/$targetUid').remove();
    await _db.ref('receivedAccess/$targetUid/$myUid').remove();
  }
}
