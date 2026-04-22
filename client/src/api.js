const BASE = '/api';

async function get(path) {
  const res = await fetch(BASE + path);
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `HTTP ${res.status}`);
  }
  return res.json();
}

function qs(params) {
  const p = Object.entries(params).filter(([, v]) => v != null && v !== '');
  return p.length ? '?' + new URLSearchParams(p).toString() : '';
}

export const api = {
  standings: (tournamentId, seasonId) =>
    get('/standings' + qs({ tournamentId, seasonId })),

  teams: (seasonId) =>
    get('/teams' + qs({ seasonId })),

  teamPlayers: (id, opts = {}) =>
    get(`/teams/${id}/players` + qs(opts)),

  teamMatches: (id, opts = {}) =>
    get(`/teams/${id}/matches` + qs(opts)),

  teamCoaches: (id, opts = {}) =>
    get(`/teams/${id}/coaches` + qs(opts)),

  teamStats: (id, seasonId) =>
    get(`/teams/${id}/stats` + qs({ seasonId })),

  playerCard: (id) =>
    get(`/players/${id}/card`),

  playerStats: (id, seasonId) =>
    get(`/players/${id}/stats` + qs({ seasonId })),

  topPlayers: (seasonId, statField = 'Points', topN = 20) =>
    get('/players/top' + qs({ seasonId, statField, topN })),

  penalizedPlayers: (seasonId, topN = 20) =>
    get('/players/penalized' + qs({ seasonId, topN })),

  transfers: (opts = {}) =>
    get('/transfers' + qs(opts)),

  matchReport: (id) =>
    get(`/matches/${id}/report`),

  matchParticipants: (id) =>
    get(`/matches/${id}/participants`),

  highScoringMatches: (opts = {}) =>
    get('/matches/high-scoring' + qs(opts)),

  seasonReport: (id) =>
    get(`/reports/season/${id}`),
};
