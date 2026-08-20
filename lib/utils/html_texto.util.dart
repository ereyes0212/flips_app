/// Limpieza de HTML compartida por el detalle de noticia y por el lector de voz.
///
/// Vivía duplicada dentro de dos widgets del detalle. Al sumar el lector iba a
/// quedar una tercera copia y, peor, la voz podía terminar leyendo un texto
/// distinto del que se ve en pantalla. Acá queda una sola versión.
library;

/// Convierte el HTML de WordPress en texto plano.
///
/// [preservarParrafos] mantiene los saltos dobles entre bloques; sin él todo
/// colapsa en una sola línea.
///
/// [quitarPrefijoRedaccion] descarta el "Redacción." con el que arrancan las
/// notas del diario. Los enlaces relacionados no lo llevan, así que el flag
/// existe para respetar esa diferencia.
String limpiarHtml(
  String value, {
  bool preservarParrafos = false,
  bool quitarPrefijoRedaccion = true,
}) {
  var text = value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</\s*(p|div|h[1-6]|li|blockquote)\s*>', caseSensitive: false),
        preservarParrafos ? '\n\n' : ' ',
      )
      .replaceAll(RegExp(r'<[^>]*>'), ' ');

  text = decodificarEntidadesHtml(text);

  final limpio = preservarParrafos
      ? text
            .split('\n')
            .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((line) => line.isNotEmpty)
            .join('\n\n')
      : text.replaceAll(RegExp(r'\s+'), ' ').trim();

  return quitarPrefijoRedaccion ? quitarPrefijoDeRedaccion(limpio) : limpio;
}

String decodificarEntidadesHtml(String value) {
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

String quitarPrefijoDeRedaccion(String value) {
  return value.replaceFirst(
    RegExp(r'^\s*redacci[oó]n[\s\.:,\-–—]+\s*', caseSensitive: false),
    '',
  );
}
