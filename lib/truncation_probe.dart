import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Un texte affiché coupé (points de suspension ou lignes en trop).
@immutable
class TruncatedText {
  final String text;
  final double width;
  final int? maxLines;

  const TruncatedText({
    required this.text,
    required this.width,
    required this.maxLines,
  });

  @override
  String toString() =>
      '« $text » (largeur ${width.round()} px, '
      '${maxLines == null ? 'sans limite' : '$maxLines ligne(s) max'})';
}

/// Tous les textes actuellement coupés dans l'arbre de rendu.
///
/// Rien ne se voit en lisant le code : une coupure dépend de la largeur de
/// l'écran ET des vraies données. Flutter, lui, le sait pour chaque texte
/// dessiné (`didExceedMaxLines`). Sert au détecteur ci-dessous et aux tests
/// de montage (`expect(findTruncatedTexts(), isEmpty)`).
List<TruncatedText> findTruncatedTexts() {
  final found = <TruncatedText>[];
  void visit(RenderObject node) {
    if (node is RenderParagraph && node.hasSize && node.didExceedMaxLines) {
      found.add(
        TruncatedText(
          text: node.text.toPlainText().trim(),
          width: node.size.width,
          maxLines: node.maxLines,
        ),
      );
    }
    node.visitChildren(visit);
  }

  for (final view in RendererBinding.instance.renderViews) {
    visit(view);
  }
  return found;
}

/// Détecteur de textes coupés, en MODE DEBUG SEULEMENT (aucun effet en
/// release) : au plus une fois par seconde, il parcourt l'écran et écrit dans
/// la console chaque texte coupé qu'il n'a pas déjà signalé :
///
///   ✂️ TEXTE COUPÉ [/home] « Base des commissions » (largeur 96 px, 1 ligne(s) max)
///
/// Naviguer dans l'app en debug suffit à dresser la liste. Certaines coupures
/// sont voulues (un nom de produit très long dans une liste) : la liste sert
/// à trier, pas à tout « corriger ».
class TruncationProbe {
  TruncationProbe._();

  static final Set<String> _reported = {};
  static Timer? _pending;
  static bool _installed = false;

  /// Nom de la page affichée, quand l'app change d'écran sans changer de
  /// route (menu latéral de la console et de l'app vendeur : tout se passe
  /// sous `/dashboard`). Sans lui, chaque ligne disait `[/dashboard]`.
  static String? Function()? _pageName;

  static void install({String? Function()? pageName}) {
    if (!kDebugMode || _installed) return;
    _installed = true;
    _pageName = pageName;
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      // Une fois par seconde au plus, même pendant une animation continue.
      _pending ??= Timer(const Duration(seconds: 1), () {
        _pending = null;
        _scan();
      });
    });
  }

  static void _scan() {
    final List<TruncatedText> found;
    try {
      found = findTruncatedTexts();
    } catch (_) {
      return; // arbre en cours de reconstruction : on verra au prochain passage
    }
    String? page;
    try {
      page = _pageName?.call();
    } catch (_) {
      page = null;
    }
    final route = page == null || page.isEmpty
        ? Get.currentRoute
        : '${Get.currentRoute} › $page';
    for (final t in found) {
      if (t.text.isEmpty) continue;
      if (!_reported.add('$route|${t.text}')) continue;
      debugPrint('✂️ TEXTE COUPÉ [$route] $t');
    }
  }
}
