import { api } from '../api.js';
import { render, loading, errorMsg, table, fmt, fmtDate, fmtMoney } from '../ui.js';

export async function teamDetailPage(id) {
  loading();
  const teamId = Number(id);

  try {
    const [playersData, coachesData, matchesData, statsData] = await Promise.all([
      api.teamPlayers(teamId),
      api.teamCoaches(teamId),
      api.teamMatches(teamId),
      api.teamStats(teamId),
    ]);

    const players = Array.isArray(playersData) ? playersData : [];
    const coaches = Array.isArray(coachesData) ? coachesData : [];
    const matches = Array.isArray(matchesData) ? matchesData : [];
    const stats   = statsData.stats || [];
    const topScorers = statsData.topScorers || [];

    const teamName = players[0]?.TeamName || matches[0]?.HomeTeam || `Команда #${id}`;

    const playerCols = [
      { label: '№',     key: 'JerseyNumber', cls: 'center' },
      { label: 'Имя',   key: (r) => `<a href="#/players/${r.PlayerID}" class="link">${r.FullName}</a>` },
      { label: 'Позиция', key: 'Position' },
      { label: 'Возраст', key: 'Age', cls: 'center' },
      { label: 'Гражданство', key: 'Citizenship' },
      { label: 'Зарплата', key: (r) => fmtMoney(r.Salary) },
      { label: 'Контракт до', key: (r) => fmtDate(r.ContractEnd) },
    ];

    const coachCols = [
      { label: 'Имя',   key: 'FullName' },
      { label: 'Роль',  key: 'Role' },
      { label: 'Сезон', key: 'Season' },
      { label: 'Возраст', key: 'Age', cls: 'center' },
    ];

    const matchCols = [
      { label: 'Дата',  key: (r) => fmtDate(r.MatchDate) },
      { label: 'Турнир', key: 'TournamentName' },
      { label: 'Хозяева', key: 'HomeTeam' },
      { label: 'Счёт', key: (r) => `<b>${r.HomeScore} : ${r.AwayScore}</b>`, cls: 'center' },
      { label: 'Гости', key: 'AwayTeam' },
      { label: 'Итог',  key: (r) => {
        const map = { 'Победа': 'win', 'Поражение': 'loss', 'Ничья': 'draw' };
        return `<span class="badge badge-${map[r.Result] || ''}">${r.Result}</span>`;
      }},
      { label: '',      key: (r) => `<a href="#/matches/${r.MatchID}" class="link">→</a>`, cls: 'center' },
    ];

    const statCols = [
      { label: 'Сезон',    key: 'SeasonName' },
      { label: 'Турнир',   key: 'Tournament' },
      { label: 'И',  key: 'GamesPlayed', cls: 'center' },
      { label: 'В',  key: 'Wins',        cls: 'center' },
      { label: 'П',  key: 'Losses',      cls: 'center' },
      { label: 'ОТ', key: 'OTLosses',    cls: 'center' },
      { label: 'О',  key: 'Points',      cls: 'center bold' },
      { label: 'ГЗ', key: 'GoalsFor',    cls: 'center' },
      { label: 'ГП', key: 'GoalsAgainst',cls: 'center' },
      { label: 'Win%', key: (r) => r.WinPct != null ? r.WinPct.toFixed(1) + '%' : '—', cls: 'center' },
    ];

    const topScorersCols = [
      { label: 'Игрок',   key: (r) => `<a href="#/players/${r.PlayerID}" class="link">${r.FullName}</a>` },
      { label: 'Позиция', key: 'Position' },
      { label: 'И',  key: 'GamesPlayed', cls: 'center' },
      { label: 'Г',  key: 'Goals',   cls: 'center' },
      { label: 'П',  key: 'Assists', cls: 'center' },
      { label: 'О',  key: 'Points',  cls: 'center bold' },
    ];

    render(`
      <div class="page-header">
        <a href="#/teams" class="back-link">← Все команды</a>
        <h1>${teamName}</h1>
      </div>

      <section class="card">
        <h2 class="card-title">Состав (${players.length} игроков)</h2>
        ${table(playerCols, players)}
      </section>

      <section class="card">
        <h2 class="card-title">Тренерский штаб</h2>
        ${table(coachCols, coaches)}
      </section>

      <section class="card">
        <h2 class="card-title">Статистика по сезонам</h2>
        ${table(statCols, stats)}
        ${topScorers.length ? `
          <h3 class="section-subtitle">Топ-3 бомбардира</h3>
          ${table(topScorersCols, topScorers)}
        ` : ''}
      </section>

      <section class="card">
        <h2 class="card-title">Матчи (${matches.length})</h2>
        ${table(matchCols, matches)}
      </section>
    `);
  } catch (e) {
    errorMsg(e);
  }
}
