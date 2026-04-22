import { api } from '../api.js';
import { render, loading, errorMsg, table, fmt, fmtDate } from '../ui.js';

export async function seasonReportPage(id) {
  loading();
  try {
    const data = await api.seasonReport(Number(id));
    const { meta, standings, topScorers, topPenalized, highScoringMatches } = data;

    const standingsCols = [
      { label: '#',   key: 'TablePosition', cls: 'center' },
      { label: 'Команда', key: (r) => `<a href="#/teams/${r.TeamID}" class="link">${r.TeamName}</a>` },
      { label: 'И',   key: 'GamesPlayed', cls: 'center' },
      { label: 'В',   key: 'Wins',        cls: 'center' },
      { label: 'П',   key: 'Losses',      cls: 'center' },
      { label: 'О',   key: 'Points',      cls: 'center bold' },
      { label: 'ГЗ',  key: 'GoalsFor',    cls: 'center' },
      { label: 'ГП',  key: 'GoalsAgainst',cls: 'center' },
    ];

    const scorersCols = [
      { label: '#',       key: (_, i) => i + 1, cls: 'center' },
      { label: 'Игрок',   key: (r) => `<a href="#/players/${r.PlayerID}" class="link">${r.FullName}</a>` },
      { label: 'Позиция', key: 'Position' },
      { label: 'Команда', key: 'TeamName' },
      { label: 'И',  key: 'GamesPlayed', cls: 'center' },
      { label: 'Г',  key: 'Goals',   cls: 'center' },
      { label: 'П',  key: 'Assists', cls: 'center' },
      { label: 'О',  key: 'Points',  cls: 'center bold' },
    ];

    const penCols = [
      { label: '#',       key: (_, i) => i + 1, cls: 'center' },
      { label: 'Игрок',   key: (r) => `<a href="#/players/${r.PlayerID}" class="link">${r.FullName}</a>` },
      { label: 'Команда', key: 'TeamName' },
      { label: 'ШВ', key: 'PenaltyMinutes', cls: 'center bold' },
      { label: 'Г',  key: 'Goals',   cls: 'center' },
      { label: 'О',  key: 'Points',  cls: 'center' },
    ];

    const matchCols = [
      { label: 'Дата',   key: (r) => fmtDate(r.MatchDate) },
      { label: 'Турнир', key: 'TournamentName' },
      { label: 'Хозяева', key: 'HomeTeam' },
      { label: 'Счёт',   key: (r) => `<b>${r.HomeScore} : ${r.AwayScore}</b>`, cls: 'center' },
      { label: 'Гости',  key: 'AwayTeam' },
      { label: 'Голов',  key: 'TotalGoals', cls: 'center bold' },
    ];

    render(`
      <div class="page-header">
        <h1>Отчёт сезона${meta ? ': ' + meta.Name : ''}</h1>
      </div>

      ${meta ? `
        <div class="stat-tiles">
          <div class="tile"><div class="tile-val">${fmt(meta.PlayedMatches)}</div><div class="tile-lbl">Сыграно матчей</div></div>
          <div class="tile"><div class="tile-val">${fmt(meta.TotalGoals)}</div><div class="tile-lbl">Всего голов</div></div>
          <div class="tile"><div class="tile-val">${meta.AvgGoalsPerMatch ? Number(meta.AvgGoalsPerMatch).toFixed(2) : '—'}</div><div class="tile-lbl">Голов за матч</div></div>
          <div class="tile"><div class="tile-val">${meta.TotalAttendance ? Number(meta.TotalAttendance).toLocaleString('ru-RU') : '—'}</div><div class="tile-lbl">Зрителей всего</div></div>
        </div>
      ` : ''}

      <section class="card">
        <h2 class="card-title">Турнирная таблица</h2>
        ${table(standingsCols, standings)}
      </section>

      <div class="two-col">
        <section class="card">
          <h2 class="card-title">Лучшие бомбардиры</h2>
          ${table(scorersCols, topScorers)}
        </section>

        <section class="card">
          <h2 class="card-title">Лидеры по штрафам</h2>
          ${table(penCols, topPenalized)}
        </section>
      </div>

      <section class="card">
        <h2 class="card-title">Самые результативные матчи</h2>
        ${table(matchCols, highScoringMatches)}
      </section>
    `);
  } catch (e) {
    errorMsg(e);
  }
}
