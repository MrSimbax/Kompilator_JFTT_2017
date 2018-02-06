# Kompilator JFTT 2017/2018

Projekt kompilatora dla specjalnego języka programowania i maszyny
rejestrowej w ramach przedmiotu _Języki formalne i techniki translacji_.

Kompilator zajął **16. miejsce** pod względem szybkości kodu wynikowego
na 85 osób biorących udział w "konkursie".

Dokładna specyfikacja od wykładowcy
znajduje się w pliku `specyfikacja.pdf`. Kod interpretera dla maszyny
rejestrowej znajduje się w katalogu `interpreter`.

## Autor kompilatora

Mateusz Przybył

## Kompilacja

W głównym katalogu użyć polecenia `make`.
Aby wyczyścić katalog z powstałych plików, użyć `make clean`.

**Uwaga.** Wymagana jest zainstalowana biblioteka `cln` do obsługi
dużych liczb, oraz `BISON` i `FLEX`.

## Uruchomienie

Po kompilacji powstanie plik wynikowy o nazwie `kompilator`.
Kod źródłowy jest wczytywany z `stdin`.
Kod dla interpretera jest wypisywany na `stdout`.
Ewentualne komunikaty o błędach są wypisywane do `stderr`.

Przykład użycia:

    ./kompilator < program.imp > program.mr

Program był testowany pod Linuxem 64-bitowym. 

## Testy automatyczne

Testy automatyczne wymagają zainstalowanego interpretera języka `Python`
w wersji `3.5+` oraz biblioteki [`pytest`](https://pytest.org/).

Testy wymagają skompilowanego interpretera. W tym celu
można wykonać polecenie `make` w folderze `interpreter`.

Aby uruchomić testy, wystarczy wykonać polecenie `make test`.

Programy do testowania znajdują się w folderze `test`, same testy
znajdują się wpliku `test/test_all.py`.
