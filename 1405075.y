%{
    #include<iostream>
    #include<cstdlib>
    #include<cstring>
    #include<cmath>
    #include<sstream>
    #include"1405075.h"
    #define YYSTYPE SymbolInfo*

    using namespace std;

    namespace patch
    {
        template < typename T > std::string to_string( const T& n )
        {
            std::ostringstream stm ;
            stm << n ;
            return stm.str() ;
        }
    }

    int yyparse(void);
    int yylex(void);
    extern FILE *yyin;

    extern int line_count;
    extern int error_count;
    extern SymbolTable *table;
    string type;
    string rtype;
    FILE *flog;
    FILE *error;

    ofstream asmO;

    vector<string>list;
    vector<string>name;

    string toData = "";

    int labelCount=0;
    int tempCount=0;

    char *newLabel(){
        char *lb= new char[4];
        strcpy(lb,"L");
        char b[3];
        sprintf(b,"%d", labelCount);
        labelCount++;
        strcat(lb,b);
        return lb;
    }

    char *newTemp(){
        char *t= new char[4];
        strcpy(t,"t");
        char b[3];
        sprintf(b,"%d", tempCount);
        tempCount++;
        strcat(t,b);
        return t;
    }

    void yyerror(string s){
        fprintf(error,"\nError at Line %d : %s\n", line_count, s.c_str());
    }


%}

%token CONST_INT CONST_FLOAT CONST_CHAR ID INCOP DECOP MULOP ADDOP RELOP LOGICOP ASSIGNOP LPAREN RPAREN RTHIRD LTHIRD LCURL RCURL COMMA SEMICOLON NOT IF ELSE FOR WHILE DO INT CHAR FLOAT DOUBLE VOID RETURN PRINTLN CONTINUE

%error-verbose

%left '+' '-'
%left '*' '/'

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE


%%

start : program {
    fprintf(flog,"\nLine no %d : start : program\n",line_count);
    fprintf(flog,"\nTotal Lines: %d\n",line_count-1);
    fprintf(flog,"\nTotal Errors: %d\n",error_count);

    string s = "";
    s += ".MODEL SMALL\n\n.STACK 100H\n\n.DATA\n";
    s += toData;
    s += "\n.CODE\nMAIN PROC\n";
    s += "MOV AX, @DATA\nMOV DS, AX\n\n";
    s += $1->code;
    s += "\nMAIN ENDP\nEND MAIN\n";

    /*if(error_count == 0) asmO<<s;
    else cout<<"Errors Found."<<endl;*/
    asmO<<s;
}
;





program : program unit {
    fprintf(flog,"\nLine no %d : program : program unit\n",line_count);
}
|
unit {
    $$=$1;
    fprintf(flog,"\nLine no %d : program : unit\n",line_count);
}
;






unit : var_declaration
{
    fprintf(flog,"\nLine no %d : unit : var_declaration\n",line_count);
}
|
func_declaration
{
    fprintf(flog,"\nLine no %d : unit : func_declaration\n",line_count);
}
|
func_definition
{
    fprintf(flog,"\nLine no %d : unit : func_definition\n",line_count);
    $$=$1;
}
;





func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON
{
    fprintf(flog,"\nLine no %d : func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON\n%s\n", line_count, $2->getName().c_str());
    $2->var_type = $1->getType();
    $2->a_size = 0;

    if (table->Insert($2)){
        SymbolInfo *sp = table->Lookup($2->getName());
        if (sp->var_type == "INT") sp->ival = 10;
        else if (sp->var_type == "FLOAT") sp->fval = 10.0;

        for (int i = 0; i < list.size(); i++){
            sp->param_list.push_back(list[i]);
            sp->param_name.push_back(name[i]);
        }
        list.clear();
        name.clear();
    }
    else {
        yyerror("Multiple declaration of "+$2->getName());
        error_count++;
    }
}
;





func_definition : type_specifier ID LPAREN parameter_list RPAREN {
    int flag = 0;
    SymbolInfo *sp = table->Lookup($2->getName());
    if (sp){
        table->EnterScope(table->len);
        if (sp->param_list.size() == list.size()){
            for (int i = 0; i < list.size(); i++){
                if (sp->param_list[i] != list[i]){
                    string s = patch::to_string(i+1);
                    yyerror(s+"th parameter mismatch in function "+sp->getName());
                    error_count++;
                    flag = 1;
                    break;
                }
            }
        }
        else {
            yyerror("Number of parameters mismatch");
            error_count++;
            flag = 1;
        }
        list.clear();
        name.clear();
    }

    else{
        $2->var_type = $1->getType();
        $2->a_size = 0;
        table->Insert($2);
        sp = table->Lookup($2->getName());
        table->EnterScope(table->len);
        if (sp->var_type == "INT") sp->ival = 10;
        else if (sp->var_type == "FLOAT") sp->fval = 10.0;
        else sp->ival = 0;

        for (int i = 0; i < list.size(); i++){
            sp->param_list.push_back(list[i]);
            sp->param_name.push_back(name[i]);
        }
        list.clear();
        name.clear();
    }
    if (flag == 0){
        for (int i = 0; i < sp->param_list.size(); i++){
            SymbolInfo *sp1 = new SymbolInfo();
            sp1->setName(sp->param_name[i]);
            sp1->setType("ID");
            sp1->var_type = sp->param_list[i];

            if (sp->getName() != ""){
                if (table->Insert(sp1) == false){
                    yyerror("Multiple definition of"+sp->getName());
                    error_count++;
                }
            }
        }
    }
    rtype = sp->var_type;
}
compound_statement
{
    fprintf(flog,"\nLine no %d : func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement\n%s\n",line_count, $2->getName().c_str());
    /*cout<<$7->code;*/
    $$=$7;

}
;





parameter_list  : parameters {
    fprintf(flog,"\nLine no %d : parameter_list  : parameters\n",line_count);
    $$=$1;
}
| {
    fprintf(flog,"\nLine no %d : parameter_list  :\n",line_count);
}
;





parameters  : parameters COMMA type_specifier ID {
    fprintf(flog,"\nLine no %d : parameters : parameters COMMA type_specifier ID\n%s\n",line_count,$4->getName().c_str());
    if (type != "VOID"){
        list.push_back(type);
        name.push_back($4->getName());
    }
    else {
        yyerror("Variable can not be of void type");
        error_count++;
    }
}
| parameters COMMA type_specifier {
    fprintf(flog,"\nLine no %d : parameters  : parameters COMMA type_specifier\n",line_count);
    if (type != "VOID"){
        list.push_back(type);
        name.push_back("");
    }
    else {
        yyerror("Variable can not be of void type");
        error_count++;
    }
}
| type_specifier ID {
    fprintf(flog,"\nLine no %d : parameters  : type_specifier ID\n%s\n",line_count,$2->getName().c_str());

    if (type != "VOID"){
        list.push_back(type);
        name.push_back($2->getName());
    }
    else {
        yyerror("Variable can not be of void type");
        error_count++;
    }
}
| type_specifier {
    fprintf(flog,"\nLine no %d : parameters  : type_specifier\n",line_count);

    if (type != "VOID"){
        list.push_back(type);
        name.push_back("");
    }
    else {
        yyerror("Variable can not be of void type");
        error_count++;
    }
}
;





compound_statement : LCURL statements RCURL {
    fprintf(flog,"\nLine no %d : compound_statement : LCURL statements RCURL\n",line_count);
    table->ExitScope();

    $$=$2;
}
| LCURL RCURL {
    fprintf(flog,"\nLine no %d : compound_statement : LCURL RCURL\n",line_count);
    table->ExitScope();
}
;





var_declaration : type_specifier declaration_list SEMICOLON {
    fprintf(flog,"\nLine no %d : var_declaration : type_specifier declaration_list SEMICOLON\n",line_count);
    $$=$2;
}
;






type_specifier	: INT {
    fprintf(flog,"\nLine no %d : type_specifier : INT\n",line_count);
    type = "INT";
    $$ = new SymbolInfo();
    $$->setType("INT");
}
| FLOAT {
    fprintf(flog,"\nLine no %d : type_specifier : FLOAT\n",line_count);
    type = "FLOAT";
    $$ = new SymbolInfo();
    $$->setType("FLOAT");
}
| VOID {
    fprintf(flog,"\nLine no %d : type_specifier : VOID\n",line_count);
    type = "VOID";
    $$ = new SymbolInfo();
    $$->setType("VOID");
}
;





declaration_list : declaration_list COMMA ID {
    fprintf(flog,"\nLine no %d : declaration_list : declaration_list COMMA ID\n%s\n",line_count,$3->getName().c_str());
    if (type != "VOID"){
        $3->var_type = type;

        $$=$1;
        toData += string($3->symbol)+" DW " + "?\n";
        /*$$->code += string($3->symbol)+" DW " + "?\n";*/

        if (table->Insert($3) == false){

            yyerror("Multiple Declaration of " + $3->getName());
            error_count++;
        }
    }
    else{
        yyerror("Variable can not be of void type");
        error_count++;
    }
}
| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
    fprintf(flog,"\nLine no %d : declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD\n%s\n",line_count,$3->getName().c_str());

    if (table->LookupCurr($3->getName()) != NULL) {
        yyerror("Multiple Declaration of " + $3->getName());
        error_count++;
    }
    else if ($5->var_type == "FLOAT")  {
        yyerror("Array index must be of 'int' type");
        error_count++;
    }
    else if($5->ival < 1) {
        yyerror("Invalid array size");
        error_count++;
    }
    else {
        if (type != "VOID"){
            $3->var_type = type;
            $3->a_size = $5->ival;
            table->Insert($3);
            SymbolInfo *sp = table->Lookup($3->getName());
            sp->arr = new SymbolInfo[$5->ival];
            sp->a_size = $5->ival;

            $$=$1;
            toData += (string)$3->symbol + " DW ";
            /*$$->code += (string)$3->symbol + " DW ";*/

            for (int i = 0; i < $5->ival; i++){
                if (type == "INT") sp->arr[i].ival = -1;
                else sp->arr[i].fval = -1.0;
                sp->arr[i].var_type = type;
                sp->arr[i].setType("ID");

                toData += "? ";
            }
            toData += "\n";
        }
        else{
            yyerror("Variable can not be of void type");
            error_count++;
        }
    }
}
| ID {
    fprintf(flog,"\nLine no %d : declaration_list : ID\n%s\n",line_count,$1->getName().c_str());
    if (type != "VOID"){
        $1->var_type = type;
        if (table->Insert($1) == false){
            yyerror("Multiple Declaration of " + $1->getName());
            error_count++;
        }
    }
    else{
        yyerror("Variable can not be of void type");
        error_count++;
    }
    $$ = $1;
    $$ = new SymbolInfo();
    toData += string($1->symbol)+" DW " + "?\n";
    /*$$->code += string($1->symbol)+" DW " + "?\n";*/
}
| ID LTHIRD CONST_INT RTHIRD {
    fprintf(flog,"\nLine no %d : declaration_list : ID LTHIRD CONST_INT RTHIRD\n%s\n",line_count,$1->getName().c_str());

    if (table->LookupCurr($1->getName()) != NULL) {
        yyerror("Multiple Declaration of " + $1->getName());
        error_count++;
    }
    else if ($3->var_type == "FLOAT"){
        yyerror("Array index must be of 'int' type");
        error_count++;
    }
    else if($3->ival < 1) {
        yyerror("Invalid array size");
        error_count++;
    }
    else {
        if (type != "VOID"){
            $1->var_type = type;
            $1->a_size = $3->ival;
            table->Insert($1);
            SymbolInfo *sp = table->Lookup($1->getName());
            sp->arr = new SymbolInfo[$3->ival];
            sp->a_size = $3->ival;

            $$=$1;
            toData += (string)$1->symbol +" DW ";
            /*$$->code += (string)$1->symbol +" DW ";*/

            for (int i = 0; i < $3->ival; i++){
                if (type == "INT") sp->arr[i].ival = -1;
                else sp->arr[i].fval = -1.0;
                sp->arr[i].var_type = type;
                sp->arr[i].setType("ID");

                toData += "? ";
            }
            toData += "\n";
        }
        else{
            yyerror("Variable can not be of void type");
            error_count++;
        }
    }
}
;





statements : statement {
    fprintf(flog,"\nLine no %d : statements : statement\n",line_count);
    $$=$1;
}
| statements statement {
    fprintf(flog,"\nLine no %d : statements : statements statement\n",line_count);
    $$=$1;
    $$->code += $2->code;
}
;





statement : var_declaration {
    fprintf(flog,"\nLine no %d : statement : var_declaration\n",line_count);
    $$=$1;
}
| expression_statement {
    fprintf(flog,"\nLine no %d : statement : expression_statement\n",line_count);
    $$=$1;
}
| compound_statement {
    fprintf(flog,"\nLine no %d : statement : compound_statement\n",line_count);
    $$=$1;
}
| FOR LPAREN expression_statement expression_statement expression RPAREN statement{
    fprintf(flog,"\nLine no %d : statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement\n",line_count);
    //BISHAL KAJ
    $$ = $3;
    string label1 = string(newLabel());
    string label2 = string(newLabel());
    $$->code += label1 + ":\n";
    $$->code += $4->code;
    $$->code += "MOV AX, " + $4->getName() + "\nCMP AX, 1\n";
    $$->code += "JNE " + label2 + "\n";
    $$->code += $7->code;
    $$->code += $5->code;
    $$->code += "JMP " + label1 + "\n";
    $$->code += label2 + ":\n";

}
| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
    fprintf(flog,"\nLine no %d : statement : IF LPAREN expression RPAREN statement\n",line_count);

    $$=$3;
    char *label=newLabel();
    $$->code += "MOV AX, "+(string)$3->getName()+"\n";
    $$->code += "CMP AX, 1\n";
    $$->code += "JNE "+(string)label+"\n";
    $$->code += $5->code;
    $$->code += (string)label+":\n";
}
| IF LPAREN expression RPAREN statement ELSE statement {
    fprintf(flog,"\nLine no %d : statement : IF LPAREN expression RPAREN statement ELSE statement\n",line_count);

    $$=$3;
    char *label1 = newLabel();
    char *label2 = newLabel();
    $$->code += "MOV AX, "+string($3->getName())+"\n";
    $$->code += "CMP AX, 1\n";
    $$->code += "JNE "+string(label1)+"\n";
    $$->code += $5->code;
    $$->code += "JMP "+string(label2)+"\n";
    $$->code += string(label1)+":\n";
    $$->code += $7->code;
    $$->code += string(label2)+":\n";
}
| WHILE LPAREN expression RPAREN statement {
    fprintf(flog,"\nLine no %d : statement : WHILE LPAREN expression RPAREN statement\n",line_count);
}
| PRINTLN LPAREN ID RPAREN SEMICOLON {
    fprintf(flog,"\nLine no %d : statement : PRINTLN LPAREN ID RPAREN SEMICOLON\n%s\n",line_count,$3->getName().c_str());
    SymbolInfo *si = table->Lookup($3->getName());

    if (si == NULL) {
        yyerror($3->getName() + " is not declared in this scope.");
        error_count++;
    }
    else{
        $$ = new SymbolInfo();
        $$->code += "MOV AX, " + $3->symbol + "\n";
        $$->code += "PUSH AX\nPUSH BX\nPUSH CX\nPUSH DX\nOR AX,AX\nJGE @END_IF1\nPUSH AX\nMOV DL,'-'\nMOV AH,2\nINT 21H\nPOP AX\nNEG AX\n\n@END_IF1:\nXOR CX,CX\nMOV BX,10D\n\n@REPEAT1:\nXOR DX,DX\nDIV BX\nPUSH DX\nINC CX\nOR AX,AX\nJNE @REPEAT1\n\nMOV AH,2\n\n@PRINT_LOOP:\n\nPOP DX\nOR DL,30H\nINT 21H\nLOOP @PRINT_LOOP\n\nLEA DX, NL\nMOV AH, 9\nINT 21H\nPOP DX\nPOP CX\n\nPOP BX\nPOP AX\n";
        $$->code += "MOV DL, 0DH\nINT 21H\nMOV DL, 0AH\nINT 21H\n";
        /*$$->code += "MOV DX, " + $3->symbol + "\nMOV AH, 2\nINT 21H\n";*/
    }

    /*cout<<$$->code;*/
}
| RETURN expression SEMICOLON {
    fprintf(flog,"\nLine no %d : statement : RETURN expression SEMICOLON\n",line_count);
    if (rtype != $2->var_type){
        yyerror("Return type does not match");
        error_count++;
    }
}
| RETURN SEMICOLON error {
    fprintf(flog,"\nLine no %d : statement : RETURN SEMICOLON error\n",line_count);
}
;





expression_statement : SEMICOLON {
    fprintf(flog,"\nLine no %d : expression_statement : SEMICOLON\n",line_count);
}
| expression SEMICOLON {
    fprintf(flog,"\nLine no %d : expression_statement : expression SEMICOLON\n",line_count);
    $$ = $1;

}
;





variable : ID 	{
    fprintf(flog,"\nLine no %d : variable : ID\n%s\n",line_count,$1->getName().c_str());
    SymbolInfo* sp = table->Lookup($1->getName().c_str());

    if (sp != NULL) $$ = $1;
    else{
        $$ = NULL;
        yyerror("Undeclared Variable "+$1->getName());
        error_count++;
    }
}
| ID LTHIRD expression RTHIRD  {
    fprintf(flog,"\nLine no %d : variable : ID LTHIRD expression RTHIRD\n%s\n",line_count,$1->getName().c_str());
    SymbolInfo* sp = table->Lookup($1->getName().c_str());

    if(sp == NULL){
        yyerror("Undeclared Variable "+$1->getName());
        error_count++;
    }
    else if(sp->a_size == -1){
        yyerror("Index on non-array");
        error_count++;
    }
    else if($3->var_type == "FLOAT"){
        yyerror("Array index must be of 'int' type");
        error_count++;
    }
    else if($3->ival < 0 || $3->ival >= sp->a_size){
        yyerror("Array index out of bound");
        error_count++;
    }
    else{
        $$ = $1;
        $$ = &(sp->arr[$3->ival]);
        $$ = new SymbolInfo();
        $$->code = $3->code + "MOV BX, " + $3->symbol + "\nADD BX, BX\n";

        /*cout<<$$->code;*/
    }
}
;





expression : logic_expression {
    fprintf(flog,"\nLine no %d : expression : logic_expression\n",line_count);
    $$ = $1;
}
| variable ASSIGNOP logic_expression {
    fprintf(flog,"\nLine no %d : expression : variable ASSIGNOP logic_expression\n",line_count);
    if ($1){
        if ($1->var_type != $3->var_type){
            yyerror("Type not matched");
            error_count++;
        }
        else if ($1->a_size == 0){
            yyerror($1->getName() + " is not a variable");
            error_count++;
        }
        else if ($1->a_size > 0 ){
            yyerror("Index not in Array"); error_count++;
        }
        else if ($1->getName() == "" && $3->var_type == "INT"){
            $1->ival = $3->ival;
        }
        else if ($1->getName() == "" && $3->var_type == "FLOAT"){
            $1->fval = $3->fval;
        }
        else if ($1->var_type == "INT" && $3->var_type == "INT"){
            $1->ival = $3->ival;
        }
        else if ($1->var_type == "FLOAT" && $3->var_type == "FLOAT"){
            $1->fval = $3->fval;
        }
        $$ = $1;
    }
    table->PrintAllScopeTable();

    $$->code += "MOV AX, " + $3->symbol + " \n";
    $$->code += "MOV " + $1->symbol+", AX\n";


}
;




//BHABTE HOBE
logic_expression : rel_expression {
    fprintf(flog,"\nLine no %d : logic_expression : rel_expression\n",line_count);
    $$ = $1;
}
| rel_expression LOGICOP rel_expression {
    fprintf(flog,"\nLine no %d : logic_expression : rel_expression LOGICOP rel_expression\n",line_count);
    $$ = new SymbolInfo();

    $$=$1;
    $$->code += $3->code;

    char* temp = newTemp();
    char* label1 = newLabel();
    char* label2 = newLabel();

    if($2->getName() == "&&"){
        $$->code += "MOV " + (string)temp + ", 1\n";
        $$->code += "MOV AX, " + $1->getName() + "\n";
        $$->code += "CMP AX, 0\n";
        $$->code += "JE " + (string)label1 + "\n";
        $$->code += "MOV AX, " + $3->getName() + "\n";
        $$->code += "CMP AX, 0\n";
        $$->code += "JNE " + (string)label2 + "\n";
        $$->code += (string)label1 + ":\n";
        $$->code += "MOV " + (string)temp + ", 0\n";
        $$->code += (string)label2 + ":\n";
        $$->symbol = (string)temp;
    }
    else if($2->getName() == "||"){
        $$->code += "MOV " + (string)temp + ", 1\n";
        $$->code += "MOV AX, " +$1->getName() + "\n";
        $$->code += "CMP AX, 1\n";
        $$->code += "JE "+ (string)label2 + "\n";
        $$->code += "MOV AX, " + $3->getName() + "\n";
        $$->code += "CMP AX, 1\n";
        $$->code += "JE " + (string)label2 + "\n";
        $$->code += (string)label1 + ":\n";
        $$->code += "MOV " + (string)temp + ", 0\n";
        $$->code += (string)label2 + ":\n";
        $$->symbol = (string)temp;
    }

    cout<<$$->code;
}
;





rel_expression	: simple_expression {
    fprintf(flog,"\nLine no %d : rel_expression : simple_expression\n",line_count);
    $$ = $1;
}
| simple_expression RELOP simple_expression {
    fprintf(flog,"\nLine no %d : rel_expression : simple_expression RELOP simple_expression\n",line_count);
    $$ = new SymbolInfo();
    $$->setType($1->getType());
    $$=$1;

    $$->code += $3->code;
    $$->code += "MOV AX, " + string($1->getName()) + "\n";
    $$->code += "CMP AX, " + string($3->getName()) + "\n";

    char *temp = newTemp();
    char *label1 = newLabel();
    char *label2 = newLabel();

    if($2->getName() == "<"){
        $$->code += "JL " + string(label1)+"\n";
    }
    else if($2->getName() == "<="){
        $$->code += "JLE " + string(label1)+"\n";
    }
    else if($2->getName() == ">"){
        $$->code += "JG " + string(label1)+"\n";
    }
    else if($2->getName() == ">="){
        $$->code += "JNL " + string(label1)+"\n";
    }
    else if($2->getName() == "=="){
        $$->code+="JE " + string(label1)+"\n";
    }
    else{
        $$->code+="JNE " + string(label1)+"\n";
    }

    $$->code += "MOV "+ string(temp) + ", 0\n";
    $$->code += "JMP " + string(label2) + "\n";
    $$->code += string(label1) + ":\nMOV " + string(temp)+ ", 1\n";
    $$->code += string(label2) + ":\n";
    $$->symbol = temp;

    /*cout<<$$->code;*/
}
;




simple_expression : term {
    fprintf(flog,"\nLine no %d : simple_expression : term\n",line_count);
    $$ = $1;
}
| simple_expression ADDOP term {
    fprintf(flog,"\nLine no %d : simple_expression : simple_expression ADDOP term\n",line_count);
    $$ = new SymbolInfo();
    $$->setType($1->getType());

    $$=$1;
    $$->code += $3->code;

    if($2->getName() == "+"){
        char *temp = newTemp();
        $$->code += "MOV AX, "+ $3->symbol + "\nADD AX, " + $1->symbol + "\nMOV "+ string(temp)+ ", AX\n";

    }
    else{
        char *temp = newTemp();
        $$->code += "MOV AX, "+ $1->symbol + "\nSUB AX, " + $3->symbol + "\nMOV "+ string(temp)+ ", AX\n";
    }
    delete $3;

    /*cout<<$$->code;*/
}
;





term :	unary_expression {
    fprintf(flog,"\nLine no %d : term : unary_expression\n",line_count);
    $$ = $1;
    }
    |  term MULOP unary_expression {
        fprintf(flog,"\nLine no %d : term MULOP unary_expression\n",line_count);
        $$ = new SymbolInfo();
        $$=$1;

        $$->code += $3->code;
        $$->code += "MOV AX, " + $1->symbol +"\n";
        $$->code += "MOV BX, " + $3->symbol + "\n";

        char *temp = newTemp();

        if ($2->getName() == "%"){
            if ($1->var_type == "FLOAT" || $3->var_type == "FLOAT"){
                yyerror("Non-Integer operand on modulus operator");
                error_count++;
            }
            else $$->ival = $1->ival % $3->ival;

            $$->code += "XOR DX, DX\nDIV BX\nMOV "+ string(temp)+", DX\n";
        }
        else {
            if ($1->var_type == "FLOAT" || $3->var_type == "FLOAT"){
                $$->var_type = "FLOAT";
                if ($1->var_type != "FLOAT" && $2->getName() == "*"){
                    $$->fval = $1->ival * $3->fval;
                    $$->code += "MUL BX\n";
                    $$->code += "MOV " + string(temp) + ", AX\n";
                }
                else if ($2->var_type != "FLOAT" && $2->getName() == "*"){
                    $$->fval = $1->fval * $3->ival;
                    $$->code += "MUL BX\n";
                    $$->code += "MOV " + string(temp) + ", AX\n";
                }
                else if ($1->var_type != "FLOAT" && $2->getName() == "/"){
                    $$->fval = $1->ival / $3->fval;
                    $$->code += "XOR DX, DX\nDIV BX\nMOV "+ string(temp)+", AX\n";
                }
                else if ($2->var_type != "FLOAT" && $2->getName() == "/"){
                    $$->fval = $1->fval / $3->ival;
                    $$->code += "XOR DX, DX\nDIV BX\nMOV "+ string(temp)+", AX\n";
                }
            }
            else {
                $$->var_type = "INT";
                if ($2->getName() == "*"){
                    $$->ival = $1->ival * $3->ival;
                    $$->code += "MUL BX\n";
                    $$->code += "MOV " + string(temp) + ", AX\n";
                }
                else{
                    $$->ival = $1->ival / $3->ival;
                    $$->code += "XOR DX, DX\nDIV BX\nMOV "+ string(temp)+", AX\n";
                }
            }
        }
        $$->symbol = temp;

        /*fprintf(flog,"\nLine no %d : term MULOP unary_expression\n",line_count);
        $$ = new SymbolInfo();
        $$=$1;

        $$->code += $3->code;
        $$->code += "MOV AX, " + $1->symbol +"\n";
        $$->code += "MOV BX, " + $3->symbol + "\n";

        char *temp = newTemp();

        if($2->getName() == "*"){
            $$->code += "MUL BX\n";
            $$->code += "MOV " + string(temp) + ", AX\n";
        }
        else if($2->getName() == "/"){
            $$->code += "XOR DX, DX\nDIV BX\nMOV "+ string(temp)+", AX\n";
        }
        else{
            $$->code += "XOR DX, DX\nDIV BX\nMOV "+ string(temp)+", DX\n";
        }
        $$->symbol = temp;*/
    }
;





unary_expression : ADDOP unary_expression  {
    fprintf(flog,"\nLine no %d : unary_expression : ADDOP unary_expression\n",line_count);
    $$ = new SymbolInfo();
    $$->setType($2->getType());
    $$->var_type = $2->var_type;

    $$=$2;

    if ($1->getName() == "+"){
        $$->ival = $2->ival;
        $$->fval = $2->fval;
    }
    else{
        $$->ival = -$2->ival;
        $$->fval = -$2->fval;

        $$->code += "MOV AX, " + $2->symbol + " \n";
        $$->code += "NEG AX\n";
        $$->code += "MOV " + $2->symbol + ", AX\n";

        cout<<$$->code;
    }
}
| NOT unary_expression  {
    fprintf(flog,"\nLine no %d : unary_expression : NOT unary_expression\n",line_count);
    $$ = new SymbolInfo();
    $$->setType($2->getType());
    $$->var_type = "INT";
    if ($2->var_type == "INT") $$->ival = !($2->ival);
    else if ($2->var_type == "FLOAT") $$->ival = !($2->fval);

    $$=$2;
    char *temp=newTemp();
    $$->code="MOV AX, " + $2->symbol + "\n";
    $$->code+="NOT AX\n";
    $$->code+="MOV "+ string(temp)+ ", AX\n";
    $2->symbol = string(temp);

}
| factor {
    fprintf(flog,"\nLine no %d : unary_expression : factor\n",line_count);
    $$ = $1;
}
;






factor	: variable {
    fprintf(flog,"\nLine no %d : factor : variable\n",line_count);
    $$ = $1;
}
| ID LPAREN argument_list RPAREN {
    SymbolInfo *sp = table->Lookup($1->getName());
    if (sp == NULL) {yyerror("Undeclared Function "+$1->getName()); error_count++;}
    else{
        fprintf(flog,"\nLine no %d : factor : ID LPAREN argument_list RPAREN\n%s\n",line_count,$1->getName().c_str());
        if (sp->a_size != 0){
            yyerror(sp->getName()+" is not a function");
            error_count++;
        }
        else if (sp->param_list.size() == list.size()){
            for (int i = 0; i < sp->param_list.size(); i++){
                if (sp->param_list[i] != list[i]){
                    string s = patch::to_string(i+1);
                    yyerror(s+"th argument mismatch in function"+sp->getName());
                    error_count++;
                    break;
                }
            }
        }
        else {
            yyerror("Number of arguments mismatch");
            error_count++;
        }
    }
    list.clear();
}
| LPAREN expression RPAREN {
    fprintf(flog,"\nLine no %d : factor : LPAREN expression RPAREN\n",line_count); $$ = $2;}
    | CONST_INT {
        fprintf(flog,"\nLine no %d : factor : CONST_INT\n%s\n",line_count,$1->getName().c_str()); $$ = $1;
    }
    | CONST_FLOAT {
        fprintf(flog,"\nLine no %d : factor : CONST_FLOAT\n%s\n",line_count,$1->getName().c_str()); $$ = $1;
    }
    | CONST_CHAR {;}
    | variable INCOP{
        SymbolInfo *sp = table->Lookup($1->getName());
        if (sp){
            if ($1->var_type == "INT"){
                $1->ival++;
                sp->ival = $1->ival;
            }
            else if ($1->var_type == "FLOAT"){
                $1->fval++;
                sp->fval = $1->fval;
            }
        }
        else yyerror("");
        $$ = $1;
        fprintf(flog,"\nLine no %d : factor : variable INCOP\n",line_count);

        $$->code += "INC " + $1->symbol + " \n";
    }
    | variable DECOP{
        SymbolInfo *sp = table->Lookup($1->getName());
        if (sp){
            if ($1->var_type == "INT"){
                $1->ival--;
                sp->ival = $1->ival;
            }
            else if ($1->var_type == "FLOAT"){
                $1->fval--;
                sp->fval = $1->fval;
            }
        }
        else yyerror("");
        $$ = $1;
        fprintf(flog,"\nLine no %d : factor : variable DECOP\n",line_count);

        $$->code += "DEC " + $1->symbol + " \n";
    }
    ;





argument_list : arguments {
    fprintf(flog,"\nLine no %d : argument_list : arguments\n",line_count);
}
| {
    fprintf(flog,"\nLine no %d : argument_list : \n",line_count);
}
;
arguments  : arguments COMMA logic_expression {
    fprintf(flog,"\nLine no %d : arguments : arguments COMMA logic_expression\n",line_count);
    list.push_back($3->var_type);
}
| logic_expression {
    fprintf(flog,"\nLine no %d : arguments : logic_expression\n",line_count);
    list.push_back($1->var_type);
}
;





%%
string command(string line){
	int i = 0;
	while(line[i] != ' ') i++;
	return line.substr(0, i);
}
string destination(string line){
	int i = 0;
	while(line[i] != ' ') i++;
	i++;
	int j = i+1;
	while(line[j] != ',' && j<line.size()) j++;
	return line.substr(i, j-i);
}
string source(string line){
	int i = 0;
	while(line[i] != ',') i++;
	i += 2;
	return line.substr(i, line.size()-i);
}

int main(int argc,char *argv[]){
    FILE *fp;
    if((fp=fopen(argv[1],"r"))==NULL)
    {
        printf("Cannot Open Input File.\n");
        exit(1);
    }
    flog = fopen("log.txt","w");
    error = fopen("error.txt","w");

    asmO.open("code.asm");

    yyin=fp;
    yyparse();

    fprintf(flog,"\nTotal Lines: %d\n",line_count-1);
    fprintf(flog,"\nTotal Errors: %d\n",error_count);

    asmO.close();
    fclose(fp);
    fclose(flog);
    fclose(error);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ifstream optIn;
    ofstream optOut;
    optIn.open("code.asm");
    optOut.open("optimizedCode.asm");

    string buffer = "";
    string line = "";

    while(!optIn.eof()){
        getline(optIn, line);

        if(line == "END MAIN") break;
        if(line == "") continue;

        if(command(line) == "ADD" || command(line) == "SUB"){
            if(source(line) == "0") continue;
        }
        if(command(line) == "MUL" || command(line) == "DIV"){
            if(destination(line) == "1") continue;
        }

        buffer = line;
        getline(optIn, line);

        if(command(line) == "MOV" && command(buffer) == "MOV"){
            if(source(line) == destination(buffer) && source(buffer) == destination(line)){
                cout<<"Unnecessary MOV found"<<endl;
                continue;
            }
        }
        optOut<<buffer<<endl;
    }

    optIn.close();
    optOut.close();

    return 0;
}
