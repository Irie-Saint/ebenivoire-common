import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';

import '../media_viewer.dart';
import 'rich_text_links.dart';

/// Couleurs et typographie du lecteur, données par chaque app ; par défaut,
/// celles du thème.
class RichHtmlViewStyle {
  const RichHtmlViewStyle({
    this.text,
    this.muted,
    this.accent,
    this.border,
    this.headerSurface,
    this.fontFamily,
    this.headingFontFamily,
    this.fontSize = 15,
    this.lineHeight = 1.6,
  });

  final Color? text, muted, accent, border, headerSurface;
  final String? fontFamily, headingFontFamily;
  final double fontSize, lineHeight;
}

/// Lecteur du HTML écrit par [RichTextEditor] (descriptions produit, CGU,
/// politiques) : titres, listes, citations, alignement, liens, images à leur
/// largeur (en %) qui s'ouvrent en plein écran, séparations, tableaux qui
/// défilent de côté.
///
/// Toujours enveloppé dans une boîte : directement dans un sliver, `Html`
/// prend une hauteur nulle. Seuls les liens http(s), mailto et tel
/// s'ouvrent ([RichTextLinks]).
class RichHtmlView extends StatelessWidget {
  const RichHtmlView({
    required this.html,
    this.style = const RichHtmlViewStyle(),
    super.key,
  });

  final String html;
  final RichHtmlViewStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = style.text ?? scheme.onSurface;
    final muted = style.muted ?? scheme.onSurfaceVariant;
    final accent = style.accent ?? scheme.primary;
    final border = style.border ?? scheme.outlineVariant;
    final headerSurface =
        style.headerSurface ??
        Color.alphaBlend(text.withValues(alpha: .05), scheme.surface);
    final line = LineHeight(style.lineHeight);
    Style heading(double size) => Style(
      fontSize: FontSize(size),
      fontWeight: FontWeight.w700,
      fontFamily: style.headingFontFamily ?? style.fontFamily,
      lineHeight: const LineHeight(1.3),
      margin: Margins.only(top: 16, bottom: 6),
    );
    return SizedBox(
      width: double.infinity,
      child: Html(
        data: html,
        onLinkTap: (url, _, _) => RichTextLinks.open(url),
        style: {
          'body': Style(
            color: text,
            fontSize: FontSize(style.fontSize),
            fontFamily: style.fontFamily,
            lineHeight: line,
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'p': Style(margin: Margins.only(top: 0, bottom: 8)),
          'h1': heading(style.fontSize + 9),
          'h2': heading(style.fontSize + 7),
          'h3': heading(style.fontSize + 3),
          'h4, h5, h6': heading(style.fontSize + 1),
          'ul, ol': Style(
            margin: Margins.only(top: 0, bottom: 8),
            padding: HtmlPaddings.only(left: 22),
          ),
          'li': Style(margin: Margins.only(bottom: 4)),
          'blockquote': Style(
            color: muted,
            fontStyle: FontStyle.italic,
            margin: Margins.symmetric(vertical: 8),
            padding: HtmlPaddings.only(left: 12, top: 2, bottom: 2),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          'blockquote p': Style(margin: Margins.zero),
          'a': Style(
            color: accent,
            textDecoration: TextDecoration.underline,
            textDecorationColor: accent,
          ),
          'code': Style(
            fontFamily: 'monospace',
            backgroundColor: headerSurface,
            fontSize: FontSize(style.fontSize - 1),
          ),
          'hr': Style(
            margin: Margins.symmetric(vertical: 12),
            border: Border(bottom: BorderSide(color: border)),
          ),
          'table': Style(
            border: Border.all(color: border),
            margin: Margins.symmetric(vertical: 8),
          ),
          'th': Style(
            padding: HtmlPaddings.all(8),
            backgroundColor: headerSurface,
            fontWeight: FontWeight.w700,
            border: Border.all(color: border, width: .5),
          ),
          'td': Style(
            padding: HtmlPaddings.all(8),
            border: Border.all(color: border, width: .5),
          ),
          'th p, td p': Style(margin: Margins.zero),
        },
        extensions: [
          TagWrapExtension(
            tagsToWrap: {'table'},
            builder: (child) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
          const TableHtmlExtension(),
          TagExtension(
            tagsToExtend: {'img'},
            builder: (extension) => _RichImage(
              src: extension.attributes['src'] ?? '',
              style: extension.attributes['style'] ?? '',
              muted: muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Image d'un texte riche, à sa largeur en % (sinon toute la largeur) ; un
/// appui l'ouvre en plein écran.
class _RichImage extends StatelessWidget {
  const _RichImage({
    required this.src,
    required this.style,
    required this.muted,
  });

  final String src, style;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    if (src.trim().isEmpty) return const SizedBox.shrink();
    final match = RegExp(r'width\s*:\s*(\d+)\s*%').firstMatch(style);
    final percent = match == null ? null : int.tryParse(match.group(1)!);
    final factor = percent != null && percent > 0 && percent < 100
        ? percent / 100
        : 1.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth * factor
            : null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              key: const Key('rich-view-image'),
              onTap: () => MediaViewer.showImages(context, [src]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: width,
                  child: CachedNetworkImage(
                    imageUrl: src,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const SizedBox(height: 160),
                    errorWidget: (_, _, _) => SizedBox(
                      height: 80,
                      child: Icon(Icons.broken_image_outlined, color: muted),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
