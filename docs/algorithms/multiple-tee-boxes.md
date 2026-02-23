# Multiple Tee Boxes

## Plain English

Each hole can have up to three tee boxes at different distances from the green:

- **Forward Tee** (red marker) — Shorter distance, used by beginner golfers. Makes the hole easier and more accessible.
- **Middle Tee** (default) — Standard distance, used by casual and serious golfers. This is the tee placed during hole creation and determines the hole's par.
- **Back Tee** (blue marker) — Longer distance, used by pro golfers and tournament players. A more challenging line.

Golfers automatically select their tee based on skill tier. The middle tee is always present (it's the original tee from hole creation). Forward and back tees are optional upgrades the player can add to existing holes.

Par is always based on the middle tee distance — forward/back tees change the effective playing distance but not the hole's official par.

## Algorithm

### Tee Selection

```
get_tee_for_tier(tier):
    if tier == BEGINNER and forward_tee exists:
        return forward_tee
    if tier == PRO and back_tee exists:
        return back_tee
    return middle_tee  (default for CASUAL, SERIOUS, and when extra tees don't exist)

get_tee_for_tournament():
    if back_tee exists:
        return back_tee
    return middle_tee
```

### Tee Mapping

| Golfer Tier  | Tee Used      | Rationale                          |
|-------------|---------------|-------------------------------------|
| Beginner    | Forward       | Shorter distance, less intimidating |
| Casual      | Middle        | Standard play                       |
| Serious     | Middle        | Standard competitive distance       |
| Pro         | Back          | Full championship distance          |
| Tournament  | Back          | Always championship tees            |

### Placement Validation

**Forward tee** must satisfy:
- `distance(forward_tee, green) < distance(middle_tee, green)` — closer to green than middle tee
- `distance(forward_tee, green) >= 3 tiles` — not on/adjacent to the green

**Back tee** must satisfy:
- `distance(back_tee, green) > distance(middle_tee, green)` — further from green than middle tee

Both forward and back tees:
- Must be on a valid grid position
- Cost one tee box tile placement ($cost from TerrainTypes)
- Place a TEE_BOX terrain tile at the position

### Distance Display

Each tee has its own effective distance to the green:
```
forward_distance = calculate_distance_yards(forward_tee, green_position)
middle_distance  = hole.distance_yards  (always middle tee to green)
back_distance    = calculate_distance_yards(back_tee, green_position)
```

### Visual Indicators

- Forward tee: Red diamond marker with "F" label
- Back tee: Blue diamond marker with "B" label
- Middle tee: Standard tee box tile (no extra marker — it's the default)
- Info label shows "Tees: N" when multiple tees exist

### Save/Load

Tee positions are serialized alongside existing hole data:
```json
{
  "tee_position": {"x": 10, "y": 20},
  "forward_tee": {"x": 12, "y": 18},
  "back_tee": {"x": 8, "y": 22},
  ...
}
```

Forward/back tee fields are only present when those tees exist (backward compatible — older saves without these fields load correctly with no extra tees).

## Tuning Levers

| Parameter | Location | Current Value | What Changing It Does |
|-----------|----------|---------------|----------------------|
| Forward tee tier | `game_manager.gd` `get_tee_for_tier()` | BEGINNER | Which tier uses forward tee |
| Back tee tier | `game_manager.gd` `get_tee_for_tier()` | PRO | Which tier uses back tee |
| Min forward tee distance from green | `hole_creation_tool.gd` `_place_extra_tee()` | 3 tiles | How close forward tee can be to green |
| Tee box placement cost | `terrain_types.gd` via `get_placement_cost(TEE_BOX)` | Terrain cost | Cost to place each extra tee |
