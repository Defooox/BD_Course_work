import { api } from '../api.js';
import { render, loading, errorMsg, table, fmtDate } from '../ui.js';

export async function standingsPage() {
  loading();
  try {
    const rows = await api.standings();

    // группируем по турниру
    const byTournament = {};
    for (const r of rows) {
      const key = r.TournamentID;
      if (!byTournament[key]) {
        byTournament[key] = { name: r.TournamentName, season: r.SeasonName, rows: [] };
      }
      byTournament[key].rows.push(r);
    }

    const cols = [
      { label: '#',     key: 'TablePosition', cls: 'center' },
      { label: 'Команда', key: (r) => `<a href="#/teams/${r.TeamID}" class="link">${r.TeamName}</a>` },
      { label: 'И',     key: 'GamesPlayed', cls: 'center' },
      { label: 'В',     key: 'Wins',        cls: 'center' },
      { label: 'П',     key: 'Losses',      cls: 'center' },
      { label: 'ОТ',    key: 'OTLosses',    cls: 'center' },
      { label: 'О',     key: 'Points',      cls: 'center bold' },
      { label: 'ГЗ',    key: 'GoalsFor',    cls: 'center' },
      { label: 'ГП',    key: 'GoalsAgainst',cls: 'center' },
      { label: '+/-',   key: (r) => {
        const d = r.GoalDiff;
        return `<span class="${d > 0 ? 'pos' : d < 0 ? 'neg' : ''}">${d > 0 ? '+' : ''}${d}</span>`;
      }, cls: 'center' },
    ];

    const sections = Object.values(byTournament).map(({ name, season, rows: tRows }) => `
      <section class="card">
        <h2 class="card-title">${name}</h2>
        <p class="subtitle">${season}</p>
        ${table(cols, tRows)}
      </section>
    `).join('');

    render(`
      <div class="page-header">
        <h1>Турнирная таблица</h1>
      </div>
      ${sections || '<p class="empty">Данных нет. Укажите параметры.</p>'}
    `);
  } catch (e) {
    errorMsg(e);
  }
}
