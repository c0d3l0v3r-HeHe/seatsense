"""Scoring crowding estimates against a held-out week."""
import numpy as np
import pandas as pd
from scipy.stats import spearmanr


def score(truth: np.ndarray, pred: np.ndarray, levels=None) -> dict:
    """WMAPE / MAE / correlation on per-day riders per stretch-hour, plus how well the busiest 10 % is found."""
    truth, pred = np.asarray(truth, float), np.asarray(pred, float)
    k = max(1, int(len(truth) * 0.10))
    top_t = set(np.argpartition(-truth, k - 1)[:k])
    top_p = set(np.argpartition(-pred, k - 1)[:k])
    out = {
        'WMAPE': np.abs(pred - truth).sum() / truth.sum(),
        'bias': pred.sum() / truth.sum() - 1,
        'MAE (riders/day)': np.abs(pred - truth).mean(),
        'Pearson r': np.corrcoef(truth, pred)[0, 1],
        'Spearman ρ': spearmanr(truth, pred).statistic,
        'busiest-10% found': len(top_t & top_p) / k,
    }
    if levels is not None:  # levels = (t1, t2) thresholds -> 0 seats / 1 standing / 2 crowded
        lt, lp = np.digitize(truth, levels), np.digitize(pred, levels)
        out['level agreement'] = (lt == lp).mean()
    return out


def score_table(df: pd.DataFrame, truth_col: str, pred_cols: dict, levels=None, by: str | None = None) -> pd.DataFrame:
    if by is None:
        return pd.DataFrame({name: score(df[truth_col], df[c], levels) for name, c in pred_cols.items()}).T
    rows = []
    for g, sub in df.groupby(by, observed=True):
        for name, c in pred_cols.items():
            rows.append({by: g, 'method': name, **score(sub[truth_col], sub[c], levels), 'cells': len(sub)})
    return pd.DataFrame(rows)
