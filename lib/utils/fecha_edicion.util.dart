/// Fechas de las ediciones del diario, sacadas de donde de verdad están.
///
/// La fecha de una edición no llega como campo propio en ningún lado: ni el
/// push del "Nuevo Flip" ni la API la traen suelta. `fechaPublicacion` viene con
/// el primer día del mes (`2026-09-01`), así que no sirve para saber de qué día
/// es un diario. Lo que sí la lleva siempre es el nombre del archivo que sube la
/// redacción: `DiarioTiempo-29-09-26_compressed` es la del 29 de septiembre.
library;

const _diasDeLaSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const _mesesDelAnio = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Día, mes y año con guiones: `29-09-26` o `29-09-2026`.
///
/// Los bordes `(?<!\d)` y `(?!\d)` evitan agarrar un pedazo de otro número:
/// sin ellos, un `2026-09-29` en formato ISO coincidía en el medio (`26-09-29`)
/// y salía el 26 de septiembre de 2029.
final _patronFecha = RegExp(r'(?<!\d)(\d{1,2})-(\d{1,2})-(\d{4}|\d{2})(?!\d)');

/// La fecha escrita en el nombre de archivo de una edición, o `null`.
///
/// El orden es día-mes-año, que es como nombra la redacción los archivos. Un
/// año de dos dígitos se toma como 20xx: el archivo empieza en 2008.
DateTime? fechaEnNombreDeArchivo(String? texto) {
  if (texto == null) return null;

  final coincidencia = _patronFecha.firstMatch(texto);
  if (coincidencia == null) return null;

  final dia = int.parse(coincidencia.group(1)!);
  final mes = int.parse(coincidencia.group(2)!);
  var anio = int.parse(coincidencia.group(3)!);
  if (anio < 100) anio += 2000;

  final fecha = DateTime(anio, mes, dia);

  // `DateTime` no rechaza fechas imposibles, las corre: el 31-02 lo convierte
  // en 3 de marzo. Un nombre mal escrito tiene que dar `null`, no otro día.
  if (fecha.year != anio || fecha.month != mes || fecha.day != dia) {
    return null;
  }

  return fecha;
}

/// `true` si las dos fechas caen el mismo día, sin importar la hora.
bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Martes 29 de septiembre", para encabezar una pantalla.
///
/// El año solo se agrega cuando no es el actual: en el diario de esta semana
/// sobra, en uno del año pasado es justo lo que hay que saber.
String fechaDeEdicionTitular(DateTime fecha, {DateTime? hoy}) {
  final texto = fechaDeEdicionEnFrase(fecha, hoy: hoy);
  return texto[0].toUpperCase() + texto.substring(1);
}

/// "lunes 22 de septiembre", para usar en medio de una oración.
String fechaDeEdicionEnFrase(DateTime fecha, {DateTime? hoy}) {
  final referencia = hoy ?? DateTime.now();
  final dia = _diasDeLaSemana[fecha.weekday - 1];
  final mes = _mesesDelAnio[fecha.month - 1];
  final anio = fecha.year == referencia.year ? '' : ' de ${fecha.year}';

  return '$dia ${fecha.day} de $mes$anio';
}
