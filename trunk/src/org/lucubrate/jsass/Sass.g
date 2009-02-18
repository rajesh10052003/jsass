/**
 * Sass Grammar
 * (c) Joey Hurst
 * 
 * This grammar is derived from the Sass rdoc documentation, compiler, and unit tests.
 */
grammar Sass;

///////////////////////////////////////////////////////////
// DOCUMENT                                              //
///////////////////////////////////////////////////////////

document
	:	statement+
	;
	
statement
//	:	css_declaration
//	|	css_selector
	:	constant_declaration
//	|	comment
//	|	directive
//	|	mixin_definition
//	|	mixin_include
	|	NEWLINE
	;

///////////////////////////////////////////////////////////
// CONSTANTS                                             //
///////////////////////////////////////////////////////////

/**
 * A document-wide constant that can be used as the value of an attribute.
 */
constant_declaration
	:	CONSTANT_IDENTIFIER ( ASSIGNMENT | OPTIONAL_ASSIGNMENT ) constant_expression NEWLINE
	;

/**
 * The value of a constant.
 * Note that "constant_term+" is used to support the adjacency operator.  The Ruby Sass
 * compiler forces whitespace for the adjanceny operator, but I allow items to
 * actually touch (like Ruby, which is what I think they were going for).
 */
constant_expression
	:	constant_term+ ( ( PLUS | MINUS ) constant_term+ )*
	;
constant_term
	:	constant_factor ( ( MULT | DIV | MOD ) constant_factor )*
	;
constant_factor
	:	INT
	|	FLOAT
	|	COLOR
	|	STR
	|	CONSTANT_IDENTIFIER
	|	'(' constant_expression ')'
	;

///////////////////////////////////////////////////////////
// LEXER RULES                                           //
///////////////////////////////////////////////////////////

/**
 * Constant operators.
 */
MULT:	'*' ;
DIV	:	'/' ;
MOD :	'%' ;
PLUS 
	:	'+' ;
MINUS 
	:	'-' ;
OPTIONAL_ASSIGNMENT
	:	'||=' ;
ASSIGNMENT
	:	'=' ;

/**
 * A constant identifier.
 * The Ruby Sass compiler is quite permissive with identifiers . . .
 * I'm only going to allow a more sane subset to prevent identifiers like:
 * []@%...FOOO~
 */
CONSTANT_IDENTIFIER
	:	CONSTANT_PREFIX
		('_' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' ) 
		('_' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' | '0'..'9')*
	;
fragment
CONSTANT_PREFIX 
	:	'!'
	;

/**
 * Number and length literals.
 * The Ruby Sass compiler is also very permissive with length units . . .
 * I'm only allowing a subset again (which includes all valid CSS2/3 units).
 */
INT
	:	MINUS?  DIGIT+ UNIT?
	;
FLOAT
	:	MINUS? DIGIT* '.' DIGIT+ UNIT?
	;
fragment
UNIT
	:	('_' | '%' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' ) 
		('_' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' | '0'..'9')*
	;
fragment
DIGIT
	: '0'..'9'
	;

/**
 * Color literals
 * CSS has a lot more built-in colors than listed here, but those are the ones
 * defined in the Ruby Sass compiler . . .
 */
COLOR
	:	'#' ( HEX_DIGIT HEX_DIGIT HEX_DIGIT |  HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT )
	|	COLOR_SHORTCUTS
	;
fragment
COLOR_SHORTCUTS 
	:	'black' | 'silver' | 'gray' | 'white' | 'maroon' | 'red' | 'purple' | 'fuchsia' | 'green' | 'lime' | 'olive' | 'yellow' | 'navy' | 'blue' | 'teal' | 'aqua'
	;
fragment
HEX_DIGIT
	:	'a'..'f' | 'A'..'F' | DIGIT
	;

/**
 * According to the documentation, string literals are,
 * "the type that's used by default when an element in a bit of constant arithmetic isn't recognized as another type of constant"
 * Oy vey.  I'm going to lock down things a bit more (no keyword-ish type chars allowed unless in double quotes).
 * I'm tempted to require all strings to go in double quotes, but it looks like a lot of people use the no-quote string literal
 * feature, so I'm going to keep it (to a degree).
 * One particularly ugly result of this is the following:
 * Sass~ :some_declaration = Clifford the big red dog
 * CSS~ some_declaration: Clifford the big #ff0000 dog
 * Oops.
 */
STR
	:	('_' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' )
		('_' | 'a'..'z'| 'A'..'Z' | '\u0100'..'\ufffe' | '0'..'9')*
	|	'"' DOUBLESTRING_CHAR* '"'
	;
fragment
DOUBLESTRING_CHAR
	:	~( '"' | '\\' | NEWLINE )
	|	'\\"'
	;

NEWLINE
	:	( ('\u000c')? ('\r')? '\n' )+
	;

WHITESPACE
	: ( ' ' | '\t' )+ { $channel=HIDDEN; }
	;
