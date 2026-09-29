import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Libellés des composants Material (calendrier, heures, « Annuler »…) dans
/// la langue de l'app.
///
/// Sans eux, l'app n'embarquait que l'anglais : le sélecteur de date
/// s'affichait en anglais, et `showDatePicker(locale: fr)` plantait
/// (« No MaterialLocalizations found »).
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  // Obligatoire pour l'éditeur de texte riche : sans lui, QuillEditor
  // plante à l'affichage.
  FlutterQuillLocalizations.delegate,
];

const List<Locale> appSupportedLocales = [Locale('fr'), Locale('en', 'US')];
