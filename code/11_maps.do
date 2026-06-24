*-------------------------------------------------------------------------------
* 11_maps.do
* Small-multiples choropleth: BA+ share of adults 25+, Kentucky census tracts,
* at 1990, 2000, 2012, and 2024. One shared color scale across all four panels
* so they are directly comparable.
*
* PREP (one-time, done outside Stata):
*   Download cb_2020_21_tract_500k.zip from the Census GENZ2020 shp folder and
*   unzip the .shp/.shx/.dbf into data/raw/.
*
* Run from the repo root.
*-------------------------------------------------------------------------------

* Packages (installs only if missing)
capture which spmap
if _rc ssc install spmap
capture which shp2dta
if _rc ssc install shp2dta

*-------------------------------------------------------------------------------
* 1. Convert the shapefile to Stata format (database + coordinates, linked by id)
*-------------------------------------------------------------------------------
shp2dta using "data/raw/cb_2020_21_tract_500k", ///
    database("data/cleaned/ky_tract_db") ///
    coordinates("data/cleaned/ky_tract_coord") ///
    genid(id) replace

*-------------------------------------------------------------------------------
* 2. Build wide tract attainment at the four benchmark years
*-------------------------------------------------------------------------------
use "data/cleaned/ky_ed_panel_full_1990_2024.dta", clear
keep if inlist(year, 1990, 2000, 2012, 2024)
keep geoid year pct_baplus
reshape wide pct_baplus, i(geoid) j(year)   // -> pct_baplus1990 ... pct_baplus2024
rename geoid GEOID
tempfile attain
save `attain'

*-------------------------------------------------------------------------------
* 3. Merge attainment onto the shapefile database (key = GEOID, both string)
*-------------------------------------------------------------------------------
use "data/cleaned/ky_tract_db", clear
capture confirm string variable GEOID
if _rc tostring GEOID, replace format(%11.0f)   // safeguard if imported numeric
merge 1:1 GEOID using `attain', keep(master match)
drop _merge

*-------------------------------------------------------------------------------
* 4. Four maps, identical custom breaks so colors mean the same thing in each
*-------------------------------------------------------------------------------
local brk 0 10 20 30 40 50 60 100   // 7 classes; top bin catches the high tracts
local opts clmethod(custom) clbreaks(`brk') fcolor(Blues) ///
           ocolor(white ..) osize(vthin ..) ndfcolor(gs13) legend(off)

spmap pct_baplus1990 using "data/cleaned/ky_tract_coord", id(id) `opts' ///
    title("1990", size(medium)) name(m1990, replace)
spmap pct_baplus2000 using "data/cleaned/ky_tract_coord", id(id) `opts' ///
    title("2000", size(medium)) name(m2000, replace)
spmap pct_baplus2012 using "data/cleaned/ky_tract_coord", id(id) `opts' ///
    title("2012", size(medium)) name(m2012, replace)

* Last panel carries the legend (identical scale, so it serves all four)
spmap pct_baplus2024 using "data/cleaned/ky_tract_coord", id(id) ///
    clmethod(custom) clbreaks(`brk') fcolor(Blues) ///
    ocolor(white ..) osize(vthin ..) ndfcolor(gs13) ///
    legend(on position(4) size(small)) ///
    legtitle("BA+ share (%)") ///
    title("2024", size(medium)) name(m2024, replace)

*-------------------------------------------------------------------------------
* 5. Combine into a 2x2 panel and export
*-------------------------------------------------------------------------------
graph combine m1990 m2000 m2012 m2024, ///
    cols(2) imargin(small) ///
    title("BA+ attainment, Kentucky census tracts", size(medium)) ///
    subtitle("Share of adults 25+ with a bachelor's degree or higher; common scale", ///
             size(small)) ///
    graphregion(color(white)) name(ba_maps, replace)

graph export "output/figures/ba_maps_1990_2024.png", replace width(2400)

legend(on position(7) size(small))
