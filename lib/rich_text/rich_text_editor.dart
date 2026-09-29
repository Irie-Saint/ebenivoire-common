import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:get/get.dart';

import 'rich_text_html.dart';
import 'rich_text_links.dart';
import 'rich_text_messages.dart';

/// Texte d'une clé `rich_text.*` : traduction de l'app, sinon le français du
/// paquet (l'éditeur reste lisible même si une app oublie de déclarer les
/// clés).
String richTextTr(String key, [Map<String, String> params = const {}]) {
  var text = key.tr;
  if (text == key) text = richTextMessages['fr']![key] ?? key;
  params.forEach((name, value) => text = text.replaceAll('@$name', value));
  return text;
}

/// Erreur lisible renvoyée par [RichTextEditor.onPickImage] : son message est
/// affiché sous l'éditeur (fichier trop lourd, format refusé…).
class RichTextImageException implements Exception {
  const RichTextImageException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Couleurs et typographie de l'éditeur, données par chaque app (kit vendeur,
/// console) ; par défaut, celles du thème.
class RichTextEditorStyle {
  const RichTextEditorStyle({
    this.accent,
    this.border,
    this.surface,
    this.toolbarSurface,
    this.text,
    this.muted,
    this.danger,
    this.radius = 12,
    this.fontFamily,
    this.headingFontFamily,
    this.fontSize = 14,
  });

  final Color? accent, border, surface, toolbarSurface, text, muted, danger;
  final double radius;
  final String? fontFamily, headingFontFamily;
  final double fontSize;
}

/// Couleurs résolues (style de l'app, sinon thème).
class _Palette {
  _Palette(BuildContext context, RichTextEditorStyle style) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    accent = style.accent ?? scheme.primary;
    border = style.border ?? scheme.outlineVariant;
    surface = style.surface ?? scheme.surface;
    text = style.text ?? scheme.onSurface;
    muted = style.muted ?? scheme.onSurfaceVariant;
    danger = style.danger ?? scheme.error;
    fontSize = style.fontSize;
    toolbar =
        style.toolbarSurface ??
        Color.alphaBlend(text.withValues(alpha: .035), surface);
  }

  late final Color accent, border, surface, text, muted, danger, toolbar;
  late final double fontSize;
}

/// Éditeur de texte riche (repris de `GestionRichTextField` d'AEECI, D062).
///
/// La valeur est du HTML ; tant que rien n'est modifié, [onChanged] n'est pas
/// appelé. Outils : gras, italique, souligné, barré, code ; titres, listes,
/// citation, séparation ; alignements ; lien ; image ([onPickImage]) ;
/// tableau ; annuler / rétablir. Un élément que l'éditeur ne sait pas
/// modifier (vidéo intégrée…) est conservé tel quel.
class RichTextEditor extends StatefulWidget {
  const RichTextEditor({
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.onPickImage,
    this.style = const RichTextEditorStyle(),
    this.minHeight = 180,
    this.maxHeight = 420,
    this.enabled = true,
    this.hasError = false,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder, helperText, errorText;

  /// Choisit et envoie une image, renvoie son URL (`null` : abandon). Sans
  /// lui, l'outil image est masqué. Une [RichTextImageException] affiche son
  /// message sous l'éditeur.
  final Future<String?> Function()? onPickImage;
  final RichTextEditorStyle style;
  final double minHeight, maxHeight;
  final bool enabled;

  /// Cadre en erreur, le message étant affiché par l'app (son propre style).
  final bool hasError;

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late final QuillController _controller = QuillController(
    document: Document.fromDelta(_deltaOf(widget.value)),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: !widget.enabled,
  );
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  StreamSubscription<DocChange>? _changes;

  /// Dernier HTML envoyé par [RichTextEditor.onChanged] : une valeur reçue
  /// qui en diffère vient de l'extérieur (IA, rechargement) et remplace le
  /// document.
  late String _lastHtml;
  bool _uploading = false;
  String? _uploadError;

  static Delta _deltaOf(String html) {
    if (html.trim().isEmpty) return Delta()..insert('\n');
    try {
      final delta = richHtmlToDelta(html);
      return delta.isEmpty ? (Delta()..insert('\n')) : delta;
    } catch (_) {
      return Delta()..insert('\n');
    }
  }

  @override
  void initState() {
    super.initState();
    _lastHtml = widget.value;
    _listen();
    _controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  void _listen() {
    unawaited(_changes?.cancel());
    _changes = _controller.document.changes.listen((change) {
      if (change.source != ChangeSource.local) return;
      _lastHtml = richDeltaToHtml(_controller.document.toDelta());
      widget.onChanged(_lastHtml);
    });
  }

  @override
  void didUpdateWidget(RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.readOnly = !widget.enabled;
    if (widget.value != _lastHtml && widget.value != oldWidget.value) {
      _lastHtml = widget.value;
      _controller.document = Document.fromDelta(_deltaOf(widget.value));
      _listen();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, Attribute> get _selectionStyle =>
      _controller.getSelectionStyle().attributes;

  bool _active(Attribute attribute) {
    final current = _selectionStyle[attribute.key];
    if (current == null) return false;
    return attribute.value == null || current.value == attribute.value;
  }

  void _toggle(Attribute attribute) => _controller.formatSelection(
    _active(attribute) ? Attribute.clone(attribute, null) : attribute,
  );

  int get _cursor => _controller.selection.baseOffset.clamp(
    0,
    _controller.document.length - 1,
  );

  /// Insère un bloc (image, séparation, tableau) sur sa propre ligne : sur
  /// une ligne vide, il la remplit ; sinon il se place juste après la ligne
  /// du curseur (Quill le collerait au texte). Un seul pas d'annulation.
  void _insertBlock(BlockEmbed block) {
    final plain = _controller.document.toPlainText();
    final index = _cursor;
    final lineStart = index == 0 || plain[index - 1] == '\n';
    final emptyLine = lineStart && index < plain.length && plain[index] == '\n';
    final lineEnd = plain.indexOf('\n', index);
    final Delta delta;
    if (emptyLine) {
      delta = Delta()
        ..retain(index)
        ..insert(block.toJson());
    } else if (lineEnd + 1 < plain.length) {
      delta = Delta()
        ..retain(lineEnd + 1)
        ..insert(block.toJson())
        ..insert('\n');
    } else {
      // Dernière ligne : rien ne s'insère après le saut de ligne final. On
      // coupe donc avant lui ; la ligne de texte garde son style (titre,
      // liste), le bloc n'en prend aucun.
      final line = _newlineAttributes(lineEnd);
      delta = Delta()
        ..retain(lineEnd)
        ..insert('\n', line)
        ..insert(block.toJson());
      if (line != null) delta.retain(1, {for (final k in line.keys) k: null});
    }
    final at = emptyLine ? index : lineEnd + 1;
    _controller.compose(
      delta,
      TextSelection.collapsed(offset: at + 1),
      ChangeSource.local,
    );
  }

  /// Attributs de ligne portés par le saut de ligne situé à [offset].
  Map<String, dynamic>? _newlineAttributes(int offset) {
    var position = 0;
    for (final op in _controller.document.toDelta().toList()) {
      final length = op.length ?? 0;
      if (offset < position + length) {
        final attributes = op.attributes;
        return attributes == null || attributes.isEmpty ? null : attributes;
      }
      position += length;
    }
    return null;
  }

  /// Remplace (ou retire, [block] nul) le bloc situé à [offset].
  void _replaceBlock(int offset, BlockEmbed? block) => _controller.replaceText(
    offset,
    1,
    block ?? '',
    TextSelection.collapsed(offset: offset),
  );

  /// Largeur d'une image (en %), `null` ou 100 : toute la largeur.
  void _setImageWidth(int offset, int? width) => _controller.compose(
    Delta()
      ..retain(offset)
      ..retain(1, {
        Attribute.width.key: width == null || width >= 100 ? null : '$width',
      }),
    _controller.selection,
    ChangeSource.local,
  );

  Future<void> _setLink() async {
    final previous = _selectionStyle[Attribute.link.key]?.value?.toString();
    final href = await showDialog<String>(
      context: context,
      builder: (_) => _LinkDialog(initial: previous ?? ''),
    );
    if (href == null || !mounted) return;
    if (href.isEmpty) {
      _controller.formatSelection(Attribute.clone(Attribute.link, null));
      return;
    }
    final selection = _controller.selection;
    if (selection.isCollapsed && previous == null) {
      // Rien de sélectionné : l'adresse elle-même devient le texte du lien.
      final index = _cursor;
      _controller
        ..replaceText(
          index,
          0,
          href,
          TextSelection.collapsed(offset: index + href.length),
        )
        ..formatText(index, href.length, LinkAttribute(href));
      return;
    }
    _controller.formatSelection(LinkAttribute(href));
  }

  Future<void> _pickImage() async {
    final pick = widget.onPickImage;
    if (pick == null) return;
    setState(() {
      _uploading = true;
      _uploadError = null;
    });
    try {
      final url = await pick();
      if (url != null && url.isNotEmpty && mounted) {
        _insertBlock(BlockEmbed.image(url));
      }
    } on RichTextImageException catch (error) {
      if (mounted) setState(() => _uploadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _uploadError = richTextTr('rich_text.image_failed'));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _Palette(context, widget.style);
    final radius = BorderRadius.circular(widget.style.radius);
    final error = widget.errorText ?? _uploadError;
    final invalid = error != null || widget.hasError;
    final borderColor = invalid
        ? palette.danger
        : _focusNode.hasFocus
        ? palette.accent
        : palette.border;
    final note = error ?? (_uploading ? null : widget.helperText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: radius,
            border: Border.all(
              color: borderColor,
              width: _focusNode.hasFocus || invalid ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.enabled) _toolbar(palette),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: widget.minHeight,
                    maxHeight: widget.maxHeight,
                  ),
                  child: QuillEditor(
                    controller: _controller,
                    focusNode: _focusNode,
                    scrollController: _scrollController,
                    config: QuillEditorConfig(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      minHeight: widget.minHeight - 8,
                      placeholder: widget.placeholder,
                      customStyles: _styles(context, widget.style, palette),
                      embedBuilders: [
                        _ImageEmbedBuilder(
                          palette: palette,
                          radius: widget.style.radius,
                          onWidth: _setImageWidth,
                          onRemove: (offset) => _replaceBlock(offset, null),
                        ),
                        _DividerEmbedBuilder(palette),
                        _TableEmbedBuilder(
                          palette: palette,
                          onChanged: _replaceBlock,
                        ),
                        _HtmlEmbedBuilder(
                          palette: palette,
                          onRemove: (offset) => _replaceBlock(offset, null),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_uploading) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                richTextTr('rich_text.image_uploading'),
                style: TextStyle(
                  fontSize: palette.fontSize - 2,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(
            note,
            style: TextStyle(
              fontSize: palette.fontSize - 2,
              height: 1.35,
              color: error != null ? palette.danger : palette.muted,
              fontWeight: error != null ? FontWeight.w500 : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _toolbar(_Palette palette) {
    Widget tool(
      String key,
      VoidCallback? onPressed, {
      IconData? icon,
      String? text,
      bool active = false,
    }) => _ToolButton(
      key: ValueKey('rich-tool-$key'),
      icon: icon,
      text: text,
      label: richTextTr('rich_text.$key'),
      active: active,
      palette: palette,
      onPressed: onPressed,
    );
    Widget toggle(
      String key,
      Attribute attribute, {
      IconData? icon,
      String? text,
    }) => tool(
      key,
      () => _toggle(attribute),
      icon: icon,
      text: text,
      active: _active(attribute),
    );
    final separator = Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: palette.border,
    );
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: palette.toolbar,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: _ToolbarLayout(
        children: [
          toggle('bold', Attribute.bold, icon: Icons.format_bold_rounded),
          toggle('italic', Attribute.italic, icon: Icons.format_italic_rounded),
          toggle(
            'underline',
            Attribute.underline,
            icon: Icons.format_underlined_rounded,
          ),
          toggle(
            'strike',
            Attribute.strikeThrough,
            icon: Icons.format_strikethrough_rounded,
          ),
          toggle('code', Attribute.inlineCode, icon: Icons.code_rounded),
          separator,
          toggle('h2', Attribute.h2, text: 'H2'),
          toggle('h3', Attribute.h3, text: 'H3'),
          toggle('h4', Attribute.h4, text: 'H4'),
          toggle(
            'bullets',
            Attribute.ul,
            icon: Icons.format_list_bulleted_rounded,
          ),
          toggle(
            'numbers',
            Attribute.ol,
            icon: Icons.format_list_numbered_rounded,
          ),
          toggle(
            'quote',
            Attribute.blockQuote,
            icon: Icons.format_quote_rounded,
          ),
          tool(
            'divider',
            () => _insertBlock(const BlockEmbed(richTextDividerEmbed, 'hr')),
            icon: Icons.horizontal_rule_rounded,
          ),
          separator,
          tool(
            'align_left',
            () => _controller.formatSelection(
              Attribute.clone(Attribute.align, null),
            ),
            icon: Icons.format_align_left_rounded,
            active: _selectionStyle[Attribute.align.key] == null,
          ),
          toggle(
            'align_center',
            Attribute.centerAlignment,
            icon: Icons.format_align_center_rounded,
          ),
          toggle(
            'align_right',
            Attribute.rightAlignment,
            icon: Icons.format_align_right_rounded,
          ),
          toggle(
            'align_justify',
            Attribute.justifyAlignment,
            icon: Icons.format_align_justify_rounded,
          ),
          separator,
          tool(
            'link',
            _setLink,
            icon: Icons.link_rounded,
            active: _selectionStyle[Attribute.link.key] != null,
          ),
          tool(
            'unlink',
            _selectionStyle[Attribute.link.key] == null
                ? null
                : () => _controller.formatSelection(
                    Attribute.clone(Attribute.link, null),
                  ),
            icon: Icons.link_off_rounded,
          ),
          if (widget.onPickImage != null)
            tool(
              'image',
              _uploading ? null : _pickImage,
              icon: Icons.add_photo_alternate_outlined,
            ),
          tool(
            'table',
            () => _insertBlock(
              BlockEmbed(richTextTableEmbed, RichTableData.blank().encode()),
            ),
            icon: Icons.table_chart_outlined,
          ),
          separator,
          tool(
            'undo',
            _controller.hasUndo ? _controller.undo : null,
            icon: Icons.undo_rounded,
          ),
          tool(
            'redo',
            _controller.hasRedo ? _controller.redo : null,
            icon: Icons.redo_rounded,
          ),
        ],
      ),
    );
  }
}

/// Barre d'outils : sur plusieurs lignes quand la place le permet ; sur un
/// téléphone, une seule ligne qui défile de côté (sinon quatre lignes
/// mangent la moitié de l'éditeur).
class _ToolbarLayout extends StatelessWidget {
  const _ToolbarLayout({required this.children});

  final List<Widget> children;

  static const narrow = 420.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < narrow) {
        return SingleChildScrollView(
          key: const Key('rich-toolbar-scroll'),
          scrollDirection: Axis.horizontal,
          child: Row(children: children),
        );
      }
      return Wrap(
        spacing: 2,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    },
  );
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.active,
    required this.palette,
    this.icon,
    this.text,
    this.onPressed,
    super.key,
  });

  final IconData? icon;
  final String? text;
  final String label;
  final bool active;
  final _Palette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? palette.muted.withValues(alpha: .35)
        : active
        ? palette.accent
        : palette.muted;
    return Tooltip(
      message: label,
      child: Material(
        color: active
            ? palette.accent.withValues(alpha: .12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Semantics(
            button: true,
            selected: active,
            label: label,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 19, color: color)
                    : Text(
                        text ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Saisie d'une adresse de lien, refusée hors http(s), mailto et tel.
/// Renvoie l'adresse, `''` pour retirer le lien, `null` pour abandonner.
class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.initial});
  final String initial;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _input = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _input.text.trim();
    if (raw.isEmpty) {
      Navigator.of(context).pop('');
      return;
    }
    // « exemple.ci » sans protocole : https:// par défaut.
    final candidate = raw.contains(':') ? raw : 'https://$raw';
    final uri = RichTextLinks.parse(candidate);
    if (uri == null) {
      setState(() => _error = richTextTr('rich_text.link.invalid'));
      return;
    }
    Navigator.of(context).pop(uri.toString());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(richTextTr('rich_text.link.title')),
    content: TextField(
      key: const Key('rich-link-input'),
      controller: _input,
      autofocus: true,
      keyboardType: TextInputType.url,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: richTextTr('rich_text.link.hint'),
        errorText: _error,
        errorMaxLines: 3,
      ),
    ),
    actions: [
      if (widget.initial.isNotEmpty)
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text(richTextTr('rich_text.link.remove')),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(richTextTr('rich_text.cancel')),
      ),
      TextButton(
        key: const Key('rich-link-ok'),
        onPressed: _submit,
        child: Text(richTextTr('rich_text.ok')),
      ),
    ],
  );
}

/// Image : affichée à sa largeur (en %) ; un appui ouvre le choix de la
/// largeur et le retrait.
class _ImageEmbedBuilder extends EmbedBuilder {
  const _ImageEmbedBuilder({
    required this.palette,
    required this.radius,
    required this.onWidth,
    required this.onRemove,
  });

  final _Palette palette;
  final double radius;
  final void Function(int offset, int? width) onWidth;
  final ValueChanged<int> onRemove;

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data.toString();
    final width = int.tryParse(
      '${embedContext.node.style.attributes[Attribute.width.key]?.value ?? ''}',
    );
    final factor = width != null && width > 0 && width < 100
        ? width / 100
        : 1.0;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(radius - 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => Container(
            height: 80,
            color: palette.toolbar,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined, color: palette.muted),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: factor,
          child: embedContext.readOnly
              ? image
              : InkWell(
                  key: const Key('rich-image'),
                  borderRadius: BorderRadius.circular(radius - 4),
                  onTap: () => _menu(
                    context,
                    embedContext.node.documentOffset,
                    width ?? 100,
                  ),
                  child: image,
                ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, int offset, int current) async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                richTextTr('rich_text.image.title'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in const [25, 50, 75, 100])
                    ChoiceChip(
                      key: ValueKey('rich-image-width-$w'),
                      label: Text(
                        w == 100
                            ? richTextTr('rich_text.image.full')
                            : richTextTr('rich_text.image.width', {
                                'value': '$w',
                              }),
                      ),
                      selected: current == w,
                      selectedColor: palette.accent.withValues(alpha: .14),
                      onSelected: (_) => Navigator.of(context).pop(w),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                key: const Key('rich-image-remove'),
                style: TextButton.styleFrom(
                  foregroundColor: palette.danger,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => Navigator.of(context).pop(0),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: Text(richTextTr('rich_text.image.remove')),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 0) {
      onRemove(offset);
    } else {
      onWidth(offset, choice);
    }
  }
}

/// Ligne de séparation (`<hr />`).
class _DividerEmbedBuilder extends EmbedBuilder {
  const _DividerEmbedBuilder(this.palette);
  final _Palette palette;

  @override
  String get key => richTextDividerEmbed;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, thickness: 1, color: palette.border),
  );
}

/// Tableau à cellules de texte : affiché, et modifié en le touchant.
class _TableEmbedBuilder extends EmbedBuilder {
  const _TableEmbedBuilder({required this.palette, required this.onChanged});

  final _Palette palette;
  final void Function(int offset, BlockEmbed? block) onChanged;

  @override
  String get key => richTextTableEmbed;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = RichTableData.decode(embedContext.node.value.data.toString());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        key: const Key('rich-table'),
        onTap: embedContext.readOnly
            ? null
            : () async {
                final offset = embedContext.node.documentOffset;
                final result = await _showTableEditor(context, data, palette);
                if (result == null) return;
                onChanged(
                  offset,
                  result.rows.isEmpty
                      ? null
                      : BlockEmbed(richTextTableEmbed, result.encode()),
                );
              },
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: palette.border),
            children: [
              for (var r = 0; r < data.rows.length; r++)
                TableRow(
                  decoration: data.header && r == 0
                      ? BoxDecoration(color: palette.toolbar)
                      : null,
                  children: [
                    for (final cell in data.rows[r])
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 56,
                            maxWidth: 220,
                          ),
                          child: Text(
                            cell.isEmpty ? ' ' : cell,
                            style: TextStyle(
                              fontSize: palette.fontSize,
                              color: palette.text,
                              fontWeight: data.header && r == 0
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Élément conservé tel quel (vidéo intégrée, tableau mis en forme…).
class _HtmlEmbedBuilder extends EmbedBuilder {
  const _HtmlEmbedBuilder({required this.palette, required this.onRemove});

  final _Palette palette;
  final ValueChanged<int> onRemove;

  @override
  String get key => richTextHtmlEmbed;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final html = embedContext.node.value.data.toString();
    final tag = RegExp(
      r'^<\s*([a-zA-Z0-9]+)',
    ).firstMatch(html)?.group(1)?.toLowerCase();
    final kind = switch (tag) {
      'iframe' || 'video' => 'rich_text.kept.video',
      'audio' => 'rich_text.kept.audio',
      'table' => 'rich_text.kept.table',
      _ => 'rich_text.kept.other',
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: palette.toolbar,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: palette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              richTextTr('rich_text.kept.suffix', {'kind': richTextTr(kind)}),
              style: TextStyle(
                fontSize: palette.fontSize - 2,
                color: palette.muted,
              ),
            ),
          ),
          if (!embedContext.readOnly)
            IconButton(
              tooltip: richTextTr('rich_text.kept.remove'),
              onPressed: () => onRemove(embedContext.node.documentOffset),
              icon: Icon(Icons.close_rounded, size: 18, color: palette.danger),
            ),
        ],
      ),
    );
  }
}

/// Éditeur d'un tableau : cellules, lignes et colonnes, en-tête, suppression.
/// Renvoie le tableau modifié ; un tableau sans ligne signifie « supprimer ».
Future<RichTableData?> showRichTableEditor(
  BuildContext context, {
  required RichTableData data,
  RichTextEditorStyle style = const RichTextEditorStyle(),
}) => _showTableEditor(context, data, _Palette(context, style));

Future<RichTableData?> _showTableEditor(
  BuildContext context,
  RichTableData data,
  _Palette colors,
) {
  return showModalBottomSheet<RichTableData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.surface,
    builder: (context) => FractionallySizedBox(
      heightFactor: .9,
      child: _TableEditor(data: data, palette: colors),
    ),
  );
}

class _TableEditor extends StatefulWidget {
  const _TableEditor({required this.data, required this.palette});
  final RichTableData data;
  final _Palette palette;

  @override
  State<_TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<_TableEditor> {
  late bool _header = widget.data.header;
  late final List<List<TextEditingController>> _cells = [
    for (final row in widget.data.rows)
      [for (final cell in row) TextEditingController(text: cell)],
  ];

  int get _width => _cells.isEmpty ? 0 : _cells.first.length;

  @override
  void dispose() {
    for (final row in _cells) {
      for (final cell in row) {
        cell.dispose();
      }
    }
    super.dispose();
  }

  RichTableData get _result => RichTableData(
    header: _header,
    rows: [
      for (final row in _cells) [for (final cell in row) cell.text],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final cellBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: palette.border),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  richTextTr('rich_text.table.title'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: richTextTr('rich_text.close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: palette.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  richTextTr('rich_text.table.header'),
                  style: TextStyle(fontSize: 14, color: palette.text),
                ),
              ),
              Switch(
                value: _header,
                activeThumbColor: palette.accent,
                onChanged: (value) => setState(() => _header = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var c = 0; c < _width; c++)
                        SizedBox(
                          width: 112,
                          child: Center(
                            child: IconButton(
                              tooltip: richTextTr(
                                'rich_text.table.delete_column',
                              ),
                              onPressed: _width <= 1
                                  ? null
                                  : () => setState(() {
                                      for (final row in _cells) {
                                        row.removeAt(c).dispose();
                                      }
                                    }),
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 18,
                                color: _width <= 1 ? null : palette.danger,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (var r = 0; r < _cells.length; r++)
                    Row(
                      children: [
                        for (final cell in _cells[r])
                          Container(
                            width: 112,
                            padding: const EdgeInsets.all(4),
                            child: TextField(
                              controller: cell,
                              minLines: 1,
                              maxLines: 4,
                              style: TextStyle(
                                fontSize: 14,
                                color: palette.text,
                                fontWeight: _header && r == 0
                                    ? FontWeight.w700
                                    : null,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: _header && r == 0,
                                fillColor: palette.toolbar,
                                contentPadding: const EdgeInsets.all(10),
                                border: cellBorder,
                                enabledBorder: cellBorder,
                                focusedBorder: cellBorder.copyWith(
                                  borderSide: BorderSide(
                                    color: palette.accent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        IconButton(
                          tooltip: richTextTr('rich_text.table.delete_row'),
                          onPressed: _cells.length <= 1
                              ? null
                              : () => setState(() {
                                  for (final cell in _cells.removeAt(r)) {
                                    cell.dispose();
                                  }
                                }),
                          icon: Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 18,
                            color: _cells.length <= 1 ? null : palette.danger,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => _cells.add(
                    List.generate(_width, (_) => TextEditingController()),
                  ),
                ),
                icon: const Icon(Icons.table_rows_outlined, size: 18),
                label: Text(richTextTr('rich_text.table.add_row')),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  for (final row in _cells) {
                    row.add(TextEditingController());
                  }
                }),
                icon: const Icon(Icons.view_column_outlined, size: 18),
                label: Text(richTextTr('rich_text.table.add_column')),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: palette.danger),
                onPressed: () =>
                    Navigator.of(context).pop(const RichTableData(rows: [])),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(richTextTr('rich_text.table.delete')),
              ),
              FilledButton.icon(
                key: const Key('rich-table-done'),
                style: FilledButton.styleFrom(backgroundColor: palette.accent),
                onPressed: () => Navigator.of(context).pop(_result),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(richTextTr('rich_text.table.done')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Styles de l'éditeur : texte 14 px (interligne 1,6), titres gras
/// 22/18/16 px dans la police de l'app (flutter_quill impose sinon 16 px et
/// sa propre police).
DefaultStyles richTextStyles(BuildContext context, RichTextEditorStyle style) =>
    _styles(context, style, _Palette(context, style));

DefaultStyles _styles(
  BuildContext context,
  RichTextEditorStyle style,
  _Palette colors,
) {
  final base = DefaultTextStyle.of(context).style.copyWith(
    fontFamily: style.fontFamily,
    fontSize: style.fontSize,
    height: 1.6,
    color: colors.text,
    decoration: TextDecoration.none,
  );
  const none = HorizontalSpacing(0, 0);
  const noLine = VerticalSpacing(0, 0);
  DefaultTextBlockStyle heading(double size) => DefaultTextBlockStyle(
    base.copyWith(
      fontFamily: style.headingFontFamily ?? style.fontFamily,
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    none,
    const VerticalSpacing(14, 6),
    noLine,
    null,
  );
  return DefaultStyles(
    paragraph: DefaultTextBlockStyle(
      base,
      none,
      const VerticalSpacing(6, 0),
      noLine,
      null,
    ),
    placeHolder: DefaultTextBlockStyle(
      base.copyWith(color: colors.muted.withValues(alpha: .8)),
      none,
      const VerticalSpacing(6, 0),
      noLine,
      null,
    ),
    // 22 / 18 / 16 pour un texte à 14, en proportion sinon.
    h2: heading(style.fontSize * 22 / 14),
    h3: heading(style.fontSize * 18 / 14),
    h4: heading(style.fontSize * 16 / 14),
    lists: DefaultListBlockStyle(
      base,
      none,
      const VerticalSpacing(6, 0),
      noLine,
      null,
      null,
    ),
    quote: DefaultTextBlockStyle(
      base.copyWith(color: colors.muted, fontStyle: FontStyle.italic),
      const HorizontalSpacing(0, 0),
      const VerticalSpacing(8, 8),
      const VerticalSpacing(4, 4),
      BoxDecoration(
        border: Border(left: BorderSide(width: 3, color: colors.accent)),
      ),
    ),
    link: TextStyle(
      color: colors.accent,
      decoration: TextDecoration.underline,
      decorationColor: colors.accent,
    ),
    inlineCode: InlineCodeStyle(
      style: base.copyWith(
        fontFamily: 'monospace',
        fontSize: style.fontSize - 1,
      ),
      backgroundColor: colors.toolbar,
      radius: const Radius.circular(4),
    ),
  );
}
