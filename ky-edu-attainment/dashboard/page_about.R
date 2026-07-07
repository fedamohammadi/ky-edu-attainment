# page_about.R ------------------------------------------------------------------
# About page. Static content.
# --------------------------------------------------------------------------------

aboutUI <- function() {
  tagList(
    page_header("About"),
    div(class = "content about-body",
        p("This project studies how educational attainment is distributed across Kentucky, and how that distribution has changed over time. The unit of analysis is the census tract, harmonized to 2020 boundaries. The measure is the share of adults aged 25 and over who hold a bachelor's degree or higher (BA+)."),
        
        h3("Research question"),
        p("Is the gap in college attainment between Kentucky's highest and lowest attainment places widening (divergence) or closing (convergence) over time, and where?"),
        
        h3("What we find so far"),
        p("Attainment rose almost everywhere between 1990 and 2024, but the gains were lopsided. The absolute gap between the top and bottom tracts widened, even as the lowest attainment places grew faster in proportional terms. The growth is concentrated in the Lexington, Louisville, and Northern Kentucky metro areas, while much of Appalachia lagged."),
        
        h3("Data"),
        p("Tract-level attainment is built from the U.S. Census decennial long form (1990 and 2000) and the American Community Survey (2012 to 2024), all harmonized to 2020 tract boundaries so the same geography is compared across years.")
    )
  )
}



