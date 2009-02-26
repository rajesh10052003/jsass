import org.antlr.runtime.*;
import java.util.*;

public class SassTokenSource implements TokenSource {
    /** Stream from which we'll pull tokens. */
    CommonTokenStream stream;

    /** The queue of tokens. */
    Vector tokens = new Vector();

    /** The current amount of indentation. */
    int indentationLevel = 0;

    /** Number of space characters used to represent blocks. */
    int SPACES_PER_BLOCK = 2;

    int lastTokenAddedIndex = -1;

    String filename;

    public SassTokenSource(CommonTokenStream stream) {
        this(stream, "<INPUT>");
    }

    public SassTokenSource(CommonTokenStream stream, String filename) {
        this.stream = stream;
        this.filename = filename;
    }

    public String getSourceName() {
        return this.filename;
    }

    public Token nextToken() {
        if (this.tokens.size() > 0) {
            Token t = (Token)this.tokens.firstElement();
            this.tokens.removeElementAt(0);
            System.out.println(t.toString());
            return t;
        }

        insertImaginaryIndentDedentTokens();
        return nextToken();
    }

    private void generateNewline(Token t) {
        CommonToken newline = new CommonToken(SassLexer.NEWLINE, "\n");
        newline.setLine(t.getLine());
        newline.setCharPositionInLine(t.getCharPositionInLine());
        this.tokens.addElement(newline);
    }

    private void handleEOF(CommonToken eof, CommonToken prev) {
        if (prev != null) {
            eof.setStartIndex(prev.getStopIndex());
            eof.setStopIndex(prev.getStopIndex());
            eof.setLine(prev.getLine());
            eof.setCharPositionInLine(prev.getCharPositionInLine());
        }
    }

    private void insertImaginaryIndentDedentTokens() {
        Token t = stream.LT(1);
        stream.consume();

        if (t.getType() == Token.EOF) {
            Token prev = stream.LT(-1);
            handleEOF((CommonToken)t, (CommonToken)prev);
            if (prev == null) {
                generateNewline(t);
            } else if (prev.getType() == SassLexer.LEADING_WHITESPACE) {
                handleDedents(-1, (CommonToken)t);
                generateNewline(t);
            } else if (prev.getType() != SassLexer.NEWLINE) {
                generateNewline(t);
                handleDedents(-1, (CommonToken)t);
            }
            enqueue(t);
        } else if (t.getType() == SassLexer.NEWLINE) {
            enqueueHiddens(t);
            this.tokens.addElement(t);
            Token newline = t;
            t = stream.LT(1);
            stream.consume();
            
            List<Token> commentedNewlines = enqueueHiddens(t);

            // find the next non-WS token on the line
            int cpos = t.getCharPositionInLine();

            if (t.getType() == Token.EOF) {
                handleEOF((CommonToken)t, (CommonToken)newline);
                cpos = -1;
            } else if (t.getType() == SassLexer.LEADING_WHITESPACE) {
                Token next = stream.LT(1);
                if (next != null && next.getType() == Token.EOF) {
                    stream.consume();
                    return;
                } else {
                    cpos = t.getText().length();
                }
            }

            if (cpos > this.indentationLevel) {
                handleIndents(cpos, (CommonToken)t);
            } else if (cpos < this.indentationLevel) {
                handleDedents(cpos, (CommonToken)t);
            }

            if (t.getType() != SassLexer.LEADING_WHITESPACE) {
                this.tokens.addElement(t);
            }
        } else {
            enqueue(t);
        }
    }

    private void enqueue(Token t) {
        enqueueHiddens(t);
        this.tokens.addElement(t);
    }

    private List<Token> enqueueHiddens(Token t) {
        List<Token> newlines = new ArrayList<Token>();
        List hiddenTokens = stream.getTokens(lastTokenAddedIndex + 1, t.getTokenIndex() -1);
        if (hiddenTokens != null) {
            tokens.addAll(hiddenTokens);
        }
        lastTokenAddedIndex = t.getTokenIndex();
        return newlines;
    }


    private void handleIndents(int cpos, CommonToken t) {
        validateIndentation(cpos, t);
        if (cpos != this.indentationLevel + SPACES_PER_BLOCK) {
            throw new ParseException("can only indent one block (two spaces) at a time", t.getLine(), t.getCharPositionInLine());
        }
        this.indentationLevel = cpos;
        CommonToken indent = new CommonToken(SassParser.INDENT, "");
        indent.setCharPositionInLine(t.getCharPositionInLine());
        indent.setLine(t.getLine());
        indent.setStartIndex(t.getStartIndex() - 1);
        indent.setStopIndex(t.getStartIndex() - 1);
        tokens.addElement(indent);
    }

    private void handleDedents(int cpos, CommonToken t) {
        validateIndentation(cpos, t);

        int delta = (this.indentationLevel - cpos) / SPACES_PER_BLOCK;
        for ( ; delta > 0; delta--) {
            CommonToken dedent = new CommonToken(SassParser.DEDENT, "");
            dedent.setCharPositionInLine(t.getCharPositionInLine());
            dedent.setLine(t.getLine());
            dedent.setStartIndex(t.getStartIndex() - 1);
            dedent.setStopIndex(t.getStartIndex() - 1);
            tokens.addElement(dedent);
        }
        
        this.indentationLevel = cpos;
    }

    private void validateIndentation(int cpos, CommonToken t) {
        if (cpos % SPACES_PER_BLOCK == 1) {
            throw new ParseException("indentation must be exactly two spaces per block", t.getLine(), t.getCharPositionInLine());
        }

    }

}
