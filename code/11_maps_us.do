*-------------------------------------------------------------------------------
* 11_maps_us.do
* Small-multiples choropleth: BA+ share, U.S. counties, 1990/2000/2012/2024
*-------------------------------------------------------------------------------

cd "C:/Users/mohammadif/Documents/ky-edu-attainment"

capture which spmap
if _rc ssc install spmap
capture which shp2dta
if _rc ssc install shp2dta

*-------------------------------------------------------------------------------
* 1. Build wide county attainment
*-------------------------------------------------------------------------------
use "data/cleaned/us_ed_county_panel_1990_2024.dta", clear
keep if inlist(year, 1990, 2000, 2012, 2024)
keep county_fips year pct_baplus
reshape wide pct_baplus, i(county_fips) j(year)

gen state_fips = substr(county_fips, 1, 2)
drop if inlist(state_fips, "02", "15", "60", "66", "69", "72", "78")
drop state_fips

rename county_fips GEOID
save "data/cleaned/us_attain_wide.dta", replace

*-------------------------------------------------------------------------------
* 2. Merge onto shapefile database AND filter shapefile to lower-48
*-------------------------------------------------------------------------------
use "data/cleaned/us_county_db", clear
capture confirm string variable GEOID
if _rc tostring GEOID, replace format(%05.0f)

* Drop AK, HI, and territories from the shapefile too, so the map isn't
* stretched to cover the Aleutians and Hawaii.
drop if inlist(STATEFP, "02", "15", "60", "66", "69", "72", "78")

merge 1:1 GEOID using "data/cleaned/us_attain_wide.dta", keep(master match)
drop _merge

*-------------------------------------------------------------------------------
* 3. Four maps
*-------------------------------------------------------------------------------
local brk 0 10 20 30 40 50 60 100
local opts clmethod(custom) clbreaks(`brk') fcolor(Blues) ///
           ocolor(white ..) osize(vvthin ..) ndfcolor(gs13) legend(off)

spmap pct_baplus1990 using "data/cleaned/us_county_coord", id(id) `opts' ///
    title("1990", size(medium)) name(m1990, replace)

spmap pct_baplus2000 using "data/cleaned/us_county_coord", id(id) `opts' ///
    title("2000", size(medium)) name(m2000, replace)

spmap pct_baplus2012 using "data/cleaned/us_county_coord", id(id) `opts' ///
    title("2012", size(medium)) name(m2012, replace)

spmap pct_baplus2024 using "data/cleaned/us_county_coord", id(id) ///
    clmethod(custom) clbreaks(`brk') fcolor(Blues) ///
    ocolor(white ..) osize(vvthin ..) ndfcolor(gs13) ///
    legend(on position(5) size(vsmall) symysize(2) symxsize(2)) ///
    legtitle("BA+ share (%)") ///
    title("2024", size(medium)) name(m2024, replace)

*-------------------------------------------------------------------------------
* 4. Combine and export (tighter layout)
*-------------------------------------------------------------------------------
graph combine m1990 m2000 m2012 m2024, ///
    cols(2) imargin(zero) ///
    title("BA+ attainment, U.S. counties", size(medium)) ///
    subtitle("Share of adults 25+ with a bachelor's degree or higher; common scale", ///
             size(small)) ///
    graphregion(color(white)) name(ba_maps_us, replace)

graph export "output/figures/us_ba_maps_1990_2024.png", replace width(3600)

