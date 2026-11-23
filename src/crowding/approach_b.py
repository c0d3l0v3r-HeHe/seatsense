"""Approach B - station graph + ML + origin-destination rebuild.

1. Features for every (route, stop, hour): position on the route, the stop's place in the station graph (degree,
   routes served, PageRank, betweenness, place type from its name), demand seen at the same station on *other* routes
   (the graph lets busy stations share information), and - for routes we already have data on - their own history.
2. Two LightGBM models (Poisson loss) predict boardings and alightings per day at each stop and hour.
3. A gravity model balanced with iterative proportional fitting (IPF) turns the two predicted columns into an
   origin-destination table (who rides from i to j, only j after i), then the running count gives riders on board.
"""
import lightgbm as lgb
import numpy as np
import pandas as pd

from .data import stop_activity

GRAPH_FEATURES = ['in_deg', 'out_deg', 'n_routes', 'pagerank', 'betweenness', 'is_metro', 'is_isbt', 'is_terminal',
                  'is_border', 'is_village', 'is_hospital', 'is_market', 'is_junction', 'is_education', 'is_airport']
STRUCT_FEATURES = ['pos', 'n_stops', 'rel_pos', 'to_end', 'hour', 'route_ac']
NETWORK_FEATURES = ['net_b_h', 'net_a_h', 'net_b_all', 'net_a_all', 'net_b_share_h', 'net_a_share_h']
HISTORY_FEATURES = ['hist_b_h', 'hist_a_h', 'hist_b_sr', 'hist_a_sr', 'hist_route_h', 'hist_route']
FEATURES_COLD = STRUCT_FEATURES + GRAPH_FEATURES + NETWORK_FEATURES       # a route with no tickets yet
FEATURES_WARM = FEATURES_COLD + HISTORY_FEATURES                          # a route with past tickets

LGB_PARAMS = dict(objective='poisson', learning_rate=0.05, num_leaves=63, min_child_samples=40, subsample=0.8,
                  subsample_freq=1, colsample_bytree=0.8, reg_lambda=1.0, n_estimators=1500, verbose=-1, n_jobs=-1)


def build_features(feat_t: pd.DataFrame, n_days: int, route_stops: pd.DataFrame, stop_feats: pd.DataFrame,
                   route_ac: pd.Series) -> pd.DataFrame:
    """One row per (route, pos, hour) with all candidate features, computed from the tickets in `feat_t`."""
    act = stop_activity(feat_t, route_stops, n_days)
    X = act[['route', 'route_base', 'pos', 'hour', 'stop_key', 'n_stops']].copy()
    X['rel_pos'] = X['pos'] / (X['n_stops'] - 1)
    X['to_end'] = X['n_stops'] - 1 - X['pos']
    X['route_ac'] = X['route'].map(route_ac).astype(float)

    # Demand at the same station on other routes (leave the whole route, both directions, out).
    by_sh = act.groupby(['stop_key', 'hour'])[['board', 'alight']].transform('sum')
    by_s = act.groupby('stop_key')[['board', 'alight']].transform('sum')
    own_sh = act.groupby(['route_base', 'stop_key', 'hour'])[['board', 'alight']].transform('sum')
    own_s = act.groupby(['route_base', 'stop_key'])[['board', 'alight']].transform('sum')
    X['net_b_h'] = (by_sh['board'] - own_sh['board']).clip(lower=0)
    X['net_a_h'] = (by_sh['alight'] - own_sh['alight']).clip(lower=0)
    X['net_b_all'] = (by_s['board'] - own_s['board']).clip(lower=0)
    X['net_a_all'] = (by_s['alight'] - own_s['alight']).clip(lower=0)
    X['net_b_share_h'] = X['net_b_h'] / X['net_b_all'].replace(0, np.nan)
    X['net_a_share_h'] = X['net_a_h'] / X['net_a_all'].replace(0, np.nan)

    # This route's own history (only usable when the route already has tickets).
    X['hist_b_h'] = act['board']
    X['hist_a_h'] = act['alight']
    X['hist_b_sr'] = act.groupby(['route', 'pos'])['board'].transform('sum')
    X['hist_a_sr'] = act.groupby(['route', 'pos'])['alight'].transform('sum')
    X['hist_route_h'] = act.groupby(['route', 'hour'])['board'].transform('sum')
    X['hist_route'] = act.groupby('route')['board'].transform('sum')

    return X.merge(stop_feats, on='stop_key', how='left')


def _fit_one(X: pd.DataFrame, y: pd.Series, features, seed: int) -> lgb.LGBMRegressor:
    routes = X['route_base'].unique()
    rng = np.random.default_rng(seed)
    val_routes = set(rng.choice(routes, size=max(1, len(routes) // 10), replace=False))
    is_val = X['route_base'].isin(val_routes).to_numpy()
    m = lgb.LGBMRegressor(**LGB_PARAMS, random_state=seed)
    m.fit(X.loc[~is_val, features], y[~is_val], eval_X=X.loc[is_val, features], eval_y=y[is_val],
          callbacks=[lgb.early_stopping(60, verbose=False)])
    return m


def fit(X_train: pd.DataFrame, target_act: pd.DataFrame, features, seed: int = 0):
    """Train the boardings and alightings models. `target_act` = stop_activity of the target window."""
    y = X_train[['route', 'pos', 'hour']].merge(target_act[['route', 'pos', 'hour', 'board', 'alight']],
                                                on=['route', 'pos', 'hour'], how='left').fillna(0)
    return {'board': _fit_one(X_train, y['board'], features, seed),
            'alight': _fit_one(X_train, y['alight'], features, seed + 1),
            'features': list(features)}


def crossfit_training_set(t: pd.DataFrame, route_stops: pd.DataFrame, stop_feats: pd.DataFrame,
                          route_ac: pd.Series, n_folds: int = 3, seed: int = 0) -> pd.DataFrame:
    """Training rows built by splitting the window's days into folds: features from the other days, targets from
    the held-out days. Every day serves as a target once, so no single odd week biases the model."""
    days = np.array(sorted(t['date'].unique()))
    np.random.default_rng(seed).shuffle(days)
    parts = []
    for k, tdays in enumerate(np.array_split(days, n_folds)):
        is_t = t['date'].isin(tdays)
        feat_t, targ_t = t[~is_t], t[is_t]
        X = build_features(feat_t, int(feat_t['date'].nunique()), route_stops, stop_feats, route_ac)
        act = stop_activity(targ_t, route_stops, len(tdays))
        X = X.merge(act[['route', 'pos', 'hour', 'board', 'alight']].rename(columns={'board': 'y_board', 'alight': 'y_alight'}),
                    on=['route', 'pos', 'hour'], how='left')
        X['fold'] = k
        parts.append(X)
    return pd.concat(parts, ignore_index=True)


def fit_crossfit(train: pd.DataFrame, features, seed: int = 0):
    """Train on the stacked cross-fit rows from crossfit_training_set."""
    return {'board': _fit_one(train, train['y_board'], features, seed),
            'alight': _fit_one(train, train['y_alight'], features, seed + 1),
            'features': list(features)}


def predict_activity(models, X: pd.DataFrame) -> pd.DataFrame:
    out = X[['route', 'route_base', 'pos', 'hour', 'n_stops']].copy()
    out['board_pred'] = np.clip(models['board'].predict(X[models['features']]), 0, None)
    out['alight_pred'] = np.clip(models['alight'].predict(X[models['features']]), 0, None)
    out.loc[out['pos'] == out['n_stops'] - 1, 'board_pred'] = 0.0   # nobody boards at the last stop
    out.loc[out['pos'] == 0, 'alight_pred'] = 0.0                   # nobody alights at the first stop
    return out


def trip_length_prior(t: pd.DataFrame, max_n: int):
    """P(ride d stops | route has n stops), from observed tickets, by route-length band, lightly smoothed."""
    bands = [0, 15, 25, 40, 60, 10_000]
    d = (t['i_off'] - t['i_on']).to_numpy()
    band = np.digitize(t['n_stops'].to_numpy(), bands) - 1
    w = t['passenger_count'].to_numpy()
    table = {}
    for b in range(len(bands) - 1):
        h = np.bincount(d[band == b], weights=w[band == b], minlength=max_n + 1).astype(float)[:max_n + 1]
        h[0] = 0
        h[1:] += 0.5 + 0.01 * h.sum() / max_n
        table[b] = h

    def prior(n: int) -> np.ndarray:
        h = table[int(np.digitize(n, bands) - 1)][:n].copy()
        return h / h.sum()
    return prior


def rebuild_loads(act_pred: pd.DataFrame, prior, iters: int = 40) -> pd.DataFrame:
    """Doubly-constrained gravity model per (route, hour): T[i, j] proportional to prior(j - i), rows match predicted
    boardings, columns match predicted alightings (rescaled to the same total). Returns riders on board per stretch."""
    out = []
    for route, g in act_pred.groupby('route', sort=False):
        n = int(g['n_stops'].iat[0])
        hours = np.sort(g['hour'].unique())
        B = g.pivot(index='hour', columns='pos', values='board_pred').reindex(index=hours, columns=range(n)).fillna(0).to_numpy()
        A = g.pivot(index='hour', columns='pos', values='alight_pred').reindex(index=hours, columns=range(n)).fillna(0).to_numpy()
        f = prior(n)
        D = np.arange(n)[None, :] - np.arange(n)[:, None]
        S = np.where(D > 0, f[np.clip(D, 0, n - 1)], 0.0)
        A = A + 1e-4 * (np.arange(n) > 0)                   # tiny floor keeps every downstream stop reachable
        A = A * (B.sum(1, keepdims=True) / A.sum(1, keepdims=True))
        rs = S.sum(1)
        T = B[:, :, None] * np.divide(S, rs[:, None], out=np.zeros_like(S), where=rs[:, None] > 0)[None]
        for _ in range(iters):
            col = T.sum(1)
            T *= np.divide(A, col, out=np.zeros_like(A), where=col > 0)[:, None, :]
            row = T.sum(2)
            T *= np.divide(B, row, out=np.zeros_like(B), where=row > 0)[:, :, None]
        load = np.cumsum(T.sum(2) - T.sum(1), axis=1)[:, :n - 1]
        out.append(pd.DataFrame({'route': route, 'hour': np.repeat(hours, n - 1),
                                 'pos': np.tile(np.arange(n - 1), len(hours)), 'load_B': load.ravel()}))
    return pd.concat(out, ignore_index=True)


def feature_importance(models) -> pd.DataFrame:
    imp = pd.DataFrame({k: pd.Series(models[k].booster_.feature_importance('gain'), index=models['features'])
                        for k in ('board', 'alight')})
    return (imp / imp.sum()).sort_values('board', ascending=False)
