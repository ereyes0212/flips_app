/// Herramientas para reconocer los enlaces de nuestros sitios.
///
/// Las notificaciones de campaña traen la URL pública de la nota
/// (`https://tiempo.hn/...`). Esas se leen dentro de la app; cualquier otro
/// dominio se manda al navegador porque no tenemos cómo renderizarlo.
class NoticiaLinkUtil {
  static const _dominiosPropios = {'tiempo.hn', 'diariotiempo.hn'};

  /// Completa enlaces relativos o sin esquema para poder leerles el host.
  ///
  /// Sigue el mismo criterio que el contenido de las notas: lo que no trae
  /// dominio se asume de `tiempo.hn`.
  static String normalizar(String rawLink) {
    final link = rawLink.trim();
    if (link.isEmpty) return '';
    if (link.startsWith('//')) return 'https:$link';
    if (link.startsWith('/')) return 'https://tiempo.hn$link';

    final parsed = Uri.tryParse(link);
    if (parsed == null || parsed.hasScheme) return link;
    if (parsed.hasAuthority) return 'https://$link';

    return 'https://tiempo.hn/$link';
  }

  /// `true` si el enlace apunta a uno de nuestros dominios (o a un subdominio).
  static bool esDominioPropio(String url) {
    final host = Uri.tryParse(normalizar(url))?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;

    return _dominiosPropios.any(
      (dominio) => host == dominio || host.endsWith('.$dominio'),
    );
  }

  /// Último segmento de la ruta: es el slug con el que la API busca la nota.
  static String slugDesdeEnlace(String url) {
    final uri = Uri.tryParse(normalizar(url));
    if (uri == null) return '';

    final segmentos = uri.pathSegments
        .map((segmento) => segmento.trim())
        .where((segmento) => segmento.isNotEmpty)
        .toList();

    return segmentos.isEmpty ? '' : segmentos.last;
  }
}
