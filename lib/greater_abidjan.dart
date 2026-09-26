/// Single home for the Greater-Abidjan geography constants.
///
/// The commune list MUST stay byte-identical to the backend's
/// `utils/commune.py` `CANONICAL_COMMUNES` — it is the offline fallback for
/// `GET /api/geocode/communes` (the backend is the source of truth) and the
/// reference the strict city selector validates against.
abstract final class GreaterAbidjan {
  // Bounding box + center DEFAULTS (offline/startup fallback, mirror the
  // backend delivery_zone default). The live values below are mutated at
  // runtime by [applyZone] from GET /api/geocode/communes.
  static const double latMinDefault = 5.15;
  static const double latMaxDefault = 6.25;
  static const double lngMinDefault = -4.55;
  static const double lngMaxDefault = -3.45;
  static const double defaultLatDefault = 5.3167;
  static const double defaultLngDefault = -4.0333;

  // Live values (admin-editable delivery_zone, applied at startup).
  static double latMin = latMinDefault;
  static double latMax = latMaxDefault;
  static double lngMin = lngMinDefault;
  static double lngMax = lngMaxDefault;
  static double defaultLat = defaultLatDefault;
  static double defaultLng = defaultLngDefault;

  /// Delivery-zone display label (null => the UI uses its bundled translation).
  static String? _zoneLabel;
  static String? get zoneLabel => _zoneLabel;

  /// The 20 canonical communes/cities (mirror of backend CANONICAL_COMMUNES).
  static const List<String> communes = [
    'Abobo',
    'Adjamé',
    'Attécoubé',
    'Cocody',
    'Koumassi',
    'Marcory',
    'Plateau',
    'Port-Bouët',
    'Treichville',
    'Yopougon',
    'Anyama',
    'Bingerville',
    'Grand-Bassam',
    'Dabou',
    'Jacqueville',
    'Bonoua',
    'Agboville',
    'Adzopé',
    'Assinie',
    'Songon',
  ];

  static bool containsPoint(double lat, double lng) =>
      lat >= latMin && lat <= latMax && lng >= lngMin && lng <= lngMax;

  /// Apply the backend delivery zone (from /api/geocode/communes `zone`).
  /// Invalid/partial payloads are ignored field-by-field (fail-open).
  static void applyZone(Map? z) {
    if (z == null) return;
    double? dbl(String k) {
      final v = z[k];
      return v is num ? v.toDouble() : null;
    }

    final laMin = dbl('lat_min'), laMax = dbl('lat_max');
    final loMin = dbl('lng_min'), loMax = dbl('lng_max');
    if (laMin != null && laMax != null && laMin < laMax) {
      latMin = laMin;
      latMax = laMax;
    }
    if (loMin != null && loMax != null && loMin < loMax) {
      lngMin = loMin;
      lngMax = loMax;
    }
    final ceLat = dbl('center_lat'), ceLng = dbl('center_lng');
    if (ceLat != null) defaultLat = ceLat;
    if (ceLng != null) defaultLng = ceLng;
    final label = z['label']?.toString().trim();
    if (label != null && label.isNotEmpty) _zoneLabel = label;
  }

  // Accent folding for matching (covers the accents used in the list and
  // common user input).
  static const Map<String, String> _accentMap = {
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };

  /// Lowercase + strip accents + collapse spaces/hyphens (mirror of the
  /// backend `_fold`).
  static String _fold(String text) {
    var out = text.toLowerCase().replaceAll('-', ' ');
    _accentMap.forEach((k, v) => out = out.replaceAll(k, v));
    return out.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  }

  /// Common variants / quartiers → canonical commune. Keys must be in FOLDED
  /// form (lowercase, no accents, spaces instead of hyphens — see [_fold]).
  /// Keep the backend `_VARIANTS` (utils/commune.py) in sync when extending this.
  /// Ambiguous quartier names shared by several communes (e.g. "sicogi",
  /// "belleville", "biabou", "zone 4 bis") are intentionally OMITTED — the
  /// coordinate fallback [communeFromCoordinates] disambiguates those.
  static const Map<String, String> _variants = {
    // Canonical spelling variants
    'port bouet': 'Port-Bouët',
    'portbouet': 'Port-Bouët',
    'grand bassam': 'Grand-Bassam',
    'adjame': 'Adjamé',
    'attecoube': 'Attécoubé',
    'adzope': 'Adzopé',
    'abidjan plateau': 'Plateau',
    'le plateau': 'Plateau',
    'yop': 'Yopougon',
    // --- Cocody quartiers ---
    'riviera': 'Cocody',
    'angre': 'Cocody',
    'deux plateaux': 'Cocody',
    'ii plateaux': 'Cocody',
    '2 plateaux': 'Cocody',
    'danga': 'Cocody',
    'mermoz': 'Cocody',
    'attoban': 'Cocody',
    'blockhauss': 'Cocody',
    'blockhaus': 'Cocody',
    'bonoumin': 'Cocody',
    'palmeraie': 'Cocody',
    'akouedo': 'Cocody',
    'mpouto': 'Cocody',
    'faya': 'Cocody',
    'saint jean': 'Cocody',
    'ambassades': 'Cocody',
    'vallon': 'Cocody',
    // --- Yopougon quartiers ---
    'selmer': 'Yopougon',
    'niangon': 'Yopougon',
    'toits rouges': 'Yopougon',
    'sideci': 'Yopougon',
    'andokoi': 'Yopougon',
    'gesco': 'Yopougon',
    'wassakara': 'Yopougon',
    'yao sehi': 'Yopougon',
    'ananeraie': 'Yopougon',
    // --- Marcory quartiers ---
    'zone 4': 'Marcory',
    'bietry': 'Marcory',
    'anoumabo': 'Marcory',
    // --- Treichville quartiers ---
    'zone 3': 'Treichville',
    'arras': 'Treichville',
    // --- Adjamé quartiers ---
    'williamsville': 'Adjamé',
    '220 logements': 'Adjamé',
    'bracodi': 'Adjamé',
    // --- Abobo quartiers ---
    'abobo gare': 'Abobo',
    'avocatier': 'Abobo',
    'anonkoua koute': 'Abobo',
    'sagbe': 'Abobo',
    'ndotre': 'Abobo',
    'akeikoi': 'Abobo',
    // --- Port-Bouët quartiers ---
    'vridi': 'Port-Bouët',
    'gonzagueville': 'Port-Bouët',
    'adjouffou': 'Port-Bouët',
    // --- Attécoubé quartiers ---
    'locodjro': 'Attécoubé',
    'agban': 'Attécoubé',
    'abobo doume': 'Attécoubé',
    'sebroko': 'Attécoubé',
    // --- Koumassi quartiers ---
    'prodomo': 'Koumassi',
    'remblais': 'Koumassi',
  };

  /// Approximate centroids (lat, lng) of each canonical commune. Used only as a
  /// FALLBACK when the reverse-geocoded NAME can't be matched — see
  /// [communeFromCoordinates]. Approximate by design (no polygon data); large
  /// communes (Cocody, Yopougon) can mis-assign a border point, which is why the
  /// user always confirms the pre-selected commune.
  static const Map<String, List<double>> _centroids = {
    'Abobo': [5.4200, -4.0200],
    'Adjamé': [5.3660, -4.0200],
    'Attécoubé': [5.3350, -4.0300],
    'Cocody': [5.3600, -3.9700],
    'Koumassi': [5.2950, -3.9450],
    'Marcory': [5.3050, -3.9850],
    'Plateau': [5.3240, -4.0180],
    'Port-Bouët': [5.2550, -3.9260],
    'Treichville': [5.2930, -4.0050],
    'Yopougon': [5.3450, -4.0850],
    'Anyama': [5.4940, -4.0520],
    'Bingerville': [5.3550, -3.8850],
    'Grand-Bassam': [5.2110, -3.7380],
    'Dabou': [5.3250, -4.3770],
    'Jacqueville': [5.2070, -4.4150],
    'Bonoua': [5.2710, -3.5940],
    'Agboville': [5.9280, -4.2130],
    'Adzopé': [6.1070, -3.8650],
    'Assinie': [5.1300, -3.2860],
    'Songon': [5.3330, -4.2500],
  };

  /// Map a free-text city ("Cocody Riviera 3", "port bouet", legacy saved
  /// addresses…) to a canonical commune, or null if unrecognized. Pass [among]
  /// to match against the live backend-served list instead of the constant.
  static String? matchCommune(String? raw, {List<String>? among}) {
    if (raw == null) return null;
    final folded = _fold(raw);
    if (folded.isEmpty) return null;
    final list = (among == null || among.isEmpty) ? communes : among;
    final foldedMap = {for (final c in list) _fold(c): c};
    final exact = foldedMap[folded];
    if (exact != null) return exact;
    final variant = _variants[folded];
    if (variant != null && list.contains(variant)) return variant;
    for (final entry in foldedMap.entries) {
      if (folded.contains(entry.key) || entry.key.contains(folded)) {
        return entry.value;
      }
    }
    for (final entry in _variants.entries) {
      if (folded.contains(entry.key) && list.contains(entry.value)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Best-effort commune from GPS coordinates: the canonical commune whose
  /// centroid is closest to (lat, lng). FALLBACK only — use [matchCommune] on
  /// the geocoded name first (more reliable when the name is clean). Returns
  /// null if the point is outside the delivery zone or too far from every known
  /// centroid (so the user is asked to pick rather than mis-assigned).
  static String? communeFromCoordinates(
    double lat,
    double lng, {
    List<String>? among,
  }) {
    if (!containsPoint(lat, lng)) return null;
    final list = (among == null || among.isEmpty) ? communes : among;
    String? best;
    double bestDist = double.infinity;
    _centroids.forEach((commune, c) {
      if (!list.contains(commune)) return;
      final dLat = lat - c[0];
      final dLng = lng - c[1];
      final dist =
          dLat * dLat + dLng * dLng; // squared euclidean (nearest only)
      if (dist < bestDist) {
        bestDist = dist;
        best = commune;
      }
    });
    // Guard: ~0.2° (≈ 22 km) max from the nearest centroid, else give up.
    if (bestDist > 0.04) return null;
    return best;
  }
}
