*===============================================================================
* 15_ipeds_completions_2024_pilot.do
*
* Replicate the R pilot's 2024 completions aggregation in Stata.
* Verifies the Stata pipeline matches R output before looping to all years.
*
* Inputs:
*   data/raw/ipeds/c2024_a.csv
*   data/cleaned/ipeds_ky_crosswalk.dta
*
* Output: data/cleaned/ipeds_ky_completions_2024.dta
*
* R pilot benchmarks (Stata output must match):
*   - 216 county x awlevel rows
*   - 40 distinct KY counties producing degrees
*   - Top-3 bachelor's producers: UK (10,110), U of L (5,540), WKU (5,470)
*===============================================================================

clear all
set more off
cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* PART A: Load c2024_a, filter to first-major rows, merge with KY crosswalk
*-------------------------------------------------------------------------------
import delimited "data/raw/ipeds/c2024_a.csv", clear varnames(1) case(lower)

* Keep first majors only (each student counted once, avoids double-counting).
keep if majornum == 1

* Merge with KY crosswalk. keep(match) drops non-KY institutions;
* keepusing brings the county fields onto each completion row.
merge m:1 unitid using "data/cleaned/ipeds_ky_crosswalk.dta", ///
    keep(match) keepusing(instnm countycd countynm) nogen

count
di "KY completion rows (first-major, 2024): " r(N)

tempfile ky_comp_2024
save `ky_comp_2024'

*-------------------------------------------------------------------------------
* PART B: Sanity check - top 10 KY institutions by bachelor's degrees
*-------------------------------------------------------------------------------
use `ky_comp_2024', clear
keep if awlevel == 5
collapse (sum) total_bachelors = ctotalt, by(unitid instnm countynm)
gsort -total_bachelors

di ""
di "Top 10 KY institutions by bachelor's degrees (2024):"
di "  R pilot expected top 3: UK (10,110), U of L (5,540), WKU (5,470)"
list unitid instnm countynm total_bachelors in 1/10, noobs

*-------------------------------------------------------------------------------
* PART C: Aggregate to county x award level
*-------------------------------------------------------------------------------
use `ky_comp_2024', clear
collapse (sum) n_awards = ctotalt, by(countycd countynm awlevel)
gen year = 2024
sort countycd awlevel

*-------------------------------------------------------------------------------
* PART D: Sanity checks against R pilot
*-------------------------------------------------------------------------------
count
di ""
di "County x awlevel rows: " r(N) "   (R pilot: 216)"

preserve
    duplicates drop countycd, force
    count
    di "Distinct KY counties producing degrees: " r(N) "   (R pilot: 40)"
restore

di ""
di "First 15 rows of county x awlevel panel:"
list countycd countynm awlevel n_awards in 1/15, noobs

*-------------------------------------------------------------------------------
* PART E: Label and save
*-------------------------------------------------------------------------------
label var countycd "5-digit county FIPS"
label var countynm "County name"
label var awlevel  "IPEDS award level code"
label var n_awards "Total awards conferred (first major only)"
label var year     "Academic year (ending year)"

save "data/cleaned/ipeds_ky_completions_2024.dta", replace
di ""
di "Saved: data/cleaned/ipeds_ky_completions_2024.dta"
