*===============================================================================
* 18_ipeds_full_panel_rebuild.do
*
* CORRECTION: Every year's file contains a CIPCODE == 99 row per
* (institution, awlevel) which is "Total of all programs" and is redundant
* with the sum across individual CIPs. Not filtering it double-counts.
*
* This script rebuilds the FULL 1990-2024 IPEDS Kentucky completions panel
* from raw files with the cipcode==99 filter applied.
*
* Aggregation logic per era:
*   1990-1994 (c*_cip files):   total = crace15 + crace16
*   1995-1998 (c*_a files):     total = rowtotal(crace01-crace14 explicit)
*   1999      (c9899_a):        total = crace24 (grand total column)
*   2000-2007 (c*_a files):     total = rowtotal(crace01-crace14 explicit),
*                                       filter majornum==1 where present
*   2008-2024 (c*_a files):     total = ctotalt, filter majornum==1
*
* Universal filter: drop cipcode == 99 in EVERY year.
*
* Output: data/cleaned/ipeds_ky_completions_1990_2024.dta (overwrites)
*===============================================================================

clear all
set more off
cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* Initialize empty master
*-------------------------------------------------------------------------------
clear
gen countycd = .
gen str50 countynm = ""
gen awlevel  = .
gen n_awards = .
gen year     = .
tempfile master
save `master', emptyok

*-------------------------------------------------------------------------------
* Program: filter cipcode==99 safely for either numeric or string cipcode
*-------------------------------------------------------------------------------
* We'll do it inline in the loop with a small conditional block.

*-------------------------------------------------------------------------------
* Loop 1990-1999
*-------------------------------------------------------------------------------
forvalues yr = 1990/1999 {
    di ""
    di "----- Processing year `yr' -----"

    * Filename
    if `yr' == 1990      local fname "c8990cip_data_stata"
    else if `yr' == 1991 local fname "c1991_cip_data_stata"
    else if `yr' == 1992 local fname "c1992_cip_data_stata"
    else if `yr' == 1993 local fname "c1993_cip_data_stata"
    else if `yr' == 1994 local fname "c1994_cip_data_stata"
    else if `yr' == 1995 local fname "c9495_a_data_stata"
    else if `yr' == 1996 local fname "c9596_a_data_stata"
    else if `yr' == 1997 local fname "c9697_a_data_stata"
    else if `yr' == 1998 local fname "c9798_a_data_stata"
    else if `yr' == 1999 local fname "c9899_a_data_stata"

    capture import delimited "data/raw/ipeds/`fname'.csv", clear
    if _rc {
        di as error "  Could not load `fname'.csv (rc=" _rc "). Skipping."
        continue
    }

    * Drop cipcode==99 (Total of all programs summary rows).
    * Handles either string or numeric storage.
    capture confirm string variable cipcode
    if !_rc {
        quietly replace cipcode = strtrim(cipcode)
        quietly drop if cipcode == "99"
    }
    else {
        quietly drop if cipcode == 99
    }

    * Build total_awards per era
    if inrange(`yr', 1990, 1994) {
        capture destring crace15 crace16, replace force
        quietly gen double total_awards = crace15 + crace16
    }
    else if inrange(`yr', 1995, 1998) {
        capture destring crace01 crace02 crace03 crace04 crace05 crace06 ///
                          crace07 crace08 crace09 crace10 crace11 crace12 ///
                          crace13 crace14, replace force
        quietly egen double total_awards = rowtotal(crace01 crace02 crace03 ///
            crace04 crace05 crace06 crace07 crace08 crace09 crace10 ///
            crace11 crace12 crace13 crace14)
    }
    else if `yr' == 1999 {
        capture destring crace24, replace force
        quietly gen double total_awards = crace24
    }

    * Merge with KY crosswalk
    quietly merge m:1 unitid using "data/cleaned/ipeds_ky_crosswalk.dta", ///
        keep(match) keepusing(countycd countynm) nogen

    * Aggregate to county x awlevel
    quietly collapse (sum) n_awards = total_awards, by(countycd countynm awlevel)
    quietly gen year = `yr'

    quietly count
    di "  Rows for `yr': " r(N)

    quietly append using `master'
    quietly save `master', replace
}

*-------------------------------------------------------------------------------
* Loop 2000-2024
*-------------------------------------------------------------------------------
forvalues yr = 2000/2024 {
    di ""
    di "----- Processing year `yr' -----"

    capture import delimited "data/raw/ipeds/c`yr'_a.csv", clear
    if _rc {
        di as error "  Could not load c`yr'_a.csv (rc=" _rc "). Skipping."
        continue
    }

    * Drop cipcode==99
    capture confirm string variable cipcode
    if !_rc {
        quietly replace cipcode = strtrim(cipcode)
        quietly drop if cipcode == "99"
    }
    else {
        quietly drop if cipcode == 99
    }

    * Filter to first majors if majornum exists
    capture confirm variable majornum
    if !_rc {
        quietly keep if majornum == 1
    }

    * Build total_awards
    capture confirm variable ctotalt
    if !_rc {
        quietly gen double total_awards = ctotalt
    }
    else {
        capture destring crace01 crace02 crace03 crace04 crace05 crace06 ///
                          crace07 crace08 crace09 crace10 crace11 crace12 ///
                          crace13 crace14, replace force
        quietly egen double total_awards = rowtotal(crace01 crace02 crace03 ///
            crace04 crace05 crace06 crace07 crace08 crace09 crace10 ///
            crace11 crace12 crace13 crace14)
    }

    quietly merge m:1 unitid using "data/cleaned/ipeds_ky_crosswalk.dta", ///
        keep(match) keepusing(countycd countynm) nogen

    quietly collapse (sum) n_awards = total_awards, by(countycd countynm awlevel)
    quietly gen year = `yr'

    quietly count
    di "  Rows for `yr': " r(N)

    quietly append using `master'
    quietly save `master', replace
}

*-------------------------------------------------------------------------------
* Load, validate, save
*-------------------------------------------------------------------------------
use `master', clear
sort year countycd awlevel

count
di ""
di "Total rows in corrected 1990-2024 panel: " r(N)

di ""
di "Full 35-year KY bachelor's series (AWLEVEL 5) - should now be halved:"
preserve
    keep if awlevel == 5
    collapse (sum) bachelors = n_awards, by(year)
    list, noobs sepby(year)
restore

di ""
di "Sanity checks - 2024:"
preserve
    keep if year == 2024 & awlevel == 5
    sum n_awards
    di "  Total KY bachelor's 2024: " r(sum) "  (expected ~24,600)"
restore
preserve
    keep if year == 2024 & awlevel == 5 & countycd == 21067
    sum n_awards
    di "  Fayette County 2024 bachelor's: " r(sum) "  (mostly UK, expected ~5,300)"
restore

label var countycd "5-digit county FIPS"
label var countynm "County name"
label var awlevel  "IPEDS award level code"
label var n_awards "Total awards conferred (KY institutions, first-major only)"
label var year     "Academic year (ending year)"

save "data/cleaned/ipeds_ky_completions_1990_2024.dta", replace
di ""
di "Saved: data/cleaned/ipeds_ky_completions_1990_2024.dta (corrected)"
