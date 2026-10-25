import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import 'settings_controller.dart';

/// Admin settings behind a 4-digit PIN. The unlocked flag lives in this
/// widget's State, so leaving the tab (or reloading the web page) re-locks it.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) => _unlocked
      ? _Settings(onLock: () => setState(() => _unlocked = false))
      : _PinGate(onUnlocked: () => setState(() => _unlocked = true));
}

class _PinGate extends StatefulWidget {
  const _PinGate({required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  State<_PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<_PinGate> {
  final _controller = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    if (v.length < 4) {
      if (_wrong) setState(() => _wrong = false);
      return;
    }
    if (v == AppConfig.adminPin) {
      widget.onUnlocked();
    } else {
      setState(() => _wrong = true);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(context.tr('admin_title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onChanged,
                decoration: InputDecoration(
                  labelText: context.tr('enter_pin'),
                  counterText: '',
                  errorText: _wrong ? context.tr('wrong_pin') : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.onLock});
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Widget section(String key, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(context.tr(key), style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(context.tr('admin_title'),
                  style: theme.textTheme.headlineSmall),
            ),
            TextButton.icon(
              onPressed: onLock,
              icon: const Icon(Icons.lock),
              label: Text(context.tr('lock')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        section(
          'brand_colour',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < AppTheme.brandChoices.length; i++)
                _Swatch(
                  color: AppTheme.brandChoices[i],
                  label: context.tr('swatch_label', {'n': i + 1}),
                  selected: s.brandColor.toARGB32() == AppTheme.brandChoices[i].toARGB32(),
                  onTap: () => c.setBrandColor(AppTheme.brandChoices[i]),
                ),
            ],
          ),
        ),
        section(
          'theme',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (mode, key) in const [
                (ThemeMode.light, 'theme_light'),
                (ThemeMode.dark, 'theme_dark'),
                (ThemeMode.system, 'theme_system'),
              ])
                ChoiceChip(
                  label: Text(context.tr(key)),
                  selected: s.themeMode == mode,
                  onSelected: (_) => c.setThemeMode(mode),
                ),
            ],
          ),
        ),
        section(
          'language',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in AppStrings.languageNames.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: s.languageCode == e.key,
                  onSelected: (_) => c.setLanguage(e.key),
                ),
            ],
          ),
        ),
        section(
          'idle_timeout',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('seconds_value', {'n': s.idleSeconds}),
                  style: theme.textTheme.bodyLarge),
              Slider(
                min: AppConfig.minIdleSeconds.toDouble(),
                max: AppConfig.maxIdleSeconds.toDouble(),
                divisions: (AppConfig.maxIdleSeconds - AppConfig.minIdleSeconds) ~/ 5,
                value: s.idleSeconds.toDouble(),
                label: '${s.idleSeconds}',
                semanticFormatterCallback: (v) =>
                    context.tr('seconds_value', {'n': v.round()}),
                onChanged: (v) => c.setIdleSeconds((v / 5).round() * 5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected ? const Icon(Icons.check, color: Colors.white) : null,
        ),
      ),
    );
  }
}
