# page_visualizations.R ---------------------------------------------------------
# Visualizations page. Interactive county leaflet map.
# Pick a year: the map updates, and hovering a county shows its name and BA+ share.
# Built as a Shiny module (UI + server) so it stays self-contained.
# --------------------------------------------------------------------------------

visualizationsUI <- function(id) {
  ns <- NS(id)
  tagList(
    page_header("Visualizations"),
    div(class = "content",
        div(class = "map-intro", MAP_INTRO),
        selectInput(ns("year"), "Select year",
                    choices = MAP_YEARS, selected = 1990, width = "200px"),
        leafletOutput(ns("map"), height = "560px"),
        uiOutput(ns("explain")),
        div(class = "sidenote", YEAR_NOTE)
    )
  )
}

visualizationsServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Base map drawn once: light basemap, framed on Kentucky. Polygons added below
    # so changing the year keeps the user's current zoom and pan.
    output$map <- renderLeaflet({
      leaflet(options = leafletOptions(zoomControl = FALSE)) %>%
        addProviderTiles(providers$CartoDB.PositronNoLabels) %>%
        fitBounds(KY_BBOX[["xmin"]], KY_BBOX[["ymin"]],
                  KY_BBOX[["xmax"]], KY_BBOX[["ymax"]]) %>%
        htmlwidgets::onRender(
          "function(el, x) {
         var map = this;
         L.control.zoom({ position: 'topright' }).addTo(map);
       }"
        )
    })
    
    # Redraw the county polygons + legend whenever the year changes.
    observe({
      yr  <- as.numeric(input$year)
      dat <- county_map_data(yr)
      
      labs <- sprintf("<strong>%s County</strong><br/>BA+: %.1f%%",
                      dat$county, dat$pct_baplus) |>
        lapply(htmltools::HTML)
      
      leafletProxy(ns("map")) %>%
        clearShapes() %>%
        clearControls() %>%
        addPolygons(
          data        = dat,
          fillColor   = ~COUNTY_PAL(pct_baplus),
          fillOpacity = 0.9,
          color       = "white",
          weight      = 1,
          label       = labs,
          highlightOptions = highlightOptions(
            weight = 2.5, color = NAVY, fillOpacity = 0.9, bringToFront = TRUE)
        ) %>%
        addLegend(
          position = "bottomright", pal = COUNTY_PAL, values = dat$pct_baplus,
          title = "BA+ share (%)", opacity = 0.9
        )
    })
    
    output$explain <- renderUI({
      div(class = "map-explain", MAP_EXPLANATIONS[[as.character(input$year)]])
    })
  })
}




