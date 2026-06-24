/*********************************************************************
  STYLIZED_FACTS_FIGURE.DO
  Kentucky Educational Attainment — Stylized Facts (3 Panels)

  Panel A: Mean BA+ and some college/associate shares + P90-P10
           dispersion over time (2009–2023, 2010 tract boundaries)
  Panel B: β-relationship (binned scatter), initial BA+ (1990)
           vs. total pp change (1990–2023), with median reference line
  Panel C: Coefficient plot — OLS estimates from 4-model regression
           (metro, 4-year proximity, 2-year proximity)

  Author:  Natalie Gross
  Updated: June 2026

  ── REQUIRES ────────────────────────────────────────────────────────
  ssc install estout, replace     (for Panel C coefplot)
  ssc install coefplot, replace   (for Panel C)
  ────────────────────────────────────────────────────────────────────
*********************************************************************/

clear all
set more off

* ── UPDATE PATHS IF NEEDED ─────────────────────────────────────────
local root   "/Users/nataliegross/Desktop/Final Combined Data 1990_2023"
local panel  "`root'/Data:ACS_2009_2023/acs_combined_2009_2023_geoid10_clean.dta"
local final  "`root'/Final Output/ky_ed_attainment_final.dta"
local out    "`root'/Maps/stylized_facts_figure.png"


/*==================================================================
  PANEL A: Mean attainment levels + P90-P10 dispersion over time
  ─ BA+ mean (left axis, navy line)
  ─ Some college/associate mean (left axis, teal line)
  ─ BA+ P90-P10 dispersion (right axis, maroon dashed line)
  Source: ACS panel file, 2009–2023, 2010 tract boundaries
==================================================================*/
di _n "=== PANEL A: Level and dispersion over time ===" _n

use "`panel'", clear

* Basic cleaning
drop if missing(geoid10) | missing(year)
drop if missing(pop_25_over) | pop_25_over <= 0
drop if missing(bachelors_or_more) | missing(some_college_or_more)

* BA+ share
gen pct_BAplus = bachelors_or_more / pop_25_over
drop if pct_BAplus < 0 | pct_BAplus > 1

* Some college / associate only (cumulative some_college_or_more minus BA+)
* some_college_or_more is cumulative; subtract BA+ to get sub-BA share
gen pct_somecoll = (some_college_or_more - bachelors_or_more) / pop_25_over
replace pct_somecoll = 0 if pct_somecoll < 0   // rare rounding artifact

* Convert to pp
gen ba_pp       = 100 * pct_BAplus
gen sc_pp       = 100 * pct_somecoll

* Collapse to year-level
collapse (mean) ba_mean=ba_pp sc_mean=sc_pp ///
         (p10)  ba_p10=ba_pp  ///
         (p90)  ba_p90=ba_pp, by(year)

gen ba_p90p10 = ba_p90 - ba_p10

label var ba_mean   "Mean BA+ share (pp)"
label var sc_mean   "Mean some coll./assoc. share (pp)"
label var ba_p90p10 "BA+ dispersion: P90\u2212P10 (pp)"

* Check expected values
list year ba_mean sc_mean ba_p90p10
* Expected: ba_mean rising slowly from ~14 to ~15 pp
*           sc_mean roughly stable ~28-32 pp
*           ba_p90p10 rising from ~28 to ~32 pp (divergence)

twoway ///
    (line ba_mean year, sort lcolor(navy) lwidth(medthick)) ///
    (line sc_mean year, sort lcolor("0 153 153") lwidth(medthick) lpattern(shortdash)) ///
    (line ba_p90p10 year, sort yaxis(2) lcolor(maroon) lwidth(medium) lpattern(longdash)) ///
    , ///
    title("A. Attainment Levels and Inequality Over Time", size(small) color(black)) ///
    xtitle("Year", size(small)) ///
    ytitle("Mean share (pp)", size(small)) ///
    ytitle("Dispersion: P90{&minus}P10 (pp)", axis(2) size(small)) ///
    xlabel(2009(2)2023, labsize(small)) ///
    legend(order(1 "BA+ mean" 2 "Some coll./assoc. mean" 3 "BA+ P90{&minus}P10 (right axis)") ///
        pos(6) ring(1) col(3) size(small) region(lstyle(none))) ///
    scheme(s1mono) ///
    plotregion(margin(small)) ///
    graphregion(color(white)) ///
    name(panelA, replace)

graph save "`root'/Maps/panelA.gph", replace
di "Panel A saved."


/*==================================================================
  PANEL B: β-relationship — initial BA+ (1990) vs. total pp change
  ─ Binned scatter (20 equal-count bins), weighted by 1990 population
  ─ Linear fit line
  ─ Vertical dashed line at statewide median initial BA+
  ─ Total pp change (NOT annualized) — consistent with maps and report
  Source: ky_ed_attainment_final.dta (2020 tract boundaries)
==================================================================*/
di _n "=== PANEL B: β-relationship (initial level vs. total growth) ===" _n

use "`final'", clear

drop if missing(pct_BAplus1990) | missing(ba_growth)
drop if missing(pct_baplus2023)

* Variables for scatter
gen p0_pp = pct_BAplus1990          // initial BA+ share (pp)
gen g_pp  = ba_growth               // total pp change, 1990–2023

label var p0_pp "Initial BA+ share, 1990 (pp)"
label var g_pp  "Change in BA+ share (pp), 1990\u20132023"

* Statewide median initial BA+ for reference line
sum p0_pp, detail
local med = r(p50)
di "Median initial BA+ (1990): `med' pp"

* 20 equal-count bins, weighted by 1990 population
* (pop25_1990_piece not in final dataset — use unweighted bins)
xtile bin = p0_pp, n(20)

preserve
    collapse (mean) g_pp p0_pp, by(bin)

    twoway ///
        (scatter g_pp p0_pp, mcolor(navy) msymbol(O) msize(small)) ///
        (lfit g_pp p0_pp, lcolor(maroon) lwidth(medthick)) ///
        , ///
        xline(`med', lpattern(dash) lcolor(gs8) lwidth(medium)) ///
        yline(0, lpattern(solid) lcolor(gs12) lwidth(thin)) ///
        title("B. Initial BA+ Level vs. Total Growth, 1990{&ndash}2023", size(small) color(black)) ///
        xtitle("Initial BA+ share, 1990 (pp)", size(small)) ///
        ytitle("Change in BA+ share (pp)", size(small)) ///
        note("Dashed line = median initial BA+ (`=round(`med',0.1)' pp). 20 equal-count bins.", ///
             size(vsmall)) ///
        legend(off) ///
        scheme(s1mono) ///
        plotregion(margin(small)) ///
        graphregion(color(white)) ///
        name(panelB, replace)

    graph save "`root'/Maps/panelB.gph", replace
    di "Panel B saved."
restore


/*==================================================================
  PANEL C: Coefficient plot — OLS regression estimates
  Shows point estimates + 95% CI for:
    ─ metro (Models 1–4)
    ─ college4_25mi (Models 2, 4)
    ─ college2_25mi (Models 3, 4)
  Initial BA share omitted (mechanical control; large positive)
  Source: ACS_Map_data.csv + RUCC + institution distances
  Requires: estout, coefplot
==================================================================*/
di _n "=== PANEL C: Coefficient plot ===" _n

* ── Load regression dataset ────────────────────────────────────────
import delimited "`root'/Final Output/ACS_Map_data.csv", clear

replace ba_growth = pct_baplus2023 - pct_baplus2009 ///
    if missing(ba_growth) & !missing(pct_baplus2009) & !missing(pct_baplus2023)

keep if !missing(ba_growth) & !missing(pct_baplus1990)
keep if !missing(intptlat) & !missing(intptlon)

rename intptlat tract_lat
rename intptlon tract_lon
gen countyfips = substr(tr2020, 2, 2) + substr(tr2020, 5, 3)
keep tr2020 ba_growth pct_baplus1990 tract_lat tract_lon countyfips
save "`root'/temp_reg_base.dta", replace

* ── RUCC ────────────────────────────────────────────────────────────
import delimited "`root'/Metro v. Nonmetro /Ruralurbancontinuumcodes2023.csv", clear
keep if attribute == "RUCC_2023"
gen countyfips = string(fips, "%05.0f")
destring value, replace
rename value rucc
gen metro = (rucc <= 3)
keep countyfips rucc metro
save "`root'/temp_rucc.dta", replace

use "`root'/temp_reg_base.dta", clear
merge m:1 countyfips using "`root'/temp_rucc.dta", keep(master match) nogenerate

* ── College distances ───────────────────────────────────────────────
preserve
    use "`root'/Maps/institutions_4yr.dta", clear
    keep _Y _X
    rename _Y inst_lat
    rename _X inst_lon
    save "`root'/temp_inst_4yr.dta", replace
restore

preserve
    use "`root'/Maps/institutions_2yr.dta", clear
    keep _Y _X
    rename _Y inst_lat
    rename _X inst_lon
    save "`root'/temp_inst_2yr.dta", replace
restore

gen min_dist_4yr = .
gen min_dist_2yr = .

local n = _N
forval i = 1/`n' {
    local tlat = tract_lat[`i']
    local tlon = tract_lon[`i']

    preserve
        use "`root'/temp_inst_4yr.dta", clear
        gen dlat = (`tlat' - inst_lat) * 69
        gen dlon = (`tlon' - inst_lon) * 69 * cos(`tlat' * _pi / 180)
        gen dist = sqrt(dlat^2 + dlon^2)
        sum dist, meanonly
        local d4 = r(min)
    restore
    replace min_dist_4yr = `d4' if _n == `i'

    preserve
        use "`root'/temp_inst_2yr.dta", clear
        gen dlat = (`tlat' - inst_lat) * 69
        gen dlon = (`tlon' - inst_lon) * 69 * cos(`tlat' * _pi / 180)
        gen dist = sqrt(dlat^2 + dlon^2)
        sum dist, meanonly
        local d2 = r(min)
    restore
    replace min_dist_2yr = `d2' if _n == `i'

    if mod(`i', 100) == 0 di "  Processed `i' / `n' tracts..."
}

gen college4_25mi = (min_dist_4yr <= 25)
gen college2_25mi = (min_dist_2yr <= 25)

label var pct_baplus1990  "Initial BA share, 1990 (pp)"
label var metro           "Metro county (RUCC 1-3)"
label var college4_25mi   "4-Year college within 25 mi."
label var college2_25mi   "2-Year college within 25 mi."
label var ba_growth       "BA growth (pp), 1990-2023"

* ── Run 4 models ────────────────────────────────────────────────────
eststo clear
eststo m1: reg ba_growth pct_baplus1990 metro, robust
eststo m2: reg ba_growth pct_baplus1990 metro college4_25mi, robust
eststo m3: reg ba_growth pct_baplus1990 metro college2_25mi, robust
eststo m4: reg ba_growth pct_baplus1990 metro college4_25mi college2_25mi, robust

* ── Coefficient plot ────────────────────────────────────────────────
* Show metro and college proximity coefficients only
* (initial BA share omitted — large positive, mechanical control)
coefplot ///
    (m1, label("Model 1: Baseline") mcolor(navy) ciopts(lcolor(navy))) ///
    (m2, label("Model 2: + 4-Year") mcolor("0 153 153") ciopts(lcolor("0 153 153"))) ///
    (m3, label("Model 3: + 2-Year") mcolor(maroon) ciopts(lcolor(maroon))) ///
    (m4, label("Model 4: Both") mcolor("204 102 0") ciopts(lcolor("204 102 0"))) ///
    , ///
    keep(metro college4_25mi college2_25mi) ///
    xline(0, lpattern(dash) lcolor(gs8)) ///
    title("C. OLS Coefficient Estimates (95% CI)", size(small) color(black)) ///
    xtitle("Estimated effect on BA+ growth (pp)", size(small)) ///
    ylabel(, labsize(small)) ///
    mlabel format(%4.2f) mlabsize(vsmall) mlabposition(3) ///
    coeflabels(metro = "Metro county" ///
               college4_25mi = "4-Year college {&le} 25 mi." ///
               college2_25mi = "2-Year college {&le} 25 mi.") ///
    legend(pos(6) ring(1) col(4) size(small) region(lstyle(none))) ///
    scheme(s1mono) ///
    plotregion(margin(small)) ///
    graphregion(color(white)) ///
    name(panelC, replace)

graph save "`root'/Maps/panelC.gph", replace
di "Panel C saved."

* Clean up temp files
foreach f in temp_reg_base temp_rucc temp_inst_4yr temp_inst_2yr {
    capture erase "`root'/`f'.dta"
}


/*==================================================================
  COMBINE ALL THREE PANELS
==================================================================*/
di _n "=== Combining panels ===" _n

graph combine ///
    "`root'/Maps/panelA.gph" ///
    "`root'/Maps/panelB.gph" ///
    "`root'/Maps/panelC.gph" ///
    , ///
    col(3) ///
    title("Stylized Facts: Kentucky Tract-Level BA+ Attainment, 1990{&ndash}2023", ///
          size(small) color(black)) ///
    note("Sources: ACS 5-Year Estimates (2009{&ndash}2023); 1990 Decennial Census; NHGIS crosswalk." ///
         "Panel A: 2010 tract boundaries (ACS panel file). Panels B{&C}: 2020 tract boundaries.", ///
         size(vsmall)) ///
    graphregion(color(white)) ///
    xsize(14) ysize(5) ///
    name(stylized_facts, replace)

graph export "`out'", replace width(3600)
di as result _n "=== Figure saved: `out' ==="
