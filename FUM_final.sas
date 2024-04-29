/* Program name: hedis_measure_fum
    Author: Jiang 'Kira' Shao  
	Version: March 18, 2024
	Program Purpose: Develope the measure 
	"Follow-Up After Emergency Department Visit for Mental Illness (FUM)" 
	using ICHP's encounter and enrollment datasets. Original HEDIS admin measure is calculated by 
	QSI (Quality Spectrum Indicator) software, which didnt published how measure calculated. Since we
	received the request to update te FUM quarterly, we are going to develop FUM measure
*/ 

/* -------------------------------------------------------------------------------------------------------------------------
	Work flow / step (from Mar 18) 
	1) create a macro to extract value set codes, so that we can determine and flag each encounters
	2) determine the base denominator population - 1. ED visit 2. With pricipal diagnosis of mental health illness
	3) filter by 1. continuous enrollment
	4) filter by the ED rules: 1. followed by inpatient admission 2. if multiple ED visit within one month, only count one
	5) filter by HEDIS exclusion rules: no hospice
	6) select numerator based on eligible trigger events/diagnosis
*/ 

/* -------------------------------------------------------------------------------------------------------------------------
What is FUM: 
The percentage of emergency department (ED) visits for members 6 years of age and older with a 
principal diagnosis of mental illness or intentional self-harm, who had a follow-up visit for mental illness. 

FUM has two rates: 
1. The percentage of ED visits for which the member received follow-up within 30 days of the ED visit (31 total days).
2. The percentage of ED visits for which the member received follow-up within 7 days of the ED visit (8 total days). 
*/ 

/* -------------------------------------------------------------------------------------------------------------------------
Denominator (Eligible Population): 
1. Continuous Enrollment: Date of the ED visit through 30 days after the ED visit (31 total days).

2. Event/Diagnosis: An ED visit (ED Value Set) with a principal diagnosis of mental illness or 
intentional self-harm (Mental Illness Value Set; Intentional Self-Harm Value Set) on or between 
January 1 and December 1 of the measurement year where the member was 6 years or older on the date of the visit.

3. Denominator method: The denominator for this measure is based on ED visits, not on members. 
If a member has more than one ED visit, identify all eligible ED visits between January 1 and December 1 
of the measurement year and do not include more than one visit per 31-day period as described below.  

4. Multiple visits in a 31-day period: If a member has more than one ED visit in a 31-day period, 
include only the first eligible ED visit. 

5. ED visits followed by inpatient admission: Exclude ED visits that result in an inpatient stay and ED visits 
followed by admission to an acute or nonacute inpatient care setting on the date of the ED visit or 
within the 30 days after the ED visit (31 total days), regardless of the principal diagnosis for the admission. 
To identify admissions to an acute or nonacute inpatient care setting: 
		1)	Identify all acute and nonacute inpatient stays (Inpatient Stay Value Set).
		2)	Identify the admission date for the stay.

6. Required exclusion by HEDIS: Members in hospice or using hospice services anytime during the measurement year
*/ 

/* -------------------------------------------------------------------------------------------------------------------------
Numerator: 
A follow-up visit with any practitioner, with a principal diagnosis of a mental health disorder or with a principal diagnosis 
of intentional self-harm and any diagnosis of a mental health disorder within 7/30 days after the ED visit (8/31 total days). 
Include visits that occur on the date of the ED visit.
*/ 

/* libname, locate datasets */ 
libname fmtlib "K:\IS-Resources\Resources\SAS Resources\TEXAS\FormatLib";
OPTIONS PS=MAX FORMCHAR="|----|+|---+=|-/\<>*" MPRINT fmtsearch=(fmtlib);

* we are going to use 2022 dataset, for testing and verify; 
libname ST "K:\TX-Data\Datasets\STAR";
libname valueset "K:\TX-Data\Datasets\HEDIS\HEDIS VALUE SET\HEDIS MY2022\data\final";
libname temp "\\fed-ad.ufl.edu\T001\user\mydocs\jiang.shao\Desktop\hedis_dev\out";

* import STAR encounter and enrollment dataset;
data star_enr_22; 
	set ST.star_enr_nodual_cy2022 (keep=membno bthdat sexcod plancod program qsi_race qsi_ethnicity v21_race v21_ethnicity county_cd C2: ); 
run;

data star_enc_22; 
	set ST.star_enc_cy2022 (keep=membno bdate plancod dschstat dfrdos dtodos diagn1-diagn25 surg1-surg25 typbill transtype svccod revcod poscod); 
run;

* impoart HEDIS value set - this set will contain code system that help us to flag; 
data HEDIS_VALUE_SET; set valueset.merged_codes_hedis_my2022; where Measure_ID = "FUM"; run;

proc freq data= HEDIS_VALUE_SET; tables Code_System; run;

* we only need to keep ICD10CM/PCS, POS, UBREV, CPT, HCPCS;
data HEDIS_VALUE_SET; 
	set HEDIS_VALUE_SET; 
	where Code_System = 'CPT' 
	or Code_System = 'ICD10CM' 
	or Code_System = 'ICD10PCS' 
	or Code_System = 'POS' 
	or Code_System = 'UBREV' 
	or Code_System = 'HCPCS' ; 
run;

/* update March 22, found that the encounter code is little bit of different than the valueset. For example: 
F11.40 in value set, but in encounter diagncode is F1140, then we should trim the dot off from valueset */ 

data HEDIS_VALUE_SET; 
	set HEDIS_VALUE_SET; 
	Code = compress(upcase(Code), '.'); 
run;


%macro select_hedis_value_code (value_set_name, code_system, output_name);
	proc sql; 
		create table &output_name as 
		select Code
		from HEDIS_VALUE_SET
		where Value_Set_Name = &value_set_name AND Code_System = &code_system;
	quit;
%mend select_hedis_value_code;

%select_hedis_value_code ("Ambulatory Surgical Center POS", "POS", amb_surg_cen_pos);
%select_hedis_value_code ("BH Outpatient", "UBREV", bh_outpat_ubrev);
%select_hedis_value_code ("BH Outpatient", "CPT", bh_outpat_cpt);
%select_hedis_value_code ("BH Outpatient", "HCPCS", bh_outpat_hcpcs);
proc sql;  select quote (trim(Code)) into: amb_surg_cen_pos SEPARATED by ' ' from amb_surg_cen_pos;  quit;
proc sql;  select quote (trim(Code)) into: bh_outpat_ubrev SEPARATED by ' ' from bh_outpat_ubrev;  quit;
proc sql;  select quote (trim(Code)) into: bh_outpat_cpt SEPARATED by ' ' from bh_outpat_cpt;  quit;
proc sql;  select quote (trim(Code)) into: bh_outpat_hcpcs SEPARATED by ' ' from bh_outpat_hcpcs;  quit;
%select_hedis_value_code ("Community Mental Health Center POS", "POS", comm_mental_health_pos);
%select_hedis_value_code ("ED", "UBREV", ed_ubrev);
%select_hedis_value_code ("ED", "CPT", ed_cpt);
%select_hedis_value_code ("Electroconvulsive Therapy", "ICD10PCS", electroconv_icd10pcs);
%select_hedis_value_code ("Electroconvulsive Therapy", "CPT", electroconv_cpt);
proc sql;  select quote (trim(Code)) into: comm_mental_health_pos SEPARATED by ' ' from comm_mental_health_pos;  quit;
proc sql;  select quote (trim(Code)) into: ed_ubrev SEPARATED by ' ' from ed_ubrev;  quit;
proc sql;  select quote (trim(Code)) into: ed_cpt SEPARATED by ' ' from ed_cpt;  quit;
proc sql;  select quote (trim(Code)) into: electroconv_icd10pcs SEPARATED by ' ' from electroconv_icd10pcs;  quit;
proc sql;  select quote (trim(Code)) into: electroconv_cpt SEPARATED by ' ' from electroconv_cpt;  quit;
%select_hedis_value_code ("Hospice Encounter", "UBREV", hospice_enc_ubrev);
%select_hedis_value_code ("Hospice Encounter", "HCPCS", hospice_enc_hcpcs);
%select_hedis_value_code ("Hospice Intervention", "CPT", hospice_interv_cpt);
%select_hedis_value_code ("Hospice Intervention", "HCPCS", hospice_interv_hcpcs);
proc sql;  select quote (trim(Code)) into: hospice_enc_ubrev SEPARATED by ' ' from hospice_enc_ubrev;  quit;
proc sql;  select quote (trim(Code)) into: hospice_enc_hcpcs SEPARATED by ' ' from hospice_enc_hcpcs;  quit;
proc sql;  select quote (trim(Code)) into: hospice_interv_cpt SEPARATED by ' ' from hospice_interv_cpt;  quit;
proc sql;  select quote (trim(Code)) into: hospice_interv_hcpcs SEPARATED by ' ' from hospice_interv_hcpcs;  quit;
%select_hedis_value_code ("Inpatient Stay", "UBREV", inpatient_stay_ubrev);
%select_hedis_value_code ("Intentional Self-Harm", "ICD10CM", intentional_self_harm_icd10cm);
%select_hedis_value_code ("Mental Health Diagnosis", "ICD10CM", mental_diagn_icd10cm);
%select_hedis_value_code ("Mental Illness", "ICD10CM", mental_illness_icd10cm);
proc sql;  select quote (trim(Code)) into: inpatient_stay_ubrev SEPARATED by ' ' from inpatient_stay_ubrev;  quit;
proc sql;  select quote (trim(Code)) into: intentional_self_harm_icd10cm SEPARATED by ' ' from intentional_self_harm_icd10cm;  quit;
proc sql;  select quote (trim(Code)) into: mental_diagn_icd10cm SEPARATED by ' ' from mental_diagn_icd10cm;  quit;
proc sql;  select quote (trim(Code)) into: mental_illness_icd10cm SEPARATED by ' ' from mental_illness_icd10cm;  quit;
%select_hedis_value_code ("Observation", "CPT", obs_cpt);
%select_hedis_value_code ("Online Assessments", "CPT", online_assess_cpt);
%select_hedis_value_code ("Online Assessments", "HCPCS", online_assess_hcpcs);
%select_hedis_value_code ("Outpatient POS", "POS", outpatient_pos);
proc sql;  select quote (trim(Code)) into: obs_cpt SEPARATED by ' ' from obs_cpt;  quit;
proc sql;  select quote (trim(Code)) into: online_assess_cpt SEPARATED by ' ' from online_assess_cpt;  quit;
proc sql;  select quote (trim(Code)) into: online_assess_hcpcs SEPARATED by ' ' from online_assess_hcpcs;  quit;
proc sql;  select quote (trim(Code)) into: outpatient_pos SEPARATED by ' ' from outpatient_pos;  quit;
%select_hedis_value_code ("Partial Hospitalization or Intensive Outpatient", "HCPCS", part_hosp_inten_outp_hcpcs);
%select_hedis_value_code ("Partial Hospitalization or Intensive Outpatient", "UBREV", part_hosp_inten_outp_ubrev);
%select_hedis_value_code ("Partial Hospitalization POS", "POS", part_hosp_pos);
proc sql;  select quote (trim(Code)) into: part_hosp_inten_outp_hcpcs SEPARATED by ' ' from part_hosp_inten_outp_hcpcs;  quit;
proc sql;  select quote (trim(Code)) into: part_hosp_inten_outp_ubrev SEPARATED by ' ' from part_hosp_inten_outp_ubrev;  quit;
proc sql;  select quote (trim(Code)) into: part_hosp_pos SEPARATED by ' ' from part_hosp_pos;  quit;
%select_hedis_value_code ("Telehealth POS", "POS", telehealth_pos);
%select_hedis_value_code ("Telephone Visits", "CPT", telephone_visit_cpt);
%select_hedis_value_code ("Visit Setting Unspecified", "CPT", visit_set_unspec_cpt);
proc sql;  select quote (trim(Code)) into: telehealth_pos SEPARATED by ' ' from telehealth_pos;  quit;
proc sql;  select quote (trim(Code)) into: telephone_visit_cpt SEPARATED by ' ' from telephone_visit_cpt;  quit;
proc sql;  select quote (trim(Code)) into: visit_set_unspec_cpt SEPARATED by ' ' from visit_set_unspec_cpt;  quit;


%macro select_code_system (code_system, output_name);
	proc sql; 
		create table &output_name as 
		select Code
		from HEDIS_VALUE_SET
		where Code_System = &code_system;
	quit;
%mend;


%select_code_system('ICD10CM', code_system_icd10cm); 
%select_code_system('ICD10PCS', code_system_ICD10PCS); 
%select_code_system('UBREV', code_system_UBREV); 
%select_code_system('POS', code_system_POS); 
%select_code_system('CPT', code_system_CPT); 
%select_code_system('HCPCS', code_system_HCPCS); 

proc sql;  select quote (trim(Code)) into: code_system_icd10cm SEPARATED by ' ' from code_system_icd10cm;  quit;
proc sql;  select quote (trim(Code)) into: code_system_ICD10PCS SEPARATED by ' ' from code_system_ICD10PCS;  quit;
proc sql;  select quote (trim(Code)) into: code_system_UBREV SEPARATED by ' ' from code_system_UBREV;  quit;
proc sql;  select quote (trim(Code)) into: code_system_POS SEPARATED by ' ' from code_system_POS;  quit;
proc sql;  select quote (trim(Code)) into: code_system_CPT SEPARATED by ' ' from code_system_CPT;  quit;
proc sql;  select quote (trim(Code)) into: code_system_HCPCS SEPARATED by ' ' from code_system_HCPCS;  quit;


data star_enc_all_flagged; 
	set star_enc_22; 

	is_cpt = 0; 
	if svccod in: (&code_system_CPT) then is_cpt = 1; 
	is_ubrev = 0; 
	if revcod in: (&code_system_UBREV) then is_ubrev = 1; 
	is_hcpcs = 0; 
	if svccod in: (&code_system_HCPCS) then is_hcpcs = 1; 
	is_pos = 0; 
	if poscod in: (&code_system_POS) then is_pos = 1; 

	is_icd10cm = 0; 
	array diagns[25] diagn1-diagn25;
	do i = 1 to 25; 
		if diagns[i] = "" then leave; 
		diagnosis = compress(upcase(diagns[i]), '. '); 
		if diagnosis in:(&code_system_icd10cm) then do; 
			is_icd10cm = 1; 
			leave; 
		end;
	end; 

	is_icd10pcs = 0; 
	array surgs[25] surg1-surg25;
	do i = 1 to 25; 
		if surgs[i] = "" then leave; 
		surgery = compress(upcase(surgs[i]), '. ');
		if surgery in:(&code_system_ICD10PCS) then do;
			is_icd10pcs = 1; 
			leave; 
		end; 
	end;

	if is_icd10cm = 1 or is_icd10pcs =1 or is_cpt =1 or is_ubrev=1 or is_hcpcs =1 or is_pos =1
	then output;

	drop i; 
	format dfrdos dtodos bdate YYMMDD10.; 
run;

proc freq data=star_enc_all_flagged; 
tables is_icd10cm is_icd10pcs is_cpt is_ubrev is_hcpcs is_pos; 
run;

* save the dataset for futher usage; 
data temp.star_enc_all_22; 
	set work.star_enc_all_flagged; 
run;


/* 2. Event/Diagnosis: An ED visit (ED Value Set) with a principal diagnosis of mental illness or 
intentional self-harm (Mental Illness Value Set; Intentional Self-Harm Value Set) on or between 
January 1 and December 1 of the measurement year where the member was 6 years or older on the date of the visit. */
proc sql;  select quote (trim(Code)) into: intentional_self_harm_icd10cm SEPARATED by ' ' from intentional_self_harm_icd10cm;  quit;
proc sql;  select quote (trim(Code)) into: mental_illness_icd10cm SEPARATED by ' ' from mental_illness_icd10cm;  quit;
proc sql;  select quote (trim(Code)) into: ED_ubrev SEPARATED by ' ' from ED_ubrev;  quit;
proc sql;  select quote (trim(Code)) into: ED_CPT SEPARATED by ' ' from ED_CPT;  quit;

%put &ED_CPT; 

data star_enc_all_flagged_denom; 
	set star_enc_all_flagged; 
	where transtype = 'I'; 
run;

data star_enc_all_flagged_denom; 
	set star_enc_all_flagged_denom; 

	is_ED = 0; 
	if revcod in: (&ED_ubrev) or svccod in: (&ED_CPT) then is_ED = 1; 

	is_mental_ill = 0; 
	if diagn1 in: (&intentional_self_harm_icd10cm) or diagn1 in: (&mental_illness_icd10cm) then is_mental_ill = 1; 

	if is_ED = 1 AND is_mental_ill = 1 then output; 
run;

proc freq data=star_enc_all_flagged_denom; 
tables is_ED is_mental_ill; 
run;

/* double check the ED visit, check if is cord with old ED selection code */ 
* flag emergency visit institutional claims;
data star_enc_all_flagged_denom_test; 
	set star_enc_all_flagged; 
	if transtype='I' and (revcod in ('0450' '0451' '0452' '0456' '0459' '0981') 
	or svccod in ('99281' '99282' '99283' '99284' '99285' 'G0380' 'G0381' 'G0382' 'G0383' 'G0384' 'G0390')) 
	and typbill not in: ('11','12','41') then ED=1;
run;

data star_enc_all_flagged_denom_test2; 
	set star_enc_all_flagged; 

	is_ED = 0; 
	if revcod in: (&ED_ubrev) or svccod in: (&ED_CPT) then is_ED = 1; 

	if is_ED = 1  AND transtype = 'I' then output; 
run;

proc freq data=star_enc_all_flagged_denom_test; 
tables ED; 
run;

proc freq data=star_enc_all_flagged_denom_test2; 
tables is_ED; 
run;

/* identify all eligible ED visits between January 1 and December 1 */ 

data star_enc_all_flagged_denom; 
	set star_enc_all_flagged_denom; 
	where '01JAN2022'd <= dfrdos <= '31DEC2022'd; 
run;

/* identify all eligible ED visits with member over 6 years old (at visit) */ 

data star_enc_all_flagged_denom; 
	set star_enc_all_flagged_denom; 
	age_years = intck('year', bdate, dfrdos); 
	if age_years >= 6; 
run;


/* exclude all ED visit that followed by inpatient admission */ 
proc sql;  select quote (trim(Code)) into: inpatient_stay_ubrev SEPARATED by ' ' from inpatient_stay_ubrev;  quit;
%put &inpatient_stay_ubrev; 

data enc_all_inp; 
	set star_enc_all_flagged; 

	is_inp = 0; 
	if revcod in: (&inpatient_stay_ubrev) then do; 
		is_inp = 1; 
		output; 
	end;

	keep revcod membno is_inp dfrdos dtodos; 
run;

/* update Mar 28, since the order of exclusion for multiple visit and inp admission should be reversed */ 
/* now we can use the enc_all_inp and star_enc_all_flagged_denom to rule out inpatient */ 
proc sort data=star_enc_all_flagged_denom; by membno dfrdos; run;

data enc_all_inp; 
	set enc_all_inp; 
	inp_admin_date = dfrdos ; 
	inp_discharge_date = dtodos; 
	format inp_admin_date inp_discharge_date YYMMDD10.; 
run;

proc sort data=enc_all_inp; by membno dfrdos; run;

proc sql;
    create table enc_all_flagged_denom_noinp as
    select a.*
    from star_enc_all_flagged_denom as a
        left join enc_all_inp as b
        on a.membno = b.membno
        and a.dfrdos <= b.dfrdos <= intnx('day', a.dtodos, 31)
    where b.is_inp ne 1 
    order by a.membno, a.dfrdos;
quit;


/* Exclude for no multiple visits in a 31-days period */
data enc_denom_noinp_no31;
    set enc_all_flagged_denom_noinp;
    by membno;
    if first.membno then do;
        dfrdos_new = dfrdos;
        temp = dfrdos;
        dtodos_new = dtodos;
        output;
    end;
    else do;

        if abs(dfrdos - temp) >= 31 then do;
            dfrdos_new = dfrdos;
            temp = dfrdos;
            dtodos_new = dtodos;
            output;
        end;
    end;
    keep membno dfrdos_new dtodos_new;
    format dfrdos_new dtodos_new YYMMDD10.;
run;


/* exclude for hospice */ 
%select_hedis_value_code ("Hospice Encounter", "UBREV", hospice_enc_ubrev);
%select_hedis_value_code ("Hospice Encounter", "HCPCS", hospice_enc_hcpcs);
%select_hedis_value_code ("Hospice Intervention", "CPT", hospice_interv_cpt);
%select_hedis_value_code ("Hospice Intervention", "HCPCS", hospice_interv_hcpcs);
proc sql;  select quote (trim(Code)) into: hospice_enc_ubrev SEPARATED by ' ' from hospice_enc_ubrev;  quit;
proc sql;  select quote (trim(Code)) into: hospice_enc_hcpcs SEPARATED by ' ' from hospice_enc_hcpcs;  quit;
proc sql;  select quote (trim(Code)) into: hospice_interv_cpt SEPARATED by ' ' from hospice_interv_cpt;  quit;
proc sql;  select quote (trim(Code)) into: hospice_interv_hcpcs SEPARATED by ' ' from hospice_interv_hcpcs;  quit;

data enc_all_hospice; 
	set star_enc_all_flagged; 

	is_hospice = 0; 
	if revcod in: (&hospice_enc_ubrev)
	or svccod in: (&hospice_enc_hcpcs) 
	or svccod in: (&hospice_interv_cpt) 
	or svccod in: (&hospice_interv_hcpcs) then is_hospice = 1; 

	keep membno revcod svccod is_hospice; 
run;

proc freq data=enc_all_hospice; 
tables is_hospice; 
run;

data enc_all_hospice; 
	set enc_all_hospice; 
	where is_hospice = 1; 
run;

proc sql; 
	create table denom_noinp_no31_nohos as 
	select a.* 
	from enc_denom_noinp_no31 as a 
	left join enc_all_hospice as b
	on a.membno = b.membno
	where b.membno is null; 
quit;

proc sql; 
select count (*) as denom
from denom_noinp_no31_nohos;
quit;

proc sql;
    title2 "Denominator - (dedup by membno and same day visit)";
    select count(*) as denom
    from (select distinct membno, dfrdos_new from denom_noinp_no31_nohos);
    title2;
quit;


/* check denominator: in 2022, the denominator should be 7413 for all age, this program gets 6552 */ 

/* numerator */
/* copy the membno, admin date and discharge date, mapped from denominator */ 
/* followup is determined by a new admission date after ED visit and 30 days after ED visit */ 
proc sql;
    create table followup_after_ED as
    select a.*, 
	b.dfrdos_new, b.dtodos_new
    from star_enc_all_flagged as a
        join denom_noinp_no31_nohos as b
        on a.membno = b.membno
        and b.dfrdos_new < a.dfrdos <= intnx('day', b.dtodos_new, 31)
    order by a.membno, a.dfrdos;
    ;
quit;


data flag_num_event_22;
	set followup_after_ED; 

	    is_MH = 0; /* Indicator of first diagnosis is mental illness */ 
	    is_SH = 0;  /* Indicator of first diagnosis is self harm */ 
		is_any_MH = 0;  /* Indicator of any diagnosis is mental illness */ 

		* with a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).; 
	    diagnosis = compress(upcase(diagn1));
	    if diagnosis in: (&intentional_self_harm_icd10cm) then is_SH = 1;
	    if diagnosis in: (&mental_diagn_icd10cm) then is_MH = 1;
	    
		* with a principal diagnosis of intentional self-harm (Intentional Self-Harm Value Set), 
		with any diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
	    array diagns[25] diagn1-diagn25;
	    do i = 1 to 25;
	        if diagns[i] = "" then leave;
	        diagnosis_any = compress(upcase(diagns[i]));
	        if diagnosis_any in: (&mental_diagn_icd10cm) then do;
	            is_any_MH = 1;
	            leave;
	        end;
	    end;

		* An outpatient visit (Visit Setting Unspecified Value Set with Outpatient POS Value Set) with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
        is_outpatient_visit_1 = 0;
        if svccod in: (&visit_set_unspec_cpt)
		and poscod in: (&outpatient_pos)
		and (is_MH = 1 
		or (is_SH = 1 and is_any_MH = 1)) then is_outpatient_visit_1 = 1;

        * An outpatient visit (BH Outpatient Value Set) with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
        is_outpatient_visit_2 = 0;
        if (svccod in: (&bh_outpat_cpt)
			or  svccod in: (&bh_outpat_hcpcs)
			or  revcod in: (&bh_outpat_ubrev)) 
			and (is_MH = 1 
			or (is_SH = 1 and is_any_MH = 1)) then is_outpatient_visit_2 = 1;

/*		flag_VisitSettingUnspeci = 0;*/
/*        if svccod in: (&visit_set_unspec_cpt) then flag_VisitSettingUnspeci = 1;*/
/**/
/*		flag_outpatient = 0;*/
/*        if (flag_VisitSettingUnspeci = 1 and poscod in: (&outpatient_pos)) */
/*            or (svccod in: (&bh_outpat_hcpcs) or revcod in: (&bh_outpat_ubrev))*/
/*        then flag_outpatient = 1;*/
        
        * An intensive outpatient encounter or partial hospitalization (Visit Setting Unspecified Value Set with 
		Partial Hospitalization POS Value Set), with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
        is_intensive_outpatient_1 = 0;
        if poscod in: (&part_hosp_pos)
			and (is_MH = 1 
			or (is_SH = 1 and is_any_MH = 1)) then is_intensive_outpatient = 1;

		* An intensive outpatient encounter or partial hospitalization (Partial Hospitalization or Intensive Outpatient Value Set) with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
        is_intensive_outpatient_2 = 0;
        if svccod in:(&part_hosp_inten_outp_hcpcs) 
			or revcod in:(&part_hosp_inten_outp_hcpcs) 
			and (is_MH = 1 
			or (is_SH = 1 and is_any_MH = 1)) then is_intensive_outpatient = 1;

		* A community mental health center visit (Visit Setting Unspecified Value Set with 
		Community Mental Health Center POS Value Set), with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
		is_community_mental_health = 0;
        if poscod in:(&comm_mental_health_pos) 
		and (is_MH = 1 
		or (is_SH = 1 and is_any_MH = 1)) then is_community_mental_health = 1;

		* Electroconvulsive therapy (Electroconvulsive Therapy Value Set) with 
		1. Ambulatory Surgical Center POS Value Set, 
		2. Community Mental Health Center POS Value Set, 
		3. Outpatient POS Value Set, 
		4. Partial Hospitalization POS Value Set) with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
		is_electro = 0;
        if svccod in: (&electroconv_cpt) 
		and (poscod in: (&amb_surg_cen_pos)			/*  #1  */
		or poscod in: (&comm_mental_health_pos)  /*  #2  */
		or poscod in: (&outpatient_pos) 					  /*  #3  */
		or poscod in: (&part_hosp_pos))					  /*  #4  */
		and (is_MH = 1 
		or (is_SH = 1 and is_any_MH = 1)) then is_electro = 1;

		* A telehealth visit (Visit Setting Unspecified Value Set with 
		Telehealth POS Value Set), with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
	    is_telehealth = 0;
        if poscod in: (&telehealth_pos)
		and (is_MH = 1 
		or (is_SH = 1 and is_any_MH = 1)) then is_telehealth = 1;

		* An observation visit (Observation Value Set) with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
		is_obs = 0;
        if svccod in: (&obs_cpt) 
		and (is_MH = 1 
		or (is_SH = 1 and is_any_MH = 1)) then is_obs = 1;

		* A telephone visit (Telephone Visits Value Set) with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
		is_telephone = 0;
        if svccod in:(&telephone_visit_cpt) 
		and (is_MH = 1 
		or (is_SH = 1 and is_any_MH = 1)) then is_telephone = 1;

		* An e-visit or virtual check-in (Online Assessments Value Set) with 
		a principal diagnosis of a mental health disorder (Mental Health Diagnosis Value Set).;
		is_virtual_checkin = 0;
        if svccod in:(&online_assess_cpt) 
		or svccod in:(&online_assess_hcpcs) 
		and (is_MH = 1 
		or (is_SH = 1 and is_any_MH = 1)) then is_virtual_checkin = 1;


    if is_outpatient_visit_1 = 1
		or is_outpatient_visit_2 = 1
        or is_intensive_outpatient_1 = 1 
		or is_intensive_outpatient_2 = 1
		or is_community_mental_health = 1
		or is_electro = 1
		or is_telehealth = 1
		or is_telephone = 1
		or is_obs = 1
		or is_virtual_checkin = 1
    then output; 
run;

/* 31 days should include 7 days visit */ 
data flag_num_event_22; 
	set flag_num_event_22; 
		followup_days = intck('day', dtodos_new, dfrdos); 
		_7days = 0; 
		if followup_days <= 8 then _7days = 1; 
		_30days = 0; 
		if followup_days <= 31 then _30days = 1; 
run;

proc freq data=flag_num_event_22; 
	tables _7days _30days
				is_MH 
				is_SH 
				is_any_MH 
				is_outpatient_visit_1 is_outpatient_visit_2 
				is_intensive_outpatient_1 is_intensive_outpatient_2
				is_virtual_checkin is_obs   
				is_community_mental_health 
				is_electro 
				is_telehealth is_telephone;
run;

proc sort data=flag_num_event_22; 
	by membno dfrdos_new; 
run;

data followup_summary; 
	set flag_num_event_22; 
	keep membno dfrdos_new _7days _30days followup_days; 
run; 

proc sort data=followup_summary out=followup_summary_de nodupkey; 
	by membno dfrdos_new; 
run; 

proc freq data=followup_summary_de; 
	tables _7days _30days; 
run;

/* 7 days = 21.79%
	30 days = 36.32% 
*/ 


