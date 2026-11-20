// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import '../config/app_config.dart';
import 'seo_metadata.dart';

abstract final class SeoService {
  static const _siteName = 'CitizenNews';
  static const _defaultImagePath = '/images/citizennews-og-default.png';

  static void apply(SeoMetadata metadata) {
    final canonical = _absolute(metadata.path);
    final image = _absoluteImage(metadata.imageUrl);
    final title = metadata.title.contains('CitizenNews')
        ? metadata.title
        : '${metadata.title} | CitizenNews';
    final imageAlt = metadata.imageAlt?.trim().isNotEmpty == true
        ? metadata.imageAlt!.trim()
        : 'CitizenNews verified local reporting network';

    html.document.title = title;
    _metaName('description', metadata.description);
    _metaName('robots', metadata.robots);
    _metaName('googlebot', metadata.robots);
    if (metadata.author?.trim().isNotEmpty == true) {
      _metaName('author', metadata.author!.trim());
    } else {
      _removeName('author');
    }

    _canonical(canonical);
    _metaProperty('og:site_name', _siteName);
    _metaProperty('og:type', metadata.type);
    _metaProperty('og:locale', 'en_US');
    _metaProperty('og:title', title);
    _metaProperty('og:description', metadata.description);
    _metaProperty('og:url', canonical);
    _metaProperty('og:image', image);
    _metaProperty('og:image:secure_url', image);
    _metaProperty('og:image:alt', imageAlt);

    _metaName('twitter:card', 'summary_large_image');
    _metaName('twitter:title', title);
    _metaName('twitter:description', metadata.description);
    _metaName('twitter:image', image);
    _metaName('twitter:image:alt', imageAlt);

    _articleProperty('article:published_time', metadata.publishedAt);
    _articleProperty('article:modified_time', metadata.modifiedAt);
    if (metadata.type == 'article' && metadata.author?.isNotEmpty == true) {
      _metaProperty('article:author', metadata.author!);
    } else {
      _removeProperty('article:author');
    }

    for (final node in html.document.head!
        .querySelectorAll('script[data-citizennews-seo]')) {
      node.remove();
    }
    for (final data in metadata.structuredData) {
      final script = html.ScriptElement()
        ..type = 'application/ld+json'
        ..setAttribute('data-citizennews-seo', '')
        ..text = jsonEncode(data);
      html.document.head!.append(script);
    }
  }

  static String _absolute(String path) {
    final base = AppConfig.webBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final clean = path.split('?').first.split('#').first;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    return '$base${clean.startsWith('/') ? clean : '/$clean'}';
  }

  static String _absoluteImage(String? imageUrl) {
    final value = imageUrl?.trim() ?? '';
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    return _absolute(value.isEmpty ? _defaultImagePath : value);
  }

  static void _canonical(String value) {
    final head = html.document.head!;
    var link = head.querySelector('link[rel="canonical"]') as html.LinkElement?;
    link ??= html.LinkElement()..rel = 'canonical';
    link.href = value;
    if (link.parent == null) head.append(link);
  }

  static void _metaName(String name, String content) {
    final head = html.document.head!;
    var node = head.querySelector('meta[name="$name"]') as html.MetaElement?;
    node ??= html.MetaElement()..name = name;
    node.content = content;
    if (node.parent == null) head.append(node);
  }

  static void _metaProperty(String property, String content) {
    final head = html.document.head!;
    var node = head.querySelector('meta[property="$property"]')
        as html.MetaElement?;
    node ??= html.MetaElement()..setAttribute('property', property);
    node.content = content;
    if (node.parent == null) head.append(node);
  }

  static void _articleProperty(String property, DateTime? value) {
    if (value == null) {
      _removeProperty(property);
    } else {
      _metaProperty(property, value.toUtc().toIso8601String());
    }
  }

  static void _removeName(String name) =>
      html.document.head?.querySelector('meta[name="$name"]')?.remove();

  static void _removeProperty(String property) => html.document.head
      ?.querySelector('meta[property="$property"]')
      ?.remove();
}
