%option noyywrap
%option yylineno
%{
/*
 * Mateusz Przybył
 * Kompilator JFTT 2017
 */
 
#include <string>
#include <iostream>

#include "types.h"
#include "kompilator.tab.h"

extern YYSTYPE yylval;
extern void yyerror(char const *);
%}

%%
[ \t\n]+ ;

\([^\)]*\) ;

[0-9]+ {
    yylval.number = new cln::cl_I(yytext);
    return NUM;
}

[_a-z]+ {
    yylval.string = new std::string(yytext);
    return PIDENTIFIER;
}

";" {
    return SEMICOLON;
}

VAR {
    return VAR;
}

BEGIN {
    return KW_BEGIN;
}

END {
    return END;
}

READ {
    return READ;
}

WRITE {
    return WRITE;
}

IF {
    return IF;
}

THEN {
    return THEN;
}

ELSE {
    return ELSE;
}

ENDIF {
    return ENDIF;
}

WHILE {
    return WHILE;
}

DO {
    return DO;
}

ENDWHILE {
    return ENDWHILE;
}

FOR {
    return FOR;
}

FROM {
    return FROM;
}

TO {
    return TO;
}

DOWNTO {
    return DOWNTO;
}

ENDFOR {
    return ENDFOR;
}

"[" {
    return L_BRACKET;
}

"]" {
    return R_BRACKET;
}

":=" {
    return ASSIGN;
}

"+" {
    return OP_PLUS;
}

"-" {
    return OP_MINUS;
}

"*" {
    return OP_MULT;
}

"/" {
    return OP_DIV;
}

"%" {
    return OP_MOD;
}

"=" {
    return OP_EQ;
}

"<>" {
    return OP_NEQ;
}

"<" {
    return OP_LT;
}

"<=" {
    return OP_LE;
}

">" {
    return OP_GT;
}

">=" {
    return OP_GE;
}

. {
    std::string errorMessage = "niewłaściwy znak ";
    errorMessage += yytext;
    yyerror(errorMessage.c_str());
}
%%
