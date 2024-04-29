options fmtsearch=(fmtlib) mprint mtrace symbolgen obs=max;
%let program = P01;
libname out "\\fed-ad.ufl.edu\T001\user\mydocs\jiang.shao\Desktop\hedis_dev\out";
libname ST "K:\TX-Data\Datasets\STAR";


/* Insert the HEDIS value set */ 
libname valueset "E:\jiang.shao\HEDIS_measure_develop\Doc";

data hedis_value_set_fum; 
	set valueset.merged_codes_hedis_my2022;
	where Measure_ID = 'FUM' AND 
		  Code_System NE 'SNOMED CT US Edition';
run;

proc freq data=hedis_value_set_fum; 
	tables Code_System;
run;

/* Step 1: Find dataset, use nondual enrollment and encounter data */

/* Enrollment */ 

data star_enr_22; 
	set ST.star_enr_nodual_cy2022 (keep=membno bthdat sexcod plancod program qsi_race qsi_ethnicity v21_race v21_ethnicity county_cd C2: ); 
run;


data star_enc_22; 
	set ST.star_enc_cy2022 (keep=membno bdate plancod dschstat dfrdos dtodos diagn1-diagn25 surg1-surg25 typbill transtype svccod revcod poscod); 
run;


/*%macro condi(prg,prgL);*/
/*Data ED_enc;*/
/*set star_enc_22;*/
/*where svccod in (&A_DME.) and membno not in ('' '000000000');*/
/*ED_enc = 1;*/
/*run;*/
/**/
/*proc sort data=ED_enc nodupkey out=&prg._ED_enc(keep=membno ED_enc);*/
/*by membno;*/
/*run;*/
/**/
/**/
/*proc sort data=star_enc_22 nodupkey */
/*	out=star_diagn_2022;*/
/*by membno clmno plancod;*/
/*run;*/
/**/
/**/
/*Data star_diagn_2022;*/
/*set star_diagn_2022;*/
/*array D(*) diagn1-diagn25;*/
/*do i=1 to dim(D) while ( D(i)^='');*/
/*	if d(i) in: (&A_Cancer) or d(i) in:(&A_heart) or d(i) in:(&A_renal) or d(i) in:(&A_stroke)*/
/*	or d(i) in:(&A_alzheimer) or d(i) in:(&A_cirrhosis) or d(i) in:(&A_frailty)*/
/*	or d(i) in:(&A_lung_failure) or d(i) in:(&A_neurodegenerative) or d(i)in (&A_hiv_aids)*/
/*	then adult_con=1;*/
/*	if d(i) in:(&A_diabetes_w_complications) then diabete=1;*/
/*	if d(i) in:(&A_diabetes_severe_complications) then comorbid=1;*/
/*	if d(i) in: (&P_neuro) or d(i) in:(&P_cardio) or d(i) in:(&P_resp) */
/*	or d(i) in: (&P_renal) or d(i) in:(&P_gastro) or d(i) in:(&P_hemo)*/
/*	or d(i) in: (&P_metab) or d(i) in:(&P_congen) or d(i) in:(&P_maligcy)*/
/*	or d(i) in: (&P_premature) or  d(i) in:(&P_misc) */
/*	then ped_con=1;*/
/*end;*/
/**/
/*run;*/
/*proc summary data=&prg._diag_20&yr.;*/
/*var adult_con diabete comorbid ped_con;*/
/*class membno;*/
/*output out=member_level_&yr. max=;*/
/*run;*/
/**/
/*proc sort data=member_level_&yr.;*/
/*where membno ^='' and (adult_con=1 or ped_con=1 or diabete=1 or comorbid=1  );*/
/*by membno;*/
/*run;*/
/**/
/*data temp.&prg._member_condition_&yr.;*/
/*merge member_level_&yr.(in=in1) &prg._DME;*/
/*by membno;*/
/*if (diabete=1 and comorbid=1) or DME=1 then adult_con=1;*/
/**/
/*if adult_con=1 or ped_con=1;*/
/*run;*/
/**/
/*%mend condi;*/


/* --------------- */ 
proc sql; 
	create table STAR_enc_filtered as 
	select a.*
	from star_enc_22 as a
	inner join hedis_value_set_fum as b









/* ---------------------- */ 
libname fmtlib "K:\IS-Resources\Resources\SAS Resources\TEXAS\FormatLib";
OPTIONS PS=MAX FORMCHAR="|----|+|---+=|-/\<>*" MPRINT fmtsearch=(fmtlib);

libname ST "K:\TX-Data\Datasets\STAR";
libname FFS "K:\TX-Data\Datasets\FFS";
libname prg "K:\TX-Data\Datasets\Medicaid";
libname VS "K:\TX-Data\Datasets\HEDIS\HEDIS VALUE SET\HEDIS MY2022\data\final";
libname temp "\\fed-ad.ufl.edu\T001\user\mydocs\jiang.shao\Desktop\hedis_dev\out";


* global parameters;
%let year = 2022;
%let ED_start_date = %sysfunc(mdy(1, 1, &year));
%let ED_end_date = %sysfunc(mdy(12, 1, &year));


* Step 1: Create the value sets to identify all needed rows by code_system----------------------------------------------------------------------------------------------------------------------------------------- ;
data _10_VS_FUM;
    set VS.merged_codes_hedis_my2022;
    where Measure_ID = "FUM" and Code_System NE "SNOMED CT US Edition";
    * standardize code;
    code = compress(upcase(code), ' .');
    * replace space with _ in code_system;
    code_system2 = tranwrd(trim(left(code_system)), " ", "_");
    if code_system2 in ("CPT", "HCPCS") then code_system2 = "CPT_HCPCS";
    * limit the length of value_set_name to 15;
    length value_set_name2 $ 15;
    value_set_name2 = '';
    do i = 1 to countw(value_set_name, " ");
        _text = scan(value_set_name, i, " ");
        value_set_name2 = compress(catx('', value_set_name2, substr(_text, 1, min(3, length(_text)))), ' ');
    end;
run;

* check if value_set_name2 is valid;
%macro check_value_set_name2;
    title2 "Check if value_set_name2 is valid";
    proc sql;
        select case when count(distinct value_set_name) = count(distinct value_set_name2) then "Yes" else "No" end as value_set_name2_valid 
            into: value_set_name2_valid
        from _10_VS_FUM;
    quit;

    * if value_set_name2 is not valid, raise an error;
    %if &value_set_name2_valid = No %then %do;
        %put ERROR: value_set_name2 is not valid;
        %abort cancel;
    %end;
    title2;
%mend check_value_set_name2;
%check_value_set_name2;

title2 "Print out the value_set_name2 and code_system2";
proc freq data=_10_VS_FUM;
    table value_set_name * value_set_name2 * code_system2 /list nocum nopercent;
    table code_system2 /nocum nopercent;
run;
title2;

*** macro to split codes by code_system;
%macro split_codes_by_code_system;
    proc sql noprint;
        select distinct code_system2 into: code_system_list separated by "|"
        from _10_VS_FUM
        ;
    quit;

    %do %while (%length(&code_system_list) > 0);
        %let code_system = %scan(&code_system_list, 1, "|");
        %put &code_system;
        proc sql;
            create table _11_VS_CS_&code_system as
            select distinct code
            from _10_VS_FUM
            where code_system2 = "&code_system";
        quit;

        * if "|" is found in the list, remove the first code_system from the list;
        %if %index(&code_system_list, %str(|)) > 0 %then %do;
            %let code_system_list = %qsubstr(&code_system_list, %eval(%length(&code_system) + 2));
        %end;
        %else %do;
            * if "|" is not found in the list, set the list to empty, to end the loop;
            %let code_system_list = ;
        %end;
    %end;
%mend split_codes_by_code_system;
%split_codes_by_code_system;

** create a dataset for descead code;
data _11_VS_DECEASED_Discharge;
    input code $;
    datalines;
20
40
41
42
;
run;

* Step 2: extract all the needed encounter data ----------------------------------------------------------------------------------------------------------------------------------------- ;
** subset prg200 data to STAR encounter only;
data _21_prg200_STAR_enc;
    set prg.prg200_enc_cy&year.;
    where put(plancod, $PROGNAME.) = "STAR";
run;

%let keep_vars_1 = membno dfrdos dtodos diagn1-diagn25 surg1-surg25 typbill transtype svccod revcod poscod 
    dschstat plancod b_NPI clmstat d_clmstat;

data _22_STAR_enc_all;
    if _N_ = 1 then do;
        if 0 then set 
            _11_VS_CS_CPT_HCPCS
            _11_VS_CS_ICD10CM
            _11_VS_CS_ICD10PCS
            _11_VS_CS_POS
            _11_VS_CS_UBREV
            _11_VS_DECEASED_Discharge
            ;
            
        declare hash h_cpt_hcpcs(dataset: "_11_VS_CS_CPT_HCPCS");
        h_cpt_hcpcs.definekey("code");
        h_cpt_hcpcs.definedone();
        
        declare hash h_icd10cm(dataset: "_11_VS_CS_ICD10CM");
        h_icd10cm.definekey("code");
        h_icd10cm.definedone();
        
        declare hash h_icd10pcs(dataset: "_11_VS_CS_ICD10PCS");
        h_icd10pcs.definekey("code");
        h_icd10pcs.definedone();
        
        declare hash h_pos(dataset: "_11_VS_CS_POS");
        h_pos.definekey("code");
        h_pos.definedone();
        
        declare hash h_ubrev(dataset: "_11_VS_CS_UBREV");
        h_ubrev.definekey("code");
        h_ubrev.definedone();
        
        declare hash h_deceased_discharge(dataset: "_11_VS_DECEASED_Discharge");
        h_deceased_discharge.definekey("code");
        h_deceased_discharge.definedone();
    end;
        
    set ST.STAR_enc_cy&year.(keep=&keep_vars_1.)
        _21_prg200_STAR_enc(keep=&keep_vars_1.);
    
    * standardize code;
    svccod = strip(svccod);
    revcod = strip(revcod);
    poscod = strip(poscod);
    dschstat = strip(dschstat);
    
    * icd diagnosis;
    flag_icd10cm = 0;
    array diagns[25] diagn1-diagn25;
    do i = 1 to 25;
        if diagns[i] = "" then leave;
        dx = compress(upcase(diagns[i]), '. ');
        if h_icd10cm.find(key: dx) = 0 then do;
            flag_icd10cm = 1;
            leave;
        end;
    end;

    * icd pcs;
    flag_icd10pcs = 0;
    array surgs[25] surg1-surg25;
    do i = 1 to 25;
        if surgs[i] = "" then leave;
        px = compress(upcase(surgs[i]), '. ');
        if h_icd10pcs.find(key: px) = 0 then do;
            flag_icd10pcs = 1;
            leave;
        end;
    end;

    * cpt and hcpcs;
    flag_cpt_hcpcs = 0;
    if h_cpt_hcpcs.find(key: svccod) = 0 then flag_cpt_hcpcs = 1;

    * pos;
    flag_pos = 0;
    if h_pos.find(key: poscod) = 0 then flag_pos = 1;

    * ubrev;
    flag_ubrev = 0;
    if h_ubrev.find(key: revcod) = 0 then flag_ubrev = 1;

    * deceased discharge;
    flag_EX_deceased_discharge = 0;
    if h_deceased_discharge.find(key: dschstat) = 0 then flag_EX_deceased_discharge = 1;

    * output;
    if flag_icd10cm = 1 
        or flag_icd10pcs = 1 
        or flag_cpt_hcpcs = 1 
        or flag_pos = 1 
        or flag_ubrev = 1 
        or flag_EX_deceased_discharge = 1 
        then output;

    drop i dx px code;

    format dfrdos dtodos YYMMDD10.;
run;

proc sort data=_22_STAR_enc_all nodupkey;
    by _all_;
run;

proc freq data=_22_STAR_enc_all;
    table flag_icd10cm flag_icd10pcs flag_cpt_hcpcs flag_pos flag_ubrev flag_EX_deceased_discharge;
run;

*** output temp data;
data temp.FUM_V02_22_STAR_enc_all;
    set _22_STAR_enc_all;
run;

* remove all dataset like _11_VS_CS_* from work library;
proc datasets lib=work nolist;
    delete _11_VS_CS_:;
quit;


* Step 3: create value set for each entity ----------------------------------------------------------------------------------------------------------------------------------------- ;
*** macro to split codes by Value_Set_name and code_system;
%macro split_codes_by_name_by_CS;
    ** create a list of value_set_name2;
    proc sql noprint;
        select distinct value_set_name2 into: enc_value_set_list separated by "|"
        from _10_VS_FUM
        ;
    quit;

    %do %while (%length(&enc_value_set_list) > 0);
        %let enc_value_set = %scan(&enc_value_set_list, 1, "|");
        proc sql noprint;
            select distinct code_system2 into: code_system_list separated by "|"
            from _10_VS_FUM
            where value_set_name2 = "&enc_value_set" and code_system2 not in ('SNOMED_CT_US_Edition', 'CDC_Race_and_Ethnicity');
        quit;
        %do %while (%length(&code_system_list) > 0);
            %let code_system = %scan(&code_system_list, 1, "|");
            %put _31_VS_&enc_value_set._&code_system;
            proc sql noprint;
                create table _31_VS_&enc_value_set._&code_system as
                select distinct code
                from _10_VS_FUM
                where value_set_name2 = "&enc_value_set" and code_system2 = "&code_system";
            quit;

            %if %index(&code_system_list, %str(|)) > 0 %then %do;
                %let code_system_list = %qsubstr(&code_system_list, %eval(%length(&code_system) + 2));
            %end;
            %else %do;
                %let code_system_list = ;
            %end;
        %end;
        %if %index(&enc_value_set_list, %str(|)) > 0 %then %do;
            %let enc_value_set_list = %qsubstr(&enc_value_set_list, %eval(%length(&enc_value_set) + 2));
        %end;
        %else %do;
            %let enc_value_set_list = ;
        %end;
    %end;
%mend split_codes_by_name_by_CS;
%split_codes_by_name_by_CS;

* print out the datasets name;
proc sql;
    select memname
    from dictionary.tables
    where libname = "WORK" and upcase(memname) like "_31_VS_%"
    order by memname;
quit;


* Step 4: extract all ED visits with a principal diagnosis of mental illness ------------------------------------------------------------------------- ;
data _41_STAR_ED_enc_all;
    if _N_ = 1 then do;
        if 0 then set 
            _31_VS_ED_CPT_HCPCS
            _31_VS_ED_UBREV
            _31_VS_MenIll_ICD10CM
            _31_VS_INTSEL_ICD10CM
            ;
            
        declare hash h_ED_CPT_HCPCS(dataset: "_31_VS_ED_CPT_HCPCS");
        h_ED_CPT_HCPCS.defineKey("code");
        h_ED_CPT_HCPCS.defineDone();
        
        declare hash h_ED_UBREV(dataset: "_31_VS_ED_UBREV");
        h_ED_UBREV.defineKey("code");
        h_ED_UBREV.defineDone();
        
        declare hash h_MenIll_ICD10CM(dataset: "_31_VS_MenIll_ICD10CM");
        h_MenIll_ICD10CM.defineKey("code");
        h_MenIll_ICD10CM.defineDone();

        declare hash h_INTSEL_ICD10CM(dataset: "_31_VS_INTSEL_ICD10CM");
        h_INTSEL_ICD10CM.defineKey("code");
        h_INTSEL_ICD10CM.defineDone();
    end;
    
    *** !!! make sure the flags here align with the key in the hash table !!!;
    set _22_STAR_enc_all(where=((&ED_start_date <= dfrdos <= &ED_end_date) and (flag_icd10cm = 1 or flag_cpt_hcpcs = 1 or flag_ubrev = 1))); 
        
    * pincipal diagnosis of mental illness or intentional self-harm;
    pdx = compress(upcase(diagn1), ' .');
    flag_MH = 0;
    if h_MenIll_ICD10CM.find(key: pdx) = 0 or h_INTSEL_ICD10CM.find(key: pdx) = 0 then flag_MH = 1;

    * ED visits;
    flag_ED = 0;
    if h_ED_CPT_HCPCS.find(key: svccod) = 0 or h_ED_UBREV.find(key: revcod) = 0 then flag_ED = 1;

    * output ED visits with a principal diagnosis of mental illness or intentional self-harm;
    if flag_MH = 1 and flag_ED = 1 then output;

    drop pdx code;
run;

proc sql;
    title2 "Number of ED visits in _41_STAR_ED_enc_all";
    select count(*) as ED_visits
    from (select distinct membno, dfrdos from test._41_STAR_ED_enc_all);
    title2;
quit;

* proc sql;
*     create table SQL_STAR_ED_enc_all as
*     select distinct a.membno
*         ,a.dfrdos
*         ,a.dtodos
*         ,(case when b.code is not null or c.code is not null then 1 else 0 end) as flag_MH
*         ,(case when d.code is not null then 1 else 0 end) as flag_ED_CPT_HCPCS
*         ,(case when e.code is not null then 1 else 0 end) as flag_ED_UBREV
*     from ST.STAR_enc_cy2022 as a
*     left join _31_VS_MenIll_ICD10CM as b on compress(upcase(a.diagn1), ' .') = b.code
*     left join _31_VS_INTSEL_ICD10CM as c on compress(upcase(a.diagn1), ' .') = c.code
*     left join _31_VS_ED_CPT_HCPCS as d on a.svccod = d.code
*     left join _31_VS_ED_UBREV as e on a.revcod = e.code
*     where (&ED_start_date <= a.dfrdos <= &ED_end_date)
*       and ((b.code is not null or c.code is not null) and (d.code is not null or e.code is not null));
* quit;


* Step 5: Exclude ED visits followed by inpatient admission ----------------------------------------------------------------------------------------------------------------------------------------- ;
data _51_STAR_INP_STAY;
    if _N_ = 1 then do;
        if 0 then set _31_VS_InpSta_UBREV;
        
        declare hash h_InpatientStay_UBREV(dataset: "_31_VS_InpSta_UBREV");
        h_InpatientStay_UBREV.defineKey("code");
        h_InpatientStay_UBREV.defineDone();
    end;

    set _22_STAR_enc_all(where=(flag_ubrev = 1));
        
    * inpatient admission;
    if h_InpatientStay_UBREV.find(key: revcod) = 0 then do;
        flag_INP_STAY = 1;
        INP_STAY_Admit_Date = dfrdos;
        INP_STAY_Discharge_Date = dtodos;
        output;
    end;

    keep membno flag_INP_STAY INP_STAY_Admit_Date INP_STAY_Discharge_Date;
run;

proc freq data=test._22_STAR_enc_all; 
tables revcod; 
run;

** option: ED_Discharge_Date vs ED_Admit_Date, INP_STAY_Admit_Date vs INP_STAY_Discharge_Date;
proc sql;
    create table _52_STAR_ED_no_INP as
    select a.*
    from _41_STAR_ED_enc_all as a
        left join _51_STAR_INP_STAY as b
        on a.membno = b.membno
        and a.dfrdos <= b.INP_STAY_Admit_Date <= intnx('day', a.dtodos, 30)
    where b.flag_INP_STAY ne 1 or b.INP_STAY_Admit_Date = .
    order by a.membno, a.dfrdos;
quit;

proc sql;
    title2 "Number of ED visits in _52_STAR_ED_no_INP";
    select count(*) as ED_visits
    from (select distinct membno, dfrdos from test._52_STAR_ED_no_INP);
    title2;
quit;


* Step 6: Deal with multiple ED visit in a 31-day period ----------------------------------------------------------------------------------------------------------------------------------------- ;
data _61_STAR_ED_enc_first_31d;
    set _52_STAR_ED_no_INP;
    by membno;
    if first.membno then do;
        ED_Admit_Date = dfrdos;
        prev_ED_Admit_date = dfrdos;
        ED_Discharge_Date = dtodos;
        output;
    end;
    else do;
        ** option: ED_Discharge_Date vs ED_Admit_Date;
        if dfrdos - prev_ED_Admit_date > 31 then do;
            ED_Admit_Date = dfrdos;
            prev_ED_Admit_date = dfrdos;
            ED_Discharge_Date = dtodos;
            output;
        end;
    end;
    keep membno ED_Admit_Date ED_Discharge_Date;
    format ED_Admit_Date ED_Discharge_Date YYMMDD10.;
run;

proc sql;
    title2 "Number of ED visits in _61_STAR_ED_enc_first_31d";
    select count(*) as ED_visits
    from (select distinct membno, ED_Admit_Date from test._61_STAR_ED_enc_first_31d);
    title2;
quit;


* Step 7: Required exclusions ----------------------------------------------------------------------------------------------------------------------------------------- ;
** members who use hospice services;
data _71_STAR_Hospice;
    if _N_ = 1 then do;
        if 0 then set 
            test._31_VS_HosEnc_UBREV
            test._31_VS_HosEnc_CPT_HCPCS
            test._31_VS_HosInt_CPT_HCPCS
            ;
            
        declare hash h_HospiceEncounter_UBREV(dataset: "test._31_VS_HosEnc_UBREV");
        h_HospiceEncounter_UBREV.defineKey("code");
        h_HospiceEncounter_UBREV.defineDone();
        
        declare hash h_HospiceEncounter_CPT_HCPCS(dataset: "test._31_VS_HosEnc_CPT_HCPCS");
        h_HospiceEncounter_CPT_HCPCS.defineKey("code");
        h_HospiceEncounter_CPT_HCPCS.defineDone();
        
        declare hash h_HospiceIntervention_CPT_HCPCS(dataset: "test._31_VS_HosInt_CPT_HCPCS");
        h_HospiceIntervention_CPT_HCPCS.defineKey("code");
        h_HospiceIntervention_CPT_HCPCS.defineDone();
    end;

    set test._22_STAR_enc_all(where=(flag_ubrev = 1 or flag_cpt_hcpcs = 1));
        
    * hospice services;
    flag_EX_Hospice = 0;
    if h_HospiceEncounter_UBREV.find(key: revcod) = 0 then flag_EX_Hospice = 1;
    if h_HospiceEncounter_CPT_HCPCS.find(key: svccod) = 0 then flag_EX_Hospice = 1;
    if h_HospiceIntervention_CPT_HCPCS.find(key: svccod) = 0 then flag_EX_Hospice = 1;

    if flag_EX_Hospice = 1 then output;

    keep membno flag_EX_Hospice;
run;

* members who die any time during the measurement year;
proc sql;
    create table _72_STAR_DECEASED as
    select membno
        ,max(flag_EX_deceased_discharge) as flag_EX_deceased_discharge
    from test._22_STAR_enc_all
    group by membno;
quit;

* continous enrollment;
%let keep_vars_2 = membno bthdat sexcod qsi_race_desc qsi_ethnicity_desc qsi_race qsi_ethnicity v21_race v21_ethnicity plancod program county_cd C2: ;
data _72_STAR_Enrollment;
    set ST.star_enr_nodual_cy&year.(keep=&keep_vars_2);
run;


** macro for selecting variables from a table, with exclusion, avoid reference to each variable;
%macro selectVars(table, varList, excludeList);
    %local i varName j excludeVar excluded;
    %let i = 1;
    %do %while(%scan(&varList, &i) ne );
        %let varName = %scan(&varList, &i);
        %let j = 1;
        %let excluded = 0;
        %do %while(%scan(&excludeList, &j) ne );
            %let excludeVar = %scan(&excludeList, &j);
            %if &varName = &excludeVar %then %do;
                %let excluded = 1;
            %end;
            %let j = %eval(&j + 1);
        %end;
        %if &excluded = 0 %then &table..&varName %if (%scan(&varList, %eval(&i + 1)) ne ) %then ,;
        %let i = %eval(&i + 1);
    %end;
%mend selectVars;

** select all variables from _72_STAR_Enrollment for the join;
proc sql noprint;
    select name into: _varList_ENR separated by " "
    from dictionary.columns
    where upcase(libname) = "WORK" and upcase(memname) = "_72_STAR_ENROLLMENT";
quit;

proc sql;
    create table _73_STAR_Enrollment_ED_enc as
    select distinct A.*
        ,%selectVars(B, &_varList_ENR, membno)
    from test._61_STAR_ED_enc_first_31d as A
    left join _72_STAR_Enrollment as B on A.membno = B.membno
    order by A.membno, A.ED_Admit_Date;
quit;

** !!! if denominator is larger than expected, change date from admit to discharge;
data _74_STAR_ED_enrolled_30d;
    set _73_STAR_Enrollment_ED_enc;
    ED_Admit_Date_30d = intnx('day', ED_Admit_Date, 30);
    ED_month_30d = month(ED_Admit_Date_30d);
    
    flag_enrolled_through_30d = 0;
    array months[12] C2: ;
    if months[ED_month_30d] NE '' then flag_enrolled_through_30d = 1;

    drop ED_Admit_Date_30d ED_month_30d C2:;
run;

* put all exclusions together;
proc sql;
    create table _75_STAR_Denominator as
    select distinct A.*
        ,coalesce(B.flag_EX_Hospice, 0) as flag_EX_Hospice
        ,coalesce(C.flag_EX_deceased_discharge, 0) as flag_EX_deceased_discharge
    from _74_STAR_ED_enrolled_30d as A
    left join _71_STAR_Hospice as B on A.membno = B.membno
    left join _72_STAR_DECEASED as C on A.membno = C.membno
    ;
quit;

title2 "Frequency of exclusion criteria in _75_STAR_Denominator";
proc freq data=_75_STAR_Denominator;
    table flag_EX_Hospice flag_EX_deceased_discharge flag_enrolled_through_30d;
run;
title2;


* Step 8: Numerators ----------------------------------------------------------------------------------------------------------------------------------------- ;
* select encounter that after ED visit and within 30 days;
proc sql;
    create table _81_STAR_ED_FollowUp as
    select a.*
        ,b.ED_Admit_Date
        ,b.ED_Discharge_Date
    from test._22_STAR_enc_all as a
        join _75_STAR_Denominator as b
        on a.membno = b.membno
        and b.ED_Admit_Date <= a.dfrdos <= intnx('day', b.ED_Discharge_Date, 30)
    order by a.membno, a.dfrdos;
    ;
quit;

* identify follow-up visits and date;
data _82_STAR_ED_FollowUp_flag;
    if _N_ = 1 then do;
        if 0 then set 
            test._31_VS_VisSetUns_CPT_HCPCS
            test._31_VS_OutPOS_POS
            test._31_VS_MenHeaDia_ICD10CM
            test._31_VS_BHOut_CPT_HCPCS
            test._31_VS_BHOut_UBREV
            test._31_VS_ParHosOrIntOut_CPT_HCPCS
            test._31_VS_ParHosOrIntOut_UBREV
            test._31_VS_EleThe_CPT_HCPCS
            test._31_VS_EleThe_ICD10PCS
            test._31_VS_TelPOS_POS
            test._31_VS_TelVis_CPT_HCPCS
            test._31_VS_OnlAss_CPT_HCPCS
            test._31_VS_IntSel_ICD10CM
            test._31_VS_Obs_CPT_HCPCS
            ;
        
        declare hash h_VisitSettingUnspeci_CPT_HCPCS(dataset: "test._31_VS_VisSetUns_CPT_HCPCS");
        h_VisitSettingUnspeci_CPT_HCPCS.defineKey("code");
        h_VisitSettingUnspeci_CPT_HCPCS.defineDone();

        declare hash h_OutpatientPOS_POS(dataset: "test._31_VS_OutPOS_POS");
        h_OutpatientPOS_POS.defineKey("code");
        h_OutpatientPOS_POS.defineDone();

        declare hash h_MentalHealthDiagnos_ICD10CM(dataset: "test._31_VS_MenHeaDia_ICD10CM");
        h_MentalHealthDiagnos_ICD10CM.defineKey("code");
        h_MentalHealthDiagnos_ICD10CM.defineDone();

        declare hash h_BHOutpatient_CPT_HCPCS(dataset: "test._31_VS_BHOut_CPT_HCPCS");
        h_BHOutpatient_CPT_HCPCS.defineKey("code");
        h_BHOutpatient_CPT_HCPCS.defineDone();

        declare hash h_BHOutpatient_UBREV(dataset: "test._31_VS_BHOut_UBREV");
        h_BHOutpatient_UBREV.defineKey("code");
        h_BHOutpatient_UBREV.defineDone();

        declare hash h_PartialHospitalizat_CPT_HCPCS(dataset: "test._31_VS_ParHosOrIntOut_CPT_HCPCS");
        h_PartialHospitalizat_CPT_HCPCS.defineKey("code");
        h_PartialHospitalizat_CPT_HCPCS.defineDone();

        declare hash h_PartialHospitalizat_UBREV(dataset: "test._31_VS_ParHosOrIntOut_UBREV");
        h_PartialHospitalizat_UBREV.defineKey("code");
        h_PartialHospitalizat_UBREV.defineDone();

        declare hash h_ElectroconvulsiveTh_CPT_HCPCS(dataset: "test._31_VS_EleThe_CPT_HCPCS");
        h_ElectroconvulsiveTh_CPT_HCPCS.defineKey("code");
        h_ElectroconvulsiveTh_CPT_HCPCS.defineDone();

        declare hash h_ElectroconvulsiveTh_ICD10PCS(dataset: "test._31_VS_EleThe_ICD10PCS");
        h_ElectroconvulsiveTh_ICD10PCS.defineKey("code");
        h_ElectroconvulsiveTh_ICD10PCS.defineDone();

        declare hash h_TelehealthPOS_POS(dataset: "test._31_VS_TelPOS_POS");
        h_TelehealthPOS_POS.defineKey("code");
        h_TelehealthPOS_POS.defineDone();

        declare hash h_TelephoneVisits_CPT_HCPCS(dataset: "test._31_VS_TelVis_CPT_HCPCS");
        h_TelephoneVisits_CPT_HCPCS.defineKey("code");
        h_TelephoneVisits_CPT_HCPCS.defineDone();

        declare hash h_OnlineAssessments_CPT_HCPCS(dataset: "test._31_VS_OnlAss_CPT_HCPCS");
        h_OnlineAssessments_CPT_HCPCS.defineKey("code");
        h_OnlineAssessments_CPT_HCPCS.defineDone();

        declare hash h_IntentionalSelfHarm_ICD10CM(dataset: "test._31_VS_IntSel_ICD10CM");
        h_IntentionalSelfHarm_ICD10CM.defineKey("code");
        h_IntentionalSelfHarm_ICD10CM.defineDone();

        declare hash h_Observation_CPT_HCPCS(dataset: "test._31_VS_Obs_CPT_HCPCS");
        h_Observation_CPT_HCPCS.defineKey("code");
        h_Observation_CPT_HCPCS.defineDone();
    end;

    set _81_STAR_ED_FollowUp;

    * a principal diagnosis of a mental health disorder;
    * a principal diagnosis of intentional self-harm and any diagnosis of a mental health disorder;
    flag_principal_MentalHealth = 0;
    flag_principal_SelfHarm = 0;
    primary_dx = compress(upcase(diagn1), ' .');
    if h_IntentionalSelfHarm_ICD10CM.find(key: primary_dx) = 0 then flag_principal_SelfHarm = 1;
    if h_MentalHealthDiagnos_ICD10CM.find(key: primary_dx) = 0 then flag_principal_MentalHealth = 1;
    
    flag_any_MentalHealth = 0;
    array diagns[25] diagn1-diagn25;
    do i = 1 to 25;
        if diagns[i] = "" then leave;
        dx = compress(upcase(diagns[i]), ' .');
        if h_MentalHealthDiagnos_ICD10CM.find(key: dx) = 0 then do;
            flag_any_MentalHealth = 1;
            leave;
        end;
    end;

    if flag_principal_MentalHealth = 1 or (flag_principal_SelfHarm = 1 and flag_any_MentalHealth = 1) then do;
        
        * visit setting unspecified flag;
        flag_VisitSettingUnspeci = 0;
        if h_VisitSettingUnspeci_CPT_HCPCS.find(key: svccod) = 0 then flag_VisitSettingUnspeci = 1;

        * outpatient visit;
        flag_outpatient = 0;
        if (flag_VisitSettingUnspeci = 1 and h_OutpatientPOS_POS.find(key: poscod) = 0) 
            or (h_BHOutpatient_CPT_HCPCS.find(key: svccod) = 0 or h_BHOutpatient_UBREV.find(key: revcod) = 0)
        then flag_outpatient = 1;
        
        * intensive outpatient encounter or partial hospitalization;
        flag_intensive_outpatient = 0;
        if (flag_VisitSettingUnspeci = 1 and poscod = '52')
            or (h_PartialHospitalizat_CPT_HCPCS.find(key: svccod) = 0 or h_PartialHospitalizat_UBREV.find(key: revcod) = 0) 
        then flag_intensive_outpatient = 1;
        
        * community mental health center visit;
        flag_community_mental_health = 0;
        if flag_VisitSettingUnspeci = 1 and poscod = '53' 
        then flag_community_mental_health = 1;
        
        * electroconvulsive therapy;
        flag_electro_therapy_p1 = 0;
        if h_ElectroconvulsiveTh_CPT_HCPCS.find(key: svccod) = 0 then flag_electro_therapy_p1 = 1;
        array surgs[25] surg1-surg25;
        do i = 1 to 25;
            if surgs[i] = "" then leave;
            px = compress(upcase(surgs[i]), ' .');
            if h_ElectroconvulsiveTh_ICD10PCS.find(key: px) = 0 then do;
                flag_electro_therapy_p1 = 1;
                leave;
            end;
        end;
        flag_electroconvulsive_therapy = 0;
        if flag_electro_therapy_p1 = 1 and (h_OutpatientPOS_POS.find(key: poscod) = 0 or poscod in ('24', '52', '53')) 
        then flag_electroconvulsive_therapy = 1;

        * telehealth visit;
        flag_telehealth = 0;
        if (flag_VisitSettingUnspeci = 1 and h_TelehealthPOS_POS.find(key: poscod) = 0) 
        then flag_telehealth = 1;

        * telephone visit;
        flag_telephone = 0;
        if h_TelephoneVisits_CPT_HCPCS.find(key: svccod) = 0 then flag_telephone = 1;

        * e-visit or virtual check-in;
        flag_e_visit = 0;
        if h_OnlineAssessments_CPT_HCPCS.find(key: svccod) = 0 then flag_e_visit = 1;

        * MY2023 FUM has observation visit;
        flag_observation = 0;
        if h_Observation_CPT_HCPCS.find(key: svccod) then flag_observation = 1;
    end;

    * follow-up visit;
    flag_follow_up_30days = 0;
    flag_follow_up_7days = 0;
    if flag_outpatient = 1 
        or flag_intensive_outpatient = 1 
        or flag_community_mental_health = 1 
        or flag_electroconvulsive_therapy = 1 
        or flag_telehealth = 1 
        or flag_telephone = 1 
        or flag_e_visit = 1 
        or flag_observation = 1
    then do;
        follow_up_in_days = intck('day', ED_Discharge_Date, dfrdos);
        if 0 < follow_up_in_days <= 30 then flag_follow_up_30days = 1;
        if 0 < follow_up_in_days <= 7 then flag_follow_up_7days = 1;
        output;
    end;

    drop i code dx px;
run;

proc freq data=test._82_STAR_ED_FollowUp_flag;
    table flag_principal_MentalHealth flag_principal_SelfHarm  flag_any_MentalHealth flag_VisitSettingUnspeci flag_outpatient flag_intensive_outpatient flag_community_mental_health flag_electroconvulsive_therapy flag_telehealth flag_telephone flag_e_visit flag_observation;
run;

proc sql;
    create table _83_STAR_FUM_Numerator as
    select membno
        ,ED_Admit_Date
        ,max(flag_follow_up_30days) as Follow_Up_30Days
        ,max(flag_follow_up_7days) as Follow_Up_7Days
    from _82_STAR_ED_FollowUp_flag
    group by membno, ED_Admit_Date;
quit;

proc sql;
    create table _84_STAR_FUM as
    select a.*
        ,coalesce(b.Follow_Up_30Days, 0) as Follow_Up_30Days
        ,coalesce(b.Follow_Up_7Days, 0) as Follow_Up_7Days
    from _75_STAR_Denominator as a
        left join _83_STAR_FUM_Numerator as b
        on a.membno = b.membno
        and a.ED_Admit_Date = b.ED_Admit_Date;
quit;

title2 "FUM rate, excluded members who use hospice services or die any time during the measurement year, and members who do not have continuous enrollment";
proc freq data=test._84_STAR_FUM(where=(flag_EX_Hospice = 0 and flag_EX_deceased_discharge = 0 and flag_enrolled_through_30d = 1));
    table Follow_Up_30Days Follow_Up_7Days;
run;
title2;

proc freq data=test._81_STAR_ED_FollowUp; 
tables plancod; 
run;