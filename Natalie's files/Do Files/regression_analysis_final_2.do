/*********************************************************************
  REGRESSION ANALYSIS: Determinants of BA Attainment Growth
  Kentucky Census Tracts, 1990-2023
  
  Outcome: ba_growth — change in BA share in percentage points
  
  Models:
    Model 1 — Baseline: initial BA share + metro/nonmetro
    Model 2 — Add 4-year college presence (25 miles)
    Model 3 — Add 2-year college presence (25 miles)
    Model 4 — Both college types (25 miles)
    Model 5 — Robustness: 10-mile threshold
    Model 6 — Robustness: 50-mile threshold

  Notes:
    - 34 Jefferson County tracts use 2009 as BA baseline (no 1990
      crosswalk equivalent due to tract boundary changes)
    - College presence = binary indicator for institution within
      X miles of tract centroid (Haversine approximation)
    - Urban/rural = USDA Rural-Urban Continuum Codes 2023
      (metro = RUCC 1-3, nonmetro = RUCC 4-9)
    - County FIPS extracted from tr2020: substr(2,2)+substr(5,3)
    - Robust standard errors throughout

  Output:
    regression_table_main.rtf      — Table 1 (main results)
    regression_table_robustness.rtf — Table 2 (distance robustness)
    regression_data_final.dta      — Final analysis dataset

  Last updated: April 2026
*********************************************************************/

clear all
set more off

* Requires estout — install if needed:
* ssc install estout, replace

* ============================================================
* DEFINE PATHS
* ============================================================
local root    "/Users/nataliegross/Desktop/Final Combined Data 1990_2023"
local maps    "`root'/Maps"
local output  "`root'/Final Output"
local shapes  "`root'/Shape files"
local metro   "`root'/Metro v. Nonmetro "

* ============================================================
* STEP 1: Load outcome data and fix missing Jefferson tracts
* ============================================================
import delimited "`output'/ACS_Map_data.csv", clear

* For 34 Jefferson County tracts missing 1990 data, use 2009 as baseline
* These are 2020-vintage tract splits with no 1990 crosswalk equivalent
replace ba_growth = pct_baplus2023 - pct_baplus2009 ///
    if missing(ba_growth) & !missing(pct_baplus2009) & !missing(pct_baplus2023)

* Keep only tracts with valid outcome and baseline
keep if !missing(ba_growth) & !missing(pct_baplus1990)
keep if !missing(intptlat) & !missing(intptlon)

* Rename centroid coordinates
rename intptlat tract_lat
rename intptlon tract_lon

* Extract 5-digit county FIPS from tr2020
* tr2020 format: G2100010970100
* state(2) = positions 2-3, county(3) = positions 5-7
gen countyfips = substr(tr2020, 2, 2) + substr(tr2020, 5, 3)

* Keep variables needed for analysis
keep tr2020 ba_growth pct_baplus1990 tract_lat tract_lon countyfips

di "Step 1 complete: `=_N' tracts loaded"
save "`root'/temp_regression_base.dta", replace

* ============================================================
* STEP 2: Prepare RUCC urban/rural codes
* ============================================================
import delimited "/Users/nataliegross/Desktop/Final Combined Data 1990_2023/Metro v. Nonmetro /Ruralurbancontinuumcodes2023.csv", clear

* File is long format — keep only RUCC_2023 rows
keep if attribute == "RUCC_2023"

* Convert numeric FIPS to 5-character string with leading zeros
gen countyfips = string(fips, "%05.0f")
destring value, replace
rename value rucc

* Metro = RUCC 1-3, Nonmetro = RUCC 4-9
gen metro = (rucc <= 3)
keep countyfips rucc metro

di "Step 2 complete: `=_N' counties in RUCC file"
save "`root'/temp_rucc.dta", replace

* ============================================================
* STEP 3: Merge RUCC onto tract data
* ============================================================
use "`root'/temp_regression_base.dta", clear
merge m:1 countyfips using "`root'/temp_rucc.dta"
drop if _merge == 2
drop _merge

* Verify — should be 0 missing
count if missing(metro)
tab metro

save "`root'/temp_tracts_for_dist.dta", replace

* ============================================================
* STEP 4: Prepare institution coordinate files
* ============================================================

* 4-year institutions
preserve
use "`maps'/institutions_4yr.dta", clear
keep _Y _X
rename _Y inst_lat
rename _X inst_lon
save "`root'/temp_inst_4yr.dta", replace
restore

* 2-year institutions
preserve
use "`maps'/institutions_2yr.dta", clear
keep _Y _X
rename _Y inst_lat
rename _X inst_lon
save "`root'/temp_inst_2yr.dta", replace
restore

* ============================================================
* STEP 5: Compute minimum distance to nearest college
* Haversine approximation:
*   1 degree latitude  ≈ 69 miles
*   1 degree longitude ≈ 69 * cos(latitude) miles
* ============================================================
use "`root'/temp_tracts_for_dist.dta", clear

gen min_dist_4yr = .
gen min_dist_2yr = .

local n_tracts = _N
di "Computing distances for `n_tracts' tracts — please wait..."

forval i = 1/`n_tracts' {
    local tlat = tract_lat[`i']
    local tlon = tract_lon[`i']

    * Distance to nearest 4-year college
    preserve
    use "`root'/temp_inst_4yr.dta", clear
    gen dlat = (`tlat' - inst_lat) * 69
    gen dlon = (`tlon' - inst_lon) * 69 * cos(`tlat' * _pi / 180)
    gen dist = sqrt(dlat^2 + dlon^2)
    summarize dist, meanonly
    local d4 = r(min)
    restore
    replace min_dist_4yr = `d4' if _n == `i'

    * Distance to nearest 2-year college
    preserve
    use "`root'/temp_inst_2yr.dta", clear
    gen dlat = (`tlat' - inst_lat) * 69
    gen dlon = (`tlon' - inst_lon) * 69 * cos(`tlat' * _pi / 180)
    gen dist = sqrt(dlat^2 + dlon^2)
    summarize dist, meanonly
    local d2 = r(min)
    restore
    replace min_dist_2yr = `d2' if _n == `i'

    * Progress update every 100 tracts
    if mod(`i', 100) == 0 di "  Processed `i' of `n_tracts' tracts..."
}

di "Distance computation complete."
sum min_dist_4yr min_dist_2yr, detail

* ============================================================
* STEP 6: Create binary college presence indicators
* ============================================================

* 10-mile threshold
gen college4_10mi = (min_dist_4yr <= 10)
gen college2_10mi = (min_dist_2yr <= 10)

* 25-mile threshold
gen college4_25mi = (min_dist_4yr <= 25)
gen college2_25mi = (min_dist_2yr <= 25)

* 50-mile threshold
gen college4_50mi = (min_dist_4yr <= 50)
gen college2_50mi = (min_dist_2yr <= 50)

* Check distributions
di "College presence indicators (% of tracts):"
foreach v of varlist college4_10mi college2_10mi college4_25mi ///
                      college2_25mi college4_50mi college2_50mi {
    quietly sum `v'
    di "  `v': `=round(r(mean)*100, 0.1)'%"
}

* Save final analysis dataset
save "`output'/regression_data_final.dta", replace
di "Final dataset saved: `=_N' observations"

* ============================================================
* STEP 7: Label variables
* ============================================================
label var ba_growth        "BA Growth (pp), 1990-2023"
label var pct_baplus1990   "Initial BA Share, 1990 (pp)"
label var metro            "Metro County (RUCC 1-3)"
label var college4_25mi    "4-Year College within 25 mi."
label var college2_25mi    "2-Year College within 25 mi."
label var college4_10mi    "4-Year College within 10 mi."
label var college2_10mi    "2-Year College within 10 mi."
label var college4_50mi    "4-Year College within 50 mi."
label var college2_50mi    "2-Year College within 50 mi."

* ============================================================
* STEP 8: Run regressions
* ============================================================
eststo clear

* Model 1: Baseline
eststo m1: reg ba_growth pct_baplus1990 metro, robust

* Model 2: 4-year college presence (25 mi)
eststo m2: reg ba_growth pct_baplus1990 metro college4_25mi, robust

* Model 3: 2-year college presence (25 mi)
eststo m3: reg ba_growth pct_baplus1990 metro college2_25mi, robust

* Model 4: Both college types (25 mi)
eststo m4: reg ba_growth pct_baplus1990 metro college4_25mi college2_25mi, robust

* Model 5: Robustness — 10-mile threshold
eststo m5: reg ba_growth pct_baplus1990 metro college4_10mi college2_10mi, robust

* Model 6: Robustness — 50-mile threshold
eststo m6: reg ba_growth pct_baplus1990 metro college4_50mi college2_50mi, robust

* ============================================================
* STEP 9: Export regression tables
* ============================================================

* Table 1 — Main results
esttab m1 m2 m3 m4 using "`output'/regression_table_main.rtf", ///
    replace ///
    title("Table 1. OLS Estimates: Determinants of BA Attainment Growth, 1990-2023") ///
    mtitles("Baseline" "4-Year" "2-Year" "Both") ///
    b(3) se(3) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
    note("Robust standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01." ///
         "College presence defined as binary indicator for institution within 25 miles of tract centroid." ///
         "Urban/rural classification from USDA Rural-Urban Continuum Codes 2023." ///
         "34 Jefferson County tracts use 2009-2023 growth due to absence of 1990 crosswalk equivalent.") ///
    nogaps

* Table 2 — Robustness across distance thresholds
esttab m5 m4 m6 using "`output'/regression_table_robustness.rtf", ///
    replace ///
    title("Table 2. Robustness: College Presence at Alternative Distance Thresholds") ///
    mtitles("10 Miles" "25 Miles" "50 Miles") ///
    b(3) se(3) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
    note("Robust standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01." ///
         "Each column varies the distance threshold for the college presence indicator." ///
         "Controls include initial BA share (1990) and metro/nonmetro classification." ///
         "34 Jefferson County tracts use 2009-2023 growth due to absence of 1990 crosswalk equivalent.") ///
    nogaps

di as result "All regression tables saved successfully."

* ============================================================
* STEP 10: Clean up temporary files
* ============================================================
capture erase "`root'/temp_regression_base.dta"
capture erase "`root'/temp_rucc.dta"
capture erase "`root'/temp_inst_4yr.dta"
capture erase "`root'/temp_inst_2yr.dta"
capture erase "`root'/temp_tracts_for_dist.dta"

di as result "Temporary files removed. Done."
