/// Tope de espera para las llamadas de red que **no** deben poder congelar la
/// app.
///
/// Sin conexión, un socket puede quedarse esperando hasta que el sistema
/// operativo lo corte (a veces minutos, a veces nunca). Como BlackReader es
/// una app de lectura offline, cualquier petición que esté en el camino del
/// arranque o de abrir un libro lleva este timeout y cae al dato local.
const Duration kNetworkTimeout = Duration(seconds: 8);

/// Lo mismo con datos móviles (ver `MobileData.timeout`): con megas la
/// primera respuesta suele tardar más, y 8 s hacía caer la biblioteca a solo
/// los libros descargados aunque la red funcionara.
const Duration kMobileNetworkTimeout = Duration(seconds: 20);

/// Espera de gracia del arranque: si pasado este tiempo Supabase todavía no
/// ha dicho si hay sesión, seguimos con la sesión guardada en el dispositivo
/// en vez de dejar el splash en pantalla para siempre.
const Duration kBootstrapTimeout = Duration(seconds: 3);
