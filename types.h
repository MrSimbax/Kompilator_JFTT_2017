/*
 * Mateusz Przybył
 * Kompilator JFTT 2017
 */

#ifndef KOMPILATOR_TYPES_H
#define KOMPILATOR_TYPES_H

#include <string>
#include <cln/cln.h>

struct Variable {
    std::string name = "";
    cln::cl_I value = -1;
    cln::cl_I index = -1;
    bool isArray = false;
    cln::cl_I arrayLength = 0;
    cln::cl_I arrayIndex = -1;
    bool isIndexAVariable = false;
    bool isTemporary = false;
};

#endif
