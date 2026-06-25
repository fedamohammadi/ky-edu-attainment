*===============================================================================
* 11_variance_decomp.do
*-------------------------------------------------------------------------------
* Decompose tract-level BA+ dispersion into BETWEEN-county and WITHIN-county
* parts, separately for each year, using the law of total variance.
*
*   Total = Between + Within
*   Between = sum_c  W_c (mean_c - mean_grand)^2          (county means spread)
*   Within  = sum_c  W_c * Var_c                          (tract spread inside c)
*
* Everything is POPULATION-WEIGHTED by adult population (wt_adult), to match the
* weighting used for the P90-P10 headline. Weights are summed (population /
* fweight definition of variance, divide by Sum(w)), NOT the aweight (N-1)
* definition. This is the ONLY definition for which Between + Within = Total
* holds exactly. The script asserts that identity at the end of every year.
*
* Run from the repo root, same working directory as your other .do files.
*===============================================================================

clear all
set more off

* force working dir to repo root so the relative paths below always resolve
cd "C:\Users\mohammadif\Documents\ky-ed-attainment"

*--- CONFIRM these three names against your panel before running ---------------
local panel "data/cleaned/ky_ed_panel_full_1990_2024.dta"
local y       pct_baplus    // BA+ share, 0-100
local w       pop25plus     // adult-population weight (pop 25+)
local geo     geoid         // lowercase, 11-digit 2020 tract GEOID
*------------------------------------------------------------------------------

use "`panel'", clear

* county id = first 5 chars of the tract GEOID (state 2 + county 3)
capture confirm string variable `geo'
if _rc tostring `geo', replace
gen str5 county = substr(`geo', 1, 5)

* keep usable tracts only (zero-pop tracts are set missing upstream)
drop if missing(`y') | missing(`w') | `w' <= 0

* --- sanity check: tract composition should be ~constant across years ---------
* If counts swing year to year, the trajectory mixes composition change with
* real sorting. Eyeball this before interpreting.
tab year

levelsof year, local(years)

tempfile out
postfile handle int year long n_tracts double(between within total btw_share) ///
    using "`out'", replace

foreach yr of local years {
    preserve
        keep if year == `yr'
        local N = _N

        * total adult weight in this year
        quietly summarize `w', meanonly
        scalar Wtot = r(sum)

        * grand population-weighted mean (manual, population definition)
        gen double _wy = `w' * `y'
        quietly summarize _wy, meanonly
        scalar gmean = r(sum) / Wtot

        * county population-weighted means
        bysort county: egen double _cw  = total(`w')
        bysort county: egen double _cwy = total(`w' * `y')
        gen double cmean = _cwy / _cw

        * per-tract pieces, then sum and divide by total weight
        gen double _btw = `w' * (cmean - gmean)^2
        gen double _wth = `w' * (`y'   - cmean)^2
        gen double _tot = `w' * (`y'   - gmean)^2     // for the conservation check

        quietly summarize _btw, meanonly
        scalar between = r(sum) / Wtot
        quietly summarize _wth, meanonly
        scalar within  = r(sum) / Wtot
        quietly summarize _tot, meanonly
        scalar total   = r(sum) / Wtot

        * CONSERVATION CHECK: between + within must equal total
        assert abs((between + within) - total) < 1e-8

        post handle (`yr') (`N') (between) (within) (total) (between/total)
    restore
}
postclose handle

*--- results ------------------------------------------------------------------
use "`out'", clear
format between within total %9.4f
format btw_share          %6.3f

label var n_tracts  "Tracts"
label var between   "Between-county var"
label var within    "Within-county var"
label var total     "Total var"
label var btw_share "Between share of total"

list year n_tracts between within total btw_share, clean noobs
save "output/tables/vardecomp_by_year.dta", replace

*--- plot 1: between-county SHARE of total variance over time ------------------
* y-axis trimmed to the data range so the 11-point rise is visible, not flat.
twoway line btw_share year, sort lwidth(medthick) ///
    title("Between-county share of BA+ variance, KY tracts") ///
    ytitle("Between-county share of total variance") xtitle("") ///
    ylabel(0.30(0.05)0.45, format(%4.2f) grid) ///
    xlabel(1990(5)2025)
graph export "output/figures/btw_share_trajectory.png", replace width(1600)

*--- plot 2: LEVELS of between and within variance over time ------------------
* This is the better figure for the report: shows total dispersion doubling AND
* that between-county grew faster than within-county.
twoway (line between year, sort lwidth(medthick)) ///
       (line within  year, sort lwidth(medthick) lpattern(dash)) ///
       (line total   year, sort lwidth(medthick) lpattern(shortdash)), ///
    title("Decomposition of BA+ variance, KY tracts 1990-2024") ///
    ytitle("Variance (BA+ share, pp{superscript:2})") xtitle("") ///
    xlabel(1990(5)2025) ///
    legend(order(1 "Between-county" 2 "Within-county" 3 "Total") ///
           rows(1) position(6))
graph export "output/figures/vardecomp_levels.png", replace width(1600)
