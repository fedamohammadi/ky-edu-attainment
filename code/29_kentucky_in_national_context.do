*-------------------------------------------------------------------------------
* Purpose: Put Kentucky in the national picture
*          across 84 years. Compare KY average to national average, identify
*          top/bottom KY counties by gain, and count KY counties in the
*          bottom 10% nationally at each anchor year.
* 
* What this file does:
*   1. Load the long county panel.
*   2. Compute the national and Kentucky population-weighted BA+ share for
*      every anchor year, and the KY-national gap.
*   3. Reshape KY counties to have 1940 and 2024 side by side, compute the
*      total pp change for each, and list the top 8 and bottom 8.
*   4. For each anchor year, rank counties nationally and count how many
*      Kentucky counties sit in the bottom 10% of the national distribution.
*   5. Save tables and produce a chart of KY vs national trajectory.
*
* Inputs : data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta
* Outputs: output/tables/ky_vs_national_trajectory.csv
*          output/tables/ky_county_gains_1940_2024.csv
*          output/tables/ky_in_national_bottom10.csv
*          output/figures/ky_vs_national_trajectory.png
*-------------------------------------------------------------------------------

cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* Part A: KY vs national BA+ trajectory
*-------------------------------------------------------------------------------
use "data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta", clear
keep year county_fips state_fips pop25plus ba_plus
drop if missing(ba_plus) | missing(pop25plus)

* National population-weighted BA+ share and KY population-weighted BA+ share.
* Doing them together with a preserve/restore pattern.
preserve
    * Compute national totals per year.
    collapse (sum) natl_pop = pop25plus natl_ba = ba_plus, by(year)
    gen natl_ba_share = 100 * natl_ba / natl_pop
    keep year natl_ba_share
    tempfile natl
    save `natl'
restore

* KY totals per year.
keep if state_fips == "21"
collapse (sum) ky_pop = pop25plus ky_ba = ba_plus, by(year)
gen ky_ba_share = 100 * ky_ba / ky_pop

* Merge national on year.
merge 1:1 year using `natl', nogenerate

* KY minus national (negative = KY is behind).
gen ky_natl_gap = ky_ba_share - natl_ba_share

format ky_ba_share natl_ba_share ky_natl_gap %6.2f

di ""
di "=== Kentucky vs National BA+ share, 1940-2024 ==="
list year ky_ba_share natl_ba_share ky_natl_gap, sep(0) noobs abbreviate(20)

export delimited using "output/tables/ky_vs_national_trajectory.csv", replace

*-------------------------------------------------------------------------------
* Chart: KY vs national trajectory
*-------------------------------------------------------------------------------
gen label_ky   = ky_ba_share   if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
gen label_natl = natl_ba_share if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
format label_ky label_natl %4.1f

twoway ///
    (connected natl_ba_share year, ///
        lcolor(navy) lwidth(medthick) ///
        mcolor(navy) msymbol(O) msize(small) ///
        mlabel(label_natl) mlabposition(12) mlabgap(*2) ///
        mlabsize(vsmall) mlabcolor(black) mlabformat(%4.1f)) ///
    (connected ky_ba_share year, ///
        lcolor(cranberry) lwidth(medthick) ///
        mcolor(cranberry) msymbol(S) msize(small) ///
        mlabel(label_ky) mlabposition(6) mlabgap(*2) ///
        mlabsize(vsmall) mlabcolor(black) mlabformat(%4.1f)), ///
    xlabel(1940(10)2020 2024, angle(45)) ///
    ylabel(0(5)40, angle(0)) ///
    xtitle("") ///
    ytitle("Population-weighted BA+ share (%)") ///
    title("Kentucky vs U.S. national BA+ share, 1940-2024", size(medium)) ///
    subtitle("Population-weighted from the long county panel", size(small) color(gs6)) ///
    note("Anchor years: 1940, 1970, 1980, 1990, 2000, 2012-2024. No county-level data for 1950 or 1960.", size(vsmall) color(gs7)) ///
    legend(order(1 "United States" 2 "Kentucky") rows(1) ///
        size(small) position(6) region(lcolor(none))) ///
    graphregion(color(white)) ///
    name(ky_traj, replace)

graph export "output/figures/ky_vs_national_trajectory.png", replace width(2400)

*-------------------------------------------------------------------------------
* Part B: Top and bottom KY county gains, 1940 to 2024
*-------------------------------------------------------------------------------
use "data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta", clear
keep if state_fips == "21"
keep if year == 1940 | year == 2024
keep county_fips county year pct_baplus pop25plus

* Drop state/county name issues (caps in 1940, title in 2024)
* by dropping county here and merging back later.
drop county

reshape wide pct_baplus pop25plus, i(county_fips) j(year)
drop if missing(pct_baplus1940) | missing(pct_baplus2024)

gen gain_pp = pct_baplus2024 - pct_baplus1940

* Merge back the 2024-format county names for readability.
preserve
    use "data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta", clear
    keep if year == 2024 & state_fips == "21"
    keep county_fips county
    tempfile knames
    save `knames'
restore

merge 1:1 county_fips using `knames', keep(master match) nogenerate

format pct_baplus1940 pct_baplus2024 gain_pp %6.2f

gsort -gain_pp
di ""
di "=== Top 8 Kentucky counties by BA+ gain, 1940 to 2024 ==="
list county pct_baplus1940 pct_baplus2024 gain_pp in 1/8, sep(0) noobs abbreviate(30)

gsort gain_pp
di ""
di "=== Bottom 8 Kentucky counties by BA+ gain, 1940 to 2024 ==="
list county pct_baplus1940 pct_baplus2024 gain_pp in 1/8, sep(0) noobs abbreviate(30)

* Save the full KY gains list
preserve
    gsort -gain_pp
    keep county pct_baplus1940 pct_baplus2024 gain_pp
    export delimited using "output/tables/ky_county_gains_1940_2024.csv", replace
restore

*-------------------------------------------------------------------------------
* Part C: How many KY counties are in the national bottom 10% at each year?
*-------------------------------------------------------------------------------
use "data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta", clear
keep year county_fips state_fips pct_baplus

keep if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
drop if missing(pct_baplus)

* Within each year, compute the national 10th percentile.
bys year: egen p10_national = pctile(pct_baplus), p(10)

* Flag counties below national P10 AND that are KY.
gen ky_in_bottom10 = (pct_baplus <= p10_national) & (state_fips == "21")
gen is_ky = state_fips == "21"

* Collapse: count KY counties in bottom 10 (numerator) and total KY (denominator).
collapse (sum) ky_in_bottom10 (sum) total_ky = is_ky, by(year)

gen ky_pct_in_bottom10 = 100 * ky_in_bottom10 / total_ky
format ky_pct_in_bottom10 %5.1f

di ""
di "=== Kentucky counties in the national BA+ bottom 10% ==="
list year ky_in_bottom10 total_ky ky_pct_in_bottom10, sep(0) noobs abbreviate(20)

export delimited using "output/tables/ky_in_national_bottom10.csv", replace



