"""The station graph: stops as nodes, consecutive stops on any route as directed edges."""
import networkx as nx
import numpy as np
import pandas as pd

NAME_FLAGS = {
    'metro': r'metro',
    'isbt': r'isbt',
    'terminal': r'terminal|depot|bus stand|\(t\)',
    'border': r'border',
    'village': r'village|gaon',
    'hospital': r'hospital|aiims|medical',
    'market': r'market|bazar|mandi|mall',
    'junction': r'crossing|chowk|xing|flyover|\bmor\b|\bmore\b',
    'education': r'college|university|school|institute|\biit\b',
    'airport': r'airport|\bigi\b',
}


def build_station_graph(route_stops: pd.DataFrame) -> nx.DiGraph:
    rs = route_stops.sort_values(['route', 'pos'])
    nxt = rs.groupby('route')['stop_key'].shift(-1)
    edges = rs.assign(nxt=nxt).dropna(subset=['nxt'])
    weights = edges.groupby(['stop_key', 'nxt'])['route'].nunique()
    G = nx.DiGraph()
    G.add_nodes_from(rs['stop_key'].unique())
    G.add_weighted_edges_from(((u, v, int(w)) for (u, v), w in weights.items()), weight='routes')
    return G


def stop_graph_features(G: nx.DiGraph, route_stops: pd.DataFrame, names: pd.Series) -> pd.DataFrame:
    """Per-stop structural features: degree, routes served, PageRank, betweenness, and name-based place type."""
    nodes = list(G.nodes)
    pr = nx.pagerank(G, weight='routes')
    bc = nx.betweenness_centrality(G, k=min(600, len(nodes)), seed=0)
    f = pd.DataFrame({'stop_key': nodes})
    f['in_deg'] = [G.in_degree(n) for n in nodes]
    f['out_deg'] = [G.out_degree(n) for n in nodes]
    f['n_routes'] = f['stop_key'].map(route_stops.groupby('stop_key')['route_base'].nunique())
    f['pagerank'] = f['stop_key'].map(pr) * len(nodes)
    f['betweenness'] = f['stop_key'].map(bc)
    lname = f['stop_key'].map(names).fillna('').str.lower()
    for k, pat in NAME_FLAGS.items():
        f[f'is_{k}'] = lname.str.contains(pat, regex=True).astype('int8')
    return f


def graph_summary(G: nx.DiGraph) -> pd.Series:
    und = G.to_undirected()
    comps = sorted((len(c) for c in nx.connected_components(und)), reverse=True)
    deg = np.array([d for _, d in und.degree()])
    return pd.Series({
        'stations (nodes)': G.number_of_nodes(),
        'links between consecutive stops (edges)': G.number_of_edges(),
        'connected pieces': len(comps),
        'stations in largest piece': comps[0],
        'share in largest piece': f'{comps[0] / G.number_of_nodes():.1%}',
        'median neighbours per station': float(np.median(deg)),
        'stations with 6+ neighbours (interchanges)': int((deg >= 6).sum()),
    })
