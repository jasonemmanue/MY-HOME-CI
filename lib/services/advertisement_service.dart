import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'storage_service.dart';

/// Publicite video : 1 000 FCFA pour 3 jours, gratuite en Pack Pro.
///
/// `status` et `visibleUntil` sont poses par le serveur — apres paiement
/// confirme, ou apres verification du Pack Pro. Les regles Firestore refusent
/// au client de les ecrire : les lui laisser reviendrait a offrir la
/// diffusion a qui sait modifier une requete.
class Advertisement {
  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String? videoUrl;
  final String? targetPropertyId;
  final String status;
  final DateTime? visibleUntil;
  final DateTime? createdAt;

  const Advertisement({
    required this.id,
    required this.ownerId,
    this.ownerName = '',
    this.title = '',
    this.videoUrl,
    this.targetPropertyId,
    this.status = 'draft',
    this.visibleUntil,
    this.createdAt,
  });

  bool get isActive =>
      status == 'active' &&
      visibleUntil != null &&
      visibleUntil!.isAfter(DateTime.now());

  int? get daysLeft {
    if (!isActive) return null;
    return visibleUntil!.difference(DateTime.now()).inDays;
  }

  factory Advertisement.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Advertisement(
      id: doc.id,
      ownerId: d['ownerId'] as String? ?? '',
      ownerName: d['ownerName'] as String? ?? '',
      title: d['title'] as String? ?? '',
      videoUrl: d['videoUrl'] as String?,
      targetPropertyId: d['targetPropertyId'] as String?,
      status: d['status'] as String? ?? 'draft',
      visibleUntil: (d['visibleUntil'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AdvertisementService {
  AdvertisementService._();
  static final AdvertisementService instance = AdvertisementService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('advertisements');

  /// Publicites de l'utilisateur, de la plus recente a la plus ancienne.
  Stream<List<Advertisement>> watchMine(String uid) {
    return _col
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(Advertisement.fromFirestore).toList());
  }

  /// Publicites en cours de diffusion, pour l'accueil.
  Stream<List<Advertisement>> watchActive({int limit = 10}) {
    return _col
        .where('status', isEqualTo: 'active')
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map(Advertisement.fromFirestore)
            .where((a) => a.isActive)
            .toList());
  }

  /// Cree le brouillon puis y attache la video.
  ///
  /// Le document est cree AVANT l'envoi du fichier : le chemin Storage
  /// contient son identifiant, et les regles s'appuient dessus. Creer
  /// l'inverse obligerait a deviner un identifiant avant de l'avoir.
  Future<String> createDraft({
    required String ownerId,
    required String ownerName,
    required String title,
    required File video,
    String? targetPropertyId,
    void Function(double progress)? onProgress,
  }) async {
    final ref = await _col.add({
      'ownerId': ownerId,
      'ownerName': ownerName,
      'title': title.trim(),
      'videoUrl': null,
      'targetPropertyId': targetPropertyId,
      // Exige par les regles : une publicite naît toujours inactive.
      'status': 'draft',
      'visibleUntil': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final url = await StorageService.instance.uploadAdvertisementVideo(
      ownerId: ownerId,
      adId: ref.id,
      file: video,
      onProgress: onProgress,
    );

    await ref.update({'videoUrl': url});
    return ref.id;
  }

  /// Diffusion immediate au titre du Pack Pro.
  ///
  /// Passe par une Cloud Function : la verification du statut Pro ne peut pas
  /// etre confiee a l'application, qui a tout interet a se l'accorder.
  Future<void> activateAsPro(String adId) async {
    final callable = _functions.httpsCallable(
      'activateAdvertisement',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    await callable.call<Map<String, dynamic>>({'adId': adId});
  }

  Future<void> delete(String adId) => _col.doc(adId).delete();
}
