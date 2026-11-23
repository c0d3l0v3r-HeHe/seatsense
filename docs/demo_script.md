# 3-minute demo script

Start: `scripts/run_api.sh`, open http://localhost:8000 (phone-size browser window or `flutter run -d linux`).

1. **The problem (15 s).** "Planners show time, not how packed the bus is. We estimate crowding from 2.56 M October e-tickets."
2. **Plan a peak trip (60 s).** Tap the example *Badarpur → Saket, 8:30*.
   - The direct **717A** (*No change*, 35 min) is **Crowded** for 25 of its minutes (worst: Asian Market → Saket Crossing).
   - The *Best match* (bus 34 then 717A, 39 min) has seats likely almost all the way: 4 extra minutes for a seat.
   - Tip on the direct bus: *Leave 30 min later (09:00)* → standing room, 17 min crowded instead of 25.
   - Switch preference to **A seat** and search again: the ranking changes (34 + 717E, 42 min, no crowded stretch).
3. **Open an option (20 s).** Leg by leg, every stretch coloured; confidence flag; "if you leave later" table.
4. **Routes tab (30 s).** 717A: busiest stretch by hour — tap 9:00 (red) vs 13:00 (green) vs 18:00. "This is the brief's
   peak/off-peak check, straight from the data."
5. **Hotspots tab (30 s).** Weekday 9:00: Asian Market → Saket Crossing tops the list; slide to 18:00: the reverse
   direction. "Where an extra bus helps most people."
6. **How it works (15 s).** Count riders on each stretch; network rebuilt from same-bus ticket timing; 92 % level
   agreement on an unseen week; honest limits.

Deep links if you need to jump: `/?from=Badarpur%20Border%20(T)&to=Saket%20Metro%20Station&time=08:30`,
`/?tab=routes`, `/?tab=hotspots`, `/?tab=about`.
