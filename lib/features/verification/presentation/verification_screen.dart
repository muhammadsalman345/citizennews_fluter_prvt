import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../../location/presentation/location_scope.dart';
import '../data/verification_repository.dart';
import '../domain/verification_models.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _citySearch = TextEditingController();
  final _picker = ImagePicker();

  VerificationRepository? _repository;
  IdentityVerification? _current;
  List<GovernmentIdType> _idTypes = const [];
  String _documentType = '';
  XFile? _front;
  XFile? _back;
  XFile? _selfie;
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  Uint8List? _selfieBytes;
  DateTime? _dateOfBirth;
  bool _initialized = false;
  bool _loading = true;
  bool _busy = false;
  bool _resubmitting = false;
  String? _error;

  GovernmentIdType? get _selectedType {
    for (final type in _idTypes) {
      if (type.type == _documentType) return type;
    }
    return null;
  }

  bool get _requiresBack => _selectedType?.requiresBack ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final client = AuthScope.read(context).service.client;
    if (client == null) {
      setState(() {
        _loading = false;
        _error = 'Supabase is not configured.';
      });
      return;
    }
    _repository = VerificationRepository(client);
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    _citySearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final current = await _repository!.latestForCurrentUser();
      if (!mounted) return;
      _current = current;
      final location = LocationScope.read(context);
      if (location.countryId.isNotEmpty) {
        _idTypes = await _repository!.governmentIdTypes(location.countryId);
        if (_documentType.isEmpty && _idTypes.isNotEmpty) {
          _documentType = _idTypes.first.type;
        }
      }
      if (!mounted) return;
      await AuthScope.read(context).syncFromClient();
    } catch (error) {
      if (mounted) _error = AppError.message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeCountry(String countryId) async {
    setState(() {
      _documentType = '';
      _idTypes = const [];
      _error = null;
    });
    await LocationScope.read(context).selectCountry(countryId);
    try {
      final types = await _repository!.governmentIdTypes(countryId);
      if (!mounted) return;
      setState(() {
        _idTypes = types;
        _documentType = types.isEmpty ? '' : types.first.type;
      });
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    }
  }

  Future<void> _pickDocument(bool front) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      setState(() => _error = 'Choose an image smaller than 5 MB.');
      return;
    }
    setState(() {
      if (front) {
        _front = file;
        _frontBytes = bytes;
      } else {
        _back = file;
        _backBytes = bytes;
      }
      _error = null;
    });
  }

  Future<void> _captureSelfie() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Choose an image smaller than 5 MB.');
      }
      if (mounted) {
        setState(() {
          _selfie = file;
          _selfieBytes = bytes;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    }
  }

  String? _validateNumber(String? raw) {
    final value = (raw ?? '')
        .replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '')
        .toUpperCase();
    if (_documentType == 'cnic' && !RegExp(r'^\d{13}$').hasMatch(value)) {
      return 'Enter the 13-digit CNIC number.';
    }
    if (_documentType == 'passport' &&
        !RegExp(r'^[A-Z0-9]{5,20}$').hasMatch(value)) {
      return 'Enter a valid 5-20 character passport number.';
    }
    if (value.length < 5 || value.length > 32) {
      return 'Enter a valid identity number.';
    }
    return null;
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18),
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year - 13, now.month, now.day),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    final location = LocationScope.read(context);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || location.countryId.isEmpty || location.cityId.isEmpty) {
      setState(() => _error = 'Complete your country, city and ID details.');
      return;
    }
    if (_front == null || (_requiresBack && _back == null) || _selfie == null) {
      setState(() => _error = 'Add the required ID photos and a live selfie.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    String frontPath = '';
    String backPath = '';
    String selfiePath = '';
    var submitted = false;
    try {
      frontPath = await _repository!.uploadPrivate(
        'identity-documents',
        _front!,
      );
      if (_back != null) {
        backPath = await _repository!.uploadPrivate(
          'identity-documents',
          _back!,
        );
      }
      selfiePath = await _repository!.uploadPrivate('selfies', _selfie!);
      await _repository!.submit(
        documentType: _documentType,
        documentNumber: _number.text,
        frontPath: frontPath,
        backPath: backPath,
        selfiePath: selfiePath,
        countryId: location.countryId,
        cityId: location.cityId,
        dateOfBirth: _dateOfBirth,
      );
      submitted = true;
      _clearForm();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (!submitted) {
        await Future.wait([
          _repository!.removeUnreferenced(
            'identity-documents',
            [frontPath, backPath],
          ),
          _repository!.removeUnreferenced('selfies', [selfiePath]),
        ]).catchError((_) => <void>[]);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _number.clear();
    _front = null;
    _back = null;
    _selfie = null;
    _frontBytes = null;
    _backBytes = null;
    _selfieBytes = null;
    _dateOfBirth = null;
    _resubmitting = false;
  }

  @override
  Widget build(BuildContext context) {
    final location = LocationScope.watch(context);
    final session = AuthScope.watch(context);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 90),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _current != null && !_resubmitting
                    ? _statusCard(session)
                    : _verificationForm(location),
          ),
        ),
      ),
    );
  }

  Widget _statusCard(dynamic session) {
    final verification = _current!;
    final approved = verification.status == 'approved';
    final rejected = verification.status == 'rejected';
    final suspended = verification.status == 'suspended';
    final color = approved
        ? AppColors.success
        : rejected || suspended
            ? AppColors.red
            : AppColors.focus;
    final title = switch (verification.status) {
      'approved' => 'Reporter verification approved',
      'rejected' => 'Verification rejected',
      'suspended' => 'Reporter access suspended',
      _ => 'Verification under review',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              approved
                  ? Icons.verified_rounded
                  : rejected || suspended
                      ? Icons.error_outline_rounded
                      : Icons.schedule_rounded,
              size: 58,
              color: color,
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              approved
                  ? 'Your reporter permissions are active.'
                  : rejected
                      ? 'Review the reason below, correct the details and resubmit.'
                      : suspended
                          ? 'Posting and verified chat are unavailable while this account is suspended.'
                          : 'An administrator must review your private documents before you can post news.',
              textAlign: TextAlign.center,
            ),
            if (verification.reason?.isNotEmpty == true ||
                verification.note?.isNotEmpty == true) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: .06),
                  border: Border.all(
                    color: AppColors.red.withValues(alpha: .25),
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  [verification.reason, verification.note]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join('\n\n'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              _Notice(message: _error!, danger: true),
            ],
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (rejected)
                  FilledButton(
                    onPressed: () => setState(() => _resubmitting = true),
                    child: const Text('Resubmit verification'),
                  ),
                if (approved && session.isReporter)
                  FilledButton(
                    onPressed: () => context.go('/report-news'),
                    child: const Text('Post news'),
                  ),
                OutlinedButton(
                  onPressed: _load,
                  child: const Text('Refresh status'),
                ),
                TextButton(
                  onPressed: () => context.go('/account'),
                  child: const Text('Back to account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _verificationForm(dynamic location) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _VerificationHeader(),
          const SizedBox(height: 22),
          _Section(
            number: 1,
            title: 'Identity details',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('verification-country-${location.countryId}'),
                  initialValue: location.countryId.isEmpty
                      ? null
                      : location.countryId,
                  decoration: const InputDecoration(labelText: 'Country'),
                  isExpanded: true,
                  items: [
                    for (final country in location.countries)
                      DropdownMenuItem(
                        value: country.id,
                        child: Text(country.name),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => _changeCountry(value ?? ''),
                  validator: (_) => location.countryId.isEmpty
                      ? 'Choose your country.'
                      : null,
                ),
                const SizedBox(height: 12),
                if (location.countryId.isNotEmpty) ...[
                  if (location.regions.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey('verification-region-${location.regionId}'),
                      initialValue: location.regionId,
                      decoration: const InputDecoration(
                        labelText: 'Region (optional)',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All regions'),
                        ),
                        for (final region in location.regions)
                          DropdownMenuItem(
                            value: region.id,
                            child: Text(region.name),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => location.selectRegion(value ?? ''),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _citySearch,
                    decoration: const InputDecoration(
                      labelText: 'Search city',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: location.searchCities,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('verification-city-${location.cityId}'),
                    initialValue:
                        location.cityId.isEmpty ? null : location.cityId,
                    decoration: const InputDecoration(labelText: 'City'),
                    isExpanded: true,
                    items: [
                      for (final city in location.cities)
                        DropdownMenuItem(
                          value: city.id,
                          child: Text(city.name),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => location.selectCity(value ?? ''),
                    validator: (_) => location.cityId.isEmpty
                        ? 'Choose your city.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  key: ValueKey('verification-id-type-$_documentType'),
                  initialValue:
                      _documentType.isEmpty ? null : _documentType,
                  decoration: const InputDecoration(labelText: 'ID type'),
                  isExpanded: true,
                  items: [
                    for (final type in _idTypes)
                      DropdownMenuItem(
                        value: type.type,
                        child: Text(type.label),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) =>
                          setState(() => _documentType = value ?? ''),
                  validator: (value) => value?.isNotEmpty == true
                      ? null
                      : 'Choose an ID type.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _number,
                  decoration: const InputDecoration(
                    labelText: 'Government ID number',
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: _validateNumber,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _chooseDate,
                  icon: const Icon(Icons.cake_outlined),
                  label: Text(
                    _dateOfBirth == null
                        ? 'Date of birth (optional)'
                        : '${_dateOfBirth!.year.toString().padLeft(4, '0')}-'
                            '${_dateOfBirth!.month.toString().padLeft(2, '0')}-'
                            '${_dateOfBirth!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            number: 2,
            title: 'Private ID photos',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth > 560
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _ImageChoice(
                        label: 'ID front (required)',
                        bytes: _frontBytes,
                        onPressed: _busy ? null : () => _pickDocument(true),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _ImageChoice(
                        label: _requiresBack
                            ? 'ID back (required)'
                            : 'ID back (optional)',
                        bytes: _backBytes,
                        onPressed: _busy ? null : () => _pickDocument(false),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            number: 3,
            title: 'Live selfie',
            child: _ImageChoice(
              label: _selfie == null ? 'Open front camera' : 'Retake selfie',
              bytes: _selfieBytes,
              camera: true,
              onPressed: _busy ? null : _captureSelfie,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _Notice(message: _error!, danger: true),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_outline_rounded),
            label: Text(_busy ? 'Submitting securely...' : 'Send for review'),
          ),
          if (_resubmitting)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _resubmitting = false),
              child: const Text('Cancel resubmission'),
            ),
        ],
      ),
    );
  }
}

class _VerificationHeader extends StatelessWidget {
  const _VerificationHeader();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101826), Color(0xFF26374D)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REPORTER VERIFICATION',
                    style: TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verify your identity',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your documents stay private and are available only to authorised reviewers.',
                    style: TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    child: Text('$number'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      );
}

class _ImageChoice extends StatelessWidget {
  const _ImageChoice({
    required this.label,
    required this.bytes,
    required this.onPressed,
    this.camera = false,
  });

  final String label;
  final Uint8List? bytes;
  final VoidCallback? onPressed;
  final bool camera;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(12),
          minimumSize: const Size.fromHeight(150),
        ),
        child: bytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    camera ? Icons.camera_alt_outlined : Icons.upload_rounded,
                    size: 34,
                    color: AppColors.red,
                  ),
                  const SizedBox(height: 9),
                  Text(label, textAlign: TextAlign.center),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Image.memory(
                      bytes!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      width: double.infinity,
                      color: Colors.black54,
                      padding: const EdgeInsets.all(7),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.danger = false});

  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: danger
              ? AppColors.red.withValues(alpha: .07)
              : AppColors.focus.withValues(alpha: .07),
          border: Border.all(
            color: (danger ? AppColors.red : AppColors.focus)
                .withValues(alpha: .25),
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(message),
      );
}
