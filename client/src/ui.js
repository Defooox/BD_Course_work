export const app = () => document.getElementById('app');

export function render(html) {
  app().innerHTML = html;
}

export function loading() {
  render('<div class="loading"><span class="spinner"></span> Загрузка…</div>');
}

export function errorMsg(err) {
  render(`<div class="error-box">
    <span class="error-icon">⚠</span>
    <p>${err?.message || err}</p>
  </div>`);
}

export function fmt(val, fallback = '—') {
  return val != null ? val : fallback;
}

export function fmtDate(s) {
  if (!s) return '—';
  return new Date(s).toLocaleDateString('ru-RU');
}

export function fmtMoney(v) {
  if (v == null) return '—';
  return Number(v).toLocaleString('ru-RU') + ' ₽';
}

export function fmtTime(min, sec) {
  if (min == null) return '—';
  return `${min}:${String(sec ?? 0).padStart(2, '0')}`;
}

export function table(cols, rows, opts = {}) {
  if (!rows?.length) return '<p class="empty">Нет данных</p>';
  const ths = cols.map((c) => `<th>${c.label}</th>`).join('');
  const trs = rows.map((row, idx) => {
    const tds = cols.map((c) => {
      const v = typeof c.key === 'function' ? c.key(row, idx) : fmt(row[c.key]);
      return `<td class="${c.cls || ''}">${v}</td>`;
    }).join('');
    const click = opts.onRow ? ` style="cursor:pointer" onclick="${opts.onRow(row)}"` : '';
    return `<tr${click}>${tds}</tr>`;
  }).join('');
  return `<div class="table-wrap"><table class="data-table ${opts.cls || ''}">
    <thead><tr>${ths}</tr></thead>
    <tbody>${trs}</tbody>
  </table></div>`;
}

export function tabs(items, activeIdx, onTab) {
  return `<div class="tabs">${items.map((label, i) =>
    `<button class="tab-btn ${i === activeIdx ? 'active' : ''}" onclick="(${onTab})(${i})">${label}</button>`
  ).join('')}</div>`;
}

export function card(title, body) {
  return `<section class="card"><h2 class="card-title">${title}</h2>${body}</section>`;
}

export function badge(text, type = '') {
  return `<span class="badge badge-${type}">${text}</span>`;
}

export function resultBadge(result) {
  const map = { 'Победа': 'win', 'Поражение': 'loss', 'Ничья': 'draw' };
  return badge(result, map[result] || '');
}

export function periodLabel(p) {
  return p === 4 ? 'ОТ' : `${p} период`;
}
