import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/utils/html_texto.util.dart';

/// Lo que el lector de voz va a pronunciar, ya partido en trozos.
class GuionNoticia {
  const GuionNoticia(this.parrafos);

  const GuionNoticia.vacio() : parrafos = const [];

  final List<String> parrafos;

  bool get estaVacio => parrafos.isEmpty;

  int get caracteres =>
      parrafos.fold(0, (total, parrafo) => total + parrafo.length);
}

/// Tope por trozo enviado al motor de voz.
///
/// Android rechaza cadenas muy largas en un solo `speak` (el límite ronda los
/// 4000 caracteres). Se corta bastante antes porque cada trozo es además la
/// unidad de avance: con trozos cortos, pausar y reanudar pierde a lo sumo unos
/// segundos de audio en vez de un párrafo entero.
const _maximoCaracteresPorTrozo = 600;

/// Arranques de párrafo que no aportan nada leídos en voz alta.
final _frasesIgnoradas = <RegExp>[
  RegExp(r'^\s*(lea|vea|le[ea]?)\s+(tambi[eé]n|adem[aá]s|m[aá]s)\b',
      caseSensitive: false),
  RegExp(r'^\s*(te|le)\s+puede\s+interesar\b', caseSensitive: false),
  RegExp(r'^\s*m[aá]s\s+noticias\b', caseSensitive: false),
  RegExp(r'^\s*(foto|fotos|imagen|cr[eé]dito|fuente)\s*:', caseSensitive: false),
];

/// Un párrafo que es solo una dirección web: leerlo letra por letra es ruido.
final _soloUrl = RegExp(r'^\s*https?://\S+\s*$', caseSensitive: false);

/// Corta al final de una oración, para que el motor respire donde corresponde.
final _finDeOracion = RegExp(r'(?<=[.!?…])\s+');

/// Arma el texto que se va a leer a partir de la noticia ya cargada.
///
/// Toma el titular y los bloques de texto. Deja fuera imágenes, galerías,
/// videos y enlaces relacionados: son navegación, no nota. Los anuncios ni
/// siquiera son bloques del modelo, así que no hay riesgo de que se cuelen.
GuionNoticia construirGuionDeLectura(NoticiaModel noticia) {
  final crudos = <String>[];

  final titulo = noticia.title.trim();
  if (titulo.isNotEmpty) {
    // El punto final hace que el motor haga una pausa antes del cuerpo; sin él
    // el titular se encadena con la primera frase y se entiende peor.
    crudos.add(RegExp(r'[.!?…]$').hasMatch(titulo) ? titulo : '$titulo.');
  }

  final bloques = noticia.contentBlocks.where((bloque) => bloque.isText);
  for (final bloque in bloques) {
    crudos.addAll(bloque.text.split('\n\n'));
  }

  // Notas viejas o guardadas antes de que existieran los bloques.
  if (bloques.isEmpty) {
    final respaldo =
        noticia.content.isNotEmpty ? noticia.content : noticia.excerpt;
    crudos.addAll(limpiarHtml(respaldo, preservarParrafos: true).split('\n\n'));
  }

  final parrafos = <String>[];
  for (final crudo in crudos) {
    final parrafo = crudo.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!_valeLaPenaLeer(parrafo)) continue;
    parrafos.addAll(_trocear(normalizarParaVoz(parrafo)));
  }

  return GuionNoticia(List.unmodifiable(parrafos));
}

bool _valeLaPenaLeer(String parrafo) {
  if (parrafo.length < 3) return false;
  if (_soloUrl.hasMatch(parrafo)) return false;
  return !_frasesIgnoradas.any((patron) => patron.hasMatch(parrafo));
}

/// Reescribe cifras y abreviaturas como se dicen en voz alta.
///
/// Es lo que más delata al motor en una nota de periódico: "L. 5,000" leído
/// literal sale como "ele punto cinco coma cero cero cero", y una sola de esas
/// arruina el párrafo entero por buena que sea la voz. Solo afecta al audio: el
/// texto que se ve en pantalla no se toca.
String normalizarParaVoz(String texto) {
  var salida = texto;

  // Separador de miles: en Honduras es la coma, y el motor la lee como decimal.
  // Se repite porque cada pasada solo resuelve un grupo ("1,234,567").
  String previo;
  do {
    previo = salida;
    salida = salida.replaceAllMapped(
      RegExp(r'(\d),(\d{3})(?!\d)'),
      (m) => '${m[1]}${m[2]}',
    );
  } while (previo != salida);

  for (final regla in _reglasDeVoz) {
    salida = salida.replaceAllMapped(regla.patron, regla.reemplazo);
  }

  return salida.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _ReglaDeVoz {
  const _ReglaDeVoz(this.patron, this.reemplazo);

  final RegExp patron;
  final String Function(Match) reemplazo;
}

String _conMoneda(Match match, String moneda) {
  final magnitud = match[2] ?? '';
  if (magnitud.trim().isEmpty) return '${match[1]} $moneda';
  return '${match[1]}$magnitud de $moneda';
}

final _reglasDeVoz = <_ReglaDeVoz>[
  // Monedas: la cifra va antes y la unidad después, como se dice. Si la cifra
  // trae magnitud ("L. 5,000 millones") la moneda va al final y con "de", que
  // es como se lee: "cinco mil millones de lempiras".
  _ReglaDeVoz(
    RegExp(
      r'\b(?:L|Lps)\.?\s*(\d+(?:\.\d+)?)(\s*(?:millones|mill[oó]n|billones|mil|miles))?',
      caseSensitive: false,
    ),
    (m) => _conMoneda(m, 'lempiras'),
  ),
  _ReglaDeVoz(
    RegExp(
      r'(?:US)?\$\s*(\d+(?:\.\d+)?)(\s*(?:millones|mill[oó]n|billones|mil|miles))?',
      caseSensitive: false,
    ),
    (m) => _conMoneda(m, 'dólares'),
  ),
  _ReglaDeVoz(
    RegExp(r'(\d+(?:\.\d+)?)\s*%'),
    (m) => '${m[1]} por ciento',
  ),
  // Unidades pegadas a una cifra.
  _ReglaDeVoz(
    RegExp(r'(\d+(?:\.\d+)?)\s*km\b', caseSensitive: false),
    (m) => '${m[1]} kilómetros',
  ),
  _ReglaDeVoz(
    RegExp(r'(\d+(?:\.\d+)?)\s*kg\b', caseSensitive: false),
    (m) => '${m[1]} kilogramos',
  ),
  // Horas.
  _ReglaDeVoz(
    RegExp(r'\ba\.\s*m\.', caseSensitive: false),
    (_) => 'de la mañana',
  ),
  _ReglaDeVoz(
    RegExp(r'\bp\.\s*m\.', caseSensitive: false),
    (_) => 'de la tarde',
  ),
  // Abreviaturas frecuentes en notas de tribunales y congreso.
  _ReglaDeVoz(
    RegExp(r'\bEE\.?\s*UU\.?', caseSensitive: false),
    (_) => 'Estados Unidos',
  ),
  _ReglaDeVoz(RegExp(r'\bArt\.', caseSensitive: false), (_) => 'artículo'),
  _ReglaDeVoz(RegExp(r'\bNo\.\s*(?=\d)', caseSensitive: false), (_) => 'número '),
  _ReglaDeVoz(RegExp(r'\bDra\.', caseSensitive: false), (_) => 'doctora'),
  _ReglaDeVoz(RegExp(r'\bDr\.', caseSensitive: false), (_) => 'doctor'),
  _ReglaDeVoz(RegExp(r'\bLic\.', caseSensitive: false), (_) => 'licenciado'),
  _ReglaDeVoz(RegExp(r'\bIng\.', caseSensitive: false), (_) => 'ingeniero'),
  _ReglaDeVoz(RegExp(r'\bSra\.', caseSensitive: false), (_) => 'señora'),
  _ReglaDeVoz(RegExp(r'\bSr\.', caseSensitive: false), (_) => 'señor'),
];

/// Parte un párrafo largo en trozos que quepan en un `speak`, cortando entre
/// oraciones siempre que se pueda.
List<String> _trocear(String parrafo) {
  if (parrafo.length <= _maximoCaracteresPorTrozo) return [parrafo];

  final trozos = <String>[];
  final buffer = StringBuffer();

  void volcar() {
    final trozo = buffer.toString().trim();
    if (trozo.isNotEmpty) trozos.add(trozo);
    buffer.clear();
  }

  for (final oracion in parrafo.split(_finDeOracion)) {
    // Una sola oración kilométrica (pasa con listados separados por comas):
    // no queda otra que cortarla entre palabras.
    if (oracion.length > _maximoCaracteresPorTrozo) {
      volcar();
      trozos.addAll(_trocearPorPalabras(oracion));
      continue;
    }

    if (buffer.length + oracion.length + 1 > _maximoCaracteresPorTrozo) {
      volcar();
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(oracion);
  }

  volcar();
  return trozos;
}

List<String> _trocearPorPalabras(String oracion) {
  final trozos = <String>[];
  final buffer = StringBuffer();

  for (final palabra in oracion.split(' ')) {
    if (buffer.isNotEmpty &&
        buffer.length + palabra.length + 1 > _maximoCaracteresPorTrozo) {
      trozos.add(buffer.toString().trim());
      buffer.clear();
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(palabra);
  }

  final resto = buffer.toString().trim();
  if (resto.isNotEmpty) trozos.add(resto);
  return trozos;
}
