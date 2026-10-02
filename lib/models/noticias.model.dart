class CategoriaNoticiaModel {
  CategoriaNoticiaModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
  });

  final int id;
  final String name;
  final String slug;
  final int count;

  factory CategoriaNoticiaModel.fromJson(Map<String, dynamic> json) {
    return CategoriaNoticiaModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: _cleanHtml(json['name']?.toString() ?? ''),
      slug: json['slug']?.toString() ?? '',
      count: int.tryParse(json['count']?.toString() ?? '') ?? 0,
    );
  }
}

enum NoticiaContentBlockType { text, image, link, gallery, video, tweet }

class NoticiaGalleryItem {
  const NoticiaGalleryItem({required this.imageUrl, this.caption = ''});

  final String imageUrl;
  final String caption;

  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'caption': caption,
  };

  factory NoticiaGalleryItem.fromJson(Map<String, dynamic> json) {
    return NoticiaGalleryItem(
      imageUrl: json['imageUrl']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
    );
  }
}

class NoticiaContentBlock {
  const NoticiaContentBlock._({
    required this.type,
    this.text = '',
    this.imageUrl = '',
    this.caption = '',
    this.linkUrl = '',
    this.videoUrl = '',
    this.videoAspectRatio = _proporcionHorizontal,
    this.galleryItems = const [],
    this.sourceHtml = '',
  });

  static const double _proporcionHorizontal = 16 / 9;

  const NoticiaContentBlock.text(String value, {String sourceHtml = ''})
    : this._(type: NoticiaContentBlockType.text, text: value, sourceHtml: sourceHtml);

  const NoticiaContentBlock.image({required String url, String caption = ''})
    : this._(
        type: NoticiaContentBlockType.image,
        imageUrl: url,
        caption: caption,
      );

  const NoticiaContentBlock.link({required String text, required String url})
    : this._(
        type: NoticiaContentBlockType.link,
        text: text,
        linkUrl: url,
        sourceHtml: text,
      );

  const NoticiaContentBlock.gallery(List<NoticiaGalleryItem> items)
    : this._(type: NoticiaContentBlockType.gallery, galleryItems: items);

  /// [aspectRatio] es ancho sobre alto: 16/9 para el video de siempre, menos de
  /// 1 para los verticales como los reels de Facebook.
  const NoticiaContentBlock.video(
    String url, {
    double aspectRatio = _proporcionHorizontal,
  }) : this._(
         type: NoticiaContentBlockType.video,
         videoUrl: url,
         videoAspectRatio: aspectRatio,
       );

  /// Una publicación de X insertada en la nota.
  ///
  /// [url] es la de la publicación (`https://twitter.com/usuario/status/id`) y
  /// [text] su texto, que se muestra solo si la inserción de X no carga: sin
  /// red, con la publicación borrada o con X caído.
  const NoticiaContentBlock.tweet({required String url, String text = ''})
    : this._(type: NoticiaContentBlockType.tweet, linkUrl: url, text: text);

  final NoticiaContentBlockType type;
  final String text;
  final String imageUrl;
  final String caption;
  final String linkUrl;
  final String videoUrl;
  final double videoAspectRatio;
  final List<NoticiaGalleryItem> galleryItems;
  final String sourceHtml;

  NoticiaContentBlock copyWithSourceHtml(String value) {
    return NoticiaContentBlock._(
      type: type,
      text: text,
      imageUrl: imageUrl,
      caption: caption,
      linkUrl: linkUrl,
      videoUrl: videoUrl,
      videoAspectRatio: videoAspectRatio,
      galleryItems: galleryItems,
      sourceHtml: value,
    );
  }

  bool get isText => type == NoticiaContentBlockType.text;
  bool get isImage => type == NoticiaContentBlockType.image;
  bool get isLink => type == NoticiaContentBlockType.link;
  bool get isGallery => type == NoticiaContentBlockType.gallery;
  bool get isVideo => type == NoticiaContentBlockType.video;
  bool get isTweet => type == NoticiaContentBlockType.tweet;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'text': text,
    'imageUrl': imageUrl,
    'caption': caption,
    'linkUrl': linkUrl,
    'videoUrl': videoUrl,
    'videoAspectRatio': videoAspectRatio,
    'galleryItems': galleryItems.map((e) => e.toJson()).toList(),
    'sourceHtml': sourceHtml,
  };

  factory NoticiaContentBlock.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? 'text';
    final type = NoticiaContentBlockType.values.firstWhere(
      (element) => element.name == typeName,
      orElse: () => NoticiaContentBlockType.text,
    );
    switch (type) {
      case NoticiaContentBlockType.image:
        return NoticiaContentBlock.image(
          url: json['imageUrl']?.toString() ?? '',
          caption: json['caption']?.toString() ?? '',
        );
      case NoticiaContentBlockType.link:
        return NoticiaContentBlock.link(
          text: json['text']?.toString() ?? '',
          url: json['linkUrl']?.toString() ?? '',
        ).copyWithSourceHtml(json['sourceHtml']?.toString() ?? '');
      case NoticiaContentBlockType.gallery:
        final items = (json['galleryItems'] as List<dynamic>? ?? [])
            .map((e) => NoticiaGalleryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return NoticiaContentBlock.gallery(items);
      case NoticiaContentBlockType.video:
        // Las noticias guardadas sin conexión antes de este campo no lo traen:
        // eran todas de MOW, horizontales.
        final proporcion = json['videoAspectRatio'];
        return NoticiaContentBlock.video(
          json['videoUrl']?.toString() ?? '',
          aspectRatio: proporcion is num && proporcion > 0
              ? proporcion.toDouble()
              : _proporcionHorizontal,
        );
      case NoticiaContentBlockType.tweet:
        return NoticiaContentBlock.tweet(
          url: json['linkUrl']?.toString() ?? '',
          text: json['text']?.toString() ?? '',
        );
      case NoticiaContentBlockType.text:
        return NoticiaContentBlock.text(
          json['text']?.toString() ?? '',
          sourceHtml: json['sourceHtml']?.toString() ?? '',
        );
    }
  }
}

class NoticiaModel {
  NoticiaModel({
    required this.id,
    required this.link,
    required this.slug,
    required this.date,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.contentBlocks,
    required this.imageUrl,
    required this.imageAlt,
    this.localImagePath = '',
    required this.categories,
    this.author = '',
  });

  final int id;
  final String link;
  final String slug;
  final DateTime? date;
  final String title;
  final String excerpt;
  final String content;
  final List<NoticiaContentBlock> contentBlocks;
  final String imageUrl;
  final String imageAlt;
  final String localImagePath;
  final List<int> categories;

  /// Autor de la nota. Puede venir vacío: no todas las notas van firmadas y el
  /// listado (`/api/noticias`) no lo trae, solo el detalle (`by-link`).
  final String author;

  bool get hasImage => imageUrl.isNotEmpty;

  /// El listado (`/api/noticias`) solo trae los datos de la tarjeta; el
  /// contenido llega al abrir la nota (`/api/noticias/by-link`).
  bool get tieneContenido => content.isNotEmpty || contentBlocks.isNotEmpty;

  NoticiaModel copyWith({
    int? id,
    String? link,
    String? slug,
    DateTime? date,
    String? title,
    String? excerpt,
    String? content,
    List<NoticiaContentBlock>? contentBlocks,
    String? imageUrl,
    String? imageAlt,
    String? localImagePath,
    List<int>? categories,
    String? author,
  }) {
    return NoticiaModel(
      id: id ?? this.id,
      link: link ?? this.link,
      slug: slug ?? this.slug,
      date: date ?? this.date,
      title: title ?? this.title,
      excerpt: excerpt ?? this.excerpt,
      content: content ?? this.content,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      imageUrl: imageUrl ?? this.imageUrl,
      imageAlt: imageAlt ?? this.imageAlt,
      localImagePath: localImagePath ?? this.localImagePath,
      categories: categories ?? this.categories,
      author: author ?? this.author,
    );
  }

  /// Completa la tarjeta con los datos de la nota completa sin perder lo que
  /// solo existe en local (por ejemplo la imagen descargada para offline).
  NoticiaModel mergeDetalle(NoticiaModel detalle) {
    return copyWith(
      id: detalle.id > 0 ? detalle.id : id,
      link: detalle.link.isNotEmpty ? detalle.link : link,
      slug: detalle.slug.isNotEmpty ? detalle.slug : slug,
      date: detalle.date ?? date,
      title: detalle.title.isNotEmpty ? detalle.title : title,
      excerpt: detalle.excerpt.isNotEmpty ? detalle.excerpt : excerpt,
      content: detalle.content,
      contentBlocks: detalle.contentBlocks,
      imageUrl: detalle.imageUrl.isNotEmpty ? detalle.imageUrl : imageUrl,
      imageAlt: detalle.imageAlt.isNotEmpty ? detalle.imageAlt : imageAlt,
      categories: detalle.categories.isNotEmpty ? detalle.categories : categories,
      author: detalle.author.isNotEmpty ? detalle.author : author,
    );
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'id': id,
      'link': link,
      'slug': slug,
      'date': date?.toIso8601String(),
      'title': title,
      'excerpt': excerpt,
      'content': content,
      'imageUrl': imageUrl,
      'imageAlt': imageAlt,
      'localImagePath': localImagePath,
      'contentBlocks': contentBlocks.map((e) => e.toJson()).toList(),
      'categories': categories,
      'author': author,
    };
  }

  factory NoticiaModel.fromStorageJson(Map<String, dynamic> json) {
    return NoticiaModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      link: json['link']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      contentBlocks: (json['contentBlocks'] as List<dynamic>? ?? [])
          .map((e) => NoticiaContentBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
      imageUrl: json['imageUrl']?.toString() ?? '',
      imageAlt: json['imageAlt']?.toString() ?? '',
      localImagePath: json['localImagePath']?.toString() ?? '',
      categories:
          (json['categories'] as List<dynamic>? ?? [])
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList(),
      author: json['author']?.toString() ?? '',
    );
  }

  /// Parsea la respuesta de la API de noticias. El listado trae solo los campos
  /// de la tarjeta (`titulo`, `resumen`, `imagen`, …) y `by-link` agrega
  /// `contenido` en HTML. Se aceptan también las llaves del formato anterior de
  /// WordPress (`title.rendered`, `date`, `_embedded`…) para que la app no se
  /// quede sin datos si el backend todavía responde con ese formato.
  factory NoticiaModel.fromJson(Map<String, dynamic> json) {
    final rawContent = _campoTexto(json, const ['contenido', 'content']);

    return NoticiaModel(
      id: int.tryParse(_campoTexto(json, const ['id'])) ?? 0,
      link: _campoTexto(json, const ['link', 'url']),
      slug: _campoTexto(json, const ['slug']),
      date: DateTime.tryParse(
        _campoTexto(json, const ['fecha', 'date', 'date_gmt', 'publishedAt']),
      ),
      title: _cleanHtml(_campoTexto(json, const ['titulo', 'title'])),
      excerpt: _cleanHtml(
        _campoTexto(json, const ['resumen', 'excerpt', 'extracto']),
      ),
      content: _cleanHtml(rawContent, preserveParagraphs: true),
      contentBlocks: _parseContentBlocks(rawContent),
      imageUrl: _imagenUrl(json),
      imageAlt: _cleanHtml(_imagenAlt(json)),
      localImagePath: '',
      categories: _categorias(json),
      author: _autor(json),
    );
  }

  /// Nombre del autor de la nota.
  ///
  /// La API lo trae en `seo.author` (texto). Se acepta además el formato viejo
  /// de WordPress, donde el nombre va en `_embedded.author[0].name` —el
  /// `author` de primer nivel ahí es solo el id numérico, que no sirve—. Si no
  /// hay nada, queda vacío y la pantalla cae a "Redacción".
  static String _autor(Map<String, dynamic> json) {
    final seo = json['seo'];
    if (seo is Map) {
      final autor = _campoTexto(
        seo.cast<String, dynamic>(),
        const ['author', 'autor'],
      );
      if (autor.isNotEmpty) return _limpiarAutor(autor);
    }

    final embedded = json['_embedded'];
    if (embedded is Map) {
      final autores = embedded['author'];
      if (autores is List && autores.isNotEmpty) {
        final primero = autores.first;
        if (primero is Map) {
          final nombre = _campoTexto(
            primero.cast<String, dynamic>(),
            const ['name'],
          );
          if (nombre.isNotEmpty) return _limpiarAutor(nombre);
        }
      }
    }

    final directo = _campoTexto(json, const ['autor']);
    return directo.isNotEmpty ? _limpiarAutor(directo) : '';
  }

  /// Limpia el nombre del autor sin el tratamiento que se le da al cuerpo.
  ///
  /// Decodifica entidades (para las tildes) y quita cualquier etiqueta, pero a
  /// diferencia de [_cleanHtml] **no** descarta el "Redacción" inicial: es una
  /// firma válida ("Redacción Deportes"), no el prefijo de relleno del texto.
  static String _limpiarAutor(String value) {
    final sinTags = value.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return _decodeHtmlEntities(sinTags).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Devuelve la primera llave con valor. Soporta el envoltorio `{rendered: …}`
  /// que usa WordPress.
  static String _campoTexto(Map<String, dynamic> json, List<String> claves) {
    for (final clave in claves) {
      final value = json[clave];
      if (value == null) continue;
      if (value is Map) {
        final rendered = value['rendered']?.toString() ?? '';
        if (rendered.isNotEmpty) return rendered;
        continue;
      }
      if (value is List) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static Map<String, dynamic>? _imagen(Map<String, dynamic> json) {
    final imagen = json['imagen'] ?? json['image'];
    if (imagen is Map) return imagen.cast<String, dynamic>();

    final embedded = json['_embedded'] as Map<String, dynamic>?;
    final featuredMedia = embedded?['wp:featuredmedia'] as List<dynamic>?;
    if (featuredMedia != null && featuredMedia.isNotEmpty) {
      final media = featuredMedia.first;
      if (media is Map) return media.cast<String, dynamic>();
    }
    return null;
  }

  static String _imagenUrl(Map<String, dynamic> json) {
    final imagen = _imagen(json);
    if (imagen != null) {
      final url = _campoTexto(imagen, const ['url', 'source_url', 'src', 'link']);
      if (url.isNotEmpty) return url;
    }

    final directa = _campoTexto(json, const ['imagen', 'image', 'imagenUrl', 'imagen_url']);
    if (directa.isNotEmpty) return directa;

    final yoast = json['yoast_head_json'] as Map<String, dynamic>?;
    final ogImages = yoast?['og_image'] as List<dynamic>?;
    if (ogImages != null && ogImages.isNotEmpty) {
      final ogImage = ogImages.first;
      if (ogImage is Map) {
        return _campoTexto(ogImage.cast<String, dynamic>(), const ['url']);
      }
    }
    return '';
  }

  static String _imagenAlt(Map<String, dynamic> json) {
    final imagen = _imagen(json);
    if (imagen == null) return '';
    return _campoTexto(imagen, const ['alt', 'alt_text', 'descripcion']);
  }

  /// Acepta `[16, 33]` y también `[{"id": 16, …}]`.
  static List<int> _categorias(Map<String, dynamic> json) {
    final raw = json['categorias'] ?? json['categories'];
    if (raw is! List) return const [];

    return raw
        .map((e) {
          if (e is Map) return int.tryParse(e['id']?.toString() ?? '') ?? 0;
          return int.tryParse(e.toString()) ?? 0;
        })
        .where((id) => id > 0)
        .toList();
  }

  static List<NoticiaContentBlock> _parseContentBlocks(String html) {
    if (html.trim().isEmpty) return const [];

    final blocks = <NoticiaContentBlock>[];
    final mediaRegex = RegExp(
      r'''(?:<style\b[\s\S]*?<\/style>\s*)?<div\b(?=[^>]*class\s*=\s*(['"])[^'"]*\btd-gallery\b[^'"]*\1)[\s\S]*?(?=<p\b|<h[1-6]\b|$)|<div\b(?=[^>]*data-mow_video\s*=)[^>]*>\s*<\/div>|<amp-iframe\b[^>]*src\s*=\s*(['"])[^'"]*mowplayer\.com/watch/[^'"]*\2[\s\S]*?<\/amp-iframe>|<iframe\b[^>]*src\s*=\s*(['"])[^'"]*mowplayer\.com/watch/[^'"]*\3[\s\S]*?<\/iframe>|<iframe\b[^>]*src\s*=\s*(['"])[^'"]*facebook\.com/plugins/video\.php[^'"]*\4[\s\S]*?<\/iframe>|<blockquote\b(?=[^>]*class\s*=\s*(['"])[^'"]*\btwitter-tweet\b[^'"]*\5)[\s\S]*?<\/blockquote>(?:\s*(?:<p\b[^>]*>\s*)?<script\b[^>]*widgets\.js[^>]*>\s*<\/script>(?:\s*<\/p>)?)?|<figure\b[\s\S]*?<\/figure>|<img\b[^>]*>''',
      caseSensitive: false,
    );
    var currentIndex = 0;

    void addText(String value) {
      for (final fragment in _splitTextFragments(value)) {
        final text = _cleanHtml(fragment, preserveParagraphs: true);
        if (text.isEmpty) continue;

        final link = _extractRelatedArticleLink(fragment);
        if (link.isNotEmpty && _isHighlightedRelatedLinkText(text)) {
          blocks.add(
            NoticiaContentBlock.link(
              text: text,
              url: link,
            ).copyWithSourceHtml(fragment),
          );
          continue;
        }

        blocks.add(NoticiaContentBlock.text(text, sourceHtml: fragment));
      }
    }

    for (final match in mediaRegex.allMatches(html)) {
      addText(html.substring(currentIndex, match.start));

      final fragment = match.group(0) ?? '';
      if (_isGalleryFragment(fragment)) {
        final items = _extractGalleryItems(fragment);
        if (items.isNotEmpty) blocks.add(NoticiaContentBlock.gallery(items));
        currentIndex = match.end;
        continue;
      }

      // Va antes que las imágenes: WordPress a veces envuelve la inserción de X
      // en un `<figure>`, y como imagen no tiene `src` y se perdía entera.
      if (_esPublicacionDeX(fragment)) {
        final tweet = _extractTweet(fragment);
        if (tweet != null) {
          blocks.add(tweet);
        } else {
          // Sin enlace a la publicación no hay qué insertar; al menos que el
          // texto no se pierda.
          addText(fragment);
        }
        currentIndex = match.end;
        continue;
      }

      final videoUrl = _extractVideoUrl(fragment);
      if (videoUrl.isNotEmpty) {
        blocks.add(
          NoticiaContentBlock.video(
            videoUrl,
            aspectRatio: _proporcionDeVideo(fragment),
          ),
        );
        currentIndex = match.end;
        continue;
      }

      final src = _extractAttribute(fragment, 'src');
      final imageUrl =
          src.isNotEmpty ? src : _extractAttribute(fragment, 'data-src');
      if (imageUrl.isNotEmpty) {
        final captionMatch = RegExp(
          r'<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>',
          caseSensitive: false,
        ).firstMatch(fragment);
        final caption =
            captionMatch == null ? '' : _cleanHtml(captionMatch.group(1) ?? '');
        blocks.add(NoticiaContentBlock.image(url: imageUrl, caption: caption));
      }

      currentIndex = match.end;
    }

    addText(html.substring(currentIndex));
    return blocks;
  }

  static String _extractVideoUrl(String html) {
    final mowId = _extractAttribute(html, 'data-mow_video');
    if (mowId.isNotEmpty) return 'https://mowplayer.com/watch/$mowId';

    final src = _extractAttribute(html, 'src');
    if (src.isEmpty) return '';
    final normalizedSrc = src.startsWith('//') ? 'https:$src' : src;
    final uri = Uri.tryParse(normalizedSrc);
    if (uri == null) return '';

    if (uri.host.endsWith('mowplayer.com')) return normalizedSrc;

    // El reproductor oficial de Facebook para insertar videos y reels. Antes
    // el lector no lo reconocía, descartaba el iframe y el video directamente
    // no aparecía en la nota: ni reproductor ni enlace.
    if (esReproductorDeFacebook(normalizedSrc)) return normalizedSrc;

    return '';
  }

  /// `true` si [url] es el reproductor de Facebook para insertar videos.
  ///
  /// Pública porque la usa también el bloque de video, que a este reproductor
  /// le cuida hacia dónde navega.
  static bool esReproductorDeFacebook(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    return (uri.host == 'facebook.com' || uri.host.endsWith('.facebook.com')) &&
        uri.path.startsWith('/plugins/video.php');
  }

  /// Ancho sobre alto de un video insertado, leído de su `width` y `height`.
  ///
  /// Un reel de Facebook viene como `265×476`: meterlo en un 16:9 lo dejaba
  /// como una franja angosta en medio de dos bandas negras. Sin medidas —el
  /// `div` de MOW no las trae— o con valores absurdos se asume 16:9.
  static double _proporcionDeVideo(String html) {
    final ancho = double.tryParse(_extractAttribute(html, 'width'));
    final alto = double.tryParse(_extractAttribute(html, 'height'));
    if (ancho == null || alto == null || ancho <= 0 || alto <= 0) {
      return _proporcionHorizontalDeVideo;
    }

    final proporcion = ancho / alto;
    // Entre un vertical muy alto y un panorámico: fuera de eso es un error de
    // quien pegó el código, no un video.
    if (proporcion < 0.4 || proporcion > 2.5) {
      return _proporcionHorizontalDeVideo;
    }

    return proporcion;
  }

  static const double _proporcionHorizontalDeVideo = 16 / 9;

  static final _claseTwitterTweet = RegExp(
    r'\btwitter-tweet\b',
    caseSensitive: false,
  );

  static final _urlDePublicacionDeX = RegExp(
    r'https?://(?:www\.|mobile\.)?(?:twitter|x)\.com/(\w+)/status(?:es)?/(\d+)',
    caseSensitive: false,
  );

  static bool _esPublicacionDeX(String html) =>
      _claseTwitterTweet.hasMatch(html);

  /// Una publicación de X pegada con el código de inserción oficial.
  ///
  /// La redacción la pega tal como la da X: un `blockquote.twitter-tweet` con
  /// el texto y un enlace a la publicación, más el `<script>` de `widgets.js`.
  /// Sin esto el lector la tomaba como un párrafo más con enlaces, y tocarla
  /// sacaba al usuario de la app hacia x.com en vez de reproducir el video.
  static NoticiaContentBlock? _extractTweet(String html) {
    final estado = _urlDePublicacionDeX.firstMatch(html);
    if (estado == null) return null;

    // Sin los parámetros de rastreo que agrega X (`?ref_src=…`) y en el
    // dominio clásico, que `widgets.js` reconoce desde siempre.
    final url =
        'https://twitter.com/${estado.group(1)}/status/${estado.group(2)}';

    // El primer párrafo es el texto de la publicación; lo que sigue es la firma
    // ("— Diario Tiempo de Honduras (@TiempoHonduras) September 28, 2026").
    final parrafo = RegExp(
      r'<p\b[^>]*>([\s\S]*?)<\/p>',
      caseSensitive: false,
    ).firstMatch(html);
    final texto = _cleanHtml(parrafo?.group(1) ?? '')
        .replaceAll(RegExp(r'pic\.(?:twitter|x)\.com/\S+'), '')
        .replaceAll(RegExp(r'https?://t\.co/\S+'), '')
        .trim();

    return NoticiaContentBlock.tweet(url: url, text: texto);
  }

  static bool _isGalleryFragment(String html) {
    return RegExp(r'\btd-gallery\b', caseSensitive: false).hasMatch(html);
  }

  static List<NoticiaGalleryItem> _extractGalleryItems(String html) {
    final items = <NoticiaGalleryItem>[];
    final seen = <String>{};
    final anchorRegex = RegExp(
      "<a\\b[^>]*class\\s*=\\s*(['\"])[^'\"]*\\bslide-gallery-image-link\\b[^'\"]*\\1[^>]*>[\\s\\S]*?<\\/a>",
      caseSensitive: false,
    );

    for (final match in anchorRegex.allMatches(html)) {
      final fragment = match.group(0) ?? '';
      final href = _extractAttribute(fragment, 'href');
      final src = _extractAttribute(fragment, 'src');
      final dataSrc = _extractAttribute(fragment, 'data-src');
      final imageUrl =
          href.isNotEmpty
              ? href
              : src.isNotEmpty
              ? src
              : dataSrc;
      if (imageUrl.isEmpty || seen.contains(imageUrl)) continue;

      final dataCaption = _extractAttribute(fragment, 'data-caption');
      final caption =
          dataCaption.isNotEmpty
              ? _cleanHtml(dataCaption)
              : _extractFigureCaption(fragment);
      items.add(NoticiaGalleryItem(imageUrl: imageUrl, caption: caption));
      seen.add(imageUrl);
    }

    if (items.isNotEmpty) return items;

    final figureRegex = RegExp(
      r'<figure\b[\s\S]*?<\/figure>|<img\b[^>]*>',
      caseSensitive: false,
    );
    for (final match in figureRegex.allMatches(html)) {
      final fragment = match.group(0) ?? '';
      final src = _extractAttribute(fragment, 'src');
      final dataSrc = _extractAttribute(fragment, 'data-src');
      final imageUrl = src.isNotEmpty ? src : dataSrc;
      if (imageUrl.isEmpty || seen.contains(imageUrl)) continue;

      items.add(
        NoticiaGalleryItem(
          imageUrl: imageUrl,
          caption: _extractFigureCaption(fragment),
        ),
      );
      seen.add(imageUrl);
    }

    return items;
  }

  static String _extractFigureCaption(String html) {
    final captionMatch = RegExp(
      r'<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>',
      caseSensitive: false,
    ).firstMatch(html);
    return captionMatch == null ? '' : _cleanHtml(captionMatch.group(1) ?? '');
  }

  static List<String> _splitTextFragments(String html) {
    final fragments = <String>[];
    final blockRegex = RegExp(
      r'<(p|div|h[1-6]|li|blockquote)\b[^>]*>[\s\S]*?<\/\1>',
      caseSensitive: false,
    );
    var currentIndex = 0;

    for (final match in blockRegex.allMatches(html)) {
      if (match.start > currentIndex) {
        fragments.add(html.substring(currentIndex, match.start));
      }
      fragments.add(match.group(0) ?? '');
      currentIndex = match.end;
    }

    if (currentIndex < html.length) {
      fragments.add(html.substring(currentIndex));
    }

    return fragments.isEmpty ? [html] : fragments;
  }

  static String _extractRelatedArticleLink(String html) {
    final anchorMatch = RegExp(
      "<a\\b[^>]*href\\s*=\\s*(['\"])(.*?)\\1[\\s\\S]*?<\\/a>",
      caseSensitive: false,
    ).firstMatch(html);
    if (anchorMatch == null) return '';

    final link = _decodeHtmlEntities(anchorMatch.group(2) ?? '').trim();
    final normalizedLink = _normalizeTiempoLink(link);
    final uri = Uri.tryParse(normalizedLink);
    if (uri == null || uri.host.isEmpty) return '';

    final host = uri.host.toLowerCase();
    return host == 'tiempo.hn' || host.endsWith('.tiempo.hn') ? normalizedLink : '';
  }

  static String _normalizeTiempoLink(String rawLink) {
    final link = _decodeHtmlEntities(rawLink).trim();
    if (link.isEmpty) return '';

    if (link.startsWith('/')) return 'https://tiempo.hn$link';
    if (link.startsWith('//')) return 'https:$link';

    final parsed = Uri.tryParse(link);
    if (parsed == null) return link;

    if (!parsed.hasScheme && parsed.hasAuthority) {
      return 'https://$link';
    }

    if (!parsed.hasScheme && !parsed.hasAuthority) {
      final path = link.startsWith('/') ? link : '/$link';
      return 'https://tiempo.hn$path';
    }

    return link;
  }

  static bool _isHighlightedRelatedLinkText(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('le puede interesar') ||
        normalized.contains('lea la edición anterior') ||
        normalized.contains('también puede leer') ||
        normalized.contains('de igual importancia') ||
        normalized.contains('lea la edicion anterior');
  }

  static String _extractAttribute(String html, String attribute) {
    final match = RegExp(
      "$attribute\\s*=\\s*(['\"])(.*?)\\1",
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return '';
    return _decodeHtmlEntities(match.group(2) ?? '').trim();
  }

  static String _cleanHtml(String value, {bool preserveParagraphs = false}) {
    var text = value
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'</\s*(p|div|h[1-6]|li|blockquote)\s*>',
            caseSensitive: false,
          ),
          preserveParagraphs ? '\n\n' : ' ',
        )
        .replaceAll(RegExp(r'<[^>]*>'), ' ');

    text = _decodeHtmlEntities(text);

    if (preserveParagraphs) {
      return _stripRedaccionPrefix(
        text
          .split('\n')
          .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((line) => line.isNotEmpty)
          .join('\n\n'),
      );
    }

    return _stripRedaccionPrefix(text.replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  static String _decodeHtmlEntities(String value) {
    var text = value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rsquo;', '’')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…');

    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final codePoint = int.tryParse(match.group(1) ?? '');
      if (codePoint == null) return match.group(0) ?? '';
      return String.fromCharCode(codePoint);
    });

    return text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final codePoint = int.tryParse(match.group(1) ?? '', radix: 16);
      if (codePoint == null) return match.group(0) ?? '';
      return String.fromCharCode(codePoint);
    });
  }

  static String _stripRedaccionPrefix(String value) {
    return value.replaceFirst(
      RegExp(r'^\s*redacci[oó]n[\s\.:,\-–—]+\s*', caseSensitive: false),
      '',
    );
  }
}

String _cleanHtml(String value, {bool preserveParagraphs = false}) {
  var text = value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</\s*(p|div|h[1-6]|li|blockquote)\s*>', caseSensitive: false),
        preserveParagraphs ? '\n\n' : ' ',
      )
      .replaceAll(RegExp(r'<[^>]*>'), ' ');

  text = _decodeHtmlEntities(text);

  if (preserveParagraphs) {
    return _stripRedaccionPrefix(
      text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .join('\n\n'),
    );
  }

  return _stripRedaccionPrefix(text.replaceAll(RegExp(r'\s+'), ' ').trim());
}

String _decodeHtmlEntities(String value) {
  var text = value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&lsquo;', '‘')
      .replaceAll('&rsquo;', '’')
      .replaceAll('&ndash;', '–')
      .replaceAll('&mdash;', '—')
      .replaceAll('&hellip;', '…');

  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
    final codePoint = int.tryParse(match.group(1) ?? '');
    if (codePoint == null) return match.group(0) ?? '';
    return String.fromCharCode(codePoint);
  });

  return text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
    final codePoint = int.tryParse(match.group(1) ?? '', radix: 16);
    if (codePoint == null) return match.group(0) ?? '';
    return String.fromCharCode(codePoint);
  });
}

String _stripRedaccionPrefix(String value) {
  return value.replaceFirst(
    RegExp(r'^\s*redacci[oó]n[\s\.:,\-–—]+\s*', caseSensitive: false),
    '',
  );
}
