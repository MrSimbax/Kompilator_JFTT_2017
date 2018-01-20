# Kompilator JFTT 2017

## Autor

Mateusz Przybył

## Kompilacja

W głównym katalogu użyć polecenia `make`.
Aby wyczyścić katalog z powstałych plików, użyć `make clean`.

**Uwaga.** Wymagana jest zainstalowana biblioteka `cln`.

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
należy wykonać polecenie `make` w folderze `interpreter`.

Aby uruchomić testy, wystarczy wykonać polecenie `make test`.

Programy do testowania znajdują się w folderze `test`, same testy
znajdują się wpliku `test/test_all.py`.
