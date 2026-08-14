import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus {
  pending,
  resolved,
  rejected;

  static ReportStatus fromString(String? value) {
    return ReportStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ReportStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case ReportStatus.pending:
        return 'En attente';
      case ReportStatus.resolved:
        return 'Traite';
      case ReportStatus.rejected:
        return 'Rejete';
    }
  }
}

/// Signalement d'une annonce ou d'un utilisateur (`reports/{id}`).
///
/// Creable sans compte : exiger une inscription pour signaler une arnaque
/// reviendrait a ne recevoir presque aucun signalement.
class Report {
  final String id;
  final String targetType; // 'property' | 'user' | 'message'
  final String targetId;
  final String reason;
  final String? details;
  final String? reporterId; // null pour un visiteur non authentifie
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? adminNote;

  const Report({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.details,
    this.reporterId,
    this.status = ReportStatus.pending,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.adminNote,
  });

  /// Motifs proposes a l'utilisateur.
  static const List<String> reasons = [
    'Annonce frauduleuse',
    'Logement inexistant',
    'Prix trompeur',
    'Photos non conformes',
    'Coordonnees demandees hors application',
    'Contenu offensant',
    'Doublon',
    'Autre',
  ];

  factory Report.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Report(
      id: doc.id,
      targetType: d['targetType'] as String? ?? 'property',
      targetId: d['targetId'] as String? ?? '',
      reason: d['reason'] as String? ?? '',
      details: d['details'] as String?,
      reporterId: d['reporterId'] as String?,
      status: ReportStatus.fromString(d['status'] as String?),
      createdAt: _toDate(d['createdAt']) ?? DateTime.now(),
      resolvedAt: _toDate(d['resolvedAt']),
      resolvedBy: d['resolvedBy'] as String?,
      adminNote: d['adminNote'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreForCreate() {
    return {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'details': details,
      'reporterId': reporterId,
      'status': ReportStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
      'resolvedBy': null,
      'adminNote': null,
    };
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
