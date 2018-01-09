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

bool in_comment = false;
%}

%%
[ \t\n]+ ;

\( {
    if(in_comment)
        yyerror("zagnieżdżone komentarze są zabronione");
    else
        in_comment = true;
}

\) {
    if(!in_comment)
        yyerror("zamknięcie nieotwartego komentarza");
    else
        in_comment = false;
}

[0-9]+ {
    yylval.number = new cln::cl_I(yytext);
    if(!in_comment)
        return NUM;
}

[_a-z]+ {
    yylval.string = new std::string(yytext);
    if(!in_comment)
        return PIDENTIFIER;
}

";" {
    if(!in_comment)
        return SEMICOLON;
}

VAR {
    if(!in_comment)
        return VAR;
}

BEGIN {
    if(!in_comment)
        return KW_BEGIN;
}

END {
    if(!in_comment)
        return END;
}

READ {
    if(!in_comment)
        return READ;
}

WRITE {
    if (!in_comment)
        return WRITE;
}

IF {
    if (!in_comment)
        return IF;
}

THEN {
    if (!in_comment)
        return THEN;
}

ELSE {
    if (!in_comment)
        return ELSE;
}

ENDIF {
    if (!in_comment)
        return ENDIF;
}

WHILE {
    if (!in_comment)
        return WHILE;
}

DO {
    if (!in_comment)
        return DO;
}

ENDWHILE {
    if (!in_comment)
        return ENDWHILE;
}

FOR {
    if (!in_comment)
        return FOR;
}

FROM {
    if (!in_comment)
        return FROM;
}

TO {
    if (!in_comment)
        return TO;
}

DOWNTO {
    if (!in_comment)
        return DOWNTO;
}

ENDFOR {
    if (!in_comment)
        return ENDFOR;
}

"[" {
    if (!in_comment)
        return L_BRACKET;
}

"]" {
    if (!in_comment)
        return R_BRACKET;
}

":=" {
    if (!in_comment)
        return ASSIGN;
}

"+" {
    if (!in_comment)
        return OP_PLUS;
}

"-" {
    if (!in_comment)
        return OP_MINUS;
}

"*" {
    if (!in_comment)
        return OP_MULT;
}

"/" {
    if (!in_comment)
        return OP_DIV;
}

"%" {
    if (!in_comment)
        return OP_MOD;
}

"=" {
    if (!in_comment)
        return OP_EQ;
}

"<>" {
    if (!in_comment)
        return OP_NEQ;
}

"<" {
    if (!in_comment)
        return OP_LT;
}

"<=" {
    if (!in_comment)
        return OP_LE;
}

">" {
    if (!in_comment)
        return OP_GT;
}

">=" {
    if (!in_comment)
        return OP_GE;
}

. {
    if (!in_comment) {
        std::string errorMessage = "niewłaściwy znak ";
        errorMessage += yytext;
        yyerror(errorMessage.c_str());
    }
}
%%
