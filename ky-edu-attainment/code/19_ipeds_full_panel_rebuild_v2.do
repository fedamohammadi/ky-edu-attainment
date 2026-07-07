*===============================================================================
* 19_ipeds_full_panel_rebuild.do  (v2, with 990000 fix)
*
* CORRECTION #2: The old era (1990-1999) uses cipcode == 990000 as the
* "Total of all programs" summary, not cipcode == 99. Our earlier filter
* missed these rows and let them double-count.
*
* Full aggregation logic per era:
*   1990-1994 (c*_cip files):   total = crace15 + crace16
*   1995-1998 (c*_a files):     total = rowtotal(crace01-crace14 explicit)
*   1999      (c9899_a):        total = crace24 (grand total column)
*   2000-2007 (c*_a files):     total = rowtotal(crace01-crace14 explicit),
*                                       filter majornum==1 where present
*   2008-2024 (c*_a files):     total = ctotalt, filter majornum==1
*
* Universal filter: drop cipcode in ("99", "990000") in every year.
*
* Output: data/cleaned/ipeds_ky_completions_1990_2024.dta (overwrites)
*===============================================================================

clear all
set more off
cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

clear
gen countycd = .
gen str50 countynm = ""
gen awlevel  = .
gen n_awards = .
gen year     = .
tempfile master
save `master', emptyok

*-------------------------------------------------------------------------------
* Loop 1990-1999
*-------------------------------------------------------------------------------
forvalues yr = 1990/1999 {
    di ""
    di "----- Processing year `yr' -----"

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

    * Drop cipcode summary rows: "99" (modern) and "990000" (older era)
    capture confirm string variable cipcode
    if !_rc {
        quietly replace cipcode = strtrim(cipcode)
        quietly drop if inlist(cipcode, "99", "990000")
    }
    else {
        quietly drop if inlist(cipcode, 99, 990000)
    }

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

    * Drop cipcode summary rows
    capture confirm string variable cipcode
    if !_rc {
        quietly replace cipcode = strtrim(cipcode)
        quietly drop if inlist(cipcode, "99", "990000")
    }
    else {
        quietly drop if inlist(cipcode, 99, 990000)
    }

    capture confirm variable majornum
    if !_rc {
        quietly keep if majornum == 1
    }

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
* Validate and save
*-------------------------------------------------------------------------------
use `master', clear
sort year countycd awlevel

count
di ""
di "Total rows in corrected 1990-2024 panel: " r(N)

di ""
di "Full 35-year KY bachelor's series (AWLEVEL 5):"
preserve
    keep if awlevel == 5
    collapse (sum) bachelors = n_awards, by(year)
    list, noobs sepby(year)
restore

label var countycd "5-digit county FIPS"
label var countynm "County name"
label var awlevel  "IPEDS award level code"
label var n_awards "Total awards conferred (KY institutions, first-major only)"
label var year     "Academic year (ending year)"

save "data/cleaned/ipeds_ky_completions_1990_2024.dta", replace
di ""
di "Saved: data/cleaned/ipeds_ky_completions_1990_2024.dta"
