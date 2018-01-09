# Kompilator JFTT 2017

## Autor

Mateusz Przybył

## Kompilacja

W głównym katalogu użyć polecenia `make`.
Aby wyczyścić katalog z powstałych plików, użyć `make clean`.

**Uwaga.** Wymagana jest zainstalowana biblioteka `cln`.

## Testowanie

Po kompilacji powstanie plik wynikowy o nazwie `kompilator`.
Kod źródłowy jest wczytywany ze standardowego wejścia.
Kod dla interpretera jest wypisywany na standardowe wyjście.
Ewentualne komunikaty o błędach są wypisywane do `stderr`.

Przykład użycia:

    ./kompilator < program.imp > program.mr

Program był testowany pod Linuxem 64-bitowym. 
