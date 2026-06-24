/*********************************************************************
  KY_ED_ATTAINMENT_CLEAN.DO
  Kentucky Educational Attainment — Complete Data Construction
  Census Tract Level (2020 Vintage Boundaries), 1990–2023

  Project:  Educational Attainment in Kentucky
  Author:   Natalie Gross
  Updated:  June 2026 (Module 5 bins revised to empirical percentiles)

  ── OVERVIEW ────────────────────────────────────────────────────────
  Constructs tract-level growth in educational attainment across
  Kentucky from 1990 to 2023. Unit of analysis: census tract
  harmonized to 2020 vintage boundaries (N = 1,306).

  Two attainment growth measures (mapped):
    somecoll_growth     — Some college / associate only (pp), 1990–2023
                          (conservative; see MODULE 4b for corrected version)
    ba_growth           — Bachelor's degree or more (pp), 1990–2023

  Exception: 34 Jefferson County (FIPS 21111) tracts created by
  2020 boundary splits use 2009 as their earliest baseline.
  Growth for these tracts is 2023 − 2009 (14 years), not 33 years.

  ── DATA SOURCES ────────────────────────────────────────────────────
  (1) 1990 Decennial Census – Social Explorer Table SE_T117
        File: c_1990_collapsed_to_tract.dta       (Final Output/)
        Variables: SE_T117_001 (pop 25+), SE_T117_003 (HS+, cumulative),
                   SE_T117_004 (some college+, cumulative),
                   SE_T117_005 (BA+, cumulative)
        N = 997 rows; collapses to 895 unique NHGIS keys

  (2) 2023 ACS 5-Year Estimates – Social Explorer Table SE_A12002
        File: ACS2023_5yr_R50125644_clean.dta      (2023/)
        Variables: _001 (total 25+), _003 (HS grad), _004 (some coll),
                   _005 (associate), _006 (BA), _007 (master's),
                   _008 (professional/doctoral)
        N = 1,306; 6 tracts with missing (zero population)

  (3) 2009 ACS 5-Year Estimates – Combined ACS panel file
        File: acs_combined_2009_2023_geoid10_clean.dta  (Data:ACS_2009_2023/)
        Variables: pop_25_over, hs_or_more, some_college_or_more,
                   bachelors_or_more (cumulative counts; 2010 boundaries)
        Used only for year == 2009; ~590 tract matches

  (4) NHGIS Tract-to-Tract Crosswalk (1990 → 2020 boundaries)
        File: cw_tr1990_to_tr2020_key11.dta        (Final Output/)
        Key variables: tr1990_11 (NHGIS 11-digit), tr2020 (GISJOIN),
                       wt_90_20 (population weight)
        N = 14,752 (one row per 1990 × 2020 tract pair)

  (5) ACS Map Base File
        File: ACS_Map_data.csv                     (Final Output/)
        Contains tr2020, id (shapefile key), county FIPS,
        pct_baplus2023 (pre-built BA endpoint used as-is)
        N = 1,306; 32 variables

  (6) Kentucky Shapefiles (Stata coordinate file)
        File: ky_tracts_coord.dta                  (Shape files/)

  (7) College Institution Locations
        Files: Maps/institutions_4yr.dta, Maps/institutions_2yr.dta

  ── INTERMEDIATE FILES SAVED ────────────────────────────────────────
    Final Output/temp_1990_for_crosswalk.dta    — 895 NHGIS-keyed counts
    Final Output/temp_1990_ed_on_tr2020.dta     — 1990 shares on 2020 geo
    Final Output/temp_2023_somecoll_hs.dta      — 2023 somecoll & hs shares
    Final Output/temp_2009_ed.dta               — 2009 shares, Jefferson Co.
    Final Output/ky_ed_attainment_final.dta     — FINAL MERGED DATASET

  ── KEY METHODOLOGICAL CAVEATS ──────────────────────────────────────
  somecoll BASELINE MISMATCH: SE_T117_004 (1990) is cumulative ("some
  college OR MORE", includes BA/grad). The 2023 endpoint counts only
  some college no degree + associate. This makes raw somecoll_growth
  conservative. MODULE 4b constructs somecoll_growth_clean using the
  corrected 1990 baseline: SE_T117_004 − SE_T117_005.

  NHGIS KEY FORMAT: tr1990_11 = state(2)+"0"+county(3)+"0"+tract[1-4]
  e.g. FIPS 21001970100 → NHGIS 21000109701

  ── UPDATE THIS BEFORE RUNNING ──────────────────────────────────────
  local root   "/path/to/Final Combined Data 1990_2023"
  ────────────────────────────────────────────────────────────────────
*********************************************************************/

clear all
set more off

* ── PATH SETUP ─────────────────────────────────────────────────────
local root   "/Users/nataliegross/Desktop/Final Combined Data 1990_2023"
local output "`root'/Final Output"
local shapes "`root'/Shape files"
local maps   "`root'/Maps"


/*====================================================================
  MODULE 1: CROSSWALK 1990 DATA TO 2020 TRACT BOUNDARIES
  ─ Build NHGIS key from FIPS geoid10
  ─ Collapse sub-tract splits (sum counts)
  ─ Apply crosswalk population weights
  ─ Compute 1990 attainment shares on 2020 geography
====================================================================*/
di _n "=== MODULE 1: Crosswalking 1990 data to 2020 tract boundaries ===" _n

* Step 1a: Convert geoid10 → NHGIS tr1990_11; collapse sub-tract splits
use "`output'/c_1990_collapsed_to_tract.dta", clear
* geoid10 format: state(2) + county(3) + tract(6)
* tr1990_11 format: state(2) + "0" + county(3) + "0" + tract[1-4]
gen state     = substr(geoid10, 1, 2)
gen county    = substr(geoid10, 3, 3)
gen tract6    = substr(geoid10, 6, 6)
gen tr1990_11 = state + "0" + county + "0" + substr(tract6, 1, 4)
drop state county tract6

* Sub-tract splits (e.g., 070301/070304/070397/070398 → key "0703")
* must be summed before merging onto the crosswalk
collapse (sum) SE_T117_001 SE_T117_004 SE_T117_005, ///
    by(tr1990_11)

rename SE_T117_001 pop25_1990
rename SE_T117_004 somecoll_1990_cnt   // Some college or more (cumulative)
rename SE_T117_005 ba_1990_cnt         // BA or more (cumulative)

save "`output'/temp_1990_for_crosswalk.dta", replace
* Expected: 895 observations after collapse

* Step 1b: Apply NHGIS crosswalk weights
use "`output'/cw_tr1990_to_tr2020_key11.dta", clear
merge m:1 tr1990_11 using "`output'/temp_1990_for_crosswalk.dta", ///
    keep(master match) nogenerate
* ~72 unmatched master rows = crosswalk entries for uninhabited/water tracts
* with no matching education data; contribute zero to sums (expected)

foreach v in pop25_1990 somecoll_1990_cnt ba_1990_cnt {
    gen `v'_piece = `v' * wt_90_20
}

* Aggregate weighted pieces to 2020 tract level
collapse (sum) pop25_1990_piece ///
               somecoll_1990_cnt_piece ba_1990_cnt_piece, by(tr2020)

* Compute percentage shares
gen pct_somecoll1990 = somecoll_1990_cnt_piece / pop25_1990_piece * 100 ///
    if pop25_1990_piece > 0
gen pct_BAplus1990   = ba_1990_cnt_piece       / pop25_1990_piece * 100 ///
    if pop25_1990_piece > 0

label var pct_somecoll1990 "% some college or more, 1990 (2020 tract geo; cumulative)"
label var pct_BAplus1990   "% BA or more, 1990 (2020 tract geo)"

keep tr2020 pct_somecoll1990 pct_BAplus1990
save "`output'/temp_1990_ed_on_tr2020.dta", replace

sum pct_somecoll1990 pct_BAplus1990
* Expected means: some college ~32.9%, BA ~13.8%


/*====================================================================
  MODULE 2: 2023 ACS SOME COLLEGE SHARE
  ─ SE_A12002 uses mutually exclusive categories
  ─ somecoll2023 = _004 (some coll, no degree) + _005 (associate)
  ─ BA endpoint used directly from ACS_Map_data.csv (pre-built)
====================================================================*/
di _n "=== MODULE 2: Building 2023 ACS somecoll measure ===" _n

use "`root'/2023/ACS2023_5yr_R50125644_clean.dta", clear

* Some college / associate only: excludes BA (_006), master's (_007),
* professional/doctoral (_008). These are EXCLUDED because the 2023
* endpoint must be comparable with the corrected 1990 baseline (see 4b).
gen pct_somecoll2023 = (se_a12002_004 + se_a12002_005) ///
                       / se_a12002_001 * 100 if se_a12002_001 > 0

sum pct_somecoll2023
* Expected mean: some college ~43.4%

keep GEOID pct_somecoll2023
rename GEOID geoid11
save "`output'/temp_2023_somecoll.dta", replace


/*====================================================================
  MODULE 3: 2009 ACS MEASURES FOR JEFFERSON COUNTY TRACTS
  ─ 34 Jefferson Co. tracts are 2020-vintage splits (no 1990 crosswalk)
  ─ 2009 ACS 5-year used as earliest available baseline
  ─ Growth for these tracts = 2023 − 2009 (14 years, not 33)
====================================================================*/
di _n "=== MODULE 3: Building 2009 ACS measures for Jefferson Co. ===" _n

use "`root'/Data:ACS_2009_2023/acs_combined_2009_2023_geoid10_clean.dta", clear
keep if year == 2009

gen pct_somecoll2009 = some_college_or_more / pop_25_over * 100 if pop_25_over > 0
gen pct_BAplus2009   = bachelors_or_more    / pop_25_over * 100 if pop_25_over > 0
* Note: some_college_or_more is cumulative (includes BA/grad), consistent
* with SE_T117_004. Jefferson Co. somecoll_growth carries the same
* conservative bias as the rest of the state.

rename geoid10 geoid11
keep geoid11 pct_somecoll2009 pct_BAplus2009
save "`output'/temp_2009_ed.dta", replace


/*====================================================================
  MODULE 4: MERGE ALL SOURCES AND COMPUTE GROWTH VARIABLES
  Base: ACS_Map_data.csv (1,306 obs)
  Merge 1: 1990 crosswalked shares (key: tr2020)
  Merge 2: 2023 somecoll and hs shares (key: geoid11)
  Merge 3: 2009 Jefferson Co. baseline (key: geoid11)
====================================================================*/
di _n "=== MODULE 4: Merging all sources and computing growth ===" _n

import delimited "`output'/ACS_Map_data.csv", clear

* Build geoid11 (standard FIPS) from GISJOIN tr2020
* tr2020 format: G2100010970100
*   pos 2-3 = state, pos 5-7 = county, pos 9-14 = tract
gen geoid11 = substr(tr2020, 2, 2) + substr(tr2020, 5, 3) + substr(tr2020, 9, 6)

* Drop pre-existing ba_growth (recomputed below for consistency)
drop ba_growth

* Merge 1: 1990 crosswalked shares
merge m:1 tr2020 using "`output'/temp_1990_ed_on_tr2020.dta", ///
    keepusing(pct_somecoll1990 pct_BAplus1990) ///
    keep(master match) nogenerate

* Merge 2: 2023 some college share
merge m:1 geoid11 using "`output'/temp_2023_somecoll.dta", ///
    keepusing(pct_somecoll2023) ///
    keep(master match) nogenerate

* Merge 3: 2009 panel for Jefferson Co. imputation
* Only ~590 matches expected (2009 file uses 2010 boundaries;
* Jefferson Co. 2020 splits not in 2010 file get values from
* pct_BAplus2009/pct_somecoll2009 already present
* in ACS_Map_data.csv from an earlier project phase)
merge m:1 geoid11 using "`output'/temp_2009_ed.dta", ///
    keepusing(pct_somecoll2009 pct_BAplus2009) ///
    keep(master match) nogenerate

* Compute growth variables (2023 − 1990 for most tracts)
gen ba_growth       = pct_baplus2023   - pct_BAplus1990
gen somecoll_growth = pct_somecoll2023 - pct_somecoll1990

label var ba_growth       "Change in BA+ attainment (pp), 1990–2023"
label var somecoll_growth "Change in some coll/assoc attainment (pp), 1990–2023 (conservative)"

* Jefferson County imputation: replace missing values using 2009 baseline
* Condition: missing (no 1990 crosswalk) + county FIPS 111 (Jefferson)
replace ba_growth = pct_baplus2023 - pct_baplus2009 ///
    if missing(ba_growth) & !missing(pct_baplus2009) & countyfp == 111
replace somecoll_growth = pct_somecoll2023 - pct_somecoll2009 ///
    if missing(somecoll_growth) & !missing(pct_somecoll2009) & countyfp == 111

* Diagnostics
count if missing(ba_growth)        // expect 6 (water/uninhabited tracts)
count if missing(somecoll_growth)  // expect 6
sum ba_growth somecoll_growth
* Expected means: ba ~1 pp, somecoll ~11 pp

save "`output'/ky_ed_attainment_final.dta", replace
di "MODULE 4 complete: final dataset saved."


/*====================================================================
  MODULE 4b: CORRECTED SOME COLLEGE VARIABLE
  pct_somecoll_only1990 = SE_T117_004 − SE_T117_005
    = (some college or more) − (BA or more)
    = some college no degree + associate only
  This gives apples-to-apples comparison with pct_somecoll2023.
  Result: somecoll_growth_clean (only 4 of 1,300 tracts show decline)
====================================================================*/
di _n "=== MODULE 4b: Adding corrected some college variable ===" _n

use "`output'/ky_ed_attainment_final.dta", clear

gen pct_somecoll_only1990 = pct_somecoll1990 - pct_BAplus1990
label var pct_somecoll_only1990 ///
    "% some coll/assoc only, 1990 (SE_T117_004 minus SE_T117_005)"

gen somecoll_growth_clean = pct_somecoll2023 - pct_somecoll_only1990
label var somecoll_growth_clean ///
    "Change in some coll/assoc only (pp), 1990–2023 (corrected baseline)"

sum somecoll_growth_clean
* Expected mean ~11 pp; range −42 to +56; only 4 negative values

save "`output'/ky_ed_attainment_final.dta", replace
di "MODULE 4b complete: somecoll_growth_clean added."


/*====================================================================
  MODULE 5: MAP — BA+ GROWTH, 1990–2023 (DIVERGING)
  Bins derived from empirical percentile distribution of ba_growth:
    p5  ≈ −10 pp  p25 ≈ −2 pp  median ≈ +1 pp  p75 ≈ +5 pp
    p90 ≈ +9 pp   p99 ≈ +20 pp

  Class scheme (confirmed tract counts, N = 1,306):
    1 = < −10 pp          81 tracts  ( 6%)  dark red
    2 = −10 to −2 pp     292 tracts  (22%)  light red/orange
    3 = −2 to +2 pp      364 tracts  (28%)  warm gray (flat)
    4 = +2 to +9 pp      429 tracts  (33%)  light blue
    5 = +9 to +20 pp     120 tracts  ( 9%)  medium blue
    6 = > +20 pp          14 tracts  ( 1%)  dark blue
  999 = missing            6 tracts         white

  Gray class uses warm gray (210 210 205) to distinguish from
  the white no-data tracts around Jefferson County.
====================================================================*/
di _n "=== MODULE 5: Map — BA+ growth (percentile bins, warm gray) ===" _n

use "`output'/ky_ed_attainment_final.dta", clear

* Confirm distribution before classifying
sum ba_growth, detail

gen _class = .
replace _class = 999 if missing(ba_growth)
replace _class = 1   if ba_growth <  -10
replace _class = 2   if ba_growth >= -10 & ba_growth <  -2
replace _class = 3   if ba_growth >=  -2 & ba_growth <   2
replace _class = 4   if ba_growth >=   2 & ba_growth <   9
replace _class = 5   if ba_growth >=   9 & ba_growth <  20
replace _class = 6   if ba_growth >=  20 & !missing(ba_growth)

* Verify counts before mapping
tab _class, missing
* Expected: 1→81, 2→292, 3→364, 4→429, 5→120, 6→14, 999→6

keep id _class
save "`output'/class_for_map.dta", replace

use "`shapes'/ky_tracts_coord.dta", clear
rename _ID id
merge m:1 id using "`output'/class_for_map.dta"
drop if _merge == 2
drop _merge

gen inst_type = .
preserve
    use "`maps'/institutions_4yr.dta", clear
    keep _Y _X
    gen inst_type = 1
    tempfile inst4
    save `inst4'
restore
append using `inst4'

preserve
    use "`maps'/institutions_2yr.dta", clear
    keep _Y _X
    gen inst_type = 2
    tempfile inst2
    save `inst2'
restore
append using `inst2'

gen byte is_inst = !missing(inst_type)

twoway ///
  (area _Y _X if _class==999 & !missing(_class), nodropbase cmissing(n) ///
    fc("white") fi(100) lc("black") lw("thin")) ///
  (area _Y _X if _class==1 & !missing(_class), nodropbase cmissing(n) ///
    fc("165 15 21") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==2 & !missing(_class), nodropbase cmissing(n) ///
    fc("239 138 98") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==3 & !missing(_class), nodropbase cmissing(n) ///
    fc("210 210 205") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==4 & !missing(_class), nodropbase cmissing(n) ///
    fc("144 187 225") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==5 & !missing(_class), nodropbase cmissing(n) ///
    fc("52 111 163") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==6 & !missing(_class), nodropbase cmissing(n) ///
    fc("0 54 102") fi(100) lc("gs12") lw("vvthin")) ///
  (scatter _Y _X if is_inst & inst_type==1, ///
    msymbol(O) msize(medlarge) mcolor("255 100 0") mlcolor("white") mlwidth(thin)) ///
  (scatter _Y _X if is_inst & inst_type==2, ///
    msymbol(T) msize(medlarge) mcolor("204 153 0") mlcolor("white") mlwidth(thin)) ///
  , ///
  ysize(4) xsize(11.47846170445704) aspect(.3484787511593838) ///
  yscale(r(36.47055126 39.17423874) off) xscale(r(-89.64726714999999 -81.88872385000001) off) ///
  ylabel(36.47055126 39.17423874) xlabel(-89.64726714999999 -81.88872385000001) ///
  ytitle("") xtitle("") ///
  legend(order(2 3 4 5 6 7 1 8 9) ///
    lab(2 `"< −10 pp"') ///
    lab(3 `"−10 to −2 pp"') ///
    lab(4 `"−2 to +2 pp (flat)"') ///
    lab(5 `"+2 to +9 pp"') ///
    lab(6 `"+9 to +20 pp"') ///
    lab(7 `"> +20 pp"') ///
    lab(1 `"No data"') ///
    lab(8 `"4-Year College"') ///
    lab(9 `"2-Year College"') ///
    symy(*1.2) symx(*0.5) keygap(*0.50) col(3) rowgap(*0.5) size(*0.75) ///
    region(lstyle(none) fcolor(none)) ring(1) position(6)) ///
  plotregion(margin(zero) style(none)) ///
  graphregion(margin(zero) style(none) color(white)) ///
  scheme(s1mono) ///
  title("Change in Bachelor's Degree Attainment (pp), 1990–2023", size(medsmall)) ///
  note("Bins based on empirical percentile distribution (p5/p25/p75/p90/p99)." ///
       "Gray = roughly flat (−2 to +2 pp); red = decline; blue = growth." ///
       "Note: 34 Jefferson County tracts use 2009–2023 growth.", ///
       size(vsmall)) ///
  name(map_ba_growth, replace)

graph export "`maps'/map_ba_growth_1990_2023.png", replace width(3000)
di "Map saved: `maps'/map_ba_growth_1990_2023.png"


/*====================================================================
  MODULE 6: MAP — SOME COLLEGE / ASSOCIATE GROWTH, 1990–2023
  Uses somecoll_growth_clean (corrected apples-to-apples baseline)
  Only 4 tracts experienced decline with this definition
  Bins: <0, 0–15, 15–22, 22–28, 28–35, >35
====================================================================*/
di _n "=== MODULE 6: Map — some college/associate growth ===" _n

use "`output'/ky_ed_attainment_final.dta", clear

gen _class = .
replace _class = 999 if missing(somecoll_growth_clean)
replace _class = 1   if somecoll_growth_clean <   0
replace _class = 2   if somecoll_growth_clean >=  0  & somecoll_growth_clean < 15
replace _class = 3   if somecoll_growth_clean >= 15  & somecoll_growth_clean < 22
replace _class = 4   if somecoll_growth_clean >= 22  & somecoll_growth_clean < 28
replace _class = 5   if somecoll_growth_clean >= 28  & somecoll_growth_clean < 35
replace _class = 6   if somecoll_growth_clean >= 35  & !missing(somecoll_growth_clean)
tab _class, missing

keep id _class
save "`output'/class_for_map.dta", replace

use "`shapes'/ky_tracts_coord.dta", clear
rename _ID id
merge m:1 id using "`output'/class_for_map.dta"
drop if _merge == 2
drop _merge

gen inst_type = .
preserve
    use "`maps'/institutions_4yr.dta", clear
    keep _Y _X
    gen inst_type = 1
    tempfile inst4
    save `inst4'
restore
append using `inst4'

preserve
    use "`maps'/institutions_2yr.dta", clear
    keep _Y _X
    gen inst_type = 2
    tempfile inst2
    save `inst2'
restore
append using `inst2'

gen byte is_inst = !missing(inst_type)

twoway ///
  (area _Y _X if _class==999 & !missing(_class), nodropbase cmissing(n) ///
    fc("white") fi(100) lc("black") lw("thin")) ///
  (area _Y _X if _class==1 & !missing(_class), nodropbase cmissing(n) ///
    fc("165 15 21") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==2 & !missing(_class), nodropbase cmissing(n) ///
    fc("204 231 255") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==3 & !missing(_class), nodropbase cmissing(n) ///
    fc("144 187 225") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==4 & !missing(_class), nodropbase cmissing(n) ///
    fc("93 147 194") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==5 & !missing(_class), nodropbase cmissing(n) ///
    fc("21 81 133") fi(100) lc("gs12") lw("vvthin")) ///
  (area _Y _X if _class==6 & !missing(_class), nodropbase cmissing(n) ///
    fc("0 54 102") fi(100) lc("gs12") lw("vvthin")) ///
  (scatter _Y _X if is_inst & inst_type==1, ///
    msymbol(O) msize(medlarge) mcolor("255 100 0") mlcolor("white") mlwidth(thin)) ///
  (scatter _Y _X if is_inst & inst_type==2, ///
    msymbol(T) msize(medlarge) mcolor("204 153 0") mlcolor("white") mlwidth(thin)) ///
  , ///
  ysize(4) xsize(11.47846170445704) aspect(.3484787511593838) ///
  yscale(r(36.47055126 39.17423874) off) xscale(r(-89.64726714999999 -81.88872385000001) off) ///
  ylabel(36.47055126 39.17423874) xlabel(-89.64726714999999 -81.88872385000001) ///
  ytitle("") xtitle("") ///
  legend(order(2 3 4 5 6 7 1 8 9) ///
    lab(2 `"< 0 pp (decline)"')  lab(3 `"0 to +15 pp"') ///
    lab(4 `"+15 to +22 pp"') lab(5 `"+22 to +28 pp"') ///
    lab(6 `"+28 to +35 pp"') lab(7 `"> +35 pp"') ///
    lab(1 `"No data"') ///
    lab(8 `"4-Year College"') lab(9 `"2-Year College"') ///
    symy(*1.2) symx(*0.5) keygap(*0.50) col(3) rowgap(*0.5) size(*0.75) ///
    region(lstyle(none) fcolor(none)) ring(1) position(6)) ///
  plotregion(margin(zero) style(none)) ///
  graphregion(margin(zero) style(none) color(white)) ///
  scheme(s1mono) ///
  title("Change in Some College / Associate Degree Attainment (pp), 1990–2023", size(medsmall)) ///
  note("2023: SE_A12002_004 + _005. 1990: SE_T117_004 minus SE_T117_005 (some college/associate only)." ///
       "Note: 34 Jefferson County tracts use 2009–2023 growth. Only 4 tracts experienced decline.", ///
       size(vsmall)) ///
  name(map_sc_growth, replace)

graph export "`maps'/map_somecoll_assoc_growth_1990_2023.png", replace width(3000)
di "Map saved: `maps'/map_somecoll_assoc_growth_1990_2023.png"


di as result _n "=== All modules complete ===" _n
di as result "Final dataset: `output'/ky_ed_attainment_final.dta"
di as result "Maps: `maps'/"
