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

static OP *parse_var(pTHX) {
    char *s = PL_parser->bufptr;
    char *start = s;
    PADOFFSET varpos;
    OP *padop;
    if(*s != '$') croak("SQL syntax error");
    while(1) {
        char c = *++s;
        if (!(isALNUM(c) || c == '_')) break;
    }
    if(s-start < 2) croak("SQL syntax error");
    lex_read_to(s);
    {
        /* because pad_findmy() doesn't really use length yet */
        SV *namesv = sv_2mortal(newSVpvn(start, s-start));
        varpos = pad_findmy(SvPVX(namesv), s-start, 0);
    }
    if(varpos == NOT_IN_PAD || PAD_COMPNAME_FLAGS_isOUR(varpos))
        croak("SQL::Embedded only supports \"my\" variables");
    padop = newOP(OP_PADSV, 0);
    padop->op_targ = varpos;
    return padop;
}

static void parse(pTHX_ SV *query, OP**op_vars) {
	while(1) {
        I32 c;
		c = lex_peek_unichar(0);
        switch (c) {
        case -1: // reached the end of the input text
            croak("reached to unexpected EOF in parsing embedded SQL");
        case '$': // vars
            {
                OP * op = parse_var(aTHX);
                if (*op_vars) {
                    *op_vars = Perl_prepend_elem(OP_LIST, op, *op_vars);
                } else {
                    *op_vars = op;
                }
            }
            sv_catpvn(query, "?", 1);
            break;
        case ';': // finished.
            lex_read_unichar(0);
            goto FINISHED;
        default: /* push to buffer */
            // PerlIO_printf(PerlIO_stderr(), "%c\n", c);
            sv_catpvn(query, (char*)&c, 1);
            lex_read_unichar(0);
        }
    }
FINISHED:
    return;
}

static OP *do_parse_select(pTHX_ const char *prefix, STRLEN prefix_len, const char *executer, size_t executer_len) {
    // PerlIO_printf(PerlIO_stderr(), "K: %s\n", prefix);
	OP *op;
    SV *query = newSVpv("", 0);
    OP *op_vars = NULL;
    OP * args;

    parse(query, &op_vars);

    // PerlIO_printf(PerlIO_stderr(), "%s\n", SvPV_nolen(buf));
    args = Perl_prepend_elem(OP_LIST,
                Perl_prepend_elem(OP_LIST,
                    newSVOP(OP_CONST, 0, newSVpvn("SQL::Embedded", sizeof("SQL::Embedded")-1)),
                    newSVOP(OP_CONST, 0, newSVpvn(prefix, prefix_len))),
                newSVOP(OP_CONST, 0, query));
    if (op_vars) {
       args = Perl_prepend_elem(OP_LIST, args, op_vars);
    }
    op = newUNOP(
            OP_ENTERSUB,
            OPf_STACKED,
            Perl_append_elem(OP_LIST,
                args,
                newUNOP(OP_METHOD, 0,
                    newSVOP(OP_CONST, 0, newSVpvn(executer, executer_len)))));
    return op;
}

#define newSVpvn_const(x) newSVpvn(x, sizeof(x)-1)

static OP *do_parse_exec(pTHX_ const char *prefix, STRLEN prefix_len, const char *executer, size_t executer_len) {
    // PerlIO_printf(PerlIO_stderr(), "K: %s\n", prefix);
	OP *op;
    SV *query = newSVpv("", 0);
    OP *op_vars = NULL;
    OP * args;

    parse(query, &op_vars);

    // PerlIO_printf(PerlIO_stderr(), "%s\n", SvPV_nolen(buf));
    args = Perl_prepend_elem(OP_LIST,
                newSVOP(OP_CONST, 0, newSVpvn("SQL::Embedded", sizeof("SQL::Embedded")-1)),
                newSVOP(OP_CONST, 0, query));
    if (op_vars) {
       args = Perl_prepend_elem(OP_LIST, args, op_vars);
    }
    op = newUNOP(
            OP_ENTERSUB,
            OPf_STACKED,
            Perl_append_elem(OP_LIST,
                args,
                newUNOP(OP_METHOD, 0,
                    newSVOP(OP_CONST, 0, newSVpvn_const("SQL::Embedded::_sql_prepare_exec")))));
    return op;
}

static OP *do_parse_do(pTHX_ const char *prefix, STRLEN prefix_len, const char *executer, size_t executer_len) {
    // PerlIO_printf(PerlIO_stderr(), "K: %s\n", prefix);
	OP *op;
    SV *query = newSVpv(prefix, prefix_len);
    OP *op_vars = NULL;
    OP * args;

    parse(query, &op_vars);

    // PerlIO_printf(PerlIO_stderr(), "%s\n", SvPV_nolen(buf));
    args = Perl_prepend_elem(OP_LIST,
                newSVOP(OP_CONST, 0, newSVpvn("SQL::Embedded", sizeof("SQL::Embedded")-1)),
                newSVOP(OP_CONST, 0, query));
    if (op_vars) {
       args = Perl_prepend_elem(OP_LIST, args, op_vars);
    }
    op = newUNOP(
            OP_ENTERSUB,
            OPf_STACKED,
            Perl_append_elem(OP_LIST,
                args,
                newUNOP(OP_METHOD, 0,
                    newSVOP(OP_CONST, 0, newSVpvn_const("SQL::Embedded::_sql_prepare_exec")))));
    return op;
}

// -----------------------------------------------------
// hook code
#define MY_CHECK(x, func, meth) \
    if (keyword_len == sizeof(x)-1 && strnEQ(keyword_ptr, x, sizeof(x)-1) && hint_active(hintkey_sv)) { \
		*op_ptr = func(aTHX_ x " ", sizeof(x)-1+1, meth, sizeof(meth)-1); \
		return KEYWORD_PLUGIN_EXPR; \
    }
static int my_keyword_plugin(pTHX_
	char *keyword_ptr, STRLEN keyword_len, OP **op_ptr)
{
    MY_CHECK("SELECT",  do_parse_select, "SQL::Embedded::_run_select");
    MY_CHECK("EXEC",    do_parse_exec, "SQL::Embedded::_run_exec");
    MY_CHECK("INSERT",  do_parse_do, "SQL::Embedded::_run_do");
    MY_CHECK("UPDATE",  do_parse_do, "SQL::Embedded::_run_do");
    MY_CHECK("DELETE",  do_parse_do, "SQL::Embedded::_run_do");
    MY_CHECK("REPLACE", do_parse_do, "SQL::Embedded::_run_do");

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

