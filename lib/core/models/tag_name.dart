/// Jedna normalizacja nazwy tagu dla calej aplikacji: tagi z modelu i tagi dopisane recznie
/// musza trafiac do bazy w tej samej postaci, inaczej "Spotkanie" i "spotkanie" bylyby dwoma
/// osobnymi chipami filtru opisujacymi to samo.
String normalizeTagName(String raw) => raw.trim().toLowerCase();
