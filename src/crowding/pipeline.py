"""End-to-end crowding pipeline: raw tickets -> crowding estimates by route, direction, stretch, day type and hour.

Run:  python -m crowding.pipeline [--raw October-Delhi.csv.zip] [--out outputs/crowding]

Method (approach A, chosen after testing against the graph + ML alternative, see notebooks/02):
  1. Recover each route-direction's stop order from ticket votes (boarding stop comes before alighting stop).
  2. Count every rider on each stretch between their boarding and planned alighting stop, in the hour they boarded;
     average per day for Weekday / Saturday / Sunday (holidays excluded).
  3. Divide by the number of buses seen on that route that day (from vehicle numbers) -> riders per bus index.
  4. Turn the index into a rider-weighted percentile score (0-100) and three levels a commuter understands.
  5. Attach a confidence flag from the number of tickets behind each estimate; smooth thin cells over +-1 hour.
"""
import argparse
import json
import time
from pathlib import Path

import numpy as np
import pandas as pd

from .data import HOURS, ROOT, PARQUET, load_tickets, loads_from_activity, stop_activity
from .ingest import csv_to_parquet
from .stops import attach_positions, infer_route_orders, place_clusters, same_bus_pairs, stop_display_names

DAY_TYPES = ['Weekday', 'Saturday', 'Sunday']
LEVELS = ['Seats likely', 'Standing room', 'Crowded']
LEVEL_CUTS = (0.50, 0.80)        # rider-weighted: lowest 50 % of rider-trips = seats, top 20 % = crowded
CONF_CUTS = (10, 30)             # tickets behind a stretch-hour over the month: <10 low, 10-29 medium, >=30 high
MIN_PER_STOP = {'peak': 2.6, 'offpeak': 2.0}   # ASSUMPTION until GTFS stop_times / GPS are connected
PEAK_HOURS = {7, 8, 9, 10, 17, 18, 19, 20}
LAYOVER_MIN = 10


def weighted_quantiles(values: np.ndarray, weights: np.ndarray, qs) -> np.ndarray:
    order = np.argsort(values)
    v, w = values[order], weights[order]
    cw = np.cumsum(w) / w.sum()
    return np.interp(qs, cw, v)


def fleet_sizes(df: pd.DataFrame) -> pd.DataFrame:
    """Average number of distinct buses seen per route per day, by day type (from tickets that carry a vehicle number)."""
    v = df.dropna(subset=['vehicle_number'])
    per_day = v.groupby(['route_base', 'day_type', 'date'])['vehicle_number'].nunique()
    f = per_day.groupby(['route_base', 'day_type']).mean().rename('fleet').reset_index()
    return f


def build(df: pd.DataFrame, route_stops: pd.DataFrame, names: pd.Series):
    tp = attach_positions(df, route_stops)
    parts = []
    for dt in DAY_TYPES:
        t = tp[tp['day_type'] == dt]
        seg = loads_from_activity(stop_activity(t, route_stops, int(t['date'].nunique())))
        seg['day_type'] = dt
        parts.append(seg)
    seg = pd.concat(parts, ignore_index=True).rename(columns={'load': 'eticket_riders', 'n_tix': 'n_tickets'})

    # Smooth thin cells: average the stretch over the neighbouring hours (+-1 h) when fewer than CONF_CUTS[0] tickets.
    seg = seg.sort_values(['route', 'day_type', 'pos', 'hour'], ignore_index=True)   # full hour grid per stretch
    first_h, last_h = seg['hour'] == HOURS[0], seg['hour'] == HOURS[-1]
    r, n = seg['eticket_riders'], seg['n_tickets']
    prev_r, next_r = r.shift(1).mask(first_h), r.shift(-1).mask(last_h)
    roll_r = pd.concat([prev_r, r, next_r], axis=1).mean(axis=1)
    roll_n = pd.concat([n.shift(1).mask(first_h), n, n.shift(-1).mask(last_h)], axis=1).sum(axis=1)
    thin = seg['n_tickets'] < CONF_CUTS[0]
    seg.loc[thin, 'eticket_riders'] = roll_r[thin]
    seg['smoothed'] = thin
    seg['n_tickets_used'] = np.where(thin, roll_n, seg['n_tickets'])

    fleet = fleet_sizes(df)
    seg = seg.merge(fleet, on=['route_base', 'day_type'], how='left')
    wk = fleet[fleet.day_type == 'Weekday'].set_index('route_base')['fleet']
    seg['fleet'] = seg['fleet'].fillna(seg['route_base'].map(wk)).fillna(2).clip(lower=2)
    seg['load_index'] = seg['eticket_riders'] / seg['fleet']

    # Score = rider-weighted percentile of the index among weekday stretch-hours; levels from fixed cut points.
    ref = seg[(seg.day_type == 'Weekday') & (seg.eticket_riders > 0)]
    v, w = ref['load_index'].to_numpy(), ref['eticket_riders'].to_numpy()
    order = np.argsort(v)
    cdf_v, cdf_p = v[order], np.cumsum(w[order]) / w.sum()
    seg['score'] = (np.interp(seg['load_index'], cdf_v, cdf_p, left=0, right=1) * 100).round(1)
    cuts = weighted_quantiles(v, w, LEVEL_CUTS)
    seg['level'] = np.digitize(seg['load_index'], cuts).astype('int8')
    seg['confidence'] = pd.cut(seg['n_tickets_used'], [-1, CONF_CUTS[0] - 1e-9, CONF_CUTS[1] - 1e-9, np.inf],
                               labels=['low', 'medium', 'high']).astype(str)

    rs = route_stops.assign(stop_name=route_stops['stop_key'].map(names))
    nxt = rs[['route', 'pos', 'stop_key', 'stop_name']].assign(pos=lambda d: d['pos'] - 1)
    seg = (seg.merge(rs[['route', 'pos', 'stop_key', 'stop_name']].rename(columns={'stop_key': 'from_key', 'stop_name': 'from_stop'}),
                     on=['route', 'pos'])
              .merge(nxt.rename(columns={'stop_key': 'to_key', 'stop_name': 'to_stop'}), on=['route', 'pos']))
    seg['direction'] = seg['route'].str.extract(r'(UP|DOWN)$')[0].fillna('')
    cols = ['route', 'route_base', 'direction', 'day_type', 'hour', 'pos', 'from_key', 'from_stop', 'to_key', 'to_stop',
            'eticket_riders', 'n_tickets', 'n_tickets_used', 'smoothed', 'fleet', 'load_index', 'score', 'level', 'confidence']
    seg = seg[cols].sort_values(['route', 'day_type', 'hour', 'pos'], ignore_index=True)
    return seg, tp, fleet, cuts


def travel_times(df: pd.DataFrame, route_stops: pd.DataFrame):
    """Minutes along each route (tau) and a time-of-day factor, from consecutive tickets bought on the same bus.

    Routes ordered by time already carry tau from the least-squares fit (stops.infer_route_orders). Routes ordered by
    votes get tau = position x their median minutes per stop step. The peak / off-peak factor compares observed
    minutes between two stops with the route's typical minutes between them."""
    pairs = same_bus_pairs(df)
    pairs['hour'] = df.loc[pairs.index, 'hour'].to_numpy()
    rs = route_stops.copy()
    pos = rs.set_index(['route', 'stop_key'])['pos']
    a = pos.reindex(pd.MultiIndex.from_arrays([pairs['route'], pairs['a']])).to_numpy()
    b = pos.reindex(pd.MultiIndex.from_arrays([pairs['route'], pairs['b']])).to_numpy()
    step = pd.DataFrame({'route': pairs['route'].to_numpy(), 'dp': b - a, 'dt': pairs['dt'].to_numpy()})
    step = step[(step['dp'] > 0) & (step['dt'] / step['dp']).between(0.3, 8)]
    mps_route = (step['dt'] / step['dp']).groupby(step['route']).median()
    mps_global = float((step['dt'] / step['dp']).median())
    no_tau = rs['tau_min'].isna()
    rs.loc[no_tau, 'tau_min'] = rs.loc[no_tau, 'pos'] * rs.loc[no_tau, 'route'].map(mps_route).fillna(mps_global)
    # make tau strictly increasing (at least 0.3 min per step)
    rs = rs.sort_values(['route', 'pos'])
    inc = rs.groupby('route')['tau_min'].diff().fillna(0).clip(lower=0.3)
    inc[rs['pos'] == 0] = 0
    rs['tau_min'] = inc.groupby(rs['route']).cumsum().round(2)
    rs = rs.reset_index(drop=True)

    tau = rs.set_index(['route', 'stop_key'])['tau_min']
    ta = tau.reindex(pd.MultiIndex.from_arrays([pairs['route'], pairs['a']])).to_numpy()
    tb = tau.reindex(pd.MultiIndex.from_arrays([pairs['route'], pairs['b']])).to_numpy()
    expected = tb - ta
    ratio = pd.Series(pairs['dt'].to_numpy() / expected)[expected >= 3]
    hours = pd.Series(pairs['hour'].to_numpy())[expected >= 3]
    by_hour = ratio.clip(0.2, 5).groupby(hours).median()
    by_hour = (by_hour / by_hour.median()).clip(0.8, 1.4).round(3)
    factors = {int(h): float(by_hour.get(h, 1.0)) for h in HOURS}
    info = {'same_bus_ticket_pairs': int(len(pairs)), 'median_min_per_stop_step': round(mps_global, 2),
            'hour_factor': factors}
    return rs, info


def route_table(route_stops: pd.DataFrame, names: pd.Series, fleet: pd.DataFrame, df: pd.DataFrame) -> pd.DataFrame:
    r = route_stops.groupby('route').agg(route_base=('route_base', 'first'), n_stops=('n_stops', 'first'),
                                         order_consistency=('order_consistency', 'first'),
                                         order_method=('order_method', 'first'), end_to_end_min=('tau_min', 'max'))
    first = route_stops[route_stops.pos == 0].set_index('route')['stop_key'].map(names)
    last = route_stops[route_stops.pos == route_stops.n_stops - 1].set_index('route')['stop_key'].map(names)
    r['first_stop'], r['last_stop'] = first, last
    r['direction'] = r.index.str.extract(r'(UP|DOWN)$')[0].fillna('').to_numpy()
    r['ac_share'] = df.groupby('route')['is_ac'].mean().reindex(r.index).round(2)
    r['weekday_riders_per_day'] = (df[df.day_type == 'Weekday'].groupby('route')['passenger_count'].sum()
                                   / df.loc[df.day_type == 'Weekday', 'date'].nunique()).reindex(r.index).round(1)
    fw = fleet[fleet.day_type == 'Weekday'].set_index('route_base')['fleet']
    r['fleet_weekday'] = r['route_base'].map(fw).fillna(2).clip(lower=2).round(1)
    r['end_to_end_min'] = r['end_to_end_min'].round(0)
    # Headway estimate: round trip (both directions + layovers) / buses in service.
    rtt = r.groupby('route_base')['end_to_end_min'].transform('sum') + 2 * LAYOVER_MIN
    r['headway_min_est'] = (rtt / r['fleet_weekday']).clip(4, 60).round(0)
    return r.reset_index()


def run(raw: Path | None = None, out: Path = ROOT / 'outputs' / 'crowding') -> dict:
    t0 = time.time()
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    if raw is not None or not PARQUET.exists():
        raw = Path(raw) if raw else next(p for p in [ROOT / 'data' / 'raw' / 'October-Delhi.csv', ROOT / 'October-Delhi.csv.zip'] if p.exists())
        csv_to_parquet(raw, PARQUET)
        print(f'[{time.time() - t0:5.1f}s] ingested {raw.name} -> {PARQUET.relative_to(ROOT)}')
    df = load_tickets()
    route_stops = infer_route_orders(df)
    names = stop_display_names(df)
    route_stops, tt = travel_times(df, route_stops)
    n_time = route_stops.loc[route_stops.order_method == 'time', 'route'].nunique()
    print(f'[{time.time() - t0:5.1f}s] stop order recovered for {route_stops.route.nunique():,} route-directions '
          f'({n_time:,} from same-bus timing); travel times from {tt["same_bus_ticket_pairs"]:,} ticket pairs')
    seg, tp, fleet, cuts = build(df, route_stops, names)
    # Evidence for each stretch: tickets (all days) riding across stop pos -> pos+1. The planner skips stretches
    # with almost none, which guards against stops misplaced by mis-tagged tickets.
    ev = np.zeros(len(route_stops))
    route_stops = route_stops.sort_values(['route', 'pos']).reset_index(drop=True)
    first_row = route_stops.index[route_stops['pos'] == 0]
    off = dict(zip(route_stops.loc[first_row, 'route'], first_row))
    on_idx = tp['route'].map(off).to_numpy() + tp['i_on'].to_numpy()
    off_idx = tp['route'].map(off).to_numpy() + tp['i_off'].to_numpy()
    np.add.at(ev, on_idx, 1); np.add.at(ev, off_idx, -1)
    route_stops = route_stops.assign(_d=ev)
    route_stops['support_next'] = route_stops.groupby('route')['_d'].cumsum().clip(lower=0).astype(int)
    route_stops = route_stops.drop(columns='_d')
    routes = route_table(route_stops, names, fleet, df)
    print(f'[{time.time() - t0:5.1f}s] {len(seg):,} stretch-hour estimates')

    stops = (route_stops.groupby('stop_key').agg(n_routes=('route_base', 'nunique')).reset_index())
    stops['name'] = stops['stop_key'].map(names)
    stops['boardings_month'] = stops['stop_key'].map(tp.groupby('ss_key')['passenger_count'].sum()).fillna(0).astype(int)
    places = place_clusters(stops.set_index('stop_key')['name'], stops.set_index('stop_key')['boardings_month'])
    stops = stops.merge(places[['stop_key', 'place_id', 'place_name', 'place_size']], on='stop_key')

    seg.to_parquet(out / 'segment_crowding.parquet', index=False)
    seg.to_csv(out / 'segment_crowding.csv.gz', index=False)
    route_stops.assign(stop_name=route_stops.stop_key.map(names)).to_parquet(out / 'route_stops.parquet', index=False)
    routes.to_parquet(out / 'routes.parquet', index=False)
    routes.to_csv(out / 'routes.csv', index=False)
    stops.to_parquet(out / 'stops.parquet', index=False)
    meta = {
        'generated_at': pd.Timestamp.now(tz='Asia/Kolkata').isoformat(timespec='seconds'),
        'data': {'tickets': int(len(df)), 'passengers': int(df.passenger_count.sum()),
                 'first_day': str(df.date.min().date()), 'last_day': str(df.date.max().date()),
                 'tickets_used': int(len(tp)), 'route_directions': int(route_stops.route.nunique()),
                 'stops': int(len(stops))},
        'levels': LEVELS, 'level_cuts_load_index': [round(float(c), 4) for c in cuts],
        'level_cuts_rider_share': list(LEVEL_CUTS), 'confidence_cuts_tickets': list(CONF_CUTS),
        'hours': HOURS, 'day_types': DAY_TYPES,
        'travel_time': tt,
        'order_method_counts': route_stops.groupby('route')['order_method'].first().value_counts().to_dict(),
        'places': int(stops.place_id.nunique()),
        'assumptions': {'fallback_min_per_stop': MIN_PER_STOP, 'peak_hours': sorted(PEAK_HOURS), 'layover_min': LAYOVER_MIN},
    }
    (out / 'meta.json').write_text(json.dumps(meta, indent=2))
    print(f'[{time.time() - t0:5.1f}s] wrote {out.relative_to(ROOT)}/')
    return meta


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--raw', type=Path, default=None, help='raw CSV or .zip (default: reuse data/processed parquet)')
    ap.add_argument('--out', type=Path, default=ROOT / 'outputs' / 'crowding')
    a = ap.parse_args()
    run(a.raw, a.out)
