# Omerta 3D Hybrid Plan

## Vision

Omerta should become a hybrid game with:

- management and task control inspired by RimWorld
- a believable 3D city atmosphere inspired by Mafia
- tactical gangster combat with cover, positioning, and zone control

The player is not a single action character like GTA.
The player is a boss who controls crews inside a living city.

## Core Direction

### World Feel

- 3D city blocks with streets, sidewalks, alleys, storefronts, warehouses, and tenements
- moving civilians, traffic, and district activity
- districts that feel connected as one city instead of isolated menus

### Management Feel

- select crew members or whole squads
- assign move orders, work orders, patrol routes, or operations
- claim buildings and turn them into fronts, labs, hideouts, and storage
- manage money, heat, influence, supplies, and district control

### Combat Feel

- tactical real-time with optional pause or slowdown later
- cover-based fights in streets, bars, warehouses, and alleys
- police, rival gangs, and player crews behave differently

## Layer Structure

### 1. City Block Layer

This is the first playable layer.
The player sees a 3D district block from an angled top-down management camera.

Needs:

- roads
- sidewalks
- buildings
- pedestrians
- traffic
- district boundaries
- crew movement

### 2. District Control Layer

Each block belongs to a district and tracks:

- player control
- heat
- police presence
- demand
- rival pressure

This should drive what happens visually and mechanically in the world.

### 3. Building Ownership Layer

Buildings can later become:

- warehouse
- workshop lab
- safehouse
- bar or club front
- doctor's office front
- gang hideout

### 4. Crew Layer

Crew members should later support:

- move
- escort
- guard
- recruit
- deliver
- fight
- hide
- work

## First 3D Prototype Goal

The first 3D prototype does not need deep mechanics yet.
It needs to prove the right feel.

The player should immediately understand:

- this is a city, not a board
- districts are real places
- people and traffic move through it
- this can become a management game with units, buildings, and fights

## First 3D Prototype Contents

- one small connected city block
- 3 visible district zones:
  - Industrial
  - Residential
  - Slums
- management camera from above at an angle
- a few simple buildings in each zone
- moving pedestrians
- moving cars
- district labels or markers
- lightweight HUD explaining controls

## Recommended Build Order

### Phase 1. Visual Foundation

- 3D blockout city
- roads, sidewalks, alleys
- skyline and lighting mood
- district coloring and landmarks

### Phase 2. Living City

- pedestrians walking routes
- cars driving routes
- simple ambient world activity

### Phase 3. Management Controls

- click-select crew
- move orders
- simple group control
- basic operation points on the map

### Phase 4. Buildings

- clickable owned buildings
- assign building purpose
- connect buildings to district systems

### Phase 5. Gangster Combat

- hostile encounters
- cover points
- street firefights
- police interventions

## Camera Direction

Use a high angled 3D camera:

- closer and more immersive than RimWorld
- still strategic and readable
- not first-person
- not over-the-shoulder

The player should feel like a criminal planner watching a live city block.

## Prototype Success Criteria

This new direction is working if:

- the city already feels more believable than the old 2D world map
- districts feel visually different in 3D
- traffic and civilians make the city feel alive
- the camera supports future management gameplay
- it is easy to imagine crew control, building ownership, and combat on top of it
