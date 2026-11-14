/// Proyecto de Supabase de la app.
///
/// Aparte de `main.dart` porque la descarga en segundo plano corre en otro
/// isolate (el del servicio de Android), donde `Supabase.instance` no existe:
/// allí se crea un cliente propio con estos mismos datos.
const supabaseUrl = 'https://ewyiuywiyykekoearvlo.supabase.co';

/// La anon key es pública por diseño; la seguridad la ponen las políticas RLS.
const supabasePublishableKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV3eWl1eXdpeXlrZWtvZWFydmxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0NTAyMTcsImV4cCI6MjA5NjAyNjIxN30.faabc5HgHW9lX_YBePvmPV1e-FJGu55EXCyytbs3rLk';
