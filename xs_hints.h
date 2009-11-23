#ifndef XS_HINTS_H_
#define XS_HINTS_H_

/*
code taken from XS-APITest-KeywordRPN's.
*/

static int THX_hint_active(pTHX_ SV *hintkey_sv)
{
	HE *he;
	if(!GvHV(PL_hintgv)) return 0;
	he = hv_fetch_ent(GvHV(PL_hintgv), hintkey_sv, 0,
				SvSHARED_HASH(hintkey_sv));
	return he && SvTRUE(HeVAL(he));
}
#define hint_active(hintkey_sv) THX_hint_active(aTHX_ hintkey_sv)

static void THX_hint_enable(pTHX_ SV *hintkey_sv)
{
	SV *val_sv = newSViv(1);
	HE *he;
	PL_hints |= HINT_LOCALIZE_HH;
	gv_HVadd(PL_hintgv);
	he = hv_store_ent(GvHV(PL_hintgv),
		hintkey_sv, val_sv, SvSHARED_HASH(hintkey_sv));
	if(he) {
		SV *val = HeVAL(he);
		SvSETMAGIC(val);
	} else {
		SvREFCNT_dec(val_sv);
	}
}
#define hint_enable(hintkey_sv) THX_hint_enable(aTHX_ hintkey_sv)

static void THX_hint_disable(pTHX_ SV *hintkey_sv)
{
	if(GvHV(PL_hintgv)) {
		PL_hints |= HINT_LOCALIZE_HH;
		hv_delete_ent(GvHV(PL_hintgv),
			hintkey_sv, G_DISCARD, SvSHARED_HASH(hintkey_sv));
	}
}
#define hint_disable(hintkey_sv) THX_hint_disable(aTHX_ hintkey_sv)

#endif  // XS_HINTS_H_

