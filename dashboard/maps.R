# maps.R -------------------------------------------------------------------------
# Maps page. Displays an interactive county-level Leaflet map.
#
# Users can select a year, hover over counties, and view the county BA+ share.
# This page is built as a Shiny module so its UI and server logic remain
# self-contained.
# --------------------------------------------------------------------------------

mapsUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    page_header("Maps"),
    
    div(
      class = "content",
      
      div(
        class = "map-intro",
        MAP_INTRO
      ),
      
      selectInput(
        inputId = ns("year"),
        label   = "Select year",
        choices = MAP_YEARS,
        selected = 1990,
        width   = "200px"
      ),
      
      leafletOutput(
        outputId = ns("map"),
        height   = "560px"
      ),
      
      uiOutput(ns("explain")),
      
      div(
        class = "sidenote",
        YEAR_NOTE
      )
    )
  )
}

mapsServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Draw the base map once so changing the year preserves the user's zoom
    # and map position.
    output$map <- renderLeaflet({
      leaflet(
        options = leafletOptions(zoomControl = FALSE)
      ) %>%
        addProviderTiles(
          providers$CartoDB.PositronNoLabels
        ) %>%
        fitBounds(
          KY_BBOX[["xmin"]],
          KY_BBOX[["ymin"]],
          KY_BBOX[["xmax"]],
          KY_BBOX[["ymax"]]
        ) %>%
        htmlwidgets::onRender(
          "
          function(el, x) {
            var map = this;
            L.control.zoom({
              position: 'topright'
            }).addTo(map);
          }
          "
        )
    })
    
    # Update county polygons and the legend whenever the selected year changes.
    observe({
      yr  <- as.numeric(input$year)
      dat <- county_map_data(yr)
      
      labs <- sprintf(
        "<strong>%s County</strong><br/>BA+: %.1f%%",
        dat$county,
        dat$pct_baplus
      ) |>
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
            weight       = 2.5,
            color        = NAVY,
            fillOpacity  = 0.9,
            bringToFront = TRUE
          )
        ) %>%
        addLegend(
          position = "bottomright",
          pal      = COUNTY_PAL,
          values   = dat$pct_baplus,
          title    = "BA+ share (%)",
          opacity  = 0.9
        )
    })
    
    output$explain <- renderUI({
      div(
        class = "map-explain",
        MAP_EXPLANATIONS[[as.character(input$year)]]
      )
    })
  })
}





