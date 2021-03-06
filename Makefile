all: kompilator

kompilator: kompilator.y kompilator.l
	bison -d kompilator.y
	flex kompilator.l
	g++ -std=c++11 lex.yy.c kompilator.tab.c -l cln -o kompilator

clean:
	rm -f kompilator kompilator.tab.c kompilator.tab.h lex.yy.c
	rm -f test/*.mr
	rm -fr test/__pycache__

.PHONY: test

test: kompilator
	cd test && pytest
