import 'package:flutter/material.dart';

import '../error/api_exception.dart';
import '../l10n/app_strings.dart';

String failureText(BuildContext context, Object error) {
  final key = switch (ApiException.from(error).kind) {
    FailureKind.network => 'err_network',
    FailureKind.timeout => 'err_timeout',
    FailureKind.server => 'err_server',
    FailureKind.validation => 'err_validation',
    FailureKind.tooLarge => 'err_too_large',
    _ => 'err_unknown',
  };
  return context.tr(key);
}

/// Centered message that stays scrollable, so it never overflows at large text
/// scales and still supports pull-to-refresh when placed in a RefreshIndicator.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(icon,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(message, textAlign: TextAlign.center),
                  ),
                  if (onAction != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh),
                      label: Text(actionLabel ?? context.tr('retry')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StateMessage(
        icon: Icons.cloud_off,
        message: failureText(context, error),
        onAction: onRetry,
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: context.tr('loading'),
          liveRegion: true,
          child: const CircularProgressIndicator(),
        ),
      );
}
