# Predictive Model of Employee Voluntarily Turnover

Fortune Corp, a maker of specialized laboratory equipment for the pharmaceutical industry, began business in June 1980. Priding itself on employee job satisfaction, the company is seeking to understand why employees voluntarily leave the company.

Over the last 3 years, at the request of the SVP of Human Resources, the HR department has been conducting an employee survey. The SVP wants enough data collected so that a predictive model of employee voluntary attrition can be built and tested. The objective is to use such a model to find current employees who might be thinking of leaving, so proactive steps can be taken to retain them.


Modeling sample qualifications to be used for the target and non-target samples of employees:

• Took the survey

• Former (voluntarily attritioned) or current employee


The following 5 data tables have been created for your use by the IT department:

• (csv) Credit Bureau file: fortune_credit.csv

• (SAS) Accounting file: fortune_acct o Payrolldata

• (SAS) Attrition file: fortune_attrition

• (SAS) HR file fortune_hr o Backgroundemployeedata

• (SAS) Survey file fortune_survey o Datacollectedfromtheemployeesurvey


## Our tasks are the following
### 1. Create data audit report
The purpose of this data audit is to ensure that: 

• all data received by the analytical team for the project are consistent with the team’s understanding of the requested analytical deliverable; 

• that the team is reading and interpreting these data correctly; 

• that the team has received all data intended to be supplied; 

• that the data are functionally usable for modeling purposes. 


The data audit is broken into four main sections: 

1.	Dataset Summary – A list of all datasets received. 

2.	Dataset Detail – For each dataset, tables showing all data variables received. It is important that this section be reviewed to ensure that the analytical team has all the data sent, the data are being read correctly and the data have reasonable values. 

3.	Modeling Sample – Based on the requestor’s sample requirements, a determination is necessary as to whether adequate sample is available to support modeling. 

4.	Questions – Specific questions that the analytical team needs answered to ensure that the team fully understands the data and that the data can support the requested analytical deliverable.


### 2. Data Cleansing 
examine all variables for such issues as dirty data, missing values, extreme values, duplicate values, extreme distributions, etc. 

### 3. Feature Engineering 
once the raw data are cleaned, create new variables that may be useful in your model. Consider both non-numeric and numeric variables. 

Our data cleansing and feature engineering should explicitly address the following areas:
1. Data integrity: duplicate values, coding errors, etc.
2. Missing values
3. Extreme values
4. Extreme distributions
5. Categorical variable preparation: simple dummy coding, threshold dummy coding, level
reduction using clustering, enumeration, linking
6. Numerical variable preparation: transformations, interactions, ratios, binning, date values


