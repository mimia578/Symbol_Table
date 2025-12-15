%{
#include "symbol_table.h"

#define YYSTYPE symbol_info*

#include <bits/stdc++.h>
using namespace std;

extern FILE *yyin;
int yyparse(void);
int yylex(void);
extern YYSTYPE yylval;

int lines = 1;
ofstream outlog;

symbol_table st(10, &outlog);

vector<pair<string, string>> temp_params; // (type, name) pairs
string current_type;

void yyerror(char *s)
{
    outlog << "At line " << lines << " " << s << endl << endl;
}
%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN
%token ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT
%token LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON
%token CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
{
    outlog << "At line no: " << lines << " start : program " << endl << endl;
    outlog << endl;
    st.print_all_scopes();
    outlog << "Total lines: " << lines << endl;
}
;

program : program unit
{
    string combined = $1->get_name() + "\n" + $2->get_name();
    $$ = new symbol_info(combined, "program");
    outlog << "At line no: " << lines << " program : program unit" << endl << endl;
    outlog << combined << endl << endl;
}
| unit
{
    $$ = new symbol_info($1->get_name(), "program");
    outlog << "At line no: " << lines << " program : unit" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
;

unit : var_declaration
{
    $$ = new symbol_info($1->get_name(), "unit");
    outlog << "At line no: " << lines << " unit : var_declaration" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| func_definition
{
    $$ = new symbol_info($1->get_name(), "unit");
    outlog << "At line no: " << lines << " unit : func_definition" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
;

func_definition
: type_specifier ID LPAREN parameter_list RPAREN
{
    symbol_info* func = new symbol_info($2->get_name(), "ID");
    func->set_symbol_type("function");
    func->set_return_type($1->get_name());
    
    // Add all accumulated parameters
    for(auto& p : temp_params) {
        func->add_parameter(p.first, p.second);
    }
    
    if(!st.insert(func)) {
        outlog << "Error at line " << lines << ": Multiple declaration of " << $2->get_name() << endl << endl;
        delete func;
    }
}
compound_statement
{
    temp_params.clear();
    string result = $1->get_name() + " " + $2->get_name() + "(" + $4->get_name() + ")\n" + $7->get_name();
    $$ = new symbol_info(result, "func_definition");
    outlog << "At line no: " << lines << " func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement" << endl << endl;
    outlog << result << endl << endl;
}
| type_specifier ID LPAREN RPAREN
{
    symbol_info* func = new symbol_info($2->get_name(), "ID");
    func->set_symbol_type("function");
    func->set_return_type($1->get_name());
    
    if(!st.insert(func)) {
        outlog << "Error at line " << lines << ": Multiple declaration of " << $2->get_name() << endl << endl;
        delete func;
    }
}
compound_statement
{
    string result = $1->get_name() + " " + $2->get_name() + "()\n" + $6->get_name();
    $$ = new symbol_info(result, "func_definition");
    outlog << "At line no: " << lines << " func_definition : type_specifier ID LPAREN RPAREN compound_statement" << endl << endl;
    outlog << result << endl << endl;
}
;

parameter_list
: parameter_list COMMA type_specifier ID
{
    temp_params.push_back(make_pair($3->get_name(), $4->get_name()));
    string result = $1->get_name() + "," + $3->get_name() + " " + $4->get_name();
    $$ = new symbol_info(result, "parameter_list");
    outlog << "At line no: " << lines << " parameter_list : parameter_list COMMA type_specifier ID" << endl << endl;
    outlog << result << endl << endl;
}
| parameter_list COMMA type_specifier
{
    temp_params.push_back(make_pair($3->get_name(), ""));
    string result = $1->get_name() + "," + $3->get_name();
    $$ = new symbol_info(result, "parameter_list");
    outlog << "At line no: " << lines << " parameter_list : parameter_list COMMA type_specifier" << endl << endl;
    outlog << result << endl << endl;
}
| type_specifier ID
{
    temp_params.push_back(make_pair($1->get_name(), $2->get_name()));
    string result = $1->get_name() + " " + $2->get_name();
    $$ = new symbol_info(result, "parameter_list");
    outlog << "At line no: " << lines << " parameter_list : type_specifier ID" << endl << endl;
    outlog << result << endl << endl;
}
| type_specifier
{
    temp_params.push_back(make_pair($1->get_name(), ""));
    $$ = new symbol_info($1->get_name(), "parameter_list");
    outlog << "At line no: " << lines << " parameter_list : type_specifier" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
;

compound_statement
: LCURL
{
    st.enter_scope();
    
    // Insert parameters into the new scope
    for(auto& p : temp_params) {
        if(!p.second.empty()) { // only insert named parameters
            symbol_info* param = new symbol_info(p.second, "ID");
            param->set_symbol_type("variable");
            param->set_data_type(p.first);
            st.insert(param);
        }
    }
}
statements RCURL
{
    st.print_current_scope();
    st.exit_scope();
    
    string result = "{\n" + $3->get_name() + "\n}";
    $$ = new symbol_info(result, "compound_statement");
    outlog << "At line no: " << lines << " compound_statement : LCURL statements RCURL" << endl << endl;
    outlog << result << endl << endl;
}
| LCURL RCURL
{
    st.enter_scope();
    st.print_current_scope();
    st.exit_scope();
    
    $$ = new symbol_info("{\n}", "compound_statement");
    outlog << "At line no: " << lines << " compound_statement : LCURL RCURL" << endl << endl;
    outlog << "{" << endl << "}" << endl << endl;
}
;

var_declaration
: type_specifier declaration_list SEMICOLON
{
    current_type = $1->get_name();
    
    // Parse declaration_list to extract variable names and array info
    string decl_text = $2->get_name();
    
    string result = $1->get_name() + " " + $2->get_name() + ";";
    $$ = new symbol_info(result, "var_declaration");
    outlog << "At line no: " << lines << " var_declaration : type_specifier declaration_list SEMICOLON" << endl << endl;
    outlog << result << endl << endl;
}
;

type_specifier
: INT   
{ 
    $$ = new symbol_info("int", "type_specifier"); 
    outlog << "At line no: " << lines << " type_specifier : INT" << endl << endl;
    outlog << "int" << endl << endl;
}
| FLOAT 
{ 
    $$ = new symbol_info("float", "type_specifier"); 
    outlog << "At line no: " << lines << " type_specifier : FLOAT" << endl << endl;
    outlog << "float" << endl << endl;
}
| VOID  
{ 
    $$ = new symbol_info("void", "type_specifier"); 
    outlog << "At line no: " << lines << " type_specifier : VOID" << endl << endl;
    outlog << "void" << endl << endl;
}
;

declaration_list
: declaration_list COMMA ID
{
    symbol_info* var = new symbol_info($3->get_name(), "ID");
    var->set_symbol_type("variable");
    var->set_data_type(current_type);
    
    if(!st.insert(var)) {
        outlog << "Error at line " << lines << ": Multiple declaration of " << $3->get_name() << endl << endl;
        delete var;
    }
    
    string result = $1->get_name() + "," + $3->get_name();
    $$ = new symbol_info(result, "declaration_list");
    outlog << "At line no: " << lines << " declaration_list : declaration_list COMMA ID" << endl << endl;
    outlog << result << endl << endl;
}
| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
{
    symbol_info* arr = new symbol_info($3->get_name(), "ID");
    arr->set_symbol_type("array");
    arr->set_data_type(current_type);
    arr->set_array_size(stoi($5->get_name()));
    
    if(!st.insert(arr)) {
        outlog << "Error at line " << lines << ": Multiple declaration of " << $3->get_name() << endl << endl;
        delete arr;
    }
    
    string result = $1->get_name() + "," + $3->get_name() + "[" + $5->get_name() + "]";
    $$ = new symbol_info(result, "declaration_list");
    outlog << "At line no: " << lines << " declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD" << endl << endl;
    outlog << result << endl << endl;
}
| ID
{
    symbol_info* var = new symbol_info($1->get_name(), "ID");
    var->set_symbol_type("variable");
    var->set_data_type(current_type);
    
    if(!st.insert(var)) {
        outlog << "Error at line " << lines << ": Multiple declaration of " << $1->get_name() << endl << endl;
        delete var;
    }
    
    $$ = new symbol_info($1->get_name(), "declaration_list");
    outlog << "At line no: " << lines << " declaration_list : ID" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| ID LTHIRD CONST_INT RTHIRD
{
    symbol_info* arr = new symbol_info($1->get_name(), "ID");
    arr->set_symbol_type("array");
    arr->set_data_type(current_type);
    arr->set_array_size(stoi($3->get_name()));
    
    if(!st.insert(arr)) {
        outlog << "Error at line " << lines << ": Multiple declaration of " << $1->get_name() << endl << endl;
        delete arr;
    }
    
    string result = $1->get_name() + "[" + $3->get_name() + "]";
    $$ = new symbol_info(result, "declaration_list");
    outlog << "At line no: " << lines << " declaration_list : ID LTHIRD CONST_INT RTHIRD" << endl << endl;
    outlog << result << endl << endl;
}
;

statements
: statement
{
    $$ = new symbol_info($1->get_name(), "statements");
    outlog << "At line no: " << lines << " statements : statement" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| statements statement
{
    string result = $1->get_name() + "\n" + $2->get_name();
    $$ = new symbol_info(result, "statements");
    outlog << "At line no: " << lines << " statements : statements statement" << endl << endl;
    outlog << result << endl << endl;
}
;

statement
: var_declaration
{
    $$ = $1;
    outlog << "At line no: " << lines << " statement : var_declaration" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| expression_statement
{
    $$ = $1;
    outlog << "At line no: " << lines << " statement : expression_statement" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| compound_statement
{
    $$ = $1;
    outlog << "At line no: " << lines << " statement : compound_statement" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| FOR LPAREN expression_statement expression_statement expression RPAREN statement
{
    string result = "for(" + $3->get_name() + $4->get_name() + $5->get_name() + ")" + $7->get_name();
    $$ = new symbol_info(result, "statement");
    outlog << "At line no: " << lines << " statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement" << endl << endl;
    outlog << result << endl << endl;
}
| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
{
    string result = "if(" + $3->get_name() + ")" + $5->get_name();
    $$ = new symbol_info(result, "statement");
    outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement" << endl << endl;
    outlog << result << endl << endl;
}
| IF LPAREN expression RPAREN statement ELSE statement
{
    string result = "if(" + $3->get_name() + ")" + $5->get_name() + "else " + $7->get_name();
    $$ = new symbol_info(result, "statement");
    outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement ELSE statement" << endl << endl;
    outlog << result << endl << endl;
}
| WHILE LPAREN expression RPAREN statement
{
    string result = "while(" + $3->get_name() + ")" + $5->get_name();
    $$ = new symbol_info(result, "statement");
    outlog << "At line no: " << lines << " statement : WHILE LPAREN expression RPAREN statement" << endl << endl;
    outlog << result << endl << endl;
}
| PRINTLN LPAREN ID RPAREN SEMICOLON
{
    string result = "printf(" + $3->get_name() + ");";
    $$ = new symbol_info(result, "statement");
    outlog << "At line no: " << lines << " statement : PRINTLN LPAREN ID RPAREN SEMICOLON" << endl << endl;
    outlog << result << endl << endl;
}
| RETURN expression SEMICOLON
{
    string result = "return " + $2->get_name() + ";";
    $$ = new symbol_info(result, "statement");
    outlog << "At line no: " << lines << " statement : RETURN expression SEMICOLON" << endl << endl;
    outlog << result << endl << endl;
}
;

expression_statement
: SEMICOLON
{
    $$ = new symbol_info(";", "expression_statement");
    outlog << "At line no: " << lines << " expression_statement : SEMICOLON" << endl << endl;
    outlog << ";" << endl << endl;
}
| expression SEMICOLON
{
    string result = $1->get_name() + ";";
    $$ = new symbol_info(result, "expression_statement");
    outlog << "At line no: " << lines << " expression_statement : expression SEMICOLON" << endl << endl;
    outlog << result << endl << endl;
}
;

variable
: ID
{
    $$ = new symbol_info($1->get_name(), "variable");
    outlog << "At line no: " << lines << " variable : ID" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| ID LTHIRD expression RTHIRD
{
    string result = $1->get_name() + "[" + $3->get_name() + "]";
    $$ = new symbol_info(result, "variable");
    outlog << "At line no: " << lines << " variable : ID LTHIRD expression RTHIRD" << endl << endl;
    outlog << result << endl << endl;
}
;

expression
: logic_expression
{
    $$ = $1;
    outlog << "At line no: " << lines << " expression : logic_expression" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| variable ASSIGNOP logic_expression
{
    string result = $1->get_name() + "=" + $3->get_name();
    $$ = new symbol_info(result, "expression");
    outlog << "At line no: " << lines << " expression : variable ASSIGNOP logic_expression" << endl << endl;
    outlog << result << endl << endl;
}
;

logic_expression
: rel_expression
{
    $$ = $1;
    outlog << "At line no: " << lines << " logic_expression : rel_expression" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| rel_expression LOGICOP rel_expression
{
    string result = $1->get_name() + $2->get_name() + $3->get_name();
    $$ = new symbol_info(result, "logic_expression");
    outlog << "At line no: " << lines << " logic_expression : rel_expression LOGICOP rel_expression" << endl << endl;
    outlog << result << endl << endl;
}
;

rel_expression
: simple_expression
{
    $$ = $1;
    outlog << "At line no: " << lines << " rel_expression : simple_expression" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| simple_expression RELOP simple_expression
{
    string result = $1->get_name() + $2->get_name() + $3->get_name();
    $$ = new symbol_info(result, "rel_expression");
    outlog << "At line no: " << lines << " rel_expression : simple_expression RELOP simple_expression" << endl << endl;
    outlog << result << endl << endl;
}
;

simple_expression
: term
{
    $$ = $1;
    outlog << "At line no: " << lines << " simple_expression : term" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| simple_expression ADDOP term
{
    string result = $1->get_name() + $2->get_name() + $3->get_name();
    $$ = new symbol_info(result, "simple_expression");
    outlog << "At line no: " << lines << " simple_expression : simple_expression ADDOP term" << endl << endl;
    outlog << result << endl << endl;
}
;

term
: unary_expression
{
    $$ = $1;
    outlog << "At line no: " << lines << " term : unary_expression" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| term MULOP unary_expression
{
    string result = $1->get_name() + $2->get_name() + $3->get_name();
    $$ = new symbol_info(result, "term");
    outlog << "At line no: " << lines << " term : term MULOP unary_expression" << endl << endl;
    outlog << result << endl << endl;
}
;

unary_expression
: ADDOP unary_expression
{
    string result = $1->get_name() + $2->get_name();
    $$ = new symbol_info(result, "unary_expression");
    outlog << "At line no: " << lines << " unary_expression : ADDOP unary_expression" << endl << endl;
    outlog << result << endl << endl;
}
| NOT unary_expression
{
    string result = "!" + $2->get_name();
    $$ = new symbol_info(result, "unary_expression");
    outlog << "At line no: " << lines << " unary_expression : NOT unary_expression" << endl << endl;
    outlog << result << endl << endl;
}
| factor
{
    $$ = $1;
    outlog << "At line no: " << lines << " unary_expression : factor" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
;

factor
: variable
{
    $$ = $1;
    outlog << "At line no: " << lines << " factor : variable" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| ID LPAREN argument_list RPAREN
{
    string result = $1->get_name() + "(" + $3->get_name() + ")";
    $$ = new symbol_info(result, "factor");
    outlog << "At line no: " << lines << " factor : ID LPAREN argument_list RPAREN" << endl << endl;
    outlog << result << endl << endl;
}
| LPAREN expression RPAREN
{
    string result = "(" + $2->get_name() + ")";
    $$ = new symbol_info(result, "factor");
    outlog << "At line no: " << lines << " factor : LPAREN expression RPAREN" << endl << endl;
    outlog << result << endl << endl;
}
| CONST_INT
{
    $$ = $1;
    outlog << "At line no: " << lines << " factor : CONST_INT" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| CONST_FLOAT
{
    $$ = $1;
    outlog << "At line no: " << lines << " factor : CONST_FLOAT" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
| variable INCOP
{
    string result = $1->get_name() + "++";
    $$ = new symbol_info(result, "factor");
    outlog << "At line no: " << lines << " factor : variable INCOP" << endl << endl;
    outlog << result << endl << endl;
}
| variable DECOP
{
    string result = $1->get_name() + "--";
    $$ = new symbol_info(result, "factor");
    outlog << "At line no: " << lines << " factor : variable DECOP" << endl << endl;
    outlog << result << endl << endl;
}
;

argument_list
: arguments
{
    $$ = $1;
    outlog << "At line no: " << lines << " argument_list : arguments" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
|
{
    $$ = new symbol_info("", "argument_list");
    outlog << "At line no: " << lines << " argument_list : " << endl << endl;
    outlog << endl << endl;
}
;

arguments
: arguments COMMA logic_expression
{
    string result = $1->get_name() + "," + $3->get_name();
    $$ = new symbol_info(result, "arguments");
    outlog << "At line no: " << lines << " arguments : arguments COMMA logic_expression" << endl << endl;
    outlog << result << endl << endl;
}
| logic_expression
{
    $$ = $1;
    outlog << "At line no: " << lines << " arguments : logic_expression" << endl << endl;
    outlog << $1->get_name() << endl << endl;
}
;

%%

int main(int argc, char *argv[])
{
    if(argc != 2)
    {
        cout << "Please provide input file name" << endl;
        return 0;
    }

    yyin = fopen(argv[1], "r");
    outlog.open("22101088_22101357_log.txt");

    if(yyin == NULL)
    {
        cout << "Couldn't open file" << endl;
        return 0;
    }

    st.enter_scope(); // Create global scope
    
    yyparse();

    outlog.close();
    fclose(yyin);

    return 0;
}