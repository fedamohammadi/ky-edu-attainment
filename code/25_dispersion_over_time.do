*-------------------------------------------------------------------------------
* Purpose: Item 2 from Darolia's follow-up: measure how the spread of county
*          BA+ shares has changed over 1940-2024. Compute the P90-P10 gap
*          (absolute spread in percentage points) and the coefficient of
*          variation (relative spread) at each anchor year. Plot both.
* 
* What this file does, in plain English:
*   1. Load the long county panel.
*   2. For each anchor year, compute:
*        - Mean county BA+ share (for context)
*        - 10th and 90th percentile of county BA+ share
*        - P90 - P10 gap (absolute divergence measure)
*        - Coefficient of variation = SD / Mean (relative divergence measure)
*   3. Print the table and save it as CSV.
*   4. Make two figures: one for the P90-P10 gap, one for the CV.
*
* Inputs : data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta
* Outputs: output/tables/dispersion_over_time.csv
*          output/figures/dispersion_p90_p10.png
*          output/figures/dispersion_cv.png
*-------------------------------------------------------------------------------

cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* 1. Load and keep only what we need
*-------------------------------------------------------------------------------
use "data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta", clear

* We only need the year and the county-level BA+ share.
keep year county_fips pct_baplus

* Drop counties with missing BA+ shares (should be very few).
drop if missing(pct_baplus)

*-------------------------------------------------------------------------------
* 2. Compute dispersion stats per year
*-------------------------------------------------------------------------------
* We compute five stats per year using the "epctile" approach through collapse:
*   - mean_ba: mean county share (unweighted; each county counts once)
*   - sd_ba:   standard deviation of county shares
*   - p10, p90: 10th and 90th percentile
*   - n_counties: how many counties contributed to the stat that year
*
* Note: we do NOT population-weight here. The question is about the
* dispersion across county units, so each county gets equal weight.
* If we weighted by population, we'd be answering a different question
* (dispersion across people, not across places).
collapse (mean) mean_ba = pct_baplus ///
         (sd)   sd_ba   = pct_baplus ///
         (p10)  p10     = pct_baplus ///
         (p90)  p90     = pct_baplus ///
         (count) n_counties = pct_baplus, ///
         by(year)

* Derived measures.
gen p90_p10 = p90 - p10                    // absolute spread (pp)
gen cv      = sd_ba / mean_ba              // coefficient of variation

* Formatting for clean output.
format mean_ba sd_ba p10 p90 p90_p10 %6.2f
format cv %6.3f

*-------------------------------------------------------------------------------
* 3. Show table and save
*-------------------------------------------------------------------------------
list year n_counties mean_ba p10 p90 p90_p10 cv, ///
    sep(0) noobs abbreviate(15)

export delimited using "output/tables/dispersion_over_time.csv", replace

*-------------------------------------------------------------------------------
* 4. Chart 1: P90-P10 gap (absolute dispersion)
*-------------------------------------------------------------------------------
* Only label the decadal anchor years so the ACS labels don't crowd the plot.
gen label_p90p10 = p90_p10 if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
format label_p90p10 %4.1f

twoway ///
    (connected p90_p10 year, ///
        lcolor(navy) lwidth(medthick) ///
        mcolor(navy) msymbol(O) msize(small) ///
        mlabel(label_p90p10) mlabposition(12) mlabgap(*2) ///
        mlabsize(vsmall) mlabcolor(black) mlabformat(%4.1f)), ///
    xlabel(1940(10)2020 2024, angle(45)) ///
    ylabel(0(5)40, angle(0)) ///
    xtitle("") ///
    ytitle("P90 - P10 gap (percentage points)") ///
    title("Absolute dispersion of county BA+ shares, 1940-2024", size(medium)) ///
    subtitle("Gap between 90th and 10th percentile counties", size(small) color(gs6)) ///
    note("Each county counts once (unweighted). No county-level data for 1950 or 1960.", size(vsmall) color(gs7)) ///
    graphregion(color(white)) ///
    legend(off) ///
    name(disp_p90p10, replace)

graph export "output/figures/dispersion_p90_p10.png", ///
    replace width(2400)

*-------------------------------------------------------------------------------
* 5. Chart 2: Coefficient of variation (relative dispersion)
*-------------------------------------------------------------------------------
gen label_cv = cv if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
format label_cv %4.2f

twoway ///
    (connected cv year, ///
        lcolor(navy) lwidth(medthick) ///
        mcolor(navy) msymbol(O) msize(small) ///
        mlabel(label_cv) mlabposition(12) mlabgap(*2) ///
        mlabsize(vsmall) mlabcolor(black) mlabformat(%4.2f)), ///
    xlabel(1940(10)2020 2024, angle(45)) ///
    ylabel(0(0.2)1.2, angle(0)) ///
    xtitle("") ///
    ytitle("Coefficient of variation (SD / Mean)") ///
    title("Relative dispersion of county BA+ shares, 1940-2024", size(medium)) ///
    subtitle("Higher = more spread relative to the mean", size(small) color(gs6)) ///
    note("Each county counts once (unweighted). No county-level data for 1950 or 1960.", size(vsmall) color(gs7)) ///
    graphregion(color(white)) ///
    legend(off) ///
    name(disp_cv, replace)

graph export "output/figures/dispersion_cv.png", ///
    replace width(2400)
	
	
	
	