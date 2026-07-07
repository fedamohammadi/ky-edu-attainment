*===============================================================================
* 16_ipeds_completions_2000_2024_loop.do
*
* Loop over academic years 2000-2024, aggregating IPEDS completions
* to county x awlevel x year for Kentucky, and append into a long panel.
*
* Handles three schema eras:
*   - 2000:      no majornum, no ctotalt -> sum crace01-crace16
*   - 2001-2007: majornum exists, no ctotalt -> sum crace01-crace16, filter majornum
*   - 2008-2024: both exist -> use ctotalt, filter majornum
*
* Inputs:
*   data/raw/ipeds/c{YEAR}_a.csv
*   data/cleaned/ipeds_ky_crosswalk.dta
*
* Output: data/cleaned/ipeds_ky_completions_2000_2024.dta
*===============================================================================
clear all
set more off
cd "C:/Users/mohammadif/Documents/ky-edu-attainment"
*-------------------------------------------------------------------------------
* Initialize empty master panel
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
* Loop over years 2000-2024
*-------------------------------------------------------------------------------
forvalues yr = 2000/2024 {
    di ""
    di "----- Processing year `yr' -----"
    * Load completions for this year
    capture import delimited "data/raw/ipeds/c`yr'_a.csv", ///
        clear varnames(1) case(lower)
    if _rc {
        di as error "  Could not load c`yr'_a.csv (rc=" _rc "). Skipping."
        continue
    }
    * --- Filter to first majors if majornum is present ---
    capture confirm variable majornum
    if !_rc {
        quietly keep if majornum == 1
    }
    else {
        di "  Note: no majornum in `yr' - assuming all rows are first majors."
    }
    * --- Build total-awards variable ---
    capture confirm variable ctotalt
    if !_rc {
        quietly gen double total_awards = ctotalt
    }
    else {
        * Ensure crace01-crace16 are numeric before summing
        quietly destring crace01-crace16, replace force
        quietly egen double total_awards = rowtotal(crace01-crace14)
    }
    * --- Merge with KY crosswalk (filters to KY, brings in county fields) ---
    quietly merge m:1 unitid using "data/cleaned/ipeds_ky_crosswalk.dta", ///
        keep(match) keepusing(countycd countynm) nogen
    * --- Aggregate to county x awlevel ---
    quietly collapse (sum) n_awards = total_awards, by(countycd countynm awlevel)
    quietly gen year = `yr'
    quietly count
    di "  Rows for `yr': " r(N)
    * --- Append to master ---
    quietly append using `master'
    quietly save `master', replace
}
*-------------------------------------------------------------------------------
* Load master, sanity checks
*-------------------------------------------------------------------------------
use `master', clear
sort year countycd awlevel
count
di ""
di "Total rows in 2000-2024 panel: " r(N)
preserve
    duplicates drop year, force
    count
    di "Distinct years: " r(N) "   (expected: 25)"
restore
di ""
di "Rows and distinct counties by year:"
preserve
    egen tag_county = tag(year countycd)
    collapse (count) n_rows = n_awards (sum) n_counties = tag_county, by(year)
    list, noobs sepby(year)
restore
di ""
di "Total KY bachelor's degrees (AWLEVEL 5) by year:"
preserve
    keep if awlevel == 5
    collapse (sum) bachelors = n_awards, by(year)
    list, noobs sepby(year)
restore
*-------------------------------------------------------------------------------
* Label and save
*-------------------------------------------------------------------------------
label var countycd "5-digit county FIPS"
label var countynm "County name"
label var awlevel  "IPEDS award level code"
label var n_awards "Total awards conferred (first major only, KY institutions)"
label var year     "Academic year (ending year)"
save "data/cleaned/ipeds_ky_completions_2000_2024.dta", replace
di ""
di "Saved: data/cleaned/ipeds_ky_completions_2000_2024.dta"