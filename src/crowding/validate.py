"""Checks against known patterns + held-out-week accuracy. Writes outputs/validation.json and outputs/figures/*.png.

Run after the pipeline:  python -m crowding.validate
"""
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from .data import ROOT, load_tickets, loads_from_activity, stop_activity, window
from .evaluate import score
from .pipeline import DAY_TYPES, LEVELS, fleet_sizes
from .stops import attach_positions

OUT = ROOT / 'outputs'
FIG = OUT / 'figures'
# SeatSense palette (matches the deck and app): plum, orange, violet; lilac for a reference series.
# Checked: every pair >= 20 OKLab dE under normal, protan, deutan and tritan vision; >= 3:1 on white.
PLUM, ORANGE, VIOLET, LILAC, INK = '#4E3268', '#D9730B', '#8C84C6', '#A39DCB', '#54456F'
DAY_STYLE = {'Weekday': (PLUM, 'o'), 'Saturday': (ORANGE, 's'), 'Sunday': (VIOLET, '^')}
LEVEL_COLORS = ['#2F7D3A', '#F2B321', '#B93A3A']

plt.rcParams.update({
    'figure.dpi': 160, 'savefig.dpi': 160, 'figure.facecolor': 'white', 'axes.facecolor': 'white',
    'font.family': ['Roboto', 'DejaVu Sans'], 'axes.titlecolor': PLUM, 'text.color': INK, 'axes.axisbelow': True,
    'axes.edgecolor': '#C9C5E2', 'axes.grid': True, 'grid.color': '#E7E5F3', 'grid.linewidth': 0.7,
    'axes.spines.top': False, 'axes.spines.right': False, 'axes.titleweight': 'bold', 'axes.titlesize': 12,
    'axes.labelcolor': INK, 'xtick.color': INK, 'ytick.color': INK, 'font.size': 10, 'legend.frameon': False,
    'lines.linewidth': 2.2,
})


def _save(fig, name):
    FIG.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(FIG / name, bbox_inches='tight')
    plt.close(fig)


def run():
    crowd = OUT / 'crowding'
    seg = pd.read_parquet(crowd / 'segment_crowding.parquet')
    meta = json.loads((crowd / 'meta.json').read_text())
    route_stops = pd.read_parquet(crowd / 'route_stops.parquet')
    cuts = np.array(meta['level_cuts_load_index'])
    df = load_tickets()
    tp = attach_positions(df, route_stops)
    res = {}

    # 1 - Peaks: share of rider-trips in the 'Crowded' level, by hour and day type
    share = {}
    for dt in DAY_TYPES:
        s = seg[seg.day_type == dt]
        share[dt] = s.groupby('hour').apply(
            lambda g: float(np.average(g.level == 2, weights=g.eticket_riders + 1e-9)), include_groups=False)
    res['crowded_share_by_hour'] = {dt: {int(h): round(v, 3) for h, v in share[dt].items()} for dt in DAY_TYPES}
    fig, ax = plt.subplots(figsize=(10, 4))
    for dt in DAY_TYPES:
        c, m = DAY_STYLE[dt]
        ax.plot(share[dt].index, share[dt].values * 100, color=c, marker=m, ms=5, label=dt)
    ax.set_xticks(list(share['Weekday'].index)); ax.set_xlabel('hour of day')
    ax.set_ylabel('% of rider-trips rated "Crowded"'); ax.legend(loc='upper right')
    ax.set_title('Crowding peaks at 08–09 h and 18–19 h on weekdays, much less at weekends')
    _save(fig, 'crowded_share_by_hour.png')

    # 2 - Busiest stretches at the weekday peaks
    hot = {}
    for h in (9, 18):
        s = seg[(seg.day_type == 'Weekday') & (seg.hour == h) & (seg.confidence != 'low')]
        top = s.nlargest(10, 'load_index')[['route', 'from_stop', 'to_stop', 'eticket_riders', 'score', 'confidence']]
        hot[f'{h:02d}:00'] = top.round(1).to_dict('records')
    res['busiest_stretches_weekday'] = hot

    # 3 - Weekday vs weekend: mean score at the morning peak
    pk = seg[seg.hour.isin([8, 9])]
    res['mean_score_8_10h'] = {dt: round(float(np.average(g.score, weights=g.eticket_riders + 1e-9)), 1)
                               for dt, g in pk.groupby('day_type')}

    # 4 - Held-out week: learn 5-23 Oct weekdays, predict 26-30 Oct
    train_t, n_tr = window(tp, [41, 42, 43]); test_t, n_te = window(tp, [44])
    pred = loads_from_activity(stop_activity(train_t, route_stops, n_tr))
    truth = loads_from_activity(stop_activity(test_t, route_stops, n_te))
    m = truth.merge(pred, on=['route', 'route_base', 'pos', 'hour', 'n_stops'], suffixes=('_true', '_pred'))
    fl = fleet_sizes(df)
    fw = fl[fl.day_type == 'Weekday'].set_index('route_base')['fleet']
    f = m['route_base'].map(fw).fillna(2).clip(lower=2)
    sc = score(m['load_true'] / f, m['load_pred'] / f, levels=cuts)
    sc_riders = score(m['load_true'], m['load_pred'])
    res['holdout_week'] = {'train_days': n_tr, 'test_days': n_te, 'cells': int(len(m)),
                           'wmape_riders': round(sc_riders['WMAPE'], 3), 'bias': round(sc_riders['bias'], 3),
                           'busiest_10pct_found': round(sc['busiest-10% found'], 3),
                           'level_agreement': round(sc['level agreement'], 3), 'pearson_r': round(sc_riders['Pearson r'], 3)}

    # 5 - Week-to-week stability of the weekday pattern
    wk = []
    for w in [41, 42, 43, 44]:
        t, n = window(tp, [w])
        wk.append(loads_from_activity(stop_activity(t, route_stops, n)).set_index(['route', 'pos', 'hour'])['load'].rename(w))
    wk = pd.concat(wk, axis=1)
    corr = wk.corr().to_numpy()
    res['week_to_week_corr_min'] = round(float(corr[~np.eye(4, dtype=bool)].min()), 3)

    # 6 - Approach comparison (from notebooks/02 if it has been run)
    comp = OUT / 'approach_comparison.csv'
    if comp.exists():
        c = pd.read_csv(comp, index_col=[0, 1])
        res['approach_comparison'] = {f'{a} | {b}': {k: round(float(v), 3) for k, v in row.items()}
                                      for (a, b), row in c.iterrows()}
        fig, axes = plt.subplots(1, 2, figsize=(11, 3.8))
        kn = c.loc['known routes']
        ax = axes[0]
        bars = ax.bar(['A · direct counting', 'B · graph + ML'], kn['WMAPE'] * 100, color=[PLUM, ORANGE], width=0.55)
        ax.bar_label(bars, fmt='%.1f%%', padding=2, color=INK); ax.set_ylabel('error (WMAPE, %)')
        ax.set_title('Routes with tickets: error on unseen week'); ax.grid(axis='x', visible=False)
        un = c.loc['unseen routes'].iloc[:2]
        ax = axes[1]
        bars = ax.bar(['naive network\naverage', 'B · graph + ML\n(no route data)'], un['busiest-10% found'] * 100,
                      color=[LILAC, ORANGE], width=0.55)
        ax.bar_label(bars, fmt='%.0f%%', padding=2, color=INK); ax.set_ylabel('busiest 10 % found (%)')
        ax.set_title('Routes with no tickets: hotspots found'); ax.grid(axis='x', visible=False); ax.set_ylim(0, 100)
        _save(fig, 'approach_comparison.png')

    # 7 - Figures for the deck: daily totals, hourly boardings, a route profile
    daily = df.groupby(['date', 'day_type'])['passenger_count'].sum().reset_index()
    col = daily.day_type.map({'Weekday': PLUM, 'Saturday': ORANGE, 'Sunday': ORANGE, 'Holiday': LILAC})
    fig, ax = plt.subplots(figsize=(11, 3.6))
    ax.bar(daily.date, daily.passenger_count / 1e3, color=col.tolist(), width=0.75)
    ax.set_ylabel('thousand e-ticket riders'); ax.set_title('Riders per day, October 2026 (purple weekday · orange weekend · lilac holiday)')
    ax.grid(axis='x', visible=False)
    _save(fig, 'daily_riders.png')

    hourly = df[df.day_type.isin(DAY_TYPES)].groupby(['day_type', 'hour'])['passenger_count'].sum().unstack(0)
    hourly = hourly / df[df.day_type.isin(DAY_TYPES)].groupby('day_type')['date'].nunique()
    fig, ax = plt.subplots(figsize=(10, 3.8))
    for dt in DAY_TYPES:
        c, m = DAY_STYLE[dt]
        ax.plot(hourly.index, hourly[dt] / 1e3, color=c, label=dt, marker=m, ms=4)
    ax.set_xticks(range(0, 24, 2)); ax.set_xlabel('hour of day'); ax.set_ylabel('thousand boardings / hour')
    ax.set_title('Boardings by hour: weekday peaks at 09:00 and 18:00'); ax.legend()
    _save(fig, 'hourly_boardings.png')

    demo = df.route_base.value_counts().index[0]
    fig, axes = plt.subplots(1, 2, figsize=(13, 4), sharey=True)
    for ax, d in zip(axes, ['UP', 'DOWN']):
        s = seg[(seg.route == f'{demo}{d}') & (seg.day_type == 'Weekday')]
        for h, c, lab in [(9, PLUM, '09:00'), (13, VIOLET, '13:00'), (18, ORANGE, '18:00')]:
            p = s[s.hour == h].sort_values('pos')
            ax.plot(p.pos, p.score, color=c, label=lab)
        ax.axhspan(0, 50, color=LEVEL_COLORS[0], alpha=0.06); ax.axhspan(50, 80, color=LEVEL_COLORS[1], alpha=0.08)
        ax.axhspan(80, 100, color=LEVEL_COLORS[2], alpha=0.08)
        first, last = s.from_stop.iloc[0], s.to_stop.iloc[-1]
        ax.set_title(f'Route {demo} {d}: {first} → {last}', fontsize=11)
        ax.set_xlabel('stretch along the route'); ax.legend(loc='lower center', ncol=3)
    axes[0].set_ylabel('crowding score (0–100)')
    _save(fig, 'route_profile_demo.png')

    (OUT / 'validation.json').write_text(json.dumps(res, indent=2, default=str))
    print(json.dumps({k: v for k, v in res.items() if k not in ('busiest_stretches_weekday', 'crowded_share_by_hour', 'approach_comparison')}, indent=2))
    print('figures ->', FIG.relative_to(ROOT))
    return res


if __name__ == '__main__':
    run()
