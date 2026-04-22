import { api } from '../api.js';
import { render, loading, errorMsg, fmt } from '../ui.js';

export async function teamsPage() {
  loading();

  // сначала рендерим форму выбора сезона
  render(`
    <div class="page-header">
      <h1>Команды</h1>
    </div>
    <section class="card">
      <form id="season-form" class="filter-form">
        <label>Сезон (ID): <input name="seasonId" type="number" min="1" value="1" class="input-sm" /></label>
        <button type="submit" class="btn">Показать</button>
      </form>
    </section>
    <div id="teams-content"></div>
  `);

  async function loadTeams(seasonId) {
    const content = document.getElementById('teams-content');
    content.innerHTML = '<div class="loading"><span class="spinner"></span> Загрузка…</div>';
    try {
      const data = await api.teams(seasonId);
      const teams = data.teams || [];
      if (!teams.length) {
        content.innerHTML = '<p class="empty">Нет команд для этого сезона.</p>';
        return;
      }
      content.innerHTML = `
        <p class="subtitle">Всего команд: ${data.totalTeams}</p>
        <div class="team-grid">
          ${teams.map((t) => `
            <a href="#/teams/${t.TeamID}" class="team-card">
              <div class="team-card-name">${t.TeamName}</div>
              <div class="team-card-meta">${fmt(t.City)}</div>
              <div class="team-card-meta">Арена: ${fmt(t.HomeArena)}</div>
              <div class="team-card-stats">
                <span>Состав: ${fmt(t.RosterSize, 0)}</span>
                <span>Рейтинг: ${fmt(t.Rating)}</span>
              </div>
            </a>
          `).join('')}
        </div>
      `;
    } catch (e) {
      content.innerHTML = `<div class="error-box"><span class="error-icon">⚠</span><p>${e.message}</p></div>`;
    }
  }

  document.getElementById('season-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const sid = e.target.seasonId.value;
    if (sid) loadTeams(Number(sid));
  });

  loadTeams(1);
}
