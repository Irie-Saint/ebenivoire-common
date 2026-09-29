import 'dart:convert';

import 'package:flutter_quill/quill_delta.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Texte riche ↔ HTML, repris de l'éditeur riche d'AEECI
/// (`gestion_rich_text.dart`, D062), pour les descriptions produit (vendeur),
/// les CGU et les politiques produit (console).
///
/// Sous-ensemble modifiable dans l'éditeur : paragraphes, titres 2 à 4,
/// listes (imbriquées), citations, alignement, gras, italique, souligné,
/// barré, code, liens, images (avec leur largeur en %), lignes de séparation
/// et tableaux à cellules de texte. Tout autre élément devient un bloc `html`
/// conservé tel quel : rien n'est perdu à l'enregistrement.
///
/// Différences avec AEECI : pas d'identifiant média (`data-media-id`), nos
/// images sont de simples URL ; la largeur d'une image (`style="width:N%"`)
/// est gardée ; du texte sans balise devient des paragraphes.

/// Types d'embed de l'éditeur (en plus de `image`).
const richTextDividerEmbed = 'divider';
const richTextTableEmbed = 'table';
const richTextHtmlEmbed = 'html';

/// Tableau à cellules de texte : `{header, rows}`.
class RichTableData {
  const RichTableData({required this.rows, this.header = true});

  factory RichTableData.decode(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return RichTableData(
      header: json['header'] != false,
      rows: [
        for (final row in (json['rows'] as List? ?? const []))
          [for (final cell in (row as List)) cell.toString()],
      ],
    );
  }

  /// Tableau vierge de l'éditeur du site : 3 × 3 avec ligne d'en-tête.
  factory RichTableData.blank() =>
      RichTableData(rows: List.generate(3, (_) => List.filled(3, '')));

  final List<List<String>> rows;
  final bool header;

  String encode() => jsonEncode({'header': header, 'rows': rows});

  String toHtml() {
    final out = StringBuffer('<table><tbody>');
    for (var r = 0; r < rows.length; r++) {
      out.write('<tr>');
      final tag = header && r == 0 ? 'th' : 'td';
      for (final cell in rows[r]) {
        final lines = cell.split('\n').map(_escape).join('<br>');
        out.write('<$tag><p>$lines</p></$tag>');
      }
      out.write('</tr>');
    }
    out.write('</tbody></table>');
    return out.toString();
  }
}

/// Tableau HTML dont chaque cellule n'est que du texte (sinon `null`).
RichTableData? _simpleTable(dom.Element table) {
  final rows = table.querySelectorAll('tr');
  if (rows.isEmpty) return null;
  const allowed = {'p', 'br', 'span'};
  final data = <List<String>>[];
  var header = true;
  for (var r = 0; r < rows.length; r++) {
    final cells = rows[r].children
        .where((c) => c.localName == 'td' || c.localName == 'th')
        .toList();
    if (cells.isEmpty) return null;
    if (r == 0) header = cells.every((c) => c.localName == 'th');
    final values = <String>[];
    for (final cell in cells) {
      final plain = cell
          .querySelectorAll('*')
          .every(
            (e) =>
                allowed.contains(e.localName) &&
                (e.localName != 'span' ||
                    (e.attributes['style'] ?? '').isEmpty),
          );
      final merged =
          (cell.attributes['colspan'] ?? '1') != '1' ||
          (cell.attributes['rowspan'] ?? '1') != '1';
      if (!plain || merged) return null;
      for (final br in cell.querySelectorAll('br')) {
        br.replaceWith(dom.Text('\n'));
      }
      final paragraphs = cell.querySelectorAll('p');
      final text = paragraphs.isEmpty
          ? cell.text
          : paragraphs.map((p) => p.text).join('\n');
      values.add(text.trim());
    }
    data.add(values);
  }
  final width = data.map((row) => row.length).reduce((a, b) => a > b ? a : b);
  return RichTableData(
    header: header,
    rows: [
      for (final row in data) [...row, ...List.filled(width - row.length, '')],
    ],
  );
}

const _rawTags = {
  'iframe',
  'video',
  'audio',
  'embed',
  'object',
  'pre',
  'figure',
};

/// Éléments conservés tels quels (blocs `html`) plutôt que modifiés.
Set<String> richTextUnsupported(String html) {
  if (html.trim().isEmpty) return const {};
  final fragment = html_parser.parseFragment(html);
  return {
    for (final element in fragment.querySelectorAll('*'))
      if (_rawTags.contains(element.localName) ||
          (element.localName == 'table' &&
              _simpleTable(element.clone(true)) == null))
        element.localName!,
  };
}

Map<String, dynamic> _style(dom.Element element) {
  final attributes = <String, dynamic>{};
  final style = (element.attributes['style'] ?? '').toLowerCase();
  if (RegExp(r'font-weight\s*:\s*(bold|[6-9]00)').hasMatch(style)) {
    attributes['bold'] = true;
  }
  if (RegExp(r'font-style\s*:\s*italic').hasMatch(style)) {
    attributes['italic'] = true;
  }
  if (style.contains('line-through')) attributes['strike'] = true;
  if (style.contains('underline')) attributes['underline'] = true;
  return attributes;
}

/// Largeur d'une image en % (`style="width:N%"`), 1 à 100, sinon `null`.
int? richImageWidth(dom.Element img) {
  final match = RegExp(
    r'width\s*:\s*(\d+)\s*%',
  ).firstMatch(img.attributes['style'] ?? '');
  final width = match == null ? null : int.tryParse(match.group(1)!);
  return width != null && width > 0 && width <= 100 ? width : null;
}

String? _align(dom.Element element) {
  final match = RegExp(
    r'text-align\s*:\s*(center|right|justify)',
  ).firstMatch((element.attributes['style'] ?? '').toLowerCase());
  return match?.group(1);
}

class _DeltaBuilder {
  final delta = Delta();
  var _lineHasContent = false;

  void text(String value, Map<String, dynamic> attributes) {
    if (value.isEmpty) return;
    delta.insert(value, attributes.isEmpty ? null : Map.of(attributes));
    _lineHasContent = true;
    justClosedEmbed = false;
  }

  void image(String src, String? alt, int? width) => embed(
    'image',
    src,
    attributes: {
      if (alt != null && alt.isNotEmpty) 'alt': alt,
      'width': ?width?.toString(),
    },
  );

  /// Bloc sur sa propre ligne (image, séparation, tableau, HTML conservé).
  void embed(String type, String data, {Map<String, dynamic>? attributes}) {
    if (_lineHasContent) newline(const {});
    delta.insert({
      type: data,
    }, attributes == null || attributes.isEmpty ? null : attributes);
    newline(const {});
    justClosedEmbed = true;
  }

  /// Vrai juste après un bloc : le paragraphe qui le contenait est déjà fermé.
  bool justClosedEmbed = false;

  void newline(Map<String, dynamic> attributes) {
    delta.insert('\n', attributes.isEmpty ? null : Map.of(attributes));
    _lineHasContent = false;
    justClosedEmbed = false;
  }

  bool get lineHasContent => _lineHasContent;
}

void _inline(
  _DeltaBuilder out,
  dom.Node node,
  Map<String, dynamic> attributes,
  Map<String, dynamic> block,
) {
  if (node is dom.Text) {
    // Le HTML n'a pas de retour à la ligne significatif dans le texte.
    out.text(node.text.replaceAll(RegExp(r'\s+'), ' '), attributes);
    return;
  }
  if (node is! dom.Element) return;
  final tag = node.localName;
  if (tag == 'br') {
    out.newline(block);
    return;
  }
  if (tag == 'img') {
    final src = node.attributes['src'];
    if (src != null && src.isNotEmpty) {
      out.image(src, node.attributes['alt'], richImageWidth(node));
    }
    return;
  }
  if (_rawTags.contains(tag)) {
    out.embed(richTextHtmlEmbed, node.outerHtml);
    return;
  }
  final next = {...attributes, ..._style(node)};
  switch (tag) {
    case 'strong' || 'b':
      next['bold'] = true;
    case 'em' || 'i':
      next['italic'] = true;
    case 'u':
      next['underline'] = true;
    case 's' || 'strike' || 'del':
      next['strike'] = true;
    case 'code':
      next['code'] = true;
    case 'a':
      final href = node.attributes['href'];
      if (href != null && href.isNotEmpty) next['link'] = href;
  }
  for (final child in node.nodes) {
    _inline(out, child, next, block);
  }
}

void _list(_DeltaBuilder out, dom.Element list, int indent, bool quote) {
  final type = list.localName == 'ol' ? 'ordered' : 'bullet';
  for (final item in list.children.where((e) => e.localName == 'li')) {
    final block = <String, dynamic>{
      'list': type,
      if (indent > 0) 'indent': indent,
      if (quote) 'blockquote': true,
    };
    final nested = <dom.Element>[];
    for (final child in item.nodes) {
      if (child is dom.Element &&
          (child.localName == 'ul' || child.localName == 'ol')) {
        nested.add(child);
      } else if (child is dom.Element && child.localName == 'p') {
        for (final inner in child.nodes) {
          _inline(out, inner, const {}, block);
        }
      } else {
        _inline(out, child, const {}, block);
      }
    }
    out.newline(block);
    for (final sub in nested) {
      _list(out, sub, indent + 1, quote);
    }
  }
}

void _block(_DeltaBuilder out, dom.Node node, {bool quote = false}) {
  if (node is dom.Text) {
    final text = node.text.trim();
    if (text.isEmpty) return;
    out.text(text, const {});
    out.newline({if (quote) 'blockquote': true});
    return;
  }
  if (node is! dom.Element) return;
  final tag = node.localName ?? '';
  final align = _align(node);
  Map<String, dynamic> block(Map<String, dynamic> base) => {
    ...base,
    'align': ?align,
    if (quote) 'blockquote': true,
  };
  switch (tag) {
    case 'p' || 'div':
      if (node.children.any(_isBlockElement)) {
        for (final child in node.nodes) {
          _block(out, child, quote: quote);
        }
        return;
      }
      final attributes = block(const {});
      for (final child in node.nodes) {
        _inline(out, child, const {}, attributes);
      }
      // `<p><img></p>` : le bloc a déjà fermé sa ligne.
      if (out.lineHasContent || !out.justClosedEmbed) {
        out.newline(attributes);
      }
    case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
      final level = int.parse(tag.substring(1)).clamp(2, 4);
      final attributes = block({'header': level});
      for (final child in node.nodes) {
        _inline(out, child, const {}, attributes);
      }
      out.newline(attributes);
    case 'ul' || 'ol':
      _list(out, node, 0, quote);
    case 'blockquote':
      final hasBlocks = node.children.any(_isBlockElement);
      if (hasBlocks) {
        for (final child in node.nodes) {
          _block(out, child, quote: true);
        }
      } else {
        final attributes = {'blockquote': true};
        for (final child in node.nodes) {
          _inline(out, child, const {}, attributes);
        }
        out.newline(attributes);
      }
    case 'img':
      _inline(out, node, const {}, const {});
    case 'hr':
      out.embed(richTextDividerEmbed, 'hr');
    case 'table':
      final table = _simpleTable(node.clone(true));
      out.embed(
        table == null ? richTextHtmlEmbed : richTextTableEmbed,
        table == null ? node.outerHtml : table.encode(),
      );
    case _ when _rawTags.contains(tag):
      out.embed(richTextHtmlEmbed, node.outerHtml);
    default:
      // Élément en ligne au niveau du bloc (ex. `<strong>` isolé) : un paragraphe.
      final attributes = block(const {});
      _inline(out, node, const {}, attributes);
      if (out.lineHasContent) out.newline(attributes);
  }
}

bool _isBlockElement(dom.Element element) => const {
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
  'table',
  'hr',
  ..._rawTags,
}.contains(element.localName);

/// HTML du site → Delta de l'éditeur.
Delta richHtmlToDelta(String html) {
  var source = html.trim();
  if (source.isNotEmpty && !source.contains('<')) {
    // Texte sans balise : un paragraphe par bloc séparé d'une ligne vide.
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
  // Un document Quill se termine toujours par un saut de ligne.
  if (out.delta.isEmpty) out.newline(const {});
  final last = out.delta.last;
  if (last.data is! String || !(last.data as String).endsWith('\n')) {
    out.newline(const {});
  }
  return out.delta;
}

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _inlineHtml(String text, Map<String, dynamic>? attributes) {
  var out = _escape(text);
  final a = attributes ?? const {};
  if (a['code'] == true) out = '<code>$out</code>';
  if (a['strike'] == true) {
    out = '<span style="text-decoration: line-through;">$out</span>';
  }
  if (a['underline'] == true) out = '<u>$out</u>';
  if (a['italic'] == true) out = '<em>$out</em>';
  if (a['bold'] == true) out = '<strong>$out</strong>';
  final link = a['link'];
  if (link is String && link.isNotEmpty) {
    out = '<a href="${_escape(link)}">$out</a>';
  }
  return out;
}

class _Line {
  _Line(this.html, this.attributes, {this.image = false});
  final String html;
  final Map<String, dynamic> attributes;
  final bool image;
}

List<_Line> _lines(Delta delta) {
  final lines = <_Line>[];
  final buffer = StringBuffer();
  var image = false;
  for (final op in delta.toList()) {
    final data = op.data;
    if (data is Map) {
      if (data[richTextDividerEmbed] != null) {
        buffer.write('<hr />');
        image = true;
      } else if (data[richTextTableEmbed] != null) {
        buffer.write(
          RichTableData.decode(data[richTextTableEmbed].toString()).toHtml(),
        );
        image = true;
      } else if (data[richTextHtmlEmbed] != null) {
        buffer.write(data[richTextHtmlEmbed].toString());
        image = true;
      }
      final src = data['image']?.toString();
      if (src != null) {
        final alt = op.attributes?['alt']?.toString() ?? '';
        final width = int.tryParse('${op.attributes?['width'] ?? ''}');
        final style = width != null && width > 0 && width <= 100
            ? ' style="width:$width%"'
            : '';
        buffer.write(
          '<img src="${_escape(src)}" alt="${_escape(alt)}"$style />',
        );
        image = true;
      }
      continue;
    }
    final text = data.toString();
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        buffer.write(_inlineHtml(parts[i], op.attributes));
      }
      if (i < parts.length - 1) {
        lines.add(
          _Line(
            buffer.toString(),
            Map<String, dynamic>.from(op.attributes ?? const {}),
            image: image,
          ),
        );
        buffer.clear();
        image = false;
      }
    }
  }
  if (buffer.isNotEmpty) lines.add(_Line(buffer.toString(), const {}));
  return lines;
}

String _alignStyle(Map<String, dynamic> attributes) {
  final align = attributes['align'];
  return align is String && align != 'left'
      ? ' style="text-align: $align;"'
      : '';
}

String _renderLists(List<_Line> lines) {
  final out = StringBuffer();
  final open = <String>[];
  for (final line in lines) {
    final tag = line.attributes['list'] == 'ordered' ? 'ol' : 'ul';
    final indent = (line.attributes['indent'] as num?)?.toInt() ?? 0;
    while (open.length > indent + 1) {
      out.write('</li></${open.removeLast()}>');
    }
    if (open.length == indent + 1 && open.last != tag) {
      out.write('</li></${open.removeLast()}>');
    }
    if (open.length == indent + 1) {
      out.write('</li>');
    }
    while (open.length < indent + 1) {
      out.write('<$tag>');
      open.add(tag);
    }
    out.write('<li${_alignStyle(line.attributes)}>${line.html}');
  }
  while (open.isNotEmpty) {
    out.write('</li></${open.removeLast()}>');
  }
  return out.toString();
}

String _renderLine(_Line line) {
  final attributes = line.attributes;
  final header = (attributes['header'] as num?)?.toInt();
  if (header != null) {
    final level = header.clamp(2, 4);
    return '<h$level${_alignStyle(attributes)}>${line.html}</h$level>';
  }
  if (line.image && attributes['align'] == null) return line.html;
  return '<p${_alignStyle(attributes)}>${line.html}</p>';
}

String _renderBlocks(List<_Line> lines) {
  final out = StringBuffer();
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (line.attributes['list'] != null) {
      final group = <_Line>[];
      while (i < lines.length && lines[i].attributes['list'] != null) {
        group.add(lines[i++]);
      }
      out.write(_renderLists(group));
      continue;
    }
    out.write(_renderLine(line));
    i++;
  }
  return out.toString();
}

/// Document de l'éditeur → HTML (enregistré tel quel par le serveur, après
/// son nettoyage par liste blanche).
String richDeltaToHtml(Delta delta) {
  final lines = _lines(delta);
  // Dernière ligne vide finale de Quill : pas un paragraphe.
  while (lines.isNotEmpty &&
      lines.last.html.isEmpty &&
      lines.last.attributes.isEmpty) {
    lines.removeLast();
  }
  if (lines.isEmpty) return '';
  final out = StringBuffer();
  var i = 0;
  while (i < lines.length) {
    if (lines[i].attributes['blockquote'] == true) {
      final group = <_Line>[];
      while (i < lines.length && lines[i].attributes['blockquote'] == true) {
        group.add(lines[i++]);
      }
      out.write('<blockquote>${_renderBlocks(group)}</blockquote>');
      continue;
    }
    final group = <_Line>[];
    while (i < lines.length && lines[i].attributes['blockquote'] != true) {
      group.add(lines[i++]);
    }
    out.write(_renderBlocks(group));
  }
  return out.toString();
}

/// Texte brut d'un HTML (contrôle « texte vide », résumés).
String richHtmlPlainText(String html) {
  if (html.trim().isEmpty) return '';
  final buffer = StringBuffer();
  for (final op in richHtmlToDelta(html).toList()) {
    if (op.data is String) buffer.write(op.data);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
