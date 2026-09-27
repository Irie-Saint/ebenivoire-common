import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import 'app_skeleton.dart';
import 'brand_colors.dart';

/// Chargement d'une photo (produit, catégorie…), commun aux 3 apps : le nom « EbènIvoire » qui
/// scintille sur un fond neutre, au lieu d'un rectangle gris.
///
/// Le nom sert de motif de marque : sur une petite vignette il n'a pas besoin
/// d'être lisible (choix du user, 27/09), il est donc affiché à toute taille.
///
/// [onDark] : sur un fond sombre (visionneuse plein écran), le nom scintille
/// en blanc, sans fond propre.
class BrandNameLoader extends StatelessWidget {
  const BrandNameLoader({super.key, this.onDark = false});

  final bool onDark;

  static const String brandName = 'EbènIvoire';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same tokens as the page skeletons (AppShimmer), the name a shade darker
    // than the box so it reads through the sweep.
    final Color background;
    final Color base;
    final Color highlight;
    if (onDark) {
      background = Colors.transparent;
      base = Colors.white24;
      highlight = Colors.white70;
    } else {
      background = isDark
          ? BrandColors.skeletonBaseDark
          : BrandColors.skeletonBaseLight;
      base = isDark ? const Color(0xFF3E3E41) : const Color(0xFFCCD1D8);
      highlight = isDark
          ? BrandColors.skeletonHighlightDark
          : BrandColors.skeletonHighlightLight;
    }

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.hasBoundedWidth ? box.maxWidth : 160.0;
        return ColoredBox(
          color: background,
          child: Center(
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              period: const Duration(milliseconds: 1400),
              child: SizedBox(
                // Le nom occupe ~70 % de la largeur, sans devenir énorme.
                width: (width * 0.7).clamp(0.0, 320.0),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    brandName,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: Colors.white,
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

/// Zone photo d'un squelette : le nom de la marque qui scintille, coupé en
/// rectangle arrondi ([radius], unités `.r`) ou en rond ([circle]).
///
/// ⚠️ Jamais sous un [AppShimmer] : le reflet repeindrait le nom en aplat.
/// Dans un squelette, mettre le reflet sur les barres ([ShimmerBox]).
class SkeletonPhoto extends StatelessWidget {
  const SkeletonPhoto({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.circle = false,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final box = SizedBox(
      width: width,
      height: height,
      child: const BrandNameLoader(),
    );
    return circle
        ? ClipOval(child: box)
        : ClipRRect(borderRadius: BorderRadius.circular(radius.r), child: box);
  }
}

/// [SkeletonBox] qui porte son propre reflet : pour les squelettes où le
/// reflet ne peut plus couvrir toute la page (à cause d'un [SkeletonPhoto]).
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: SkeletonBox(
      width: width,
      height: height,
      radius: radius,
      shape: shape,
    ),
  );
}
