"""Loading tickets and the shared (route, stop, hour) grid helpers."""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
PARQUET = ROOT / 'data' / 'processed' / 'tickets_oct2026.parquet'
HOLIDAYS = pd.to_datetime(['2026-10-02', '2026-10-20'])
HOURS = list(range(5, 23))  # modelled service hours, 05:00-22:59 (99.5 % of boardings)


def stop_key(s: pd.Series) -> pd.Series:
    """Normalise a stop name so spacing/punctuation variants collapse ('Badarpur Border(T)' == 'Badarpur Border (T)')."""
    return s.str.lower().str.replace(r'[^a-z0-9]+', '', regex=True)


def load_tickets(path: Path = PARQUET) -> pd.DataFrame:
    cols = ['passenger_count', 'vehicle_number', 'start_stop_name', 'end_stop_name', 'route', 'route_base',
            'created_at', 'is_ac', 'fare_per_pax', 'date', 'hour', 'dow']
    df = pd.read_parquet(path, columns=cols)
    df['day_type'] = np.select([df['date'].isin(HOLIDAYS), df['dow'] == 6, df['dow'] == 5],
                               ['Holiday', 'Sunday', 'Saturday'], 'Weekday')
    df['week'] = df['created_at'].dt.isocalendar().week.astype('int16')
    df['ss_key'] = stop_key(df['start_stop_name'])
    df['es_key'] = stop_key(df['end_stop_name'])
    return df


def window(t: pd.DataFrame, weeks, day_type: str = 'Weekday'):
    """Tickets for the given ISO weeks and day type, plus the number of distinct days (for per-day averages)."""
    w = t[t['week'].isin(list(weeks)) & (t['day_type'] == day_type)]
    return w, int(w['date'].nunique())


def route_grid(route_stops: pd.DataFrame, hours=HOURS) -> pd.DataFrame:
    """Every (route, stop position, hour) cell for the ordered routes."""
    g = route_stops[['route', 'route_base', 'pos', 'stop_key', 'n_stops']]
    return g.merge(pd.DataFrame({'hour': list(hours)}), how='cross')


def stop_activity(t: pd.DataFrame, route_stops: pd.DataFrame, n_days: int, hours=HOURS) -> pd.DataFrame:
    """Boardings and alightings per day at every (route, pos, hour). Hour = the passenger's boarding hour.

    `t` must already carry i_on / i_off positions (see stops.attach_positions)."""
    t = t[t['hour'].isin(list(hours))]
    on = (t.groupby(['route', 'i_on', 'hour'])['passenger_count'].agg(board='sum', n_board='size')
            .rename_axis(['route', 'pos', 'hour']))
    off = (t.groupby(['route', 'i_off', 'hour'])['passenger_count'].agg(alight='sum', n_alight='size')
             .rename_axis(['route', 'pos', 'hour']))
    g = route_grid(route_stops, hours).set_index(['route', 'pos', 'hour']).join(on).join(off)
    g[['board', 'n_board', 'alight', 'n_alight']] = g[['board', 'n_board', 'alight', 'n_alight']].fillna(0)
    g['board'] /= max(n_days, 1)
    g['alight'] /= max(n_days, 1)
    return g.reset_index().sort_values(['route', 'hour', 'pos'], ignore_index=True)


def loads_from_activity(act: pd.DataFrame, board: str = 'board', alight: str = 'alight') -> pd.DataFrame:
    """Running count along the route: riders on board leaving stop `pos` (= on stretch pos -> pos+1)."""
    act = act.sort_values(['route', 'hour', 'pos'], ignore_index=True)
    keys = [act['route'], act['hour']]
    out = act[['route', 'route_base', 'pos', 'hour', 'n_stops']].copy()
    out['load'] = (act[board] - act[alight]).groupby(keys).cumsum().clip(lower=0)
    if 'n_board' in act:
        out['n_tix'] = (act['n_board'] - act['n_alight']).groupby(keys).cumsum().clip(lower=0)
    return out[out['pos'] < out['n_stops'] - 1].reset_index(drop=True)
