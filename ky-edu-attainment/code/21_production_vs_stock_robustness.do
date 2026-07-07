*===============================================================================
* 21_production_vs_stock_robustness.do
*
* Four-column robustness table for the production-vs-stock regression.
*
*   (1) Baseline: full sample, 1990 baseline (matches script 21)
*   (2) Excluding online-heavy counties (Adair = Lindsey Wilson, Whitley = Cumberlands)
*   (3) Producing counties only (drop 93 zero-production counties)
*   (4) Full sample with 2000 baseline instead of 1990
*
* Inputs:
*   data/cleaned/ky_production_vs_stock_summary.dta   (from script 21)
*   data/cleaned/ky_ed_county_panel_1990_2024.dta
*   data/cleaned/ipeds_ky_completions_1990_2024.dta
*
* Output: output/tables/production_vs_stock_robustness.tex
*===============================================================================

clear all
set more off
cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

*-------------------------------------------------------------------------------
* (1) Baseline
*-------------------------------------------------------------------------------
use "data/cleaned/ky_production_vs_stock_summary.dta", clear
reg ba_growth_1990_2024 cum_prod_per1k pct_baplus1990 [aw=pop25plus1990], robust
estimates store m1

*-------------------------------------------------------------------------------
* (2) Exclude Adair (21001) and Whitley (21235)
*-------------------------------------------------------------------------------
preserve
    drop if inlist(county_fips, "21001", "21235")
    reg ba_growth_1990_2024 cum_prod_per1k pct_baplus1990 [aw=pop25plus1990], robust
    estimates store m2
restore

*-------------------------------------------------------------------------------
* (3) Producing counties only
*-------------------------------------------------------------------------------
preserve
    drop if total_bachelors_produced == 0
    di "Producing counties in sample: " _N
    reg ba_growth_1990_2024 cum_prod_per1k pct_baplus1990 [aw=pop25plus1990], robust
    estimates store m3
restore

*-------------------------------------------------------------------------------
* (4) 2000 baseline
*-------------------------------------------------------------------------------
* Build cumulative production 2000-2024
use "data/cleaned/ipeds_ky_completions_1990_2024.dta", clear
keep if awlevel == 5 & year >= 2000
collapse (sum) n_awards, by(countycd year)
collapse (sum) total_prod_2000_2024 = n_awards, by(countycd)
rename countycd county_fips_num
tostring county_fips_num, gen(county_fips) format(%05.0f)
drop county_fips_num
tempfile cum_prod_2000
save `cum_prod_2000'

* Build 2000-2024 resident change
use "data/cleaned/ky_ed_county_panel_1990_2024.dta", clear
keep if inlist(year, 2000, 2024)
keep county_fips county year pop25plus pct_baplus
reshape wide pop25plus pct_baplus, i(county_fips county) j(year)

gen ba_growth_2000_2024 = pct_baplus2024 - pct_baplus2000

merge 1:1 county_fips using `cum_prod_2000', keep(master match) nogen
replace total_prod_2000_2024 = 0 if missing(total_prod_2000_2024)
gen cum_prod_per1k_2000 = 1000 * total_prod_2000_2024 / pop25plus2000

reg ba_growth_2000_2024 cum_prod_per1k_2000 pct_baplus2000 [aw=pop25plus2000], robust
estimates store m4

*-------------------------------------------------------------------------------
* Table
*-------------------------------------------------------------------------------
di ""
di "Robustness table:"
esttab m1 m2 m3 m4, b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(0 3)) ///
    mtitles("Baseline" "Excl. AD/WH" "Producing only" "2000 baseline")

esttab m1 m2 m3 m4 using "output/tables/production_vs_stock_robustness.tex", ///
    replace booktabs b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(0 3) labels("Observations" "R-squared")) ///
    mtitles("Baseline" "Excl. Adair/Whitley" "Producing only" "2000 baseline") ///
    coeflabels(cum_prod_per1k "Cum. bachelor's per 1,000 adults" ///
               cum_prod_per1k_2000 "Cum. bachelor's per 1,000 adults" ///
               pct_baplus1990 "Initial BA+ share (pp)" ///
               pct_baplus2000 "Initial BA+ share (pp)" ///
               _cons "Constant") ///
    title("Robustness: production and BA+ share growth, KY counties")

di ""
di "Saved: output/tables/production_vs_stock_robustness.tex"
