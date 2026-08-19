import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_model.dart';
import '../utils/phone.dart';

/// Erreur d'authentification portant un message deja traduit en francais.
class AuthException implements Exception {
  final String message;
  final String? code;
  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Signal interne : le compte est authentifie mais n'a pas encore de fiche.
///
/// Une exception plutot qu'un retour nul, pour que `_ensureUserDocument` garde
/// une signature non nullable pour ses quatre autres appelants — email,
/// telephone, et les deux voies sociales une fois le profil complete.
class _ProfileIncomplete implements Exception {
  const _ProfileIncomplete();
}

/// Point d'entree unique pour tout ce qui touche a l'identite.
///
/// Regle structurante : un compte Firebase Auth sans document
/// `users/{uid}` correspondant est un compte inutilisable (l'app ne saurait
/// pas son role). [_ensureUserDocument] est donc appele apres *chaque* voie
/// d'entree — email, Google, Apple, telephone — et pas seulement a
/// l'inscription.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Profil public de l'utilisateur connecte, en temps reel.
  Stream<UserModel?> get currentUserStream {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<UserModel?>.value(null);
      return _db
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
    });
  }

  // ── Email / mot de passe ────────────────────────────────────────────────

  Future<UserModel> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(name.trim());

      final model = await _ensureUserDocument(
        user,
        fallbackName: name.trim(),
        role: role,
        phone: phone.trim(),
        email: email.trim(),
      );

      // Non bloquant : un echec d'envoi ne doit pas annuler l'inscription.
      unawaited(user.sendEmailVerification());

      return model;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e), code: e.code);
    }
  }

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return await _ensureUserDocument(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e), code: e.code);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e), code: e.code);
    }
  }

  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  // ── Telephone (OTP SMS) ─────────────────────────────────────────────────

  /// Demarre la verification d'un numero.
  ///
  /// [onCodeSent] recoit le `verificationId` a repasser a [confirmOtp].
  /// [onAutoVerified] ne se declenche que sur Android, ou le systeme peut lire
  /// le SMS lui-meme — sur iOS il n'est jamais appele, l'ecran doit donc
  /// toujours proposer la saisie manuelle.
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(AuthException error) onFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: _normalizePhone(phoneNumber),
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) {
        onAutoVerified?.call(credential);
      },
      verificationFailed: (e) {
        onFailed(AuthException(_translate(e), code: e.code));
      },
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Valide le code recu par SMS et connecte l'utilisateur.
  Future<UserModel> confirmOtp({
    required String verificationId,
    required String smsCode,
    String? name,
    UserRole? role,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final cred = await _auth.signInWithCredential(credential);
      return await _ensureUserDocument(
        cred.user!,
        fallbackName: name,
        role: role,
        phone: cred.user!.phoneNumber,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e), code: e.code);
    }
  }

  /// Met le numero au format E.164 attendu par Firebase.
  ///
  /// Delegue a `utils/phone.dart` : la meme regle sert desormais a
  /// l'enregistrement du profil, ou le numero doit etre stocke sous une forme
  /// unique — c'est celle que reprendront les paiements Mobile Money.
  String _normalizePhone(String input) =>
      toE164(input) ?? input.trim();

  // ── Google ──────────────────────────────────────────────────────────────

  /// Renvoie `null` lorsque le profil reste a completer : le compte Firebase
  /// existe, mais ni le role ni le telephone ne sont connus. L'appelant doit
  /// alors afficher l'ecran de completion, seul habilite a creer la fiche.
  Future<UserModel?> signInWithGoogle({UserRole? role}) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw const AuthException('Connexion Google annulee.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      return await _ensureUserDocument(
        cred.user!,
        fallbackName: googleUser.displayName,
        role: role,
        email: googleUser.email,
        // Google ne fournit ni role ni telephone. Creer une fiche d'office la
        // figerait en « locataire » sans numero, et les regles interdisent de
        // corriger `role` ensuite.
        createIfMissing: false,
      );
    } on _ProfileIncomplete {
      return null;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e), code: e.code);
    }
  }

  // ── Apple ───────────────────────────────────────────────────────────────

  /// Disponible sur iOS et macOS uniquement.
  ///
  /// Non negociable pour la publication : la regle App Store 4.8 impose une
  /// option de connexion equivalente des lors qu'un service tiers (ici Google)
  /// est propose. Sans elle, l'app est rejetee.
  bool get isAppleSignInAvailable => !kIsWeb && Platform.isIOS;

  /// Renvoie `null` lorsque le profil reste a completer, comme
  /// [signInWithGoogle].
  Future<UserModel?> signInWithApple({UserRole? role}) async {
    try {
      // Le nonce protege du rejeu : on envoie son empreinte SHA-256 a Apple et
      // sa valeur brute a Firebase, qui verifie la correspondance.
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauth = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final cred = await _auth.signInWithCredential(oauth);

      // Apple ne transmet nom et email qu'a la toute premiere autorisation.
      // Si on ne les enregistre pas maintenant, ils sont perdus definitivement.
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      final composedName = [givenName, familyName]
          .where((p) => p != null && p.isNotEmpty)
          .join(' ');

      return await _ensureUserDocument(
        cred.user!,
        fallbackName: composedName.isEmpty ? null : composedName,
        role: role,
        email: appleCredential.email,
        // Meme raison que pour Google : ni role ni telephone connus.
        createIfMissing: false,
      );
    } on _ProfileIncomplete {
      return null;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthException('Connexion Apple annulee.');
      }
      throw AuthException('Connexion Apple impossible : ${e.message}');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e), code: e.code);
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  // ── Session ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    // Deconnexion Google en plus de Firebase : sans cela, le selecteur de
    // compte Google ne reapparait pas a la reconnexion suivante.
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Reauthentification, exigee par Firebase avant toute operation sensible
  /// (changement de mot de passe, suppression de compte) si la session date.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user?.email == null) {
      throw const AuthException(
          'Reauthentification impossible pour ce mode de connexion.');
    }
    try {
      await user!.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e), code: e.code);
    }
  }

  // ── Document utilisateur ────────────────────────────────────────────────

  /// Cree le profil public s'il manque, le met a jour sinon.
  ///
  /// Idempotent a dessein : il est appele apres chaque connexion, y compris
  /// pour un compte existant, ou il ne fait que rafraichir `lastSeenAt`.
  /// Le compte authentifie n'a pas encore de fiche `users/{uid}`.
  ///
  /// C'est l'etat d'un utilisateur arrive par Google ou Apple : ces voies ne
  /// demandent ni role ni telephone, et la fiche n'est creee qu'une fois le
  /// profil complete. `role` etant verrouille par `noPrivilegeEscalation`
  /// cote regles, creer une fiche « locataire » par defaut pour la corriger
  /// ensuite serait impossible — d'ou l'attente.
  Future<bool> get needsProfileCompletion async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final snap = await _db.collection('users').doc(user.uid).get();
    return !snap.exists;
  }

  /// Cree la fiche d'un compte social, une fois le role et le telephone
  /// choisis par l'utilisateur.
  Future<UserModel> completeProfile({
    required String name,
    required UserRole role,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Session expiree. Reconnectez-vous.');
    }
    if (role == UserRole.admin) {
      throw const AuthException('Role invalide.');
    }

    final trimmed = name.trim();
    if (trimmed != user.displayName) {
      await user.updateDisplayName(trimmed);
    }

    return _ensureUserDocument(
      user,
      fallbackName: trimmed,
      role: role,
      phone: phone.trim(),
      email: user.email,
      createIfMissing: true,
    );
  }

  Future<UserModel> _ensureUserDocument(
    User user, {
    String? fallbackName,
    UserRole? role,
    String? phone,
    String? email,
    bool createIfMissing = true,
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists && !createIfMissing) {
      throw const _ProfileIncomplete();
    }

    if (!snap.exists) {
      final model = UserModel(
        id: user.uid,
        name: (fallbackName?.trim().isNotEmpty ?? false)
            ? fallbackName!.trim()
            : (user.displayName?.trim().isNotEmpty ?? false)
                ? user.displayName!.trim()
                : 'Utilisateur',
        photoUrl: user.photoURL,
        role: role ?? UserRole.tenant,
        createdAt: DateTime.now(),
      );
      await ref.set(model.toFirestoreForCreate());

      // Coordonnees dans le sous-document prive : elles ne doivent jamais
      // apparaitre dans le profil lisible par tous.
      // Toujours en E.164 : selon l'ecran d'origine, la meme personne serait
      // sinon enregistree « 07 00 00 00 00 » ou « +2250700000000 », et le
      // pre-remplissage du paiement Mobile Money deviendrait inexploitable.
      await ref.collection('private').doc('contact').set(
            UserContact(
              email: email ?? user.email,
              phone: toE164(phone ?? user.phoneNumber),
            ).toMap(),
          );

      return model;
    }

    await ref.update({'lastSeenAt': FieldValue.serverTimestamp()});

    // Complete les coordonnees si une nouvelle voie de connexion en apporte.
    if (email != null || phone != null) {
      await ref.collection('private').doc('contact').set(
        {
          if (email != null) 'email': email,
          if (phone != null) 'phone': toE164(phone),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    return UserModel.fromFirestore(snap);
  }

  /// Bascule un compte locataire en compte proprietaire.
  ///
  /// Passe par une Cloud Function : `role` fait partie des champs qu'un client
  /// ne peut pas modifier lui-meme (cf. `noPrivilegeEscalation`), sans quoi
  /// n'importe qui s'auto-promeut.
  Future<void> requestOwnerUpgrade() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Connexion requise.');
    await _db.collection('verificationRequests').doc(user.uid).set({
      'status': 'pending',
      'requestedRole': UserRole.owner.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Recharge le jeton pour recuperer les custom claims a jour (role admin,
  /// notamment) apres une modification cote serveur.
  Future<bool> refreshClaims() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(true);
    return token.claims?['admin'] == true;
  }

  // ── Traduction des erreurs ──────────────────────────────────────────────

  String _translate(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'user-disabled':
        return 'Ce compte a ete suspendu. Contactez le support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe deja avec cette adresse email.';
      case 'weak-password':
        return 'Mot de passe trop faible (8 caracteres minimum).';
      case 'operation-not-allowed':
        return 'Ce mode de connexion n\'est pas active.';
      case 'too-many-requests':
        return 'Trop de tentatives. Reessayez dans quelques minutes.';
      case 'network-request-failed':
        return 'Connexion internet indisponible.';
      case 'invalid-phone-number':
        return 'Numero de telephone invalide.';
      case 'invalid-verification-code':
        return 'Code de verification incorrect.';
      case 'session-expired':
        return 'Le code a expire. Demandez-en un nouveau.';
      case 'quota-exceeded':
        return 'Quota SMS depasse. Reessayez plus tard.';
      case 'account-exists-with-different-credential':
        return 'Un compte existe deja avec cette adresse, via un autre mode '
            'de connexion.';
      case 'requires-recent-login':
        return 'Pour des raisons de securite, reconnectez-vous avant de '
            'poursuivre.';
      default:
        return 'Erreur d\'authentification (${e.code}).';
    }
  }
}

/// Evite d'avoir a importer `dart:async` juste pour ignorer un Future.
void unawaited(Future<void> future) {
  future.catchError((_) {});
}
