%{
    #include<stdio.h>
    #include<stdlib.h>
    #include<string.h>
    #include"Attrib.h"
    int yylex();
    void yyerror(const char *s);
    struct Attrib symtab[100];
    int symtab_index = 0; 
    int lookup_symbol(const char* name) {
        for (int i = 0; i < symtab_index; i++) {
            if (strcmp(symtab[i].name, name) == 0) {
                return i;
            }
        }
        return -1;
    }
    int insert_symbol(const char* name, const char* type) {
        if (symtab_index < 100) {
            strcpy(symtab[symtab_index].name, name);
            strcpy(symtab[symtab_index].type, type);
            return symtab_index++;
        }
        return -1;
    }
    char current_type[10];
    int temp_count = 0;
    void new_temp(char *buf) {
        sprintf(buf, "t%d", temp_count++);
    }
    int label_count = 0;
    void new_label(char *buf) {
        sprintf(buf, "L%d", label_count++);
    }
    extern FILE *yyin; 
    extern FILE *yyout;
    extern void yyrestart(FILE *input_file);
    typedef struct {
    char start[20];
    char end[20];
    char increment[20];
} Loop;

Loop loop_stack[50];
int loop_top = -1;
void push_loop(const char *start, const char *end, const char *increment) {
    loop_top++;
    strcpy(loop_stack[loop_top].start, start);
    strcpy(loop_stack[loop_top].end, end);
    strcpy(loop_stack[loop_top].increment, increment);
}

void pop_loop() {
    loop_top--;
}

char* current_loop_start() {
    if(loop_top < 0) {
        fprintf(yyout, "Error: CONTINUE statement not within a loop.\n");
        exit(1);
    }
    return loop_stack[loop_top].start;
}

char* current_loop_end() {
    if(loop_top < 0) {
        fprintf(yyout, "Error: CONTINUE statement not within a loop.\n");
        exit(1);
    }
    return loop_stack[loop_top].end;
}
char* current_loop_increment() {
    if(loop_top < 0) {
        fprintf(yyout, "Error: CONTINUE statement not within a loop.\n");
        exit(1);
    }
    return loop_stack[loop_top].increment;
}
%}

%union {
    struct Attrib a;
}
%token PROGRAM END IF THEN DO CONTINUE
%token INTEGER REAL LOGICAL ERROR
%token<a> ID NUMBER
%token AND OR NOT
%token LT GT EQ
%token PLUS MINUS MUL DIV
%token DCOLON
%token TRUE FALSE
%type <a> Expression LogicalOr LogicalAnd RelExpr
%type <a> ArithExpr Term Factor
%type <a> Statements Statement Declarations Declaration Idlist Type
%type<a> DoHeader
%%
Program:
    PROGRAM ID DCOLON Declarations Statements END
    {
        fprintf(yyout, "Program parsed successfully.\n");
        fprintf(yyout, "start\n");
        fprintf(yyout, "Generated Intermediate Code:\n%s", $5.code);
        fprintf(yyout, "end\n");
        exit(0);
    }
    ;
Declarations:
    Declarations Declaration{
        strcpy($$.code, $1.code);
        strcat($$.code, $2.code);
    }
    |
    {
        $$.code[0] = '\0';
    }
    ;
Declaration:
    Type DCOLON Idlist{
        strcpy($$.code, $1.code);
        strcat($$.code, $3.code);
    }
    ;
Idlist:
    ID
    {
        $$.code[0] = '\0';
        if (lookup_symbol($1.place) == -1) {
            insert_symbol($1.place, current_type);
        } else {
            fprintf(yyout, "Error: Variable '%s' already declared.\n", $1.place);
            exit(1);
        }
    }
    |
    Idlist ',' ID
    {
        $$.code[0] = '\0';
        if (lookup_symbol($3.place) == -1) {
            insert_symbol($3.place, current_type);
        } else {
            fprintf(yyout, "Error: Variable '%s' already declared.\n", $3.place);
            exit(1);
        }
    }
    ;
Type:
    INTEGER
    {strcpy(current_type, "INTEGER"); $$.code[0] = '\0';}
    |
    REAL
    {strcpy(current_type, "REAL"); $$.code[0] = '\0';}
    |
    LOGICAL
    {strcpy(current_type, "LOGICAL"); $$.code[0] = '\0';}
    ;
Statements:
    Statements Statement{
        strcpy($$.code, $1.code);
        strcat($$.code, $2.code);
    }
    |
    {
        $$.code[0] = '\0';
    }
    ;
DoHeader:
DO ID '=' Expression ',' Expression
{
    if (lookup_symbol($2.place) == -1) {
        fprintf(yyout, "Error: Undeclared variable '%s' in DO loop.\n", $2.place);
        exit(1);
    }
    if (strcmp(symtab[lookup_symbol($2.place)].type, "INTEGER") != 0) {
        fprintf(yyout, "Error: Loop variable '%s' must be of type INTEGER.\n", $2.place);
        exit(1);
    }
    if(strcmp($4.type, "INTEGER") != 0) {
        fprintf(yyout, "Error: Loop variable '%s' must be of type INTEGER.\n", $2.place);
        exit(1);
    }
    if(strcmp($6.type, "INTEGER") != 0) {
        fprintf(yyout, "Error: Loop end expression must be of type INTEGER.\n");
        exit(1);
    }
    char buf[200];
    char Lstart[20], Lend[20], bound[20],Lincrement[20];
    new_label(Lstart);
    new_label(Lend);
    new_temp(bound);
    new_label(Lincrement);

    push_loop(Lstart, Lend, Lincrement);

    $$.code[0] = '\0';

    
    strcat($$.code, $4.code);
    sprintf(buf, "%s = %s;\n", $2.place, $4.place);
    strcat($$.code, buf);

    
    strcat($$.code, $6.code);
    sprintf(buf, "%s = %s;\n", bound, $6.place);
    strcat($$.code, buf);

    sprintf(buf, "%s:\n", current_loop_start());
    strcat($$.code, buf);
    sprintf(buf, "if %s > %s goto %s;\n", $2.place, bound, Lend);
    strcat($$.code, buf);

    
    strcpy($$.place, $2.place);
    strcpy($$.type, "INTEGER");   
}
    ;
Statement:
    IF Expression THEN Statements END
    {
        if (strcmp($2.type, "LOGICAL") != 0) {
            fprintf(yyout, "Error: Condition in IF statement must be of type LOGICAL.\n");
            exit(1);
        }
        char Lend[20];
        new_label(Lend);
        $$.code[0] = '\0';
        strcpy($$.code,$2.code);
        char buf[100];
        sprintf(buf, "if %s == 0 goto %s;\n", $2.place, Lend);
        strcat($$.code, buf);
        strcat($$.code,$4.code);
        sprintf(buf, "%s:\n", Lend);
        strcat($$.code, buf);
    }
    |
    DoHeader Statements END
    {
    char buf[200];
    $$.code[0] = '\0';

    
    

    strcat($$.code, $1.code);
    

    
    strcat($$.code, $2.code);

    sprintf(buf,"%s:\n", current_loop_increment());
    strcat($$.code, buf);
    sprintf(buf, "%s = %s + 1;\n",
            $1.place, $1.place);
    strcat($$.code, buf);

    
    sprintf(buf, "goto %s;\n", current_loop_start());
    strcat($$.code, buf);

    
    sprintf(buf, "%s:\n", current_loop_end());
    strcat($$.code, buf);

    pop_loop();
}
    |
    CONTINUE
    {
    char buf[200];
        $$.code[0] = '\0';

    sprintf(buf, "goto %s;\n", current_loop_increment());
    strcat($$.code, buf);
    }
    |
    ID '=' Expression
    {
        int index = lookup_symbol($1.place);
        if (index == -1) {
            fprintf(yyout, "Error: Undeclared variable '%s'.\n", $1.place);
            exit(1);
        } else if (strcmp(symtab[index].type, "INTEGER") == 0&&strcmp($3.type, "REAL") == 0) {
            fprintf(yyout, "Error: Type mismatch in assignment to variable '%s'.\n", $1.place);
            exit(1);
        }else if ((strcmp(symtab[index].type,"LOGICAL") == 0 && strcmp($3.type, "LOGICAL") != 0)|| (strcmp(symtab[index].type,"LOGICAL") != 0 && strcmp($3.type, "LOGICAL") == 0)) {
            fprintf(yyout, "Error: Type mismatch in assignment to variable '%s'.\n", $1.place);
            exit(1);
        }
        $$.code[0] = '\0';
        strcat($$.code, $3.code);
        char buf[100];
        sprintf(buf, "%s = %s;\n", $1.place, $3.place);
        strcat($$.code, buf);
        symtab[index].val = $3.val;
        strcpy(symtab[index].type, $3.type);
    }
    ;
Expression:
    LogicalOr
    ;
LogicalOr:
    LogicalOr OR LogicalAnd
    {
        if (strcmp($1.type, "LOGICAL") == 0 && strcmp($3.type, "LOGICAL") == 0) {
            strcpy($$.type, "LOGICAL");
        } else {
            fprintf(yyout, "Error: Type mismatch in logical OR operation.\n");
            exit(1);
        }
        $$.val.bval = $1.val.bval || $3.val.bval;
        new_temp($$.place);
        strcpy($$.code,$1.code);
        strcat($$.code,$3.code);
        char instr[128];    
        sprintf(instr, "%s = %s || %s;\n", $$.place, $1.place, $3.place);
        strcat($$.code, instr);
    }
    |
    LogicalAnd
    ;
LogicalAnd:
    LogicalAnd AND RelExpr
    {
        if (strcmp($1.type, "LOGICAL") == 0 && strcmp($3.type, "LOGICAL") == 0) {
            strcpy($$.type, "LOGICAL");
        } else {
            fprintf(yyout, "Error: Type mismatch in logical AND operation.\n");
            exit(1);
        }
        $$.val.bval = $1.val.bval && $3.val.bval;
        new_temp($$.place);
        strcpy($$.code,$1.code);
        strcat($$.code,$3.code);
        char instr[128];
        sprintf(instr, "%s = %s && %s;\n", $$.place, $1.place, $3.place);
        strcat($$.code, instr);

    }
    |
    RelExpr
    ;
RelExpr:
    ArithExpr LT ArithExpr
    {
        if ((strcmp($1.type, "INTEGER") == 0 || strcmp($1.type, "REAL") == 0) && (strcmp($3.type, "INTEGER") == 0 || strcmp($3.type, "REAL") == 0)) {
            strcpy($$.type, "LOGICAL");
        } else {
            fprintf(yyout, "Error: Type mismatch in relational operation.\n");
            exit(1);
        }
        if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"REAL")==0){
            $$.val.bval = $1.val.fval < $3.val.fval;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.bval = $1.val.ival < $3.val.ival;
        } else if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.bval = $1.val.fval < $3.val.ival;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"REAL")==0){
            $$.val.bval = $1.val.ival < $3.val.fval;
        }
        new_temp($$.place);
        strcpy($$.code,$1.code);
        strcat($$.code,$3.code);
        char instr[128];
        sprintf(instr, "%s = %s < %s;\n", $$.place, $1.place, $3.place);
        strcat($$.code, instr);
    }
    |
    ArithExpr GT ArithExpr
    {
        if ((strcmp($1.type, "INTEGER") == 0 || strcmp($1.type, "REAL") == 0) && (strcmp($3.type, "INTEGER") == 0 || strcmp($3.type, "REAL") == 0)) {
            strcpy($$.type, "LOGICAL");
        } else {
            fprintf(yyout, "Error: Type mismatch in relational operation.\n");
            exit(1);
        }
        if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"REAL")==0){
            $$.val.bval = $1.val.fval > $3.val.fval;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.bval = $1.val.ival > $3.val.ival;
        } else if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.bval = $1.val.fval > $3.val.ival;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"REAL")==0){
            $$.val.bval = $1.val.ival > $3.val.fval;
        }
        new_temp($$.place);
        strcpy($$.code,$1.code);
        strcat($$.code,$3.code);
        char instr[128];
        sprintf(instr, "%s = %s > %s;\n", $$.place, $1.place, $3.place);
        strcat($$.code, instr);

    }
    |
    ArithExpr EQ ArithExpr
    {
        if ((strcmp($1.type, "INTEGER") == 0 || strcmp($1.type, "REAL") == 0) && (strcmp($3.type, "INTEGER") == 0 || strcmp($3.type, "REAL") == 0)) {
            strcpy($$.type, "LOGICAL");
        } else {
            fprintf(yyout, "Error: Type mismatch in relational operation.\n");
            exit(1);
        }
        if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"REAL")==0){
            $$.val.bval = $1.val.fval == $3.val.fval;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.bval = $1.val.ival == $3.val.ival;
        } else if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.bval = $1.val.fval == $3.val.ival;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"REAL")==0){
            $$.val.bval = $1.val.ival == $3.val.fval;
        }
        new_temp($$.place);
        strcpy($$.code,$1.code);
        strcat($$.code,$3.code);
        char instr[128];
        sprintf(instr, "%s = %s == %s;\n", $$.place, $1.place, $3.place);
        strcat($$.code, instr);
    }
    |
    ArithExpr
    ;
ArithExpr:
    ArithExpr PLUS Term
    {
        if ((strcmp($1.type, "INTEGER") == 0 || strcmp($1.type, "REAL") == 0) && (strcmp($3.type, "INTEGER") == 0 || strcmp($3.type, "REAL") == 0)) {
            if (strcmp($1.type, "REAL") == 0 || strcmp($3.type, "REAL") == 0) {
                strcpy($$.type, "REAL");
            } else {
                strcpy($$.type, "INTEGER");
            }
        } else {
            fprintf(yyout, "Error: Type mismatch in arithmetic operation.\n");
            exit(1);
        }
        if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"REAL")==0){
            $$.val.fval = $1.val.fval + $3.val.fval;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.ival = $1.val.ival + $3.val.ival;
        } else if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.fval = $1.val.fval + $3.val.ival;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"REAL")==0){
            $$.val.fval = $1.val.ival + $3.val.fval;
        }
        new_temp($$.place);
        strcpy($$.code,$1.code);
        strcat($$.code,$3.code);
        char instr[128];
        sprintf(instr, "%s = %s + %s;\n", $$.place, $1.place, $3.place);
        strcat($$.code, instr);
        
    }
    |
    ArithExpr MINUS Term
    {
        if ((strcmp($1.type, "INTEGER") == 0 || strcmp($1.type, "REAL") == 0) && (strcmp($3.type, "INTEGER") == 0 || strcmp($3.type, "REAL") == 0)) {
            if (strcmp($1.type, "REAL") == 0 || strcmp($3.type, "REAL") == 0) {
                strcpy($$.type, "REAL");
            } else {
                strcpy($$.type, "INTEGER");
            }
        } else {
            fprintf(yyout, "Error: Type mismatch in arithmetic operation.\n");
            exit(1);
        }
        if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"REAL")==0){
            $$.val.fval = $1.val.fval - $3.val.fval;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.ival = $1.val.ival - $3.val.ival;
        } else if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.fval = $1.val.fval - $3.val.ival;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"REAL")==0){
            $$.val.fval = $1.val.ival - $3.val.fval;
        }
        new_temp($$.place);
        strcpy($$.code,$1.code);
        strcat($$.code,$3.code);
        char instr[128];   
        sprintf(instr, "%s = %s - %s;\n", $$.place, $1.place, $3.place);
        strcat($$.code, instr);
    }
    |
    Term
    ;
Term:
    Term MUL Factor
    {
        if ((strcmp($1.type, "INTEGER") == 0 || strcmp($1.type, "REAL") == 0) && (strcmp($3.type, "INTEGER") == 0 || strcmp($3.type, "REAL") == 0)) {
            if (strcmp($1.type, "REAL") == 0 || strcmp($3.type, "REAL") == 0) {
                strcpy($$.type, "REAL");
            } else {
                strcpy($$.type, "INTEGER");
            }
        } else {
            fprintf(yyout, "Error: Type mismatch in arithmetic operation.\n");
            exit(1);
        }
        if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"REAL")==0){
            $$.val.fval = $1.val.fval * $3.val.fval;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.ival = $1.val.ival * $3.val.ival;
        } else if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.fval = $1.val.fval * $3.val.ival;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"REAL")==0){
            $$.val.fval = $1.val.ival * $3.val.fval;
        }
        new_temp($$.place);
        strcpy($$.code,$1.code);
        strcat($$.code,$3.code);
        char instr[128];
        sprintf(instr, "%s = %s * %s;\n", $$.place, $1.place, $3.place);
        strcat($$.code, instr);
    }
    |
    Term DIV Factor
    {
        if ((strcmp($1.type, "INTEGER") == 0 || strcmp($1.type, "REAL") == 0) && (strcmp($3.type, "INTEGER") == 0 || strcmp($3.type, "REAL") == 0)) {
            if (strcmp($1.type, "REAL") == 0 || strcmp($3.type, "REAL") == 0) {
                strcpy($$.type, "REAL");
            } else {
                strcpy($$.type, "INTEGER");
            }
        } else {
            fprintf(yyout, "Error: Type mismatch in arithmetic operation.\n");  
            exit(1);
        }
        if(strcmp($3.type,"REAL")==0&&$3.val.fval==0){
            fprintf(yyout, "Error: Division by zero.\n");
            exit(1);
        } else if(strcmp($3.type,"INTEGER")==0&&$3.val.ival==0){
            fprintf(yyout, "Error: Division by zero.\n");
            exit(1);
        }
        if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"REAL")==0){
            $$.val.fval = $1.val.fval / $3.val.fval;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.ival = $1.val.ival / $3.val.ival;
        } else if(strcmp($1.type,"REAL")==0&&strcmp($3.type,"INTEGER")==0){
            $$.val.fval = $1.val.fval / $3.val.ival;
        } else if(strcmp($1.type,"INTEGER")==0&&strcmp($3.type,"REAL")==0){
            $$.val.fval = $1.val.ival / $3.val.fval;
        }
        new_temp($$.place);
        strcpy($$.code,$1.code);
        strcat($$.code,$3.code);
        char instr[128];
        sprintf(instr, "%s = %s / %s;\n", $$.place, $1.place, $3.place);
        strcat($$.code, instr);
    }
    |
    Factor
    ;
Factor:
    NOT Factor
    {
        if (strcmp($2.type, "LOGICAL") == 0) {
            strcpy($$.type, "LOGICAL");
        } else {
            fprintf(yyout, "Error: Type mismatch in logical NOT operation.\n");
            exit(1);
        }
        $$.val.bval = !$2.val.bval;
        new_temp($$.place);
        strcpy($$.code,$2.code);
        char instr[128];
        sprintf(instr, "%s = !%s;\n", $$.place, $2.place);
        strcat($$.code, instr);
    }
    |
    ID
    {
        int index = lookup_symbol($1.place);
        if (index != -1) {
            $$.val = symtab[index].val;
            strcpy($$.type, symtab[index].type);
        } else {
            fprintf(yyout, "Error: Undeclared variable '%s'.\n", $1.place);
            exit(1);
        }
        strcpy($$.place, $1.place);
        $$.code[0] = '\0';
    }
    |
    NUMBER
    {
        $$.val = $1.val;
        strcpy($$.type, $1.type);
        strcpy($$.place, $1.place);
        $$.code[0] = '\0';
    }
    |
    '(' Expression ')'
    {
        $$.val = $2.val;
        strcpy($$.type, $2.type);
        strcpy($$.place, $2.place);
        strcpy($$.code, $2.code);
    }
    |
    TRUE
    {
        strcpy($$.type, "LOGICAL");
        strcpy($$.place, "1");
        $$.code[0] = '\0';
    }
    |
    FALSE
    {
        strcpy($$.type, "LOGICAL");
        strcpy($$.place, "0");
        $$.code[0] = '\0';
    }
    ;
%%
void yyerror(const char *s) {
    fprintf(yyout, "Error: %s\n", s);
}
int main() {
     yyin=stdin;
     yyout=stdout;
     yyparse();
     fclose(yyin);
     fclose(yyout);
    return 0;
}   