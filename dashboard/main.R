# main.R -------------------------------------------------------------------------
# Run THIS file to launch the dashboard.
#   In RStudio: open this file and click "Run App" (top-right of the editor).
#   Or from the console: shiny::runApp("dashboard/main.R")
#
# This file sources the shared setup and every dashboard page, then assembles
# the full Shiny application.
# --------------------------------------------------------------------------------

library(here)

source(here("dashboard", "setup.R"))
source(here("dashboard", "page_about.R"))
source(here("dashboard", "page_methodology.R"))
source(here("dashboard", "maps.R"))
source(here("dashboard", "page_results.R"))
source(here("dashboard", "page_references.R"))

ui <- fluidPage(
  tags$head(
    tags$style(HTML(APP_CSS))
  ),
  
  div(
    class = "app-title",
    "Kentucky Educational Attainment"
  ),
  
  navlistPanel(
    widths = c(2, 10),
    well   = FALSE,
    
    tabPanel("About",       aboutUI()),
    tabPanel("Methodology", methodologyUI()),
    tabPanel("Maps",        mapsUI("maps")),
    tabPanel("Results",     resultsUI()),
    tabPanel("References",  referencesUI())
  ),
  
  div(
    class = "app-footer",
    "Author: Feda Mohammadi"
  )
)

server <- function(input, output, session) {
  mapsServer("maps")
}

shinyApp(ui, server)



