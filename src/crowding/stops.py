"""Recover the stop sequence of every route-direction from ticket start->end votes (stand-in until GTFS arrives)."""
import numpy as np
import pandas as pd


def _order_one_route(M: np.ndarray) -> np.ndarray:
    """Copeland ranking from the pairwise vote matrix M[a, b] = riders going a -> b, then adjacent-swap polishing."""
    wins = (M > M.T).sum(1) - (M < M.T).sum(1)
    tiebreak = (M.sum(1) - M.sum(0)) / (M.sum(1) + M.sum(0) + 1)  # mostly-boarding stops come first
    order = list(np.lexsort((-tiebreak, -wins)))
    improved = True
    while improved:  # swap neighbours while that puts more riders "forward"
        improved = False
        for p in range(len(order) - 1):
            a, b = order[p], order[p + 1]
            if M[b, a] > M[a, b]:
                order[p], order[p + 1] = b, a
                improved = True
    return np.array(order)


def same_bus_pairs(df: pd.DataFrame, max_gap_min: float = 45) -> pd.DataFrame:
    """Consecutive tickets bought on the same bus and route: (route, earlier stop, later stop, minutes between)."""
    v = df.dropna(subset=['vehicle_number'])[['vehicle_number', 'route', 'ss_key', 'created_at']].sort_values(
        ['vehicle_number', 'created_at'])
    dt = v['created_at'].diff().dt.total_seconds() / 60
    ok = (v['vehicle_number'].eq(v['vehicle_number'].shift()) & v['route'].eq(v['route'].shift())
          & v['ss_key'].ne(v['ss_key'].shift()) & (dt > 0) & (dt <= max_gap_min))
    return pd.DataFrame({'route': v['route'][ok], 'a': v['ss_key'].shift()[ok], 'b': v['ss_key'][ok], 'dt': dt[ok]})


def _time_positions(pairs: pd.DataFrame, keep: pd.Index, min_obs: int = 1):
    """Least-squares minutes-along-route for each stop from same-bus time differences (largest linked group only)."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    from scipy.sparse.linalg import lsqr

    p = pairs[pairs['a'].isin(keep) & pairs['b'].isin(keep)]
    if len(p) < 30:
        return None
    a, b = keep.get_indexer(p['a']), keep.get_indexer(p['b'])
    lo, hi = np.minimum(a, b), np.maximum(a, b)
    signed = np.where(a == lo, p['dt'].to_numpy(), -p['dt'].to_numpy())     # minutes from stop lo to stop hi
    agg = pd.DataFrame({'lo': lo, 'hi': hi, 'd': signed}).groupby(['lo', 'hi'])['d'].agg(['median', 'size']).reset_index()
    obs = np.bincount(agg['lo'], weights=agg['size'], minlength=len(keep)) + np.bincount(agg['hi'], weights=agg['size'], minlength=len(keep))
    strong = obs >= min_obs                       # a stop needs several same-bus timings to be placed by time
    agg = agg[strong[agg['lo']] & strong[agg['hi']]]
    n = len(keep)
    g = coo_matrix((np.ones(len(agg)), (agg['lo'], agg['hi'])), shape=(n, n))
    _, lab = connected_components(g, directed=False)
    main = np.bincount(lab).argmax()
    members = np.flatnonzero(lab == main)
    members = members[strong[members]]
    if len(members) < max(5, 0.6 * n):
        return None
    sub = agg[np.isin(agg['lo'], members) & np.isin(agg['hi'], members)]
    idx = {m: k for k, m in enumerate(members)}
    rows = np.arange(len(sub))
    w = np.sqrt(sub['size'].to_numpy())
    data = np.concatenate([-w, w])
    cols = np.concatenate([sub['lo'].map(idx).to_numpy(), sub['hi'].map(idx).to_numpy()])
    A = coo_matrix((data, (np.concatenate([rows, rows]), cols)), shape=(len(sub), len(members))).tocsr()
    tau = lsqr(A, sub['median'].to_numpy() * w, damp=1e-3)[0]
    return pd.Series(tau - tau.min(), index=keep[members])


def infer_route_orders(df: pd.DataFrame, min_route_pax: int = 300, min_stop_count: int = 8,
                       min_stop_share: float = 0.002, min_stops: int = 5, use_time: bool = True) -> pd.DataFrame:
    """One row per (route, pos): stop key, minutes along the route (tau_min) and how the order was found.

    Primary method: minutes-along-route from same-bus ticket time differences (orders stops and gives travel times).
    Fallback (thin routes, or use_time=False): pairwise 'boarded at a -> going to b' votes with Copeland ranking.
    Stops seen fewer than max(min_stop_count, min_stop_share x route tickets) times are dropped as noise."""
    pairs_by_route = dict(tuple(same_bus_pairs(df).groupby('route', sort=False))) if use_time else {}
    rows = []
    cols = df[['route', 'route_base', 'ss_key', 'es_key', 'passenger_count']]
    for route, t in cols.groupby('route', sort=False):
        if t['passenger_count'].sum() < min_route_pax:
            continue
        cnt = pd.concat([t['ss_key'], t['es_key']]).value_counts()
        keep = pd.Index(cnt[cnt >= max(min_stop_count, min_stop_share * len(t))].index)
        if len(keep) < min_stops:
            continue
        i, j = keep.get_indexer(t['ss_key']), keep.get_indexer(t['es_key'])
        ok = (i >= 0) & (j >= 0) & (i != j)
        M = np.zeros((len(keep), len(keep)))
        np.add.at(M, (i[ok], j[ok]), t['passenger_count'].to_numpy()[ok])
        method, tau = 'votes', None
        tp = _time_positions(pairs_by_route[route], keep) if route in pairs_by_route else None
        if tp is not None:
            sel = keep.get_indexer(tp.index)
            Ms = M[np.ix_(sel, sel)]
            order_t = np.argsort(tp.to_numpy(), kind='stable')
            Mo = Ms[np.ix_(order_t, order_t)]
            cons_t = np.triu(Mo, 1).sum() / max(Mo.sum(), 1)
            if cons_t >= 0.8:
                method = 'time'
                order = sel[order_t]
                tau = tp.to_numpy()[order_t]
        if method == 'votes':
            order = _order_one_route(M)
        Mo = M[np.ix_(order, order)]
        consistency = np.triu(Mo, 1).sum() / max(Mo.sum(), 1)
        if len(order) < min_stops:
            continue
        base = t['route_base'].iat[0]
        taus = tau if tau is not None else np.full(len(order), np.nan)
        rows += [(route, base, p, keep[k], len(order), consistency, method, taus[p]) for p, k in enumerate(order)]
    return pd.DataFrame(rows, columns=['route', 'route_base', 'pos', 'stop_key', 'n_stops', 'order_consistency',
                                       'order_method', 'tau_min'])


def stop_display_names(df: pd.DataFrame) -> pd.Series:
    """Most common raw spelling for each normalised stop key."""
    pairs = pd.concat([df[['ss_key', 'start_stop_name']].set_axis(['stop_key', 'name'], axis=1),
                       df[['es_key', 'end_stop_name']].set_axis(['stop_key', 'name'], axis=1)])
    vc = pairs.value_counts().reset_index()
    return vc.drop_duplicates('stop_key').set_index('stop_key')['name']


def attach_positions(t: pd.DataFrame, route_stops: pd.DataFrame) -> pd.DataFrame:
    """Add i_on / i_off (stop positions) and keep tickets whose boarding stop comes before their alighting stop."""
    rs = route_stops[['route', 'stop_key', 'pos', 'n_stops']]
    t = t.merge(rs.rename(columns={'stop_key': 'ss_key', 'pos': 'i_on'}), on=['route', 'ss_key'], how='inner')
    t = t.merge(rs[['route', 'stop_key', 'pos']].rename(columns={'stop_key': 'es_key', 'pos': 'i_off'}),
                on=['route', 'es_key'], how='inner')
    return t[t['i_on'] < t['i_off']].reset_index(drop=True)


GENERIC_PARTS = {'metrostation', 'mainroad', 'busstand', 'village', 'crossing', 'terminal', 'depot', 'market', 'chowk',
                 'extension', 'colony', 'block', 'sector', 'phase', 'gate', 'school', 'hospital', 'isbt', 'road', 'stand',
                 'more', 'xing', 'flyover', 'nh8', 'busterminal', 'policestation', 'postoffice', 'temple', 'mandir',
                 'park', 'enclave', 'nagar', 'vihar', 'puri', 'metro', 'station', 'bustop', 'busstop', 'ring', 'ringroad'}


def place_clusters(names: pd.Series, popularity: pd.Series, min_len: int = 6, sim: float = 0.92) -> pd.DataFrame:
    """Group stop-name variants of the same place ('Saket Metro Station' / 'Saket Metro Sation / Said-Ul-Ajaib').

    Names are split on '/' and brackets; two stops join a place when they share a distinctive part, or when two parts
    are near-identical spellings (difflib ratio >= sim). Generic parts ('Metro Station', 'Village') never link."""
    import difflib
    import re

    keys = names.index.tolist()
    parent = {k: k for k in keys}

    def find(k):
        while parent[k] != k:
            parent[k] = parent[parent[k]]
            k = parent[k]
        return k

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    road = re.compile(r'(road|marg|nh\d*|highway|flyover|bypass)$')
    digits = lambda x: re.sub(r'[^0-9]', '', x)
    owner = {}
    for k, nm in names.items():
        raw_parts = [p.strip() for p in re.split(r'[/()]', str(nm)) if p.strip()]
        parts = set()
        for rp in raw_parts:
            p = re.sub(r'[^a-z0-9]+', '', rp.lower())
            if len(p) < min_len or p in GENERIC_PARTS or road.search(p) or p[0].isdigit():
                continue
            parts.add(p)
            parts.add('~' + ''.join(sorted(re.findall(r'[a-z0-9]+', rp.lower()))))   # word-order variants
        parts.add(k)
        for p in parts:
            if p in owner:
                union(owner[p], k)
            else:
                owner[p] = k
    # near-identical spellings of the whole name (typos), never across different numbers ('Sec 1' vs 'Sec 13')
    by_prefix = {}
    for k in keys:
        by_prefix.setdefault(k[:5], []).append(k)
    for group in by_prefix.values():
        group.sort()
        for i, a in enumerate(group):
            for b in group[i + 1:]:
                if (abs(len(a) - len(b)) <= 2 and digits(a) == digits(b)
                        and difflib.SequenceMatcher(None, a, b).ratio() >= sim):
                    union(a, b)
    out = pd.DataFrame({'stop_key': keys})
    out['place_id'] = out['stop_key'].map(find)
    out['popularity'] = out['stop_key'].map(popularity).fillna(0)
    out['stop_name'] = out['stop_key'].map(names)
    lead = out.sort_values('popularity', ascending=False).drop_duplicates('place_id').set_index('place_id')['stop_name']
    out['place_name'] = out['place_id'].map(lead)
    out['place_size'] = out.groupby('place_id')['stop_key'].transform('size')
    return out[['stop_key', 'stop_name', 'place_id', 'place_name', 'place_size']]
