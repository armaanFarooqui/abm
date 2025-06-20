extensions [gis csv] ;; Import GIS and CSV extensions

__includes ["tick-bite-submodel.nls"] ;; Include external file with submodel logic

;; Define agent breeds for residents and tourists by age group
breed [children child]
breed [students student]
breed [adults adult]
breed [seniors senior]
breed [tourists-children tourist-child]
breed [tourists-adults tourist-adult]
breed [tourists-seniors tourist-senior]

;; Agent variables (both residents and tourists)
turtles-own [
  activity                ;; Current activity type
  risk-factor             ;; Base bite risk multiplier
  bite-stat               ;; Bite status (bitten or not)
  protection-level        ;; Level of protection against bites
  exposure-level          ;; Exposure to tick habitat
  awareness               ;; Awareness of tick risk
  age-group               ;; String label for age group
  original-color          ;; Stored to reset color
  arrival-tick            ;; Timestep when tourist arrived
]

patches-own [
  landuse                 ;; Type of land use
  agent-count             ;; Count of agents on patch
  patch-risk              ;; Risk level of patch
  tick-density            ;; Tick population density
  patch-bite-count        ;; Bites occurring on this patch

]

;; Global variables used for datasets, tracking, and output
globals [
  landuse-dataset shape-dataset
  precipitation temperature
  output-file bite-count new-bites
  weather-list

  ;; Total cumulative bite counters
  total-bites-children total-bites-adults total-bites-seniors
  total-bites-tourists-children total-bites-tourists-adults total-bites-tourists-seniors
  total-residents-bites total-tourists-bites
  total-children-population-bites total-adults-population-bites total-seniors-population-bites

  ;; New (this tick) bite counters
  new-bites-children new-bites-adults new-bites-seniors
  new-bites-tourists-children new-bites-tourists-adults new-bites-tourists-seniors
  new-residents-bites new-tourists-bites
  new-children-population-bites new-adults-population-bites new-seniors-population-bites

  ;; History of bite counts
  bite-count-history new-count-history
  total-residents-history total-tourists-history
  new-residents-history new-tourists-history
  total-children-population-history total-adults-population-history total-seniors-population-history
  new-children-population-history new-adults-population-history new-seniors-population-history

  ;; group totals
  total-children-group-history total-adults-group-history total-seniors-group-history total-tourists-children-group-history total-tourists-adults-group-history total-tourists-seniors-group-history
  new-children-group-history new-adults-group-history new-seniors-group-history new-tourists-children-group-history new-tourists-adults-group-history new-tourists-seniors-group-history
]

;; Convert ticks to month (1–12)
to-report tick-to-month
  let day ticks mod 365
  ifelse day < 31 [report 1]
  [ifelse day < 59 [report 2]
  [ifelse day < 90 [report 3]
  [ifelse day < 120 [report 4]
  [ifelse day < 151 [report 5]
  [ifelse day < 181 [report 6]
  [ifelse day < 212 [report 7]
  [ifelse day < 243 [report 8]
  [ifelse day < 273 [report 9]
  [ifelse day < 304 [report 10]
  [ifelse day < 334 [report 11]
                      [report 12]]]]]]]]]]]
end

;; Setup procedure: initializes everything
to setup
  clear-all
  reset-ticks
  file-close-all

  ;; Load weather data
  set weather-list load-weather-data "data/ede_precipitation.csv"

  ;; Setup spatial and agent components
  setup-environment
  setup-agents

  ;; Initialize bite counters
  set bite-count 0
  set total-bites-children 0
  set total-bites-adults 0
  set total-bites-seniors 0
  set total-bites-tourists-children 0
  set total-bites-tourists-adults 0
  set total-bites-tourists-seniors 0

  set new-bites-children 0
  set new-bites-adults 0
  set new-bites-seniors 0
  set new-bites-tourists-children 0
  set new-bites-tourists-adults 0
  set new-bites-tourists-seniors 0

  ;; Initialize histories for plotting/analysis
  set bite-count-history []
  set new-count-history []
  set total-residents-history []
  set total-tourists-history []
  set new-residents-history []
  set new-tourists-history []

  set total-children-population-history []
  set total-adults-population-history []
  set total-seniors-population-history []
  set new-children-population-history []
  set new-adults-population-history []
  set new-seniors-population-history []

  set total-children-group-history []
  set total-adults-group-history []
  set total-seniors-group-history []
  set total-tourists-children-group-history []
  set total-tourists-adults-group-history []
  set total-tourists-seniors-group-history []

  set new-children-group-history []
  set new-adults-group-history []
  set new-seniors-group-history []
  set new-tourists-children-group-history []
  set new-tourists-adults-group-history []
  set new-tourists-seniors-group-history []

  ;; Draw the map index
  draw-legend

  ;; Prepare CSV output file header
  file-open "data/outputs/csv/agent-output.csv"
  file-print "tick,agent-type,activity,bite-stat,patch-landuse"
  file-close
end

;; Load weather data from CSV
to-report load-weather-data [filename]
  file-open filename
  let values []
  while [not file-at-end?] [
    let line csv:from-row file-read-line
    if length line >= 2 [
      set values lput line values
    ]
  ]
  file-close
  report values
end

;; Load GIS landuse raster and shape data, assign patch properties
to setup-environment
  set landuse-dataset gis:load-dataset "data/Ede/ede_ascii.asc"
  gis:set-world-envelope (gis:envelope-of landuse-dataset)
  gis:apply-raster landuse-dataset landuse

  ask patches [
    ;; Assign tick density and risk based on landuse code
    if landuse = 20 [set pcolor red set tick-density 0.66 set patch-risk 0.32]; residential
    if landuse = 60 [set pcolor green set tick-density 0.15 set patch-risk 0.50]; forest
    if landuse = 61 [set pcolor brown set tick-density 0.10 set patch-risk 0.04]; dunes/ sand
    if landuse = 62 [set pcolor grey set tick-density 0.08 set patch-risk 0.01]; other (offices)
  ]

  ;; Load municipality border
  set shape-dataset gis:load-dataset "data/Ede/Ede_shape.shp"
  gis:set-drawing-color white
  gis:draw shape-dataset 1
  draw-legend

  ;; Initialize bite counter on each patch
  ask patches [ set patch-bite-count 0 ]

end

;; Create the agents
to setup-agents

  ;; Create residents (children)
  create-children initial-number-children [
    move-to one-of patches with [landuse = 20]
    set color cyan set shape "person"
    set original-color color
    set risk-factor 0.24
    set protection-level ifelse-value use-fixed-protection [children-protection-level] [0.1 + random-float 0.9]
    set awareness ifelse-value use-fixed-awareness [children-awareness-level] [0.1 + random-float 0.9]
    set age-group "child"
  ]

  ;; Create residents (school children)
  create-students initial-number-students [
    move-to one-of patches with [landuse = 20]
    set color cyan set shape "person"
    set original-color color
    set risk-factor 0.24
    set protection-level ifelse-value use-fixed-protection [children-protection-level] [0.1 + random-float 0.9]
    set awareness ifelse-value use-fixed-awareness [children-awareness-level] [0.1 + random-float 0.9]
    set age-group "student"
  ]

  ;; Create residents (adults)
  create-adults initial-number-adults [
    move-to one-of patches with [landuse = 20]
    set color blue set shape "person"
    set original-color color
    set risk-factor 0.55
    set protection-level ifelse-value use-fixed-protection [adults-protection-level] [0.1 + random-float 0.9]
    set awareness ifelse-value use-fixed-awareness [adults-awareness-level] [0.1 + random-float 0.9]
    set age-group "adult"
  ]

  ;; Create residents (seniors)
  create-seniors initial-number-seniors [
    move-to one-of patches with [landuse = 20]
    set color white set shape "person"
    set original-color color
    set risk-factor 0.20
    set protection-level ifelse-value use-fixed-protection [seniors-protection-level] [0.1 + random-float 0.9]
    set awareness ifelse-value use-fixed-awareness [seniors-awareness-level] [0.1 + random-float 0.9]
    set age-group "senior"
  ]

    ;; Create tourists (children)
    create-tourists-children tourists-children-number [
    move-to one-of patches with [landuse > 0]
    set color yellow set shape "person"
    set original-color color
    set stay-duration stay-duration
    set arrival-tick ticks
    set risk-factor 0.24
    set protection-level ifelse-value use-fixed-protection [tourist-children-protection] [0.1 + random-float 0.9]
    set awareness ifelse-value use-fixed-awareness [tourist-children-awareness] [0.1 + random-float 0.9]
    set age-group "tourist-child"
  ]

  ;; Create tourists (adults)
  create-tourists-adults tourists-adults-number [
    move-to one-of patches with [landuse > 0]
    set color yellow set shape "person"
    set original-color color
    set stay-duration stay-duration
    set arrival-tick ticks
    set risk-factor 0.50
    set protection-level ifelse-value use-fixed-protection [tourist-adults-protection] [0.1 + random-float 0.9]
    set awareness ifelse-value use-fixed-awareness [tourist-adults-awareness] [0.1 + random-float 0.9]
    set age-group "tourist-adult"
  ]

  ;; Create tourists (seniors)
  create-tourists-seniors tourists-seniors-number [
    move-to one-of patches with [landuse > 0]
    set color yellow set shape "person"
    set original-color color
    set stay-duration stay-duration
    set arrival-tick ticks
    set risk-factor 0.20
    set protection-level ifelse-value use-fixed-protection [tourist-seniors-protection] [0.1 + random-float 0.9]
    set awareness ifelse-value use-fixed-awareness [tourist-seniors-awareness] [0.1 + random-float 0.9]
    set age-group "tourist-senior"
  ]

end

to go
;; End the simulation when the weather file ends, execute these tasks along with it
if ticks >= length weather-list [
    export-results
    export-total-group
    export-new-group
    stop ]

  read-weather                      ;; Read temperature and precipitation for current tick
  assign-activities                 ;; Assign activities to agents based on day and type
  move-turtles                      ;; Move agents to locations based on activity and weather
  reset-bite-stats                  ;; Reset bite status before evaluating bites
  evaluate-tick-bite-risk temperature ;; Compute bite risk and update agent bite status
  count-bites                       ;; Update counters for new/total bites
  update-bite-counts                ;; Update patch bite count values
  write-csv-output                  ;; Log agent-level data to file
  update-visualization             ;; Update map visuals
  draw-map-title
  draw-legend

  ;; Store bite count history for time series plotting
  set bite-count-history lput (list ticks bite-count) bite-count-history
  set new-count-history lput (list ticks new-bites) new-count-history

  ;; Store aggregated bite counts by population (residents vs tourists)
  set total-residents-history lput (list ticks total-residents-bites) total-residents-history
  set total-tourists-history lput (list ticks total-tourists-bites) total-tourists-history
  set new-residents-history lput (list ticks new-residents-bites) new-residents-history
  set new-tourists-history lput (list ticks new-tourists-bites) new-tourists-history

  ;; Store aggregated bite counts by age population group
  set total-children-population-history lput (list ticks total-children-population-bites) total-children-population-history
  set total-adults-population-history lput (list ticks total-adults-population-bites) total-adults-population-history
  set total-seniors-population-history lput (list ticks total-seniors-population-bites) total-seniors-population-history
  set new-children-population-history lput (list ticks new-children-population-bites) new-children-population-history
  set new-adults-population-history lput (list ticks new-adults-population-bites) new-adults-population-history
  set new-seniors-population-history lput (list ticks new-seniors-population-bites) new-seniors-population-history

  ;; Store aggregated bite counts by agent type (resident/tourist by age group)
  set total-children-group-history lput (list ticks total-bites-children) total-children-group-history
  set total-adults-group-history lput (list ticks total-bites-adults) total-adults-group-history
  set total-seniors-group-history lput (list ticks total-bites-seniors) total-seniors-group-history
  set total-tourists-children-group-history lput (list ticks total-bites-tourists-children) total-tourists-children-group-history
  set total-tourists-adults-group-history lput (list ticks total-bites-tourists-adults) total-tourists-adults-group-history
  set total-tourists-seniors-group-history lput (list ticks total-bites-tourists-seniors) total-tourists-seniors-group-history

  set new-children-group-history lput (list ticks new-bites-children) new-children-group-history
  set new-adults-group-history lput (list ticks new-bites-adults) new-adults-group-history
  set new-seniors-group-history lput (list ticks new-bites-seniors) new-seniors-group-history
  set new-tourists-children-group-history lput (list ticks new-bites-tourists-children) new-tourists-children-group-history
  set new-tourists-adults-group-history lput (list ticks new-bites-tourists-adults) new-tourists-adults-group-history
  set new-tourists-seniors-group-history lput (list ticks new-bites-tourists-seniors) new-tourists-seniors-group-history

  ;; Regenerate tourists if their stay has ended (simulating tourist turnover)
  ask tourists-children [
  if (ticks - arrival-tick) >= stay-duration [
    ;; Store current location
    let where patch-here
    let n tourists-children-number  ;; Save how many new ones to create
    let d stay-duration            ;; Save the same stay-duration if desired
    die

    ;; Spawn new tourists-children at the same patch
    ask where [
      sprout-tourists-children n [
        set stay-duration d
        set arrival-tick ticks
        ;; any other setup here
      ]
    ]
  ]
]

ask tourists-adults [
  if (ticks - arrival-tick) >= stay-duration [
    ;; Store current location
    let where patch-here
    let n tourists-children-number  ;; Save how many new ones to create
    let d stay-duration            ;; Save the same stay-duration if desired
    die

    ;; Spawn new tourists-children at the same patch
    ask where [
      sprout-tourists-children n [
        set stay-duration d
        set arrival-tick ticks
        ;; any other setup here
      ]
    ]
  ]
]

ask tourists-seniors [
  if (ticks - arrival-tick) >= stay-duration [
    ;; Store current location
    let where patch-here
    let n tourists-children-number  ;; Save how many new ones to create
    let d stay-duration            ;; Save the same stay-duration if desired
    die

    ;; Spawn new tourists-children at the same patch
    ask where [
      sprout-tourists-children n [
        set stay-duration d
        set arrival-tick ticks
        ;; any other setup here
      ]
    ]
  ]
]

  tick
end

;; Set weather conditions from the weather csv file
to read-weather
  let row item ticks weather-list
  set precipitation item 0 row
  set temperature item 1 row
end

;; Activities
; 1 = dog walking
; 2 = gardening
; 3 = green maintenance
; 4 = playing
; 5 = walking
; 6 = picnicking
; 7 = others (work)
; 8 = indoors

to assign-activities
  ;; Define flags
  let is-weekday (ticks mod 7 != 6 and ticks mod 7 != 0)
  let is-weekend (ticks mod 7 = 6 or ticks mod 7 = 0)
  let is-student-vacation (
    (ticks >= 300 and ticks <= 307) or ; 26 Oct – 3 Nov
    (ticks >= 356 or ticks <= 5) or  ; 21 Dec – 5 Jan
    (ticks >= 53 and ticks <= 61) or ; 22 Feb – 2 Mar
    (ticks >= 117 and ticks <= 125) or ; 26 Apr – 4 May
    (ticks >= 200 and ticks <= 243) ; 19 Jul – 31 Aug
  )
  let is-adult-vacation (ticks >= 200 and ticks <= 219) ; 19 Jul - 7 Aug
  let is-hot-or-rainy (temperature >= 25 or precipitation >= 5)

  ;; Adults
  (ifelse
    is-weekday and not is-adult-vacation [
      ask adults [ set activity 7 ]
    ]
    is-hot-or-rainy [
      ask adults [ set activity 8 ]
    ]
    [ ask adults [ set activity one-of [1 2 3 4 5 6 7 8] ] ]
  )

  ;; Students
  (ifelse
    is-weekday and not is-student-vacation [
      ask students [ set activity 7 ]
    ]
    is-hot-or-rainy [
      ask students [ set activity 8 ]
    ]
    [ ask students [ set activity one-of [1 2 3 4 5 6 7 8] ] ]
  )

  ;; Children
  (ifelse
    is-hot-or-rainy [
      ask children [ set activity 8 ]
    ]
    [ ask children [ set activity one-of [1 2 3 4 5 6 7 8] ] ]
  )

  ;; Seniors
  (ifelse
    is-hot-or-rainy [
      ask seniors [ set activity 8 ]
    ]
    [ ask seniors [ set activity one-of [1 2 3 4 5 6 7 8] ] ]
  )

  ;; Tourists
  (ifelse
    is-hot-or-rainy [
      ask tourists-children [ set activity 8 ]
      ask tourists-adults [ set activity 8 ]
      ask tourists-seniors [ set activity 8 ]
    ]
    [
      ask tourists-children [ set activity one-of [1 2 3 4 5 6 7 8] ]
      ask tourists-adults [ set activity one-of [1 2 3 4 5 6 7 8] ]
      ask tourists-seniors [ set activity one-of [1 2 3 4 5 6 7 8] ]
    ]
  )
end



;; Move agents to land-use patches based on activity and weather
to move-turtles
  ask turtles [

    if (activity = 1 or activity = 2 or activity = 3 or activity = 5 or activity = 8) [
      move-to one-of patches with [landuse = 20]
    ]
    if (activity = 7) [
      move-to one-of patches with [landuse = 62]
    ]
    if (activity = 4 or activity = 6) [
      move-to one-of patches with [landuse = 60 or landuse = 61]
    ]

  ]
end

;; Reset each agent’s bite status to false at start of each tick
to reset-bite-stats
  ask turtles [set bite-stat false]
end

to count-bites

  ;; Count new bites per agent group
  set new-bites-children (count children with [bite-stat]) + (count students with [bite-stat])
  set new-bites-adults count adults with [bite-stat]
  set new-bites-seniors count seniors with [bite-stat]
  set new-bites-tourists-children count tourists-children with [bite-stat]
  set new-bites-tourists-adults count tourists-adults with [bite-stat]
  set new-bites-tourists-seniors count tourists-seniors with [bite-stat]

  ;; Total new bites this tick
  set new-bites (new-bites-children + new-bites-adults + new-bites-seniors + new-bites-tourists-children + new-bites-tourists-adults + new-bites-tourists-seniors)

  ;; Cumulative total bites
  set bite-count bite-count + new-bites

  ;; Update group-specific cumulative counts
  set total-bites-children total-bites-children + new-bites-children
  set total-bites-adults total-bites-adults + new-bites-adults
  set total-bites-seniors total-bites-seniors + new-bites-seniors
  set total-bites-tourists-children total-bites-tourists-children + new-bites-tourists-children
  set total-bites-tourists-adults total-bites-tourists-adults + new-bites-tourists-adults
  set total-bites-tourists-seniors total-bites-tourists-seniors + new-bites-tourists-seniors

  ;; Total by population type
  set new-residents-bites (new-bites-children + new-bites-adults + new-bites-seniors)
  set new-tourists-bites (new-bites-tourists-children + new-bites-tourists-adults + new-bites-tourists-seniors)
  set total-residents-bites (total-bites-children + total-bites-adults + total-bites-seniors)
  set total-tourists-bites (total-bites-tourists-children + total-bites-tourists-adults + total-bites-tourists-seniors)

  ;; Combined population-level counts
  set new-children-population-bites (new-bites-children + new-bites-tourists-children)
  set new-adults-population-bites (new-bites-adults + new-bites-tourists-adults)
  set new-seniors-population-bites (new-bites-seniors + new-bites-tourists-seniors)
  set total-children-population-bites (total-bites-children + total-bites-tourists-children)
  set total-adults-population-bites (total-bites-adults + total-bites-tourists-adults)
  set total-seniors-population-bites (total-bites-seniors + total-bites-tourists-seniors)

end

;; Export agent-level data for each tick to a CSV file
to write-csv-output
  file-open "data/outputs/csv/agent-output.csv"
  ask turtles [
    let agent-type ""
    if is-child? self [set agent-type "child"]
    if is-adult? self [set agent-type "adult"]
    if is-senior? self [set agent-type "senior"]
    if is-tourist-child? self [set agent-type "tourist-child"]
    if is-tourist-adult? self [set agent-type "tourist-adult"]
    if is-tourist-senior? self [set agent-type "tourist-senior"]


    file-print ( (word ticks ","
                      agent-type ","
                      activity ","
                      bite-stat ","
                      landuse))
  ]
  file-close
end

to update-bite-counts
  ;; Always reset patch bite counts each tick
  ;;ask patches [ set patch-bite-count 0 ]

  ;; Now add bites from this tick
  ask turtles with [bite-stat] [
    ask patch-here [
      set patch-bite-count patch-bite-count + 1
    ]
  ]
end


;; Export raster dataset of agent counts per patch
to export-results
  set output-file gis:patch-dataset patch-bite-count
  gis:store-dataset output-file "data/outputs/tick_bite_heatmap.asc"
end

;; Update the color of the patches and turtles based on the selected visualization layer
to update-visualization
  ifelse show-bite-heatmap [;; Show red-scaled heatmap of bite counts per patch
    let max-bites max [patch-bite-count] of patches
    if max-bites = 0 [ set max-bites 1 ] ;; Avoid division by zero when no bites yet
    ask patches [
      set pcolor scale-color red patch-bite-count 0 max-bites
    ]
  ] [
    ifelse show-tick-density [;; Show green-scaled heatmap of tick density
      ask patches [
        set pcolor scale-color green tick-density 0 1
      ]
    ] [
      ifelse show-patch-risk [;; Show red-scaled heatmap of calculated patch risk
        ask patches [
          set pcolor scale-color red patch-risk 0 1
        ]
      ] [
        ;; Default view: color patches by land use class
        ask patches [
          if landuse = 20 [ set pcolor red ]
          if landuse = 60 [ set pcolor green ]
          if landuse = 61 [ set pcolor brown ]
          if landuse = 62 [ set pcolor gray ]
        ]
      ]
    ]
  ]

  ;; Update turtle color based on whether they have been bitten
  ask turtles [
    if bite-stat [
      set color pink
    ]
    if not bite-stat [
      set color original-color
    ]
  ]
end

;; Draw a legend on the map explaining the current visualization
to draw-legend
  ; Clear previous legend
  ask patches with [pxcor > (max-pxcor - 8) and pycor < (min-pycor + 5)] [
    set pcolor black
    set plabel ""
  ]

  ask patches with [pxcor > (max-pxcor - 30) and pycor < (min-pycor + 5)] [
    set pcolor black
    set plabel ""
  ]

  ;; agents index
show-legend-entry (min-pxcor ) (min-pycor + 4) "Children" cyan
show-legend-entry (min-pxcor) (min-pycor + 3) "Adults" blue
show-legend-entry (min-pxcor) (min-pycor + 2) "Seniors" white
show-legend-entry (min-pxcor) (min-pycor + 1) "Tourists" yellow


  ;; Show legend depending on which layer is being visualized
  if show-tick-density [
    let y min-pycor
    show-legend-entry (max-pxcor - 7) (min-pycor + 3) "Low Density" white
    show-legend-entry (max-pxcor - 7) (min-pycor + 2) "Medium Density" 53
    show-legend-entry (max-pxcor - 7) (min-pycor + 1) "High Density" 51

  ]

  if show-patch-risk [
    show-legend-entry (max-pxcor - 6) (min-pycor + 3) "Low Risk" 14
    show-legend-entry (max-pxcor - 6) (min-pycor + 2) "Medium Risk" 12
    show-legend-entry (max-pxcor - 6) (min-pycor + 1) "High Risk" black

  ]

  if show-bite-heatmap [
    show-legend-entry (max-pxcor - 6) (min-pycor + 3) "Low Risk" white
    show-legend-entry (max-pxcor - 6) (min-pycor + 2) "Medium Risk" 14
    show-legend-entry (max-pxcor - 6) (min-pycor + 1) "High Risk" black

  ]

  if not show-tick-density and not show-patch-risk and not show-bite-heatmap [
  show-legend-entry (max-pxcor - 6) (min-pycor + 4) "Residential" red
  show-legend-entry (max-pxcor - 6) (min-pycor + 3) "Forest" green
  show-legend-entry (max-pxcor - 6) (min-pycor + 2) "Dunes/Sand" brown
  show-legend-entry (max-pxcor - 6) (min-pycor + 1) "Other" gray

  ]
end

;; Display a single entry in the legend
to show-legend-entry [x y caption swatch-color]

  ;; Draw color swatch and label for legend
  if not show-tick-density [
  ask patch x y [
    set pcolor swatch-color
    ask patch (x + 5) y [ set plabel caption ]
  ]
  ]

  if show-tick-density [
    ask patch x y [
    set pcolor swatch-color
    ask patch (x + 6) y [ set plabel caption ]
  ]
  ]
end

;; Draw map title and a North arrow
to draw-map-title
  ask patch (max-pxcor / 6) max-pycor [ set plabel "Ede, The Netherlands" ]
  ask patch (max-pxcor / 6) (max-pycor - 2) [ set plabel "Tick Bite Risk Simulation" ]
  ask patch max-pxcor max-pycor [ set plabel "N" ]
end

;; Export total bite counts by group and age (residents and tourists) to CSV
to export-total-group
  file-open "data/outputs/csv/total_group.csv"
  file-print "time-step,total-children-bites,total-adults-bites,total-seniors-bites,total-tourists-children-bites,total-tourists-adults-bites,total-tourists-seniors-bites"

  let n length total-children-group-history
  (foreach n-values n [ i -> i ] [
    i ->
    let tick-value item 0 (item i total-children-group-history)
    let children-bite item 1 (item i total-children-group-history)
    let adults-bite item 1 (item i total-adults-group-history)
    let seniors-bite item 1 (item i total-seniors-group-history)
    let tourists-children-bite item 1 (item i total-tourists-children-group-history)
    let tourists-adults-bite item 1 (item i total-tourists-adults-group-history)
    let tourists-seniors-bite item 1 (item i total-tourists-seniors-group-history)
    file-print (word tick-value "," children-bite "," adults-bite "," seniors-bite "," tourists-children-bite "," tourists-adults-bite "," tourists-seniors-bite)
  ])

  file-close
end

;; Export new bite counts by group and age (residents and tourists) to CSV
to export-new-group
  file-open "data/outputs/csv/new_group.csv"
  file-print "time-step,new-children-bites,new-adults-bites,new-seniors-bites,new-tourists-children-bites,new-tourists-adults-bites,new-tourists-seniors-bites"

  let n length new-children-group-history
  (foreach n-values n [ i -> i ] [
    i ->
    let tick-value item 0 (item i new-children-group-history)
    let children-bite item 1 (item i new-children-group-history)
    let adults-bite item 1 (item i new-adults-group-history)
    let seniors-bite item 1 (item i new-seniors-group-history)
    let tourists-children-bite item 1 (item i new-tourists-children-group-history)
    let tourists-adults-bite item 1 (item i new-tourists-adults-group-history)
    let tourists-seniors-bite item 1 (item i new-tourists-seniors-group-history)
    file-print (word tick-value "," children-bite "," adults-bite "," seniors-bite "," tourists-children-bite "," tourists-adults-bite "," tourists-seniors-bite)
  ])

  file-close
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
13
12
76
45
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
96
12
159
45
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
13
57
84
102
NIL
bite-count
17
1
11

MONITOR
92
57
162
102
NIL
new-bites
17
1
11

SLIDER
92
575
266
608
children-protection-level
children-protection-level
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
267
575
442
608
adults-protection-level
adults-protection-level
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
442
575
618
608
seniors-protection-level
seniors-protection-level
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
92
609
267
642
tourist-children-protection
tourist-children-protection
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
13
485
168
518
stay-duration
stay-duration
1
30
30.0
1
1
NIL
HORIZONTAL

PLOT
19
812
339
1028
Total Bites
Time
Tick Bites
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total Bites" 1.0 0 -16777216 true "" "plot bite-count"

PLOT
340
812
652
1028
New Bites
Time
Tick Bites
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"New Bites" 1.0 0 -16777216 true "" "plot new-bites"

PLOT
19
1460
340
1673
Total Bites (Separated) - Per Capita
Time
Tick Bites
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Children" 1.0 0 -8053223 true "" "plotxy ticks (total-bites-children / (initial-number-children))"
"Adults" 1.0 0 -13210332 true "" "plotxy ticks (total-bites-adults / (initial-number-adults))"
"Seniors" 1.0 0 -14730904 true "" "plotxy ticks (total-bites-seniors / (initial-number-seniors))"
"Tourist Children" 1.0 0 -11053225 true "" "plotxy ticks (total-bites-tourists-children / (tourists-children-number))"
"Tourist Adults" 1.0 0 -10402772 true "" "plotxy ticks (total-bites-tourists-adults / (tourists-adults-number))"
"Tourist Seniors" 1.0 0 -4079321 true "" "plotxy ticks (total-bites-tourists-seniors / (tourists-seniors-number))"

PLOT
340
1460
652
1673
New Bites (Separated) - Per Capita
Time
Tick Bites
0.0
10.0
0.0
0.5
true
true
"" ""
PENS
"Children" 1.0 0 -8053223 true "" "plotxy ticks (new-bites-children / (initial-number-children))"
"Adults" 1.0 0 -13210332 true "" "plotxy ticks (new-bites-adults / (initial-number-adults))"
"Seniors" 1.0 0 -14730904 true "" "plotxy ticks (new-bites-seniors / (initial-number-seniors))"
"Tourist Children" 1.0 0 -11053225 true "" "plotxy ticks (new-bites-tourists-children / (tourists-children-number))"
"Tourist Adults" 1.0 0 -10402772 true "" "plotxy ticks (new-bites-tourists-adults / (tourists-adults-number))"
"Tourist Seniors" 1.0 0 -4079321 true "" "plotxy ticks (new-bites-tourists-seniors / (tourists-seniors-number))"

SLIDER
12
246
166
279
initial-number-children
initial-number-children
0
100
10.0
5
1
NIL
HORIZONTAL

SLIDER
12
311
166
344
initial-number-adults
initial-number-adults
0
100
60.0
10
1
NIL
HORIZONTAL

SLIDER
12
346
167
379
initial-number-seniors
initial-number-seniors
0
100
20.0
10
1
NIL
HORIZONTAL

SWITCH
13
114
163
147
show-tick-density
show-tick-density
1
1
-1000

SWITCH
13
147
163
180
show-patch-risk
show-patch-risk
1
1
-1000

SWITCH
13
179
163
212
show-bite-heatmap
show-bite-heatmap
1
1
-1000

SWITCH
267
542
417
575
use-fixed-protection
use-fixed-protection
1
1
-1000

SLIDER
88
713
267
746
children-awareness-level
children-awareness-level
0.0
1.0
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
267
713
445
746
adults-awareness-level
adults-awareness-level
0.0
1.0
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
445
713
624
746
seniors-awareness-level
seniors-awareness-level
0.0
1.0
0.5
0.1
1
NIL
HORIZONTAL

SWITCH
267
681
444
714
use-fixed-awareness
use-fixed-awareness
1
1
-1000

SLIDER
12
381
167
414
tourists-children-number
tourists-children-number
0
200
55.0
5
1
NIL
HORIZONTAL

SLIDER
13
416
168
449
tourists-adults-number
tourists-adults-number
0
200
160.0
5
1
NIL
HORIZONTAL

SLIDER
13
450
168
483
tourists-seniors-number
tourists-seniors-number
0
200
55.0
5
1
NIL
HORIZONTAL

PLOT
19
1029
339
1243
Total Bites (Overall) - Per Capita
Time
Tick Bites
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Residents" 1.0 0 -8053223 true "" "plotxy ticks (total-residents-bites / (initial-number-students + initial-number-children + initial-number-adults + initial-number-seniors))"
"Tourists" 1.0 0 -14730904 true "" "plotxy ticks (total-tourists-bites / (tourists-children-number + tourists-adults-number + tourists-seniors-number))"

PLOT
340
1028
652
1244
New Bites (Overall) - Per Capita
Time
Tick Bites
0.0
365.0
0.0
0.3
true
true
"" ""
PENS
"Residents" 1.0 0 -8053223 true "" "plotxy ticks (new-residents-bites / (initial-number-students + initial-number-children + initial-number-adults + initial-number-seniors))"
"Tourists" 1.0 0 -14730904 true "" "plotxy ticks (new-tourists-bites / (tourists-children-number + tourists-adults-number + tourists-seniors-number))"

PLOT
19
1244
338
1459
Total Bites (Grouped) - Per Capita
Time
Tick Bites
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Children" 1.0 0 -8053223 true "" "plotxy ticks (total-children-population-bites /(initial-number-children + initial-number-students + tourists-children-number))"
"Adults" 1.0 0 -13210332 true "" "plotxy ticks (total-adults-population-bites / (initial-number-adults + tourists-adults-number))"
"Seniors" 1.0 0 -14730904 true "" "plotxy ticks (total-seniors-population-bites / (initial-number-seniors + tourists-seniors-number))"

PLOT
340
1244
652
1460
New Bites (Grouped) - Per Capita
Time
Tick Bites
0.0
365.0
0.0
0.3
true
true
"" ""
PENS
"Children" 1.0 0 -8053223 true "" "plotxy ticks (new-children-population-bites / (initial-number-students + initial-number-children + tourists-children-number))"
"Adults" 1.0 0 -13210332 true "" "plotxy ticks (new-adults-population-bites / (initial-number-adults + tourists-adults-number))"
"Seniors" 1.0 0 -14730904 true "" "plotxy ticks (new-seniors-population-bites /(initial-number-seniors + tourists-seniors-number))"

SLIDER
88
745
268
778
tourist-children-awareness
tourist-children-awareness
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
267
745
445
778
tourist-adults-awareness
tourist-adults-awareness
0
1.0
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
445
745
625
778
tourist-seniors-awareness
tourist-seniors-awareness
0
1.0
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
267
609
443
642
tourist-adults-protection
tourist-adults-protection
0
1.0
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
442
609
618
642
tourist-seniors-protection
tourist-seniors-protection
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
12
279
166
312
initial-number-students
initial-number-students
0
100
10.0
5
1
NIL
HORIZONTAL

@#$#@#$#@
# Tick Bite Risk Simulation – Ede, The Netherlands

## WHAT IS IT?

This model simulates tick bite risk across a spatially-explicit landscape in Ede, the Netherlands. The simulation accounts for environmental features such as land use types, spatial tick densities, and human populations. It produces visual maps and exports various CSV datasets to support further analysis of bite risk, human exposure, and group-level statistics.

## WHY IS THIS MODEL INTERESTING?

Ticks are vectors for serious diseases like Lyme borreliosis. Understanding how environmental features and human behavior affect tick bite risk is essential for public health and spatial planning. This model visualizes risk dynamically and provides structured output data for epidemiological or ecological analysis.

## HOW IT WORKS

The model operates on a GIS-based landscape where patches represent spatial units with different land use types and tick densities. Agents (turtles) represent humans who can receive tick bites based on local risk levels. The model records bite events over time and categorizes them by group (residents vs. tourists, age categories, etc.).

The model supports several visualization modes:

* **Bite Heatmap**: Shows number of bites per patch.
* **Tick Density**: Displays static tick density per patch.
* **Patch Risk**: Visualizes model-computed tick bite risk.
* **Land Use Map**: Colors patches by land use category.

Users can toggle these visualizations and observe how tick bite risk evolves over time.

## VISUALIZATION & LEGEND

The `update-visualization` procedure colors patches and agents depending on the current display mode:

* Red gradient: Number of bites (heatmap)
* Green gradient: Tick density
* Land use:
-- Red: Residential (code 20)
-- Green: Forest (code 60)
-- Blue: Dunes/Sand (code 61)
-- Gray: Other (code 62)

Legends are dynamically drawn in the lower-right corner of the map depending on the active visualization.

A map title and north arrow are shown at the top of the view.

## OUTPUT EXPORTS

### Raster Output:

* `output_ascii.asc`: An ASCII grid file storing patch-level agent count for GIS use.

### CSV Time-Series Data:

Each CSV is stored in the `data/outputs/csv/` directory.

* **Bite Counts**:

  * `bite_count.csv`: Total bite count per tick.
  *  &nbsp; &nbsp; &nbsp;`new_count.csv`: New bites per tick (incremental).

* **Aggregate Bites**:

  * `total_agg.csv`: Cumulative resident vs. tourist bites.
  * &nbsp; &nbsp; &nbsp;`new_agg.csv`: New resident vs. tourist bites per tick.

* **Census Bites (by Age Group)**:

  * `total_census.csv`: Cumulative bites by children, adults, seniors.
  * &nbsp; &nbsp; &nbsp;`new_census.csv`: New bites per tick by age group.

* **Group Bites (Residents + Tourists, by Age Group)**:

  * `total_group.csv`: Total bites by age and population type.
  * &nbsp; &nbsp; &nbsp;`new_group.csv`: New bites by age and population type.

These outputs enable users to analyze temporal dynamics of tick exposure across groups and locations.

## HOW TO USE IT

1. Load the model and initialize the environment.
2. Use the interface controls to start the simulation.
3. Toggle visualization options to inspect different layers.
4. After running, use the export buttons or procedures to generate output files.
5. Analyze exported CSV or ASCII raster data in external tools, like QGIS.

## EXTENSIONS USED

* GIS Extension: Used for storing raster datasets (e.g., agent counts per patch).
* CSV Extension: Used for reading and writing CSV files.

## RELATED MODELS

This model is inspired by spatial agent-based models used in disease ecology and environmental epidemiology, particularly those simulating vector-host interactions in heterogeneous landscapes.

## CREDITS AND REFERENCES

Model developed for spatial epidemiological analysis of tick bite risk in Ede, the Netherlands.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Robustness experiment" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>bite-count</metric>
  </experiment>
  <experiment name="fixed_residents" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>initial-number-tourists</metric>
    <metric>bite-count</metric>
    <steppedValueSet variable="initial-number-residents" first="0" step="100" last="1000"/>
    <steppedValueSet variable="initial-number-tourists" first="0" step="100" last="1000"/>
  </experiment>
  <experiment name="landuse_bites" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="365"/>
    <metric>bites-forest</metric>
    <metric>bites-dunes</metric>
    <metric>bites-other</metric>
    <metric>bites-residential</metric>
    <steppedValueSet variable="initial-number-residents" first="0" step="100" last="1000"/>
    <steppedValueSet variable="initial-number-tourists" first="0" step="100" last="1000"/>
  </experiment>
  <experiment name="baseline_simulation" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>bite-count</metric>
    <metric>total-bites-children</metric>
    <metric>total-bites-adults</metric>
    <metric>total-bites-seniors</metric>
    <metric>total-bites-tourists</metric>
    <steppedValueSet variable="initial-number-children" first="0" step="100" last="10"/>
    <steppedValueSet variable="initial-number-adults" first="0" step="100" last="10"/>
    <steppedValueSet variable="initial-number-seniors" first="0" step="100" last="10"/>
    <steppedValueSet variable="initial-number-tourists" first="0" step="100" last="10"/>
    <steppedValueSet variable="stay-duration" first="0" step="30" last="1"/>
    <steppedValueSet variable="children-risk-factor" first="0" step="2" last="0.2"/>
    <steppedValueSet variable="adults-risk-factor" first="0" step="2" last="0.2"/>
    <steppedValueSet variable="seniors-risk-factor" first="0" step="2" last="0.2"/>
    <steppedValueSet variable="tourists-risk-factor" first="0" step="2" last="0.2"/>
    <steppedValueSet variable="children-awareness" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="adults-awareness" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="seniors-awareness" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="tourists-awareness" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="children-protection-level" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="adults-protection-level" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="seniors-protection-level" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="tourists-protection-level" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="children-prevention-level" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="adults-prevention-level" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="seniors-prevention-level" first="0" step="1" last="0.1"/>
    <steppedValueSet variable="tourists-prevention-level" first="0" step="1" last="0.1"/>
  </experiment>
  <experiment name="ex_3" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="366"/>
    <metric>initial-number-children</metric>
    <metric>bite-count</metric>
    <steppedValueSet variable="initial-number-children" first="0" step="10" last="100"/>
  </experiment>
  <experiment name="stabalisation" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="366"/>
    <metric>bite-count</metric>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
