/* Use 2024 dataset to do test, since this dataset is 25 times smaller than 2022 encounter data */ 

libname fmtlib "K:\IS-Resources\Resources\SAS Resources\TEXAS\FormatLib";
OPTIONS PS=MAX FORMCHAR="|----|+|---+=|-/\<>*" MPRINT fmtsearch=(fmtlib);

* we are going to use 2022 dataset, for testing and verify; 
libname ST "K:\TX-Data\Datasets\STAR";
libname valueset "K:\TX-Data\Datasets\HEDIS\HEDIS VALUE SET\HEDIS MY2022\data\final";
libname temp "\\fed-ad.ufl.edu\T001\user\mydocs\jiang.shao\Desktop\hedis_dev\out";

* import STAR encounter and enrollment dataset;
data star_enr_24; 
	set ST.star_enr_nodual_cy2024 (keep=membno bthdat sexcod plancod program qsi_race qsi_ethnicity v21_race v21_ethnicity county_cd C2: ); 
run;

data star_enc_24; 
	set ST.star_enc_cy2024 (keep=membno bdate plancod dschstat dfrdos dtodos diagn1-diagn25 surg1-surg25 typbill transtype svccod revcod poscod); 
run;

%put &code_system_CPT; 

data star_enc_all_flagged_2024; 
	set star_enc_24; 

	revcod = strip(revcod); 
	poscod = strip(poscod); 
	svccod = strip(svccod); 

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

proc freq data=star_enc_all_flagged_2024; 
tables is_icd10cm is_icd10pcs is_cpt is_ubrev is_hcpcs is_pos; 
run;

proc freq data=star_enc_all_flagged_2024; 
tables diagnosis; 
run;

data star_enc_all_flagged_2024_denom; 
	set star_enc_all_flagged_2024; 

	is_ED = 0; 
	if revcod in: (&ED_ubrev) or svccod in: (&ED_CPT) then is_ED = 1; 

	is_mental_ill = 0; 
	diagnosis = compress(upcase(diagn1), ' .'); 
	if diagn1 in: (&intentional_self_harm_icd10cm) or diagn1 in: (&mental_illness_icd10cm) then is_mental_ill = 1; 

	if is_ED = 1 AND is_mental_ill = 1
	then output; 
run;

%put &mental_illness_icd10cm; 

proc freq data=star_enc_all_flagged_2024_denom; 
	tables is_ED is_mental_ill; 
run;


data enc_all_inp_2024; 
	set star_enc_all_flagged_2024; 

	is_inp = 0; 
	if revcod in: (&inpatient_stay_ubrev) then do; 
		is_inp = 1; 
		inp_admin = dfrdos;
		output; 
	end;

	keep revcod membno is_inp inp_admin dfrdos dtodos; 
run;

%put &inpatient_stay_ubrev;

proc sort data=star_enc_all_flagged_2024_denom; by membno dfrdos; run;
proc sort data=enc_all_inp_2024; by membno dfrdos; run;

/*data enc_all_denom_noinp_2024; */
/*	merge star_enc_all_flagged_2024_denom (in=a)*/
/*				enc_all_inp_2024 (in=b); */
/*	by membno; */
/*	if a and (b and is_inp ne 1 or b and dfrdos = . or not b); */
/*	retain is_inp dfrdos; */
/*	if b then do; */
/*		if a.dfrdos <= dfrdos <= intx('day', a.dfrdos, 30) then delete; */
/*	end; */
/*run;*/

proc sql;
    create table enc_all_denom_noinp_2024 as
    select a.*
    from star_enc_all_flagged_2024_denom as a
        left join enc_all_inp_2024 as b
        on a.membno = b.membno
        and a.dfrdos <= b.inp_admin <= intnx('day', a.dtodos, 30)
    where b.is_inp ne 1 or b.inp_admin = .
    order by a.membno, a.dfrdos;
quit;

data enc_denom_noinp_no31_24;
    set enc_all_denom_noinp_2024;
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

data enc_all_hospice_2024; 
	set star_enc_all_flagged_2024; 

	is_hospice = 0; 
	if revcod in: (&hospice_enc_ubrev) then is_hospice = 1; 
	if svccod in: (&hospice_enc_hcpcs) then is_hospice = 1; 
	if svccod in: (&hospice_interv_cpt) then is_hospice = 1; 
	if svccod in: (&hospice_interv_hcpcs) then is_hospice = 1; 
	
	if is_hospice = 1 then output; 
	keep membno revcod svccod is_hospice; 
run;


/*  num */ 
proc sql;
    create table star_ed_followup_24 as
    select a.*
        ,b.ED_Admit_Date
        ,b.ED_Discharge_Date
    from star_enc_all_flagged_2024 as a
        join enc_denom_noinp_no31_24 as b
        on a.membno = b.membno
        and b.ED_Admit_Date <= a.dfrdos <= intnx('day', b.ED_Discharge_Date, 30)
    order by a.membno, a.dfrdos;
    ;
quit;

* identify follow-up visits and date;
data flag_FollowUp_24;

    set star_ed_followup_24;

    * a principal diagnosis of a mental health disorder;
    * a principal diagnosis of intentional self-harm and any diagnosis of a mental health disorder;
    flag_principal_MentalHealth = 0;
    flag_principal_SelfHarm = 0;
    primary_dx = compress(upcase(diagn1), ' .');
    if primary_dx in: (&intentional_self_harm_icd10cm) then flag_principal_SelfHarm = 1;
    if primary_dx in: (&mental_diagn_icd10cm) then flag_principal_MentalHealth = 1;
    
    flag_any_MentalHealth = 0;
    array diagns[25] diagn1-diagn25;
    do i = 1 to 25;
        if diagns[i] = "" then leave;
        dx = compress(upcase(diagns[i]), ' .');
        if dx in: (&mental_diagn_icd10cm) then do;
            flag_any_MentalHealth = 1;
            leave;
        end;
    end;

	 if flag_principal_MentalHealth = 1 or (flag_principal_SelfHarm = 1 and flag_any_MentalHealth = 1) then output; 
run;






libname test "E:\jiang.shao\Check_STAR_Health_and_MD_dental\temp"; 

proc freq data=test._41_star_ed_enc_all; 
tables revcod; 
run;

%put &part_hosp_pos; 


data flag_num_final; 
	set flag_num_event_22; 
	by membno dfrdos_new; 
	retain  _7days_flag _30days_flag; 

	if first.dfrdos_new then do; 
		_7days_flag = _7days; 
		_30days_flag = _30days; 
	end; 
	else do; 
		_7days_flag = max(_7days_flag, _7days); 
		_30days_flag = max(_30days_flag, _30days); 
	end; 

	if last.dfrdos_new then do; 
		_7days_flag = max(_7days_flag, _7days); 
		_30days_flag = max(_30days_flag, _30days); 
		output; 
	end; 

	keep membno dfrdos_new _7days_flag _30days_flag ; 
run;
