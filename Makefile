all: kompilator

kompilator: kompilator.y kompilator.l
	bison -d kompilator.y
	flex kompilator.l
	g++ -std=c++11 -l cln -o kompilator lex.yy.c kompilator.tab.c

clean:
	rm kompilator kompilator.tab.c kompilator.tab.h lex.yy.c
