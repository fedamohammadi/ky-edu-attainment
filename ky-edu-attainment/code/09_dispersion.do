*-------------------------------------------------------------------------------
* 09_dispersion.do
* Dispersion of tract BA+ attainment over time, Kentucky, 1990-2024.
* table and the headline figure, natively in Stata.
*
* Run from the repo root, or set the global below to your repo path.
*-------------------------------------------------------------------------------

* global root "C:/path/to/ky-ed-attainment"
* cd "$root"

use "data/cleaned/ky_ed_panel_full_1990_2024.dta", clear

*-------------------------------------------------------------------------------
* 1. Dispersion of pct_baplus across tracts, by year.
*    p90_p10 = absolute spread (pp).  cv = sd/mean = relative spread.
*-------------------------------------------------------------------------------
preserve

collapse (count) n_tracts = pct_baplus ///
         (mean)  mean_ba  = pct_baplus ///
         (sd)    sd_ba    = pct_baplus ///
         (p10)   p10      = pct_baplus ///
         (p90)   p90      = pct_baplus , by(year)

gen p90_p10 = p90 - p10
gen cv      = sd_ba / mean_ba

* flag the decennial years for coloring
gen byte decennial = inlist(year, 1990, 2000)
label define dec 1 "Decennial" 0 "ACS 5-yr"
label values decennial dec

order year n_tracts mean_ba sd_ba p10 p90 p90_p10 cv
format mean_ba sd_ba p10 p90 p90_p10 %5.1f
format cv %5.3f

list year n_tracts mean_ba p10 p90 p90_p10 cv, clean noobs
export delimited using "output/tables/dispersion_by_year.csv", replace

*-------------------------------------------------------------------------------
* 2. Figure: P90-P10 over time.
*    Solid line = 2012-2024 (every year real). Dashed line = across the
*    1990->2000 and 2000->2012 gaps, where no annual data exist.
*    Points: decennial (cranberry) vs ACS (navy).
*-------------------------------------------------------------------------------
twoway ///
    (line    p90_p10 year if year <= 2012, lpattern(dash)  lcolor(gs9) lwidth(medthin)) ///
    (line    p90_p10 year if year >= 2012, lpattern(solid) lcolor(gs9) lwidth(medthin)) ///
    (scatter p90_p10 year if decennial == 1, mcolor(cranberry) msymbol(O) msize(medium)) ///
    (scatter p90_p10 year if decennial == 0, mcolor(navy)      msymbol(O) msize(medium)) ///
    , ///
    title("Spatial dispersion in BA+ attainment, Kentucky tracts, 1990-2024", size(medium)) ///
    subtitle("P90-P10 gap in tract BA+ share (percentage points)", size(small)) ///
    ytitle("P90 - P10 (pp)") xtitle("") ///
    xlabel(1990 2000 2010 2020 2024) ///
    legend(order(3 "Decennial" 4 "ACS 5-yr") position(3) cols(1) region(lstyle(none))) ///
    graphregion(color(white)) plotregion(color(white))

graph export "output/figures/ba_dispersion_1990_2024_stata.png", replace width(2000)

restore

*-------------------------------------------------------------------------------
* Note: the dashed segments connect real points across years with no data.
* They are a visual guide only, not interpolated estimates.
*-------------------------------------------------------------------------------
