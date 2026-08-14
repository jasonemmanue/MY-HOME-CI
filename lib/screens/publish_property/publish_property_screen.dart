import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/property.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/location_service.dart';
import '../../services/property_service.dart';
import '../../services/storage_service.dart';

/// Formulaire de publication en six étapes.
///
/// L'annonce est enregistrée en brouillon dès la première étape validée :
/// perdre vingt minutes de saisie parce que l'application a été fermée est la
/// façon la plus sûre de dissuader un propriétaire de réessayer.
class PublishPropertyScreen extends StatefulWidget {
  /// Annonce existante à modifier, ou `null` pour une création.
  final Property? existing;

  const PublishPropertyScreen({super.key, this.existing});

  @override
  State<PublishPropertyScreen> createState() => _PublishPropertyScreenState();
}

class _PublishPropertyScreenState extends State<PublishPropertyScreen> {
  final PageController _pageController = PageController();
  int _step = 0;
  static const int _stepCount = 6;

  // Étape 1 — type
  String? _type;

  // Étape 2 — localisation
  final _addressController = TextEditingController();
  String? _quarter;
  String _city = 'Abidjan';
  double? _latitude;
  double? _longitude;
  GoogleMapController? _mapController;

  // Étape 3 — détails
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _surfaceController = TextEditingController();
  int _rooms = 1;
  int _bathrooms = 1;
  int _floor = 0;
  bool _isFurnished = false;

  // Étape 4 — équipements
  final Set<String> _equipment = {};

  // Étape 5 — photos
  final List<File> _newPhotos = [];
  List<String> _existingPhotos = [];

  // Étape 6 — loyer
  final _priceController = TextEditingController();

  String? _propertyId;
  bool _saving = false;
  double _uploadProgress = 0;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _propertyId = existing.id;
      _type = existing.type;
      _addressController.text = existing.address;
      _quarter = existing.quarter.isEmpty ? null : existing.quarter;
      _city = existing.city;
      _latitude = existing.latitude;
      _longitude = existing.longitude;
      _titleController.text = existing.title;
      _descriptionController.text = existing.description;
      _surfaceController.text =
          existing.surface > 0 ? existing.surface.toInt().toString() : '';
      _rooms = existing.rooms;
      _bathrooms = existing.bathrooms;
      _floor = existing.floor;
      _isFurnished = existing.isFurnished;
      _equipment.addAll(existing.equipment);
      _existingPhotos = List.of(existing.images);
      _priceController.text =
          existing.price > 0 ? existing.price.toString() : '';
    } else {
      AnalyticsService.instance.logPublishStarted();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _addressController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _surfaceController.dispose();
    _priceController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Navigation entre étapes ─────────────────────────────────────────────

  /// Message d'erreur si l'étape courante est incomplète, `null` sinon.
  String? _validateStep(int step) {
    switch (step) {
      case 0:
        return _type == null ? 'Choisissez un type de bien.' : null;
      case 1:
        if (_quarter == null) return 'Indiquez le quartier.';
        if (_latitude == null || _longitude == null) {
          return 'Placez le logement sur la carte.';
        }
        return null;
      case 2:
        if (_titleController.text.trim().length < 5) {
          return 'Le titre doit comporter au moins 5 caracteres.';
        }
        if (_descriptionController.text.trim().length < 20) {
          return 'Decrivez le logement en au moins 20 caracteres.';
        }
        return null;
      case 4:
        if (_newPhotos.isEmpty && _existingPhotos.isEmpty) {
          return 'Ajoutez au moins une photo.';
        }
        return null;
      case 5:
        final price = int.tryParse(_priceController.text.trim()) ?? 0;
        if (price < AppConstants.minPrice) {
          return 'Le loyer doit etre d\'au moins '
              '${AppConstants.formatPrice(AppConstants.minPrice)}.';
        }
        if (price > AppConstants.maxPrice) {
          return 'Le loyer saisi depasse le maximum autorise.';
        }
        return null;
      default:
        return null;
    }
  }

  Future<void> _next() async {
    final error = _validateStep(_step);
    if (error != null) {
      _snack(error);
      return;
    }

    if (_step == _stepCount - 1) {
      await _publish();
      return;
    }

    // Sauvegarde discrète du brouillon à chaque étape franchie.
    unawaited(_saveDraft());

    setState(() => _step++);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _previous() {
    if (_step == 0) {
      Navigator.maybePop(context);
      return;
    }
    setState(() => _step--);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  // ── Persistance ─────────────────────────────────────────────────────────

  Property _buildProperty(AuthProvider auth, {required List<String> images}) {
    return Property(
      id: _propertyId ?? '',
      title: _titleController.text.trim(),
      type: _type ?? '',
      description: _descriptionController.text.trim(),
      price: int.tryParse(_priceController.text.trim()) ?? 0,
      address: _addressController.text.trim(),
      quarter: _quarter ?? '',
      city: _city,
      latitude: _latitude,
      longitude: _longitude,
      surface: double.tryParse(_surfaceController.text.trim()) ?? 0,
      rooms: _rooms,
      bathrooms: _bathrooms,
      floor: _floor,
      isFurnished: _isFurnished,
      equipment: _equipment.toList(),
      images: images,
      ownerId: auth.uid!,
      ownerName: auth.user!.name,
      ownerPhotoUrl: auth.user!.photoUrl,
      ownerIsVerified: auth.user!.isVerified,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      status: widget.existing?.status ?? PropertyStatus.draft,
    );
  }

  /// Enregistre l'état courant en brouillon, sans les photos locales.
  ///
  /// Les photos sont envoyées uniquement à la publication : téléverser à
  /// chaque étape gaspillerait la bande passante d'un utilisateur qui n'a pas
  /// encore décidé de publier.
  Future<void> _saveDraft() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) return;

    try {
      final draft = _buildProperty(auth, images: _existingPhotos);
      final id = await PropertyService.instance.save(draft);
      _propertyId ??= id;
    } catch (_) {
      // Le brouillon est un filet de sécurité : son échec ne doit pas
      // interrompre la saisie en cours.
    }
  }

  Future<void> _publish() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) {
      _snack('Connexion requise.');
      return;
    }

    setState(() {
      _saving = true;
      _uploadProgress = 0;
    });

    try {
      // 1. L'identifiant doit exister avant l'envoi des photos : le chemin
      //    Storage l'inclut, et les règles de sécurité s'appuient dessus.
      if (_propertyId == null) {
        final draft = _buildProperty(auth, images: const []);
        _propertyId = await PropertyService.instance.create(draft);
      }

      // 2. Photos.
      var images = List<String>.from(_existingPhotos);
      if (_newPhotos.isNotEmpty) {
        final uploaded = await StorageService.instance.uploadPropertyImages(
          ownerId: auth.uid!,
          propertyId: _propertyId!,
          files: _newPhotos,
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );
        images = [...images, ...uploaded];
      }

      // 3. Enregistrement complet, puis passage en modération.
      final property = _buildProperty(auth, images: images).copyWith(
        id: _propertyId,
      );
      await PropertyService.instance.update(property);
      await PropertyService.instance.submitForReview(_propertyId!);

      await AnalyticsService.instance.logPublishSubmitted(
        type: _type ?? '',
        price: int.tryParse(_priceController.text.trim()) ?? 0,
        photoCount: images.length,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline,
              size: 42, color: AppTheme.primaryGreen),
          title: Text(
            _isEditing ? 'Annonce mise a jour' : 'Annonce envoyee',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Votre annonce est en cours de verification. Elle sera visible par '
            'les locataires apres validation, generalement sous 24 heures. '
            'Vous recevrez une notification.',
            style: GoogleFonts.inter(fontSize: 14, height: 1.55),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Compris'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _snack('Publication impossible. Verifiez votre connexion et reessayez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ── Rendu ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previous();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saving ? null : _previous,
          ),
          title: Text(
            _isEditing ? 'Modifier l\'annonce' : 'Publier une annonce',
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: _progress(isDark),
          ),
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _stepType(isDark),
              _stepLocation(isDark),
              _stepDetails(isDark),
              _stepEquipment(isDark),
              _stepPhotos(isDark),
              _stepPrice(isDark),
            ],
          ),
        ),
        bottomNavigationBar: _bottomBar(isDark),
      ),
    );
  }

  Widget _progress(bool isDark) {
    const labels = [
      'Type',
      'Lieu',
      'Details',
      'Equipements',
      'Photos',
      'Loyer',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (_step + 1) / _stepCount,
              minHeight: 5,
              backgroundColor:
                  isDark ? AppTheme.cardDark : const Color(0xFFE8ECEA),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Etape ${_step + 1} sur $_stepCount · ${labels[_step]}',
            style: GoogleFonts.inter(
                fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_saving && _uploadProgress > 0 && _uploadProgress < 1) ...[
              LinearProgressIndicator(value: _uploadProgress, minHeight: 3),
              const SizedBox(height: 4),
              Text(
                'Envoi des photos… ${(_uploadProgress * 100).round()} %',
                style: GoogleFonts.inter(
                    fontSize: 11.5, color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _previous,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text('Retour',
                          style: GoogleFonts.inter(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusDefault),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _step == _stepCount - 1
                                ? (_isEditing ? 'Enregistrer' : 'Publier')
                                : 'Continuer',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Étape 1 : type ──────────────────────────────────────────────────────

  Widget _stepType(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _heading('Quel type de bien proposez-vous ?'),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: AppConstants.propertyTypes.map((type) {
            final selected = _type == type;
            return GestureDetector(
              onTap: () => setState(() => _type = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusDefault),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primaryGreen
                        : (isDark
                            ? AppTheme.dividerDark
                            : AppTheme.dividerLight),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_typeIcon(type),
                        size: 26,
                        color: selected
                            ? AppTheme.primaryGreen
                            : Theme.of(context).hintColor),
                    const SizedBox(height: 8),
                    Text(
                      type,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? AppTheme.primaryGreen : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Studio':
        return Icons.single_bed_outlined;
      case 'Appartement':
        return Icons.apartment;
      case 'Villa':
        return Icons.villa_outlined;
      case 'Chambre':
        return Icons.bedroom_parent_outlined;
      case 'Duplex':
        return Icons.stairs_outlined;
      case 'Terrain':
        return Icons.landscape_outlined;
      case 'Bureau':
        return Icons.business_center_outlined;
      default:
        return Icons.house_outlined;
    }
  }

  // ── Étape 2 : localisation ──────────────────────────────────────────────

  Widget _stepLocation(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _heading('Ou se trouve le logement ?'),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _city,
          decoration: const InputDecoration(labelText: 'Ville'),
          items: AppConstants.cities
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _city = v ?? 'Abidjan'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _quarter,
          decoration: const InputDecoration(labelText: 'Quartier'),
          items: AppConstants.popularQuarters
              .map((q) => DropdownMenuItem(value: q, child: Text(q)))
              .toList(),
          onChanged: (v) => setState(() => _quarter = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Adresse ou point de repere',
            hintText: 'Rue, immeuble, reference connue…',
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _heading('Position sur la carte', small: true)),
            TextButton.icon(
              onPressed: _useCurrentPosition,
              icon: const Icon(Icons.my_location, size: 17),
              label: Text('Ma position',
                  style: GoogleFonts.inter(fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Appuyez sur la carte pour placer le logement. La position exacte '
          'n\'est visible que sur la fiche de l\'annonce.',
          style: GoogleFonts.inter(
              fontSize: 12, height: 1.45, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          child: SizedBox(
            height: 260,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _latitude ?? LocationService.abidjanLat,
                  _longitude ?? LocationService.abidjanLng,
                ),
                zoom: _latitude == null ? 11.5 : 16,
              ),
              markers: (_latitude == null || _longitude == null)
                  ? const {}
                  : {
                      Marker(
                        markerId: const MarkerId('selection'),
                        position: LatLng(_latitude!, _longitude!),
                        draggable: true,
                        onDragEnd: (pos) => _setPosition(
                            pos.latitude, pos.longitude, geocode: true),
                      ),
                    },
              onMapCreated: (c) => _mapController = c,
              onTap: (pos) =>
                  _setPosition(pos.latitude, pos.longitude, geocode: true),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
        ),
        if (_latitude != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 16, color: AppTheme.primaryGreen),
              const SizedBox(width: 7),
              Text(
                'Position enregistree',
                style: GoogleFonts.inter(
                    fontSize: 12.5, color: AppTheme.primaryGreen),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _setPosition(double lat, double lng,
      {bool geocode = false}) async {
    setState(() {
      _latitude = lat;
      _longitude = lng;
    });

    // Pré-remplissage de l'adresse si l'utilisateur ne l'a pas déjà saisie :
    // écraser sa saisie serait plus agaçant qu'utile.
    if (geocode && _addressController.text.trim().isEmpty) {
      final address =
          await LocationService.instance.addressFromCoordinates(lat, lng);
      if (address != null && mounted) _addressController.text = address;
    }
  }

  Future<void> _useCurrentPosition() async {
    final result = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final latitude, :final longitude):
        await _setPosition(latitude, longitude, geocode: true);
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 16),
        );
      case LocationServiceDisabled():
        _snack('Activez la localisation de votre appareil.');
      case LocationDenied(:final permanently):
        _snack(permanently
            ? 'Autorisez la localisation dans les reglages de l\'application.'
            : 'Autorisation de localisation refusee.');
      case LocationFailure():
        _snack('Position indisponible.');
    }
  }

  // ── Étape 3 : détails ───────────────────────────────────────────────────

  Widget _stepDetails(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _heading('Decrivez le logement'),
        const SizedBox(height: 20),
        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Titre de l\'annonce',
            hintText: 'Appartement 3 pieces — Cocody Angre',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 6,
          maxLength: AppConstants.maxDescriptionLength,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Etat, environnement, proximites, conditions…',
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _surfaceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Surface',
            suffixText: 'm²',
          ),
        ),
        const SizedBox(height: 20),
        _counter('Nombre de pieces', _rooms, 1, 20,
            (v) => setState(() => _rooms = v)),
        _counter('Salles d\'eau', _bathrooms, 1, 10,
            (v) => setState(() => _bathrooms = v)),
        _counter('Etage', _floor, 0, 30, (v) => setState(() => _floor = v)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isFurnished,
          activeThumbColor: AppTheme.primaryGreen,
          title: Text('Logement meuble',
              style: GoogleFonts.inter(fontSize: 14.5)),
          onChanged: (v) => setState(() => _isFurnished = v),
        ),
      ],
    );
  }

  Widget _counter(String label, int value, int min, int max,
      ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.inter(fontSize: 14.5)),
          ),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 24),
            color: AppTheme.primaryGreen,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline, size: 24),
            color: AppTheme.primaryGreen,
          ),
        ],
      ),
    );
  }

  // ── Étape 4 : équipements ───────────────────────────────────────────────

  Widget _stepEquipment(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _heading('Quels equipements sont disponibles ?'),
        const SizedBox(height: 6),
        Text(
          'Facultatif, mais les annonces detaillees recoivent nettement plus '
          'de contacts.',
          style: GoogleFonts.inter(
              fontSize: 12.5, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppConstants.equipmentList.map((item) {
            final selected = _equipment.contains(item);
            return FilterChip(
              label: Text(item, style: GoogleFonts.inter(fontSize: 13)),
              selected: selected,
              selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.18),
              checkmarkColor: AppTheme.primaryGreen,
              onSelected: (v) => setState(() {
                if (v) {
                  _equipment.add(item);
                } else {
                  _equipment.remove(item);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Étape 5 : photos ────────────────────────────────────────────────────

  Widget _stepPhotos(bool isDark) {
    final total = _existingPhotos.length + _newPhotos.length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _heading('Ajoutez des photos'),
        const SizedBox(height: 6),
        Text(
          'La premiere photo servira de couverture. $total/'
          '${AppConstants.maxPhotos} ajoutees.',
          style: GoogleFonts.inter(
              fontSize: 12.5, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: total >= AppConstants.maxPhotos
                    ? null
                    : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 19),
                label: Text('Galerie',
                    style: GoogleFonts.inter(fontSize: 13.5)),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    total >= AppConstants.maxPhotos ? null : _pickFromCamera,
                icon: const Icon(Icons.photo_camera_outlined, size: 19),
                label: Text('Appareil photo',
                    style: GoogleFonts.inter(fontSize: 13.5)),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (total == 0)
          Container(
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              border: Border.all(
                color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    size: 36, color: Theme.of(context).disabledColor),
                const SizedBox(height: 10),
                Text('Aucune photo',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Theme.of(context).hintColor)),
              ],
            ),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              ..._existingPhotos.asMap().entries.map(
                    (e) => _photoTile(
                      child: CachedNetworkImage(
                          imageUrl: e.value, fit: BoxFit.cover),
                      isCover: e.key == 0,
                      onRemove: () =>
                          setState(() => _existingPhotos.removeAt(e.key)),
                    ),
                  ),
              ..._newPhotos.asMap().entries.map(
                    (e) => _photoTile(
                      child: Image.file(e.value, fit: BoxFit.cover),
                      isCover: _existingPhotos.isEmpty && e.key == 0,
                      onRemove: () =>
                          setState(() => _newPhotos.removeAt(e.key)),
                    ),
                  ),
            ],
          ),
      ],
    );
  }

  Widget _photoTile({
    required Widget child,
    required bool isCover,
    required VoidCallback onRemove,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: child,
        ),
        if (isCover)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Couverture',
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFromGallery() async {
    final remaining =
        AppConstants.maxPhotos - _existingPhotos.length - _newPhotos.length;
    final files = await StorageService.instance.pickImages(limit: remaining);
    if (files.isNotEmpty) setState(() => _newPhotos.addAll(files));
  }

  Future<void> _pickFromCamera() async {
    final file = await StorageService.instance.pickCamera();
    if (file != null) setState(() => _newPhotos.add(file));
  }

  // ── Étape 6 : loyer ─────────────────────────────────────────────────────

  Widget _stepPrice(bool isDark) {
    final price = int.tryParse(_priceController.text.trim()) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _heading('Quel est le loyer mensuel ?'),
        const SizedBox(height: 20),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Loyer mensuel',
            suffixText: 'FCFA',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (price > 0) ...[
          const SizedBox(height: 10),
          Text(
            AppConstants.formatPricePerMonth(price),
            style: GoogleFonts.inter(
                fontSize: 14, color: AppTheme.primaryGreen),
          ),
        ],
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.secondaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gavel_outlined,
                  size: 20, color: AppTheme.secondaryOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'En publiant, vous certifiez etre en droit de louer ce '
                  'logement et que les informations fournies sont exactes. '
                  'Toute annonce frauduleuse entraine la suppression du '
                  'compte.',
                  style: GoogleFonts.inter(fontSize: 12.5, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _recap(isDark),
      ],
    );
  }

  Widget _recap(bool isDark) {
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: Theme.of(context).hintColor)),
              ),
              Expanded(
                child: Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recapitulatif',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          line('Type', _type ?? '—'),
          line('Localisation', '${_quarter ?? '—'}, $_city'),
          line('Pieces', '$_rooms piece(s), $_bathrooms salle(s) d\'eau'),
          line('Meuble', _isFurnished ? 'Oui' : 'Non'),
          line('Equipements',
              _equipment.isEmpty ? 'Aucun' : '${_equipment.length} selectionne(s)'),
          line('Photos',
              '${_existingPhotos.length + _newPhotos.length} photo(s)'),
        ],
      ),
    );
  }

  Widget _heading(String text, {bool small = false}) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: small ? 14 : 19,
        fontWeight: small ? FontWeight.w600 : FontWeight.w700,
        height: 1.3,
      ),
    );
  }
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}
