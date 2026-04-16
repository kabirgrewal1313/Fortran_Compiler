%{
#include <stdio.h>
#include <stdlib.h>
#include<string.h>
#include"Attrib.h"
#include"y.tab.h"
%}
DIGIT  [0-9]
LETTER [A-Za-z]
ID  {LETTER}({LETTER}|{DIGIT}|_)*
REALNUM  {DIGIT}+"."{DIGIT}+
INTEGERNUM {DIGIT}+
%%
"PROGRAM" {return PROGRAM;}
"DO" {return DO;}
"CONTINUE" {return CONTINUE;}
"::" { return DCOLON; }
"=="|"EQ" { return EQ; }
"=" {return '=';}
"<"|"LT" { return LT;}
">"|"GT" { return GT;}
"\+" {return PLUS;}
"-" {return MINUS;}
"\*" {return MUL;}
"/" {return DIV;}
"\.AND\." {return AND;}
"\.OR\." {return OR;}
"\.NOT\." {return NOT;}
"\.TRUE\." { return TRUE;}
"\.FALSE\." { return FALSE;}
","  {return ',';}
"\("  {return '(';}
"\)" {return ')';}
"IF"  {return IF;}
"THEN"  {return THEN;}
"END" {return END;}
"INTEGER"  { return INTEGER; }
"REAL"     { return REAL; }
"LOGICAL"  { return LOGICAL; }
{REALNUM} {yylval.a.val.fval=atof(yytext); strcpy(yylval.a.type,"REAL"); strcpy(yylval.a.place, yytext); return NUMBER;}
{INTEGERNUM} {yylval.a.val.ival=atoi(yytext); strcpy(yylval.a.type,"INTEGER"); strcpy(yylval.a.place, yytext); return NUMBER;}
{ID} {yylval.a.code[0] = '\0'; strcpy(yylval.a.place, yytext); return ID;}
[ \t\n]+  {}
"!"[^\n]* {}
. {return ERROR;}
%%
int yywrap() {
    return 1;
}