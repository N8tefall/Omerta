# Omerta City Visual Prototype

## Goal

Give a clear visual picture of what the first playable world and district structure should feel like in a 2D tile-based management game.

This is not final art. It is a production guide for layout, camera feel, UI structure, and district identity.

## Visual Direction

The game should feel like:

- top-down 2D
- tile-based
- readable like a colony sim
- gritty 1920s crime atmosphere
- compact city map at the world layer

The player first interacts with the city as a strategic board, then later zooms into district maps, then eventually into buildings.

## World Layer Layout

The first prototype city should contain 3 major districts:

- Industrial
- Residential
- Slums

Suggested world map arrangement:

```text
+-----------------------------------------------------------+
|                      CITY OVERVIEW                        |
|                                                           |
|   [ INDUSTRIAL ]                                          |
|   Factories, rail, storage, smoke                         |
|                                                           |
|                                [ RESIDENTIAL ]            |
|                                Homes, shops, bars         |
|                                                           |
|                  [ SLUMS ]                                |
|                  Crowded blocks, alleys, gang turf        |
|                                                           |
|-----------------------------------------------------------|
| Money | Crew | Goods | City Heat | Active District | Day  |
+-----------------------------------------------------------+
```

## District Identity At A Glance

### Industrial

Visual cues:

- brick warehouses
- factory roofs
- train tracks
- chimneys
- loading yards
- muted grey-brown palette

Player expectation:

- this is where goods are produced and stored

### Residential

Visual cues:

- apartment blocks
- corner stores
- bars
- cleaner streets
- street lamps
- warmer and more orderly palette

Player expectation:

- this is where product gets sold and influence grows

### Slums

Visual cues:

- cramped buildings
- patched roofs
- narrow alleys
- broken fences
- crowded lots
- rougher, dirtier palette

Player expectation:

- this is where cheap expansion and recruitment happen, but danger is higher

## UI Structure For The First Prototype

The world layer should show:

- district map in the center
- global resources at the bottom or top
- district details in a side panel
- action buttons for the selected district

Suggested UI:

```text
+----------------------+------------------------------------+
| District Details     |                                    |
|----------------------|           CITY MAP                 |
| Name                 |                                    |
| Heat                 |                                    |
| Police Presence      |                                    |
| Demand               |                                    |
| Rival Pressure       |                                    |
| Player Control       |                                    |
|                      |                                    |
| [Action Buttons]     |                                    |
+----------------------+------------------------------------+
| Money | Crew | Goods | City Heat | Day | Tick Speed       |
+-----------------------------------------------------------+
```

## Camera Feel

For the first city layer:

- fixed top-down presentation
- light camera pan is optional
- district selection should be immediate and readable
- each district should feel like a large city zone, not a tiny icon

The world layer should resemble a tactical city board more than a literal full city simulation.

## District Layer Preview

Later, when entering a district, the player should see a tile-based local map with lots, roads, and building shells.

Example expectation:

```text
+---------------------------------------------+
| DISTRICT: INDUSTRIAL                        |
|                                             |
|  RR====RR         Warehouse Lot             |
|  RR====RR   [] [] [] [] []                  |
|                                             |
|  Factory Block       Yard       Side Road   |
|  ###########         ....       ========    |
|  ###########         ....                   |
|                                             |
+---------------------------------------------+
```

This later layer should support:

- selecting lots
- moving crews
- choosing operations
- eventually entering buildings

## Production Art Notes

When we later build the actual visuals, the style should favor:

- readable silhouettes
- muted historic colors
- grime and atmosphere without losing clarity
- clear tile contrast for roads, lots, buildings, and danger zones

Avoid:

- overly cartoony look
- overly realistic clutter that hurts readability
- bright modern neon style

## First Prototype Promise

If we build the first prototype correctly, the player should immediately understand:

- where to produce
- where to sell
- where to recruit and hide

Even before buildings exist, the city layer should already communicate strategy.
