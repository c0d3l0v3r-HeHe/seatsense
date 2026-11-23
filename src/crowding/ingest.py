"""Raw ticket CSV (or the official .zip) -> typed, cleaned parquet."""
import zipfile
from pathlib import Path

import pandas as pd


def read_raw(path: Path) -> pd.DataFrame:
    """Read every column as text first so nothing is silently coerced."""
    path = Path(path)
    opts = dict(dtype=str, keep_default_na=False, na_filter=False)
    if path.suffix == '.zip':
        with zipfile.ZipFile(path) as z:
            name = next(n for n in z.namelist() if n.endswith('.csv') and not n.startswith('__MACOSX'))
            with z.open(name) as f:
                return pd.read_csv(f, **opts)
    return pd.read_csv(path, **opts)


def clean(raw: pd.DataFrame) -> pd.DataFrame:
    df = pd.DataFrame({
        'passenger_count': raw['passenger_count'].astype('int16'),
        'amount': raw['amount'].astype('float64'),
        'vehicle_number': raw['vehicle_number'].replace({'NULL': None, '': None}),
        'ticket_type_id': raw['ticket_type_id'].astype('int16'),
        'start_stop_name': raw['start_stop_name'].str.strip(),
        'end_stop_name': raw['end_stop_name'].str.strip(),
        'route': raw['route'].str.strip(),
        'created_at': pd.to_datetime(raw['created_at'], format='ISO8601').dt.tz_convert('Asia/Kolkata'),
        'is_ac': raw['is_ac'].eq('True'),
    })
    rt = df['route'].str.extract(r'^(?P<route_base>.*?)(?P<direction>UP|DOWN)?$')
    df['route_base'] = rt['route_base']
    df['direction'] = rt['direction'].fillna('NONE')
    df['fare_per_pax'] = df['amount'] / df['passenger_count'].clip(lower=1)
    df['date'] = df['created_at'].dt.tz_localize(None).dt.normalize()
    df['hour'] = df['created_at'].dt.hour.astype('int8')
    df['dow'] = df['created_at'].dt.dayofweek.astype('int8')
    df['veh_prefix'] = df['vehicle_number'].str[:6]
    return df


def csv_to_parquet(raw_path: Path, out_path: Path) -> Path:
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    clean(read_raw(raw_path)).to_parquet(out_path, index=False)
    return out_path
