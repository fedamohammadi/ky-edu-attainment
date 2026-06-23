*===============================================================
* 03_state_trends.do
* Purpose: state-level trend figure (mean BA+, mean some-college,
*          and BA+ dispersion P90-P10) by year, on harmonized 2020 tracts.
* Input  : data/cleaned/ky_ed_panel_harmonized_2012_2024.dta
*===============================================================

clear all
set more off

* --- EDIT THIS: your repo folder, with forward slashes ---
cd "C:/Users/mohammadif/Documents/ky-ed-attainment"

* make sure output folders exist
capture mkdir "output"
capture mkdir "output/figures"
capture mkdir "output/tables"

* --- load the HARMONIZED panel (all years on 2020 tracts) ---
use "data/cleaned/ky_ed_panel_harmonized_2012_2024.dta", clear

* --- collapse the tract panel to one row per year ---
collapse (mean) mean_baplus   = pct_baplus      ///
                mean_somecoll = pct_somecoll    ///
         (p90)  p90_baplus    = pct_baplus      ///
         (p10)  p10_baplus    = pct_baplus,     ///
         by(year)

gen disp_baplus = p90_baplus - p10_baplus
label variable disp_baplus "BA+ dispersion (P90-P10, pp)"

* --- print the numbers and save them ---
list year mean_baplus mean_somecoll disp_baplus, clean
export delimited year mean_baplus mean_somecoll disp_baplus ///
       using "output/tables/state_trends_harmonized.csv", replace

* --- build the figure ---
twoway ///
   (line mean_baplus   year, lcolor(navy)   lwidth(medthick) lpattern(solid)) ///
   (line mean_somecoll year, lcolor(teal)   lwidth(medthick) lpattern(dot))   ///
   (line disp_baplus   year, lcolor(maroon) lwidth(medthick) lpattern(dash) yaxis(2)) ///
   , ///
   ytitle("Mean tract share (%)", axis(1)) ///
   ytitle("BA+ dispersion: P90-P10 (pp)", axis(2)) ///
   xtitle("Year") ///
   xlabel(2012(2)2024) ///
   legend(order(1 "BA+ mean" 2 "Some coll./assoc. mean" 3 "BA+ P90-P10 (right axis)") ///
          rows(1) position(6) size(small)) ///
   title("Kentucky Educational Attainment Over Time, 2012-2024") ///
   note("Unweighted mean across tracts, all years harmonized to 2020 tract boundaries.") ///
   graphregion(color(white)) plotregion(color(white))

* --- save the figure ---
graph export "output/figures/fig1_state_trends_harmonized.png", replace width(2400)
display "Done."