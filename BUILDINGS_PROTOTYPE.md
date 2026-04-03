# Omerta Buildings Prototype

## Goal

Define the first building set for the gangster management game so the building layer can be added after the world and district layers are working.

Buildings should support the core fantasy:

- grow a criminal empire
- hide illegal activity
- manage risk
- turn districts into specialized territory

## Building Progression

The game should progress through these layers:

1. World layer
2. District layer
3. Building layer
4. Room and object layer

This document focuses on layer 3: buildings.

## Core Building Categories

The first prototype should use 4 building categories:

- production buildings
- sales and front buildings
- safe and support buildings
- control and expansion buildings

## Production Buildings

### Warehouse

Purpose:

- storage
- future production support
- smuggling staging point

Best district:

- Industrial

Gameplay role:

- raises storage capacity
- good for hiding goods in moderate volumes
- vulnerable if heat is already high

### Workshop Lab

Purpose:

- early illegal production
- later upgrade path into more advanced drug processing

Best district:

- Industrial

Gameplay role:

- produces goods
- increases district heat while active
- benefits from protection and low police attention

## Sales And Front Buildings

### Corner Store Front

Purpose:

- cover for low-scale sales
- legal-looking public presence

Best district:

- Residential

Gameplay role:

- small income
- lowers suspicion compared to open street activity
- improves local influence over time

### Bar Or Social Club

Purpose:

- front business
- recruitment and social network hub

Best district:

- Residential
- Slums

Gameplay role:

- improves influence
- helps recruit crew
- can become a meeting point for missions and story events

## Safe And Support Buildings

### Safehouse

Purpose:

- crew shelter
- stash point
- emergency fallback location

Best district:

- Slums
- Residential

Gameplay role:

- protects crew
- stores limited goods, cash, or weapons
- useful during raids and heat spikes

### Doctor's Office Front

Purpose:

- medical support
- clean public-facing cover

Best district:

- Residential

Gameplay role:

- helps injured crew recover later in development
- lowers suspicion compared to overt criminal sites
- opens future research and chemistry paths

## Control And Expansion Buildings

### Tenement Block

Purpose:

- area influence
- passive recruitment

Best district:

- Slums

Gameplay role:

- slowly increases local control
- helps player gain a foothold in rough neighborhoods
- attracts gang attention if overused

### Gang Hideout

Purpose:

- territory anchor
- planning and enforcement center

Best district:

- Slums

Gameplay role:

- increases control
- supports intimidation and defense
- raises chance of gang conflict

## Prototype Building Set By District

### Industrial

Recommended first buildings:

- Warehouse
- Workshop Lab

District fantasy:

- produce, store, move

### Residential

Recommended first buildings:

- Corner Store Front
- Bar Or Social Club
- Doctor's Office Front

District fantasy:

- sell, influence, legitimize

### Slums

Recommended first buildings:

- Safehouse
- Tenement Block
- Gang Hideout
- Bar Or Social Club

District fantasy:

- recruit, hide, expand

## Building Stats For The First Prototype

Each building can later share a small common stat set:

- `cost`
- `heat_generation`
- `income`
- `control_gain`
- `storage`
- `crew_capacity`
- `risk`

Example interpretation:

- `cost`: upfront purchase or setup price
- `heat_generation`: how much attention it creates over time
- `income`: direct or indirect money output
- `control_gain`: influence in the district
- `storage`: goods or cash capacity
- `crew_capacity`: how many crew can operate there
- `risk`: chance of attracting raids, tips, or rival aggression

## Suggested Early Building Rules

- Industrial buildings produce more heat when run aggressively
- Residential fronts reduce suspicion compared to raw street dealing
- Slums buildings are cheaper but increase rival trouble
- buildings should reinforce district identity rather than make all districts interchangeable

## First Building Layer Success Criteria

The building layer will be working well if:

- each district has a clear building identity
- players can understand why a building belongs in one district more than another
- fronts, production, and hideouts create meaningful tradeoffs
- buildings expand strategy instead of replacing district strategy
