# Mikro

Dyktafon na Androida i Linuksa, ktory nagrania glosowe zamienia na tekst przy pomocy
zewnetrznej uslugi transkrypcji zgodnej z API OpenAI. Nagrania trafiaja do lokalnej
bazy na urzadzeniu; nic poza samym audio i transkryptem nie opuszcza maszyny.

## Co potrafi

- nagrywanie z mikrofonu z podgladem poziomu sygnalu i zapisem obwiedni amplitudy
- automatyczna transkrypcja zaraz po zakonczeniu nagrania, w tle
- tytul i tagi ukladane przez model jezykowy z gotowego transkryptu
- biblioteka nagran z odtwarzaniem, wyszukiwaniem rozmytym i filtrem po tagach
- reczna edycja tagow w szczegolach nagrania
- kolejka offline: nagrania, ktore utknely na bledzie sieci, wznawiaja sie po powrocie
  lacznosci; bledy autoryzacji czy limitu nie sa ponawiane, bo ponowia sie tak samo
- interfejs po polsku i angielsku, motyw jasny/ciemny i cztery palety kolorow

Adres uslugi, klucz API i nazwy modeli ustawia sie w aplikacji. Klucz idzie do
schowka systemowego (Keystore na Androidzie, libsecret na Linuksie), nie do preferencji.

## Budowanie

Toolchain siedzi w devcontainerze (`.devcontainer/`) i tylko tam jest przewidziany —
Flutter, Android SDK i biblioteki natywne Linuksa sa zainstalowane w obrazie. Kontener
otwiera sie dowolnym klientem devcontainerow albo z linii polecen:

```sh
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . flutter test
devcontainer exec --workspace-folder . flutter build linux --release
devcontainer exec --workspace-folder . flutter build apk --release
```

Paczki desktopowe skladaja skrypty z `packaging/` — obie biora ten sam bundle Fluttera
i te same metadane desktopowe, wiec nie da sie ich rozjechac:

```sh
./packaging/build-flatpak.sh --install
./packaging/build-appimage.sh
```

Skrypty domyslnie wolaja build wewnatrz devcontainera; szczegoly, zaleznosci systemowe
i uklad katalogow opisuje `packaging/README.md`.

## Licencje

Kod aplikacji jest wlasnoscia autora. Zbundlowany kroj Roboto Mono
(`assets/fonts/`) jest na licencji SIL Open Font License 1.1 — pelny tekst lezy
w `assets/fonts/OFL.txt` i musi isc razem z fontem w kazdej dystrybucji.
