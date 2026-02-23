# Scenario System

## Plain English

Scenarios are hand-crafted challenges that give players structured goals instead of pure sandbox play. Each scenario has specific objectives to complete (build X holes, reach Y reputation, etc.), optional time limits, and a 1-3 star rating based on performance.

There are 10 scenarios arranged in an unlock chain — completing one unlocks the next. Some scenarios force a specific course theme (desert, links, mountain) while others let the player choose. Starting money varies per scenario, and "The Turnaround" even starts the player in debt.

Stars work as follows:
- **1 star**: Complete all required objectives
- **2 stars**: Complete objectives + meet bonus conditions (e.g., profit threshold)
- **3 stars**: Complete objectives + meet harder bonus conditions

Progress persists across saves — completed scenarios and star ratings are saved with the game data. Players can replay scenarios to earn higher star ratings.

## Algorithm

### Scenario Structure

Each scenario defines:
```
{
  id: String,              # Unique identifier
  name: String,            # Display name
  description: String,     # Flavor text
  theme: int,              # CourseTheme.Type or -1 for player choice
  starting_money: int,     # Override starting balance
  time_limit_days: int,    # 0 = no limit
  unlock_requires: String, # id of prerequisite scenario
  objectives: Array,       # Required objectives
  star_2: Dictionary,      # Bonus conditions for 2 stars
  star_3: Dictionary,      # Bonus conditions for 3 stars
}
```

### Objective Types

| Type | What It Measures | Example |
|------|-----------------|---------|
| HOLES_CREATED | Open holes on course | "Build 9 holes" |
| GOLFERS_SERVED | Cumulative golfers who finished rounds | "Serve 50 golfers" |
| REPUTATION_REACHED | Current reputation value | "Reach 75 reputation" |
| TOTAL_PROFIT | Cumulative daily profit | "Earn $10,000 profit" |
| RATING_STARS | Current course star rating | "Reach 3-star rating" |
| TOURNAMENT_HOSTED | Highest tournament tier hosted | "Host Regional tournament" |
| MONEY_REACHED | Current money balance | "End with $25,000+" |
| DAYS_SURVIVED | Days elapsed since scenario start | "Survive 28 days" |

### Progress Check (runs end-of-day)

```
for each objective:
    progress = get_current_value(objective.type)
    met = progress >= objective.target

if all objectives met:
    stars = 1
    if meets_star_2_conditions: stars = 2
    if meets_star_3_conditions: stars = 3
    complete_scenario(stars)
elif time_limit > 0 and elapsed >= time_limit:
    fail_scenario("Time limit reached")
```

### Star Conditions

Star bonus conditions use these checks:
- `total_profit`: Cumulative daily profit across all days
- `reputation`: Current reputation value
- `rating_stars`: Current course star rating (1-5)
- `money`: Current money balance

All conditions in a star tier must be met simultaneously.

### Unlock Chain

```
first_tee (no prereq)
├── budget_build → weather_storm
│                → city_slicker
├── the_nine → desert_oasis → the_turnaround
│            → mountain_majesty → championship_dream → resort_paradise
```

### The 10 Scenarios

| # | Name | Theme | Money | Time | Key Objective |
|---|------|-------|-------|------|---------------|
| 1 | First Tee | Choice | $30k | None | Build 3 holes, serve 10 golfers |
| 2 | Budget Build | Choice | $20k | 56d | Reach 3-star with tight budget |
| 3 | The Nine | Choice | $40k | 84d | Build 9 holes, $10k profit |
| 4 | Weather the Storm | Links | $35k | 28d | Survive windy conditions |
| 5 | Desert Oasis | Desert | $35k | 56d | Profitable desert course |
| 6 | Mountain Majesty | Mountain | $45k | 84d | Host Regional tournament |
| 7 | City Slicker | City | $40k | 56d | 75 reputation, 80 golfers |
| 8 | The Turnaround | Choice | -$5k | 56d | Recover from debt |
| 9 | Championship Dream | Choice | $50k | 168d | Host all tournament tiers |
| 10 | Resort Paradise | Resort | $60k | 112d | 5-star, 90 rep, $100k profit |

## Tuning Levers

| Parameter | Location | Current Value | What Changing It Does |
|-----------|----------|---------------|----------------------|
| Starting money per scenario | `scenario_system.gd` SCENARIOS | Varies ($20k-$60k) | Adjusts scenario difficulty |
| Time limits | `scenario_system.gd` SCENARIOS | 0-168 days | Adjusts time pressure |
| Objective targets | `scenario_system.gd` SCENARIOS | Varies | Changes what players must achieve |
| Star 2/3 conditions | `scenario_system.gd` SCENARIOS | Varies | Adjusts bonus challenge difficulty |
| Unlock requirements | `scenario_system.gd` SCENARIOS | Chain-based | Changes scenario progression order |
