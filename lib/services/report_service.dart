import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/report.dart';

/// Signalements de contenu.
///
/// Un mecanisme de signalement fonctionnel n'est pas une option : Apple
/// (guideline 1.2) et Google Play exigent des applications a contenu genere
/// par les utilisateurs qu'elles offrent un moyen de signaler et un traitement
/// des signalements. C'est un motif de rejet frequent.
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('reports');

  /// Signale une annonce. Fonctionne sans compte : `reporterId` reste null.
  Future<void> reportProperty({
    required String propertyId,
    required String reason,
    String? details,
  }) async {
    await _create(
      targetType: 'property',
      targetId: propertyId,
      reason: reason,
      details: details,
    );
  }

  Future<void> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    await _create(
      targetType: 'user',
      targetId: userId,
      reason: reason,
      details: details,
    );
  }

  Future<void> reportMessage({
    required String conversationId,
    required String reason,
    String? details,
  }) async {
    await _create(
      targetType: 'message',
      targetId: conversationId,
      reason: reason,
      details: details,
    );
  }

  Future<void> _create({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final report = Report(
      id: '',
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      details: details?.trim().isEmpty == true ? null : details?.trim(),
      reporterId: FirebaseAuth.instance.currentUser?.uid,
      createdAt: DateTime.now(),
    );
    await _col.add(report.toFirestoreForCreate());
  }
}
