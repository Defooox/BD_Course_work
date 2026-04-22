import { api } from '../api.js';
import { render, loading, errorMsg, table, fmt, fmtDate, fmtMoney } from '../ui.js';

const TYPE_LABELS = { Transfer: 'Трансфер', Loan: 'Аренда', Free: 'Свободный агент', Draft: 'Драфт' };

export async function transfersPage() {
  render(`
    <div class="page-header"><h1>Трансферы</h1></div>
    <section class="card">
      <form id="tf-form" class="filter-form">
        <label>С: <input name="dateFrom" type="date" class="input-sm" /></label>
        <label>По: <input name="dateTo"   type="date" class="input-sm" /></label>
        <label>Тип:
          <select name="type" class="input-sm">
            <option value="">Все</option>
            <option value="Transfer">Трансфер</option>
            <option value="Loan">Аренда</option>
            <option value="Free">Свободный агент</option>
            <option value="Draft">Драфт</option>
          </select>
        </label>
        <button type="submit" class="btn">Найти</button>
        <button type="reset" class="btn btn-sec" id="tf-reset">Сбросить</button>
      </form>
    </section>
    <div id="tf-content"></div>
  `);

  const cols = [
    { label: 'Дата',    key: (r) => fmtDate(r.TransferDate) },
    { label: 'Тип',     key: (r) => TYPE_LABELS[r.TransferType] || r.TransferType },
    { label: 'Игрок',   key: (r) => `<a href="#/players/${r.PlayerID}" class="link">${r.PlayerName}</a>` },
    { label: 'Позиция', key: 'Position' },
    { label: 'Откуда',  key: (r) => fmt(r.FromTeam) },
    { label: 'Куда',    key: 'ToTeam' },
    { label: 'Сумма',   key: (r) => fmtMoney(r.TransferFee) },
  ];

  async function load(opts) {
    const el = document.getElementById('tf-content');
    if (!el) return;
    el.innerHTML = '<div class="loading"><span class="spinner"></span> Загрузка…</div>';
    try {
      const rows = await api.transfers(opts);
      el.innerHTML = rows.length
        ? `<p class="subtitle">Записей: ${rows.length}</p>` + table(cols, rows)
        : '<p class="empty">Нет трансферов по заданным критериям.</p>';
    } catch (e) {
      el.innerHTML = `<div class="error-box"><span class="error-icon">⚠</span><p>${e.message}</p></div>`;
    }
  }

  document.getElementById('tf-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const f = new FormData(e.target);
    load({ dateFrom: f.get('dateFrom'), dateTo: f.get('dateTo'), type: f.get('type') });
  });

  document.getElementById('tf-reset').addEventListener('click', () => load({}));

  load({});
}
