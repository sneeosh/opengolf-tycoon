# Tournament System

> **Source:** `scripts/systems/tournament_system.gd` and `scripts/managers/tournament_manager.gd`

## Plain English

Tournaments are special events where the course is closed to regular play and filled with competitive golfers. The player pays an entry cost upfront, and if the course qualifies, earns revenue from spectators and sponsorships plus a reputation boost.

### Four Tiers

Tournaments come in four tiers with escalating requirements and rewards:
- **Local** — Small community event. Needs just 4 holes and a 2-star rating. Low risk, low reward.
- **Regional** — Competitive event. Needs 9 holes, 3 stars, and difficulty 4+. Medium rewards.
- **National** — Prestigious event. Needs 18 holes, 4 stars, and difficulty 5+. Big money and reputation.
- **Championship** — The ultimate event. Needs 18 holes, 4.5 stars, difficulty 6+, and 6500+ yards. Huge rewards but $50,000 entry cost.

### Tournament Flow

1. **Schedule** — Player selects a tier and pays the entry cost. Local tournaments start the next day; larger ones need 3 days of preparation.
2. **Play** — On tournament day, regular golfers are cleared and tournament golfers (50% Pro, 50% Serious tier) spawn in groups of 4 with staggered start times.
3. **Scoring** — Live scores are tracked on a leaderboard. If the player ends the day early, remaining holes are simulated mathematically.
4. **Completion** — Revenue is awarded (spectators + sponsorships), reputation is gained, and results are displayed.

### Cooldown

There's a mandatory 7-day cooldown between tournaments to prevent spam and maintain their special event feel.

---

## Algorithm

### 1. Tier Requirements & Rewards

| | Local | Regional | National | Championship |
| --- | --- | --- | --- | --- |
| **Min Holes** | 4 | 9 | 18 | 18 |
| **Min Rating** | 2.0 | 3.0 | 4.0 | 4.5 |
| **Min Difficulty** | - | 4.0 | 5.0 | 6.0 |
| **Min Yardage** | 1,500 | 3,000 | 6,000 | 6,500 |
| **Entry Cost** | $500 | $2,000 | $10,000 | $50,000 |
| **Prize Pool** | $1,000 | $5,000 | $25,000 | $100,000 |
| **Spectator Revenue** | $800 | $4,000 | $20,000 | $80,000 |
| **Sponsorship Revenue** | $500 | $3,000 | $15,000 | $60,000 |
| **Total Revenue** | $1,300 | $7,000 | $35,000 | $140,000 |
| **Net Profit** | $800 | $5,000 | $25,000 | $90,000 |
| **Participants** | 12 | 24 | 48 | 72 |
| **Duration** | 1 day | 2 days | 3 days | 4 days |
| **Rep Reward** | +15 | +40 | +100 | +300 |

### 2. Qualification Check

```
for each requirement:
    check open_holes >= min_holes
    check overall_rating >= min_rating
    check difficulty >= min_difficulty  (if > 0)
    check total_yardage >= min_yardage

# Also check:
    can_afford(entry_cost)
    no tournament already active
    days_since_last_tournament >= TOURNAMENT_COOLDOWN (7 days)
```

### 3. Scheduling

```
# Lead time
lead_days = 1 if tier == LOCAL else 3

tournament_start_day = current_day + lead_days
tournament_end_day   = start_day + duration_days - 1

# Pay entry cost immediately
money -= entry_cost
```

### 4. Tournament Execution

```
# On tournament start:
clear_all_regular_golfers()
total_groups = ceil(participant_count / 4.0)

# Groups spawn staggered (every 2 game-minutes)
GROUP_SPAWN_INTERVAL = 120.0 seconds (in game time)

# Each group is 50% PRO, 50% SERIOUS tier
for each golfer in group:
    tier = PRO if randf() > 0.5 else SERIOUS
    spawn_tournament_golfer(tier, group_id)
```

### 5. Score Tracking (Live Play)

```
# Per golfer:
tournament_scores[golfer_id] = {
    name: golfer_name,
    total_strokes: 0,
    total_par: 0,
    holes_completed: 0,
    is_finished: false,
    skill: average_of_4_skills,
}

# Updated each hole via golfer_finished_hole signal
# Sorted by score-to-par for leaderboard display
```

### 6. Score Simulation (End Day Fast-Forward)

When the player ends the day early, unfinished golfers have their remaining holes simulated:

```
# For each unfinished golfer:
ShotSimulator.simulate_remaining_holes(golfer_data, course_data, difficulty)

# For each unspawned group:
generate_skills(random PRO/SERIOUS tier)
simulate_entire_round_headlessly()
# Uses negative IDs (-1000, -1001...) for headless golfers
```

### 7. Results & Rewards

```
# Sort all entries by score-to-par (ascending)
all_entries.sort(by: total_strokes - total_par)

# Winner = first entry
winner = all_entries[0]

# Award revenue
total_revenue = spectator_revenue + sponsorship_revenue
money += total_revenue

# Award reputation (flat, not mood-based)
reputation += reputation_reward

# Record cooldown
last_tournament_end_day = current_day
```

### 8. Tournament Cooldown

```
TOURNAMENT_COOLDOWN = 7 days

can_schedule = (current_day - last_tournament_end_day) >= 7
days_remaining = max(0, 7 - (current_day - last_tournament_end_day))
```

### 9. Save/Load Handling

```
# Saved: tier, state, start_day, end_day, last_end_day
# NOT saved: active tournament golfers (too complex to serialize mid-round)

# On load: if tournament was IN_PROGRESS, revert to NONE
# (tournament golfers aren't persisted, so can't resume)
if loaded_state == IN_PROGRESS:
    state = NONE
    tier = -1
```

### Tuning Levers

| Parameter | Location | Current Value | Effect |
| --- | --- | --- | --- |
| Tournament cooldown | `tournament_manager.gd:18` | 7 days | Lower = more frequent tournaments |
| Group spawn interval | `tournament_manager.gd:29` | 120 game-seconds | Lower = faster group flow |
| Pro/Serious split | `tournament_manager.gd:180` | 50/50 | Adjust golfer quality mix |
| Lead time (local) | `tournament_manager.gd:127` | 1 day | Time to prepare |
| Lead time (other) | `tournament_manager.gd:127` | 3 days | Time to prepare |
| Entry costs | `tournament_system.gd:25-82` | $500–$50,000 | Higher = more risk |
| Revenue amounts | `tournament_system.gd:25-82` | $1,300–$140,000 | Higher = more reward |
| Rep rewards | `tournament_system.gd:25-82` | 15–300 | Higher = more incentive |
| Participant counts | `tournament_system.gd:25-82` | 12–72 | More = bigger event feel |
| Min rating/difficulty | `tournament_system.gd:25-82` | See table | Higher = harder to qualify |
