"""Crowding-aware journey planner on the bus network recovered from tickets (swap in GTFS when available).

Finds direct and one-change bus journeys between two places, estimates travel time from same-bus ticket pairs, and
scores every stretch of every leg with the crowding estimate for the hour the bus is expected to be there. Options
are ranked by
    cost = travel minutes + lambda * (minutes standing * 0.3 + minutes crowded * 1.0)
with lambda from the user's preference (fastest 0, balanced 0.6, comfortable 2.0). Stretches with too little data
count as 'standing' in the cost, so thin routes are never sold as empty.
"""
import difflib
import json
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd

from .data import HOURS, ROOT
from .pipeline import LEVELS

H0, H1 = HOURS[0], HOURS[-1]
LEVEL_PENALTY = np.array([0.0, 0.3, 1.0])
PREFERENCES = {'fastest': 0.0, 'balanced': 0.6, 'comfortable': 2.0}
WALK_SAME_STOP, WALK_NEARBY = 2, 5
CONF = ['low', 'medium', 'high']


def norm(s: str) -> str:
    return ''.join(ch for ch in s.lower() if ch.isalnum())


def hhmm(minutes: float) -> str:
    m = int(round(minutes)) % (24 * 60)
    return f'{m // 60:02d}:{m % 60:02d}'


def level_of(score: float) -> int:
    return int(np.digitize(score, [50, 80]))


@dataclass
class Leg:
    route: str
    i: int
    j: int
    walk_min: float = 0
    board_min: float = 0
    wait_min: float = 0
    ride_min: float = 0
    stretches: list = field(default_factory=list)


class Planner:
    def __init__(self, data_dir: Path = ROOT / 'outputs' / 'crowding'):
        data_dir = Path(data_dir)
        self.meta = json.loads((data_dir / 'meta.json').read_text())
        rs = pd.read_parquet(data_dir / 'route_stops.parquet').sort_values(['route', 'pos'])
        self.routes = pd.read_parquet(data_dir / 'routes.parquet').set_index('route')
        self.stops = pd.read_parquet(data_dir / 'stops.parquet').set_index('stop_key')
        self.seq = {r: g['stop_key'].tolist() for r, g in rs.groupby('route', sort=False)}
        self.names = dict(zip(rs['stop_key'], rs['stop_name']))
        self.place_of = self.stops['place_id'].to_dict()
        self.places = (self.stops.reset_index().sort_values('boardings_month', ascending=False)
                       .groupby('place_id').agg(name=('place_name', 'first'), members=('stop_key', list),
                                                aka=('name', list), boardings=('boardings_month', 'sum'),
                                                routes=('n_routes', 'max')))
        # place -> {route: [positions]}
        self.place_routes: dict[str, dict[str, list[int]]] = {}
        for r, s in self.seq.items():
            for p, k in enumerate(s):
                self.place_routes.setdefault(self.place_of[k], {}).setdefault(r, []).append(p)
        self.base = self.routes['route_base'].to_dict()
        self.tau = {r: g['tau_min'].to_numpy() for r, g in rs.groupby('route', sort=False)}
        sup = {r: g['support_next'].to_numpy()[:-1] for r, g in rs.groupby('route', sort=False)}
        # a stretch is usable when enough tickets actually ride across it (guards against misplaced stops)
        self.usable = {r: s_ >= max(10, 0.03 * np.median(s_)) for r, s_ in sup.items()}
        self.hour_factor = {int(h): f for h, f in self.meta['travel_time']['hour_factor'].items()}

        seg = pd.read_parquet(data_dir / 'segment_crowding.parquet',
                              columns=['route', 'day_type', 'hour', 'pos', 'eticket_riders', 'score', 'level', 'confidence'])
        seg = seg.sort_values(['route', 'day_type', 'hour', 'pos'])
        seg['conf'] = seg['confidence'].map({c: i for i, c in enumerate(CONF)}).astype('int8')
        self.grid = {}
        nh = len(HOURS)
        for (r, dt), g in seg.groupby(['route', 'day_type'], sort=False):
            n = len(self.seq[r]) - 1
            self.grid[(r, dt)] = {k: g[c].to_numpy().reshape(nh, n) for k, c in
                                  [('score', 'score'), ('level', 'level'), ('riders', 'eticket_riders'), ('conf', 'conf')]}
        self._place_names = self.places['name'].tolist()
        self._all_names = {norm(a): pid for pid, row in self.places.iterrows() for a in row['aka']}

    # ---------- lookups ----------
    def route_label(self, r: str) -> dict:
        m = self.routes.loc[r]
        return {'route': r, 'number': m['route_base'], 'direction': m['direction'], 'towards': m['last_stop'],
                'from_terminal': m['first_stop'], 'ac_share': float(m['ac_share']),
                'headway_min': float(m['headway_min_est'])}

    def _place_json(self, pid: str) -> dict:
        p = self.places.loc[pid]
        return {'key': pid, 'name': p['name'], 'also_called': [a for a in p['aka'] if a != p['name']][:4],
                'routes': int(len(self.place_routes.get(pid, {}))), 'boardings_month': int(p['boardings'])}

    def search_stops(self, q: str, limit: int = 10) -> list[dict]:
        nq = norm(q)
        if not nq:
            return [self._place_json(pid) for pid in self.places.nlargest(limit, 'boardings').index]
        hits = {}
        for a, pid in self._all_names.items():
            if nq in a:
                rank = (0 if a.startswith(nq) else 1, -self.places.at[pid, 'boardings'])
                hits[pid] = min(hits.get(pid, rank), rank)
        out = sorted(hits, key=hits.get)
        if len(out) < limit:
            for nm in difflib.get_close_matches(q.title(), self._place_names, n=limit, cutoff=0.6):
                for pid in self.places.index[self.places['name'] == nm]:
                    if pid not in out:
                        out.append(pid)
        return [self._place_json(pid) for pid in out[:limit]]

    def resolve(self, q: str) -> str | None:
        if q in self.places.index:
            return q
        if q in self.place_of:
            return self.place_of[q]
        hits = self.search_stops(q, 1)
        return hits[0]['key'] if hits else None

    # ---------- time model ----------
    def stretch_minutes(self, r: str, k: int, hour: int) -> float:
        tau = self.tau[r]
        return float(max(0.3, (tau[k + 1] - tau[k]) * self.hour_factor.get(hour, 1.0)))

    def wait(self, r: str) -> float:
        return float(np.clip(self.routes.at[r, 'headway_min_est'] / 2, 2, 15))

    @staticmethod
    def _hour_idx(minutes: float) -> int:
        return int(np.clip(int(minutes // 60), H0, H1)) - H0

    def evaluate_leg(self, leg: Leg, start_min: float, day: str) -> float:
        leg.wait_min = self.wait(leg.route)
        leg.board_min = start_min + leg.walk_min + leg.wait_min
        g = self.grid.get((leg.route, day))
        t = leg.board_min
        seq = self.seq[leg.route]
        leg.stretches = []
        for k in range(leg.i, leg.j):
            hi = self._hour_idx(t)
            mps = self.stretch_minutes(leg.route, k, hi + H0)
            if g is not None:
                sc, lv, rd, cf = float(g['score'][hi, k]), int(g['level'][hi, k]), float(g['riders'][hi, k]), int(g['conf'][hi, k])
            else:
                sc, lv, rd, cf = 0.0, 0, 0.0, 0
            leg.stretches.append({'from': self.names[seq[k]], 'to': self.names[seq[k + 1]], 'minutes': round(mps, 2),
                                  'score': round(sc, 1), 'level': lv, 'riders_eticket': round(rd, 2), 'confidence': CONF[cf]})
            t += mps
        leg.ride_min = t - leg.board_min
        return t

    # ---------- search ----------
    def ok(self, r: str, i: int, j: int) -> bool:
        return bool(self.usable[r][i:j].all())

    def candidates(self, f: str, t: str, max_one_change: int = 60) -> list[list[Leg]]:
        from_r = self.place_routes.get(f, {})
        to_r = self.place_routes.get(t, {})
        direct = []
        for r, starts in from_r.items():
            ends = to_r.get(r)
            if not ends:
                continue
            best = min(((j - i, i, j) for i in starts for j in ends if j > i and self.ok(r, i, j)), default=None)
            if best:
                direct.append([Leg(r, best[1], best[2])])
        dest_routes = set(to_r)
        best: dict[tuple, tuple] = {}
        for r1, starts in from_r.items():
            i1 = max(starts)
            seq1 = self.seq[r1]
            for x in range(i1 + 1, len(seq1)):
                if not self.usable[r1][x - 1]:
                    break
                px = self.place_of[seq1[x]]
                pr = self.place_routes.get(px, {})
                for r2 in dest_routes.intersection(pr):
                    if self.base[r2] == self.base[r1]:
                        continue
                    opts = [(j - i, i, j) for i in pr[r2] for j in to_r[r2] if j > i and self.ok(r2, i, j)]
                    if not opts:
                        continue
                    d2, i2, j2 = min(opts)
                    stops = (x - i1) + d2
                    if (r1, r2) not in best or stops < best[(r1, r2)][0]:
                        same = seq1[x] == self.seq[r2][i2]
                        best[(r1, r2)] = (stops, [Leg(r1, i1, x), Leg(r2, i2, j2, walk_min=WALK_SAME_STOP if same else WALK_NEARBY)])
        direct_min = min((lg[0].j - lg[0].i for lg in direct), default=10 ** 6)
        ones = sorted(best.values(), key=lambda v: v[0])
        ones = [legs for stops, legs in ones if stops <= direct_min * 1.6 + 8][:max_one_change]
        return direct + ones

    def summarize(self, legs: list[Leg], depart_min: float, day: str, lam: float) -> dict:
        t = depart_min
        for leg in legs:
            t = self.evaluate_leg(leg, t, day)
        stretches = [s for leg in legs for s in leg.stretches]
        mins = np.array([s['minutes'] for s in stretches])
        lv = np.array([s['level'] for s in stretches])
        sc = np.array([s['score'] for s in stretches])
        cf = np.array([CONF.index(s['confidence']) for s in stretches])
        ride = mins.sum()
        lv_cost = np.where(cf == 0, np.maximum(lv, 1), lv)      # too little data: assume standing room
        penalty = float((LEVEL_PENALTY[lv_cost] * mins).sum())
        mean_score = float((sc * mins).sum() / ride)
        low_share, high_share = mins[cf == 0].sum() / ride, mins[cf == 2].sum() / ride
        confidence = 'low' if low_share > 0.3 else ('high' if high_share >= 0.7 else 'medium')
        total = t - depart_min
        worst = max(stretches, key=lambda s: s['score'])
        return {'legs': legs, 'total_min': round(float(total)), 'ride_min': round(float(ride)),
                'wait_min': round(float(sum(l.wait_min for l in legs))), 'walk_min': round(float(sum(l.walk_min for l in legs))),
                'transfers': len(legs) - 1, 'crowded_min': round(float(mins[lv == 2].sum())),
                'standing_min': round(float(mins[lv == 1].sum())), 'mean_score': round(mean_score, 1),
                'level': level_of(mean_score), 'confidence': confidence, 'cost': float(total + lam * penalty),
                'busiest': worst, 'depart': hhmm(depart_min), 'arrive': hhmm(t)}

    def plan(self, f: str, t: str, day: str = 'Weekday', depart: str = '08:30', pref: str = 'balanced',
             limit: int = 5) -> dict:
        fk, tk = self.resolve(f), self.resolve(t)
        if fk is None or tk is None:
            return {'error': 'Stop not found', 'options': []}
        base = {'from': self._place_json(fk), 'to': self._place_json(tk), 'day': day, 'depart': depart, 'preference': pref}
        if fk == tk:
            return {**base, 'error': 'Start and destination are the same place', 'options': []}
        lam = PREFERENCES.get(pref, 0.6)
        hh, mm = (int(x) for x in depart.split(':'))
        dep = hh * 60 + mm
        opts = [self.summarize(legs, dep, day, lam) for legs in self.candidates(fk, tk)]
        if not opts:
            return {**base, 'options': [], 'error': 'No direct or one-change bus found between these places in the ticket data'}
        opts.sort(key=lambda o: o['cost'])
        fastest = min(opts, key=lambda o: (o['total_min'], o['cost']))
        calmest = min(opts, key=lambda o: (o['crowded_min'] + 0.3 * o['standing_min'] + (100 if o['confidence'] == 'low' else 0),
                                           o['total_min']))
        directs = [o for o in opts if o['transfers'] == 0]
        direct = directs[0] if directs else None
        chosen, seen = [], set()
        for o in [opts[0], fastest, calmest] + ([direct] if direct else []) + opts:
            sig = tuple(self.base[l.route] for l in o['legs'])
            if sig in seen:
                continue
            seen.add(sig)
            chosen.append(o)
            if len(chosen) >= limit:
                break
        out = []
        for o in chosen:
            tags = (['Best match'] if o is opts[0] else []) + (['Fastest'] if o is fastest else []) + \
                   (['Least crowded'] if o is calmest else []) + (['No change'] if o is direct else [])
            later = []
            for off in (15, 30):
                s2 = self.summarize([Leg(l.route, l.i, l.j, walk_min=l.walk_min) for l in o['legs']], dep + off, day, lam)
                later.append({'offset_min': off, 'depart': s2['depart'], 'arrive': s2['arrive'], 'total_min': s2['total_min'],
                              'level': s2['level'], 'label': LEVELS[s2['level']], 'crowded_min': s2['crowded_min'],
                              'mean_score': s2['mean_score']})
            better = [l for l in later if l['crowded_min'] <= o['crowded_min'] - 3 or l['level'] < o['level']]
            out.append(self._option_json(o, tags, later, better[0] if better else None))
        return {**base, 'options': out}

    def _option_json(self, o: dict, tags, later, tip) -> dict:
        legs = []
        for l in o['legs']:
            lv = np.array([s['level'] for s in l.stretches])
            mins = np.array([s['minutes'] for s in l.stretches])
            sc = np.array([s['score'] for s in l.stretches])
            cf = np.array([CONF.index(s['confidence']) for s in l.stretches])
            mean = float((sc * mins).sum() / mins.sum())
            conf = 'low' if mins[cf == 0].sum() / mins.sum() > 0.3 else ('high' if mins[cf == 2].sum() / mins.sum() >= 0.7 else 'medium')
            legs.append({**self.route_label(l.route), 'board_stop': self.names[self.seq[l.route][l.i]],
                         'alight_stop': self.names[self.seq[l.route][l.j]], 'walk_min': round(l.walk_min),
                         'board_time': hhmm(l.board_min), 'alight_time': hhmm(l.board_min + l.ride_min),
                         'wait_min': round(l.wait_min), 'ride_min': round(l.ride_min), 'stops': l.j - l.i,
                         'mean_score': round(mean, 1), 'level': level_of(mean), 'label': LEVELS[level_of(mean)],
                         'max_level': int(lv.max()), 'crowded_min': round(float(mins[lv == 2].sum())),
                         'confidence': conf, 'stretches': l.stretches})
        b = o['busiest']
        return {'tags': tags, 'total_min': o['total_min'], 'ride_min': o['ride_min'], 'wait_min': o['wait_min'],
                'walk_min': o['walk_min'], 'transfers': o['transfers'], 'depart': o['depart'], 'arrive': o['arrive'],
                'level': o['level'], 'label': LEVELS[o['level']], 'mean_score': o['mean_score'],
                'crowded_min': o['crowded_min'], 'standing_min': o['standing_min'], 'confidence': o['confidence'],
                'busiest_stretch': {'from': b['from'], 'to': b['to'], 'level': b['level'], 'label': LEVELS[b['level']]},
                'legs': legs, 'later': later,
                'tip': (f"Leave {tip['offset_min']} min later ({tip['depart']}): {tip['label'].lower()}, "
                        f"{tip['crowded_min']} min crowded instead of {o['crowded_min']}") if tip else None}

    # ---------- explore / operator views ----------
    def route_view(self, r: str, day: str = 'Weekday', hour: int = 9) -> dict:
        g = self.grid[(r, day)]
        hi = int(np.clip(hour, H0, H1)) - H0
        seq = self.seq[r]
        stretches = [{'from': self.names[seq[k]], 'to': self.names[seq[k + 1]], 'score': round(float(g['score'][hi, k]), 1),
                      'level': int(g['level'][hi, k]), 'riders_eticket': round(float(g['riders'][hi, k]), 2),
                      'confidence': CONF[int(g['conf'][hi, k])]} for k in range(len(seq) - 1)]
        w = g['riders'] + 1e-9
        by_hour = [{'hour': h, 'mean_score': round(float(np.average(g['score'][i], weights=w[i])), 1),
                    'max_score': round(float(g['score'][i].max()), 1), 'level': level_of(float(g['score'][i].max()))}
                   for i, h in enumerate(HOURS)]
        m = self.routes.loc[r]
        return {**self.route_label(r), 'day': day, 'hour': hour, 'n_stops': len(seq), 'stretches': stretches, 'by_hour': by_hour,
                'weekday_riders_per_day': float(m['weekday_riders_per_day']), 'fleet_weekday': float(m['fleet_weekday']),
                'end_to_end_min': float(m['end_to_end_min'])}

    def list_routes(self, q: str = '', limit: int = 50) -> list[dict]:
        r = self.routes
        if q:
            ql = q.lower()
            r = r[r.index.str.lower().str.contains(ql.replace(' ', ''), regex=False)
                  | r['last_stop'].str.lower().str.contains(ql, regex=False)
                  | r['first_stop'].str.lower().str.contains(ql, regex=False)]
        r = r.sort_values('weekday_riders_per_day', ascending=False).head(limit)
        return [{**self.route_label(k), 'n_stops': int(v['n_stops']), 'weekday_riders_per_day': float(v['weekday_riders_per_day'])}
                for k, v in r.iterrows()]

    def hotspots(self, day: str = 'Weekday', hour: int = 9, limit: int = 20) -> list[dict]:
        """Crowded stretches carrying the most riders at this hour (where an extra bus helps most people)."""
        hi = int(np.clip(hour, H0, H1)) - H0
        rows = []
        for (r, dt), g in self.grid.items():
            if dt != day:
                continue
            ok = (g['level'][hi] == 2) & (g['conf'][hi] > 0)
            if not ok.any():
                continue
            k = int(np.argmax(np.where(ok, g['riders'][hi], -1)))
            rows.append((float(g['riders'][hi, k]), float(g['score'][hi, k]), r, k, int(ok.sum())))
        rows.sort(reverse=True)
        out = []
        for rd, sc, r, k, n_crowded in rows[:limit]:
            seq = self.seq[r]
            out.append({**self.route_label(r), 'from': self.names[seq[k]], 'to': self.names[seq[k + 1]], 'score': round(sc, 1),
                        'level': 2, 'label': LEVELS[2], 'riders_eticket': round(rd, 1), 'crowded_stretches': n_crowded,
                        'n_stretches': len(seq) - 1})
        return out
