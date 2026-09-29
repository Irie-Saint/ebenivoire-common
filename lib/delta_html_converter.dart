import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:parchment/parchment.dart';

/// Texte riche ↔ HTML : descriptions produit (vendeur), CGU et politiques
/// produit (console). Même approche que l'éditeur riche d'AEECI : un vrai
/// analyseur HTML à l'aller, une construction ligne par ligne au retour.
class DeltaHtmlConverter {
  /// Normalize HTML for comparison purposes
  /// Strips CSS classes, styles, and normalizes structure to compare content only
  static String normalizeHtmlForComparison(String html) {
    if (html.isEmpty) return '';

    String normalized = html;

    // Remove CSS classes
    normalized = normalized.replaceAll(RegExp(r'\s+class="[^"]*"'), '');

    // Remove inline styles
    normalized = normalized.replaceAll(RegExp(r'\s+style="[^"]*"'), '');

    // Remove other common attributes (width, height, alt with content)
    normalized = normalized.replaceAll(RegExp(r'\s+width="[^"]*"'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+height="[^"]*"'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+alt="[^"]*"'), '');

    // Normalize image tags - keep only src
    normalized = normalized.replaceAllMapped(
      RegExp(r'<img[^>]*src="([^"]+)"[^>]*/?>', caseSensitive: false),
      (match) => '<img src="${match.group(1)}" />',
    );

    // Remove empty list items
    normalized = normalized.replaceAll(RegExp(r'<li>\s*</li>'), '');

    // Remove <br> tags (they're often inconsistent)
    normalized = normalized.replaceAll(RegExp(r'<br\s*/?>'), ' ');

    // Normalize whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    // Remove whitespace between tags
    normalized = normalized.replaceAll(RegExp(r'>\s+<'), '><');

    // Trim
    normalized = normalized.trim();

    return normalized;
  }

  /// Compare two HTML strings for semantic equality
  /// Returns true if they have the same content (ignoring formatting differences)
  static bool htmlContentEquals(String html1, String html2) {
    final normalized1 = normalizeHtmlForComparison(html1);
    final normalized2 = normalizeHtmlForComparison(html2);
    return normalized1 == normalized2;
  }

  /// Document de l'éditeur → HTML (description produit, CGU, politiques).
  ///
  /// Construit LIGNE par ligne (comme l'éditeur riche d'AEECI) : aucun bloc
  /// vide n'est fabriqué. L'ancienne version écrivait `<h2></h2>` et
  /// `<li></li>` en trop : chaque enregistrement ajoutait des titres et des
  /// puces vides à la description.
  static String deltaToHtml(ParchmentDocument document) {
    try {
      final lines = _lines(document.toDelta());
      while (lines.isNotEmpty &&
          lines.last.html.isEmpty &&
          !lines.last.embed &&
          lines.last.attributes.isEmpty) {
        lines.removeLast();
      }
      if (lines.isEmpty) return '';
      final out = StringBuffer();
      var i = 0;
      while (i < lines.length) {
        final block = lines[i].attributes['block'];
        if (block == 'ul' || block == 'ol') {
          out.write('<$block>');
          while (i < lines.length && lines[i].attributes['block'] == block) {
            final line = lines[i++];
            // Une puce vide (retour à la ligne en fin de liste) n'est pas
            // un élément.
            if (line.html.isNotEmpty) {
              out.write('<li${_alignStyle(line.attributes)}>${line.html}</li>');
            }
          }
          out.write('</$block>');
          continue;
        }
        if (block == 'quote') {
          out.write('<blockquote>');
          while (i < lines.length && lines[i].attributes['block'] == 'quote') {
            final line = lines[i++];
            if (line.html.isNotEmpty) out.write('<p>${line.html}</p>');
          }
          out.write('</blockquote>');
          continue;
        }
        out.write(_renderLine(lines[i++]));
      }
      return out.toString();
    } catch (e) {
      debugPrint('Error converting Delta to HTML: $e');
      return '';
    }
  }

  /// HTML → document de l'éditeur, par un VRAI analyseur (paquet `html`),
  /// plus d'expressions régulières : le gras d'un seul mot reste sur ce mot
  /// (avant, tout le paragraphe passait en gras), les listes, titres,
  /// citations et images se relisent tels qu'ils ont été écrits.
  static ParchmentDocument htmlToDelta(String html) {
    try {
      var source = html.trim();
      if (source.isEmpty) return ParchmentDocument();
      if (!source.contains('<')) {
        // Texte brut : un paragraphe par bloc séparé d'une ligne vide.
        source = source
            .split(RegExp(r'\n\s*\n'))
            .where((p) => p.trim().isNotEmpty)
            .map((p) => '<p>${_escape(p.trim()).replaceAll('\n', '<br>')}</p>')
            .join();
      }
      final out = _DeltaBuilder();
      for (final node in html_parser.parseFragment(source).nodes) {
        _block(out, node);
      }
      if (out.delta.isEmpty) out.newline(const {});
      final last = out.delta.last;
      if (last.data is! String || !(last.data as String).endsWith('\n')) {
        out.newline(const {});
      }
      return ParchmentDocument.fromDelta(out.delta);
    } catch (e) {
      debugPrint('Error converting HTML to Delta: $e');
      final plain = html_parser.parseFragment(html).text ?? '';
      return ParchmentDocument.fromDelta(Delta()..insert('${plain.trim()}\n'));
    }
  }

  // --- HTML → document ------------------------------------------------------

  static const _blockTags = {
    'p',
    'div',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'ul',
    'ol',
    'blockquote',
    'pre',
    'hr',
    'table',
  };

  static bool _isBlock(dom.Element e) => _blockTags.contains(e.localName);

  static String? _alignOf(dom.Element e) => RegExp(
    r'text-align\s*:\s*(center|right|justify)',
  ).firstMatch((e.attributes['style'] ?? '').toLowerCase())?.group(1);

  static Map<String, dynamic> _styleOf(dom.Element e) {
    final style = (e.attributes['style'] ?? '').toLowerCase();
    return {
      if (RegExp(r'font-weight\s*:\s*(bold|[6-9]00)').hasMatch(style))
        'b': true,
      if (RegExp(r'font-style\s*:\s*italic').hasMatch(style)) 'i': true,
      if (style.contains('underline')) 'u': true,
      if (style.contains('line-through')) 's': true,
    };
  }

  static int? _imageWidth(dom.Element img) {
    final match = RegExp(
      r'width\s*:\s*(\d+)\s*%',
    ).firstMatch(img.attributes['style'] ?? '');
    final width = match == null ? null : int.tryParse(match.group(1)!);
    return width != null && width > 0 && width <= 100 ? width : null;
  }

  static void _inline(
    _DeltaBuilder out,
    dom.Node node,
    Map<String, dynamic> attributes,
    Map<String, dynamic> line,
  ) {
    if (node is dom.Text) {
      out.text(node.text.replaceAll(RegExp(r'\s+'), ' '), attributes);
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName;
    if (tag == 'br') {
      out.newline(line);
      return;
    }
    if (tag == 'img') {
      final src = node.attributes['src'];
      if (src != null && src.isNotEmpty) out.image(src, _imageWidth(node));
      return;
    }
    final next = {...attributes, ..._styleOf(node)};
    switch (tag) {
      case 'strong' || 'b':
        next['b'] = true;
      case 'em' || 'i':
        next['i'] = true;
      case 'u':
        next['u'] = true;
      case 's' || 'strike' || 'del':
        next['s'] = true;
      case 'a':
        final href = node.attributes['href'];
        if (href != null && href.isNotEmpty) next['a'] = href;
    }
    for (final child in node.nodes) {
      _inline(out, child, next, line);
    }
  }

  static void _list(_DeltaBuilder out, dom.Element list) {
    final type = list.localName == 'ol' ? 'ol' : 'ul';
    for (final item in list.children.where((e) => e.localName == 'li')) {
      final line = {'block': type, 'alignment': ?_alignOf(item)};
      final nested = <dom.Element>[];
      for (final child in item.nodes) {
        if (child is dom.Element &&
            (child.localName == 'ul' || child.localName == 'ol')) {
          nested.add(child);
        } else if (child is dom.Element && child.localName == 'p') {
          for (final inner in child.nodes) {
            _inline(out, inner, const {}, line);
          }
        } else {
          _inline(out, child, const {}, line);
        }
      }
      if (out.lineHasContent) out.newline(line);
      // L'éditeur n'imbrique pas : une sous-liste suit à plat.
      for (final sub in nested) {
        _list(out, sub);
      }
    }
  }

  static void _block(_DeltaBuilder out, dom.Node node, {bool quote = false}) {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return;
      out.text(text, const {});
      out.newline({if (quote) 'block': 'quote'});
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName ?? '';
    Map<String, dynamic> line(Map<String, dynamic> base) => {
      ...base,
      'alignment': ?_alignOf(node),
      if (quote) 'block': 'quote',
    };
    switch (tag) {
      case 'p' || 'div' || 'pre':
        if (node.children.any(_isBlock)) {
          for (final child in node.nodes) {
            _block(out, child, quote: quote);
          }
          return;
        }
        final attributes = line(const {});
        for (final child in node.nodes) {
          _inline(out, child, const {}, attributes);
        }
        if (out.lineHasContent || !out.justClosedEmbed) {
          out.newline(attributes);
        }
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final attributes = line({'heading': int.parse(tag.substring(1))});
        for (final child in node.nodes) {
          _inline(out, child, const {}, attributes);
        }
        // Un titre vide n'est pas un titre.
        if (out.lineHasContent) out.newline(attributes);
      case 'ul' || 'ol':
        _list(out, node);
      case 'blockquote':
        if (node.children.any(_isBlock)) {
          for (final child in node.nodes) {
            _block(out, child, quote: true);
          }
        } else {
          const attributes = {'block': 'quote'};
          for (final child in node.nodes) {
            _inline(out, child, const {}, attributes);
          }
          if (out.lineHasContent) out.newline(attributes);
        }
      case 'img':
        _inline(out, node, const {}, const {});
      case 'hr':
        return;
      default:
        final attributes = line(const {});
        _inline(out, node, const {}, attributes);
        if (out.lineHasContent) out.newline(attributes);
    }
  }

  // --- document → HTML ------------------------------------------------------

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _inlineHtml(String text, Map<String, dynamic>? attributes) {
    var out = _escape(text);
    final a = attributes ?? const {};
    if (a['s'] == true) out = '<s>$out</s>';
    if (a['u'] == true) out = '<u>$out</u>';
    if (a['i'] == true) out = '<em>$out</em>';
    if (a['b'] == true) out = '<strong>$out</strong>';
    final link = a['a'];
    if (link is String && link.isNotEmpty) {
      out = '<a href="${_escape(link)}">$out</a>';
    }
    return out;
  }

  /// L'image d'une opération, quel que soit le format (Parchment `_type`,
  /// ou ancien `{image: …}`).
  static (String, int?)? _imageOf(Map data) {
    String? src;
    if (data['_type'] == 'image' || data.containsKey('source')) {
      src = data['source']?.toString();
    } else if (data['image'] is String) {
      src = data['image'] as String;
    } else if (data['image'] is Map) {
      src = (data['image'] as Map)['source']?.toString();
    }
    if (src == null || src.isEmpty) return null;
    final raw = data['width'];
    final width = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    return (src, width != null && width > 0 && width <= 100 ? width : null);
  }

  static List<_Line> _lines(Delta delta) {
    final lines = <_Line>[];
    final buffer = StringBuffer();
    var embed = false;
    for (final op in delta.toList()) {
      final data = op.data;
      if (data is Map) {
        final image = _imageOf(data);
        if (image != null) {
          final (src, width) = image;
          buffer.write(
            width == null
                ? '<img src="${_escape(src)}" alt="" />'
                : '<img src="${_escape(src)}" alt="" style="width:$width%" />',
          );
          embed = true;
        }
        continue;
      }
      final parts = data.toString().split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          buffer.write(_inlineHtml(parts[i], op.attributes));
        }
        if (i < parts.length - 1) {
          lines.add(
            _Line(
              buffer.toString(),
              Map<String, dynamic>.from(op.attributes ?? const {}),
              embed: embed,
            ),
          );
          buffer.clear();
          embed = false;
        }
      }
    }
    if (buffer.isNotEmpty) {
      lines.add(_Line(buffer.toString(), const {}, embed: embed));
    }
    return lines;
  }

  static String _alignStyle(Map<String, dynamic> attributes) {
    final align = attributes['alignment'];
    return align is String && align != 'left'
        ? ' style="text-align: $align;"'
        : '';
  }

  static String _renderLine(_Line line) {
    final heading = (line.attributes['heading'] as num?)?.toInt();
    if (heading != null) {
      if (line.html.isEmpty) return '';
      return '<h$heading${_alignStyle(line.attributes)}>${line.html}</h$heading>';
    }
    if (line.embed && line.attributes['alignment'] == null) return line.html;
    // Une ligne vide garde sa place (espace voulu entre deux paragraphes).
    if (line.html.isEmpty) return '<p><br></p>';
    return '<p${_alignStyle(line.attributes)}>${line.html}</p>';
  }
}

class _Line {
  _Line(this.html, this.attributes, {this.embed = false});

  final String html;
  final Map<String, dynamic> attributes;
  final bool embed;
}

/// Construit le document ligne par ligne.
class _DeltaBuilder {
  final delta = Delta();
  bool _lineHasContent = false;

  /// Vrai juste après une image : sa ligne est déjà fermée.
  bool justClosedEmbed = false;

  bool get lineHasContent => _lineHasContent;

  void text(String value, Map<String, dynamic> attributes) {
    if (value.isEmpty) return;
    // Pas d'espace en début de ligne (indentation du HTML source).
    final text = _lineHasContent ? value : value.trimLeft();
    if (text.isEmpty) return;
    delta.insert(text, attributes.isEmpty ? null : Map.of(attributes));
    _lineHasContent = true;
    justClosedEmbed = false;
  }

  void image(String src, int? width) {
    if (_lineHasContent) newline(const {});
    delta.insert(
      BlockEmbed('image', data: {'source': src, 'width': ?width}).toJson(),
    );
    newline(const {});
    justClosedEmbed = true;
  }

  void newline(Map<String, dynamic> attributes) {
    delta.insert('\n', attributes.isEmpty ? null : Map.of(attributes));
    _lineHasContent = false;
    justClosedEmbed = false;
  }
}
