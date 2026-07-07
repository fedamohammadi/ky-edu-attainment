*===============================================================================
* Beta-convergence in tract BA+ attainment, Kentucky 1990-2024.
*
* Mirrors the variance decomposition with three regressions:
*   (1) Tract pooled, no FE        -> unconditional beta
*   (2) Tract with county FE       -> WITHIN-county convergence
*   (3) County-level (collapsed)   -> BETWEEN-county convergence
* Plus two sub-period checks on (1):
*   (4) 1990-2012  (decennial-anchored leg)
*   (5) 2012-2024  (ACS-only leg)
*
* Dep var: change in BA+ share (pp). Initial BA+ in pp.
* Weights: population at baseline year (pop25plus).
* SEs:     clustered at county for tract regressions; robust for county.
*
* Requires: reghdfe, estout.
*   ssc install reghdfe
*   ssc install estout
*===============================================================================

clear all
set more off

cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* PART A: Build tract-level wide file
*-------------------------------------------------------------------------------
use "data/cleaned/ky_ed_panel_full_1990_2024.dta", clear

keep geoid year pop25plus pct_baplus
keep if inlist(year, 1990, 2012, 2024)
drop if missing(pct_baplus) | pop25plus <= 0

reshape wide pct_baplus pop25plus, i(geoid) j(year)

* drop tracts not observed in all three benchmark years
drop if missing(pct_baplus1990) | missing(pct_baplus2012) | missing(pct_baplus2024)

* growth measures (total change, pp)
gen g_full  = pct_baplus2024 - pct_baplus1990
gen g_early = pct_baplus2012 - pct_baplus1990
gen g_late  = pct_baplus2024 - pct_baplus2012

* county id from first 5 chars of tract geoid
gen str5 county_fips_str = substr(geoid, 1, 5)
destring county_fips_str, gen(county_fips)
drop county_fips_str

tempfile tract_wide
save `tract_wide'

*-------------------------------------------------------------------------------
* PART B: Build county-level wide file
*-------------------------------------------------------------------------------
use "data/cleaned/ky_ed_county_panel_1990_2024.dta", clear

keep county_fips county year pop25plus pct_baplus
keep if inlist(year, 1990, 2012, 2024)
drop if missing(pct_baplus) | pop25plus <= 0

reshape wide pct_baplus pop25plus, i(county_fips) j(year)

gen g_full = pct_baplus2024 - pct_baplus1990

tempfile county_wide
save `county_wide'

*-------------------------------------------------------------------------------
* PART C: Regressions
*-------------------------------------------------------------------------------

* (1) Tract pooled, no FE
use `tract_wide', clear
reg g_full pct_baplus1990 [aw=pop25plus1990], vce(cluster county_fips)
estimates store m1

* (2) Tract with county FE -- within-county beta
reghdfe g_full pct_baplus1990 [aw=pop25plus1990], ///
    absorb(county_fips) vce(cluster county_fips)
estimates store m2

* (3) County level -- between-county beta
use `county_wide', clear
reg g_full pct_baplus1990 [aw=pop25plus1990], robust
estimates store m3

* (4) Tract pooled, 1990-2012
use `tract_wide', clear
reg g_early pct_baplus1990 [aw=pop25plus1990], vce(cluster county_fips)
estimates store m4

* (5) Tract pooled, 2012-2024  (uses 2012 as baseline)
reg g_late pct_baplus2012 [aw=pop25plus2012], vce(cluster county_fips)
estimates store m5

*-------------------------------------------------------------------------------
* PART D: Output table
*-------------------------------------------------------------------------------
esttab m1 m2 m3 m4 m5 using "output/tables/beta_convergence.tex", ///
    replace booktabs ///
    b(3) se(3) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
    mtitles("Tract pooled" "Tract + county FE" "County" "1990-2012" "2012-2024") ///
    coeflabels(pct_baplus1990 "Initial BA+ share (pp)" ///
               pct_baplus2012 "Initial BA+ share (pp)" ///
               _cons "Constant") ///
    title("Beta-convergence in BA+ attainment, Kentucky 1990-2024") ///
    addnotes("Dependent variable: total change in BA+ share over the period (pp)." ///
             "Weights: adult population at baseline year." ///
             "SEs clustered at county (tract regressions); robust (county regression).")

* also dump to console for quick reading
esttab m1 m2 m3 m4 m5, b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2) ///
    mtitles("Tract pooled" "Tract + cty FE" "County" "1990-2012" "2012-2024")
