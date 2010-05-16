#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "xs_hints.h"
#include "ppport.h"

// -----------------------------------------------------
// allocate global vars.
static SV *hintkey_sv;                                              // key for hinthash
static int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);     // next plugin code for next chain

// -----------------------------------------------------
// the parser

static OP *THX_do_parse(pTHX_ const char *prefix, STRLEN len, const char *executer, size_t executer_len) {
    // PerlIO_printf(PerlIO_stderr(), "K: %s\n", prefix);
	OP *op;
    SV *buf = newSVpv(prefix, len);
	while(1) {
        I32 c;
		c = lex_peek_unichar(0);
        switch (c) {
        case -1: // reached the end of the input text
            croak("reached to unexpected EOF in parsing embedded SQL");
        case ';': // finished.
            lex_read_unichar(0);
            goto FINISHED;
        default: /* push to buffer */
            // PerlIO_printf(PerlIO_stderr(), "%c\n", c);
            sv_catpvn(buf, (char*)&c, 1);
            lex_read_unichar(0);
        }
    }
FINISHED:
    // PerlIO_printf(PerlIO_stderr(), "%s\n", SvPV_nolen(buf));
    op = newUNOP(
            OP_ENTERSUB,
            OPf_STACKED,
            Perl_append_elem(OP_LIST,
                Perl_prepend_elem(OP_LIST,
                    newSVOP(OP_CONST, 0, newSVpvn("SQL::Embedded", sizeof("SQL::Embedded")-1)),
                    newSVOP(OP_CONST, 0, buf)),
                newUNOP(OP_METHOD, 0,
                    newSVOP(OP_CONST, 0, newSVpvn(executer, executer_len)))));
    return op;
}

// -----------------------------------------------------
// hook code
#define MY_CHECK(x, func) \
    if (keyword_len == sizeof(x)-1 && strnEQ(keyword_ptr, x, sizeof(x)-1) && hint_active(hintkey_sv)) { \
		*op_ptr = THX_do_parse(aTHX_ x " ", sizeof(x)-1+1, func, sizeof(func)-1); \
		return KEYWORD_PLUGIN_EXPR; \
    }
static int my_keyword_plugin(pTHX_
	char *keyword_ptr, STRLEN keyword_len, OP **op_ptr)
{
    MY_CHECK("SELECT",  "SQL::Embedded::_run_select");
    MY_CHECK("EXEC",    "SQL::Embedded::_run_exec");
    MY_CHECK("INSERT",  "SQL::Embedded::_run_do");
    MY_CHECK("UPDATE",  "SQL::Embedded::_run_do");
    MY_CHECK("DELETE",  "SQL::Embedded::_run_do");
    MY_CHECK("REPLACE", "SQL::Embedded::_run_do");

    return next_keyword_plugin(aTHX_ keyword_ptr, keyword_len, op_ptr);
}

MODULE = SQL::Embedded PACKAGE = SQL::Embedded

BOOT:
    // initialize key for hinthash
	hintkey_sv = newSVpvs_share("SQL::Embedded");

    // inject my code to hook point.
	next_keyword_plugin = PL_keyword_plugin;
	PL_keyword_plugin = my_keyword_plugin;

void
import(SV *classname, ...)
PPCODE:
    hint_enable(hintkey_sv);

void
unimport(SV *classname, ...)
PPCODE:
    hint_disable(hintkey_sv);

