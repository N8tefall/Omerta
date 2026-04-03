# Omerta World Layer Prototype

## Goal

Build a small, testable city map for the first playable prototype of a 2D tile-based gangster management game inspired by RimWorld-style layered simulation.

This first version focuses only on the world layer:

- 1 city
- 3 districts
- district selection
- district stats
- simple action loop
- heat and police pressure

The goal is not full content yet. The goal is to prove that the core management loop feels good.

## Prototype City Structure

The first city contains 3 districts:

1. Industrial
2. Residential
3. Slums

These 3 districts are enough to test production, selling, expansion, police pressure, and rival pressure without making the map too large.

## Core District Stats

Each district should have the following values:

- `heat`
- `police_presence`
- `demand`
- `rival_pressure`
- `player_control`

Optional later values:

- `income_modifier`
- `recruitment_value`
- `transport_risk`
- `front_business_value`

## District Roles

### 1. Industrial

Main role:
- production district

Gameplay identity:
- best location for manufacturing and storage
- suitable for warehouses, labs, and later transport hubs
- efficient, but easier to detect when large-scale activity grows

Prototype strengths:
- high production efficiency
- medium district demand
- good future logistics potential

Prototype weaknesses:
- visible operations increase heat faster
- police attention grows quickly once activity becomes large

Suggested starting values:

- `heat: 15`
- `police_presence: 45`
- `demand: 35`
- `rival_pressure: 25`
- `player_control: 20`

### 2. Residential

Main role:
- sales and public influence district

Gameplay identity:
- best place to distribute product and build social influence
- useful for small fronts, soft power, and lower-scale operations
- residents and informants create risk if the player acts too openly

Prototype strengths:
- high demand
- stable environment
- strong long-term value for fronts and money flow

Prototype weaknesses:
- complaints and tips can raise heat
- police response is more sensitive to visible crime

Suggested starting values:

- `heat: 10`
- `police_presence: 55`
- `demand: 70`
- `rival_pressure: 15`
- `player_control: 10`

### 3. Slums

Main role:
- expansion, recruitment, and hidden operations

Gameplay identity:
- cheapest district to enter and grow in
- easier to hide small illegal activity
- unstable and dangerous because rival gangs are stronger here

Prototype strengths:
- low entry cost
- strong recruitment potential
- easier to build underground influence

Prototype weaknesses:
- high rival pressure
- instability can trigger conflict and sudden losses

Suggested starting values:

- `heat: 20`
- `police_presence: 25`
- `demand: 50`
- `rival_pressure: 65`
- `player_control: 30`

## First Prototype Loop

The first playable loop should be simple:

1. The player views the city map.
2. The player selects a district.
3. The player chooses a simple district action.
4. Stats change over time.
5. Heat and pressure create consequences.

## District Actions For Prototype

Each district should support a few basic actions.

### Industrial

- `Produce`
- `Store Goods`
- `Lay Low`

Expected effect:
- `Produce` increases stock and money potential, but raises heat
- `Store Goods` reduces short-term risk but ties up inventory
- `Lay Low` lowers heat slowly

### Residential

- `Sell`
- `Build Influence`
- `Lay Low`

Expected effect:
- `Sell` converts stock into money
- `Build Influence` increases future control
- `Lay Low` lowers heat and police attention

### Slums

- `Recruit`
- `Expand Influence`
- `Hide Operations`

Expected effect:
- `Recruit` increases crew potential
- `Expand Influence` increases control but risks gang attention
- `Hide Operations` lowers visibility but slows growth

## City-Level Resources

The player should track a few global values in the first prototype:

- `money`
- `crew`
- `stored_goods`
- `city_heat`

`city_heat` can be derived from district heat totals or averages.

## Early Balancing Intention

The first prototype should encourage this pattern:

- produce mainly in Industrial
- build foothold and recruit in Slums
- sell mainly in Residential

This creates natural movement between districts and gives each district a clear reason to exist.

## Event Hooks For Later

Not needed in version 1, but the world layer should leave room for:

- police inspections
- rival ambushes
- neighborhood complaints
- corrupt officials
- transport interceptions

## Recommended Godot Implementation Order

1. Create a city scene with 3 selectable districts.
2. Store district data in resources, dictionaries, or a simple manager script.
3. Add UI panels for district stats.
4. Add a time tick system.
5. Add district actions that modify stats.
6. Add simple consequence rules based on heat and police presence.

## Success Criteria

The world layer prototype is successful if:

- the player can understand district differences at a glance
- each district feels useful for a different purpose
- actions create understandable tradeoffs
- heat creates pressure without overwhelming the player too early
- the loop is interesting before buildings are added
