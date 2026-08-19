import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:uuid/uuid.dart';

/// Envoi et suppression des images.
///
/// La compression n'est pas une optimisation de confort : la cible est le
/// reseau 3G ivoirien, et une photo brute de smartphone (4 a 8 Mo) rend la
/// publication d'annonce impraticable. On vise ~250 Ko par image, ce qui reste
/// tres correct a l'affichage sur mobile.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Cote maximal apres redimensionnement.
  static const int _maxDimension = 1600;

  /// Qualite JPEG initiale ; abaissee par paliers si le fichier reste lourd.
  static const int _initialQuality = 82;

  /// Poids vise apres compression.
  static const int _targetBytes = 250 * 1024;

  // ── Selection ───────────────────────────────────────────────────────────

  Future<List<File>> pickImages({int limit = 10}) async {
    final picked = await _picker.pickMultiImage(imageQuality: 100);
    if (picked.isEmpty) return [];
    return picked.take(limit).map((x) => File(x.path)).toList();
  }

  Future<File?> pickCamera() async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    return shot == null ? null : File(shot.path);
  }

  Future<File?> pickSingleImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    return picked == null ? null : File(picked.path);
  }

  // ── Compression ─────────────────────────────────────────────────────────

  /// Reduit une image jusqu'a approcher [_targetBytes].
  ///
  /// Renvoie le fichier d'origine si la compression echoue : mieux vaut
  /// televerser une image lourde que perdre la photo de l'utilisateur.
  Future<File> compress(File source) async {
    try {
      final dir = await getTemporaryDirectory();
      var quality = _initialQuality;
      File? best;

      // Trois paliers suffisent : au-dela, la perte de qualite se voit plus
      // que le gain de poids.
      for (var attempt = 0; attempt < 3; attempt++) {
        final target =
            '${dir.path}/mhci_${_uuid.v4()}_$attempt.jpg';

        final result = await FlutterImageCompress.compressAndGetFile(
          source.absolute.path,
          target,
          quality: quality,
          minWidth: _maxDimension,
          minHeight: _maxDimension,
          format: CompressFormat.jpeg,
          keepExif: false, // les EXIF portent la geolocalisation de la prise
        );

        if (result == null) break;
        best = File(result.path);
        if (await best.length() <= _targetBytes) break;
        quality = (quality * 0.75).round();
      }

      return best ?? source;
    } catch (_) {
      return source;
    }
  }

  // ── Televersement ───────────────────────────────────────────────────────

  /// Envoie les photos d'une annonce et renvoie leurs URLs publiques.
  ///
  /// [onProgress] recoit une valeur entre 0 et 1 couvrant l'ensemble du lot,
  /// pour alimenter une barre de progression unique plutot qu'une par photo.
  Future<List<String>> uploadPropertyImages({
    required String ownerId,
    required String propertyId,
    required List<File> files,
    void Function(double progress)? onProgress,
  }) async {
    final urls = <String>[];

    for (var i = 0; i < files.length; i++) {
      final compressed = await compress(files[i]);
      final name = '${_uuid.v4()}.jpg';
      final ref = _storage.ref('properties/$ownerId/$propertyId/$name');

      final task = ref.putFile(
        compressed,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=604800',
        ),
      );

      if (onProgress != null) {
        task.snapshotEvents.listen((s) {
          final fileProgress =
              s.totalBytes == 0 ? 0.0 : s.bytesTransferred / s.totalBytes;
          onProgress((i + fileProgress) / files.length);
        });
      }

      await task;
      urls.add(await ref.getDownloadURL());
    }

    onProgress?.call(1);
    return urls;
  }

  Future<String> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    final compressed = await compress(file);
    final ref = _storage.ref('avatars/$userId/avatar.jpg');
    await ref.putFile(
      compressed,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<String> uploadChatImage({
    required String conversationId,
    required File file,
  }) async {
    final compressed = await compress(file);
    final ref = _storage.ref('chat/$conversationId/${_uuid.v4()}.jpg');
    await ref.putFile(
      compressed,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<String> uploadVerificationDocument({
    required String userId,
    required File file,
    required String label,
  }) async {
    final ref = _storage.ref('verifications/$userId/$label-${_uuid.v4()}.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Video d'une publicite : `advertisements/{ownerId}/{adId}/video.mp4`.
  ///
  /// Le chemin porte l'identifiant de la publicite pour que la suppression du
  /// compte puisse balayer tout le prefixe d'un seul appel, sans avoir a
  /// relire chaque document.
  Future<String> uploadAdvertisementVideo({
    required String ownerId,
    required String adId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref('advertisements/$ownerId/$adId/video.mp4');
    final task = ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));

    if (onProgress != null) {
      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress(s.bytesTransferred / s.totalBytes);
        }
      });
    }

    await task;
    return ref.getDownloadURL();
  }

  // ── Suppression ─────────────────────────────────────────────────────────

  /// Supprime un fichier a partir de son URL de telechargement.
  ///
  /// Silencieux en cas d'echec : une image deja absente ne doit pas empecher
  /// la suppression de l'annonce qui la reference.
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  Future<void> deleteAll(List<String> urls) async {
    await Future.wait(urls.map(deleteByUrl));
  }

  /// Supprime le dossier complet des photos d'une annonce.
  Future<void> deletePropertyFolder({
    required String ownerId,
    required String propertyId,
  }) async {
    try {
      final list = await _storage.ref('properties/$ownerId/$propertyId').listAll();
      await Future.wait(list.items.map((r) => r.delete()));
    } catch (_) {}
  }
}
