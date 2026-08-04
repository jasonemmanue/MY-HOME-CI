import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';

class PublishPropertyScreen extends StatefulWidget {
  const PublishPropertyScreen({super.key});

  @override
  State<PublishPropertyScreen> createState() => _PublishPropertyScreenState();
}

class _PublishPropertyScreenState extends State<PublishPropertyScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 6;

  // Etat du formulaire
  String? _selectedType;
  final TextEditingController _addressController = TextEditingController();
  String? _selectedQuarter;
  final TextEditingController _surfaceController = TextEditingController();
  final TextEditingController _roomsController = TextEditingController();
  final TextEditingController _bathroomsController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  bool _isFurnished = false;
  final Set<String> _selectedEquipment = {};
  final List<bool> _uploadedPhotos = [true, true, true, false, false, false];
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _cautionController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _addressController.dispose();
    _surfaceController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _floorController.dispose();
    _priceController.dispose();
    _cautionController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _publish() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Annonce publiee avec succes ! Elle sera visible apres validation.',
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Publier une annonce'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'Etape ${_currentStep + 1}/$_totalSteps',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de progression
          _buildProgressBar(),
          // Contenu des etapes
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1TypeDeBien(),
                _buildStep2Localisation(),
                _buildStep3Details(),
                _buildStep4Equipements(),
                _buildStep5Photos(),
                _buildStep6Loyer(),
              ],
            ),
          ),
          // Boutons de navigation
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (_currentStep + 1) / _totalSteps,
          minHeight: 4,
          backgroundColor: AppTheme.dividerLight,
          valueColor:
              const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
        ),
      ),
    );
  }

  // ─── Etape 1 : Type de bien ───

  Widget _buildStep1TypeDeBien() {
    final types = [
      {'name': 'Studio', 'icon': Icons.apartment},
      {'name': 'Appartement', 'icon': Icons.business},
      {'name': 'Villa', 'icon': Icons.villa},
      {'name': 'Chambre', 'icon': Icons.bed},
      {'name': 'Duplex', 'icon': Icons.home_work},
      {'name': 'Terrain', 'icon': Icons.landscape},
      {'name': 'Bureau', 'icon': Icons.work},
      {'name': 'Maison', 'icon': Icons.home},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type de bien',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Quel type de bien souhaitez-vous publier ?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: types.length,
            itemBuilder: (context, index) {
              final type = types[index];
              final isSelected = _selectedType == type['name'] as String;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedType = type['name'] as String);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusDefault),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.dividerLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        size: 32,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondaryLight,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        type['name'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Etape 2 : Localisation ───

  Widget _buildStep2Localisation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Localisation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Ou se situe votre bien ?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Adresse complete',
              hintText: 'Ex: Rue des Jardins, Cocody',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedQuarter,
            decoration: const InputDecoration(
              labelText: 'Quartier',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: AppConstants.popularQuarters
                .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                .toList(),
            onChanged: (value) => setState(() => _selectedQuarter = value),
          ),
          const SizedBox(height: 24),
          // Zone carte placeholder
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              border: Border.all(color: AppTheme.dividerLight),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_rounded,
                  size: 48,
                  color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Placez le repere sur la carte',
                  style: TextStyle(
                    color: AppTheme.textSecondaryLight,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Appuyez pour definir l\'emplacement',
                  style: TextStyle(
                    color: AppTheme.textSecondaryLight.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Etape 3 : Details ───

  Widget _buildStep3Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details du bien',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Decrivez les caracteristiques de votre bien.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _surfaceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Surface (m2)',
              hintText: 'Ex: 85',
              prefixIcon: Icon(Icons.square_foot),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pieces',
                    hintText: 'Ex: 3',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _bathroomsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Salle de bain',
                    hintText: 'Ex: 2',
                    prefixIcon: Icon(Icons.bathtub_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _floorController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Etage',
              hintText: 'Ex: 2 (0 pour RDC)',
              prefixIcon: Icon(Icons.layers_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              border: Border.all(color: AppTheme.dividerLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.chair_outlined,
                        color: AppTheme.textSecondaryLight),
                    const SizedBox(width: 12),
                    const Text(
                      'Meuble',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isFurnished,
                  onChanged: (value) =>
                      setState(() => _isFurnished = value),
                  activeColor: AppTheme.primaryGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Etape 4 : Equipements ───

  Widget _buildStep4Equipements() {
    final equipments = [
      {'name': 'Eau courante', 'icon': Icons.water_drop},
      {'name': 'Electricite', 'icon': Icons.bolt},
      {'name': 'Climatisation', 'icon': Icons.ac_unit},
      {'name': 'Internet/WiFi', 'icon': Icons.wifi},
      {'name': 'Parking', 'icon': Icons.local_parking},
      {'name': 'Gardien', 'icon': Icons.security},
      {'name': 'Piscine', 'icon': Icons.pool},
      {'name': 'Balcon', 'icon': Icons.balcony},
      {'name': 'Cuisine equipee', 'icon': Icons.kitchen},
      {'name': 'Meuble', 'icon': Icons.chair},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Equipements',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Selectionnez les equipements disponibles.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: equipments.map((eq) {
              final name = eq['name'] as String;
              final icon = eq['icon'] as IconData;
              final isSelected = _selectedEquipment.contains(name);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedEquipment.remove(name);
                    } else {
                      _selectedEquipment.add(name);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.dividerLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondaryLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.textPrimaryLight,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Etape 5 : Photos ───

  Widget _buildStep5Photos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez jusqu\'a ${AppConstants.maxPhotos} photos de votre bien.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _uploadedPhotos.length,
            itemBuilder: (context, index) {
              final isUploaded = _uploadedPhotos[index];

              if (isUploaded) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color:
                            AppTheme.primaryGreen.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusDefault),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_rounded,
                          size: 36,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _uploadedPhotos[index] = false);
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Principale',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }

              return GestureDetector(
                onTap: () {
                  setState(() => _uploadedPhotos[index] = true);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusDefault),
                    border: Border.all(
                      color: AppTheme.dividerLight,
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _DashedBorderPainter(),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 28,
                            color: AppTheme.textSecondaryLight,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ajouter',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            '${_uploadedPhotos.where((u) => u).length}/${AppConstants.maxPhotos} photos ajoutees',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Etape 6 : Loyer ───

  Widget _buildStep6Loyer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loyer et conditions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Definissez le montant du loyer et les conditions.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Loyer mensuel (FCFA)',
              hintText: 'Ex: 150 000',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cautionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Caution (FCFA)',
              hintText: 'Ex: 300 000',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _conditionsController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Conditions particulieres',
              hintText:
                  'Ex: Disponible immediatement, animaux non acceptes...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(Icons.description_outlined),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 28),
          // Carte de resume
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              border: Border.all(
                color: AppTheme.primaryGreen.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.preview, size: 20, color: AppTheme.primaryGreen),
                    SizedBox(width: 8),
                    Text(
                      'Resume de l\'annonce',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSummaryRow('Type', _selectedType ?? 'Non defini'),
                _buildSummaryRow(
                    'Adresse', _addressController.text.isEmpty
                        ? 'Non defini'
                        : _addressController.text),
                _buildSummaryRow(
                    'Quartier', _selectedQuarter ?? 'Non defini'),
                _buildSummaryRow(
                    'Surface',
                    _surfaceController.text.isEmpty
                        ? 'Non defini'
                        : '${_surfaceController.text} m2'),
                _buildSummaryRow(
                    'Pieces', _roomsController.text.isEmpty
                        ? 'Non defini'
                        : _roomsController.text),
                _buildSummaryRow(
                    'Meuble', _isFurnished ? 'Oui' : 'Non'),
                _buildSummaryRow(
                    'Equipements',
                    _selectedEquipment.isEmpty
                        ? 'Aucun'
                        : '${_selectedEquipment.length} selectionne(s)'),
                _buildSummaryRow(
                    'Photos',
                    '${_uploadedPhotos.where((u) => u).length} photo(s)'),
                _buildSummaryRow(
                    'Loyer',
                    _priceController.text.isEmpty
                        ? 'Non defini'
                        : '${_priceController.text} FCFA/mois'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation ───

  Widget _buildNavigationButtons() {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(
          top: BorderSide(color: AppTheme.dividerLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Precedent'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: isLastStep ? _publish : _nextStep,
              style: isLastStep
                  ? ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                    )
                  : null,
              child: Text(isLastStep ? 'Publier' : 'Suivant'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Peintre de bordure en pointilles
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Simple placeholder - pas de peinture custom necessaire
    // La bordure est geree par le Container parent
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
