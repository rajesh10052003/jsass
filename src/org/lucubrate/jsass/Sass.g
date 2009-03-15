/**
 * Sass Grammar
 * (c) Joey Hurst 2009
 *
 * This grammar is derived from the Sass rdoc documentation, compiler, and unit
 * tests.
 */
grammar Sass;

///////////////////////////////////////////////////////////
// ANTLR CONFIG                                          //
///////////////////////////////////////////////////////////

options {
    output=AST;
    ASTLabelType=CommonTree;
}

tokens {
    INDENT;
    DEDENT;
    SELECTOR_GROUP;
    DECLARATION_GROUP;
    SUBRULE_GROUP;
}

@lexer::members {
List tokens = new ArrayList();
public void emit(Token token) {
    state.token = token;
    tokens.add(token);
}
public Token nextToken() {
    super.nextToken();
    if ( tokens.size()==0 ) {
        return Token.EOF_TOKEN;
    }
    return (Token)tokens.remove(0);
}

/* Was the last matched token LEADING_WHITESPACE ? */
private boolean afterLeadingWS = false;

/* Are we currently at the beginning of a line (ignoring whitespace)? */
private boolean isBeginningOfLine() {
    return afterLeadingWS || getCharPositionInLine() == 0;
}
}

///////////////////////////////////////////////////////////
// DOCUMENT                                              //
///////////////////////////////////////////////////////////

document
    :   (statement { System.out.println($statement.tree.toStringTree()); } )+
    ;

// @todo
statement
    :   constant_declaration
//  |   import_declaration
    |   css_rule
//  |   silent_comment
//  |   loud_comment
//  |   mixin_definition
//  |   mixin_include
    ;

///////////////////////////////////////////////////////////
// CSS RULES                                             //
///////////////////////////////////////////////////////////

/**
 * A CSS rule.
 */
css_rule
    :   css_selector (INDENT (css_declaration | css_rule)+ DEDENT)?
        -> ^(SELECTOR_GROUP css_selector)
           ^(DECLARATION_GROUP css_declaration*)?
           ^(SUBRULE_GROUP css_rule*)?
    ;

/**
 * A CSS selector
 */
css_selector
    :   SELECTOR+ NEWLINE!
    ;

/**
 * A CSS property/value pair.
 */
css_declaration
    :   DECLARATION_PROPERTY^ DECLARATION_VALUE NEWLINE!
    |   DECLARATION_PROPERTY ASSIGNMENT^ constant_expression NEWLINE!
    ;


///////////////////////////////////////////////////////////
// CONSTANTS                                             //
///////////////////////////////////////////////////////////

/**
 * A document-wide constant that can be used as the value of a declaration.
 */
constant_declaration
    :   CONSTANT_IDENTIFIER
            ( ASSIGNMENT | OPTIONAL_ASSIGNMENT )^
            constant_expression
            NEWLINE!
    ;

/**
 * The value of a constant.
 * Note that "constant_term+" is used to support the adjacency operator.  The
 * Ruby Sass compiler forces whitespace for the adjanceny operator, but I allow
 * items to actually touch (like Ruby, which is what I think they were going
 * for).
 */
constant_expression
    :   constant_term+ ( ( PLUS | MINUS )^ constant_term+ )*
    ;
constant_term
    :   constant_factor ( ( MULT | DIV | MOD )^ constant_factor )*
    ;
constant_factor
    :   INT
    |   FLOAT
    |   COLOR
    |   COLOR_SHORTCUTS
    |   STR
    |   CONSTANT_IDENTIFIER
    |   '('! constant_expression ')'!
    ;

///////////////////////////////////////////////////////////
// DOCUMENT LEXER RULES                                  //
///////////////////////////////////////////////////////////

/**
 * One or more cross-platform newlines.  Empty lines are hidden.
 */
NEWLINE
@init {int position = getCharPositionInLine();}
    :   ('\r'? '\n')+
        { if (position==0) { $channel = HIDDEN; } }
    ;

/**
 * Hidden whitespace.
 */
WHITESPACE
    :   {getCharPositionInLine() > 0}?=> ( ' ' | '\t' )+ { $channel=HIDDEN; }
    ;

/**
 * Whitespace at the beginning of a line which is used in conjunction with
 * SassTokenSource to generate INDENT and (imaginary) DEDENT tokens.
 */
LEADING_WHITESPACE
    :   {getCharPositionInLine() == 0}?=> ' '+
        ( '\r'? '\n' { $channel = HIDDEN; } )*
        {afterLeadingWS = true;}
    ;


///////////////////////////////////////////////////////////
// CSS LEXER RULES                                       //
///////////////////////////////////////////////////////////

fragment DECLARATION_SEPARATOR
    :   ':'
    ;
fragment DECLARATION_PROPERTY
    :   ~(' ' | '\t' | '\r' | '\n' | ASSIGNMENT | DECLARATION_SEPARATOR)+
    ;
fragment DECLARATION_VALUE
    :   ~( ASSIGNMENT | '\n' | '\r' ) ~('\n' | '\r')*
    ;
/**
 * A CSS property/value pair.
 */
DECLARATION
    :   // Sass style declarations (e.g. ":width 20px")
        DECLARATION_SEPARATOR p=DECLARATION_PROPERTY
        {
            $p.setType(DECLARATION_PROPERTY); emit($p);
            afterLeadingWS = false;
        }
        (
            ( WHITESPACE? a=ASSIGNMENT { $a.setType(ASSIGNMENT); emit($a); } )
          | ( WHITESPACE v=DECLARATION_VALUE n=NEWLINE
                {
                    $v.setType(DECLARATION_VALUE); emit($v);
                    $n.setType(NEWLINE); emit($n);
                }
            )
        )
    |   // CSS style declarations (e.g. "width: 20px")
        l=LEADING_WHITESPACE p=DECLARATION_PROPERTY
        {
            $l.setType(LEADING_WHITESPACE); emit($l);
            $p.setType(DECLARATION_PROPERTY); emit($p);
            afterLeadingWS = false;
        }
        (
            ( WHITESPACE? a=ASSIGNMENT { $a.setType(ASSIGNMENT); emit($a); } )
          | ( DECLARATION_SEPARATOR WHITESPACE? v=DECLARATION_VALUE n=NEWLINE
                {
                    $v.setType(DECLARATION_VALUE); emit($v);
                    $n.setType(NEWLINE); emit($n);
                }
            )
        )
    ;

// css selector separator character (in a grouped selector)
fragment SELECTOR_SEPARATOR
    :   ','
    ;
// a css selector expression
fragment SELECTOR
    :   
        ~( ASSIGNMENT
           | DECLARATION_SEPARATOR
           | CONSTANT_PREFIX
           | SELECTOR_SEPARATOR
           | ' ' | '\t'
           | '\r' | '\n'
         )
        ~( '\r' | '\n' | SELECTOR_SEPARATOR )*
    ;
// allow a group selector to span multiple lines 
fragment SELECTOR_WHITESPACE
    :   WHITESPACE? (NEWLINE (' ' | '\t')*)?
    ;
 /**
 * A CSS selector.
 */
GROUPED_SELECTOR
    :   {isBeginningOfLine()}?=>
        (
            s1=SELECTOR { $s1.setType(SELECTOR); emit($s1); }
              (
                SELECTOR_SEPARATOR SELECTOR_WHITESPACE s2=SELECTOR
                {  $s2.setType(SELECTOR); emit($s2); }
              )*

        )
    ;

///////////////////////////////////////////////////////////
// CONSTANT LEXER RULES                                  //
///////////////////////////////////////////////////////////

/**
 * Constant operators.
 */
MULT                :   '*' ;
DIV                 :   '/' ;
MOD                 :   '%' ;
PLUS                :   '+' ;
MINUS               :   '-' ;
OPTIONAL_ASSIGNMENT :   '||=' ;
ASSIGNMENT          :   '=' ;

/**
 * A constant identifier.
 * The Ruby Sass compiler is quite permissive with identifiers . . .
 * I'm only going to allow a more sane subset to prevent identifiers like:
 * []@%...FOOO~
 */
CONSTANT_IDENTIFIER
    :   CONSTANT_PREFIX
        ('_' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' )
        ('_' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' | '0'..'9')*
        {afterLeadingWS = false;}
    ;
fragment
CONSTANT_PREFIX
    :   '!'
    ;

/**
 * Number and length literals.
 * The Ruby Sass compiler is also very permissive with length units . . .
 * I'm only allowing a subset again (which includes all valid CSS2/3 units).
 */
INT
    :   MINUS?  DIGIT+ UNIT?
    ;
FLOAT
    :   MINUS? DIGIT* '.' DIGIT+ UNIT?
    ;
fragment
UNIT
    :   ('_' | '%' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' )
        ('_' | '%' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' | '0'..'9')*
    ;
fragment
DIGIT
    :   '0'..'9'
    ;

/**
 * Color literals
 * CSS has a lot more built-in color shortcuts than listed here, but those are
 * the ones defined in the Ruby Sass compiler . . .
 */
COLOR
    :   '#' (   HEX_DIGIT HEX_DIGIT HEX_DIGIT
              | HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT
            )
    ;
fragment
HEX_DIGIT
    :   'a'..'f' | 'A'..'F' | DIGIT
    ;
COLOR_SHORTCUTS
    :   {!isBeginningOfLine()}?=>
        ( 'black' | 'silver' | 'gray' | 'white' | 'maroon' | 'red' | 'purple' |
            'fuchsia' | 'green' | 'lime' | 'olive' | 'yellow' | 'navy' |
            'blue' |'teal' | 'aqua' )
    ;

/**
 * According to the documentation, string literals are,
 * "the type that's used by default when an element in a bit of constant
 * arithmetic isn't recognized as another type of constant" Oy vey.  I'm going
 * to lock down things a bit more (no keyword-ish type chars allowed unless in
 * double quotes). I'm tempted to require all strings to go in double quotes,
 * but it looks like a lot of people use the no-quote string literal feature,
 * so I'm going to keep it (to a degree).
 *
 * One ugly result of this is the following:
 * Sass~ :some_declaration = Clifford the big red dog
 * CSS~ some_declaration: Clifford the big #ff0000 dog
 *
 * Oops.
 */
fragment UnicodeChar: ~('"'| '\\');
fragment StringChar :  UnicodeChar | EscapeSequence;
fragment EscapeSequence
    :   '\\' ('\"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' |
             'u' HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT)
    ;
STR :   ('_' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' )
            ('_' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' | '0'..'9')*
    |   '"' StringChar* '"'
    ;
