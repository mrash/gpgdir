#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = Class::MethodMaker PACKAGE = Class::MethodMaker

void
set_sub_name(SV *sub, char *pname, char *subname, char *stashname)
  CODE:
    CvGV((GV*)SvRV(sub)) = gv_fetchpv(stashname, TRUE, SVt_PV);
    GvSTASH(CvGV((GV*)SvRV(sub))) = gv_stashpv(pname, 1);
    GvNAME(CvGV((GV*)SvRV(sub))) = savepv(subname);
    GvNAMELEN(CvGV((GV*)SvRV(sub))) = strlen(subname);
