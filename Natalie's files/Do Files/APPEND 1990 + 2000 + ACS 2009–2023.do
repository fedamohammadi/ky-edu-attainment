/********************************************************************
  APPEND: 1990 + 2000 + ACS 2009–2023
  All on 2010 tract geography.

  Required common vars:
    - tract2010  (str14)
    - year       (numeric)
    - pop25plus  (count)
    - BAplus     (count)
    - pct_BAplus (share)
********************************************************************/

clear all
set more off

*------------------------------*
* PATHS (EDIT THESE)
*------------------------------*
local f1990 "/Users/nataliegross/Downloads/Cross walk Ed data/Final Output/ky_1990_2010geo.dta"
local f2000 "/Users/nataliegross/Downloads/Cross walk Ed data/Final Output/ky_2000_2010geo.dta" 
local facs  "/Users/nataliegross/Downloads/Cross walk Ed data/Final Output/acs_2009_2023_2010geo.dta" 

local out   "/Users/nataliegross/Downloads/ACS Kentucky Ed attainment 1990-2023/Output/ky_ed_1990_2023_2010geo.dta"

*------------------------------*
* Helper: standardize variables
*------------------------------*
program define _stdpanel
    * tract2010 must be string
    capture confirm string variable tract2010
    if _rc tostring tract2010, replace format(%14.0f)

    * year must be numeric
    capture confirm numeric variable year
    if _rc destring year, replace force

    * ensure pct exists
    capture confirm variable pct_BAplus
    if _rc gen pct_BAplus = BAplus / pop25plus

    keep tract2010 year pop25plus BAplus pct_BAplus
end

*------------------------------*
* STEP 1: Start with 1990
*------------------------------*
use "`f1990'", clear
_stdpanel
tempfile master
save `master', replace

*------------------------------*
* STEP 2: Append 2000
*------------------------------*
use "`f2000'", clear
_stdpanel
append using `master'
save `master', replace

*------------------------------*
* STEP 3: Append ACS 2009–2023
*------------------------------*
use "`facs'", clear
_stdpanel
append using `master'

*------------------------------*
* STEP 4: Final checks + save
*------------------------------*
order tract2010 year pop25plus BAplus pct_BAplus
sort tract2010 year

* check duplicates (should be 1 row per tract-year)
duplicates report tract2010 year

* quick coverage check
tab year

save "`out'", replace
