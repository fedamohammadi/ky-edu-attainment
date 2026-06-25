## ky-ed-attainment

## Project Structure

```text
ky-ed-attainment/
│
├── code/
│   ├── 01_pull_data.R
│   ├── 02_build_panel.R
│   ├── 03_state_trends.do
│   ├── 04_map_levels.R
│   ├── 05_harmonize.R
│   ├── 06_pull_decennial.R
│   ├── 07_harmonize_decennial.R
│   ├── 08_stack_panel.R
│   ├── 09_dispersion.do
│   ├── 10_county_rollup.R
│   ├── 11_maps.do
│   └── 11_variance_decomp.do
│
├── dashboard/
│   ├── main.R
│   ├── setup.R
│   ├── page_about.R
│   ├── page_methodology.R
│   ├── page_references.R
│   ├── page_results.R
│   └── page_visualizations.R
│
├── data/
│   ├── raw/
│   │   ├── acs_b15003_2012_2024_raw.rds
│   │   ├── nhgis_bgp1990_tr2010_21.csv
│   │   ├── nhgis_bgp2000_tr2010_21.csv
│   │   ├── nhgis_tr2010_tr2020_21.csv
│   │   ├── cb_2020_21_tract_500k.*
│   │   ├── cb_2020_us_county_500k.*
│   │   └── nhgis0001_csv/
│   │
│   └── cleaned/
│       ├── ky_ed_panel_2012_2024.dta
│       ├── ky_ed_panel_2012_2024.rds
│       ├── ky_ed_panel_harmonized_2012_2024.dta
│       ├── ky_ed_panel_harmonized_2012_2024.rds
│       ├── ky_ed_decennial_1990_2000.dta
│       ├── ky_ed_decennial_1990_2000.rds
│       ├── ky_ed_panel_full_1990_2024.dta
│       ├── ky_ed_panel_full_1990_2024.rds
│       ├── ky_ed_county_panel_1990_2024.dta
│       ├── ky_ed_county_panel_1990_2024.rds
│       ├── ky_county_baplus_growth.dta
│       ├── ky_tract_db.dta
│       └── ky_tract_coord.dta
│
├── docs/
│   └── codebook.md
│
├── output/
│   ├── figures/
│   │   ├── ba_dispersion_1990_2024_stata.png
│   │   ├── ba_maps_1990_2024.png
│   │   ├── btw_share_trajectory.png
│   │   ├── fig1_state_trends.png
│   │   ├── fig1_state_trends_harmonized.png
│   │   ├── map_baplus_2024.png
│   │   ├── map_somecoll_2024.png
│   │   └── vardecomp_levels.png
│   │
│   └── tables/
│       ├── county_baplus_growth.csv
│       ├── dispersion_by_year.csv
│       ├── state_trends.csv
│       ├── state_trends_harmonized.csv
│       └── vardecomp_by_year.dta
│
├── .gitignore
├── ky-ed-attainment.Rproj
└── README.md
```

