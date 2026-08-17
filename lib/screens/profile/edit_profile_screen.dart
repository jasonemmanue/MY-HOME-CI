import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/payment_config.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';

/// Édition du profil : nom, photo et coordonnées privées.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  File? _newAvatar;
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    _name.text = user.name;

    final contact = await UserService.instance.fetchContact(user.id);
    if (!mounted) return;
    setState(() {
      // Le numero est stocke au format international, le champ affiche
      // l'indicatif a part : sans conversion, l'utilisateur relirait
      // « 2250700000000 » derriere un prefixe « +225 » deja affiche.
      _phone.text = localPhoneDigits(contact.phone) ?? contact.phone ?? '';
      _email.text = contact.email ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await StorageService.instance.pickSingleImage();
    if (file != null) setState(() => _newAvatar = file);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      if (_newAvatar != null) {
        await UserService.instance.updateAvatar(uid: uid, file: _newAvatar!);
      }
      await UserService.instance.updateProfile(uid: uid, name: _name.text);
      await UserService.instance.updateContact(
        uid: uid,
        // Un seul format en base, quelle que soit la facon dont il a ete saisi.
        phone: normalizeIvorianPhone(_phone.text) ?? _phone.text,
        email: _email.text,
      );
      await auth.refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis a jour.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mise a jour impossible. Reessayez.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier mon profil',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _avatar(user)),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: _busy ? null : _pickAvatar,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text('Changer la photo',
                            style: GoogleFonts.inter(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Saisissez votre nom complet'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telephone',
                        prefixText: '$kCountryDialCode ',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        helperText: 'Jamais visible par les autres utilisateurs. '
                            'Propose par defaut lors d\'un paiement.',
                        helperMaxLines: 3,
                      ),
                      // Le champ etait libre : un numero mal forme n'avait pas
                      // de consequence tant qu'il ne servait qu'a la fiche.
                      // Depuis qu'il alimente le parcours de paiement, il doit
                      // etre exploitable tel quel.
                      validator: (v) {
                        final saisie = (v ?? '').trim();
                        if (saisie.isEmpty) return null;
                        if (normalizeIvorianPhone(saisie) == null) {
                          return 'Numero ivoirien a $kLocalPhoneLength chiffres attendu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        helperText: 'Jamais visible par les autres utilisateurs',
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _busy ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusDefault),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Enregistrer',
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _avatar(UserModel? user) {
    const size = 96.0;

    if (_newAvatar != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: FileImage(_newAvatar!),
      );
    }
    if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(user.photoUrl!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
      child: Text(
        user?.initials ?? '?',
        style: GoogleFonts.poppins(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }
}
