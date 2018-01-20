"""
Testy dla kompilatora.
"""

import subprocess
import os
import re

COMPILER_PATH = "../kompilator"
INTERPRETER_PATH = "../interpreter/interpreter-cln"

"""
Sprawdza, czy kompilacja wszystkich plików error*.imp zwraca błąd
(kompilator zwraca kod błędu różny od 0)
"""
def test_errors():
    for prog in os.listdir():
        if re.match(r"error.*\.imp", prog):
            with open(prog, 'rb') as progf:
                compl_proc = subprocess.run(COMPILER_PATH, stdin=progf)
                print(prog)
                assert compl_proc.returncode != 0

"""
Kompiluje i uruchamia program o nazwie imp_name.
Może to być ścieżka względem miejsca uruchomienia pytest, ale BEZ
rozszerzenia imp.

Funkcja zakłada, że plik z kodem ma rozszerzenie imp. Plik wyjściowy
będzie miał roszerzenie mr.

given_input -- string bajtowy,
    dane wejściowe dla programu oddzielone znakiem nowej linii, lub pusty string
expected_output -- string bajtowy
    oczekiwane wyjście programu,
    liczby oddzielone znakiem nowej linii lub pusty string

Test się nie powodzi, gdy:
    1. kompilator zwrócił kod błędu różny od zera (błąd kompilacji)
    2. interpreter zwrócił za mało linijek (czyli program się nie wykonał)
    3. oczekiwane wyjście nie zgadza się z wyjściem faktycznym

Zwraca czas wykonania w postaci stringa.
"""
def run_program(imp_name, given_input, expected_output):
    mr_name = imp_name + ".mr"
    imp_name = imp_name + ".imp"
    with open(imp_name, 'rb') as impf, open(mr_name, 'wb') as mrf:
        compl_proc = subprocess.run(COMPILER_PATH, stdin=impf, stdout=mrf)
        assert compl_proc.returncode == 0
    compl_proc = subprocess.run([INTERPRETER_PATH, mr_name], input=given_input, stdout=subprocess.PIPE)
    lines = compl_proc.stdout.split(b'\n')
    if len(lines) < 5:
        assert False
    output = b''
    for line in lines[3:-2]:
        match = re.search(b'.*> (\d+)', line)
        assert match
        output += match.group(1) + b'\n'
        print(line)
    assert output == expected_output
    match = re.search(b'czas: (\d+)', lines[-2])
    return match.group(1)

"""
Tutaj są testy.
"""

def test_program0():
    run_program("program0", b'0\n', b'')
    run_program("program0", b'1\n', b'1\n')
    run_program("program0", b'2\n', b'0\n1\n')
    run_program("program0", b'1345601\n', b'1\n0\n0\n0\n0\n0\n1\n0\n0\n0\n0\n1\n0\n0\n0\n1\n0\n0\n1\n0\n1\n')

def test_program1():
    run_program("program1", b'', b'2\n3\n5\n7\n11\n13\n17\n19\n23\n29\n31\n37\n41\n43\n47\n53\n59\n61\n67\n71\n73\n79\n83\n89\n97\n')

def test_program2():
    assert len(run_program("program2", b'12345678901\n', b'857\n1\n14405693\n1\n')) <= 8
    # assert len(run_program("program2", b'12345678903\n', b'3\n1\n4115226301\n1\n')) <= 9

def test_numbers():
    run_program('1-numbers', b'20\n', b'0\n1\n2\n10\n100\n10000\n1234567890\n35\n15\n999\n555555555\n7777\n999\n11\n707\n7777\n')

def test_fib():
    run_program('2-fib', b'1\n', b'121393\n')

def test_fib_factorial():
    run_program('3-fib-factorial', b'20\n', b'2432902008176640000\n17711\n')

def test_factorial():
    run_program('4-factorial', b'20\n', b'2432902008176640000\n')

def test_tab():
    run_program('5-tab', b'', b'0\n23\n44\n63\n80\n95\n108\n119\n128\n135\n140\n143\n144\n143\n140\n135\n128\n119\n108\n95\n80\n63\n44\n23\n0\n')

def test_mod_mult():
    run_program('6-mod-mult', b'1234567890\n1234567890987654321\n987654321\n', b'674106858\n')

def test_loopiii():
    run_program('7-loopiii', b'0\n0\n0\n', b'31000\n40900\n2222010\n')
    run_program('7-loopiii', b'1\n0\n2\n', b'31001\n40900\n2222012\n')

def test_for():
    run_program('8-for', b'12\n23\n34\n', b'507\n4379\n0\n')

def test_sort():
    run_program('9-sort', b'', b'5\n2\n10\n4\n20\n8\n17\n16\n11\n9\n22\n18\n21\n13\n19\n3\n15\n6\n7\n12\n14\n1\n1234567890\n1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20\n21\n22\n')

def test_div_mod():
    run_program('0-div-mod', b'1\n0\n', b'1\n0\n0\n0\n')

def test_program6_and_7():
    t1 = run_program('program6', b'20\n', b'2432902008176640000\n')
    t2 = run_program('program7', b'20\n', b'2432902008176640000\n')
    assert t1 == t2

def test_test0():
    run_program('test0', b'5\n10\n', b'10\n')

def test_test1():
    run_program('test1', b'', b'10\n')

def test_test2():
    run_program('test2', b'', b'10\n20\n30\n40\n9\n14\n34\n44\n15\n30\n40\n50\n45\n60\n70\n70\n45\n60\n70\n70\n9\n11\n80\n')

def test_test3():
    run_program('test3', b'', b'10\n20\n30\n40\n45\n40\n20\n10\n40\n25\n15\n5\n35\n20\n10\n10\n35\n20\n10\n10\n0\n0\n5\n9\n0\n0\n')

def test_test4():
    run_program('test4', b'', b'0\n0\n0\n1\n2\n2\n15\n27775\n0\n0\n0\n1\n2\n2\n15\n27775\n11376640\n11371085\n11371085\n')

def test_test5():
    run_program('test5', b'', b'0\n0\n0\n1\n0\n2\n2\n130\n0\n0\n0\n1\n0\n2\n2\n130\n')

def test_test6():
    run_program('test6', b'', b'0\n0\n0\n0\n1\n0\n0\n5\n0\n0\n0\n0\n1\n0\n0\n5\n')

def test_test7():
    run_program('test7', b'', b'10\n9\n8\n7\n6\n5\n4\n3\n2\n1\n0\n')

def test_test8():
    run_program('test8', b'', b'0\n0\n0\n1\n1\n0\n1\n0\n1\n1\n0\n0\n1\n1\n0\n1\n0\n1\n0\n1\n0\n1\n2\n')