*===============================================================================
* 17_extend_ky_crosswalk_1999.do
*
* Extends the KY UNITID -> county crosswalk backward using ic99_hd.
* Catches institutions that existed in 1999 but closed before 2010.
*
* Input:  data/raw/ipeds/ic99_hd_data_stata.csv  (verify filename first!)
* Input:  data/cleaned/ipeds_ky_crosswalk.dta    (from script 14)
*
* Output: data/cleaned/ipeds_ky_crosswalk.dta    (updated in place)
*
* Notes on ic99_hd schema:
*   - No countycd. Must be built as (fips * 1000 + cntygeo).
*   - KY is state FIPS 21.
*   - No stabbr — filter by fips == 21.
*===============================================================================

clear all
set more off
cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* PART A: Load ic99_hd, filter to KY, construct countycd
*-------------------------------------------------------------------------------
import delimited "data/raw/ipeds/ic99_hd_data_stata.csv", clear

* Make sure fips and cntygeo are numeric before arithmetic
capture destring fips cntygeo, replace force

keep if fips == 21

* Build 5-digit county FIPS: state * 1000 + county
gen long countycd = fips * 1000 + cntygeo
format countycd %5.0f

* Keep only the crosswalk fields, add stabbr and source_year
keep unitid instnm countycd countynm
gen stabbr = "KY"
gen source_year = 1999

count
di "KY institutions in ic99_hd: " r(N)

tempfile hd99
save `hd99'

*-------------------------------------------------------------------------------
* PART B: Append to existing crosswalk, keep newer record for duplicates
*-------------------------------------------------------------------------------
use "data/cleaned/ipeds_ky_crosswalk.dta", clear
append using `hd99'

* Keep most recent source_year for each UNITID
gsort unitid -source_year
duplicates drop unitid, force

*-------------------------------------------------------------------------------
* PART C: Sanity checks
*-------------------------------------------------------------------------------
count
di ""
di "Total KY institutions in extended crosswalk: " r(N)
di "  (Was 128 before adding 1999 records)"

di ""
tab source_year
di ""
di "  source_year meaning:"
di "    2024 = still open in 2024"
di "    2010 = in hd2010 but not hd2024  (closed 2010-2024)"
di "    1999 = in ic99_hd but not hd2010 (closed 1999-2010)"

*-------------------------------------------------------------------------------
* PART D: Save (overwrite crosswalk)
*-------------------------------------------------------------------------------
label var unitid       "IPEDS institution ID"
label var instnm       "Institution name"
label var stabbr       "State abbreviation"
label var countycd     "5-digit county FIPS"
label var countynm     "County name"
label var source_year  "HD file year that supplied this record"

save "data/cleaned/ipeds_ky_crosswalk.dta", replace
di ""
di "Saved: data/cleaned/ipeds_ky_crosswalk.dta (updated with 1999 records)"
