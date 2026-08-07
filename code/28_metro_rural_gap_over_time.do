*-------------------------------------------------------------------------------
* Purpose: Item 5 from Darolia's follow-up: track the metro-rural BA+ gap
*          from 1940 to 2024. Compute population-weighted BA+ share by
*          RUCC-based metro status at each anchor year, then look at
*          when the gap emerged and how it grew.
* 
* What this file does:
*   1. Load the long county panel (already has metro_status from RUCC).
*   2. For each anchor year, compute the population-weighted BA+ share
*      separately for Metro, Nonmetro-with-city, and Rural counties.
*   3. Compute the metro-rural gap (Metro minus Rural) at each year.
*   4. Show the trajectory table and save.
*   5. Plot two things:
*        - The three lines by metro status over time
*        - The metro-rural gap alone as a single line
*
* Inputs : data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta
* Outputs: output/tables/metro_rural_trajectory.csv
*          output/figures/metro_rural_shares.png
*          output/figures/metro_rural_gap.png
*-------------------------------------------------------------------------------

cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* 1. Load
*-------------------------------------------------------------------------------
use "data/cleaned/us_ed_county_panel_long_1940_2024_full_cbp.dta", clear

* Keep only what we need
keep year county_fips metro_status pop25plus ba_plus

* Drop counties with no metro status (usually AK boroughs, VA cities,
* or Connecticut counties that changed FIPS across editions).
drop if missing(metro_status)
drop if missing(ba_plus) | missing(pop25plus)

*-------------------------------------------------------------------------------
* 2. Population-weighted BA+ share by year and metro status
*-------------------------------------------------------------------------------
* We collapse to totals (sum), then divide, because that gives the true
* population-weighted share. Averaging county-level shares would over-
* weight small counties.
collapse (sum) pop25plus ba_plus, by(year metro_status)

gen ba_share = 100 * ba_plus / pop25plus

*-------------------------------------------------------------------------------
* 3. Reshape wide so each row is one year with three columns for the
*    three metro categories, then compute the metro-rural gap
*-------------------------------------------------------------------------------
* First encode metro_status as a short string for reshape
gen str10 ms = ""
replace ms = "metro"    if metro_status == "Metro"
replace ms = "nonmetro" if metro_status == "Nonmetro with city"
replace ms = "rural"    if metro_status == "Rural"

keep year ms ba_share
reshape wide ba_share, i(year) j(ms) string

* Rename for readability
rename ba_sharemetro    ba_metro
rename ba_sharenonmetro ba_nonmetro
rename ba_sharerural    ba_rural

* The headline metric: the gap between Metro and Rural, in percentage points
gen metro_rural_gap = ba_metro - ba_rural

* Format for clean output
format ba_metro ba_nonmetro ba_rural metro_rural_gap %6.2f

*-------------------------------------------------------------------------------
* 4. Show table and save
*-------------------------------------------------------------------------------
list year ba_metro ba_nonmetro ba_rural metro_rural_gap, ///
    sep(0) noobs abbreviate(20)

export delimited using "output/tables/metro_rural_trajectory.csv", replace

*-------------------------------------------------------------------------------
* 5. Chart 1: Three lines over time
*-------------------------------------------------------------------------------
* Label only decadal anchor years so ACS labels don't crowd the plot.
gen label_metro    = ba_metro    if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
gen label_nonmetro = ba_nonmetro if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
gen label_rural    = ba_rural    if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
format label_metro label_nonmetro label_rural %4.1f

twoway ///
    (connected ba_metro year, ///
        lcolor(navy) lwidth(medthick) ///
        mcolor(navy) msymbol(O) msize(small) ///
        mlabel(label_metro) mlabposition(12) mlabgap(*2) ///
        mlabsize(vsmall) mlabcolor(black) mlabformat(%4.1f)) ///
    (connected ba_nonmetro year, ///
        lcolor("192 124 30") lwidth(medthick) ///
        mcolor("192 124 30") msymbol(T) msize(small) ///
        mlabel(label_nonmetro) mlabposition(12) mlabgap(*2) ///
        mlabsize(vsmall) mlabcolor(black) mlabformat(%4.1f)) ///
    (connected ba_rural year, ///
        lcolor(cranberry) lwidth(medthick) ///
        mcolor(cranberry) msymbol(S) msize(small) ///
        mlabel(label_rural) mlabposition(6) mlabgap(*2) ///
        mlabsize(vsmall) mlabcolor(black) mlabformat(%4.1f)), ///
    xlabel(1940(10)2020 2024, angle(45)) ///
    ylabel(0(5)45, angle(0)) ///
    xtitle("") ///
    ytitle("Population-weighted BA+ share (%)") ///
    title("Metro vs rural BA+ attainment, U.S. counties, 1940-2024", size(medium)) ///
    subtitle("By RUCC metro status (nearest available edition)", size(small) color(gs6)) ///
    note("No county-level data for 1950 or 1960. 1940 and 1970 use 1974 RUCC.", size(vsmall) color(gs7)) ///
    legend(order(1 "Metro (RUCC 1-3)" 2 "Nonmetro with city (RUCC 4-7)" 3 "Rural (RUCC 8-9)") ///
        rows(1) size(small) position(6) region(lcolor(none))) ///
    graphregion(color(white)) ///
    name(metro_rural_lines, replace)

graph export "output/figures/metro_rural_shares.png", ///
    replace width(2400)

*-------------------------------------------------------------------------------
* 6. Chart 2: Metro-rural gap alone
*-------------------------------------------------------------------------------
gen label_gap = metro_rural_gap if inlist(year, 1940, 1970, 1980, 1990, 2000, 2012, 2024)
format label_gap %4.1f

twoway ///
    (connected metro_rural_gap year, ///
        lcolor(navy) lwidth(medthick) ///
        mcolor(navy) msymbol(O) msize(small) ///
        mlabel(label_gap) mlabposition(12) mlabgap(*2) ///
        mlabsize(vsmall) mlabcolor(black) mlabformat(%4.1f)), ///
    xlabel(1940(10)2020 2024, angle(45)) ///
    ylabel(0(2)20, angle(0)) ///
    xtitle("") ///
    ytitle("Metro minus Rural (percentage points)") ///
    title("The metro-rural BA+ gap, 1940-2024", size(medium)) ///
    subtitle("Metro (RUCC 1-3) BA+ share minus Rural (RUCC 8-9) BA+ share", size(small) color(gs6)) ///
    note("No county-level data for 1950 or 1960. 1940 and 1970 use 1974 RUCC.", size(vsmall) color(gs7)) ///
    graphregion(color(white)) ///
    legend(off) ///
    name(metro_rural_gap, replace)

graph export "output/figures/metro_rural_gap.png", ///
    replace width(2400)