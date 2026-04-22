import { api } from '../api.js';
import { render, loading, errorMsg, table } from '../ui.js';

export async function topScorersPage() {
  render(`
    <div class="page-header"><h1>Бомбардиры</h1></div>
    <section class="card">
      <form id="ts-form" class="filter-form">
        <label>Сезон (ID): <input name="seasonId" type="number" min="1" value="1" class="input-sm" /></label>
        <label>Показатель:
          <select name="statField" class="input-sm">
            <option value="Points">Очки</option>
            <option value="Goals">Голы</option>
            <option value="Assists">Передачи</option>
            <option value="Shots">Броски</option>
          </select>
        </label>
        <label>Топ: <input name="topN" type="number" min="5" max="50" value="20" class="input-sm" /></label>
        <button type="submit" class="btn">Показать</button>
      </form>
    </section>
    <div id="ts-content"></div>
  `);

  const cols = [
    { label: 'Место',   key: 'Rank', cls: 'center' },
    { label: 'Игрок',   key: (r) => `<a href="#/players/${r.PlayerID}" class="link">${r.FullName}</a>` },
    { label: 'Позиция', key: 'Position' },
    { label: 'Команда', key: 'TeamName' },
    { label: 'И',  key: 'GamesPlayed',    cls: 'center' },
    { label: 'Г',  key: 'Goals',          cls: 'center' },
    { label: 'П',  key: 'Assists',        cls: 'center' },
    { label: 'О',  key: 'Points',         cls: 'center bold' },
    { label: 'ШВ', key: 'PenaltyMinutes', cls: 'center' },
    { label: '+/-',key: 'PlusMinus',      cls: 'center' },
    { label: 'Бр', key: 'Shots',          cls: 'center' },
  ];

  async function load(seasonId, statField, topN) {
    const el = document.getElementById('ts-content');
    if (!el) return;
    el.innerHTML = '<div class="loading"><span class="spinner"></span> Загрузка…</div>';
    try {
      const rows = await api.topPlayers(seasonId, statField, topN);
      el.innerHTML = rows.length ? table(cols, rows) : '<p class="empty">Нет данных.</p>';
    } catch (e) {
      el.innerHTML = `<div class="error-box"><span class="error-icon">⚠</span><p>${e.message}</p></div>`;
    }
  }

  document.getElementById('ts-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const f = new FormData(e.target);
    load(f.get('seasonId'), f.get('statField'), f.get('topN'));
  });

  load(1, 'Points', 20);
}
