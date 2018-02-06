/*
 * Mateusz Przybył
 * Kompilator JFTT 2017
 */

%{
#include <string>
#include <iostream>
#include <sstream>
#include <vector>
#include <map>
#include <stack>
#include <algorithm> // swap, count

#include <cln/cln.h>

#include "types.h"

extern int yylex();
int yyerror(const char*);
extern int yylineno;
extern char *yytext;

using namespace std;
using namespace cln;

Variable empty;
Variable accumulator;
vector<string> commands;
map<string, Variable*> memory;
stack<size_t> condition_begin_ips;
stack<size_t> condition_end_ips;
stack<size_t> else_begin_ips;
stack<cl_I> temp_vars;

// Liczba zadeklarowanych zmiennych.
// Pierwsze komórki są zarezerwowane dla kompilatora.
// 0,1 -- ładowanie
// 2,3,4,5 -- expression
// 6 -- condition
cl_I variablesCount = 10;

size_t ip()
{
    return commands.size();
}

/**
 * Dodaje nową zmienną do pamięci.
 * Jeśli zmienna o danej nazwie już istnieje, zwraca nullptr.
 * W przeciwnym wypadku zwraca indeks w pamięci nowej zmiennej.
 * Domyślna wartość zmiennej jest ustawiana na -1 (niezainicjalizowana).
 * Jeśli arrayLength > 0, to deklaruje arrayLength komórek pamięci i
 * zapisuje pierwszą zmienną jako tablicowa.
 */
Variable* put_new_variable(string name, cl_I arrayLength) {
    if (memory.count(name) > 0) {
        return nullptr;
    }
    Variable *v = new Variable();
    v->name = name;
    v->isArray = (arrayLength > 0);
    v->value =  v->isArray ? 1 : -1;
    v->index = variablesCount;
    v->arrayLength = v->isArray ? arrayLength : 0;
    v->arrayIndex = -1;
    v->isIndexAVariable = false;
    variablesCount += v->isArray ? arrayLength + 1 : 1;
    memory[name] = v;
    return memory[name];
}

Variable* put_new_temp_variable(string name) {
    if (memory.count(name) > 0) {
        return nullptr;
    }
    Variable *v = new Variable();
    v->name = name;
    v->value = 1;
    v->isTemporary = true;
    v->index = variablesCount + temp_vars.size();
    temp_vars.push(v->index);
    memory[name] = v;
    return memory[name];
}

/**
 * Zwraca zmienną o podanej nazwie.
 * Jeśli nie ma takiej zmiennej, zwraca nullptr.
 */
Variable* get_variable(string name) {
    if (memory.count(name) < 1) {
        return nullptr;
    }
    return memory[name];
}

size_t delete_temp_variable(string name) {
    Variable *v = get_variable(name);
    if (v != nullptr) {
        delete v;
        temp_vars.pop();
    }
    return memory.erase(name);
}

string cln_to_string(cl_I n) {
    stringstream ss;
    ss << n;
    return ss.str();
}

// Funkcje z prefiksem mr_ dodają komendę maszyny rejestrowej
// do listy komend.

void mr_get() {
    commands.push_back("GET");
}

void mr_put() {
    commands.push_back("PUT");
}

void mr_load(cl_I i) {
    commands.push_back("LOAD " + cln_to_string(i));
}

void mr_loadi(cl_I i) {
    commands.push_back("LOADI " + cln_to_string(i));
}

void mr_store(cl_I i) {
    commands.push_back("STORE " + cln_to_string(i));
}

void mr_storei(cl_I i) {
    commands.push_back("STOREI " + cln_to_string(i));
}

void mr_add(cl_I i) {
    commands.push_back("ADD " + cln_to_string(i));
}

void mr_addi(cl_I i) {
    commands.push_back("ADDI " + cln_to_string(i));
}

void mr_sub(cl_I i) {
    commands.push_back("SUB " + cln_to_string(i));
}

void mr_subi(cl_I i) {
    commands.push_back("SUBI " + cln_to_string(i));
}

void mr_shr() {
    commands.push_back("SHR");
}

void mr_shl() {
    commands.push_back("SHL");
}

void mr_inc() {
    commands.push_back("INC");
}

void mr_dec() {
    commands.push_back("DEC");
}

void mr_zero() {
    commands.push_back("ZERO");
}

void mr_jump(cl_I j) {
    commands.push_back("JUMP " + cln_to_string(j));
}

void mr_jzero(cl_I j) {
    commands.push_back("JZERO " + cln_to_string(j));
}

void mr_jodd(cl_I j) {
    commands.push_back("JODD " + cln_to_string(j));
}

void mr_halt() {
    commands.push_back("HALT");
}

/**
 * Wyświetla wszystkie komendy.
 */
void print_all_commands() {
    for (vector<string>::iterator it = commands.begin(); it != commands.end(); ++it) {
        cout << *it << "\n";
    }
}

bool same_memory_cell(Variable v1, Variable v2) {
    if (v1.index < 0 || v2.index < 0)
    {
        return false;
    }
    cln::cl_I index1 = v1.index;
    cln::cl_I index2 = v2.index;
    if (v1.isArray) {
        if (!v1.isIndexAVariable) {
            index1 += 1 + v1.arrayIndex;
        } else {
            return (v1.name == v2.name && v2.isArray && v2.isIndexAVariable && v2.arrayIndex == v1.arrayIndex);
        }
    }
    if (v2.isArray) {
        if (!v2.isIndexAVariable) {
            index2 += 1 + v2.arrayIndex;
        } else {
            return (v1.name == v2.name && v1.isArray && v1.isIndexAVariable && v1.arrayIndex == v2.arrayIndex);
        }
    }
    return index1 == index2;
}

cln::cl_I get_real_index(Variable v) {
    cln::cl_I ret = v.index;
    if (v.isArray) {
        if (!v.isIndexAVariable) {
            ret += 1 + v.arrayIndex;
        } else {
            ret = v.arrayIndex;
        }
    }
    return ret;
}

void calculate_num_to_acc(cl_I num)
{
    mr_zero();
    if (num > 0)
    {
        stringstream ss;
        fprintbinary(ss, num);
        string bin_num = ss.str();
        mr_inc();
        for (size_t i = 1; i < bin_num.size(); ++i)
        {
            mr_shl();
            if (bin_num[i] == '1')
            {
                mr_inc();
            }
        }
    }
}

// Wynik w komórce 1
void calculate_array_index(Variable &v)
{
    mr_load(get_real_index(v));
    mr_add(v.index);
}

// 0, 1
void store_accumulator_in_variable(Variable &v)
{
    if (v.isTemporary)
    {
        string errorMessage = "modyfikacja zmiennej iterujacej " + v.name.substr(1);
        yyerror(errorMessage.c_str());
        return;
    }

    if (!v.isArray)
    {
        mr_store(v.index);
    }
    else
    {
        if (!v.isIndexAVariable)
        {
            mr_store(get_real_index(v));
        }
        else
        {
            mr_store(0);
            calculate_array_index(v);
            mr_store(1);
            mr_load(0);
            mr_storei(1);
        }
    }

    if (v.value < 0)
    {
        v.value = 1; // zainicjalizowana
    }
    accumulator = v;
}

void load_variable_to_accumulator(Variable v)
{
    if (v.value < 0) {
        string errorMessage = "niezainicjalizowana zmienna " + v.name;
        yyerror(errorMessage.c_str());
    }

    if (same_memory_cell(accumulator, v))
    {
        return;
    }

    accumulator = v;

    if (v.name == "@")
    {
        calculate_num_to_acc(v.value);
    }
    else if (!v.isArray)
    {
        mr_load(v.index);
    }
    else
    {
        if (!v.isIndexAVariable)
        {
            mr_load(get_real_index(v));
        }
        else
        {
            calculate_array_index(v);
            mr_store(1);
            mr_loadi(1);
        }
    }
}

bool is_power_of_two(cl_I num)
{
    stringstream ss;
    fprintbinary(ss, num);
    string bin_num = ss.str();
    return (std::count(bin_num.begin(), bin_num.end(), '1') == 1);
}

void multiply(Variable *v1, Variable *v2)
{
    cl_I ida = 2;
    cl_I idb = 3;
    cl_I idr = 4;

    load_variable_to_accumulator(*v1);
    mr_store(ida);
    load_variable_to_accumulator(*v2);
    mr_store(idb);
    mr_sub(ida);
    mr_jzero(ip()+17); // if a > b (0 > b - a)
    mr_zero();
    mr_store(idr); // ret = 0
    mr_load(ida); // while a > 0
    mr_jzero(ip()+29);
    mr_inc(); // if a & 1
    mr_jodd(ip()+4);
    mr_load(idr);
    mr_add(idb);
    mr_store(idr); // ret += b // endif
    mr_load(idb);
    mr_shl();
    mr_store(idb); // b <<= 1
    mr_load(ida);
    mr_shr();
    mr_store(ida); // a <<= 1
    mr_jump(ip()-12); // endwhile
    mr_zero(); // else (a <= b)
    mr_store(idr); // ret = 0
    mr_load(idb); // while b > 0
    mr_jzero(ip()+13);
    mr_inc();
    mr_jodd(ip()+4); // if b & 1
    mr_load(idr);
    mr_add(ida);
    mr_store(idr); // ret += a // endif
    mr_load(ida);
    mr_shl();
    mr_store(ida); // a <<= 1
    mr_load(idb);
    mr_shr();
    mr_store(idb); // b <<= 1
    mr_jump(ip()-12);
    mr_load(idr); // return
}

void divide(Variable *v1, Variable *v2)
{
    cl_I ida = 2;
    cl_I idb = 3;
    cl_I idq = 4;
    cl_I idt = 5;

    load_variable_to_accumulator(*v1);
    mr_store(ida); // a
    load_variable_to_accumulator(*v2);
    mr_store(idb); // b
    mr_zero();
    mr_store(idq); // q = 0
    mr_load(idb); // if b == 0
    mr_jzero(ip()+49); // Return 0
    mr_dec(); // if b == 1
    mr_jzero(ip()+45); // Return a
    mr_zero();
    mr_inc();
    mr_store(idt); // t = 1
    mr_load(idb); // while (b <= a) // (b - a = 0)
    mr_sub(ida);
    mr_jzero(ip()+2);
    mr_jump(ip()+8); // to endwhile
    mr_load(idb);
    mr_shl();
    mr_store(idb); // b <<= 1
    mr_load(idt);
    mr_shl();
    mr_store(idt); // t <<= 1
    mr_jump(ip()-10); // endwhile
    mr_load(idb);
    mr_shr();
    mr_store(idb); // b >>= 1
    mr_load(idt);
    mr_shr();
    mr_store(idt); // t >>= 1
    mr_load(idt); // while (t > 0)
    mr_jzero(ip()+21); // to endwhile
    mr_load(idq);
    mr_shl();
    mr_store(idq); // q <<= 1
    mr_load(idb); // if b <= a // (b - a = 0)
    mr_sub(ida);
    mr_jzero(ip()+2);
    mr_jump(ip()+7); // to endif
    mr_load(ida);
    mr_sub(idb);
    mr_store(ida); // a = a - b
    mr_load(idq);
    mr_inc();
    mr_store(idq); // q++ //endif
    mr_load(idb);
    mr_shr();
    mr_store(idb); // b >>= 1
    mr_load(idt);
    mr_shr();
    mr_store(idt); // t >>= 1
    mr_jump(ip()-20); // endwhile
    mr_load(idq); // Return q
    mr_jump(ip()+4);
    mr_load(ida); // Return a
    mr_jump(ip()+2);
    mr_zero(); // Return 0
}

void modulo(Variable *v1, Variable *v2)
{
    cl_I ida = 2;
    cl_I idb = 3;
    cl_I idq = 4;
    cl_I idt = 5;

    load_variable_to_accumulator(*v1);
    mr_store(ida); // a
    load_variable_to_accumulator(*v2);
    mr_store(idb); // b
    mr_zero();
    mr_store(idq); // q = 0
    mr_load(idb); // if b == 0
    mr_jzero(ip()+47); // Return 0
    mr_dec(); // if b == 1
    mr_jzero(ip()+45); // Return 0
    mr_zero();
    mr_inc();
    mr_store(idt); // t = 1
    mr_load(idb); // while (b <= a) // (b - a = 0)
    mr_sub(ida);
    mr_jzero(ip()+2);
    mr_jump(ip()+8); // to endwhile
    mr_load(idb);
    mr_shl();
    mr_store(idb); // b <<= 1
    mr_load(idt);
    mr_shl();
    mr_store(idt); // t <<= 1
    mr_jump(ip()-10); // endwhile
    mr_load(idb);
    mr_shr();
    mr_store(idb); // b >>= 1
    mr_load(idt);
    mr_shr();
    mr_store(idt); // t >>= 1
    mr_load(idt); // while (t > 0)
    mr_jzero(ip()+21); // to endwhile
    mr_load(idq);
    mr_shl();
    mr_store(idq); // q <<= 1
    mr_load(idb); // if b <= a // (b - a = 0)
    mr_sub(ida);
    mr_jzero(ip()+2);
    mr_jump(ip()+7); // to endif
    mr_load(ida);
    mr_sub(idb);
    mr_store(ida); // a = a - b
    mr_load(idq);
    mr_inc();
    mr_store(idq); // q++ //endif
    mr_load(idb);
    mr_shr();
    mr_store(idb); // b >>= 1
    mr_load(idt);
    mr_shr();
    mr_store(idt); // t >>= 1
    mr_jump(ip()-20); // endwhile
    mr_load(ida); // Return a
    mr_jump(ip()+2);
    mr_zero(); // Return 0
}

void sub_from_acc(Variable *v2)
{
    if (v2->isArray && v2->isIndexAVariable)
    {
        mr_store(2);
        calculate_array_index(*v2);
        mr_store(3);
        mr_load(2);
        mr_subi(3);
    }
    else if (v2->name == "@")
    {
        if (v2->value == 0)
        {
            return;
        }
        else if (v2->value <= 40)
        {
            for (int i = 0; i < v2->value; ++i)
            {
                if (ip() > 0 && commands[ip()-1] == "INC")
                {
                    commands.pop_back();
                    continue;
                }
                mr_dec();
            }
        }
        else
        {
            mr_store(2); // 10
            calculate_num_to_acc(v2->value); // >=1
            mr_store(3); // 10
            mr_load(2); // 10
            mr_sub(3); // 10
        }
    }
    else
    {
        mr_sub(get_real_index(*v2));
    }
    accumulator = empty;
}

void update_jump(size_t k, size_t j)
{
    if ( commands[k] == "JUMP -1" ) {
        commands[k] = "JUMP " + std::to_string(j);
    } else {
        commands[k] = "JZERO " + std::to_string(j);
    }
}

%}
%union {
    Variable *variable;
    cln::cl_I *number;
    std::string *string;
    int token;
}

%locations
%token <token> VAR KW_BEGIN END
%token <string> PIDENTIFIER
%token <number> NUM
%token <token> SEMICOLON
%token <token> READ WRITE
%token <token> IF THEN ELSE ENDIF
%token <token> WHILE DO ENDWHILE
%token <token> FOR FROM TO DOWNTO ENDFOR
%token <token> ASSIGN
%token <token> L_BRACKET R_BRACKET
%token <token> OP_PLUS OP_MINUS OP_MULT OP_DIV OP_MOD
%token <token> OP_EQ OP_NEQ OP_LT OP_LE OP_GT OP_GE
%precedence NEGATION

%type <variable> identifier
%type <variable> value
%type <string> error
%%

program:
      VAR vdeclarations KW_BEGIN commands END {
          mr_halt();
          print_all_commands();
      }
    ;

vdeclarations:
      vdeclarations PIDENTIFIER {
        string *name = $2;
        Variable *result = put_new_variable(*name, 0);
        if (result == nullptr) {
            string errorMessage = "zmienna " + *name + " już została zadeklarowana";
            yyerror(errorMessage.c_str());
        }
        delete name;
      }
    | vdeclarations PIDENTIFIER L_BRACKET NUM R_BRACKET {
        string *name = $2;
        cl_I *arrayLength = $4;
        if (*arrayLength < 1) {
            string errorMessage = "zła długość tablicy " + *name + ": ";
            errorMessage += cln_to_string(*arrayLength);
            yyerror(errorMessage.c_str());
        }
        Variable *result = put_new_variable(*name, *arrayLength);
        if (result == nullptr) {
            string errorMessage = "zmienna " + *name + " już została zadeklarowana";
            yyerror(errorMessage.c_str());
        }

        // Zapisz indeks w pamięci
        calculate_num_to_acc(result->index);
        mr_inc();
        mr_store(result->index);

        delete name;
        delete arrayLength;
    }
    | %empty
    | vdeclarations PIDENTIFIER NUM {
        string *name = $2;
        cl_I *num = $3;
        string errorMessage = "nierozpoznany napis " + *name + cln_to_string(*num);
        yyerror(errorMessage.c_str());
        delete name;
        delete num;
    }
    ;

commands:
      commands command
    | command
    ;

command:
      identifier ASSIGN expression SEMICOLON {
        Variable *a = $1;

        store_accumulator_in_variable(*a);

        if (a->isArray) {
            delete a;
        }
      }
    | IF condition THEN commands {
        condition_begin_ips.pop();
        size_t end = condition_end_ips.top();
        condition_end_ips.pop();

        else_begin_ips.push(ip());
        mr_jump(-1);
        
        update_jump(end, ip());
        accumulator = empty;
    } ELSE commands {
        size_t begin = else_begin_ips.top();
        else_begin_ips.pop();
        update_jump(begin, ip());
        accumulator = empty;
    } ENDIF
    | IF condition THEN commands {
        condition_begin_ips.pop();
        size_t end = condition_end_ips.top();
        condition_end_ips.pop();
        update_jump(end, ip());
        accumulator = empty;
    } ENDIF
    | WHILE condition DO commands {
        size_t begin = condition_begin_ips.top();
        condition_begin_ips.pop();
        size_t end = condition_end_ips.top();
        condition_end_ips.pop();
        mr_jump(begin);
        update_jump(end, ip());
        accumulator = empty;
    } ENDWHILE
    | FOR PIDENTIFIER FROM value TO value {
        string *name = $2;
        *name = *name;
        Variable *iter = put_new_temp_variable(*name);
        if (iter == nullptr) {
            string errorMessage = "zmienna " + *name + " już została zadeklarowana";
            yyerror(errorMessage.c_str());
        }
        iter->isTemporary = true;
        iter->value = 1;
        Variable *iterCond = put_new_temp_variable(*name + "'");
        iterCond->isTemporary = true;
        iterCond->value = 1;
        Variable *min = $4;
        Variable *max = $6;

        load_variable_to_accumulator(*min);
        mr_store(iter->index);
        load_variable_to_accumulator(*max);
        mr_inc();
        sub_from_acc(min);
        mr_store(iterCond->index);
        condition_begin_ips.push(ip());
        condition_end_ips.push(ip());
        mr_jzero(-1);

        accumulator = empty;
        accumulator.value = 1;
        if (min->name == "@" || min->isArray) {
            delete min;
        }
        if (max->name == "@" || max->isArray) {
            delete max;
        }
    } DO commands ENDFOR {
        string *name = $2;
        Variable *iter = get_variable(*name);
        Variable *iterCond = get_variable(*name + "'");
        size_t condIp = condition_begin_ips.top();
        condition_begin_ips.pop();
        condition_end_ips.pop();

        mr_load(iter->index);
        mr_inc();
        mr_store(iter->index);
        mr_load(iterCond->index);
        mr_dec();
        mr_store(iterCond->index);
        mr_jump(condIp);
        update_jump(condIp, ip());

        delete_temp_variable(iterCond->name);
        delete_temp_variable(iter->name);

        accumulator = empty;
        accumulator.value = 1;

        delete name;
    }
    | FOR PIDENTIFIER FROM value DOWNTO value {
        string *name = $2;
        *name = *name;
        Variable *iter = put_new_temp_variable(*name);
        if (iter == nullptr) {
            string errorMessage = "zmienna " + *name + " już została zadeklarowana";
            yyerror(errorMessage.c_str());
        }
        iter->isTemporary = true;
        iter->value = 1;
        Variable *iterCond = put_new_temp_variable(*name + "'");
        iterCond->isTemporary = true;
        iterCond->value = 1;
        Variable *min = $6;
        Variable *max = $4;

        load_variable_to_accumulator(*max);
        mr_store(iter->index);
        mr_inc();
        sub_from_acc(min);
        mr_store(iterCond->index);
        condition_begin_ips.push(ip());
        condition_end_ips.push(ip());
        mr_jzero(-1);

        accumulator = empty;
        accumulator.value = 1;
        if (min->name == "@" || min->isArray) {
            delete min;
        }
        if (max->name == "@" || max->isArray) {
            delete max;
        }
    } DO commands ENDFOR {
        string *name = $2;
        Variable *iter = get_variable(*name);
        Variable *iterCond = get_variable(*name + "'");
        size_t condIp = condition_begin_ips.top();
        condition_begin_ips.pop();
        condition_end_ips.pop();

        mr_load(iter->index);
        mr_dec();
        mr_store(iter->index);
        mr_load(iterCond->index);
        mr_dec();
        mr_store(iterCond->index);
        mr_jump(condIp);
        update_jump(condIp, ip());

        delete_temp_variable(iterCond->name);
        delete_temp_variable(iter->name);

        accumulator = empty;
        accumulator.value = 1;

        delete name;
    }
    | READ identifier SEMICOLON {
        Variable *v = $2;
        mr_get();

        store_accumulator_in_variable(*v);

        if (v->isArray) {
            delete v;
        }
    }
    | WRITE value SEMICOLON {
        Variable *v = $2;
        // cerr << accumulator.name << endl;
        // cerr << v->name << endl;
        // cerr << endl;
        load_variable_to_accumulator(*v);
        mr_put();
        if (v->name == "@" || v->isArray) {
            delete v;
        }
    }
    ;

expression:
      value { // Assumption: the value of expression is in accumulator
        Variable *v = $1;
        load_variable_to_accumulator(*v);
        if (v->name == "@" || v->isArray) {
            delete v;
        }
    }
    | value OP_PLUS value {
        Variable *v1 = $1;
        Variable *v2 = $3;
        if (v1->name == "@" && v2->name == "@")
        {
            // num + num
            calculate_num_to_acc(v1->value + v2->value);
        }
        else if (same_memory_cell(*v1, *v2))
        {
            // v + v
            load_variable_to_accumulator(*v1);
            mr_shl();
        }
        else
        {
            // dwie różne zmienne, co najwyżej jedna z nich jest stałą
            if (v2->name == "@")
            {
                std::swap(v1, v2);
            }
            
            if (same_memory_cell(accumulator, *v2))
            {
                if (v1->isArray && v1->isIndexAVariable)
                {
                    mr_store(2);
                    calculate_array_index(*v1);
                    mr_store(3);
                    mr_load(2);
                    mr_addi(3);
                }
                else if (v1->name == "@")
                {
                    if (v1->value <= 40)
                    {
                        for (int i = 0; i < v1->value; ++i)
                        {
                            mr_inc();
                        }
                    }
                    else
                    {
                        mr_store(2);
                        calculate_num_to_acc(v1->value);
                        mr_store(3);
                        mr_load(2);
                        mr_add(3);
                    }
                }
                else
                {
                    mr_add(get_real_index(*v1));
                }
            }
            else
            {
                if (v2->isArray && v2->isIndexAVariable)
                {
                    calculate_array_index(*v2);
                    mr_store(2);
                    load_variable_to_accumulator(*v1);
                    mr_addi(2);
                }
                else if (v1->name == "@" && v1->value < 10)
                {
                    load_variable_to_accumulator(*v2);
                    for (int i = 0; i < v1->value; ++i)
                    {
                        mr_inc();
                    }
                }
                else
                {
                    load_variable_to_accumulator(*v1);
                    mr_add(get_real_index(*v2));
                }
            }
        }
        accumulator = empty;
        accumulator.value = 1;
        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    | value OP_MINUS value {
        Variable *v1 = $1;
        Variable *v2 = $3;
        if (v1->name == "@" && v2->name == "@")
        {
            // num - num
            cl_I ret = v1->value - v2->value;
            if (ret < 0) {
                ret = 0;
            }
            calculate_num_to_acc(ret);
        }
        else if (same_memory_cell(*v1, *v2))
        {
            // v - v
            mr_zero();
        }
        else
        {
            // dwie różne zmienne, co najwyżej jedna z nich jest stałą
            load_variable_to_accumulator(*v1);
            sub_from_acc(v2);
        }
        accumulator = empty;
        accumulator.value = 1;
        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    | value OP_MULT value {
        Variable *v1 = $1;
        Variable *v2 = $3;

        if (v1->name == "@" && v2->name == "@")
        {
            // num * num
            cl_I ret = v1->value * v2->value;
            calculate_num_to_acc(ret);
        }
        else
        {
            // co najwyżej jedna ze zmiennych jest stałą
            if (v2->name == "@")
            {
                std::swap(v1, v2);
            }

            if (v1->name == "@")
            {
                if (v1->value == 0)
                {
                    mr_zero();
                }
                else if (v1->value == 1)
                {
                    load_variable_to_accumulator(*v2);
                }
                else if (is_power_of_two(v1->value))
                {
                    load_variable_to_accumulator(*v2);
                    while (v1->value > 1)
                    {
                        mr_shl();
                        v1->value >>= 1;
                    }
                }
                else
                {
                    multiply(v1, v2);
                }
            }
            else
            {
                multiply(v1, v2);
            }

            accumulator = empty;
            accumulator.value = 1;
            if (v1->name == "@" || v1->isArray) {
                delete v1;
            }
            if (v2->name == "@" || v2->isArray) {
                delete v2;
            }
        }
    }
    | value OP_DIV value {
        Variable *v1 = $1;
        Variable *v2 = $3;

        if (v1->name == "@" && v2->name == "@")
        {
            // num / num
            cl_I ret = 0;
            if (v2->value != 0)
            {
                ret = cln::floor1(v1->value / v2->value);
            }
            calculate_num_to_acc(ret);
        }
        else
        {
            // drugi argument jest stałą
            if (v2->name == "@")
            {
                if (v2->value == 0)
                {
                    mr_zero();
                }
                else if (v2->value == 1)
                {
                    load_variable_to_accumulator(*v1);
                }
                else if (is_power_of_two(v2->value))
                {
                    load_variable_to_accumulator(*v1);
                    while (v2->value > 1)
                    {
                        mr_shr();
                        v2->value >>= 1;
                    }
                }
                else
                {
                    divide(v1, v2);
                }
            }
            // pierwszy argument jest stałą
            else if (v1->name == "@")
            {
                if (v1->value == 0)
                {
                    mr_zero();
                }
                else
                {
                    divide(v1, v2);
                }
            }
            else
            {
                divide(v1, v2);
            }
        }

        accumulator = empty;
        accumulator.value = 1;
        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    | value OP_MOD value {
        Variable *v1 = $1;
        Variable *v2 = $3;

        if (v1->name == "@" && v2->name == "@")
        {
            // num % num
            cl_I ret = 0;
            if (v2->value != 0)
            {
                ret = cln::mod(v1->value, v2->value);
            }
            calculate_num_to_acc(ret);
        }
        else
        {
            // drugi argument jest stałą
            if (v2->name == "@")
            {
                if (v2->value == 0)
                {
                    mr_zero();
                }
                else if (v2->value == 1)
                {
                    mr_zero();
                }
                else
                {
                    modulo(v1, v2);
                }
            }
            // pierwszy argument jest stałą
            else if (v1->name == "@")
            {
                if (v1->value == 0)
                {
                    mr_zero();
                }
                else
                {
                    modulo(v1, v2);
                }
            }
            else
            {
                modulo(v1, v2);
            }
        }

        accumulator = empty;
        accumulator.value = 1;
        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    ;

condition:
      value OP_EQ value {
        Variable *v1 = $1;
        Variable *v2 = $3;

        accumulator = empty;

        condition_begin_ips.push(ip());
        // a = b <=> (a - b) + (b - a) = 0
        load_variable_to_accumulator(*v1);
        sub_from_acc(v2);
        mr_store(6);
        load_variable_to_accumulator(*v2);
        sub_from_acc(v1);
        mr_add(6);
        mr_jzero(ip()+2);
        condition_end_ips.push(ip());
        mr_jump(-1);

        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    | value OP_NEQ value {
        Variable *v1 = $1;
        Variable *v2 = $3;

        // a <> b
        accumulator = empty;

        condition_begin_ips.push(ip());
        load_variable_to_accumulator(*v1);
        sub_from_acc(v2);
        mr_store(6);
        load_variable_to_accumulator(*v2);
        sub_from_acc(v1);
        mr_add(6);
        condition_end_ips.push(ip());
        mr_jzero(-1);

        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    | value OP_LT value {
        Variable *v1 = $1;
        Variable *v2 = $3;

        // a < b <=> 0 < b - a
        accumulator = empty;

        condition_begin_ips.push(ip());
        load_variable_to_accumulator(*v2);
        sub_from_acc(v1);
        condition_end_ips.push(ip());
        mr_jzero(-1);

        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    | value OP_GT value {
        Variable *v1 = $1;
        Variable *v2 = $3;

        accumulator = empty;

        // a > b <=> a - b > 0
        condition_begin_ips.push(ip());
        load_variable_to_accumulator(*v1);
        sub_from_acc(v2);
        condition_end_ips.push(ip());
        mr_jzero(-1);

        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    | value OP_LE value {
        Variable *v1 = $1;
        Variable *v2 = $3;

        accumulator = empty;

        // a <= b <=> a - b <= 0 <=> a - b = 0
        condition_begin_ips.push(ip());
        load_variable_to_accumulator(*v1);
        sub_from_acc(v2);
        mr_jzero(ip()+2);
        condition_end_ips.push(ip());
        mr_jump(-1);

        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    | value OP_GE value {
        Variable *v1 = $1;
        Variable *v2 = $3;

        accumulator = empty;

        // a >= b <=> 0 >= b - a <=> 0 = b - a
        condition_begin_ips.push(ip());
        load_variable_to_accumulator(*v2);
        sub_from_acc(v1);
        mr_jzero(ip()+2);
        condition_end_ips.push(ip());
        mr_jump(-1);

        if (v1->name == "@" || v1->isArray) {
            delete v1;
        }
        if (v2->name == "@" || v2->isArray) {
            delete v2;
        }
    }
    ;

value:
      NUM {
          Variable *v = new Variable();
          v->name = "@";
          v->value = *$1;
          $$ = v;
          delete $1;
      }
    | OP_MINUS NUM %prec NEGATION { yyerror("niewłaściwy znak '-'"); }
    | identifier {
        Variable *v = $1;
        if (v->value < 0) {
            string errorMessage = "niezainicjalizowana zmienna " + v->name;
            yyerror(errorMessage.c_str());
        }
        $$ = v;
    }
    ;

identifier:
      PIDENTIFIER {
          string *name = $1;
          Variable *variable = get_variable(*name);
          if (variable == nullptr) {
              string errorMessage = "niezadeklarowana zmienna " + *name;
              yyerror(errorMessage.c_str());
          }
          if (variable->isArray) {
            string errorMessage = "niewłaściwe użycie zmiennej tablicowej " + *name;
            yyerror(errorMessage.c_str());
          }
          $$ = variable;
          delete name;
      }
    | PIDENTIFIER L_BRACKET PIDENTIFIER R_BRACKET {
        string *name = $1;
        string *name2 = $3;

        // Zmienna tablicowa
        Variable *variable = get_variable(*name);
        if (variable == nullptr) {
            string errorMessage = "niezadeklarowana zmienna " + *name;
            yyerror(errorMessage.c_str());
        }
        if (!variable->isArray) {
            string errorMessage = "niewłaściwe użycie zmiennej " + *name;
            yyerror(errorMessage.c_str());
        }

        // Zmienna indeksowa
        Variable *variable2 = get_variable(*name2);
        if (variable2 == nullptr) {
            string errorMessage = "niezadeklarowana zmienna " + *name2;
            yyerror(errorMessage.c_str());
        }
        if (variable2->value < 0) {
            string errorMessage = "niezainicjalizowana zmienna " + *name2;
            yyerror(errorMessage.c_str());
        }
        if (variable2->isArray) {
            string errorMessage = "niewłaściwe użycie zmiennej " + *name2;
            yyerror(errorMessage.c_str());
        }

        // Właściwa zmienna
        Variable *ret_variable = new Variable(*variable);
        ret_variable->arrayIndex = variable2->index;
        ret_variable->isIndexAVariable = true;

        $$ = ret_variable;
        
        delete name;
        delete name2;
    }
    | PIDENTIFIER L_BRACKET NUM R_BRACKET {
        string *name = $1;
        cl_I *index = $3;

        // Zmienna tablicowa
        Variable *variable = get_variable(*name);
        if (variable == nullptr) {
            string errorMessage = "niezadeklarowana zmienna " + *name;
            yyerror(errorMessage.c_str());
        }
        if (!variable->isArray) {
            string errorMessage = "niewłaściwe użycie zmiennej " + *name;
            yyerror(errorMessage.c_str());
        }

        // Indeks
        if (*index < 0 || *index >= variable->arrayLength) {
            string errorMessage = "zły indeks " + cln_to_string(*index)  + " tablicy " + *name;
            yyerror(errorMessage.c_str());
        }

        // Właściwa zmienna
        Variable *ret_variable = new Variable(*variable);
        ret_variable->arrayIndex = *index;
        ret_variable->isIndexAVariable = false;

        $$ = ret_variable;
        
        delete name;
        delete index;
    }
    ;
%%

int yyerror(const char *s)
{
    std::cerr << "Błąd w linii " << yylineno << ": " << s << std::endl;
    exit(1);
}

int main()
{
    empty.index = -2;
    return yyparse();
}
