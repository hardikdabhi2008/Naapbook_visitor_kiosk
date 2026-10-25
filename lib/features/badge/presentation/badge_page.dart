import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../checkin/presentation/checkin_providers.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../visitors/presentation/visitor_providers.dart';
import 'badge_content.dart';

/// Shows the badge and returns to the home screen after the idle timeout.
/// Any touch resets the countdown.
class BadgePage extends ConsumerStatefulWidget {
  const BadgePage({super.key});

  @override
  ConsumerState<BadgePage> createState() => _BadgePageState();
}

class _BadgePageState extends ConsumerState<BadgePage> {
  late final int _total;
  late int _left;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _total = ref.read(settingsProvider).idleSeconds;
    _left = _total;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) _finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // no ticks (and no setState) after the page is gone
    super.dispose();
  }

  void _reset() => setState(() => _left = _total);

  void _finish() {
    _timer?.cancel();
    context.go('/checkin');
    ref.read(lastCheckInProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastCheckInProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('badge_title')), automaticallyImplyLeading: false),
      body: last == null
          ? const SizedBox.shrink()
          : Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _reset(),
              child: BadgeContent(
                visitor: last.visitor,
                photo: last.photo,
                photoUrl: last.photo == null && last.visitor.hasPhoto
                    ? ref.read(visitorRepositoryProvider).photoUrl(last.visitor.id)
                    : null,
                secondsLeft: _left < 0 ? 0 : _left,
                totalSeconds: _total,
                onDone: _finish,
              ),
            ),
    );
  }
}
