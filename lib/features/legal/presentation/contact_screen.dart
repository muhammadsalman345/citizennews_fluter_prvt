import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../data/contact_repository.dart';
import 'legal_screen.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  ContactRepository? _repository;
  bool _initialized = false;
  bool _busy = false;
  bool _sent = false;
  bool _validate = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final client = AuthScope.read(context).service.client;
    if (client == null) {
      _error = 'Contact service is not configured.';
      return;
    }
    _repository = ContactRepository(client);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _validate = true;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false) ||
        _repository == null ||
        _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _repository!.send(
        name: _name.text,
        email: _email.text,
        subject: _subject.text,
        message: _message.text,
      );
      if (!mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message received. An editor can review it in the newsroom contact queue.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _contactError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 18 : 32,
                mobile ? 24 : 42,
                mobile ? 18 : 32,
                90,
              ),
              children: [
                const Text(
                  'TALK TO THE NEWSROOM',
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Contact CitizenNews',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  'For an article correction or safety issue, use the report button on the story. For general questions, leave a message for the editorial team.',
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use this form for account support, privacy questions and editorial enquiries. Include the relevant article link or username so the team can identify your concern. Do not include passwords, payment credentials or identity-document images in your message.',
                  style: TextStyle(height: 1.5),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.go('/privacy'),
                    child: const Text('Read the privacy policy'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_sent)
                  _ContactSuccess(
                    another: () => setState(() {
                      _sent = false;
                      _validate = false;
                      _error = null;
                      _subject.clear();
                      _message.clear();
                    }),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _validate
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _name,
                              maxLength: 100,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                              validator: (value) {
                                final length = value?.trim().length ?? 0;
                                return length < 2
                                    ? 'Enter a name between 2 and 100 characters.'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: (value) =>
                                  _validEmail(value?.trim() ?? '')
                                  ? null
                                  : 'Enter a valid email address.',
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _subject,
                              minLines: 1,
                              maxLines: 2,
                              maxLength: 180,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Subject',
                              ),
                              validator: (value) {
                                final length = value?.trim().length ?? 0;
                                return length < 3
                                    ? 'Enter a subject between 3 and 180 characters.'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _message,
                              minLines: 6,
                              maxLines: 12,
                              maxLength: 5000,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Message',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) {
                                final length = value?.trim().length ?? 0;
                                return length < 10
                                    ? 'Enter a message between 10 and 5,000 characters.'
                                    : null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              _ContactError(message: _error!),
                            ],
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _busy || _repository == null
                                  ? null
                                  : _send,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 17,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_outlined),
                              label: Text(
                                _busy ? 'Sending message…' : 'Send message',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                const LegalRelatedLinks(),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(context.tr('legal.back')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactSuccess extends StatelessWidget {
  const _ContactSuccess({required this.another});

  final VoidCallback another;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.success,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Message received',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          const Text(
            'An editor can review it in the newsroom contact queue.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: another,
            child: const Text('Send another message'),
          ),
        ],
      ),
    ),
  );
}

class _ContactError extends StatelessWidget {
  const _ContactError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.red.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.red.withValues(alpha: .2)),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.redDark)),
  );
}

bool _validEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

String _contactError(Object error) {
  final raw = error is PostgrestException ? error.message : error.toString();
  if (RegExp('daily contact limit', caseSensitive: false).hasMatch(raw)) {
    return 'This email has reached the daily contact limit. Try again tomorrow.';
  }
  if (RegExp(
    'complete all contact fields',
    caseSensitive: false,
  ).hasMatch(raw)) {
    return 'Complete all contact fields with a valid email address.';
  }
  return AppError.message(error);
}
