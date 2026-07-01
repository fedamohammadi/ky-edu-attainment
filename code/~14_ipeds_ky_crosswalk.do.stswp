*===============================================================================
* 14_ipeds_ky_crosswalk.do
*
* Build UNITID -> county crosswalk for Kentucky institutions.
* Uses hd2024 as primary (most current), then appends hd2000 to catch
* institutions that closed between 2000 and 2024.
*
* Input files (in data/raw/ipeds/):
*   hd2000.dta
*   hd2024.dta
*
* Output: data/cleaned/ipeds_ky_crosswalk.dta
*
* Assumes IPEDS Stata files store variable names in lowercase (modern convention).
* If they are uppercase, replace unitid -> UNITID, etc.
*===============================================================================

clear all
set more off

cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* PART A: Load hd2024 (CSV), filter to KY
*-------------------------------------------------------------------------------
import delimited "data/raw/ipeds/hd2024.csv", clear varnames(1) case(lower)
keep if stabbr == "KY"
keep unitid instnm stabbr countycd countynm
gen source_year = 2024
tempfile hd24
save `hd24'

count
di "KY institutions in hd2024: " r(N)

*-------------------------------------------------------------------------------
* PART B: Load hd2000 (CSV), filter to KY
*-------------------------------------------------------------------------------
import delimited "data/raw/ipeds/hd2010.csv", clear varnames(1) case(lower)
keep if stabbr == "KY"
keep unitid instnm stabbr countycd countynm
gen source_year = 2010
tempfile hd10
save `hd10'

count
di "KY institutions in hd2000: " r(N)

*-------------------------------------------------------------------------------
* PART C: Combine, keeping hd2024 record when institution appears in both
*-------------------------------------------------------------------------------
use `hd24', clear
append using `hd00'

* Sort so hd2024 records come first for each UNITID; drop duplicates keeping first.
gsort unitid -source_year
duplicates drop unitid, force

*-------------------------------------------------------------------------------
* PART D: Sanity checks
*-------------------------------------------------------------------------------
count
di "Total KY institutions in crosswalk: " r(N)

tab source_year
di "  source_year == 2024: still open in 2024"
di "  source_year == 2000: present in 2000 but absent from hd2024 (likely closed)"

* Spot-check a few known institutions
di ""
di "Spot check (UK, U of L, Berea, WKU):"
list unitid instnm countynm if inlist(unitid, 157085, 157289, 156620, 157951), ///
    noobs sepby(unitid)

*-------------------------------------------------------------------------------
* PART E: Label and save
*-------------------------------------------------------------------------------
label var unitid       "IPEDS institution ID"
label var instnm       "Institution name"
label var stabbr       "State abbreviation"
label var countycd     "5-digit county FIPS"
label var countynm     "County name"
label var source_year  "HD file year that supplied this record"

save "data/cleaned/ipeds_ky_crosswalk.dta", replace
di ""
di "Saved: data/cleaned/ipeds_ky_crosswalk.dta"
