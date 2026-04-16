#ifndef ATTRIB_H
#define ATTRIB_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct Attrib {
    char name[100];
    char type[100];
    char code[4096];
    char place[200];
    union{
        int ival;
        float fval;
        int bval;
    }val;

};
#endif