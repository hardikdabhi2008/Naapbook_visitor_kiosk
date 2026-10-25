
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../hosts/presentation/host_directory.dart';
import '../../visitors/presentation/visitor_providers.dart';
import '../domain/checkin_draft.dart';
import 'checkin_providers.dart';

/// The check-in form.
///
/// [onPickHost] is non-null on phones, where the directory is a separate
/// screen. On tablets the directory sits beside the form and the host field
/// is read-only.
class CheckinForm extends ConsumerStatefulWidget {
  const CheckinForm({super.key, this.onPickHost, this.useHero = false});

  final VoidCallback? onPickHost;
  final bool useHero;

  @override
  ConsumerState<CheckinForm> createState() => _CheckinFormState();
}

class _CheckinFormState extends ConsumerState<CheckinForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _company;
  final _picker = ImagePicker();
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    final d = ref.read(checkinProvider);
    _name = TextEditingController(text: d.name);
    _mobile = TextEditingController(text: d.mobile);
    _company = TextEditingController(text: d.company);
    _recoverLostPhoto();
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _company.dispose();
    super.dispose();
  }

  /// If Android killed the app while the camera was open, the photo comes back
  /// through retrieveLostData() on the next launch.
  Future<void> _recoverLostPhoto() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final lost = await _picker.retrieveLostData();
      final file = lost.file;
      if (file == null || !mounted) return;
      ref.read(checkinProvider.notifier).setPhoto(await file.readAsBytes());
    } catch (_) {/* nothing to recover */}
  }

  void _syncController(TextEditingController c, String value) {
    if (c.text != value) c.text = value; // e.g. after "Clear form" or submit
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      ref.read(checkinProvider.notifier).setPhoto(bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('err_unknown'))));
    }
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    final d = ref.read(checkinProvider);
    final valid = _formKey.currentState!.validate();
    if (!valid || d.purposeId == null || d.hostId == null || !d.consent) return;

    final visitor = await ref.read(submitProvider.notifier).submit();
    // The user may have left the screen while the request was in flight.
    if (!mounted || visitor == null) return;
    context.go('/badge');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(checkinProvider);
    ref.listen(checkinProvider, (_, next) {
      _syncController(_name, next.name);
      _syncController(_mobile, next.mobile);
      _syncController(_company, next.company);
    });
    final submit = ref.watch(submitProvider);
    final notifier = ref.read(checkinProvider.notifier);
    final restored = notifier.restored;
    final scheme = Theme.of(context).colorScheme;

    String? msg(String? key) => key == null ? null : context.tr(key);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(context.tr('checkin_title'),
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
              if (!draft.isEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _attempted = false);
                    notifier.clear();
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: Text(context.tr('clear_form')),
                ),
            ],
          ),
          if (restored && !draft.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(context.tr('draft_restored'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.primary)),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            onChanged: notifier.setName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => msg(Validators.name(v)),
            decoration: InputDecoration(labelText: context.tr('field_name')),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _mobile,
            onChanged: notifier.setMobile,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => msg(Validators.mobile(v)),
            decoration: InputDecoration(
              labelText: context.tr('field_mobile'),
              counterText: '',
              prefixText: '+91 ',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _company,
            onChanged: notifier.setCompany,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: context.tr('field_company')),
          ),
          const SizedBox(height: 16),
          _PurposeField(
            value: draft.purposeId,
            showError: _attempted,
            onChanged: notifier.setPurpose,
          ),
          const SizedBox(height: 16),
          _HostField(
            draft: draft,
            showError: _attempted,
            onPick: widget.onPickHost,
            useHero: widget.useHero,
          ),
          const SizedBox(height: 16),
          _PhotoField(photo: draft.photo, onPick: _pickPhoto, onRemove: () => notifier.setPhoto(null)),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: draft.consent,
            onChanged: (v) => notifier.setConsent(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('consent_text')),
          ),
          if (_attempted && !draft.consent)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(context.tr('v_consent'),
                  style: TextStyle(color: scheme.error)),
            ),
          if (submit.error != null) ...[
            const SizedBox(height: 8),
            _SubmitError(error: submit.error!, onRetry: _submit),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: submit.busy ? null : _submit,
            child: submit.busy
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Flexible(child: Text(context.tr('submitting'))),
                    ],
                  )
                : Text(context.tr('submit')),
          ),
        ],
      ),
    );
  }
}

class _PurposeField extends ConsumerWidget {
  const _PurposeField({required this.value, required this.showError, required this.onChanged});

  final String? value;
  final bool showError;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purposesProvider);
    return async.when(
      loading: () => InputDecorator(
        decoration: InputDecoration(labelText: context.tr('field_purpose')),
        child: const LinearProgressIndicator(),
      ),
      error: (e, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: context.tr('field_purpose'),
          errorText: context.tr('purposes_failed'),
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => ref.invalidate(purposesProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('retry')),
          ),
        ),
      ),
      data: (purposes) => DropdownButtonFormField<String>(
        key: ValueKey(value), // rebuild when the draft is restored/cleared
        initialValue: purposes.any((p) => p.id == value) ? value : null,
        isExpanded: true,
        onChanged: onChanged,
        validator: (v) => showError && v == null ? context.tr('v_purpose') : null,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(labelText: context.tr('field_purpose')),
        items: [
          for (final p in purposes)
            DropdownMenuItem(
              value: p.id,
              child: Text(p.label, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

class _HostField extends StatelessWidget {
  const _HostField({
    required this.draft,
    required this.showError,
    required this.onPick,
    required this.useHero,
  });

  final CheckinDraft draft;
  final bool showError;
  final VoidCallback? onPick;
  final bool useHero;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasHost = draft.hostId != null;
    final error = showError && !hasHost;

    Widget? avatar;
    if (hasHost) {
      final initials = (draft.hostName!)
          .trim()
          .split(RegExp(r'\s+'))
          .take(2)
          .map((p) => p.isEmpty ? '' : p[0])
          .join()
          .toUpperCase();
      avatar = CircleAvatar(child: Text(initials));
      if (useHero) avatar = Hero(tag: hostHeroTag(draft.hostId!), child: avatar);
    }

    return InputDecorator(
      decoration: InputDecoration(
        labelText: context.tr('field_host'),
        errorText: error ? context.tr('v_host') : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: InkWell(
        onTap: onPick,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              if (avatar != null) ...[ExcludeSemantics(child: avatar), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasHost ? draft.hostName! : context.tr('choose_host'),
                      style: hasHost
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (hasHost && draft.hostDepartment != null)
                      Text(draft.hostDepartment!,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (onPick != null)
                Semantics(
                  button: true,
                  label: context.tr(hasHost ? 'change_host' : 'choose_host'),
                  excludeSemantics: true,
                  child: const Icon(Icons.chevron_right),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({required this.photo, required this.onPick, required this.onRemove});

  final Uint8List? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(labelText: context.tr('photo')),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                photo!,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                semanticLabel: context.tr('photo_preview'),
              ),
            )
          else
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ExcludeSemantics(
                  child: Icon(Icons.person, size: 48, color: scheme.outline)),
            ),
          FilledButton.tonalIcon(
            onPressed: onPick,
            icon: Icon(kIsWeb ? Icons.upload_file : Icons.photo_camera),
            label: Text(context.tr(kIsWeb ? 'choose_photo' : 'take_photo')),
          ),
          if (photo != null)
            IconButton(
              tooltip: context.tr('remove_photo'),
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class _SubmitError extends StatelessWidget {
  const _SubmitError({required this.error, required this.onRetry});

  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = <String>[
      switch (error.kind) {
        FailureKind.network => context.tr('err_network'),
        FailureKind.timeout => context.tr('timeout_note'),
        FailureKind.server => context.tr('err_server'),
        FailureKind.validation => context.tr('err_validation'),
        FailureKind.tooLarge => context.tr('err_too_large'),
        _ => context.tr('err_unknown'),
      },
      ...error.fields.values,
    ];
    return Semantics(
      liveRegion: true,
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines)
                Text(l, style: TextStyle(color: scheme.onErrorContainer)),
              // A timed-out POST may have succeeded; the message above tells
              // the guard to check the visitor list before retrying.
              if (error.kind != FailureKind.validation)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.tr('retry')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
