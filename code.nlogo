extensions [gis csv]

__includes ["tick-bite-submodel.nls"]

breed [children child]
breed [adults adult]
breed [seniors senior]
breed [tourists tourist]

breed [residents resident]

turtles-own [
  activity risk-factor bite-stat protection-level exposure-level
  awareness prevention-level age-group
  original-color

]

patches-own [
  landuse agent-count patch-risk tick-density
  patch-bite-count
]

globals [
  landuse-dataset shape-dataset
  precipitation temperature
  output-file bite-count new-bites
  weather-list
  total-bites-children total-bites-adults total-bites-seniors total-bites-tourists
  new-bites-children new-bites-adults new-bites-seniors new-bites-tourists
]

to setup
  clear-all
  file-close-all

  set weather-list load-weather-data "data/ede_precipitation.csv"

  setup-environment
  setup-agents
  reset-ticks
  set bite-count 0

  set total-bites-children 0
  set total-bites-adults 0
  set total-bites-seniors 0
  set total-bites-tourists 0

  set new-bites-children 0
  set new-bites-adults 0
  set new-bites-seniors 0
  set new-bites-tourists 0

  draw-legend

  file-open "data/agent-output.csv"
  file-print "tick,agent-type,x,y,activity,bite-stat,age-group,protection-level,awareness,exposure-level,patch-landuse,patch-risk"
  file-close
end

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

to setup-environment
  set landuse-dataset gis:load-dataset "data/Ede/ede_ascii.asc"
  gis:set-world-envelope (gis:envelope-of landuse-dataset)
  gis:apply-raster landuse-dataset landuse

  ask patches [
    if landuse = 20 [set pcolor red set tick-density 0.2 set patch-risk 0.05]; residential
    if landuse = 60 [set pcolor green set tick-density 1.0 set patch-risk 0.85]; forest
    if landuse = 61 [set pcolor blue set tick-density 0.6 set patch-risk 0.40]; dunes/ sand
    if landuse = 62 [set pcolor grey set tick-density 0.3 set patch-risk 0.20]; other
  ]

  set shape-dataset gis:load-dataset "data/Ede/Ede_shape.shp"
  gis:set-drawing-color white
  gis:draw shape-dataset 1
  draw-legend
  ask patches [ set patch-bite-count 0 ]

end

to setup-agents
  create-children initial-number-children [
    move-to one-of patches with [landuse = 20]
    set color cyan set shape "person"
    set original-color color
    set risk-factor children-risk-factor
    set protection-level children-protection-level
    set awareness children-awareness
    set prevention-level children-prevention-level
    set age-group "child"
  ]

  create-adults initial-number-adults [
    move-to one-of patches with [landuse = 20]
    set color blue set shape "person"
    set original-color color
    set risk-factor adults-risk-factor
    set protection-level adults-protection-level
    set awareness adults-awareness
    set prevention-level adults-prevention-level
    set age-group "adult"
  ]

  create-seniors initial-number-seniors [
    move-to one-of patches with [landuse = 20]
    set color gray set shape "person"
    set original-color color
    set risk-factor seniors-risk-factor
    set protection-level seniors-protection-level
    set awareness seniors-awareness
    set prevention-level seniors-prevention-level
    set age-group "senior"
  ]

  create-tourists initial-number-tourists [
    move-to one-of patches with [landuse > 0]
    set color yellow set shape "person"
    set original-color color
    set stay-duration stay-duration
    set risk-factor tourists-risk-factor
    set protection-level tourists-protection-level
    set awareness tourists-awareness
    set prevention-level tourists-prevention-level
    set age-group "tourist"
  ]
end

to go
  if ticks >= length weather-list [export-results stop]

  read-weather
  assign-activities
  move-turtles
  reset-bite-stats
  evaluate-tick-bite-risk temperature
  count-bites
  write-csv-output
  update-visualization
  draw-map-title
  draw-legend
  tick
end

to read-weather
  let row item ticks weather-list
  set precipitation item 0 row
  set temperature item 1 row
end

; activities
; 1 = work
; 2 = cycling
; 3 = picnic
; 4 = walking
; 5 = playing
; 6 = school

to assign-activities
  ask children [set activity one-of [2 3 4 5 6]]

  if ticks mod 7 != 6 and ticks mod 7 != 0 [
    ; Weekdays
    ask adults [set activity 1]
  ]
  if ticks mod 7 = 6 or ticks mod 7 = 0 [
    ; Weekends
    ask adults [set activity one-of [2 3 4]]
  ]

  ask seniors [set activity one-of [2 3 4]]
  ask tourists [set activity one-of [2 3 4]]
end

to move-turtles
  ask turtles [
    if (activity = 1 or activity = 4 or activity = 5 or activity = 6) [
      move-to one-of patches with [landuse = 20]
    ]
    if (activity = 2 or activity = 3 and precipitation < 50) [
      move-to one-of patches with [landuse = 60 or landuse = 61]
    ]
    if (temperature > 25) [move-to one-of patches with [landuse = 20]]
  ]
end

to reset-bite-stats
  ask turtles [set bite-stat false]
end

to count-bites
  set new-bites-children count children with [bite-stat]
  set new-bites-adults count adults with [bite-stat]
  set new-bites-seniors count seniors with [bite-stat]
  set new-bites-tourists count tourists with [bite-stat]

  set new-bites (new-bites-children + new-bites-adults + new-bites-seniors + new-bites-tourists)
  set bite-count bite-count + new-bites

  set total-bites-children total-bites-children + new-bites-children
  set total-bites-adults total-bites-adults + new-bites-adults
  set total-bites-seniors total-bites-seniors + new-bites-seniors
  set total-bites-tourists total-bites-tourists + new-bites-tourists
end


to write-csv-output
  file-open "data/agent-output.csv"
  ask turtles [
    let agent-type ""
    if is-child? self [set agent-type "child"]
    if is-adult? self [set agent-type "adult"]
    if is-senior? self [set agent-type "senior"]
    if is-tourist? self [set agent-type "tourist"]

    file-print ( (word ticks ","
                      agent-type ","
                      xcor ","
                      ycor ","
                      activity ","
                      bite-stat ","
                      age-group ","
                      protection-level ","
                      awareness ","
                      exposure-level ","
                      [landuse] of patch-here ","
                      [patch-risk] of patch-here) )
  ]
  file-close
end


to export-results
  set output-file gis:patch-dataset agent-count
  gis:store-dataset output-file "data/output_ascii.asc"
end

to update-visualization
  ifelse show-bite-heatmap [
    let max-bites max [patch-bite-count] of patches
    if max-bites = 0 [ set max-bites 1 ] ;; avoid division by zero when no bites yet
    ask patches [
      set pcolor scale-color red patch-bite-count 0 max-bites
    ]
  ] [
    ifelse show-tick-density [
      ask patches [
        set pcolor scale-color green tick-density 0 1
      ]
    ] [
      ifelse show-patch-risk [
        ask patches [
          set pcolor scale-color red patch-risk 0 1
        ]
      ] [
        ;; Default landuse-based coloring
        ask patches [
          if landuse = 20 [ set pcolor red ]
          if landuse = 60 [ set pcolor green ]
          if landuse = 61 [ set pcolor blue ]
          if landuse = 62 [ set pcolor gray ]
        ]
      ]
    ]
  ]

  ask turtles [
    if bite-stat [
      set color black
    ]
    if not bite-stat [
      set color original-color
    ]
  ]
end




to draw-legend
  ; Clear previous legend
  ask patches with [pxcor > (max-pxcor - 8) and pycor < (min-pycor + 5)] [
    set pcolor black
    set plabel ""
  ]

  if show-tick-density [
    let y min-pycor
    show-legend-entry (max-pxcor - 7) (min-pycor + 3) "Low Density" white
    show-legend-entry (max-pxcor - 7) (min-pycor + 2) "Medium Density" 56
    show-legend-entry (max-pxcor - 7) (min-pycor + 1) "High Density" 53

  ]

  if show-patch-risk [
    show-legend-entry (max-pxcor - 6) (min-pycor + 3) "Low Risk" 19
    show-legend-entry (max-pxcor - 6) (min-pycor + 2) "Medium Risk" 14
    show-legend-entry (max-pxcor - 6) (min-pycor + 1) "High Risk" 12
  ]

  if show-bite-heatmap [
    show-legend-entry (max-pxcor - 6) (min-pycor + 3) "Low Risk" white
    show-legend-entry (max-pxcor - 6) (min-pycor + 2) "Medium Risk" 14
    show-legend-entry (max-pxcor - 6) (min-pycor + 1) "High Risk" black
  ]

  if not show-tick-density and not show-patch-risk and not show-bite-heatmap [
  show-legend-entry (max-pxcor - 6) (min-pycor + 4) "Residential" red
  show-legend-entry (max-pxcor - 6) (min-pycor + 3) "Forest" green
  show-legend-entry (max-pxcor - 6) (min-pycor + 2) "Dunes/Sand" blue
  show-legend-entry (max-pxcor - 6) (min-pycor + 1) "Other" gray
  ]
end

to show-legend-entry [x y caption swatch-color]

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

to draw-map-title

  ask patch (max-pxcor / 6) max-pycor [ set plabel "Ede, The Netherlands" ]
  ask patch (max-pxcor / 6) (max-pycor - 2) [ set plabel "Tick Bite Risk Simulation" ]

  ; North arrow
  ask patch min-pxcor max-pycor [ set plabel "N" ]
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

SLIDER
12
106
175
139
initial-number-residents
initial-number-residents
0
100
90.0
10
1
NIL
HORIZONTAL

SLIDER
11
147
176
180
initial-number-tourists
initial-number-tourists
0
100
40.0
10
1
NIL
HORIZONTAL

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
11
466
170
499
children-risk-factor
children-risk-factor
0
2
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
179
467
327
500
adults-risk-factor
adults-risk-factor
0
2
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
333
467
483
500
seniors-risk-factor
seniors-risk-factor
0
2
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
491
468
649
501
tourists-risk-factor
tourists-risk-factor
0
2
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
11
558
172
591
children-protection-level
children-protection-level
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
178
558
327
591
adults-protection-level
adults-protection-level
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
335
559
486
592
seniors-protection-level
seniors-protection-level
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
493
559
652
592
tourists-protection-level
tourists-protection-level
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
11
513
171
546
children-awareness
children-awareness
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
177
513
326
546
adults-awareness
adults-awareness
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
334
513
485
546
seniors-awareness
seniors-awareness
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
490
512
650
545
tourists-awareness
tourists-awareness
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
12
606
172
639
children-prevention-level
children-prevention-level
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
178
605
327
638
adults-prevention-level
adults-prevention-level
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
335
606
487
639
seniors-prevention-level
seniors-prevention-level
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
493
605
653
638
tourists-prevention-level
tourists-prevention-level
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
12
652
173
685
stay-duration
stay-duration
1
30
10.0
1
1
NIL
HORIZONTAL

PLOT
11
191
171
311
Total Bites
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot bite-count"

PLOT
12
322
172
442
New Bites
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot new-bites"

PLOT
12
696
294
880
Total Bites (by group)
Time
Cumulative Bites
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"children" 1.0 0 -11221820 true "" "plotxy ticks total-bites-children"
"adults" 1.0 0 -13345367 true "" "plotxy ticks total-bites-adults"
"seniors" 1.0 0 -16777216 true "" "plotxy ticks total-bites-seniors"
"tourists" 1.0 0 -1184463 true "" "plotxy ticks total-bites-tourists"

PLOT
309
695
608
880
New Bites (by group)
Time
New Bites per Tick
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"children" 1.0 0 -11221820 true "" "plotxy ticks new-bites-children"
"adults" 1.0 0 -13345367 true "" "plotxy ticks new-bites-adults"
"seniors" 1.0 0 -16777216 true "" "plotxy ticks new-bites-seniors"
"tourists" 1.0 0 -1184463 true "" "plotxy ticks new-bites-seniors"

SLIDER
13
887
191
920
initial-number-children
initial-number-children
0
100
20.0
10
1
NIL
HORIZONTAL

SLIDER
200
891
372
924
initial-number-adults
initial-number-adults
0
100
40.0
10
1
NIL
HORIZONTAL

SLIDER
383
895
556
928
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
17
932
172
965
show-tick-density
show-tick-density
1
1
-1000

SWITCH
187
936
333
969
show-patch-risk
show-patch-risk
1
1
-1000

SWITCH
349
939
514
972
show-bite-heatmap
show-bite-heatmap
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
