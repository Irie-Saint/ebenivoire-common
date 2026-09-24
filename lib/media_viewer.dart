/// Afficheur d'images et lecteur vidéo en plein écran — LE seul de l'app.
///
/// Avant, chaque écran avait le sien (fiche commande, produit, retours, avis,
/// support…) : fonds, boutons et gestes différents d'une section à l'autre.
/// Ce fichier est le même dans les trois apps (console, vendeur, cliente) :
/// il ne dépend d'aucune d'elles.
///
/// - Images : fond noir, « 2 / 5 », on glisse d'une image à l'autre, on
///   pince pour zoomer, double appui = zoom / retour ; flèches et clavier
///   (← → Échap) sur ordinateur et tablette.
/// - Vidéo : même cadre noir, vidéo à sa proportion, lecture / pause, barre
///   de progression, temps, son ; « Ouvrir ailleurs » si elle ne se lit pas.
/// - [MediaThumbnail] : la vignette qui ouvre l'un ou l'autre, même forme
///   partout, pastille « lecture » sur une vidéo.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Un élément à afficher : une image ou une vidéo.
class MediaItem {
  final String url;
  final bool isVideo;

  const MediaItem.image(this.url) : isVideo = false;
  const MediaItem.video(this.url) : isVideo = true;
}

class MediaViewer {
  MediaViewer._();

  /// Images en plein écran, à partir de [initialIndex].
  static Future<void> showImages(
    BuildContext context,
    List<String> urls, {
    int initialIndex = 0,
    String? title,
  }) {
    final images = [
      for (final url in urls)
        if (url.trim().isNotEmpty) CachedNetworkImageProvider(url),
    ];
    return showImageProviders(
      context,
      images,
      initialIndex: initialIndex,
      title: title,
    );
  }

  /// Même afficheur pour des images qui ne sont pas (encore) en ligne :
  /// photo choisie sur le téléphone avant l'envoi (`FileImage`), mémoire…
  static Future<void> showImageProviders(
    BuildContext context,
    List<ImageProvider> images, {
    int initialIndex = 0,
    String? title,
  }) {
    if (images.isEmpty) return Future.value();
    return _push(
      context,
      _ImageGalleryPage(
        images: images,
        initialIndex: initialIndex.clamp(0, images.length - 1),
        title: title,
      ),
    );
  }

  /// Une vidéo en plein écran, lancée tout de suite.
  ///
  /// [controllerBuilder] : pour une vidéo qui n'est pas en ligne (fichier
  /// choisi sur le téléphone, pas encore envoyé) — l'appelant fournit
  /// `VideoPlayerController.file(...)`, ce fichier reste sans `dart:io`.
  static Future<void> showVideo(
    BuildContext context,
    String url, {
    String? title,
    VideoPlayerController Function()? controllerBuilder,
  }) {
    if (url.trim().isEmpty && controllerBuilder == null) return Future.value();
    return _push(
      context,
      _VideoPage(url: url, title: title, controllerBuilder: controllerBuilder),
    );
  }

  /// Ouvre l'élément avec le bon afficheur ; pour une image, les autres
  /// images de [gallery] restent accessibles en glissant.
  static Future<void> open(
    BuildContext context,
    MediaItem item, {
    List<MediaItem> gallery = const [],
    String? title,
  }) {
    if (item.isVideo) return showVideo(context, item.url, title: title);
    final images = [
      for (final media in gallery.isEmpty ? [item] : gallery)
        if (!media.isVideo) media.url,
    ];
    final index = images.indexOf(item.url);
    return showImages(
      context,
      images.isEmpty ? [item.url] : images,
      initialIndex: index < 0 ? 0 : index,
      title: title,
    );
  }

  static Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------- cadre

/// Le cadre commun : fond noir, titre et boutons en haut, sur un léger
/// dégradé pour rester lisibles au-dessus de n'importe quelle photo.
class _MediaScaffold extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottom;

  const _MediaScaffold({
    required this.child,
    this.title,
    this.actions = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...actions,
                        _RoundButton(
                          icon: Icons.close_rounded,
                          tooltip: 'media.close'.tr,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (bottom != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0x99000000), Color(0x00000000)],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: bottom,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.14),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  final String message;
  final VoidCallback? onOpenElsewhere;

  const _Failure({required this.message, this.onOpenElsewhere});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (onOpenElsewhere != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onOpenElsewhere,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('media.open_elsewhere'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _spinner = Center(
  child: SizedBox(
    width: 32,
    height: 32,
    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
  ),
);

Future<void> _openElsewhere(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ---------------------------------------------------------------- images

class _ImageGalleryPage extends StatefulWidget {
  final List<ImageProvider> images;
  final int initialIndex;
  final String? title;

  const _ImageGalleryPage({
    required this.images,
    required this.initialIndex,
    this.title,
  });

  @override
  State<_ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<_ImageGalleryPage> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  final _focus = FocusNode();

  // Pas de glissement de page pendant un zoom : le doigt déplace la photo.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= widget.images.length) return;
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.images.length > 1;
    final wide = MediaQuery.sizeOf(context).width >= 600;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: _MediaScaffold(
        title: widget.title,
        bottom: many
            ? Center(
                child: Text(
                  '${_index + 1} / ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() {
                _index = i;
                _zoomed = false;
              }),
              itemBuilder: (_, i) => _ZoomableImage(
                image: widget.images[i],
                onZoomChanged: (zoomed) {
                  if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                },
              ),
            ),
            if (many && wide) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _RoundButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'media.previous'.tr,
                    onPressed: _index > 0 ? () => _go(-1) : null,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _RoundButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'media.next'.tr,
                    onPressed: _index < widget.images.length - 1
                        ? () => _go(1)
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final ImageProvider image;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableImage({required this.image, required this.onZoomChanged});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<Matrix4>? _tween;
  TapDownDetails? _doubleTap;

  @override
  void initState() {
    super.initState();
    _animation.addListener(() {
      if (_tween != null) _transform.value = _tween!.value;
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  void _toggleZoom() {
    final target = _isZoomed
        ? Matrix4.identity()
        : (() {
            final position = _doubleTap?.localPosition ?? Offset.zero;
            const scale = 2.5;
            return Matrix4.identity()
              ..translateByDouble(
                -position.dx * (scale - 1),
                -position.dy * (scale - 1),
                0,
                1,
              )
              ..scaleByDouble(scale, scale, 1, 1);
          })();
    _tween = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOut));
    _animation.forward(from: 0);
    widget.onZoomChanged(target.getMaxScaleOnAxis() > 1.01);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTap = details,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        onInteractionEnd: (_) => widget.onZoomChanged(_isZoomed),
        child: SizedBox.expand(
          child: Image(
            image: widget.image,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _spinner,
            errorBuilder: (_, _, _) {
              final image = widget.image;
              final url = image is CachedNetworkImageProvider
                  ? image.url
                  : null;
              return _Failure(
                message: 'media.image_failed'.tr,
                onOpenElsewhere: url == null ? null : () => _openElsewhere(url),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- vidéo

class _VideoPage extends StatefulWidget {
  final String url;
  final String? title;
  final VideoPlayerController Function()? controllerBuilder;

  const _VideoPage({required this.url, this.title, this.controllerBuilder});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final VideoPlayerController _video =
      widget.controllerBuilder?.call() ??
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool get _isRemote => widget.url.startsWith('http');
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _video.addListener(_onTick);
    _video
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _video.play();
        })
        .catchError((Object error) {
          debugPrint('[MEDIA VIEWER] vidéo illisible : $error');
          if (mounted) setState(() => _failed = true);
        });
  }

  void _onTick() {
    if (!mounted) return;
    if (_video.value.hasError && !_failed) {
      setState(() => _failed = true);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _video.removeListener(_onTick);
    _video.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_ready) return;
    _video.value.isPlaying ? _video.pause() : _video.play();
  }

  static String _time(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = _video.value;
    final muted = value.volume == 0;

    Widget body;
    if (_failed) {
      body = _Failure(
        message: 'media.video_failed'.tr,
        onOpenElsewhere: _isRemote ? () => _openElsewhere(widget.url) : null,
      );
    } else if (!_ready) {
      body = _spinner;
    } else {
      body = GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(_video),
              ),
            ),
            if (!value.isPlaying)
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
          ],
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.space) {
          _togglePlay();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _MediaScaffold(
        title: widget.title,
        actions: [
          if (_isRemote)
            _RoundButton(
              icon: Icons.open_in_new_rounded,
              tooltip: 'media.open_elsewhere'.tr,
              onPressed: () => _openElsewhere(widget.url),
            ),
        ],
        bottom: _ready && !_failed
            ? Row(
                children: [
                  _RoundButton(
                    icon: value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: value.isPlaying
                        ? 'media.pause'.tr
                        : 'media.play'.tr,
                    onPressed: _togglePlay,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: VideoProgressIndicator(
                      _video,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_time(value.position)} / ${_time(value.duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  _RoundButton(
                    icon: muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    tooltip: muted ? 'media.unmute'.tr : 'media.mute'.tr,
                    onPressed: () => _video.setVolume(muted ? 1 : 0),
                  ),
                ],
              )
            : null,
        child: body,
      ),
    );
  }
}

// ---------------------------------------------------------------- vignette

/// La vignette qui ouvre l'afficheur : coins arrondis, image recadrée,
/// pastille « lecture » sur une vidéo. Même forme dans toutes les sections.
class MediaThumbnail extends StatelessWidget {
  final MediaItem item;
  final List<MediaItem> gallery;
  final double size;
  final double radius;
  final String? title;

  /// Image fixe d'une vidéo (sinon un fond sombre avec la pastille).
  final String? posterUrl;

  const MediaThumbnail({
    super.key,
    required this.item,
    this.gallery = const [],
    this.size = 72,
    this.radius = 10,
    this.title,
    this.posterUrl,
  });

  @override
  Widget build(BuildContext context) {
    final picture = item.isVideo ? posterUrl : item.url;
    return Semantics(
      button: true,
      label: item.isVideo ? 'media.play'.tr : 'media.zoom'.tr,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            color: const Color(0xFF1F2330),
            child: InkWell(
              onTap: () => MediaViewer.open(
                context,
                item,
                gallery: gallery,
                title: title,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (picture != null && picture.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: picture,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                      ),
                    ),
                  if (item.isVideo)
                    Center(
                      child: Container(
                        width: size * 0.42,
                        height: size * 0.42,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: size * 0.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
