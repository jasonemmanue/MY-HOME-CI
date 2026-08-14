import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';

/// Demande du badge « Propriétaire vérifié ».
///
/// Les pièces déposées vont dans un dossier Storage lisible du seul déposant
/// et de l'administration ([storage.rules]) : une pièce d'identité en lecture
/// publique serait une fuite majeure.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _fullName = TextEditingController();
  String _documentType = 'CNI';
  File? _document;
  File? _selfie;
  bool _busy = false;

  static const List<String> _documentTypes = [
    'CNI',
    'Passeport',
    'Attestation d\'identite',
    'Titre de sejour',
  ];

  @override
  void initState() {
    super.initState();
    _fullName.text = context.read<AuthProvider>().user?.name ?? '';
  }

  @override
  void dispose() {
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isSelfie}) async {
    final file = isSelfie
        ? await StorageService.instance.pickCamera()
        : await StorageService.instance.pickSingleImage();
    if (file == null) return;
    setState(() => isSelfie ? _selfie = file : _document = file);
  }

  Future<void> _submit() async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) return;

    if (_fullName.text.trim().length < 3) {
      _snack('Saisissez votre nom tel qu\'il figure sur la piece.');
      return;
    }
    if (_document == null) {
      _snack('Ajoutez une photo de votre piece d\'identite.');
      return;
    }

    setState(() => _busy = true);
    try {
      await UserService.instance.submitVerification(
        uid: uid,
        idDocument: _document!,
        selfie: _selfie,
        fullName: _fullName.text,
        documentType: _documentType,
      );
      if (!mounted) return;
      _snack('Demande envoyee. Vous serez notifie sous 48 heures.');
      Navigator.pop(context);
    } catch (_) {
      _snack('Envoi impossible. Verifiez votre connexion.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Verification du profil',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Connexion requise.'))
          : StreamBuilder<String?>(
              stream: UserService.instance.watchVerificationStatus(uid),
              builder: (context, snapshot) {
                final status = snapshot.data;
                if (status == 'pending') return _pendingView(isDark);
                if (status == 'approved') return _approvedView(isDark);
                return _formView(isDark, rejected: status == 'rejected');
              },
            ),
    );
  }

  Widget _formView(bool isDark, {required bool rejected}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rejected) ...[
            _banner(
              isDark,
              Icons.error_outline,
              const Color(0xFFD64545),
              'Votre precedente demande n\'a pas ete validee. Verifiez que la '
              'piece est lisible, entiere et non expiree.',
            ),
            const SizedBox(height: 20),
          ],
          _banner(
            isDark,
            Icons.shield_outlined,
            AppTheme.primaryGreen,
            'Le badge « Verifie » rassure les locataires et augmente '
            'nettement le nombre de contacts. Vos documents ne sont visibles '
            'que par l\'equipe de moderation et sont supprimes apres examen.',
          ),
          const SizedBox(height: 24),
          Text('Nom figurant sur la piece',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          Text('Type de document',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _documentType,
            items: _documentTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _documentType = v ?? 'CNI'),
          ),
          const SizedBox(height: 20),
          _uploadTile(
            isDark,
            label: 'Photo de la piece d\'identite',
            hint: 'Recto, lisible, sans reflet',
            file: _document,
            onTap: () => _pick(isSelfie: false),
          ),
          const SizedBox(height: 12),
          _uploadTile(
            isDark,
            label: 'Selfie avec la piece (facultatif)',
            hint: 'Accelere la validation',
            file: _selfie,
            onTap: () => _pick(isSelfie: true),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('Envoyer ma demande',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _uploadTile(
    bool isDark, {
    required String label,
    required String hint,
    required File? file,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: file != null
                ? AppTheme.primaryGreen
                : (isDark ? AppTheme.dividerDark : AppTheme.dividerLight),
            width: file != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : const Icon(Icons.add_a_photo_outlined,
                      size: 22, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    file != null ? 'Photo ajoutee — appuyez pour changer' : hint,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: file != null
                          ? AppTheme.primaryGreen
                          : (isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingView(bool isDark) => _statusView(
        isDark,
        Icons.hourglass_top_outlined,
        AppTheme.secondaryOrange,
        'Demande en cours d\'examen',
        'Votre dossier est entre les mains de notre equipe. Vous recevrez une '
            'notification des qu\'une decision sera prise, generalement sous '
            '48 heures.',
      );

  Widget _approvedView(bool isDark) => _statusView(
        isDark,
        Icons.verified,
        AppTheme.primaryGreen,
        'Profil verifie',
        'Votre badge « Proprietaire verifie » est actif et apparait sur toutes '
            'vos annonces.',
      );

  Widget _statusView(bool isDark, IconData icon, Color color, String title,
      String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(bool isDark, IconData icon, Color color, String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
