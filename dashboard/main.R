# main.R -------------------------------------------------------------------------
# Run THIS file to launch the dashboard.
#   In RStudio: open this file and click "Run App" (top-right of the editor).
#   Or from the console:  shiny::runApp("dashboard/main.R")
# It sources the shared setup and every page, then assembles the app. You do not
# run the other files yourself.
# --------------------------------------------------------------------------------

source("setup.R")
source("page_about.R")
source("page_methodology.R")
source("page_visualizations.R")
source("page_results.R")
source("page_references.R")

ui <- fluidPage(
  tags$head(tags$style(HTML(APP_CSS))),
  div(class = "app-title", "Kentucky Educational Attainment"),
  navlistPanel(
    widths = c(2, 10),
    well   = FALSE,
    tabPanel("About",          aboutUI()),
    tabPanel("Methodology",    methodologyUI()),
    tabPanel("Visualizations", visualizationsUI("viz")),
    tabPanel("Results",        resultsUI()),
    tabPanel("References",     referencesUI())
  )
)

server <- function(input, output, session) {
  visualizationsServer("viz")   # only the visualization page needs server logic
}

shinyApp(ui, server)




