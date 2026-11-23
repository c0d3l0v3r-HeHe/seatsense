# SeatSense — Phase 1 proposal

**Transport Stack Hackathon 2026 · Problem 2: Crowdedness-aware journey planner**
**Team:** _[team name]_ · _[members]_

## The problem

A Delhi commuter choosing a bus sees travel time and changes, never how full the bus will be. Yet a packed bus is slow
to board, hard to stand in, and often skipped. Operators, for their part, lack a simple view of which stretches and
hours are overloaded.

## What we built

**SeatSense** turns one month of e-tickets into a crowding estimate for every route, direction, stretch and hour, and
puts it next to each journey option.

- **For commuters (app):** pick from/to, day and time, and a preference — *fastest*, *balanced* or *a seat*. Each
  option shows total time, a crowding level (Seats likely / Standing room / Crowded, always icon + words + colour), how
  many minutes are crowded, the worst stretch, a confidence flag, and a tip such as *"Leave 15 min later: standing
  room, 18 min crowded instead of 25."*
- **For operators (Hotspots, Routes):** crowded stretches ranked by riders carried, and an hour-by-hour profile of
  any route.
- **For anyone (open data):** a rerunnable pipeline and queryable tables (Parquet/CSV) plus an HTTP API.

## Why it is sound

- **Grounded in the tickets.** Each estimate is a count of riders whose trip covers that stretch at that hour —
  nothing is invented. The network itself (stop order, travel time) is recovered from tickets bought on the same bus.
- **Checked on an unseen week.** Learning from 5–23 Oct and predicting 26–30 Oct gives the same crowding level on 92 %
  of stretch-hours (correlation 0.96). Peaks at 08–09 h and 18 h, lighter weekends and commute directions that flip
  between morning and evening all come out of the data.
- **Honest about limits.** E-tickets are a small share of riders, so levels are relative and every estimate carries a
  confidence flag; thin data is never shown as an empty bus.
- **Tested against an alternative.** A station-graph + machine-learning model was built and scored the same way; it
  did not beat direct counting on routes with data, so we kept the simpler, more explainable method and reserved the
  model for routes without tickets.

## Prototype

- Pipeline + validation (Python): `python -m crowding.pipeline`, `python -m crowding.validate`
- API (FastAPI) and Flutter app (web, desktop; Android/iOS from the same code)
- Notebooks: data exploration; counting vs graph + ML comparison
- Technical note: method, assumptions, where estimates are least reliable

## Phase 2 plan

| Week | Work |
|---|---|
| 1 | Connect GTFS (stop IDs, coordinates, schedules): map view, exact headways, routes without tickets via the graph model |
| 1 | Use the GPS feed for observed travel times and per-trip loads |
| 2 | Scale to all riders (route ridership / ETM totals) and bus capacity by type; operator dashboard of overloaded hours |
| 2 | User test with 10 commuters; polish the crowding display; package as an open-source Transport Stack component |
