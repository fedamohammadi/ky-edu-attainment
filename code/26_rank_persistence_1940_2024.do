*-------------------------------------------------------------------------------
* Purpose: Item 3 from Darolia's follow-up: how much have county rankings on
*          BA+ share changed between 1940 and 2024? Compute Spearman and
*          Kendall's tau correlations, then look at bottom-10% persistence
*          and top-10% persistence, and identify counties with the biggest
*          rank changes.
* 
* What this file does:
*   1. Load the long county panel.
*   2. Keep only 1940 and 2024, then reshape wide so each county has one row
*      with its 1940 share and its 2024 share side by side. Drop counties
*      that don't have data in both years (typically Alaska boroughs and a
*      few Connecticut counties that changed FIPS).
*   3. Rank counties within each year (1 = lowest BA+, N = highest).
*   4. Compute Spearman rank correlation between 1940 and 2024 rankings.
*      Also compute Kendall's tau for robustness.
*   5. Transition matrix: for counties in the bottom 10% in 1940, where
*      did they end up in 2024? Same for the top 10%.
*   6. List the counties that moved up the most (climbers) and moved down
*      the most (fallers).
*
* Inputs : data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta
* Outputs: output/tables/rank_persistence_summary.csv
*          output/tables/rank_persistence_movers.csv
*          output/figures/rank_persistence_scatter.png
*-------------------------------------------------------------------------------

cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* 1. Load and reshape to have 1940 and 2024 side by side
*-------------------------------------------------------------------------------
use "data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta", clear

* Keep only what we need. Drop state/county names before reshape
* because they're inconsistent across years (caps vs title case).
keep county_fips year pct_baplus pop25plus

* Keep only 1940 and 2024
keep if year == 1940 | year == 2024

* Reshape wide: one row per county with 1940 and 2024 side by side.
reshape wide pct_baplus pop25plus, i(county_fips) j(year)

* Drop counties without data in both years.
drop if missing(pct_baplus1940) | missing(pct_baplus2024)

count
di "Counties with data in BOTH 1940 and 2024: " r(N)

* Now merge back the county names from 2024 (the more readable format).
preserve
    use "data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta", clear
    keep if year == 2024
    keep county_fips state county
    tempfile names
    save `names'
restore

merge 1:1 county_fips using `names', keep(master match) nogenerate

*-------------------------------------------------------------------------------
* 2. Rank each county within each year
*-------------------------------------------------------------------------------
* Higher BA+ share = higher rank number.
* Use egen rank() which handles ties by averaging their ranks.
egen rank_1940 = rank(pct_baplus1940)
egen rank_2024 = rank(pct_baplus2024)

* Change in rank position. Positive = moved up over 84 years.
gen rank_change = rank_2024 - rank_1940

*-------------------------------------------------------------------------------
* 3. Spearman and Kendall's tau
*-------------------------------------------------------------------------------
di ""
di "=== Rank correlations between 1940 and 2024 BA+ shares ==="
di ""

* spearman is Stata's built-in Spearman rank correlation
spearman pct_baplus1940 pct_baplus2024, stats(rho p)

* ktau is Kendall's tau
ktau pct_baplus1940 pct_baplus2024, stats(taua taub p)

*-------------------------------------------------------------------------------
* 4. Transition matrix: bottom 10% and top 10% persistence
*-------------------------------------------------------------------------------
* Classify each county's position in 1940 and in 2024 by decile.
xtile decile_1940 = pct_baplus1940, nquantiles(10)
xtile decile_2024 = pct_baplus2024, nquantiles(10)

* Persistence in bottom decile
di ""
di "=== Where did the bottom 10% in 1940 end up in 2024? ==="
tab decile_2024 if decile_1940 == 1, missing

* Persistence in top decile
di ""
di "=== Where did the top 10% in 1940 end up in 2024? ==="
tab decile_2024 if decile_1940 == 10, missing

* Compute the two headline persistence numbers explicitly
qui count if decile_1940 == 1 & decile_2024 == 1
scalar bottom_stayed = r(N)
qui count if decile_1940 == 1
scalar bottom_total = r(N)
di ""
di "Bottom 10% persistence: " bottom_stayed " of " bottom_total ///
   " counties in bottom decile 1940 are still in bottom decile 2024 (" ///
   %5.1f 100*bottom_stayed/bottom_total "%)"

qui count if decile_1940 == 10 & decile_2024 == 10
scalar top_stayed = r(N)
qui count if decile_1940 == 10
scalar top_total = r(N)
di "Top 10% persistence: " top_stayed " of " top_total ///
   " counties in top decile 1940 are still in top decile 2024 (" ///
   %5.1f 100*top_stayed/top_total "%)"

*-------------------------------------------------------------------------------
* 5. Biggest climbers and fallers
*-------------------------------------------------------------------------------
* Sort by rank_change descending. Top climbers are the biggest positive changes.
gsort -rank_change

di ""
di "=== Top 15 counties that climbed the most in rank, 1940 to 2024 ==="
list county state pct_baplus1940 pct_baplus2024 rank_1940 rank_2024 rank_change ///
     in 1/15, sep(0) abbreviate(30)

* Bottom of the list = biggest fallers.
gsort rank_change

di ""
di "=== Top 15 counties that fell the most in rank, 1940 to 2024 ==="
list county state pct_baplus1940 pct_baplus2024 rank_1940 rank_2024 rank_change ///
     in 1/15, sep(0) abbreviate(30)

*-------------------------------------------------------------------------------
* 6. Save the movers table
*-------------------------------------------------------------------------------
preserve
    gsort rank_change
    keep county_fips state county pct_baplus1940 pct_baplus2024 ///
         rank_1940 rank_2024 rank_change
    export delimited using "output/tables/rank_persistence_movers.csv", replace
restore

*-------------------------------------------------------------------------------
* 7. Scatter plot: 1940 rank vs 2024 rank
*-------------------------------------------------------------------------------
* If ranks are perfectly persistent, all points fall on the 45-degree line.
* If ranks are completely scrambled, the points look like a cloud.
* The tightness around the 45-degree line visually communicates the Spearman rho.

twoway ///
    (scatter rank_2024 rank_1940, ///
        msymbol(o) msize(vsmall) mcolor(navy%40)) ///
    (function y = x, range(1 3200) lcolor(black) lpattern(dash) lwidth(thin)), ///
    xtitle("County rank in 1940 (1 = lowest BA+)") ///
    ytitle("County rank in 2024") ///
    title("Rank persistence in county BA+ share, 1940 vs 2024", size(medium)) ///
    subtitle("Each dot is one county. Dashed line = perfect persistence.", size(small) color(gs6)) ///
    xlabel(0(500)3000, angle(0)) ///
    ylabel(0(500)3000, angle(0)) ///
    graphregion(color(white)) ///
    legend(off) ///
    aspectratio(1) ///
    name(rank_scatter, replace)

graph export "output/figures/rank_persistence_scatter.png", ///
    replace width(2400)
	
	
	