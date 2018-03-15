#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* inspired/stolen from Clone::Closure, to keep in sync with 5.13.3+ */
#ifndef CvGV_set
#define CvGV_set(cv,gv) CvGV(cv) = (gv)
#endif

MODULE = Class::MethodMaker PACKAGE = Class::MethodMaker

void
set_sub_name(SV *sub, char *pname, char *subname, char *stashname)
  CODE:
    CvGV_set((CV*)SvRV(sub), gv_fetchpv(stashname, TRUE, SVt_PV));
    GvSTASH(CvGV((GV*)SvRV(sub))) = gv_stashpv(pname, 1);
#ifdef gv_name_set
    gv_name_set(CvGV((GV*)SvRV(sub)), subname, strlen(subname), GV_NOTQUAL);
#else
    GvNAME(CvGV((GV*)SvRV(sub))) = savepv(subname);
    GvNAMELEN(CvGV((GV*)SvRV(sub))) = strlen(subname);
#endif
