libname final 'C:\Users\ksomkul\Desktop\ANA 610 Final Project Data';

proc import datafile='C:\Users\ksomkul\Desktop\ANA 610 Final Project Data\fortune_credit.csv' 
	out=work.credit replace; run;

/*== DATA AUDIT ==*/
*1;
proc contents data=work.credit; run;

proc means data=work.credit n nmiss min mean median max; 
	var ssn fico_scr; run;
*2;
proc contents data=final.fortune_acct; run;

proc means data=final.fortune_acct n nmiss min mean median max; 
	var DailyRate
		HourlyRate
		MonthlyIncome
		PercentSalaryHike
		employee_no; run;

proc freq data=final.fortune_acct;
	table Department
		OverTime
		PerformanceRating
		StockOptionLevel ; run;

data work.char_ssn ; set final.fortune_acct ; 
	ssn_no=length(ssn_no); run;
	proc means data=work.char_ssn  n nmiss min mean median max; 
	var ssn_no   ; run;

*3;
proc contents data=final.fortune_attrition; run;

proc means data=final.fortune_attrition n nmiss min mean median max; 
	var employee_no; run;

proc tabulate data=final.fortune_attrition;
	var depart_dt;
	table depart_dt, n nmiss (min max)*f=mmddyy10.; run;
data work.year_attrition; set final.fortune_attrition; 
	year_depart_dt=year(depart_dt); run; 
proc freq data=work.year_attrition;
	table year_depart_dt; run;

*4;
proc contents data=final.fortune_hr; run;

proc means data= final.fortune_hr n nmiss min mean median max;run;

proc freq data=final.fortune_hr; 
	table Education
	EducationField
	Gender
	birth_state; run;

data work.char_fortune_hr; set final.fortune_hr; 
	len_fst_nm=length(fst_nm); run;
proc means data=work.char_fortune_hr n nmiss min mean median max; 
	var len_fst_nm ; run;

proc tabulate data=final.fortune_hr;
	var birth_dt hire_dt;
	table birth_dt hire_dt,  n nmiss (min max)*f=mmddyy10.; run;
data work.year_fortune_hr; set final.fortune_hr; 
	year_birth_dt=year(birth_dt);
year_hire_dt=year(hire_dt);
run; 
proc freq data=work.year_fortune_hr;
	table year_birth_dt year_hire_dt; run;
*5;
proc contents data=final.fortune_survey; run;

proc means data=final.fortune_survey n nmiss min mean median max; 
	var DistanceFromHome NumCompaniesWorked TotalWorkingYears  YearsInCurrentRole
		YearsSinceLastPromotion YearsWithCurrManager employee_no TrainingTimesLastYear; run;

proc freq data=final.fortune_survey;
	table EnvironmentSatisfaction JobInvolvement JobLevel JobSatisfaction
		MaritalStatus RelationshipSatisfaction WorkLifeBalance BusinessTravel ; run;

/*== MERGE FILES ==*/
	*merge 3 files = hr,survey, and attrition;
proc sort data=final.fortune_attrition; by employee_no; run;
proc sort data=final.fortune_hr ; by employee_no; run;
proc sort data=final.fortune_survey ; by employee_no; run;
	data work.employ_no; merge final.fortune_attrition final.fortune_hr final.fortune_survey ; by employee_no; run;
	
	*back to acct file;
	*clean "-" in ssn, and make numeric (fortune_acct file);
data work.one; set final.fortune_acct;
ssn_1 = compress(ssn, " - -- ");
if length(ssn_1) = 9 then valid_ssn = "Yes"; else valid_ssn = "No";
ssn_n = input(ssn_1,9.); run;

data work.acct work.review; set work.one; keep employee_no ssn_n;
	if valid_ssn = "Yes" then output work.acct; else output work.review; run;

proc print data= work.acct (firstobs = 1 obs=20); run; 
proc sql; select count(*) into : nobs from work.acct; quit;

proc print data= work.review (firstobs = 1 obs=20); run; 
proc sql; select count(*) into : nobs from work.review; quit;
	*NOTE: no obs in work.review, which means all ssn values are valid;

	*back to credit file;
proc contents data=work.credit; run;
data work.credit; set work.credit;
rename ssn = ssn_n; run;

	*merge credit with acct;
proc sort data=work.one; 	by ssn_n; run;
proc sort data=work.credit; by ssn_n; run;
	data work.credit_acct; merge work.one work.credit; by ssn_n; run;
 	*merge acct with hr, survey, and attrition;
proc sort data=work.employ_no; 		by employee_no; run;
proc sort data=work.credit_acct; 	by employee_no; run;
	data work.master_exploy; merge work.employ_no work.credit_acct; by employee_no; run;

	*save a master file;
data final.master_employ; set work.master_exploy; drop ssn ssn_1 valid_ssn; run;

/*== MODELING SAMPLE ==*/
proc means data=final.master_employ n nmiss; run;
data work.master_employ; set final.master_employ;
	if  depart_dt notin(.)
	then employee_attritioned = 1;
	else employee_attritioned = 0;

	if JobSatisfaction in(1,2,3,4)
	then took_survey = 1;
	else took_survey = 0;
run;
proc freq data=work.master_employ;
table took_survey employee_attritioned ; run;

data work.target; set work.master_employ;
	if employee_attritioned = 1 and took_survey = 1
	then Retain_q = 1; 
	if employee_attritioned = 0 and took_survey = 1
	then Retain_q = 0;
run;
proc freq data=work.target;
table retain_q; run;

/*find # of target sample*/
	*employees who artritioned (left the company);
proc sql; select count(*) as obs_count from work.target 
where employee_attritioned = 1; run;
	*employees who artritioned and took the survey;
proc sql; select count(*) as obs_count from work.target 
where employee_attritioned = 1 and took_survey = 1; run;	

/*find # of non-target sample*/
	*employees who did not artrition;
proc sql; select count(*) as obs_count from work.target 
where employee_attritioned = 0 ; run;
	*employees who did not artrition and took the survey;
proc sql; select count(*) as obs_count from work.target 
where employee_attritioned = 0 and took_survey = 1; run;

	*save score model file;
data final.master_employ; set work.target; rename ssn_n = ssn; run;

/*== DATA CLEASING ==*/
proc contents data=final.master_employ; run;

/*DATA INTEGRITY*/
*===> duplicate values;
proc sql; select count(*) into : nobs from final.master_employ; quit;

proc sort data=final.master_employ out=work.clean nodupkey; by employee_no; run; 
proc sql; select count(*) into : nobs from work.clean; quit;

*exclude all employee who did not took the survey;
proc contents data=work.clean; run;

%let anal_var = BusinessTravel
DailyRate Department DistanceFromHome Education EducationField
EnvironmentSatisfaction Gender HourlyRate JobInvolvement JobLevel
JobSatisfaction MaritalStatus MonthlyIncome NumCompaniesWorked
OverTime PercentSalaryHike PerformanceRating RelationshipSatisfaction Retain_q
StockOptionLevel TotalWorkingYears TrainingTimesLastYear
WorkLifeBalance YearsInCurrentRole YearsSinceLastPromotion YearsWithCurrManager
birth_dt birth_state depart_dt employee_attritioned employee_no
fico_scr first_name hire_dt ssn took_survey;

data work.qualified; set work.clean;
	keep &anal_var;
	where retain_q notin(.); run;

*===> checking Numeric data;
proc contents data=work.qualified out=work.contents; run;
proc sql; select NAME into : num_vars separated by ' ' from work.contents where TYPE =1; quit;
proc means data=work.qualified n nmiss min mean median max; var &num_vars; run;

*===> checking Character data;
proc sql; select NAME into : char_vars separated by ' ' from work.contents where TYPE =2; quit;
proc sql; select NAME into : cat_vars separated by ' ' from work.contents where TYPE =2 
	and NAME notin("first_name")and NAME notin("birth_state"); quit;
proc freq data=work.qualified; table &cat_vars; run;

*===> checking Date data;
Proc means data=work.qualified; var birth_dt hire_dt depart_dt; run;

*===> check the consistency of variable;

/*check how dirty data is >> clean it*/
*SSN - we cannot make digits because it has "-" which is non-numeric, so we have to change it to numeric;
	/*Before remove "-" (raw file from fortune_acct)*/
proc freq data=final.fortune_acct; table ssn ; run;
	/*after remove "-"*/
proc freq data=final.master_employ; table ssn ; run;

/*coding error*/

*educationfield and dapartment;
data work.qualified; set work.qualified;
	if educationfield in ("Human Resources") 		then EducationField_2 = "Human Resources";
	if educationfield in ("LS","Life Sciences") 	then EducationField_2 = "Life Sciences";
	if educationfield in ("Mkt","Marketing") 		then EducationField_2 = "Marketing";
	if educationfield in ("Medical") 				then EducationField_2 = "Medical";
	if educationfield in ("Other") 					then EducationField_2 = "Other";
	if educationfield in ("Tech","Technical Degree") then EducationField_2 = "Technical"; 

	if Department in ("Human Resources") 						then Department_2 = "Human Resources";
	if Department in ("Research & D","Research & Development") 	then Department_2 = "Research & D";
	if Department in ("Sales") 									then Department_2 = "Sales";
run;

proc freq data=work.qualified; table educationfield_2 Department_2; run;

*===> missing values;

*check missing;
proc means data = work.qualified n nmiss; run;

proc format; value $misscnt "  " = "Missing" other = 'Nonmissing'; run;
proc freq data=work.qualified;
	tables _character_ /  nocum missing;
	format _character_ $misscnt.;
run;

*check histogram;
proc univariate data=work.qualified;
var	DailyRate
	MonthlyIncome; histogram / normal; run;

	*Dailyrate - median imputation;
data work.indicator; set work.qualified;
	array red dailyrate;
	do i = 1 to dim(red);
		if red(i) in (.) then dailyrate_mi_dum = 1; else dailyrate_mi_dum = 0;
	end;
	drop i; run;

proc means data=work.indicator sum; var dailyrate_mi_dum; run;

proc stdize data=work.indicator
	method=median
	reponly
	out=work.imputed; 
	var dailyrate; run;

data work.imputed; set work.imputed (rename =(dailyrate = dailyrate_mi));
	keep employee_no dailyrate_mi dailyrate_mi_dum; run;

proc sort data=work.indicator;  by employee_no; run;
proc sort data=work.imputed; 	by employee_no; run;

data work.master_employ_mi; merge work.indicator work.imputed; by employee_no; run;

proc univariate data=work.master_employ_mi;
	var dailyrate_mi; histogram / normal ; run;

	*Monthlyincome - median imputation;
data work.indicator2; set work.master_employ_mi;
	array red monthlyincome;
	do i = 1 to dim(red);
		if red(i) in (.) then monthlyincome_mi_dum = 1; else monthlyincome_mi_dum = 0;
	end;
	drop i; run;

proc means data=work.indicator2 sum; var monthlyincome_mi_dum; run;

proc stdize data=work.indicator2
	method=median
	reponly
	out=work.imputed2; 
	var monthlyincome; run;

data work.imputed2; set work.imputed2 (rename =(monthlyincome = monthlyincome_mi));
	keep employee_no monthlyincome_mi monthlyincome_mi_dum; run;

proc sort data=work.indicator2;  by employee_no; run;
proc sort data=work.imputed2; 	by employee_no; run;

data work.master_employ_mi_2; merge work.indicator2 work.imputed2; by employee_no; run;

proc univariate data=work.master_employ_mi_2;
	var monthlyincome_mi; histogram / normal ; run;

	*Create minssing indicators for	Birth_dt;

data work.indicator3; set work.master_employ_mi_2;
	array red birth_dt;
	do i = 1 to dim(red);
		if red(i) in (.) then birth_dt_mi_dum = 1; else birth_dt_mi_dum = 0;
	end;
	drop i; 
run;

proc means data=work.indicator3 sum; 
	var birth_dt_mi_dum;
run;

data work.indicator3; set work.indicator3;
	keep employee_no 
	birth_dt_mi_dum; 
run;

proc sort data=work.master_employ_mi_2;  	by employee_no; run;
proc sort data=work.indocator3; 		 	by employee_no; run;

data work.master_employ_mi_3; merge work.indicator3 work.master_employ_mi_2; by employee_no; run;

	* Create category for missing for Birth_state and MaritalStatus;
data work.unknown_cat; set work.master_employ_mi_3; 
	if birth_state in(" ") then birth_state_cat = "OT"; 
	   else birth_state_cat = birth_state;
	if MaritalStatus in(" ") then MaritalStatus_cat = "Marital_other"; 
	   else MaritalStatus_cat = MaritalStatus;	
run;

proc freq data=work.unknown_cat; 
tables  birth_state_cat
		MaritalStatus_cat; run;

data work.clean2; set work.unknown_cat;
	drop dailyrate monthlyincome birth_state MaritalStatus; run;

data final.master_clean; set work.clean2; run;

*===> extreme values;
proc contents data=final.master_clean; run;

%let anal_var = DistanceFromHome
NumCompaniesWorked
TotalWorkingYears
YearsInCurrentRole
YearsSinceLastPromotion
YearsWithCurrManager
DailyRate_mi
HourlyRate
MonthlyIncome_mi
PercentSalaryHike
fico_scr
TrainingTimesLastYear;

proc univariate data=final.master_clean nextrobs=10;
	var TrainingTimesLastYear;
	histogram TrainingTimesLastYear / normal; run;

proc univariate data=final.master_clean nextrobs=10;
	var &anal_var;
	histogram &anal_var / normal; run;

	/*range checking*/
%let anal_var = NumCompaniesWorked;
proc print data=final.master_clean; var &anal_var;
	where &anal_var >= 9; run;

%let anal_var = YearsInCurrentRole;
proc print data=final.master_clean; var &anal_var;
	where &anal_var >= 16; run;

%let anal_var = YearsSinceLastPromotion;
proc print data=final.master_clean; var &anal_var;
	where &anal_var >= 15; run;

%let anal_var = YearsWithCurrManager;
proc print data=final.master_clean; var &anal_var;
	where &anal_var >= 17; run;

%let anal_var = DailyRate_mi;
proc print data=final.master_clean; var &anal_var;
	where &anal_var <= 100; run;

%let anal_var = MonthlyIncome_mi;
proc print data=final.master_clean; var &anal_var;
	where &anal_var >= 20000; run;

	/*cutoff Top and Bottom 1%*/
%let anal_var = NumCompaniesWorked;
%let anal_var = YearsInCurrentRole;
%let anal_var = YearsSinceLastPromotion;
%let anal_var = YearsWithCurrManager;
%let anal_var = DailyRate_mi;
%let anal_var = MonthlyIncome_mi;

proc univariate data=final.master_clean; 
	var &anal_var; histogram &anal_var;
	output out=work.tmp pctlpts= 1 99 pctlpre = percent;   run;
proc print data=work.tmp; run;

data work.hi_low; set final.master_clean;
	if _n_ = 1 then set work.tmp;

	if &anal_var le percent1
		then do; range = "low "; output; end;
	else if &anal_var ge percent99 
		then do; range = "high"; output; end; run;
proc sort data=work.hi_low; by &anal_var; run;
proc print data=work.hi_low; var employee_no &anal_var range;  run;

	/*standard diviation*/
%let anal_var = DailyRate_mi;
%let anal_var = MonthlyIncome_mi;

proc means data= final.master_clean noprint; var &anal_var;
	output out=work.std(drop = _freq_ _type_) mean= anal_var_mean std= anal_var_std; run;

proc print data=work.std; run;

%let n_std = 2;

data work.std_test; set final.master_clean;
	if _n_ = 1 then set work.std;
	if &anal_var le anal_var_mean - &n_std*anal_var_std then do;
		range = "low";
		output;
	end;
	else if &anal_var ge anal_var_mean + &n_std*anal_var_std then do;
		range = "high";
		output;
	end; 
run;

proc sort data=work.std_test; by descending &anal_var; run;		
proc print data=work.std_test; var employee_no &anal_var range; run;	

	/*Trimmed statistics*/
%let anal_var = DailyRate_mi;
%let anal_var = MonthlyIncome_mi;

proc rank data=final.master_clean(keep=employee_no &anal_var) out=work.tmp_rank groups = 20;
	var &anal_var;
	ranks anal_var_rank; run;

proc means data=work.tmp_rank; var &anal_var;
output out=work.tmp_stat(drop = _freq_ _type_) mean=anal_var_mean std=anal_var_std; 
where anal_var_rank notin(0,19); run;

proc print data=work.tmp_stat; run;

%let n_std = 3;
%let mult = 1.24;

data work.std_test;
	set final.master_clean;
	if _n_ = 1 then set work.tmp_stat;
	if &anal_var le anal_var_mean - &n_std*anal_var_std*&mult 
		then do; range = "low "; output; end;
	else if &anal_var ge anal_var_mean + &n_std*anal_var_std*&mult 
		then do; range = "high"; output; end; run;

proc sort data=work.std_test; by descending &anal_var; run;
proc print data=work.std_test; var employee_no &anal_var range; run;

	/*Interquartile range*/
%let anal_var = DailyRate_mi;
%let anal_var = MonthlyIncome_mi;

proc means data=final.master_clean noprint; var &anal_var;
	output out=work.tmp(drop = _freq_ _type_) q3 = upper q1 = lower qrange = IQR; run;
proc print data=work.tmp; run;

%let iqr_mult = 3;

data work.iqr_test;
	set final.master_clean;
	if _n_ = 1 then set work.tmp;
	if &anal_var lt lower - &iqr_mult*IQR  then do; 
		range = "low "; output; end;
	else if &anal_var gt upper + &iqr_mult*IQR then do;
		range = "high"; output; end; run;

proc sort data=work.iqr_test; by descending &anal_var; run;
proc print data=work.iqr_test; var employee_no &anal_var range; run;

	/*Cluster check*/
%macro clust_out(dsin,varlist,pmin,dsout);

proc fastclus data=&dsin maxc=50 maxiter=100 cluster=_clusterindex_ out=work.temp_clus noprint;
	var &varlist;
run;

proc freq data=work.temp_clus noprint;
	tables _clusterindex_ / out=work.temp_freq;
run;

data work.temp_low; set work.temp_freq;
	if percent < &pmin; _outlier_ = 1;
	keep _clusterindex_ _outlier_;
run; 

proc sort data=work.temp_clus; by _clusterindex_; run;
proc sort data=work.temp_low; by _clusterindex_; run;

data &dsout; merge work.temp_clus work.temp_low; by _clusterindex_;
	if _outlier_ = . then _outlier_ = 0;
run;

proc print data=&dsout; var &varlist _outlier_; where _outlier_ = 1; run;

%mend;

%let anal_var = DailyRate_mi;
%let anal_var = MonthlyIncome_mi;

%clust_out(final.master_clean, &anal_var, .070, work.clus_out);

	/*Check extreme values in date data*/
proc univariate data=final.master_clean nextrobs=10;
	var depart_dt;
	histogram depart_dt / normal; run;

proc univariate data=final.master_clean nextrobs=10;
	var depart_dt; where employee_attritioned notin(0);
	histogram depart_dt / normal; run;

proc univariate data=final.master_clean nextrobs=10;
	var birth_dt;
	histogram birth_dt / normal; run;

proc univariate data=final.master_clean nextrobs=10;
	var birth_dt; where birth_dt_mi_dum = 0;
	histogram birth_dt / normal; run;

proc univariate data=final.master_clean nextrobs=10;
	var  hire_dt; 
	histogram  hire_dt / normal; run;

Proc freq data=final.master_clean;
	table hire_dt; run;

	/*Flag the oulier*/
data final.master_clean; set final.master_clean;
	if dailyrate_mi lt 100 then dailyrate_outlier = 1;
	else dailyrate_outlier = 0;
	if monthlyincome_mi ge 20000 then monthlyincome_outlier = 1;
	else monthlyincome_outlier = 0; 
	if hire_dt lt mdy(6,1,1980) then hire_dt_outlier = 1;
	else hire_dt_outlier = 0; ;run;

proc freq data=final.master_clean; table dailyrate_outlier monthlyincome_outlier hire_dt_outlier; run;


proc contents data=final.master_clean; run;

*===> extreme distribution;
%let anal_var = DistanceFromHome
NumCompaniesWorked
TotalWorkingYears
YearsInCurrentRole
YearsSinceLastPromotion
YearsWithCurrManager
DailyRate_mi
HourlyRate
MonthlyIncome_mi
PercentSalaryHike
fico_scr
TrainingTimesLastYear;
	*check skewness values;
proc univariate data=final.master_clean;
	var &anal_var; histogram; run;

	*taming distribution (transformation);
%let emp_var=MonthlyIncome_mi;

data work.tmp; set final.master_clean ;
	if &emp_var ne 0 then do;
		sqrt_emp_var = sqrt(&emp_var);
		sq_emp_var=(&emp_var*&emp_var);
		log_emp_var = log(&emp_var);
		inv_emp_var = 1/(&emp_var);
		inv_sqrt_emp_var= 1/(sqrt(&emp_var));
		inv_sq_emp_var= 1/(&emp_var*&emp_var);
		end;
	else do;
		sqrt_emp_var = 0;
		sq_emp_var=0;
		log_emp_var = 0;
		inv_emp_var = 0;
		inv_sqrt_emp_var=0;
		inv_sq_emp_var=0;
		end;
run;

proc univariate data=work.tmp nextrobs=10 normal; 
	var inv_emp_var sqrt_emp_var log_emp_var inv_sqrt_emp_var inv_sq_emp_var sq_emp_var;
	histogram  / normal;
run;
	*NOTE: invert square root yields the lowest skewness value;

	*compare before and after taming;
proc univariate data=work.tmp nextrobs=10 normal; 
	var inv_sqrt_emp_var monthlyincome_mi;
	histogram  / normal;
run;
	*save inv_sqrt_emp_var;
data final.master_clean; set work.tmp; drop inv_emp_var sqrt_emp_var log_emp_var inv_sq_emp_var sq_emp_var; 
rename inv_sqrt_emp_var = inv_sqrt_monthlyincome_mi; run;


/*== Feature Engineering ==*/
data work.master_clean; set final.master_clean; run;

*===> cardinality;
%let cat_var = BusinessTravel;
%let cat_var = Department_2;
%let cat_var = Education;
%let cat_var = EducationField_2;
%let cat_var = EnvironmentSatisfaction;
%let cat_var = Gender;
%let cat_var = JobInvolvement;
%let cat_var = JobLevel;
%let cat_var = JobSatisfaction;
%let cat_var = MaritalStatus_cat;
%let cat_var = OverTime;
%let cat_var = PerformanceRating;
%let cat_var = RelationshipSatisfaction;
%let cat_var = StockOptionLevel;
%let cat_var = WorkLifeBalance;
%let cat_var = birth_state_cat;
%let cat_var = employee_attritioned;
%let cat_var = took_survey;
%let cat_var = Retain_q;
%let cat_var = monthlyincome_mi_dum;
%let cat_var = birth_dt_mi_dum;
%let cat_var = dailyrate_mi_dum;
%let cat_var = dailyrate_outlier;
%let cat_var = hire_dt_outlier;
%let cat_var = monthlyincome_outlier;

proc contents data=work.master_clean out=work.cat_cont; run;
data work.cat_cont; set work.cat_cont; keep name nobs; run;

proc freq data=work.master_clean noprint; table &cat_var / out=work.cat_counts; run;
proc freq data=work.cat_counts noprint; table &cat_var / out=work.cat_counts; run;
proc sql; select count(*) into: TotalCats from work.cat_counts; quit;

data work.new; set work.cat_cont; where name ="&cat_var"; 
	level = scan("&TotalCats", _n_);
	card_ratio = level/nobs;
run;

proc print data=work.new; run;


*===> Recoding;

/*Dummy Coding:*/
data work.dummy; set work.master_clean;
	
	Education_dum_1 = (Education="1");
	Education_dum_2 = (Education="2"); 
	Education_dum_3 = (Education="3"); 
	Education_dum_4 = (Education="4"); 
	Education_dum_5 = (Education="5"); 

	EduField2_dum_HR = (EducationField_2 = "Human Resources");
	EduField2_dum_LS = (EducationField_2 ="Life Sciences"); 
	EduField2_dum_MKT = (EducationField_2 ="Marketing"); 
	EduField2_dum_MD = (EducationField_2 ="Medical"); 
	EduField2_dum_OT = (EducationField_2 ="Other"); 
	EduField2_dum_Tech = (EducationField_2="Technical");

	joblevel_dum_1 = (joblevel="1");
	joblevel_dum_2 = (joblevel="2"); 
	joblevel_dum_3 = (joblevel="3"); 
	joblevel_dum_4 = (joblevel="4"); 
	joblevel_dum_5 = (joblevel="5");

	Department_2_dum_HR = (Department_2="Human Resources");
	Department_2_dum_RD = (Department_2="Research & D"); 
	Department_2_dum_Sales = (Department_2="Sales"); 

	EnvironmentSatisfaction_dum_1 = (EnvironmentSatisfaction="1");
	EnvironmentSatisfaction_dum_2 = (EnvironmentSatisfaction="2"); 
	EnvironmentSatisfaction_dum_3 = (EnvironmentSatisfaction="3"); 
	EnvironmentSatisfaction_dum_4 = (EnvironmentSatisfaction="4"); 

	JobInvolvement_dum_1 = (JobInvolvement="1");
	JobInvolvement_dum_2 = (JobInvolvement="2"); 
	JobInvolvement_dum_3 = (JobInvolvement="3"); 
	JobInvolvement_dum_4 = (JobInvolvement="4"); 

	JobSatisfaction_dum_1 = (JobSatisfaction="1");
	JobSatisfaction_dum_2 = (JobSatisfaction="2"); 
	JobSatisfaction_dum_3 = (JobSatisfaction="3"); 
	JobSatisfaction_dum_4 = (JobSatisfaction="4"); 

	MaritalStatus_cat_dum_D = (MaritalStatus_cat="Divorced");
	MaritalStatus_cat_dum_M = (MaritalStatus_cat="Married"); 
	MaritalStatus_cat_dum_S = (MaritalStatus_cat="Single");

	RelationshipSatisfaction_dum_1 = (RelationshipSatisfaction="1");
	RelationshipSatisfaction_dum_2 = (RelationshipSatisfaction="2"); 
	RelationshipSatisfaction_dum_3 = (RelationshipSatisfaction="3"); 
	RelationshipSatisfaction_dum_4 = (RelationshipSatisfaction="4"); 

	StockOptionLevel_dum_0 = (StockOptionLevel="0");
	StockOptionLevel_dum_1 = (StockOptionLevel="1"); 
	StockOptionLevel_dum_2 = (StockOptionLevel="2"); 
	StockOptionLevel_dum_3 = (StockOptionLevel="3"); 

	WorkLifeBalance_dum_1 = (WorkLifeBalance="1");
	WorkLifeBalance_dum_2 = (WorkLifeBalance="2"); 
	WorkLifeBalance_dum_3 = (WorkLifeBalance="3"); 
	WorkLifeBalance_dum_4 = (WorkLifeBalance="4"); 

	BusinessTravel_dum_TFreq = (BusinessTravel="Travel_Frequently");
	BusinessTravel_dum_TRare = (BusinessTravel="Travel_Rarely"); 
	BusinessTravel_dum_NonT = (BusinessTravel="Non-Travel"); 

	gender_dum_F = (gender="Female");
	gender_dum_M = (gender="Male"); 
	gender_dum_NA = (gender="N/A"); 

	OverTime_dum_Y = (OverTime="Yes");
	OverTime_dum_N = (OverTime="No");

	PerformanceRating_dum_3 = (PerformanceRating="3"); 
	PerformanceRating_dum_4 = (PerformanceRating="4"); 

	Birth_State_dum_AK = (Birth_State_cat="AK"); 
	Birth_State_dum_AL = (Birth_State_cat="AL"); 
	Birth_State_dum_AR = (Birth_State_cat="AR"); 
	Birth_State_dum_AZ = (Birth_State_cat="AZ"); 
	Birth_State_dum_CA = (Birth_State_cat="CA"); 
	Birth_State_dum_CO = (Birth_State_cat="CO"); 
	Birth_State_dum_CT = (Birth_State_cat="CT"); 
	Birth_State_dum_DC = (Birth_State_cat="DC"); 
	Birth_State_dum_DE = (Birth_State_cat="DE"); 
	Birth_State_dum_FL = (Birth_State_cat="FL"); 
	Birth_State_dum_GA = (Birth_State_cat="GA"); 
	Birth_State_dum_HI = (Birth_State_cat="HI"); 
	Birth_State_dum_IA = (Birth_State_cat="IA"); 
	Birth_State_dum_ID = (Birth_State_cat="ID"); 
	Birth_State_dum_IL = (Birth_State_cat="IL"); 
	Birth_State_dum_IN = (Birth_State_cat="IN"); 
	Birth_State_dum_KS = (Birth_State_cat="KS"); 
	Birth_State_dum_KY = (Birth_State_cat="KY"); 
	Birth_State_dum_LA = (Birth_State_cat="LA"); 
	Birth_State_dum_MA = (Birth_State_cat="MA"); 
	Birth_State_dum_MD = (Birth_State_cat="MD"); 
	Birth_State_dum_ME = (Birth_State_cat="ME"); 
	Birth_State_dum_MI = (Birth_State_cat="MI"); 
	Birth_State_dum_MN = (Birth_State_cat="MN"); 
	Birth_State_dum_MO = (Birth_State_cat="MO"); 
	Birth_State_dum_MS = (Birth_State_cat="MS"); 
	Birth_State_dum_MT = (Birth_State_cat="MT"); 
	Birth_State_dum_NC = (Birth_State_cat="NC"); 
	Birth_State_dum_ND = (Birth_State_cat="ND"); 
	Birth_State_dum_NE = (Birth_State_cat="NE"); 
	Birth_State_dum_NH = (Birth_State_cat="NH"); 
	Birth_State_dum_NJ = (Birth_State_cat="NJ"); 
	Birth_State_dum_NM = (Birth_State_cat="NM"); 
	Birth_State_dum_NV = (Birth_State_cat="NV"); 
	Birth_State_dum_NY = (Birth_State_cat="NY"); 
	Birth_State_dum_OH = (Birth_State_cat="OH"); 
	Birth_State_dum_OK = (Birth_State_cat="OK"); 
	Birth_State_dum_OR = (Birth_State_cat="OR"); 
	Birth_State_dum_PA = (Birth_State_cat="PA");
	Birth_State_dum_RI = (Birth_State_cat="RI"); 
	Birth_State_dum_SC = (Birth_State_cat="SC"); 
	Birth_State_dum_SD = (Birth_State_cat="SD"); 
	Birth_State_dum_TN = (Birth_State_cat="TN"); 
	Birth_State_dum_TX = (Birth_State_cat="TX"); 
	Birth_State_dum_UT = (Birth_State_cat="UT"); 
	Birth_State_dum_VT = (Birth_State_cat="VT"); 
	Birth_State_dum_OT = (Birth_State_cat="OT"); 
run;

%let dum_var = Education_dum_1 Education_dum_2 Education_dum_3 Education_dum_4 Education_dum_5
EduField2_dum_HR EduField2_dum_LS EduField2_dum_MKT EduField2_dum_MD EduField2_dum_OT EduField2_dum_Tech
joblevel_dum_1 joblevel_dum_2 joblevel_dum_3 joblevel_dum_4 joblevel_dum_5
Department_2_dum_HR Department_2_dum_RD Department_2_dum_Sales
EnvironmentSatisfaction_dum_1 EnvironmentSatisfaction_dum_2 EnvironmentSatisfaction_dum_3 EnvironmentSatisfaction_dum_4 
JobInvolvement_dum_1 JobInvolvement_dum_2 JobInvolvement_dum_3 JobInvolvement_dum_4 
JobSatisfaction_dum_1 JobSatisfaction_dum_2 JobSatisfaction_dum_3 JobSatisfaction_dum_4 
MaritalStatus_cat_dum_D MaritalStatus_cat_dum_M MaritalStatus_cat_dum_S
RelationshipSatisfaction_dum_1 RelationshipSatisfaction_dum_2 RelationshipSatisfaction_dum_3 RelationshipSatisfaction_dum_4
StockOptionLevel_dum_0 StockOptionLevel_dum_1 StockOptionLevel_dum_2 StockOptionLevel_dum_3
WorkLifeBalance_dum_1 WorkLifeBalance_dum_2 WorkLifeBalance_dum_3 WorkLifeBalance_dum_4 
BusinessTravel_dum_TFreq BusinessTravel_dum_TRare BusinessTravel_dum_NonT
gender_dum_F gender_dum_M gender_dum_NA
OverTime_dum_Y OverTime_dum_N
PerformanceRating_dum_3 PerformanceRating_dum_4
Birth_State_dum_AK Birth_State_dum_AL Birth_State_dum_AR Birth_State_dum_AZ Birth_State_dum_CA Birth_State_dum_CO
Birth_State_dum_CT Birth_State_dum_DC Birth_State_dum_DE Birth_State_dum_FL Birth_State_dum_GA Birth_State_dum_HI
Birth_State_dum_IA Birth_State_dum_ID Birth_State_dum_IL Birth_State_dum_IN Birth_State_dum_KS Birth_State_dum_KY 
Birth_State_dum_LA Birth_State_dum_MA Birth_State_dum_MD Birth_State_dum_ME Birth_State_dum_MI Birth_State_dum_MN
Birth_State_dum_MO Birth_State_dum_MS Birth_State_dum_MT Birth_State_dum_NC Birth_State_dum_ND Birth_State_dum_NE 
Birth_State_dum_NH Birth_State_dum_NJ Birth_State_dum_NM Birth_State_dum_NV Birth_State_dum_NY Birth_State_dum_OH 
Birth_State_dum_OK Birth_State_dum_OR Birth_State_dum_PA Birth_State_dum_RI Birth_State_dum_SC Birth_State_dum_SD
Birth_State_dum_TN Birth_State_dum_TX Birth_State_dum_UT Birth_State_dum_VT Birth_State_dum_OT;
 
proc means data=final.scored min mean max sum;
	var &dum_var; run;

proc means data=final.scored mean min max sum;
	var &dum_var; where retain_q = 1; run;

proc means data=final.scored mean min max sum;
	var &dum_var; where retain_q = 0; run;



/*CLUSTERING LEVELS*/
*1;
%let input_data 	= work.dummy; 
%let anal_var 		= birth_state_cat;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=50; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*merge  Birth_state_cat Cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored; merge &input_data work.clus2; by &anal_var; 
	B_state_dum_cus1=(cluster=1);
	B_state_dum_cus2=(cluster=2);
	B_state_dum_cus3=(cluster=3);
	B_state_dum_cus4=(cluster=4);
run;

%let dum_vars = B_state_dum_cus1 B_state_dum_cus2 B_state_dum_cus3 B_state_dum_cus4;

proc means data=work.scored sum; var &dum_vars; run;

	*check frequencies at the target-level;

proc sort data=work.scored; by &target_var; run;

proc means data=work.scored sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;




*3;
%let input_data 	= work.scored2; 
%let anal_var 		= EducationField_2;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=6; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored3; merge &input_data work.clus2; by &anal_var; 
	EduField_2_dum_cus1=(cluster=1);
	EduField_2_dum_cus2=(cluster=2);
run;

%let dum_vars = EduField_2_dum_cus1 EduField_2_dum_cus2;
proc means data=work.scored3 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored3; by &target_var; run;
proc means data=work.scored3 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;



*4;
%let input_data 	= work.scored3; 
%let anal_var 		= Education;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=5; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored4; merge &input_data work.clus2; by &anal_var; 
	Education_dum_cus1=(cluster=1);
	Education_dum_cus2=(cluster=2);
run;

%let dum_vars = Education_dum_cus1 Education_dum_cus2 ;
proc means data=work.scored4 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored4; by &target_var; run;
proc means data=work.scored4 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;


*5;
%let input_data 	= work.scored4; 
%let anal_var 		= JobLevel;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=5; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored5; merge &input_data work.clus2; by &anal_var; 
	JobLevel_dum_cus1=(cluster=1);
	JobLevel_dum_cus2=(cluster=2);
run;

%let dum_vars = JobLevel_dum_cus1 JobLevel_dum_cus2 ;
proc means data=work.scored5 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored5; by &target_var; run;
proc means data=work.scored5 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;

*6;
%let input_data 	= work.scored5; 
%let anal_var 		= Department_2;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=5; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored6; merge &input_data work.clus2; by &anal_var; 
	Department_2_dum_cus1=(cluster=1);
	Department_2_dum_cus2=(cluster=2);
run;

%let dum_vars = Department_2_dum_cus1 Department_2_dum_cus2 ;
proc means data=work.scored6 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored6; by &target_var; run;
proc means data=work.scored6 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;

*7;
%let input_data 	= work.scored6; 
%let anal_var 		= EnvironmentSatisfaction;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=5; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored7; merge &input_data work.clus2; by &anal_var; 
	EnvrmSat_dum_cus1=(cluster=1);
	EnvrmSat_dum_cus2=(cluster=2);
run;

%let dum_vars = EnvrmSat_dum_cus1 EnvrmSat_dum_cus2 ;
proc means data=work.scored7 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored7; by &target_var; run;
proc means data=work.scored7 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;


*8;
%let input_data 	= work.scored7; 
%let anal_var 		= JobInvolvement;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=5; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored8; merge &input_data work.clus2; by &anal_var; 
	JobInvolve_dum_cus1=(cluster=1);
	JobInvolve_dum_cus2=(cluster=2);
	JobInvolve_dum_cus3=(cluster=3);
run;

%let dum_vars = JobInvolve_dum_cus1 JobInvolve_dum_cus2 JobInvolve_dum_cus3;

proc means data=work.scored8 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored8; by &target_var; run;
proc means data=work.scored8 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;


*9;
%let input_data 	= work.scored8; 
%let anal_var 		= JobSatisfaction;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=5; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored9; merge &input_data work.clus2; by &anal_var; 
	JobSat_dum_cus1=(cluster=1);
	JobSat_dum_cus2=(cluster=2);
	JobSat_dum_cus3=(cluster=3);
run;

%let dum_vars = JobSat_dum_cus1 JobSat_dum_cus2 JobSat_dum_cus3;
proc means data=work.scored9 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored9; by &target_var; run;
proc means data=work.scored9 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;


*10;
%let input_data 	= work.scored9; 
%let anal_var 		= MaritalStatus_cat;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=5; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored10; merge &input_data work.clus2; by &anal_var; 
	Marital_cat_dum_cus1=(cluster=1);
	Marital_cat_dum_cus2=(cluster=2);
run;

%let dum_vars = Marital_cat_dum_cus1 Marital_cat_dum_cus2;
proc means data=work.scored10 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored10; by &target_var; run;
proc means data=work.scored10 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;



*11;
%let input_data 	= work.scored10; 
%let anal_var 		= RelationshipSatisfaction;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=5; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored11; merge &input_data work.clus2; by &anal_var; 
	RelationshipSat_dum_cus1=(cluster=1);
	RelationshipSat_dum_cus2=(cluster=2);
run;

%let dum_vars = RelationshipSat_dum_cus1 RelationshipSat_dum_cus2;
proc means data=work.scored11 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored11; by &target_var; run;
proc means data=work.scored11 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;



*12;
%let input_data 	= work.scored11; 
%let anal_var 		= StockOptionLevel;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=5; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored12; merge &input_data work.clus2; by &anal_var; 
	StockOpLv_dum_cus1=(cluster=1);
	StockOpLv_dum_cus2=(cluster=2);
run;

%let dum_vars = StockOpLv_dum_cus1 StockOpLv_dum_cus2;
proc means data=work.scored12 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored12; by &target_var; run;
proc means data=work.scored12 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;


*13;
%let input_data 	= work.scored12; 
%let anal_var 		= WorkLifeBalance;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=19; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored13; merge &input_data work.clus2; by &anal_var; 
	WorkLifeBalance_dum_cus1=(cluster=1);
	WorkLifeBalance_dum_cus2=(cluster=2);
run;

%let dum_vars = WorkLifeBalance_dum_cus1 WorkLifeBalance_dum_cus2;
proc means data=work.scored13 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored13; by &target_var; run;
proc means data=work.scored13 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;



*14;
%let input_data 	= work.scored13; 
%let anal_var 		= BusinessTravel;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=19; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored14; merge &input_data work.clus2; by &anal_var; 
	BusinessTravel_dum_cus1=(cluster=1);
	BusinessTravel_dum_cus2=(cluster=2);
run;

%let dum_vars = BusinessTravel_dum_cus1 BusinessTravel_dum_cus2;
proc means data=work.scored14 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored14; by &target_var; run;
proc means data=work.scored14 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;


*15;
%let input_data 	= work.scored14; 
%let anal_var 		= Gender;
%let target_var 	= retain_q; 

	*showing level proportions in the “yes” group;
 proc means data= &input_data noprint nway;
 	class &anal_var;
 	var &target_var;
 	output out=work.level mean = prop;
 run;
 proc print data=work.level; run;

 	*cluster the levels based on the proportions;
ods output clusterhistory=work.cluster;
proc cluster data=work.level method=ward outtree=work.fortree; 
	freq _freq_;
	var prop;
	id &anal_var;
run;

	*examine the hierarchical tree (dendrogram);
proc tree data=work.fortree out=work.treeout clusters=19; id &anal_var;  run;

	*find optimal number of clusters;
proc freq data=&input_data noprint;
table &anal_var*&target_var / chisq; output out=work.chi(keep=_pchi_) chisq; run;

data work.cutoff;
   if _n_=1 then set work.chi;
   set work.cluster;
   chisquare=_pchi_*rsquared;
   degfree=numberofclusters-1;
   logpvalue=logsdf('CHISQ',chisquare,degfree);
run;

	*Plot the log p-values;
proc gplot data=work.cutoff;
plot logpvalue*numberofclusters; run;

	*create a macro variable (&ncl) that contains the number of clusters associated with the minimum log p-value;
proc sql;
   select NumberOfClusters into :ncl
   from work.cutoff
   having logpvalue=min(logpvalue); quit;

	*create a dataset with the cluster solution;
proc tree data=work.fortree nclusters=&ncl out=work.clus;
   id &anal_var; run;

proc sort data=work.clus; by clusname; run;

title1 "Levels of Categorical Variable by Cluster";
proc print data=work.clus;
   by clusname;
   id clusname; run;

	*Merge cluster onto master file and create dummies;
data work.clus2; set work.clus; drop clusname; run;
proc sort data=work.clus2; 	by &anal_var; run;
proc sort data=&input_data; 	by &anal_var; run;
data work.scored15; merge &input_data work.clus2; by &anal_var; 
	Gender_dum_cus1=(cluster=1);
	Gender_dum_cus2=(cluster=2);
run;

%let dum_vars = Gender_dum_cus1 Gender_dum_cus2;
proc means data=work.scored15 sum; var &dum_vars; run;

	*check frequencies at the target-level;
proc sort data=work.scored15; by &target_var; run;
proc means data=work.scored15 sum;
	var &dum_vars; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = &dum_vars;
	by &target_var; where &target_var notin(.); run;
proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;
proc print data=work.tmp_sum_t; run;

	*save cluster dummy coding;
data final.scored; set work.scored15; run;




*===> TARGET-BASED ENUMERATION;
data work.scored; set final.scored; run;

*1;
%let target_var     = retain_q;
%let dataset 		= work.scored;
%let anal_var 	= birth_state_cat;


proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = Bstate_iv;
rename woe = Bstate_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final; merge work.level_sum &dataset; 	by &anal_var; run;



*3;
%let anal_var 	= EducationField_2;
%let target_var     = retain_q;
%let dataset 		= work.final2;


proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = Edufield2_iv;
rename woe = Edufield2_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final3; merge work.level_sum &dataset; 	by &anal_var; run;

*4;
%let anal_var 	= Education;
%let target_var     = retain_q;
%let dataset 		= work.final3;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = Edu_iv;
rename woe = Edu_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final4; merge work.level_sum &dataset; 	by &anal_var; run;

*5;
%let anal_var 	= JobLevel;
%let target_var     = retain_q;
%let dataset 		= work.final4;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = Joblevel_iv;
rename woe = JobLevel_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final5; merge work.level_sum &dataset; 	by &anal_var; run;


*6;
%let anal_var 	= EnvironmentSatisfaction;
%let target_var     = retain_q;
%let dataset 		= work.final5;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = EnvironmentSat_iv;
rename woe = EnvironmenrSat_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final6; merge work.level_sum &dataset; 	by &anal_var; run;


*7;
%let anal_var 	= JobInvolvement;
%let target_var     = retain_q;
%let dataset 		= work.final6;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = Jobenvolve_iv;
rename woe = Jobenvolve_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final7; merge work.level_sum &dataset; 	by &anal_var; run;


*8;
%let anal_var 	= JobSatisfaction;
%let target_var     = retain_q;
%let dataset 		= work.final7;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = JobSat_iv;
rename woe = JobSat_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final8; merge work.level_sum &dataset; 	by &anal_var; run;

*9;
%let anal_var 	= MaritalStatus_cat;
%let target_var     = retain_q;
%let dataset 		= work.final8;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = Marital_iv;
rename woe = Marital_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final9; merge work.level_sum &dataset; 	by &anal_var; run;



*10;
%let anal_var 	= RelationshipSatisfaction;
%let target_var     = retain_q;
%let dataset 		= work.final9;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = RelationshipSat_iv;
rename woe = RelationshipSat_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final10; merge work.level_sum &dataset; 	by &anal_var; run;


*11;
%let anal_var 	= StockOptionLevel;
%let target_var     = retain_q;
%let dataset 		= work.final10;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = Stock_iv;
rename woe = Stock_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final11; merge work.level_sum &dataset; 	by &anal_var; run;

*12;
%let anal_var 	= WorkLifeBalance;
%let target_var     = retain_q;
%let dataset 		= work.final11;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = WorkLifeBL_iv;
rename woe = WorkLifeBL_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final12; merge work.level_sum &dataset; 	by &anal_var; run;

*13;
%let anal_var 	= Department_2;
%let target_var     = retain_q;
%let dataset 		= work.final12;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = Department2_iv;
rename woe = Department2_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final13; merge work.level_sum &dataset; 	by &anal_var; run;



*14;
%let anal_var 	= BusinessTravel;
%let target_var     = retain_q;
%let dataset 		= work.final13;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = BusiTravel_iv;
rename woe = BusiTravel_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final14; merge work.level_sum &dataset; 	by &anal_var; run;


*15;
%let anal_var 	= Gender;
%let target_var     = retain_q;
%let dataset 		= work.final14;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = Gender_iv;
rename woe = Gender_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final15; merge work.level_sum &dataset; 	by &anal_var; run;


*16;
%let anal_var 	= OverTime;
%let target_var     = retain_q;
%let dataset 		= work.final15;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = OverTime_iv;
rename woe = OverTime_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final16; merge work.level_sum &dataset; 	by &anal_var; run;

*17;
%let anal_var 	= PerformanceRating;
%let target_var     = retain_q;
%let dataset 		= work.final16;

proc sort data=&dataset; by &anal_var; run;

	*calculate level data;
proc means data=&dataset sum noprint; var &target_var; by &anal_var;
	output out=work.level_sum (drop= _TYPE_ _STAT_) sum = events; run;

	*calculate total data;
proc means data=&dataset sum noprint; var &target_var;
	output out=work.total_sum (drop= _TYPE_ _STAT_) sum = tot_events; run;
data work.total_sum; set work.total_sum; drop _FREQ_;
	tot_non_events 	=	_FREQ_ - tot_events;
	tot_obs			= 	_FREQ_;
	tot_event_prob	=	tot_events/_FREQ_; run;

	*merge level with total data and compute stats;
data work.level_sum; 
	if _n_ = 1 then set work.total_sum; 
	set work.level_sum; 

		non_events 	= 	_freq_ - events;
		pct_events	=	(events/tot_events);
		pct_non_events 	= 	(non_events/tot_non_events);

		woe 		= 	log((events/tot_events)/(non_events/tot_non_events));
		iv		=	((events/tot_events)-(non_events/tot_non_events))*woe;
run;

	*print out results;
proc print data=work.level_sum;
	var &anal_var _freq_ events non_events pct_events pct_non_events woe iv; run;

	*get the variable-level IV;
proc sql; select sum(iv) into: IV from work.level_sum; quit;

	*Merge WOE and IV onin master file;
data work.level_sum; set work.level_sum; keep iv woe &anal_var; 
rename iv = PerformSat_iv;
rename woe = PerformSat_woe ;run;

proc sort data=work.level_sum;  					by &anal_var; run;
proc sort data=&dataset;							by &anal_var; run;
data work.final17; merge work.level_sum &dataset; 	by &anal_var; run;

	*save enumerated variables;
data final.scored; set work.final17; run;



/*THRESHOLD VARIABLES*/

*1;
data work.scored; set final.scored; 
	if Birth_State_cat="AK" then B_st_num = 1;  
	if Birth_State_cat="AL" then B_st_num = 2;  
	if Birth_State_cat="AR" then B_st_num = 3;  
	if Birth_State_cat="AZ" then B_st_num = 4;   
	if Birth_State_cat="CA" then B_st_num = 5;   
	if Birth_State_cat="CO" then B_st_num = 6;    
	if Birth_State_cat="CT" then B_st_num = 7;   
	if Birth_State_cat="DC" then B_st_num = 8;   
	if Birth_State_cat="DE" then B_st_num = 9;   
	if Birth_State_cat="FL" then B_st_num = 10;   
	if Birth_State_cat="GA" then B_st_num = 11;   
	if Birth_State_cat="HI" then B_st_num = 12;    
	if Birth_State_cat="IA" then B_st_num = 13;   
	if Birth_State_cat="ID" then B_st_num = 14;    
	if Birth_State_cat="IL" then B_st_num = 15;    
	if Birth_State_cat="IN" then B_st_num = 16;    
	if Birth_State_cat="KS" then B_st_num = 17;   
	if Birth_State_cat="KY" then B_st_num = 18;    
	if Birth_State_cat="LA" then B_st_num = 19;   
	if Birth_State_cat="MA" then B_st_num = 20;    
	if Birth_State_cat="MD" then B_st_num = 21;    
	if Birth_State_cat="ME" then B_st_num = 22;    
	if Birth_State_cat="MI" then B_st_num = 23;    
	if Birth_State_cat="MN" then B_st_num = 24;    
	if Birth_State_cat="MO" then B_st_num = 25;    
	if Birth_State_cat="MS" then B_st_num = 26;    
	if Birth_State_cat="MT" then B_st_num = 27;    
	if Birth_State_cat="NC" then B_st_num = 28;    
	if Birth_State_cat="ND" then B_st_num = 29;    
	if Birth_State_cat="NE" then B_st_num = 30;    
	if Birth_State_cat="NH" then B_st_num = 31;    
	if Birth_State_cat="NJ" then B_st_num = 32;    
	if Birth_State_cat="NM" then B_st_num = 33;    
	if Birth_State_cat="NV" then B_st_num = 34;    
	if Birth_State_cat="NY" then B_st_num = 35;    
	if Birth_State_cat="OH" then B_st_num = 36;    
	if Birth_State_cat="OK" then B_st_num = 37;    
	if Birth_State_cat="OR" then B_st_num = 38;    
	if Birth_State_cat="PA" then B_st_num = 39;   
	if Birth_State_cat="RI" then B_st_num = 40;    
	if Birth_State_cat="SC" then B_st_num = 41;    
	if Birth_State_cat="SD" then B_st_num = 42;    
	if Birth_State_cat="TN" then B_st_num = 43;    
	if Birth_State_cat="TX" then B_st_num = 44;    
	if Birth_State_cat="UT" then B_st_num = 45;    
	if Birth_State_cat="VT" then B_st_num = 46;    
	if Birth_State_cat="OT" then B_st_num = 47;
run;

%let input_data = final.scored; 
%let anal_var = b_st_num;
%let segment = retain_q;

	* finding freq;
proc freq data=&input_data order=freq; table &anal_var / out=work.freq (drop = percent);
proc print data=work.freq; run;
	* merge files and create dummies;
proc sort data=work.freq; 				by &anal_var; run;
proc sort data=&input_data; 			by &anal_var; run;

	*#1 at least 30 for each b_st_num;
data work.dummies; merge &input_data work.freq; by &anal_var;
	array 	red(5) B_st_ThDum_1 - B_st_Thdum_5;
			do i = 1 to dim(red); 
	if &anal_var = i and count ge 30 				then red(i) = 1; 			else red(i) = 0; end;
	if sum(of B_st_ThDum_1 - B_st_Thdum_5) = 0 	then B_st_ThDum_oth = 1; 	else B_st_ThDum_oth = 0; 
run;

	* check sum;
proc means data=work.dummies nmiss min mean max sum; 
var eB_st_ThDum_1 - B_st_Thdum_5 B_st_ThDum_oth; run;

	*#2 at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	array 	red(47) B_st_ThDum_1 - B_st_Thdum_47;
			do i = 1 to dim(red); 
	if (&anal_var = i and count_seg_0 ge 30 and count_seg_1 ge 30) 				
													then red(i) = 1; 			else red(i) = 0; end;
	if sum(of B_st_ThDum_1 - B_st_ThDum_47) = 0 	then B_st_ThDum_oth = 1; 	else B_st_ThDum_oth = 0; 
run;

	*check sums by target variable;
proc sort data=work.dummies_seg; by &segment; run;

proc means data=work.dummies_seg sum; 
	var B_st_ThDum_1 - B_st_ThDum_47 B_st_ThDum_oth; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = B_st_ThDum_1 - B_st_ThDum_47 B_st_ThDum_oth;
	by &segment; where &segment notin(.); run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored; set work.dummies_seg; run;


*2;
%let input_data = final.scored; 
%let anal_var = education;
%let segment = retain_q;

	* at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	if (education = 1 and count_seg_0 ge 30 and count_seg_1 ge 30) then edu_thdum1 = 1; else edu_thdum1 = 0; 
	if (education = 2 and count_seg_0 ge 30 and count_seg_1 ge 30) then edu_thdum2 = 1; else edu_thdum2 = 0; 
	if (education = 3 and count_seg_0 ge 30 and count_seg_1 ge 30) then edu_thdum3 = 1; else edu_thdum3 = 0; 
	if (education = 4 and count_seg_0 ge 30 and count_seg_1 ge 30) then edu_thdum4 = 1; else edu_thdum4 = 0; 
	if (education = 5 and count_seg_0 ge 30 and count_seg_1 ge 30) then edu_thdum5 = 1; else edu_thdum5 = 0; 
	if sum(of edu_thdum1 - edu_thdum5) = 0 		then edu_thdum_oth = 1; 	else edu_thdum_oth = 0; 
run;

	*check sums by target variable;
proc sort data=work.dummies; by &segment; run;

proc means data=work.dummies sum; 
	var edu_thdum1-edu_thdum5 edu_thdum_oth; output out=work.tmp_sum (drop = _TYPE_ _FREQ_ _STAT_)
	sum = edu_thdum1-edu_thdum5 edu_thdum_oth;
	by &segment; where &segment notin(.); run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored2; set work.dummies_seg; run;



*3;
%let input_data = work.scored; 
%let anal_var = educationfield_2;
%let segment = retain_q;

	* at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	if (educationField_2 = "Human Resources" and count_seg_0 ge 30 and count_seg_1 ge 30) then EduField2_thdum_HR = 1; else EduField2_thdum_HR = 0;
	if (EducationField_2 ="Life Sciences" and count_seg_0 ge 30 and count_seg_1 ge 30) then EduField2_thdum_LS = 1; else EduField2_thdum_LS = 0; 
	if (EducationField_2 ="Marketing" and count_seg_0 ge 30 and count_seg_1 ge 30) then EduField2_thdum_MKT = 1; else EduField2_thdum_MKT = 0; 
	if (EducationField_2 ="Medical" and count_seg_0 ge 30 and count_seg_1 ge 30) then EduField2_thdum_MD = 1; else EduField2_thdum_MD = 0; 
	if (EducationField_2 ="Other" and count_seg_0 ge 30 and count_seg_1 ge 30) then EduField2_thdum_OT = 1; else EduField2_thdum_OT = 0;
	if (EducationField_2="Technical" and count_seg_0 ge 30 and count_seg_1 ge 30) then EduField2_thdum_Tech = 1; else EduField2_thdum_Tech = 0;
	if (EduField2_thdum_HR and EduField2_thdum_LS and EduField2_thdum_MKT and EduField2_thdum_MD and EduField2_thdum_OT and EduField2_thdum_Tech) = 0 	then EduField2_thdum_Other = 1; 	else EduField2_thdum_Other = 0; 
run;


	*check sums by target variable;
proc sort data=work.dummies_seg; by &segment; run;

proc means data=work.dummies_seg sum; 
	var EduField2_thdum_HR EduField2_thdum_LS EduField2_thdum_MKT EduField2_thdum_MD EduField2_thdum_OT EduField2_thdum_Tech EduField2_thdum_Other; 
	output out=work.tmp_sum1 (drop = _TYPE_ _FREQ_ _STAT_)
	sum = EduField2_thdum_HR and EduField2_thdum_LS and EduField2_thdum_MKT and EduField2_thdum_MD and EduField2_thdum_OT and EduField2_thdum_Tech EduField2_thdum_Other;
	by &segment;  run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored3; set work.dummies_seg; run;


*4;
%let input_data = work.scored3; 
%let anal_var = joblevel;
%let segment = retain_q;

	* at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	if (joblevel = 1 and count_seg_0 ge 30 and count_seg_1 ge 30) then  joblv_thdum1 = 1; else joblv_thdum1 = 0; 
	if (joblevel = 2 and count_seg_0 ge 30 and count_seg_1 ge 30) then  joblv_thdum2 = 1; else joblv_thdum2 = 0; 
	if (joblevel = 3 and count_seg_0 ge 30 and count_seg_1 ge 30) then  joblv_thdum3 = 1; else joblv_thdum3 = 0; 
	if (joblevel = 4 and count_seg_0 ge 30 and count_seg_1 ge 30) then  joblv_thdum4 = 1; else joblv_thdum4 = 0; 
	if (joblevel = 5 and count_seg_0 ge 30 and count_seg_1 ge 30) then  joblv_thdum5 = 1; else joblv_thdum5 = 0; 
	if sum(of joblv_thdum1 - joblv_thdum5) = 0 		then joblv_thdum_oth = 1; 	else joblv_thdum_oth = 0; 
run;


	*check sums by target variable;
proc sort data=work.dummies_seg; by &segment; run;

proc means data=work.dummies_seg sum; 
	var joblv_thdum1 - joblv_thdum5 joblv_thdum_oth;
	output out=work.tmp_sum1 (drop = _TYPE_ _FREQ_ _STAT_)
	sum = joblv_thdum1 - joblv_thdum5 joblv_thdum_oth;
	by &segment;  run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored4; set work.dummies_seg; run;

*5;
%let input_data = work.scored4; 
%let anal_var = Department_2;
%let segment = retain_q;

	* at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	if (Department_2="Human Resources" and count_seg_0 ge 30 and count_seg_1 ge 30) then Department2_thdum_HR = 1; else Department2_thdum_HR = 0;
	if (Department_2="Research & D" and count_seg_0 ge 30 and count_seg_1 ge 30) then Department2_thdum_RD = 1; else Department2_thdum_RD = 0; 
	if (Department_2="Sales" and count_seg_0 ge 30 and count_seg_1 ge 30) then Department2_thdum_Sales = 1; else Department2_thdum_Sales = 0; 
	if sum(of Department2_thdum_HR Department2_thdum_RD Department2_thdum_Sales) = 0 	then Department2_thdum_other = 1; 	else Department2_thdum_other = 0; 
run;

	*check sums by target variable;
proc sort data=work.dummies_seg; by &segment; run;

proc means data=work.dummies_seg sum; 
	var Department2_thdum_HR Department2_thdum_RD Department2_thdum_Sales Department2_thdum_other;
	output out=work.tmp_sum1 (drop = _TYPE_ _FREQ_ _STAT_)
	sum = Department2_thdum_HR Department2_thdum_RD Department2_thdum_Sales Department2_thdum_other;
	by &segment;  run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored5; set work.dummies_seg; run;


*6;
%let input_data = work.scored5; 
%let anal_var = JobInvolvement;
%let segment = retain_q;

	* at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	if (JobInvolvement = 1 and count_seg_0 ge 30 and count_seg_1 ge 30) then  JobInvo_thdum1 = 1; else JobInvo_thdum1 = 0; 
	if (JobInvolvement = 2 and count_seg_0 ge 30 and count_seg_1 ge 30) then  JobInvo_thdum2 = 1; else JobInvo_thdum2 = 0; 
	if (JobInvolvement = 3 and count_seg_0 ge 30 and count_seg_1 ge 30) then  JobInvo_thdum3 = 1; else JobInvo_thdum3 = 0; 
	if (JobInvolvement = 4 and count_seg_0 ge 30 and count_seg_1 ge 30) then  JobInvo_thdum4 = 1; else JobInvo_thdum4 = 0; 
	if sum(of JobInvo_thdum1-JobInvo_thdum4) = 0 	then JobInvo_thdum_other = 1; 	else JobInvo_thdum_other = 0; 
run;

	*check sums by target variable;
proc sort data=work.dummies_seg; by &segment; run;

proc means data=work.dummies_seg sum; 
	var JobInvo_thdum1-JobInvo_thdum4 JobInvo_thdum_other;
	output out=work.tmp_sum1 (drop = _TYPE_ _FREQ_ _STAT_)
	sum = JobInvo_thdum1-JobInvo_thdum4 JobInvo_thdum_other;
	by &segment;  run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored6; set work.dummies_seg; run;

*7;
%let input_data = work.scored6; 
%let anal_var = StockOptionLevel;
%let segment = retain_q;

	* at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	if (StockOptionLevel = 0 and count_seg_0 ge 30 and count_seg_1 ge 30) then  Stock_thdum0 = 1; else Stock_thdum0 = 0; 
	if (StockOptionLevel = 1 and count_seg_0 ge 30 and count_seg_1 ge 30) then  Stock_thdum1 = 1; else Stock_thdum1 = 0; 
	if (StockOptionLevel = 2 and count_seg_0 ge 30 and count_seg_1 ge 30) then  Stock_thdum2 = 1; else Stock_thdum2 = 0; 
	if (StockOptionLevel = 3 and count_seg_0 ge 30 and count_seg_1 ge 30) then  Stock_thdum3 = 1; else Stock_thdum3 = 0; 
	if sum(of Stock_thdum0-Stock_thdum3) = 0 	then Stock_thdum_other = 1; 	else Stock_thdum_other = 0; 
run;

	*check sums by target variable;
proc sort data=work.dummies_seg; by &segment; run;

proc means data=work.dummies_seg sum; 
	var Stock_thdum0-Stock_thdum3 Stock_thdum_other;
	output out=work.tmp_sum1 (drop = _TYPE_ _FREQ_ _STAT_)
	sum = Stock_thdum0-Stock_thdum3 Stock_thdum_other;
	by &segment;  run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored7; set work.dummies_seg; run;

*8;
%let input_data = work.scored7; 
%let anal_var = WorkLifeBalance;
%let segment = retain_q;

	* at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	if (WorkLifeBalance = 1 and count_seg_0 ge 30 and count_seg_1 ge 30) then  WorkLife_thdum1 = 1; else WorkLife_thdum1 = 0; 
	if (WorkLifeBalance = 2 and count_seg_0 ge 30 and count_seg_1 ge 30) then  WorkLife_thdum2 = 1; else WorkLife_thdum2 = 0; 
	if (WorkLifeBalance = 3 and count_seg_0 ge 30 and count_seg_1 ge 30) then  WorkLife_thdum3 = 1; else WorkLife_thdum3 = 0; 
	if (WorkLifeBalance = 4 and count_seg_0 ge 30 and count_seg_1 ge 30) then  WorkLife_thdum4 = 1; else WorkLife_thdum4 = 0; 
	if sum(of WorkLife_thdum1-WorkLife_thdum4) = 0 	then WorkLife_thdum_other = 1; 	else WorkLife_thdum_other = 0; 
run;

	*check sums by target variable;
proc sort data=work.dummies_seg; by &segment; run;

proc means data=work.dummies_seg sum; 
	var WorkLife_thdum1-WorkLife_thdum4 WorkLife_thdum_other;
	output out=work.tmp_sum1 (drop = _TYPE_ _FREQ_ _STAT_)
	sum = WorkLife_thdum1-WorkLife_thdum4 WorkLife_thdum_other;
	by &segment;  run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored8; set work.dummies_seg; run;

*9;
%let input_data = work.scored8; 
%let anal_var = BusinessTravel;
%let segment = retain_q;

	* at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	if (BusinessTravel = "Travel_Frequently" and count_seg_0 ge 30 and count_seg_1 ge 30) then  BusiTravel_thdum_TFreq = 1; else BusiTravel_thdum_TFreq = 0; 
	if (BusinessTravel = "Travel_Rarely" and count_seg_0 ge 30 and count_seg_1 ge 30) then  BusiTravel_thdum_TRare = 1; else BusiTravel_thdum_TRare = 0; 
	if (BusinessTravel = "Non-Travel" and count_seg_0 ge 30 and count_seg_1 ge 30) then  BusiTravel_thdum_NonT = 1; else BusiTravel_thdum_NonT = 0; 
	if sum(of BusiTravel_thdum_tfreq BusiTravel_thdum_trare BusiTravel_thdum_nont) = 0 	then BusiTravel_thdum_other = 1; 	else BusiTravel_thdum_other = 0; 
run;

	*check sums by target variable;
proc sort data=work.dummies_seg; by &segment; run;

proc means data=work.dummies_seg sum; 
	var BusiTravel_thdum_tfreq BusiTravel_thdum_trare BusiTravel_thdum_nont BusiTravel_thdum_other;
	output out=work.tmp_sum1 (drop = _TYPE_ _FREQ_ _STAT_)
	sum = BusiTravel_thdum_tfreq BusiTravel_thdum_trare BusiTravel_thdum_nont BusiTravel_thdum_other;
	by &segment;  run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored9; set work.dummies_seg; run;

*10;
%let input_data = work.scored9; 
%let anal_var = gender;
%let segment = retain_q;

	* at least 30 for each segment;
	* finging freq by segment;
proc sort data=&input_data; by &segment; run;
proc freq data=&input_data order=freq; 
	table &anal_var / out=work.freq_seg (drop = percent);
	by &segment; where &segment notin(.); run;

data work.seg_1 work.seg_0; set work.freq_seg;
	if &segment = 1 then output work.seg_1; 
	if &segment = 0 then output work.seg_0; run;

data work.seg_1; set work.seg_1; count_seg_1 = count; keep &anal_var count_seg_1; run;
data work.seg_0; set work.seg_0; count_seg_0 = count; keep &anal_var count_seg_0; run;

proc print data=work.seg_1; run;
proc print data=work.seg_0; run;

	*merge files and create dummies;
proc sort data=work.seg_1; 			by &anal_var; run;
proc sort data=work.seg_0; 			by &anal_var; run;
proc sort data=&input_data; 		by &anal_var; run;

data work.dummies_seg; merge &input_data work.seg_1 work.seg_0; by &anal_var;
	if (gender = "female" and count_seg_0 ge 30 and count_seg_1 ge 30) then  gender_thdum_F = 1; else gender_thdum_F = 0; 
	if (gender = "male" and count_seg_0 ge 30 and count_seg_1 ge 30) then  gender_thdum_M = 1; else gender_thdum_M = 0; 
	if (gender = "N/A" and count_seg_0 ge 30 and count_seg_1 ge 30) then  gender_thdum_NA = 1; else gender_thdum_NA = 0; 
	if sum(of gender_thdum_f gender_thdum_m gender_thdum_na) = 0 	then gender_thdum_other = 1; 	else gender_thdum_other = 0; 
run;

	*check sums by target variable;
proc sort data=work.dummies_seg; by &segment; run;

proc means data=work.dummies_seg sum; 
	var gender_thdum_f gender_thdum_m gender_thdum_na gender_thdum_other;
	output out=work.tmp_sum1 (drop = _TYPE_ _FREQ_ _STAT_)
	sum = gender_thdum_f gender_thdum_m gender_thdum_na gender_thdum_other;
	by &segment;  run;

proc transpose data=work.tmp_sum out=work.tmp_sum_t; run;

proc print data=work.tmp_sum_t; run;

	*save threshold dummy coding;
data work.scored10; set work.dummies_seg; run;

*====> Variable Creation;

data work.creator; set final.scored;
age = round((mdy(6,1,2018) - birth_dt)/365.25);
YearSinceLeftCompany = round((mdy(6,1,2018) - depart_dt)/365.25);

data work.creator; set work.creator;
	if YearSinceLeftCompany notin(.) 	
	then Total_NumYearWork = (round((mdy(6,1,2018) - hire_dt)/365.25) - YearSinceLeftCompany);
	else if YearSinceLeftCompany in(.) 	
	then Total_NumYearWork = (round((mdy(6,1,2018) - hire_dt)/365.25) - 0);
run;

proc means data=work.creator n nmiss mean min max; 
	var age YearSinceLeftCompany Total_NumYearWork; run;

	*save;
data final.scored; set work.creator; run;

*===> Binning;
proc univariate data=final.scored; var age; histogram age; run;

/* try 6 bins equal width */
*age;
data work.creator; set final.scored;
	if age in(.) then age_dum_miss = 1; else age_dum_miss = 0;
	if age  > 15 and age < 25 then age_dum_15_24 = 1; 	else age_dum_15_24 = 0; 
	if age ge 25 and age < 35 then age_dum_25_34 = 1; 	else age_dum_25_34 = 0;
	if age ge 35 and age < 45 then age_dum_35_44 = 1; 	else age_dum_35_44 = 0; 
	if age ge 45 and age < 55 then age_dum_45_54 = 1; 	else age_dum_45_54 = 0;
	if age ge 55 and age < 60 then age_dum_55_59 = 1; 	else age_dum_55_59 = 0;
	if age ge 60  			  then age_dum_ge60 = 1; 	else age_dum_ge60 = 0;
run;
proc means data=work.creator n nmiss min mean max sum; 
	var age_dum_miss age_dum_15_24 age_dum_25_34 age_dum_35_44 age_dum_45_54 age_dum_55_59 age_dum_ge60; run;

/* try 4 bins equal width */
data work.creator; set work.creator;
	if age in(.) then age_dum_miss = 1; else age_dum_miss = 0;
	if age  > 18 and age < 30 then age_dum_19_29 = 1; 	else age_dum_19_29 = 0;
	if age ge 30 and age < 40 then age_dum_30_39 = 1; 	else age_dum_30_39 = 0;
	if age ge 40 and age < 50 then age_dum_40_49 = 1; 	else age_dum_40_49 = 0;
	if age ge 50  			  then age_dum_ge50 = 1; 	else age_dum_ge50 = 0;
run;
proc means data=work.creator n nmiss min mean max sum; 
	var age_dum_miss age_dum_19_29 age_dum_30_39 age_dum_40_49 age_dum_ge50; run;

*monthlyincome;
/* try 6 bins equal width */
proc univariate data=final.scored; var monthlyincome_mi; histogram monthlyincome_mi; run;

data work.bin; set final.scored;
	if monthlyincome_mi in(.) then M_Income_dum_miss = 1; else M_Income_dum_miss = 0;
	if monthlyincome_mi  > 1000 and monthlyincome_mi < 3000 then M_Income_dum_1000_3000 = 1; 	else M_Income_dum_1000_3000 = 0; 
	if monthlyincome_mi ge 3000 and monthlyincome_mi < 6000 then M_Income_dum_3000_6000 = 1; 	else M_Income_dum_3000_6000 = 0;
	if monthlyincome_mi ge 6000 and monthlyincome_mi < 9000 then M_Income_dum_6000_9000 = 1; 	else M_Income_dum_6000_9000 = 0; 
	if monthlyincome_mi ge 9000 and monthlyincome_mi < 12000 then M_Income_dum_9000_12000 = 1; 	else M_Income_dum_9000_12000 = 0;
	if monthlyincome_mi ge 12000 and monthlyincome_mi < 15000 then M_Income_dum_12000_15000 = 1; 	else M_Income_dum_12000_15000 = 0;
	if monthlyincome_mi ge 15000  			  then M_Income_mi_dum_ge15000 = 1; 	else M_Income_mi_dum_ge15000 = 0;
run;
proc means data=work.bin n nmiss min mean max sum; 
	var M_Income_dum_miss M_Income_dum_1000_3000 M_Income_dum_3000_6000 M_Income_dum_6000_9000
 	M_Income_dum_9000_12000  M_Income_dum_12000_15000  M_Income_mi_dum_ge15000 ; run;

data final.scored; set work.bin; run;

*===> interaction;
data work.interaction; set final.scored; 
	MonthlyIncome_OvertimeDumY = Monthlyincome_mi*OverTime_dum_Y ;
	age_genderDumF = age*gender_dum_F; 
	age_genderDumM = age*gender_dum_M; 
	YearLastPro_JobSat_dum_1 = YearsSinceLastPromotion*JobSatisfaction_dum_1;
	TotalWorkYear_JobSat_dum_1 = TotalWorkingYears*JobSatisfaction_dum_1;
	SalaryHire_OvertimeDum_Y = PercentSalaryHike*OverTime_dum_Y;
	SalaryHire_HR = PercentSalaryHike*Department_2_dum_HR;
	SalaryHire_RD = PercentSalaryHike*Department_2_dum_RD;
	SalaryHire_Sales = PercentSalaryHike*Department_2_dum_Sales;
run;

proc means data=work.interaction; 
	var MonthlyIncome_OvertimeDumY age_genderDumF age_genderDumM
	YearLastPro_JobSat_dum_1 TotalWorkYear_JobSat_dum_1 SalaryHire_OvertimeDum_Y
	SalaryHire_HR SalaryHire_RD SalaryHire_Sales;
run;

*===> Variable clusterin;
proc contents data=final.scored; run;

data work.varclus; set final.scored; run;

%let anal_vars = B_st_ThDum_1
B_st_ThDum_2
B_st_ThDum_3
B_st_ThDum_4
B_st_ThDum_5
B_st_ThDum_6
B_st_ThDum_7
B_st_ThDum_8
B_st_ThDum_9
B_st_ThDum_10
B_st_ThDum_11
B_st_ThDum_12
B_st_ThDum_13
B_st_ThDum_14
B_st_ThDum_15
B_st_ThDum_16
B_st_ThDum_17
B_st_ThDum_18
B_st_ThDum_19
B_st_ThDum_20
B_st_ThDum_21
B_st_ThDum_22
B_st_ThDum_23
B_st_ThDum_24
B_st_ThDum_25
B_st_ThDum_26
B_st_ThDum_27
B_st_ThDum_28
B_st_ThDum_29
B_st_ThDum_30
B_st_ThDum_31
B_st_ThDum_32
B_st_ThDum_33
B_st_ThDum_34
B_st_ThDum_35
B_st_ThDum_36
B_st_ThDum_37
B_st_ThDum_38
B_st_ThDum_39
B_st_ThDum_40
B_st_ThDum_41
B_st_ThDum_42
B_st_ThDum_43
B_st_ThDum_44
B_st_ThDum_45
B_st_ThDum_46
B_st_ThDum_47
B_st_ThDum_oth
B_st_num
B_state_dum_cus1
B_state_dum_cus2
B_state_dum_cus3
B_state_dum_cus4
Birth_State_dum_AK
Birth_State_dum_AL
Birth_State_dum_AR
Birth_State_dum_AZ
Birth_State_dum_CA
Birth_State_dum_CO
Birth_State_dum_CT
Birth_State_dum_DC
Birth_State_dum_DE
Birth_State_dum_FL
Birth_State_dum_GA
Birth_State_dum_HI
Birth_State_dum_IA
Birth_State_dum_ID
Birth_State_dum_IL
Birth_State_dum_IN
Birth_State_dum_KS
Birth_State_dum_KY
Birth_State_dum_LA
Birth_State_dum_MA
Birth_State_dum_MD
Birth_State_dum_ME
Birth_State_dum_MI
Birth_State_dum_MN
Birth_State_dum_MO
Birth_State_dum_MS
Birth_State_dum_MT
Birth_State_dum_NC
Birth_State_dum_ND
Birth_State_dum_NE
Birth_State_dum_NH
Birth_State_dum_NJ
Birth_State_dum_NM
Birth_State_dum_NV
Birth_State_dum_NY
Birth_State_dum_OH
Birth_State_dum_OK
Birth_State_dum_OR
Birth_State_dum_OT
Birth_State_dum_PA
Birth_State_dum_RI
Birth_State_dum_SC
Birth_State_dum_SD
Birth_State_dum_TN
Birth_State_dum_TX
Birth_State_dum_UT
Birth_State_dum_VT
Bstate_iv
Bstate_woe
BusiTravel_iv
BusiTravel_woe
BusinessTravel_dum_NonT
BusinessTravel_dum_TFreq
BusinessTravel_dum_TRare
BusinessTravel_dum_cus1
BusinessTravel_dum_cus2
Department2_iv
Department2_woe
Department_2_dum_HR
Department_2_dum_RD
Department_2_dum_Sales
Department_2_dum_cus1
Department_2_dum_cus2
DistanceFromHome
EduField2_dum_HR
EduField2_dum_LS
EduField2_dum_MD
EduField2_dum_MKT
EduField2_dum_OT
EduField2_dum_Tech
EduField_2_dum_cus1
EduField_2_dum_cus2
Edu_iv
Edu_woe
Education
Education_dum_1
Education_dum_2
Education_dum_3
Education_dum_4
Education_dum_5
Education_dum_cus1
Education_dum_cus2
Edufield2_iv
Edufield2_woe
EnvironmenrSat_woe
EnvironmentSat_iv
EnvironmentSatisfaction
EnvironmentSatisfaction_dum_1
EnvironmentSatisfaction_dum_2
EnvironmentSatisfaction_dum_3
EnvironmentSatisfaction_dum_4
EnvrmSat_dum_cus1
EnvrmSat_dum_cus2
Gender_dum_cus1
Gender_dum_cus2
Gender_iv
Gender_woe
HourlyRate
JobInvolve_dum_cus1
JobInvolve_dum_cus2
JobInvolve_dum_cus3
JobInvolvement
JobInvolvement_dum_1
JobInvolvement_dum_2
JobInvolvement_dum_3
JobInvolvement_dum_4
JobLevel
JobLevel_dum_cus1
JobLevel_dum_cus2
JobLevel_woe
JobSat_dum_cus1
JobSat_dum_cus2
JobSat_dum_cus3
JobSat_iv
JobSat_woe
JobSatisfaction
JobSatisfaction_dum_1
JobSatisfaction_dum_2
JobSatisfaction_dum_3
JobSatisfaction_dum_4
Jobenvolve_iv
Jobenvolve_woe
Joblevel_iv
M_Income_dum_1000_3000
M_Income_dum_12000_15000
M_Income_dum_3000_6000
M_Income_dum_6000_9000
M_Income_dum_9000_12000
M_Income_dum_miss
M_Income_mi_dum_ge15000
MaritalStatus_cat_dum_D
MaritalStatus_cat_dum_M
MaritalStatus_cat_dum_S
Marital_cat_dum_cus1
Marital_cat_dum_cus2
Marital_iv
Marital_woe
NumCompaniesWorked
OverTime_dum_N
OverTime_dum_Y
OverTime_iv
OverTime_woe
PercentSalaryHike
PerformSat_iv
PerformSat_woe
PerformanceRating
PerformanceRating_dum_3
PerformanceRating_dum_4
RelationshipSat_dum_cus1
RelationshipSat_dum_cus2
RelationshipSat_iv
RelationshipSat_woe
RelationshipSatisfaction
RelationshipSatisfaction_dum_1
RelationshipSatisfaction_dum_2
RelationshipSatisfaction_dum_3
RelationshipSatisfaction_dum_4
StockOpLv_dum_cus1
StockOpLv_dum_cus2
StockOptionLevel
StockOptionLevel_dum_0
StockOptionLevel_dum_1
StockOptionLevel_dum_2
StockOptionLevel_dum_3
Stock_iv
Stock_woe
TotalWorkingYears
Total_NumYearWork
TrainingTimesLastYear
WorkLifeBL_iv
WorkLifeBL_woe
WorkLifeBalance
WorkLifeBalance_dum_1
WorkLifeBalance_dum_2
WorkLifeBalance_dum_3
WorkLifeBalance_dum_4
WorkLifeBalance_dum_cus1
WorkLifeBalance_dum_cus2
YearSinceLeftCompany
YearsInCurrentRole
YearsSinceLastPromotion
YearsWithCurrManager
age
age_dum_19_29
age_dum_30_39
age_dum_40_49
age_dum_ge50
age_dum_miss
birth_dt
birth_dt_mi_dum
count_seg_0
count_seg_1
dailyrate_mi
dailyrate_mi_dum
dailyrate_outlier
depart_dt
fico_scr
gender_dum_F
gender_dum_M
gender_dum_NA
hire_dt
hire_dt_outlier
inv_sqrt_monthlyincome_mi
joblevel_dum_1
joblevel_dum_2
joblevel_dum_3
joblevel_dum_4
joblevel_dum_5
monthlyincome_mi
monthlyincome_mi_dum
monthlyincome_outlier
ssn;

proc varclus data=work.varclus maxeigen=.7 outtree=work.fortree maxclusters=286 short hi; var &anal_vars; run;

proc tree data=work.fortree horizontal; height _maxeig_; run;


/*task 5*/


proc means data =final.scored; run;
%let anal_var = retain_q;

data work.correlation; set final.scored; where &anal_var in(1,0); 

%let num_vars = 
employee_no
Trainingtimeslastyear
DistanceFromHome
NumCompaniesWorked
TotalWorkingYears
YearsInCurrentRole
YearsSinceLastPromotion
YearsWithCurrManager
DailyRate_mi
HourlyRate
MonthlyIncome_mi
PercentSalaryHike
ssn
fico_scr;

proc corr data=final.scored out=work.corr;
	var &anal_var; with &num_vars; run;

/* FROM THE O/P 
	1st line is relation with target value
	2nd line is p-value 
	3rd line is total no of observations */

data work.corr; set work.corr; where TYPE in("CORR");
	rename &anal_var = corr;
	abs_corr = abs(&anal_var); run;

proc sort data=work.corr; by descending abs_corr; run;

proc print data=work.corr; var name abs_corr; run;

