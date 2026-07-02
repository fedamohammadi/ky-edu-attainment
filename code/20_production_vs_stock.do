*===============================================================================
* 20_production_vs_stock.do
*
* Join the county-level IPEDS production panel to the county-level resident
* BA+ panel, and build two comparisons:
*
*   Option 1: Snapshot production rate vs. resident BA+ share
*             (bachelor's produced per 1,000 adults 25+, compared to BA+ share)
*
*   Option 3: Cumulative production intensity vs. BA+ share growth
*             (34-year cumulative production per capita regressed on
*              1990-2024 change in BA+ share)
*
* Focus: bachelor's degrees only (AWLEVEL 5). This matches the BA+ stock
* measure directly.
*
* Inputs:
*   data/cleaned/ky_ed_county_panel_1990_2024.dta       (resident stock)
*   data/cleaned/ipeds_ky_completions_1990_2024.dta     (production flow)
*
* Outputs:
*   data/cleaned/ky_production_vs_stock_annual.dta      (Option 1 panel)
*   data/cleaned/ky_production_vs_stock_summary.dta     (Option 3 cross-section)
*   output/tables/production_vs_stock_regression.tex    (Option 3 table)
*===============================================================================

clear all
set more off
cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* PART A: Prep the production side
*-------------------------------------------------------------------------------
use "data/cleaned/ipeds_ky_completions_1990_2024.dta", clear
keep if awlevel == 5

* Collapse away any countynm inconsistencies (e.g. "FAYETTE" vs "Fayette County"
* in old crosswalk entries) by re-summing on (countycd, year) only.
collapse (sum) n_awards, by(countycd year)

rename n_awards bachelors_produced
rename countycd county_fips_num
tostring county_fips_num, gen(county_fips) format(%05.0f)
drop county_fips_num

keep county_fips year bachelors_produced

tempfile prod
save `prod'

*-------------------------------------------------------------------------------
* PART B: Load resident panel, keep only needed columns
*-------------------------------------------------------------------------------
use "data/cleaned/ky_ed_county_panel_1990_2024.dta", clear
keep county_fips county year pop25plus pct_baplus ba_plus

tempfile resident
save `resident'

*-------------------------------------------------------------------------------
* PART C: Join for Option 1 (annual snapshot)
*-------------------------------------------------------------------------------
* Start from the resident panel (which has the years we have stock data for)
* and merge in production for those same years. Fill missing production with 0.
use `resident', clear
merge 1:1 county_fips year using `prod', keep(master match) nogen

replace bachelors_produced = 0 if missing(bachelors_produced)

* Production rate: bachelors per 1,000 adults 25+
gen production_rate = 1000 * bachelors_produced / pop25plus

label var bachelors_produced "Bachelor's degrees conferred by county's institutions"
label var production_rate    "Bachelor's produced per 1,000 adults 25+"
label var pct_baplus         "BA+ share of adults 25+ (%)"

save "data/cleaned/ky_production_vs_stock_annual.dta", replace

di ""
di "==============================================================="
di "OPTION 1: Snapshot production vs. resident stock, 2024"
di "==============================================================="

preserve
    keep if year == 2024
    gsort -production_rate
    di ""
    di "Top 10 KY counties by 2024 production rate:"
    list county pct_baplus production_rate bachelors_produced pop25plus in 1/10, ///
        noobs sepby(county) abbrev(20)
    di ""
    di "Bottom 10 KY counties by 2024 production rate (excluding zero-production):"
    keep if production_rate > 0
    gsort production_rate
    list county pct_baplus production_rate bachelors_produced pop25plus in 1/10, ///
        noobs sepby(county) abbrev(20)
restore

di ""
di "Correlation between production rate and BA+ share, 2024:"
preserve
    keep if year == 2024
    corr production_rate pct_baplus
restore

*-------------------------------------------------------------------------------
* PART D: Build the Option 3 cross-section
*-------------------------------------------------------------------------------
* We need: cumulative bachelor's produced 1990-2024, per capita.
* And: change in BA+ share, 1990-2024.
* And: baseline BA+ share in 1990 (as a control).

* Cumulative production per county
use `prod', clear
collapse (sum) total_bachelors_produced = bachelors_produced, by(county_fips)
tempfile cum_prod
save `cum_prod'

* Resident change 1990-2024
use `resident', clear
keep if inlist(year, 1990, 2024)
keep county_fips county year pop25plus pct_baplus
reshape wide pop25plus pct_baplus, i(county_fips county) j(year)

gen ba_growth_1990_2024 = pct_baplus2024 - pct_baplus1990

* Merge in cumulative production
merge 1:1 county_fips using `cum_prod', keep(master match) nogen
replace total_bachelors_produced = 0 if missing(total_bachelors_produced)

* Cumulative production per 1,000 adults (using 1990 population as base)
gen cum_prod_per1k = 1000 * total_bachelors_produced / pop25plus1990

label var ba_growth_1990_2024   "Change in BA+ share, 1990-2024 (pp)"
label var pct_baplus1990        "BA+ share in 1990 (%)"
label var cum_prod_per1k        "Cumulative bachelor's 1990-2024 per 1,000 adults 1990"
label var total_bachelors_produced "Total bachelor's produced 1990-2024"

save "data/cleaned/ky_production_vs_stock_summary.dta", replace

*-------------------------------------------------------------------------------
* PART E: Option 3 regression
*-------------------------------------------------------------------------------
di ""
di "==============================================================="
di "OPTION 3: Does county production predict BA+ share growth?"
di "==============================================================="

* Regression: growth on cumulative production, weighted by 1990 population
reg ba_growth_1990_2024 cum_prod_per1k [aw=pop25plus1990], robust
estimates store prod_only

* Add initial BA+ as control (this is the key comparison to the beta-conv result)
reg ba_growth_1990_2024 cum_prod_per1k pct_baplus1990 [aw=pop25plus1990], robust
estimates store prod_and_baseline

esttab prod_only prod_and_baseline, ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2) ///
    mtitles("Production only" "Production + baseline") ///
    title("Does county-level bachelor's production predict BA+ share growth?")

esttab prod_only prod_and_baseline using "output/tables/production_vs_stock_regression.tex", ///
    replace booktabs b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
    mtitles("Production only" "Production + baseline") ///
    coeflabels(cum_prod_per1k "Cumulative bachelor's per 1,000 adults (1990-2024)" ///
               pct_baplus1990 "Initial BA+ share, 1990 (pp)" ///
               _cons "Constant") ///
    title("Bachelor's production and BA+ share growth, KY counties 1990-2024")

di ""
di "Saved:"
di "  data/cleaned/ky_production_vs_stock_annual.dta"
di "  data/cleaned/ky_production_vs_stock_summary.dta"
di "  output/tables/production_vs_stock_regression.tex"
