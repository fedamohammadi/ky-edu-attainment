*Author: Natalie Gross
  *Date: March 30 2026
  *Data: ACS 5-Year Estimates for Kentucky (2018-2024)
/*==============================================================================*/

/*------------------------------------------------------------------------------
  STEP 0: Setup and Preparation
------------------------------------------------------------------------------*/

clear all                    
set more off                 

* Set working directory to where your data files are located
cd "/Users/nataliegross/Desktop/DOGE Medicaid Spending Data/2018-2024 Education Data"

* Check that we're in the right place
pwd                          

/*------------------------------------------------------------------------------
  STEP 1: Understanding the File Structure
------------------------------------------------------------------------------*/

di as text _newline "STEP 1: Loading 2023 data as an example..."

infile using "ACS2023_5yr_R50128624.dct", using("R50128624_SL140.txt") clear

* Look at what we loaded
describe, short              
di "Number of observations (census tracts): " _N

/*------------------------------------------------------------------------------
  STEP 2: Define the Years and R Numbers
------------------------------------------------------------------------------*/

di as text _newline "STEP 2: Setting up year and file information..."

* Create a list of all years we want to include
local years 2018 2019 2020 2021 2022 2023 2024 

* Each year has a different R number
local r_2018 "50128629"
local r_2019 "50128628"
local r_2020 "50128627"
local r_2021 "50128626"
local r_2022 "50128625"
local r_2023 "50128624"
local r_2024 "50128619"


di "Years to process: `years'"

/*------------------------------------------------------------------------------ 

  STEP 3: Load Each Year and Keep Only What We Need 

  KEY LEARNING POINT: Different years can store the same variable in different 

  ways (text vs. numbers). We need to make them consistent! 

  SOLUTION:  

  1. Keep only the variables we need 

  2. Convert them to a consistent format (all text or all numbers) 

------------------------------------------------------------------------------*/ 

di as text _newline(2) "STEP 3: Loading all years one at a time..."

foreach year of local years {

    * 3A: Clear memory and show progress
    clear
    di as text _newline "Processing year: `year'"

    * 3B: Get the R number for this specific year
    local r_num = "`r_`year''"
    di "  Using R number: `r_num'"

    * 3C: Load the data for this year
    quietly infile using "ACS`year'_5yr_R`r_num'.dct", using("R`r_num'_SL140.txt") clear
    di "  Loaded " _N " observations (census tracts)"

    * 3D: Keep only the variables we need
    * IMPORTANT FIX: keep Geo_STATE + Geo_COUNTY so we can build full 11-digit GEOID
    keep SE_A12002_* Geo_NAME Geo_STATE Geo_COUNTY Geo_TRACT
    di "  Kept only education variables + Geo_STATE/Geo_COUNTY/Geo_TRACT"

    * 3E: Convert Geo vars to TEXT (string) if needed
    foreach g in Geo_STATE Geo_COUNTY Geo_TRACT {
        capture confirm numeric variable `g'
        if _rc == 0 {
            tostring `g', replace
        }
    }

    * 3F: Pad with leading zeros + build full 11-digit tract GEOID
    replace Geo_STATE  = substr("00"     + Geo_STATE,  -2, 2)
    replace Geo_COUNTY = substr("000"    + Geo_COUNTY, -3, 3)
    replace Geo_TRACT  = substr("000000" + Geo_TRACT,  -6, 6)

    gen str11 geoid10 = Geo_STATE + Geo_COUNTY + Geo_TRACT
    label variable geoid10 "2010 tract GEOID (STATE+COUNTY+TRACT)"
replace Geo_STATE  = substr(Geo_STATE,  -2, 2)
replace Geo_COUNTY = substr(Geo_COUNTY, -3, 3)
replace Geo_TRACT  = substr(Geo_TRACT,  -6, 6)

recast str2 Geo_STATE
recast str3 Geo_COUNTY
recast str6 Geo_TRACT	

    * (Optional) keep the old tract code too, for readability
    gen str6 tract_code = Geo_TRACT
    label variable tract_code "Tract code (6-digit)"

    * 3G: Add a year variable
    gen year = `year'
    label variable year "ACS Survey Year"

    * 3H: Save this year as a regular .dta file
    save "acs_`year'.dta", replace
    di "  Saved acs_`year'.dta"
}

di as result _newline "All years loaded successfully!"

/*------------------------------------------------------------------------------ 

  STEP 4: Combine All Years into One Dataset 

  Now that all variables are the same type, combining will work! 

------------------------------------------------------------------------------*/ 

di as text _newline(2) "STEP 4: Combining all years into one dataset..." 

* Start with the first year (2018) 

use "acs_2018.dta", clear 
di "Starting with 2018 data: " _N " observations" 

* Append each subsequent year 

foreach year in 2018 2019 2020 2021 2022 2023 2024 { 
    append using "acs_`year'.dta" 
    di "After adding `year': " _N " observations" 
} 

* Sort the data by year 

sort year 
di as result _newline "Combined dataset created with " _N " total observations!" 

* Check how many observations we have per year 

di as text _newline "Observations per year:" 
tab year 
/*------------------------------------------------------------------------------
  STEP 5: Rename Variables to More Intuitive Names
  
  Original name: SE_A12002_001 (cryptic!)
  New name:      pop_25_over (clear and understandable!)
------------------------------------------------------------------------------*/

di as text _newline(2) "STEP 5: Renaming variables..."

* Educational attainment variables from ACS Table A12002

* Total population aged 25 and over
rename SE_A12002_001 pop_25_over
label variable pop_25_over "Population 25 years and older"

* Less than high school
rename SE_A12002_002 less_than_hs
label variable less_than_hs "Less than high school diploma"

* High school graduate or more (includes college)
rename SE_A12002_003 hs_or_more
label variable hs_or_more "High school graduate or more"

* Some college or more (includes bachelor's and graduate)
rename SE_A12002_004 some_college_or_more
label variable some_college_or_more "Some college or more"

* Bachelor's degree or more (includes graduate)
rename SE_A12002_005 bachelors_or_more
label variable bachelors_or_more "Bachelor's degree or more"

* Master's degree or more (includes professional and doctorate)
rename SE_A12002_006 masters_or_more
label variable masters_or_more "Master's degree or more"

* Professional school degree or more (includes doctorate)
rename SE_A12002_007 professional_or_more
label variable professional_or_more "Professional degree or more"

* Doctorate degree
rename SE_A12002_008 doctorate
label variable doctorate "Doctorate degree"

* Geographic variables
rename Geo_NAME area_name
label variable area_name "Census tract name"

* tract_code was already created in Step 3 (str6)
* If it doesn't exist for some reason, create it now
capture confirm variable tract_code
if _rc {
    tostring Geo_TRACT, replace
    replace Geo_TRACT = substr("000000" + Geo_TRACT, -6, 6)
    rename Geo_TRACT tract_code
}
label variable tract_code "Tract code (6-digit)"

di as result "All variables renamed!"

* Show the new variable names
describe year area_name tract_code pop_25_over less_than_hs hs_or_more

* ==========================
* STEP 6: Organizing variables
* ==========================

di as text _newline(2) "STEP 6: Organizing variables..."

order year geoid10 area_name tract_code pop_25_over less_than_hs hs_or_more ///
      some_college_or_more bachelors_or_more masters_or_more professional_or_more doctorate

di as result "Variables organized!"

/*------------------------------------------------------------------------------
  STEP 7: Save the Combined Dataset
------------------------------------------------------------------------------*/

di as text _newline(2) "STEP 7: Saving the combined dataset..."

* Save in Stata format
save "../Output/acs_combined_2018_2024.dta", replace
di as result "✓ Saved Stata file: acs_combined_2018_2024.dta"

* Save as CSV (Excel-friendly format)
export delimited using "../Output/acs_combined_2018_2024.csv", replace
di as result "✓ Saved CSV file: acs_combined_2018_2024.csv"

/*------------------------------------------------------------------------------
  STEP 8: Display Summary Information
------------------------------------------------------------------------------*/

di as text _newline(2) "================================================"
di as result "SUCCESS! Data combination complete!"
di as text "================================================" _newline

* Display summary information
di as text "Summary of Combined Dataset:"
di as text "----------------------------"
di as text "Total observations: " as result _N
di as text "Number of years: " as result "15 (2018-2024)"

di as text _newline "Observations by year:"
tab year, missing

di as text _newline "Sample of data (first 5 observations):"
list year area_name geoid10 pop_25_over bachelors_or_more masters_or_more in 1/5, clean abbreviate(20)

di as text _newline "Total population 25+ by year:"
table year, statistic(sum pop_25_over) nformat(%12.0fc)

di as text _newline "Key variables in dataset:"
describe year area_name tract_code pop_25_over less_than_hs hs_only ///
         some_college_only bachelors_only college_grad

di as text _newline(2) "Files saved to:"
di as text "  C:\Users\nataliegross\Downloads\Kentucky_ACS_Analysis_Ed Attainment 09-23\Output\"
di as text "    • acs_combined_2018_2024.dta (Stata format)"
di as text "    • acs_combined_2018_2024.csv (CSV format)"

di as text _newline "NEXT STEPS:"
di as text "  1. Open the .dta file: use ../Output/acs_combined_2018_2024.dta"
di as text "  2. Or open the .csv file in Excel to explore the data"
di as text "  3. Aggregate tract data to county level (see next lesson!)"
