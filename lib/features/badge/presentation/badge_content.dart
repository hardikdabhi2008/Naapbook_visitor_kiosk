import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../visitors/domain/visitor.dart';

/// Pure presentation of the badge, so it can be golden-tested without a
/// network, timers or providers.
class BadgeContent extends StatelessWidget {
  const BadgeContent({
    super.key,
    required this.visitor,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onDone,
    this.photo,
    this.photoUrl,
  });

  final Visitor visitor;
  final Uint8List? photo;
  final String? photoUrl;
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhotoBox(photo: photo, photoUrl: photoUrl, label: visitor.name),
        const SizedBox(height: 16),
        Text(visitor.name, style: theme.textTheme.headlineMedium),
        if ((visitor.company ?? '').isNotEmpty)
          Text(visitor.company!, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(context.tr('badge_visiting', {'host': visitor.hostName}),
            style: theme.textTheme.titleMedium),
      ],
    );

    final qr = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          image: true,
          label: context.tr('qr_label', {'code': visitor.badgeCode}),
          child: Container(
            color: Colors.white, // QR needs a light quiet zone, even in dark mode
            padding: const EdgeInsets.all(12),
            child: ExcludeSemantics(
              child: QrImageView(
                data: visitor.badgeCode,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(context.tr('badge_code', {'code': visitor.badgeCode}),
            style: theme.textTheme.titleMedium),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              const _SuccessMark(),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(context.tr('badge_welcome'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(builder: (context, c) {
                    if (c.maxWidth >= 600) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 24),
                          qr,
                        ],
                      );
                    }
                    return Column(children: [
                      Align(alignment: AlignmentDirectional.centerStart, child: details),
                      const SizedBox(height: 20),
                      qr,
                    ]);
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Text(context.tr('returning', {'n': secondsLeft}),
                  textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: totalSeconds == 0 ? 0 : secondsLeft / totalSeconds,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onDone, child: Text(context.tr('done'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({this.photo, this.photoUrl, required this.label});

  final Uint8List? photo;
  final String? photoUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => Container(
          width: 140,
          height: 140,
          color: scheme.surfaceContainerHighest,
          child: Semantics(
            label: context.tr('no_photo'),
            child: Icon(Icons.person, size: 72, color: scheme.outline),
          ),
        );

    Widget child;
    if (photo != null) {
      child = Image.memory(photo!,
          width: 140, height: 140, fit: BoxFit.cover, semanticLabel: label);
    } else if (photoUrl != null) {
      child = Image.network(photoUrl!,
          width: 140,
          height: 140,
          fit: BoxFit.cover,
          semanticLabel: label,
          errorBuilder: (_, _, _) => placeholder());
    } else {
      child = placeholder();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: child);
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (context, t, child) =>
              Transform.scale(scale: t.clamp(0.0, 1.4), child: child),
          child: Icon(Icons.check_circle,
              size: 72, color: Theme.of(context).colorScheme.primary),
        ),
      );
}
