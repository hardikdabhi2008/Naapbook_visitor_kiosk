import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Hand-rolled string table for English / हिन्दी / ગુજરાતી.
///
/// Chosen over gen-l10n/ARB to keep the assessment build free of codegen. A
/// unit test asserts every key exists in every language.
class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static const supported = [Locale('en'), Locale('hi'), Locale('gu')];
  static const delegate = _AppStringsDelegate();

  static const languageNames = {
    'en': 'English',
    'hi': 'हिन्दी',
    'gu': 'ગુજરાતી',
  };

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      AppStrings(const Locale('en'));

  /// Looks up [key]; `{name}` placeholders are replaced from [args].
  String t(String key, [Map<String, Object> args = const {}]) {
    var s = table[locale.languageCode]?[key] ?? table['en']![key] ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  @visibleForTesting
  static const table = <String, Map<String, String>>{
    'en': _en,
    'hi': _hi,
    'gu': _gu,
  };
}

extension AppStringsContext on BuildContext {
  String tr(String key, [Map<String, Object> args = const {}]) =>
      AppStrings.of(this).t(key, args);
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings.languageNames.containsKey(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}

const _en = <String, String>{
  'app_title': 'Naapbooks Visitor Kiosk',
  'nav_checkin': 'Check-in',
  'nav_visitors': 'Visitors',
  'nav_admin': 'Admin',
  'hosts_title': 'Host directory',
  'search_hosts': 'Search by name or department',
  'clear_search': 'Clear search',
  'no_hosts': 'No hosts match your search.',
  'host_count': '{n} hosts',
  'available': 'Available',
  'unavailable': 'Unavailable',
  'floor_label': 'Floor: {f}',
  'retry': 'Retry',
  'loading': 'Loading…',
  'err_network': "Can't reach the server. Check your connection.",
  'err_timeout': 'The request timed out.',
  'err_server': 'The server had a problem. Please retry.',
  'err_unknown': 'Something went wrong.',
  'err_validation': 'Please correct the highlighted details.',
  'err_too_large': 'The photo is too large. Please retake it.',
  'checkin_title': 'Visitor check-in',
  'field_name': 'Full name',
  'field_mobile': 'Mobile number',
  'field_company': 'Company (optional)',
  'field_purpose': 'Purpose of visit',
  'field_host': 'Host',
  'choose_host': 'Choose who you are visiting',
  'change_host': 'Change host',
  'photo': 'Photo (optional)',
  'take_photo': 'Take photo',
  'choose_photo': 'Choose photo',
  'remove_photo': 'Remove photo',
  'photo_preview': 'Visitor photo preview',
  'consent_text':
      'I agree to my details and photo being stored for visitor security.',
  'submit': 'Check in',
  'submitting': 'Checking in…',
  'clear_form': 'Clear form',
  'draft_restored': 'Your unfinished form was restored.',
  'v_name': 'Enter your name (2–80 characters).',
  'v_mobile': 'Enter a valid 10-digit mobile number starting with 6–9.',
  'v_purpose': 'Choose a purpose.',
  'v_host': 'Choose a host.',
  'v_consent': 'Consent is required.',
  'timeout_note':
      "The request timed out — the visitor may already be checked in. Check Today's visitors before trying again.",
  'purposes_failed': "Couldn't load purposes.",
  'badge_title': 'Visitor badge',
  'badge_welcome': "You're checked in",
  'badge_visiting': 'Visiting {host}',
  'badge_code': 'Badge {code}',
  'qr_label': 'QR code for badge {code}',
  'no_photo': 'No photo',
  'returning': 'Returning to home in {n}s',
  'done': 'Done',
  'visitors_title': "Today's visitors",
  'no_visitors': 'No visitors here yet.',
  'filter_all': 'All',
  'status_checked_in': 'Checked in',
  'status_checked_out': 'Checked out',
  'status_expected': 'Expected',
  'checkout': 'Check out',
  'checked_out_snack': '{name} checked out',
  'undo': 'Undo',
  'checkout_failed': "Couldn't check out {name}. Restored to the list.",
  'load_more_failed': "Couldn't load more.",
  'refresh_failed': 'Refresh failed.',
  'admin_title': 'Admin settings',
  'enter_pin': 'Enter 4-digit PIN',
  'wrong_pin': 'Incorrect PIN',
  'brand_colour': 'Brand colour',
  'swatch_label': 'Colour option {n}',
  'theme': 'Appearance',
  'theme_light': 'Light',
  'theme_dark': 'Dark',
  'theme_system': 'System',
  'language': 'Language',
  'idle_timeout': 'Badge idle timeout',
  'seconds_value': '{n} seconds',
  'lock': 'Lock settings',
};

const _hi = <String, String>{
  'app_title': 'Naapbooks विज़िटर कियोस्क',
  'nav_checkin': 'चेक-इन',
  'nav_visitors': 'आगंतुक',
  'nav_admin': 'एडमिन',
  'hosts_title': 'होस्ट सूची',
  'search_hosts': 'नाम या विभाग से खोजें',
  'clear_search': 'खोज साफ़ करें',
  'no_hosts': 'आपकी खोज से कोई होस्ट नहीं मिला।',
  'host_count': '{n} होस्ट',
  'available': 'उपलब्ध',
  'unavailable': 'अनुपलब्ध',
  'floor_label': 'मंज़िल: {f}',
  'retry': 'पुनः प्रयास करें',
  'loading': 'लोड हो रहा है…',
  'err_network': 'सर्वर तक नहीं पहुँच सके। अपना कनेक्शन जाँचें।',
  'err_timeout': 'अनुरोध का समय समाप्त हो गया।',
  'err_server': 'सर्वर में समस्या आई। कृपया पुनः प्रयास करें।',
  'err_unknown': 'कुछ गलत हो गया।',
  'err_validation': 'कृपया दी गई जानकारी सुधारें।',
  'err_too_large': 'फ़ोटो बहुत बड़ी है। कृपया दोबारा लें।',
  'checkin_title': 'विज़िटर चेक-इन',
  'field_name': 'पूरा नाम',
  'field_mobile': 'मोबाइल नंबर',
  'field_company': 'कंपनी (वैकल्पिक)',
  'field_purpose': 'आने का उद्देश्य',
  'field_host': 'होस्ट',
  'choose_host': 'चुनें कि आप किससे मिल रहे हैं',
  'change_host': 'होस्ट बदलें',
  'photo': 'फ़ोटो (वैकल्पिक)',
  'take_photo': 'फ़ोटो लें',
  'choose_photo': 'फ़ोटो चुनें',
  'remove_photo': 'फ़ोटो हटाएँ',
  'photo_preview': 'विज़िटर फ़ोटो पूर्वावलोकन',
  'consent_text':
      'मैं सहमत हूँ कि मेरी जानकारी और फ़ोटो विज़िटर सुरक्षा के लिए सहेजी जाएँ।',
  'submit': 'चेक-इन करें',
  'submitting': 'चेक-इन हो रहा है…',
  'clear_form': 'फ़ॉर्म साफ़ करें',
  'draft_restored': 'आपका अधूरा फ़ॉर्म वापस लाया गया।',
  'v_name': 'अपना नाम दर्ज करें (2–80 अक्षर)।',
  'v_mobile': '6–9 से शुरू होने वाला सही 10 अंकों का मोबाइल नंबर दर्ज करें।',
  'v_purpose': 'उद्देश्य चुनें।',
  'v_host': 'होस्ट चुनें।',
  'v_consent': 'सहमति आवश्यक है।',
  'timeout_note':
      'अनुरोध का समय समाप्त हो गया — विज़िटर चेक-इन हो चुका हो सकता है। दोबारा प्रयास से पहले आज के आगंतुक देखें।',
  'purposes_failed': 'उद्देश्य लोड नहीं हो सके।',
  'badge_title': 'विज़िटर बैज',
  'badge_welcome': 'आप चेक-इन हो गए',
  'badge_visiting': '{host} से मिलने',
  'badge_code': 'बैज {code}',
  'qr_label': 'बैज {code} का QR कोड',
  'no_photo': 'फ़ोटो नहीं',
  'returning': '{n} सेकंड में होम पर लौटेंगे',
  'done': 'पूर्ण',
  'visitors_title': 'आज के आगंतुक',
  'no_visitors': 'यहाँ अभी कोई आगंतुक नहीं।',
  'filter_all': 'सभी',
  'status_checked_in': 'चेक-इन',
  'status_checked_out': 'चेक-आउट',
  'status_expected': 'अपेक्षित',
  'checkout': 'चेक-आउट करें',
  'checked_out_snack': '{name} चेक-आउट हुए',
  'undo': 'पूर्ववत करें',
  'checkout_failed': '{name} को चेक-आउट नहीं कर सके। सूची में वापस रखा गया।',
  'load_more_failed': 'और लोड नहीं हो सका।',
  'refresh_failed': 'रीफ़्रेश विफल रहा।',
  'admin_title': 'एडमिन सेटिंग्स',
  'enter_pin': '4 अंकों का पिन दर्ज करें',
  'wrong_pin': 'गलत पिन',
  'brand_colour': 'ब्रांड रंग',
  'swatch_label': 'रंग विकल्प {n}',
  'theme': 'रूप',
  'theme_light': 'लाइट',
  'theme_dark': 'डार्क',
  'theme_system': 'सिस्टम',
  'language': 'भाषा',
  'idle_timeout': 'बैज निष्क्रियता समय',
  'seconds_value': '{n} सेकंड',
  'lock': 'सेटिंग्स लॉक करें',
};

const _gu = <String, String>{
  'app_title': 'Naapbooks વિઝિટર કિયોસ્ક',
  'nav_checkin': 'ચેક-ઇન',
  'nav_visitors': 'મુલાકાતીઓ',
  'nav_admin': 'એડમિન',
  'hosts_title': 'હોસ્ટ ડિરેક્ટરી',
  'search_hosts': 'નામ અથવા વિભાગથી શોધો',
  'clear_search': 'શોધ સાફ કરો',
  'no_hosts': 'તમારી શોધ સાથે કોઈ હોસ્ટ મળ્યો નથી.',
  'host_count': '{n} હોસ્ટ',
  'available': 'ઉપલબ્ધ',
  'unavailable': 'અનુપલબ્ધ',
  'floor_label': 'માળ: {f}',
  'retry': 'ફરી પ્રયાસ કરો',
  'loading': 'લોડ થઈ રહ્યું છે…',
  'err_network': 'સર્વર સુધી પહોંચી શકાયું નથી. તમારું કનેક્શન તપાસો.',
  'err_timeout': 'વિનંતીનો સમય પૂરો થયો.',
  'err_server': 'સર્વરમાં સમસ્યા આવી. કૃપા કરીને ફરી પ્રયાસ કરો.',
  'err_unknown': 'કંઈક ખોટું થયું.',
  'err_validation': 'કૃપા કરીને દર્શાવેલી વિગતો સુધારો.',
  'err_too_large': 'ફોટો ખૂબ મોટો છે. કૃપા કરીને ફરી લો.',
  'checkin_title': 'વિઝિટર ચેક-ઇન',
  'field_name': 'પૂરું નામ',
  'field_mobile': 'મોબાઇલ નંબર',
  'field_company': 'કંપની (વૈકલ્પિક)',
  'field_purpose': 'મુલાકાતનો હેતુ',
  'field_host': 'હોસ્ટ',
  'choose_host': 'તમે કોને મળી રહ્યા છો તે પસંદ કરો',
  'change_host': 'હોસ્ટ બદલો',
  'photo': 'ફોટો (વૈકલ્પિક)',
  'take_photo': 'ફોટો લો',
  'choose_photo': 'ફોટો પસંદ કરો',
  'remove_photo': 'ફોટો દૂર કરો',
  'photo_preview': 'વિઝિટર ફોટો પૂર્વાવલોકન',
  'consent_text':
      'હું સંમત છું કે મારી વિગતો અને ફોટો મુલાકાતી સુરક્ષા માટે સંગ્રહિત થાય.',
  'submit': 'ચેક-ઇન કરો',
  'submitting': 'ચેક-ઇન થઈ રહ્યું છે…',
  'clear_form': 'ફોર્મ સાફ કરો',
  'draft_restored': 'તમારું અધૂરું ફોર્મ પાછું લાવવામાં આવ્યું.',
  'v_name': 'તમારું નામ દાખલ કરો (2–80 અક્ષર).',
  'v_mobile': '6–9 થી શરૂ થતો સાચો 10 અંકનો મોબાઇલ નંબર દાખલ કરો.',
  'v_purpose': 'હેતુ પસંદ કરો.',
  'v_host': 'હોસ્ટ પસંદ કરો.',
  'v_consent': 'સંમતિ જરૂરી છે.',
  'timeout_note':
      'વિનંતીનો સમય પૂરો થયો — વિઝિટર કદાચ ચેક-ઇન થઈ ગયો હશે. ફરી પ્રયાસ કરતાં પહેલાં આજના મુલાકાતીઓ તપાસો.',
  'purposes_failed': 'હેતુઓ લોડ થઈ શક્યા નહીં.',
  'badge_title': 'વિઝિટર બેજ',
  'badge_welcome': 'તમે ચેક-ઇન થઈ ગયા',
  'badge_visiting': '{host} ને મળવા',
  'badge_code': 'બેજ {code}',
  'qr_label': 'બેજ {code} માટે QR કોડ',
  'no_photo': 'ફોટો નથી',
  'returning': '{n} સેકન્ડમાં હોમ પર પાછા ફરીશું',
  'done': 'પૂર્ણ',
  'visitors_title': 'આજના મુલાકાતીઓ',
  'no_visitors': 'અહીં હજી કોઈ મુલાકાતી નથી.',
  'filter_all': 'બધા',
  'status_checked_in': 'ચેક-ઇન થયેલ',
  'status_checked_out': 'ચેક-આઉટ થયેલ',
  'status_expected': 'અપેક્ષિત',
  'checkout': 'ચેક-આઉટ કરો',
  'checked_out_snack': '{name} ચેક-આઉટ થયા',
  'undo': 'પૂર્વવત્ કરો',
  'checkout_failed': '{name} ને ચેક-આઉટ કરી શકાયા નહીં. યાદીમાં પાછા મૂક્યા.',
  'load_more_failed': 'વધુ લોડ થઈ શક્યું નહીં.',
  'refresh_failed': 'રિફ્રેશ નિષ્ફળ.',
  'admin_title': 'એડમિન સેટિંગ્સ',
  'enter_pin': '4 અંકનો પિન દાખલ કરો',
  'wrong_pin': 'ખોટો પિન',
  'brand_colour': 'બ્રાન્ડ રંગ',
  'swatch_label': 'રંગ વિકલ્પ {n}',
  'theme': 'દેખાવ',
  'theme_light': 'લાઇટ',
  'theme_dark': 'ડાર્ક',
  'theme_system': 'સિસ્ટમ',
  'language': 'ભાષા',
  'idle_timeout': 'બેજ નિષ્ક્રિયતા સમય',
  'seconds_value': '{n} સેકન્ડ',
  'lock': 'સેટિંગ્સ લૉક કરો',
};
