"""Approach A - direct counting.

Every ticket says 'boarded at stop i, getting off at stop j'. Count the rider on every stretch i..j-1 in the hour they
boarded, sum over all tickets in the window and divide by the number of days. No model: the estimate for a stretch and
hour is simply the average observed in the past weeks."""
import pandas as pd

from .data import loads_from_activity, stop_activity


def estimate(train_t: pd.DataFrame, route_stops: pd.DataFrame, n_days: int) -> pd.DataFrame:
    """Per-day e-ticket riders on board for every (route, stretch pos -> pos+1, hour), plus the ticket count behind it."""
    act = stop_activity(train_t, route_stops, n_days)
    return loads_from_activity(act).rename(columns={'load': 'load_A', 'n_tix': 'n_tix_A'})
