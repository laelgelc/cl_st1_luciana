/* BEGINNING PART 1 */
/* === EDIT BELOW ====*/

/* account: CEPRIL */

%let project = group2_profiles ;

%let mainfolder = %scan(&project,1,_) ;

%let myfolder = &project ;

%let sasusername = u61738292 ;

%let whereisit = /home/&sasusername ;   /* online */

libname gelc "&whereisit/&myfolder";
/* files will NOT be saved to the folder above unless you put in 'gelc.'' before every destination */
/* otherwise files are going to the work library and not saved to the current folder */
/* this is needed to enable SGPLOT */
/* otherwise if your run SGPLOT, SAS will throw up an error message and stop working ... */

options fmtsearch=(work library);

/* enter number of factors to extract */
%let extractfactors = 7 ;

%let factorvars = fac1-fac&extractfactors ;

/* enter profiles variable names */
/* %let conversationvars = u000001-u021842 ; */

/* enter min loading cutoff */
%let minloading = .3 ;

/* enter min communality cutoff */
%let communalcutoff = .15 ;

DATA long1;
  INFILE "/home/u61738292/&myfolder/data.txt" ;
  length user $ 8 word $ 8 count 8 ;
  input user $ word $ count ;
RUN;

proc sort data= long1; by user; run;
    
proc transpose data=long1 out=observed ;
    by user ;
    id word ;
    var count;
run;

data observed (DROP= _NAME_) ; set observed; run;

/* end read in data file in long format */

/* turn missing to zeros  */

proc stdize data = observed out=observed reponly missing=0; run;

proc datasets library=work nolist;
delete 
temp long1 rot  ;
run;

/* pearson correlation input */
/* matrix generated in Python */

proc datasets library=work nolist; delete corr  ; run;

DATA corr;
  INFILE "/home/u61738292/&myfolder/corr.txt" ;
  length _TYPE_ $ 4 _NAME_ $ 8 v000001-v001000 8 ;
  input _TYPE_ $ _NAME_ $ v000001-v001000 ;
RUN;

/* turn missing correlation values to zeros */
proc stdize data = corr out=corr reponly missing=0; run;

data temp (DROP=_TYPE_); set corr; where _TYPE_="CORR" ; run;

PROC TRANSPOSE
DATA=temp (rename=_name_ = Name1)
OUT=temp2 (rename = (_name_ = Name2 col1=corr))
;
by name1;
var v000001-v001000;
RUN;

proc sort data=temp2 ; by corr ; run;
data neg ; set temp2 ; if corr < 0 ; if _N_ <=400 ; run;
proc sort data=temp2 ; by descending corr ; run;
data pos ; set temp2 ; if corr < 1 ; run;
data pos ; set pos ; if _N_ <= 400 ; run;
data temp3 (KEEP= Name1) ; set pos neg ; run ;
data temp4 ; set pos neg ; KEEP Name2; RENAME Name2=Name1 ; run ;
data temp5 ; set temp3 temp4 ; run;
proc sort data=temp5 out=selectedvars nodupkey; by Name1 ; run;

PROC EXPORT
  DATA= WORK.selectedvars
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/selectedvars.txt"
  REPLACE;
RUN;

/* tetrachoric correlation computation */

proc sql ;
    select Name1 into :names separated by ' ' from selectedvars ;
quit;

proc corr data = observed outplc = polychor polychoric noprint;
var &names ;
run;

proc stdize data = polychor out=polychor reponly missing=0; run;

/*
data GELC.polychor;
set  polychor;
run;

data WORK.polychor;
set  GELC.polychor;
run;
*/

PROC EXPORT
  DATA= WORK.polychor
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/polychor.tsv"
  REPLACE;
RUN;

/* number of observations IN THE DATA */
data _NULL_;
	if 0 then set observed nobs=n;
	call symputx('nobs',n);
	stop;
run;
%put nobs=&nobs ;

/* get variable list */

proc sql ;
    select Name1 into :names separated by ' ' from selectedvars ;
quit;

/* unrotated, before dropping low communalities */

proc datasets library=work nolist;
delete 
fout;
run;

ODS EXCLUDE NONE;
proc factor fuzz=0.3 data= polychor (type=corr) OUTSTAT= fout NOPRINT
method=principal 
plots=scree
mineigen=1
reorder 
heywood  
nfactors=100  
nobs=&nobs;  /* specify number of obs because this is missing from a corr matrix */
var &names  ;
run;

/* communalities ***/

data fout2;
    set fout (where=(_TYPE_="COMMUNAL"));
run;

proc transpose data=fout2 out=communal; id _TYPE_; run;

/* list vars to drop  */
proc sql ;
    select _name_ into :lowcomm separated by ' ' from communal
        where communal < &communalcutoff   ;
quit;

/* list vars to keep  */

proc sql NOPRINT;
    select _name_ into :highcomm separated by ' ' from communal
        where communal >= &communalcutoff   ;
quit;

/* save communalities to spreadsheet */

PROC SORT data=communal (keep= _name_ communal);   BY communal ; RUN;

PROC EXPORT
  DATA= WORK.communal
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/communalities.tsv"
  REPLACE;
RUN;

/* scree plot */

data fout2;
  set fout (where=(_TYPE_="EIGENVAL"));
run;

proc transpose data=fout2 out= fout3 (drop = _NAME_);
id _TYPE_;
run;

data fout4 ;
set fout3 ;
factor = _n_;
if factor <= 20 ;
run;

/* create the scree files */

ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="scree_1" imagefmt=png;
title "Scree plot";
proc sgplot data= fout4 ;
  series x=factor y=EIGENVAL / markers datalabel=EIGENVAL 
  markerattrs=(symbol = circle color = blue size = 10px);
   xaxis grid values=(1 TO 20) label='Factor';
   yaxis grid label='Eigenvalue';
   refline &extractfactors / axis = x lineattrs = (color = red pattern = dash);
run;
title;

ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="scree_2" imagefmt=png;
title "Scree plot";
proc sgplot data= fout4 ;
  series x=factor y=EIGENVAL / markers datalabel=factor
  markerattrs=(symbol = circle color = blue size = 10px);
  yaxis grid label='Eigenvalue';
  xaxis grid values=(1 TO 20) label='Factor';
  refline &extractfactors / axis = x lineattrs = (color = red pattern = dash);
run;
title;


/* rotated w/o low communalities */
/* do not use msa in factor analysis, it will give an error: 'matrix is singular' */

proc datasets library=work nolist;
delete 
rotatedfinal fout ;
run;

proc factor fuzz=0.3 data= polychor (type=corr) OUTSTAT= rotatedfinal NOPRINT
method=principal
mineigen=0
nfactors= &extractfactors
rotate=promax
heywood
nobs=&nobs;  /* specify number of obs because this is missing from a corr matrix */
var &highcomm  ;
run;


/* loadings table */

/*
 
https://stats.idre.ucla.edu/sas/output/factor-analysis/ 
Rotated Factor Pattern – This table contains the rotated factor loadings, which are the correlations between the variable and the factor.  Because these are correlations, possible values range from -1 to +1. 
in the outstat data file, the rotated factor pattern appears as PREROTAT. The standardized regression coefficients appear as PATTERN.
Use PREROTAT in the outstat data file. 

https://documentation.sas.com/?docsetId=statug&docsetTarget=statug_factor_details02.htm&docsetVersion=15.1&locale=en

PREROTAT: prerotated factor pattern.
PATTERN: factor pattern. (regression coefficients)

PREROTAT: prerotated factor pattern. =>   Stat.Factor.OrthRotFactPat
PATTERN: factor pattern. =>  Stat.Factor.ObliqueRotFactPat

*/

/*END PART 14*/
/* BEGINNING PART 15*/

/* labeling: https://stats.idre.ucla.edu/sas/modules/labeling/ */

/* 

run separately:

user_labels_format.sas
word_labels_format.sas

*/

%include "/home/u61738292/&myfolder/user_labels_format.sas";
%include "/home/u61738292/&myfolder/word_labels_format.sas";

OPTIONS VALIDVARNAME=ANY;
data rotated2;
  set rotatedfinal (where=(_TYPE_="PREROTAT"));
run;

proc transpose data=rotated2 out= rotated2 ;
id _NAME_ ;
run;

/* PRIMARY AND SECONDARY LOADINGS */

data abs ;
    set rotated2 ;
    array v Factor1-Factor&extractfactors  ;
    do over v ; 
      v = abs( v ) ; 
    end ;
run;

data primary (KEEP= _NAME_ load  );
set abs ;
 max=largest(1,of Factor1-Factor&extractfactors );
      if max = Factor1 AND max >= &minloading then do; load = 'fac1' ; end ;
 else if max = Factor2 AND max >= &minloading then do; load = 'fac2' ; end ;
 else if max = Factor3 AND max >= &minloading then do; load = 'fac3' ; end ;
 else if max = Factor4 AND max >= &minloading then do; load = 'fac4' ; end ;
 else if max = Factor5 AND max >= &minloading then do; load = 'fac5' ; end ;
 else if max = Factor6 AND max >= &minloading then do; load = 'fac6' ; end ;
 else if max = Factor7 AND max >= &minloading then do; load = 'fac7' ; end ;
 else if max = Factor8 AND max >= &minloading then do; load = 'fac8' ; end ;
 else if max = Factor9 AND max >= &minloading then do; load = 'fac9' ; end ;
 else if max = Factor10 AND max >= &minloading then do; load = 'fac10' ; end ;
run;

data secondary (KEEP= _NAME_ load secondary );
set abs ;
 max=largest(2,of Factor1-Factor&extractfactors );
      if max = Factor1 AND max >= &minloading then do; load = 'fac1' ; secondary = 1 ; end ;
 else if max = Factor2 AND max >= &minloading then do; load = 'fac2' ; secondary = 1 ; end ;
 else if max = Factor3 AND max >= &minloading then do; load = 'fac3' ; secondary = 1 ; end ;
 else if max = Factor4 AND max >= &minloading then do; load = 'fac4' ; secondary = 1 ; end ;
 else if max = Factor5 AND max >= &minloading then do; load = 'fac5' ; secondary = 1 ; end ;
 else if max = Factor6 AND max >= &minloading then do; load = 'fac6' ; secondary = 1 ; end ;
 else if max = Factor7 AND max >= &minloading then do; load = 'fac7' ; secondary = 1 ; end ;
 else if max = Factor8 AND max >= &minloading then do; load = 'fac8' ; secondary = 1 ; end ;
 else if max = Factor9 AND max >= &minloading then do; load = 'fac9' ; secondary = 1 ; end ;
 else if max = Factor10 AND max >= &minloading then do; load = 'fac10' ; secondary = 1 ; end ;
run;

proc sort data=rotated2 ; by _NAME_ ; run;
proc sort data=primary ; by _NAME_ ; run;
proc sort data=secondary ; by _NAME_ ; run;

data temp1 ;
merge rotated2 primary ;
by _NAME_ ;
run;

data temp2 ;
merge rotated2 secondary ;
by _NAME_ ;
run;

data temp3;
set temp2 temp1;
run;

/* loadtable with primary and secondary loadings */

ods html file="&whereisit/&myfolder/loadtable.html"; 
%macro create(howmany);
%do i=1 %to &howmany;

title "LOADINGS TABLE";
title2 "Factor &i pos" ;
data temp4;
  set temp3 ;
  where load= "fac&i" and Factor&i >= 0  ;
  if secondary = 1 then do; l = '(' ; r = ')' ; end; 
proc sort;
  by descending Factor&i ;
proc print ; FORMAT _NAME_ $profilelexlabels.; var l _NAME_ Factor&i r ;
run;

title "Factor &i neg" ;
data temp4;
  set temp3 ;
  where load= "fac&i" and Factor&i < 0  ;
  if secondary = 1 then do; l = '(' ; r = ')' ; end; 
proc sort;
  by  Factor&i ;
proc print ; FORMAT _NAME_ $profilelexlabels.; var l _NAME_ Factor&i r ;
run;

%end;
%mend create;
%create(&extractfactors) 
ods html close;
quit;

PROC EXPORT
  DATA= work.temp3
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/rotated.tsv"
  REPLACE;
RUN;

/* factor scores */
/* no standardizing the data because it is ranked */

/* the vars are all listed in a single column, so no need to rotate */

proc datasets library=work nolist;
delete 
fout fout2 fout3 fout4 ;
run;

%macro create(howmany);
%do i=1 %to &howmany;

data fac&i.p;
  set temp3 ;
  where load= "fac&i" and Factor&i >= 0  ;
  pole = 1;
run;

data fac&i.n;
  set temp3 ;
  where load= "fac&i" and Factor&i < 0  ;
  pole = -1;
run;

%end;
%mend create;
%create(&extractfactors) 
quit;

proc sql NOPRINT;
    select memname into :names separated by ' ' from dictionary.tables 
    where libname = 'WORK' AND  memname like "FAC%"  ;
quit;

/* discard variables loading as secondary to compute factor scores */
data poles ;
set &names ;
if secondary NE 1;
run;

proc transpose data=poles out=score;
  by load ;
  id _NAME_ ;
  var pole;
run;

data score;
  _type_='SCORE';
  set score;
  drop _name_;
  rename load=_name_;
run;

/* checking */
/*
proc print data=score; var _name_ v000025 v000076 v000319 ; 
run;
*/

proc score data=observed score=score out=scores; run;

data scores_only 
(keep =  user &factorvars ) ; 
set scores ; 
run;

PROC EXPORT
  DATA= WORK.scores
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/&project._scores.tsv"
  REPLACE;
RUN;

PROC EXPORT
  DATA= WORK.scores_only
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/&project._scores_only.tsv"
  REPLACE;
RUN;

/* metadata */

DATA likesreplies;
  INFILE "/home/&sasusername/&myfolder/replies_likes.txt"  ;
  length user $ 8 replies 8 likes 8 ;
  input user $ replies likes ;
  proc sort; by user ;
RUN;

/* data is in the main group_sas folder, not in the profiles sas folder */
DATA followers;
  INFILE "/home/&sasusername/&mainfolder/followers.txt"  ;
  length user $ 8 followers 8 ;
  input user $ followers ;
  proc sort; by user ;
RUN;

data popularity;
merge likesreplies (in=a) followers (in=b) ;
by user;
run;

proc rank data = popularity groups = 10 out = popularity_ranked ties=dense ; 
var replies likes followers ; 
ranks replies_rank likes_rank followers_rank ;
run;

data popularity_ranked  ;
    set popularity_ranked ;
    array v replies_rank  ;
    do over v ; 
      v = v + 1  ; 
    end ;
    array x likes_rank  ;
    do over x ; 
      x = x + 1  ; 
    end ;    
    array y followers_rank  ;
    do over y ; 
      y = y + 1  ; 
    end ;    
run;

ods html file="&whereisit/&myfolder/popularity_ranks.html"; 
proc means data=popularity_ranked min max n mean  ; 
var replies ;
class replies_rank; 
run;
proc means data=popularity_ranked min max n mean  ; 
var likes ;
class likes_rank; 
run;
proc means data=popularity_ranked min max n mean  ; 
var followers ;
class followers_rank; 
run;
ods html close;

DATA wcount;
  INFILE "/home/&sasusername/&myfolder/wcount.txt"  ;
  length user $ 8 wcount 8 ;
  input user $ wcount ;
  proc sort; by user ;
RUN;

data metadata ;
merge popularity_ranked (in=a) wcount (in=b);
by user;
if wcount = . then wcount = 0;
run;

ods html file="&whereisit/&myfolder/corr_popularity_wcount.html"; 
proc corr data=metadata;
var replies likes followers ;
with wcount ;
run;
ods html close;


/* 
N of users here will be less here than in the main MD analysis, because only users w/ descriptions are included 
here, but in the main MD analysis, all users are included, regardless of whether they have profile texts or not
*/

data scores_metadata ;
merge scores_only (in=a) metadata (in=b) ;
by user;
if (a and b) then output;
run;

data temp;
merge scores_only(in=a) wcount (in=b) ;
by user;
if (a and b) then output ;
run;

/* correlation with metadata */

ods html file="&whereisit/&myfolder/profiles_metadata_correlations.html"; 
proc corr data= scores_metadata ;
var &factorvars ;
with likes replies followers ;
run;
ods html close;

/* GLM Analysis of variance */

/* begin macro */
ods html file="&whereisit/&myfolder/glm_meta.html"; 
%macro create(howmany);
%do i=1 %to &howmany;
ods graphics off; 
%macro repeat_glm(var=);
proc glm data=scores_metadata;
	title GLM for dataset = &project user &var f&i ;
	class &var ;
	model fac&i = &var ;
	means &var ;
ods table FitStatistics=rsq_&var._fac&i;
/*ods table Means=means_&var._fac&i;*/
run;
ods trace off;
%mend repeat_glm;
%repeat_glm(var=followers_rank)
%repeat_glm(var=replies_rank)
%repeat_glm(var=likes_rank)
ods graphics on;
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
ods html close; 
quit;
/* end macro */

/* mean dimension scores bar charts */
/* https://blogs.sas.com/content/graphicallyspeaking/2016/11/27/getting-started-sgplot-part-2-vbar/ */

/* begin macro */
%macro create(howmany);
%do i=1 %to &howmany;
%macro repeat_do(var=);
proc sql noprint;
    select rsquare into :names separated by ' ' from rsq_&var._fac&i ;
quit;
data temp;
set rsq_&var._fac&i ;
Percent = RSquare * 100;
run;
proc sql noprint;
    select percent into :perc separated by ' ' from temp ;
quit;

ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="&var._dim_&i" imagefmt=png;
proc sgplot data=scores_metadata;
  vbar &var / response=fac&i stat=mean 
            barwidth=0.6
            fillattrs=graphdata4 limits=both 
            baselineattrs=(thickness=1 color=red) 
            datalabel = fac&i ;
  title height=12pt "Mean scores dim. &i (%qscan(&var,1,_))";
  yaxis label= "Mean dimension &i score" ;
  xaxis label= 'Ranks';
  INSET  ( "R(*ESC*){sup '2'}" = "&names" "%" = "&perc" ) / BORDER TEXTATTRS = (SIZE=10 COLOR=black);
run;
%mend repeat_do;
%repeat_do(var=followers_rank)
%repeat_do(var=replies_rank)
%repeat_do(var=likes_rank)
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
quit;
/* end macro */

/* mean dimension scores box plots */
/* https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.4/statug/statug_odsgraph_sect013.htm */

/* begin macro */
%macro create(howmany);
%do i=1 %to &howmany;
%macro repeat_do(var=);
proc sql noprint;
    select rsquare into :names separated by ' ' from rsq_&var._fac&i ;
quit;
data temp;
set rsq_&var._fac&i ;
Percent = RSquare * 100;
run;
proc sql noprint;
    select percent into :perc separated by ' ' from temp ;
quit;
ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="&var._boxplot_dim_&i" imagefmt=png;
title "Dimension &i scores (%qscan(&var,1,_))" ;
proc sgplot data=scores_metadata noautolegend;
   vbox fac&i / category=&var connect=mean connectattrs=(color=black pattern=mediumdash thickness=1)
                                                    meanattrs=(symbol=plus color=red size=20)
                                                    lineattrs=(color=black)
                                                    medianattrs=(color=black)
                                                    whiskerattrs=(color=black)
                                                    outlierattrs=(color=black symbol=circle size=6);
   xaxis label='Ranks' display=(noline noticks );
   yaxis label="Dimension &i score" display=(noline noticks) ;
   INSET  ( "R(*ESC*){sup '2'}" = "&names" "%" = "&perc" ) / BORDER TEXTATTRS = (SIZE=10 COLOR=black);
run;
title;
%mend repeat_do;
%repeat_do(var=followers_rank)
%repeat_do(var=replies_rank)
%repeat_do(var=likes_rank)
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
quit;
/* end macro */

/* corpus size */

/* begin macro */
ods html file="&whereisit/&myfolder/corpus_size.html"; 
title "User profile corpus size ";
ods output summary = size;
proc means data = scores_metadata n sum mean std ; 
var wcount; 
run;
proc means data = scores_metadata n sum mean std ; 
var wcount; 
class followers_rank ;
run;
proc means data = scores_metadata n sum mean std ; 
var wcount; 
class likes_rank ;
run;
proc means data = scores_metadata n sum mean std ; 
var wcount; 
class replies_rank ;
run;
ods html close;
/* end macro */

proc transpose data= size out=rot; run;

data temp (DROP= _NAME_); 
  set rot ; 
  IF _label_ = 'N' OR _label_ = 'Sum'; 
  if _label_ = "N" then pretty="Texts";
      else pretty="Words";
run;

data plotvalue;
  set temp;
  if _LABEL_ = 'Sum' then gridvalue = ceil(COL1/10000)*10000;
run;
proc sql noprint;
    select max into :max separated by ' ' from plotvalue ;
quit;
data plotvalue;
  set temp;
  if _LABEL_ = 'N' then gridvalue = 10000 + ceil(COL1/10000)*10000;
run;
proc sql noprint;
    select min into :min separated by ' ' from plotvalue ;
quit;

ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="corpus_size_profiles" imagefmt=png;
proc sgplot data=temp ;
  vbar pretty / response=COL1 
            barwidth=0.5
            fillattrs=graphdata4 
            baselineattrs=(thickness=0) 
            datalabel = COL1 datalabelattrs=(size=12) ;
  title height=12pt "Corpus size";
  yaxis grid label='Count' values=(0 TO &max BY 5000) ranges=(min-&min 360000-max);
  xaxis label= "Measurement";
run;

  yaxis grid label='Count' values=(0 TO 380000 BY 5000) ranges=(min-40000 360000-max);

/* R-Square table */

ods html file="&whereisit/&myfolder/rsquare.html"; 

%let first = %scan(&factorvars, 1, '-');
%let last = %scan(&factorvars, 2, '-');

%macro repeat_do(var=);
data temp (KEEP= Factor RSquare Percent);
retain Factor RSquare Percent;
set &var._&first.-&var._&last ;
Factor = substr(Dependent, 4, 1);
Percent = RSquare * 100;
run;

title "&var" ;
proc print data= temp NOOBS; format RSquare 8.3 ; run;
title ;

%mend repeat_do;
%repeat_do(var=rsq_followers_rank)
%repeat_do(var=rsq_replies_rank)
%repeat_do(var=rsq_likes_rank)
ods html close;
quit;

/**** ZIP UP THE FILES INTO zip/<this folder>.zip ****/
/* list all files in your directory */


data filelist;
run;
data filelist;
  length root dname $ 2048 filename $ 256 dir level 8;
  input root;
  retain filename dname ' ' level 0 dir 1;
cards4;
/home/u61738292/group2_profiles
;;;;
run;

data filelist;
  modify filelist;
  rc1=filename('tmp',catx('/',root,dname,filename));
  rc2=dopen('tmp');
  dir = 1 & rc2;
  if dir then 
    do;
      dname=catx('/',dname,filename);
      filename=' ';
    end;
  replace;

  if dir;

  level=level+1;

  do i=1 to dnum(rc2);
    filename=dread(rc2,i);
    output;
  end;
  rc3=dclose(rc2);
run;

proc sort data=filelist;
  by root dname filename;
run;

/* print out files list too see if you have all you want */
proc print data=filelist;
run;

/* name the zip file you want to zip into, e.g. */
%let addcntzip = /home/u61738292/zip/output_&project..zip;

data _null_;

  set filelist; /* loop over all files */
  if dir=0;

  rc1=filename("in" , catx('/',root,dname,filename), "disk", "lrecl=1 recfm=n");
  rc1txt=sysmsg();
  rc2=filename("out", "&addcntzip.", "ZIP", "lrecl=1 recfm=n member='" !! catx('/',dname,filename) !! "'");
  rc2txt=sysmsg();

  do _N_ = 1 to 6; /* push into the zip...*/
    rc3=fcopy("in","out");
    rc3txt=sysmsg();
    if fexist("out") then leave; /* if success leave the loop */
    else sleeprc=sleep(0.5,1); /* if fail wait half a second and retry (up to 6 times) */
  end;

  rc4=fexist("out");
  rc4txt=sysmsg();

/* just to see errors */
  put _N_ @12 (rc:) (=);

run;

/* delete all png, html and tsv files, because they've been zipped */

/* Read files in a folder */

%let path=&whereisit/&myfolder;
FILENAME _folder_ "%bquote(&path.)";
data filenames(keep=memname);
  handle=dopen( '_folder_' );
  if handle > 0 then do;
    count=dnum(handle);
    do i=1 to count;
      memname=dread(handle,i);
      if scan(memname, 2, '.')='png' 
      OR scan(memname, 2, '.')='html' 
      OR scan(memname, 2, '.')='tsv' 
      then output filenames;
    end;
  end;
  rc=dclose(handle);
run;
filename _folder_ clear;

/* delete files identified in above step */
data _null_;
set filenames;
fname = 'todelete';
rc = filename(fname, quote(cats("&path",'/',memname)));
rc = fdelete(fname);
rc = filename(fname);
run;



