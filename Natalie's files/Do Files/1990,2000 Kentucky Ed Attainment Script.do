/*
  Author: Natalie Gross
  Date: February 2026
  Data: Decennial Census Educational Attainment – KY Tracts (1990 & 2000)
*/

/*------------------------------------------------------------------------------
  STEP 0: Setup and Preparation
------------------------------------------------------------------------------*/

clear all                    
set more off                 

* Set working directory to where your data files are located
cd "/Users/nataliegross/Downloads/ACS Kentucky Ed Attainment 1990-2000/Data"

* Check that we're in the right place
pwd                          

/*------------------------------------------------------------------------------
  STEP 1: Understanding the File Structure
------------------------------------------------------------------------------*/

di as text _newline "STEP 1: Loading 2000 data as an example..."

infile using "C2000_R50090125.dct", using("R50090125_SL080.txt") clear

* Look at what we loaded
describe, short              
di "Number of observations (census tracts): " _N

/*------------------------------------------------------------------------------
  STEP 2: Define the Years and R Numbers
------------------------------------------------------------------------------*/

di as text _newline "STEP 2: Setting up year and file information..."

* Create a list of all years we want to include
local years 1990 2000

* Each year has a different R number
local r_1990 "50090119"
local r_2000 "50090125"


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

local years 1990 2000
local r_1990 "50090119"
local r_2000 "50090125"

foreach year of local years {

    clear
    di as text _newline "Processing year: `year'"

    local r_num "`r_`year''"
    di "  Using R number: `r_num'"

    quietly infile using "C`year'_R`r_num'.dct", using("R`r_num'_SL080.txt") clear
    di "  Loaded " _N " observations (census tracts)"

    * --- Find a *_001 variable whose label indicates 25 years and over ---
    local base ""
    foreach v of varlist _all {
        local lbl : variable label `v'
        if regexm("`v'", "_001$") & regexm(lower("`lbl'"), "25") & regexm(lower("`lbl'"), "year") {
            local base "`v'"
            continue, break
        }
    }

    if "`base'" == "" {
        di as error "  ERROR: can't find the education base variable (*_001) for `year'."
        di as error "  Run after loading: lookfor 25"
        exit 111
    }

    * Extract prefix before _001
    quietly {
        local junk = regexm("`base'", "^(.*)_001$")
        local prefix = regexs(1)
    }
    di "  Detected prefix: `prefix'"

    * Keep only the 8 vars if they exist + Geo vars
    local keepvars "Geo_NAME Geo_TRACT"
    forvalues i = 1/8 {
        local suf : display %03.0f `i'
        capture confirm variable `prefix'_`suf'
        if _rc == 0 local keepvars "`keepvars' `prefix'_`suf'"
    }
    keep `keepvars'

    * Rename into standard names (only if present)
    capture rename `prefix'_001 pop_25_over
    capture rename `prefix'_002 less_than_hs
    capture rename `prefix'_003 hs_or_more
    capture rename `prefix'_004 some_college_or_more
    capture rename `prefix'_005 bachelors_or_more
    capture rename `prefix'_006 masters_or_more
    capture rename `prefix'_007 doctorate
    capture rename `prefix'_008 professional_or_more

    * Ensure tract is string
    capture confirm numeric variable Geo_TRACT
    if _rc == 0 tostring Geo_TRACT, replace

    gen year = `year'

    save "c_`year'.dta", replace
    di "  Saved c_`year'.dta"
}

di as result _newline "All years loaded successfully!"

/*------------------------------------------------------------------------------ 

  STEP 4: Combine All Years into One Dataset 

  Now that all variables are the same type, combining will work! 

------------------------------------------------------------------------------*/
 

di as text _newline(2) "STEP 4: Combining all years into one dataset..." 

* Start with the first year (2009) 

use "c_1990.dta", clear 
di "Starting with 1990 data: " _N " observations" 

* Append each subsequent year 

foreach year in 1990 2000 { 
    append using "c_`year'.dta" 
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

rename Geo_TRACT tract_code
label variable tract_code "Census tract code"

di as result "All variables renamed!"

* Show the new variable names
describe year area_name tract_code pop_25_over less_than_hs hs_or_more

* ==========================
* STEP 6: Organizing variables
* ==========================

di as text _newline(2) "STEP 6: Organizing variables..."

order year area_name tract_code pop_25_over less_than_hs hs_or_more some_college_or_more bachelors_or_more masters_or_more professional_or_more doctorate

di as result "Variables organized!"

/*------------------------------------------------------------------------------
  STEP 7: Save the Combined Dataset
------------------------------------------------------------------------------*/

di as text _newline(2) "STEP 7: Saving the combined dataset..."

* Save in Stata format
save "/Users/nataliegross/Downloads/ACS Kentucky Ed Attainment 1990-2000/Output", replace
di as result "✓ Saved Stata file: c_combined_1990_2000.dta"

* Save as CSV (Excel-friendly format)
export delimited using "../Output/c_combined_1990_2000.csv", replace
di as result "✓ Saved CSV file: c_combined_1990_2000.csv"

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
di as text "Number of years: " as result "15 (1990-2000)"

di as text _newline "Observations by year:"
tab year, missing

di as text _newline "Sample of data (first 5 observations):"
list year area_name pop_25_over college_grad in 1/5, clean abbreviate(15)

di as text _newline "Total population 25+ by year:"
table year, statistic(sum pop_25_over) nformat(%12.0fc)

di as text _newline "Key variables in dataset:"
describe year area_name tract_code pop_25_over less_than_hs hs_only ///
         some_college_only bachelors_only college_grad

di as text _newline(2) "Files saved to:"
di as text "  /Users/nataliegross/Downloads/ACS Kentucky Ed Attainment 1990-2000/Output"
di as text "    • c_combined_1990_2000.dta (Stata format)"
di as text "    • c_combined_1990_2000.csv (CSV format)"

di as text _newline "NEXT STEPS:"
di as text "  1. Open the .dta file: use ../Output/c_combined_1990_2000.dta"
di as text "  2. Or open the .csv file in Excel to explore the data"
di as text "  3. Aggregate tract data to county level (see next lesson!)"
