import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import 'storage_service.dart';

/// Profil utilisateur et cycle de vie du compte.
class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Future<UserModel?> fetch(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  }

  Stream<UserModel?> watch(String uid) {
    return _doc(uid)
        .snapshots()
        .map((s) => s.exists ? UserModel.fromFirestore(s) : null);
  }

  /// Marque l'utilisateur comme vu a l'instant.
  ///
  /// `lastSeenAt` n'etait rafraichi qu'a la connexion, ce qui le rendait
  /// inexploitable : un compte connecte la semaine derniere aurait paru
  /// absent depuis. Les accuses de remise du chat s'appuient dessus pour
  /// distinguer « envoye » de « remis ».
  ///
  /// Silencieux en cas d'echec : une presence non mise a jour ne doit jamais
  /// interrompre ce que l'utilisateur est en train de faire.
  Future<void> touchLastSeen(String uid) async {
    try {
      await _doc(uid).update({'lastSeenAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  /// Coordonnees privees du titulaire du compte.
  Future<UserContact> fetchContact(String uid) async {
    try {
      final snap =
          await _doc(uid).collection('private').doc('contact').get();
      return UserContact.fromMap(snap.data());
    } catch (_) {
      return const UserContact();
    }
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{
      'lastSeenAt': FieldValue.serverTimestamp(),
    };
    if (name != null && name.trim().isNotEmpty) data['name'] = name.trim();
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    await _doc(uid).update(data);

    if (name != null && name.trim().isNotEmpty) {
      await _auth.currentUser?.updateDisplayName(name.trim());
    }
  }

  Future<String> updateAvatar({
    required String uid,
    required File file,
  }) async {
    final url = await StorageService.instance.uploadAvatar(
      userId: uid,
      file: file,
    );
    await updateProfile(uid: uid, photoUrl: url);
    await _auth.currentUser?.updatePhotoURL(url);
    return url;
  }

  Future<void> updateContact({
    required String uid,
    String? email,
    String? phone,
  }) async {
    await _doc(uid).collection('private').doc('contact').set(
      {
        if (email != null) 'email': email.trim(),
        if (phone != null) 'phone': phone.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ── Suppression de compte ───────────────────────────────────────────────

  /// Supprime definitivement le compte et toutes les donnees rattachees.
  ///
  /// Passe obligatoirement par une Cloud Function : la suppression doit
  /// balayer les annonces, les conversations, les fichiers Storage et le
  /// compte Auth lui-meme, ce qu'un client ne peut pas faire (les regles lui
  /// interdisent d'ecrire ailleurs que chez lui, a juste titre).
  ///
  /// Cette fonctionnalite n'est pas facultative : Apple (5.1.1(v)) et Google
  /// Play l'exigent des lors que l'application permet de creer un compte. Son
  /// absence est un motif de rejet systematique.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Aucun compte connecte.');

    try {
      final callable = _functions.httpsCallable(
        'deleteAccount',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      await callable.call<Map<String, dynamic>>();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated' || e.code == 'permission-denied') {
        throw StateError(
            'Pour des raisons de securite, reconnectez-vous puis reessayez.');
      }
      throw StateError(
          e.message ?? 'La suppression du compte a echoue. Reessayez.');
    }

    // La fonction a supprime le compte Auth cote serveur ; on nettoie la
    // session locale pour que l'application revienne a l'ecran d'accueil.
    await _auth.signOut();
  }

  // ── Verification proprietaire ───────────────────────────────────────────

  /// Depose une demande de badge « proprietaire verifie ».
  Future<void> submitVerification({
    required String uid,
    required File idDocument,
    File? selfie,
    required String fullName,
    required String documentType,
  }) async {
    final idUrl = await StorageService.instance.uploadVerificationDocument(
      userId: uid,
      file: idDocument,
      label: 'id',
    );

    String? selfieUrl;
    if (selfie != null) {
      selfieUrl = await StorageService.instance.uploadVerificationDocument(
        userId: uid,
        file: selfie,
        label: 'selfie',
      );
    }

    await _db.collection('verificationRequests').doc(uid).set({
      'status': 'pending',
      'fullName': fullName.trim(),
      'documentType': documentType,
      'idDocumentUrl': idUrl,
      'selfieUrl': selfieUrl,
      'requestedRole': UserRole.owner.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<String?> watchVerificationStatus(String uid) {
    return _db
        .collection('verificationRequests')
        .doc(uid)
        .snapshots()
        // Les parentheses ne sont pas cosmetiques : `x ? y as T? : z` est
        // ambigu pour l'analyseur, qui lit `T?` puis bute sur le `:`.
        .map((d) => d.exists ? (d.data()?['status'] as String?) : null);
  }
}
