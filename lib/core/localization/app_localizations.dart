import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_language.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  String text(String key, [Map<String, Object> parameters = const {}]) {
    final language = _catalogs[locale.languageCode] ?? _catalogs['en']!;
    var value = language[key] ?? _catalogs['en']![key] ?? key;
    for (final entry in parameters.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }

  String formatDate(DateTime value, {bool includeTime = false}) {
    final local = value.toLocal();
    final formatter = includeTime
        ? DateFormat.yMMMd(locale.toLanguageTag()).add_jm()
        : DateFormat.yMMMd(locale.toLanguageTag());
    return formatter.format(local);
  }

  String formatNumber(num value, {int maximumFractionDigits = 6}) {
    final formatter = NumberFormat.decimalPattern(locale.toLanguageTag())
      ..maximumFractionDigits = maximumFractionDigits;
    return formatter.format(value);
  }
}

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String key, [Map<String, Object> parameters = const {}]) =>
      l10n.text(key, parameters);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => supportedAppLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _catalogs = <String, Map<String, String>>{
  'en': {
    'nav.home': 'Home',
    'nav.latest': 'Latest',
    'nav.explore': 'Explore',
    'nav.reporters': 'Reporters',
    'nav.postNews': 'Post news',
    'nav.chat': 'Chat',
    'nav.account': 'Account',
    'nav.more': 'More',
    'auth.login': 'Log in',
    'auth.createAccount': 'Create account',
    'language.title': 'Language',
    'language.choose': 'Choose language',
    'language.subtitle': 'Change the language and reading direction used by the app.',
    'legal.policies': 'About and policies',
    'legal.about': 'About',
    'legal.contact': 'Contact',
    'legal.editorial': 'Editorial policy',
    'legal.community': 'Community guidelines',
    'legal.privacy': 'Privacy',
    'legal.terms': 'Terms',
    'legal.corrections': 'Corrections',
    'legal.removal': 'Content removal',
    'legal.copyright': 'Copyright',
    'legal.related': 'Related legal pages',
    'legal.back': 'Back to CitizenNews',
    'network.offline': 'You are offline. Saved news is shown where available.',
    'network.restored': 'Connection restored. News is refreshing.',
  },
  'ur': {
    'nav.home': 'ہوم',
    'nav.latest': 'تازہ ترین',
    'nav.explore': 'تلاش',
    'nav.reporters': 'رپورٹرز',
    'nav.postNews': 'خبر شائع کریں',
    'nav.chat': 'چیٹ',
    'nav.account': 'اکاؤنٹ',
    'nav.more': 'مزید',
    'auth.login': 'لاگ اِن',
    'auth.createAccount': 'اکاؤنٹ بنائیں',
    'language.title': 'زبان',
    'language.choose': 'زبان منتخب کریں',
    'language.subtitle': 'ایپ کی زبان اور پڑھنے کی سمت تبدیل کریں۔',
    'legal.policies': 'تعارف اور پالیسیاں',
    'legal.about': 'تعارف',
    'legal.contact': 'رابطہ',
    'legal.editorial': 'ادارتی پالیسی',
    'legal.community': 'کمیونٹی رہنما اصول',
    'legal.privacy': 'رازداری',
    'legal.terms': 'شرائط',
    'legal.corrections': 'تصحیحات',
    'legal.removal': 'مواد ہٹانا',
    'legal.copyright': 'حقوقِ اشاعت',
    'legal.related': 'متعلقہ قانونی صفحات',
    'legal.back': 'CitizenNews پر واپس جائیں',
    'network.offline': 'آپ آف لائن ہیں۔ دستیاب محفوظ خبریں دکھائی جا رہی ہیں۔',
    'network.restored': 'انٹرنیٹ بحال ہو گیا۔ خبریں تازہ کی جا رہی ہیں۔',
  },
  'ar': {
    'nav.home': 'الرئيسية',
    'nav.latest': 'الأحدث',
    'nav.explore': 'استكشاف',
    'nav.reporters': 'المراسلون',
    'nav.postNews': 'نشر خبر',
    'nav.chat': 'الدردشة',
    'nav.account': 'الحساب',
    'nav.more': 'المزيد',
    'auth.login': 'تسجيل الدخول',
    'auth.createAccount': 'إنشاء حساب',
    'language.title': 'اللغة',
    'language.choose': 'اختر اللغة',
    'language.subtitle': 'غيّر لغة التطبيق واتجاه القراءة.',
    'legal.policies': 'حول والسياسات',
    'legal.about': 'حول',
    'legal.contact': 'اتصل بنا',
    'legal.editorial': 'السياسة التحريرية',
    'legal.community': 'إرشادات المجتمع',
    'legal.privacy': 'الخصوصية',
    'legal.terms': 'الشروط',
    'legal.corrections': 'التصحيحات',
    'legal.removal': 'إزالة المحتوى',
    'legal.copyright': 'حقوق النشر',
    'legal.related': 'صفحات قانونية ذات صلة',
    'legal.back': 'العودة إلى CitizenNews',
    'network.offline': 'أنت غير متصل. يتم عرض الأخبار المحفوظة عند توفرها.',
    'network.restored': 'تمت استعادة الاتصال. جارٍ تحديث الأخبار.',
  },
  'es': {
    'nav.home': 'Inicio',
    'nav.latest': 'Últimas',
    'nav.explore': 'Explorar',
    'nav.reporters': 'Reporteros',
    'nav.postNews': 'Publicar noticia',
    'nav.chat': 'Chat',
    'nav.account': 'Cuenta',
    'nav.more': 'Más',
    'auth.login': 'Iniciar sesión',
    'auth.createAccount': 'Crear cuenta',
    'language.title': 'Idioma',
    'language.choose': 'Elegir idioma',
    'language.subtitle': 'Cambia el idioma y la dirección de lectura de la aplicación.',
    'legal.policies': 'Información y políticas',
    'legal.about': 'Acerca de',
    'legal.contact': 'Contacto',
    'legal.editorial': 'Política editorial',
    'legal.community': 'Normas de la comunidad',
    'legal.privacy': 'Privacidad',
    'legal.terms': 'Términos',
    'legal.corrections': 'Correcciones',
    'legal.removal': 'Retirada de contenido',
    'legal.copyright': 'Derechos de autor',
    'legal.related': 'Páginas legales relacionadas',
    'legal.back': 'Volver a CitizenNews',
    'network.offline': 'Estás sin conexión. Se muestran noticias guardadas cuando están disponibles.',
    'network.restored': 'Conexión restablecida. Actualizando noticias.',
  },
  'fr': {
    'nav.home': 'Accueil',
    'nav.latest': 'Actualités',
    'nav.explore': 'Explorer',
    'nav.reporters': 'Journalistes',
    'nav.postNews': 'Publier une actualité',
    'nav.chat': 'Discussion',
    'nav.account': 'Compte',
    'nav.more': 'Plus',
    'auth.login': 'Se connecter',
    'auth.createAccount': 'Créer un compte',
    'language.title': 'Langue',
    'language.choose': 'Choisir la langue',
    'language.subtitle': 'Modifiez la langue et le sens de lecture de l’application.',
    'legal.policies': 'À propos et politiques',
    'legal.about': 'À propos',
    'legal.contact': 'Contact',
    'legal.editorial': 'Politique éditoriale',
    'legal.community': 'Règles de la communauté',
    'legal.privacy': 'Confidentialité',
    'legal.terms': 'Conditions',
    'legal.corrections': 'Corrections',
    'legal.removal': 'Retrait de contenu',
    'legal.copyright': 'Droits d’auteur',
    'legal.related': 'Pages juridiques associées',
    'legal.back': 'Retour à CitizenNews',
    'network.offline': 'Vous êtes hors ligne. Les actualités enregistrées sont affichées si disponibles.',
    'network.restored': 'Connexion rétablie. Actualisation des actualités.',
  },
  'de': {
    'nav.home': 'Startseite',
    'nav.latest': 'Neueste',
    'nav.explore': 'Entdecken',
    'nav.reporters': 'Reporter',
    'nav.postNews': 'Nachricht veröffentlichen',
    'nav.chat': 'Chat',
    'nav.account': 'Konto',
    'nav.more': 'Mehr',
    'auth.login': 'Anmelden',
    'auth.createAccount': 'Konto erstellen',
    'language.title': 'Sprache',
    'language.choose': 'Sprache wählen',
    'language.subtitle': 'Ändern Sie Sprache und Leserichtung der App.',
    'legal.policies': 'Über uns und Richtlinien',
    'legal.about': 'Über uns',
    'legal.contact': 'Kontakt',
    'legal.editorial': 'Redaktionelle Richtlinie',
    'legal.community': 'Community-Richtlinien',
    'legal.privacy': 'Datenschutz',
    'legal.terms': 'Bedingungen',
    'legal.corrections': 'Korrekturen',
    'legal.removal': 'Entfernung von Inhalten',
    'legal.copyright': 'Urheberrecht',
    'legal.related': 'Zugehörige rechtliche Seiten',
    'legal.back': 'Zurück zu CitizenNews',
    'network.offline': 'Sie sind offline. Gespeicherte Nachrichten werden angezeigt, sofern verfügbar.',
    'network.restored': 'Verbindung wiederhergestellt. Nachrichten werden aktualisiert.',
  },
};
