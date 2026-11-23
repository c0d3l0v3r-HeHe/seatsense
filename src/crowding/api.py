"""HTTP API for the crowding-aware journey planner (and static host for the Flutter web app).

Run:  python -m crowding.api            -> http://localhost:8000  (docs at /docs)
"""
import json
import os
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from .data import ROOT
from .pipeline import DAY_TYPES, LEVELS
from .planner import PREFERENCES, Planner

DATA = Path(os.environ.get('CROWDING_DATA', ROOT / 'outputs' / 'crowding'))
WEB = Path(os.environ.get('CROWDING_WEB', ROOT / 'app' / 'build' / 'web'))

app = FastAPI(title='SeatSense API', version='1.0',
              description='Crowding estimates for Delhi buses from October 2026 e-ticket data, and a journey planner that shows them.')
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_methods=['GET'], allow_headers=['*'])
planner = Planner(DATA)
validation = json.loads((ROOT / 'outputs' / 'validation.json').read_text()) if (ROOT / 'outputs' / 'validation.json').exists() else {}


def _day(day: str) -> str:
    d = day.capitalize()
    if d not in DAY_TYPES:
        raise HTTPException(400, f'day must be one of {DAY_TYPES}')
    return d


@app.get('/api/health')
def health():
    return {'ok': True}


@app.get('/api/meta')
def meta():
    m = planner.meta
    hv = validation.get('holdout_week', {})
    return {'data': m['data'], 'levels': LEVELS, 'day_types': DAY_TYPES, 'hours': m['hours'],
            'preferences': list(PREFERENCES), 'travel_time': {k: v for k, v in m['travel_time'].items() if k != 'hour_factor'},
            'places': m.get('places'), 'validation': {'holdout_week': hv, 'week_to_week_corr_min': validation.get('week_to_week_corr_min'),
                                                      'mean_score_8_10h': validation.get('mean_score_8_10h')},
            'generated_at': m['generated_at']}


@app.get('/api/stops')
def stops(q: str = '', limit: int = Query(10, le=50)):
    return planner.search_stops(q, limit)


@app.get('/api/plan')
def plan(from_: str = Query(..., alias='from'), to: str = Query(...), day: str = 'Weekday',
         time: str = Query('08:30', pattern=r'^\d{1,2}:\d{2}$'), pref: str = 'balanced', limit: int = Query(5, le=8)):
    if pref not in PREFERENCES:
        raise HTTPException(400, f'pref must be one of {list(PREFERENCES)}')
    return planner.plan(from_, to, _day(day), time, pref, limit)


@app.get('/api/routes')
def routes(q: str = '', limit: int = Query(30, le=200)):
    return planner.list_routes(q, limit)


@app.get('/api/route/{route}')
def route(route: str, day: str = 'Weekday', hour: int = Query(9, ge=0, le=23)):
    if route not in planner.seq:
        raise HTTPException(404, 'unknown route')
    return planner.route_view(route, _day(day), hour)


@app.get('/api/hotspots')
def hotspots(day: str = 'Weekday', hour: int = Query(9, ge=0, le=23), limit: int = Query(20, le=100)):
    return planner.hotspots(_day(day), hour, limit)


@app.get('/api/validation')
def get_validation():
    return validation


if WEB.exists():
    app.mount('/assets', StaticFiles(directory=WEB / 'assets'), name='assets')

    @app.get('/{path:path}', include_in_schema=False)
    def web(path: str):
        f = WEB / path
        if path and f.is_file() and WEB in f.resolve().parents:
            return FileResponse(f)
        return FileResponse(WEB / 'index.html')


if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host=os.environ.get('HOST', '0.0.0.0'), port=int(os.environ.get('PORT', 8000)))
