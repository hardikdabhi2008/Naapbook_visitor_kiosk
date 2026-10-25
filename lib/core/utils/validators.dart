/// Pure validators. They return a string-table key (or null when valid) so the
/// message is localised at the widget layer.
class Validators {
  const Validators._();

  static final _mobile = RegExp(r'^[6-9]\d{9}$');

  static String? name(String? v) {
    final n = (v ?? '').trim();
    return n.length < 2 || n.length > 80 ? 'v_name' : null;
  }

  static String? mobile(String? v) =>
      _mobile.hasMatch(v ?? '') ? null : 'v_mobile';

  static String? required(Object? v, String key) => v == null ? key : null;
}
