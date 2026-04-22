import { api } from '../api.js';
import { render, loading, errorMsg, table, fmt, fmtDate } from '../ui.js';

function periodLabel(p) {
  return p === 4 ? 'ОТ' : `${p} пер.`;
}

function fmtGameTime(min, sec) {
  if (min == null) return '—';
  return `${min}:${String(sec ?? 0).padStart(2, '0')}`;
}

export async function matchPage(id) {
  loading();
  try {
    const data = await api.matchReport(Number(id));
    const { match, goals, periodScores, penalties, referees } = data;

    if (!match) { render('<p class="empty">Матч не найден.</p>'); return; }

    const winner = match.HomeScore > match.AwayScore ? 'home'
                 : match.AwayScore > match.HomeScore ? 'away' : 'draw';

    const goalCols = [
      { label: 'Пер.',  key: (r) => periodLabel(r.Period), cls: 'center' },
      { label: 'Время', key: (r) => fmtGameTime(r.GameMinute, r.GameSecond), cls: 'center' },
      { label: 'Команда', key: 'Team' },
      { label: 'Автор', key: 'PlayerName' },
      { label: 'Пас 1', key: (r) => fmt(r.Assist1) },
      { label: 'Пас 2', key: (r) => fmt(r.Assist2) },
    ];

    const penaltyCols = [
      { label: 'Пер.',  key: (r) => periodLabel(r.Period), cls: 'center' },
      { label: 'Время', key: (r) => `${fmt(r.GameMinute)}:00`, cls: 'center' },
      { label: 'Команда', key: 'Team' },
      { label: 'Игрок',   key: 'PlayerName' },
      { label: 'Мин',     key: 'PenaltyMinutes', cls: 'center' },
      { label: 'Описание', key: (r) => fmt(r.Description) },
    ];

    const periodRows = periodScores || [];

    render(`
      <div class="page-header">
        <h1 class="match-title">
          <span class="${winner === 'home' ? 'winner' : ''}">${match.HomeTeam}</span>
          <span class="score-big">${match.HomeScore} : ${match.AwayScore}</span>
          <span class="${winner === 'away' ? 'winner' : ''}">${match.AwayTeam}</span>
        </h1>
        <p class="subtitle">${fmtDate(match.MatchDate)}${match.MatchTime ? ', ' + match.MatchTime.slice(0,5) : ''} · ${fmt(match.ArenaName)}, ${fmt(match.ArenaCity)}</p>
        <p class="subtitle">${fmt(match.TournamentName)} · ${fmt(match.SeasonName)} · ${fmt(match.Stage)}</p>
        ${match.Attendance ? `<p class="subtitle">Зрителей: ${match.Attendance.toLocaleString('ru-RU')}</p>` : ''}
      </div>

      ${periodRows.length ? `
        <section class="card">
          <h2 class="card-title">Счёт по периодам</h2>
          <div class="period-scores">
            ${periodRows.map(r => `
              <div class="period-block">
                <div class="period-label">${periodLabel(r.Period)}</div>
                <div class="period-result">${r.HomeGoals} : ${r.AwayGoals}</div>
              </div>
            `).join('')}
          </div>
        </section>
      ` : ''}

      <section class="card">
        <h2 class="card-title">Голы (${goals?.length || 0})</h2>
        ${table(goalCols, goals)}
      </section>

      <section class="card">
        <h2 class="card-title">Удаления (${penalties?.length || 0})</h2>
        ${table(penaltyCols, penalties)}
      </section>

      <section class="card">
        <h2 class="card-title">Судьи</h2>
        ${referees?.length ? `
          <ul class="referee-list">
            ${referees.map(r => `<li><b>${r.Role}</b>: ${r.RefereeName}</li>`).join('')}
          </ul>
        ` : '<p class="empty">Нет данных</p>'}
      </section>
    `);
  } catch (e) {
    errorMsg(e);
  }
}
