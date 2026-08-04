*-------------------------------------------------------------------------------
* Purpose: Item 1 from Darolia's follow-up: show the national BA+ trajectory 
*          across the full 1940-2024 panel. Compute the population-weighted
*          national BA+ share at each anchor year, then plot it and export
*          a small summary table.
* 
* What this file does:
*   1. Load the long county panel (has attainment for 18 anchor years).
*   2. For each year, sum ba_plus and pop25plus across all counties.
*   3. Divide to get the national population-weighted BA+ share.
*   4. Also compute the average pp-per-year growth between consecutive anchors,
*      which is what shows whether growth "sped up after 2000."
*   5. Save the summary table as CSV, and export a line chart as PNG.
*
* Inputs : data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta
* Outputs: output/tables/natl_baplus_trajectory.csv
*          output/figures/natl_baplus_trajectory.png
*-------------------------------------------------------------------------------

* Force Stata's working directory to be the project root, so all relative paths
* below (data/, output/) resolve correctly regardless of where Stata was opened.
cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* 1. Load the long county panel
*-------------------------------------------------------------------------------
use "data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta", clear

* Keep only the columns we need for this exercise, so the collapse below is fast
* and unambiguous. We only need year + the two count variables.
keep year pop25plus ba_plus

*-------------------------------------------------------------------------------
* 2. Sum counts to the national level, then compute the share
*-------------------------------------------------------------------------------
* Collapse to one row per year. sum() sums the counts across counties.
collapse (sum) pop25plus ba_plus, by(year)

* National population-weighted BA+ share in percent.
* We compute the share on TOTALS, not by averaging county shares, because
* averaging shares would give every county equal weight regardless of size.
gen natl_baplus_pct = 100 * ba_plus / pop25plus

* Round to two decimals for readability.
format natl_baplus_pct %6.2f

*-------------------------------------------------------------------------------
* 3. Compute pp-per-year growth between consecutive anchor years
*-------------------------------------------------------------------------------
* The panel is not annual; there are big gaps (e.g., 1940 -> 1970 is 30 years).
* We want a "growth speed" that is comparable across gaps of different lengths,
* so we compute the average change per year, not the total change.
sort year
gen gap_years        = year - year[_n-1]
gen pp_change_total  = natl_baplus_pct - natl_baplus_pct[_n-1]
gen pp_per_year      = pp_change_total / gap_years

format pp_change_total pp_per_year %6.3f

*-------------------------------------------------------------------------------
* 4. Show the table on screen and save it
*-------------------------------------------------------------------------------
list year natl_baplus_pct pp_change_total pp_per_year, ///
    sep(0) noobs abbreviate(20)

* Save as CSV so it can be pasted into the LaTeX report if needed.
export delimited using "output/tables/natl_baplus_trajectory.csv", replace

*-------------------------------------------------------------------------------
* 5. Line chart of the trajectory
*-------------------------------------------------------------------------------
* Plot the actual anchor years as points connected by lines. Because the panel
* is uneven (1940, 1970, 1980, 1990, 2000, then annual 2012-2024), we mark
* every point so the reader sees where the real observations are.
* Label only the anchor decadal years so the ACS labels don't crowd the plot.
gen label_year = natl_baplus_pct if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
format label_year %3.1f

twoway ///
    (connected natl_baplus_pct year, ///
        lcolor(navy) lwidth(medthick) ///
        mcolor(navy) msymbol(O) msize(small) ///
        mlabel(label_year) mlabposition(12) mlabgap(*2) ///
        mlabsize(vsmall) mlabcolor(black) mlabformat(%3.1f)), ///
    xlabel(1940(10)2020 2024, angle(45)) ///
    ylabel(0(5)40, angle(0)) ///
    xtitle("") ///
    ytitle("National BA+ share (%)") ///
    title("U.S. BA+ share of adults 25+, 1940-2024", size(medium)) ///
    subtitle("Population-weighted from the long county panel", size(small) color(gs6)) ///
    note("Anchor years: 1940, 1970, 1980, 1990, 2000, 2012-2024. No county-level data for 1950 or 1960.", size(vsmall) color(gs7)) ///
    graphregion(color(white)) ///
    legend(off) ///
    name(natl_traj, replace)

graph export "output/figures/natl_baplus_trajectory.png", ///
    replace width(2400)