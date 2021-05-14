__includes[
  "trafficnetwork.nls"
  "Vehicle(NS).nls"
]

; INSTRUCTIONS IN ENGLISH
; Instructions if there is a problem adding the osmnlogo extension:
; inside the NetLogo directory, enter the 'app' directory
; then enter the 'extensions' directory, create a folder called osmnlogo
; and add the osmnlogo.jar file inside the created folder

; INSTRUÇÕES EM PORTUGUÊS
; Instruções caso haja problema ao adicionar a extensão osmnlogo:
; dentro do diretório do NetLogo, entre no diretório 'app'
; depois entre no diretório 'extensions', crie uma pasta chamada osmnlogo
; e adicione o arquivo osmnlogo.jar dentro da pasta criada

extensions [gis nw osmnlogo table ] ; padrao dos modelos de exemplo: extensions todas em uma linha

breed [ GraphNodes GraphNode ] ; padrao eh declaracao da breed em linha unica

undirected-link-breed [ GraphLinks GraphLink ]

breed [ Controladores Controlador ]

GraphNodes-own[
  inlinks
  outlinks
]

Controladores-own[
  duracaoCiclo
  inLanes ;  os inlinks do GraphNode onde está o semáforo
  qTable ; o conhecimento do agente
  states ; lista de todos os estados percebidos
  actions ;lista de todas as ações (planos) disponíveis
  learningRate
  discountFactor
  epsilon
  epsilonDecay
  currentState ; o estado atual
  currentAction ; a ação (plano) escolhido
  currentReward ; a recompensa calculada
  previousState ; o estado anterior (particularidade Q-learning)
  previousAction ; a ação anterior (particularidade Q-learning)
  paradosNorte
  paradosOeste
]

to setup
  clear-all
  reset-ticks
  random-seed 47822
  createTrafficNetworkFromOsm  "1x1-oneway-network.osm" GraphNodes GraphLinks

  vehiclesSetup

  ask GraphNodes with [ length inlinks > 1 ] [
    hatch-Controladores 1 [
      set inLanes [inlinks] of myself
      ; inicializa parâmetros do aprendizado
      set learningRate 0.1
      set discountFactor 0.3
      set epsilon 0.7
      set epsilonDecay 0.995
      set previousState nobody
      set previousAction nobody
      set actions ["plano1" "plano2"] ; representação lógica das ações
      set currentAction "plano1" ; ativar um determinado plano para iniciar o agente
      setupQLearning ; ativar procedure do qlearning.nls que inicializa os 'states' e outros detalhes
    ]
  ]
end

to go
  tick
  ask Controladores [
    controlarFluxo
  ]
  vehiclesGo
end

to controlarFluxo
   contaCarrosParados
  if duracaoCiclo = 45[

    set duracaoCiclo 0
    set currentReward recompensa

    set currentState (word paradosNorte "," paradosOeste) ; determinar o estado atual: string com tamanho das filas
    updateQLearning ; ativar o aprendizado para o agente aprender

    set currentAction selectQLearningActionEpsilonGreedy currentState ; escolher ação que será feita agora
    set epsilon epsilon * epsilonDecay
  ]

  executarPlano
  set duracaoCiclo duracaoCiclo + 1
end

to-report recompensa
    report -1 * (paradosNorte + paradosOeste)
end

to contaCarrosParados
 if-else currentAction = "plano1" [
    if duracaoCiclo = 30 [
      set paradosOeste queueLength item 1 inLanes
    ]
    if duracaoCiclo = 45 [
      set paradosNorte queueLength item 0 inLanes
    ]
  ][
    if duracaoCiclo = 15 [
      set paradosOeste queueLength item 1 inLanes
    ]
    if duracaoCiclo = 45 [
      set paradosNorte queueLength item 0 inLanes
    ]
  ]
end

to executarPlano
  if-else currentAction = "plano1" [
    ifelse duracaoCiclo < 30 [
      ask patch-at 0 1 [
        set pcolor green
      ]
      ask patch-at -1 0 [
        set pcolor red
      ]
    ][
      ask patch-at 0 1 [
        set pcolor red
      ]
      ask patch-at -1 0 [
        set pcolor green
      ]
    ]
  ][
    ifelse duracaoCiclo < 15 [
      ask patch-at 0 1 [
        set pcolor green
      ]
      ask patch-at -1 0 [
        set pcolor red
      ]
    ][
      ask patch-at 0 1 [
        set pcolor red
      ]
      ask patch-at -1 0 [
        set pcolor green
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Q-Learning NetLogo library.
; This implementation requires the following breed-owns:
;    actions        ; List that stores the available actions. This list
;                   ; must be populated by the user during the agent setup.
;    states         ; List that stores the learning states. This list is populated
;                   ; automatically by this Q-Learning implementation as new states are discovered
;    qTable         ; Table data structure that stores que QTable of the Q-Learning algorithm
;    learningRate   ; Numeric variable that provides the learning rate value for the Q-Learning
;                   ; algorithm. Must be initialized by the user
;    discountFactor ; Numeric variable that provides the discount factor value for the Q-Learning
;                   ; algorithm. Must be initialized by the user
;    reward         ; Numeric variable that provides the reward value that will be used to update the QTable.
;                   ; Must be set by the user before running the 'updateQLearning' procedure
;    currentState   ; Provides the current state, as perceived by the agent.
;                   ; Its value must be updated by the user before running the 'updateQLearning' procedure
;    currentAction  ; Provides the current action that was chosen by the agent.
;                   ; Its value must be updated by the user before running the 'updateQLearning' procedure
;    previousState  ; Stores the previous state of the QLearning.
;                   ; It is set automatically by the 'updateQLearning' procedure
;    previousAction ; Stores the previous action chosen by the QLearning
;                   ; It is set automatically by the 'selectQLearningActionEpsilonGreedy' procedure
;    epsilon        ; Numeric variable that provides the epsilon value for the
;                   ; epsilon-greedy action selection strategy.
;                   ; Must be set by the user before running the 'selectQLearningActionEpsilonGreedy' procedure
;
; Limitations:
; Only one QLearning feature is allowed per agent breed, and therefore an agent is able to deal
; with only one learning task. If you agent need more than one QLearning feature, you must extend
; this library to deal with additional breed-owns (one of the above set of breed-owns must be
; defined for each learning task).
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Q-Learning setup procedure.
; Must be called by the agent breed to initialize the Q-Learning data structures.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setupQLearning
  set  states []
  set qTable table:make
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Updates the Q-Table according to the values provided by the agent breed-owns explained above.
; In other words, makes the agent 'learn'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to updateQLearning
  let sPos position currentState states

  if sPos = false [
     ; It is a new state. Save it on the states list
     set states lput currentState states
     ; Saving the state position for further reference
     set sPos length states - 1

     ; Creating a new action-values table for the new state
     let sActionValues table:make
     let aPos 0
     foreach actions [
       table:put sActionValues aPos 0
       set aPos aPos + 1
     ]
     ; Adding the new state and its action-value table to the Qtable
     table:put qTable sPos sActionValues
  ]


  ; Updating the q-table given the previousState, previousAction, currentState, and currentReward
  let previousStateActionValues 0
  ; Update only if there is a previousState and previousAction
  if previousState != nobody and previousAction != nobody [
    let previousStatePos findStatePos previousState
    ;show (word "previousStatePos: " previousStatePos)
	  ifelse table:has-key? qTable previousStatePos [
	    ; An entry for this state already exists in the qTable
	    set previousStateActionValues table:get qTable previousStatePos
	  ][
	    ; A new entry for this state must be created
	    set previousStateActionValues table:make
	    table:put qTable previousStatePos previousStateActionValues
	  ]

	  let currentStateActionValues 0
    let currentStatePos findStatePos currentState
    ;show (word "currentStatePos: " currentStatePos)
    ifelse table:has-key? qTable currentStatePos [
	  	 ; An entry for the currentState already exists in the qTable
	    set currentStateActionValues table:get qTable currentStatePos
	  ][
	    ; A new entry for the currentState must be created
	    set currentStateActionValues table:make
	    table:put qTable currentStatePos currentStateActionValues
	  ]

	  let q_s_a 0
	  let max_q_s'_a' 0

    ; If there are actionValues for the previousState, find the qValue for the previousAction
    let previousActionPos findActionPos previousAction
    ;show (word "previousActionPos: " previousActionPos)
    if table:length previousStateActionValues > 0 and table:has-key? previousStateActionValues previousActionPos [
	    set q_s_a table:get previousStateActionValues previousActionPos
	  ]

    ; If there are actionValues for the currentState, find the qValue for the currentAction
	  if table:length currentStateActionValues > 0 [
      let maxActionPosition internalFindMaxActionValuePosition currentStateActionValues
	    set max_q_s'_a' table:get currentStateActionValues maxActionPosition
	  ]
	  let new_q_s_a ( q_s_a + (learningRate * ( currentReward + (discountFactor * max_q_s'_a') - q_s_a ) ) )
	  table:put previousStateActionValues previousActionPos new_q_s_a
   ]

  ; Saves the current state. Next turn it will be considered the previous state
  set previousState currentState
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Selects an action for the given state using the epsilon greedy strategy and considering the QTable.
; Parameters:
;  state: The state to which an action will be selected using the epsilon greedy strategy.
; Returns:
;  The action with the maximum Q value for the given state with probability '1-epsilon', and a random
;  action with probability 'epsilon'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report selectQLearningActionEpsilonGreedy [ state ]
  ; Selects an action for the given state using the epsilon-greedy selection policy
  let sPos position state states
  let aPos 0
  let roulette random-float 1.0
  ifelse roulette < epsilon [
    ; Pick a random action
    set aPos random length actions
    ;show "Epsilon greedy strategy: random action was chosen"
  ][
    ; Select the action for the state s with max Q value
    ;show "Epsilon greedy strategy:  max Q(s,a) action was chosen"
    let actionValues table:get qTable sPos
    ifelse table:length actionValues > 0 [
       	set aPos internalFindMaxActionValuePosition actionValues

    ][
       ; If no action has been visited so far, return a random one since all have qValue = 0
       set aPos random length actions
    ]
  ]
  ; Recovers the selected action from its position
  let selectedAction item aPos actions

  ; Saves the selected action. Next turn it will be considered the previous action
  set previousAction selectedAction

  report selectedAction
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Internal (private) reporter that examines the given actionValues table and reports the position
; of the action with the maximum Q-value.
; Parameters:
;  actionValues: A table data structure with actions and their corresponding Q-values
; Returns:
;  The position of the action with the maximum Q-value
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report internalFindMaxActionValuePosition [ actionValues ]
  let keys table:keys actionValues
  let maxValuePos random length keys
  let maxValue table:get actionValues item maxValuePos keys
  foreach keys [ [key] ->
     let v table:get actionValues key
     if v > maxValue [
       set maxValue v
       set maxValuePos key
     ]
  ]
  report maxValuePos
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Internal (private) reporter that finds the position of the given action in the 'actions' breed-own.
; Parameters:
;  action: An action object
; Returns:
;  The position of the action object in the 'actions' breed-own.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report findActionPos [action]
  report position action actions
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Internal (private) reporter that finds the position of the given state in the 'states' breed-own.
; Parameters:
;  state: A state object
; Returns:
;  The position of the state object in the 'states' breed-own.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report findStatePos [state]
  report position state states
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper procedure that prints the 'qTable' breed-own in a [almost] human-readable format.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to printQTable
	let actionsHeader "  "
	foreach actions [ [a] ->
		set actionsHeader (word actionsHeader a "   ")
	]
	show actionsHeader
	let sPos 0
	foreach states [ [s] ->
		let stateRow ""
		set stateRow (word stateRow s)
		let sActionValues table:get qTable sPos
		let aPos 0
		repeat length actions [
			let aValue table:get sActionValues aPos
			set aPos aPos + 1
			set stateRow (word stateRow "   " aValue)
		]
		set sPos sPos + 1
		show stateRow
	]
end
@#$#@#$#@
GRAPHICS-WINDOW
281
10
718
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
12
10
75
43
NIL
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
81
10
144
43
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
12
52
276
236
Veiculos
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"parados" 1.0 0 -16777216 true "" "if ticks mod 45 = 0 [ plot count Vehicles with [ speed = 0 ] ]"

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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="86400"/>
    <metric>ifelse-value (ticks mod 45 = 0) [count Vehicles with [ speed = 0 ]] [""]</metric>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
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
