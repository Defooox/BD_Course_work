import { api } from '../api.js';
import { render, loading, errorMsg, table, fmt, fmtDate, fmtMoney } from '../ui.js';

export async function playerPage(id) {
  loading();
  try {
    const data = await api.playerCard(Number(id));
    const { info, contract, stats, transfers, recentMatches } = data;

    if (!info) { render('<p class="empty">Игрок не найден.</p>'); return; }

    const statCols = [
      { label: 'Сезон',   key: 'Season' },
      { label: 'Команда', key: 'Team' },
      { label: 'И',   key: 'GamesPlayed',    cls: 'center' },
      { label: 'Г',   key: 'Goals',          cls: 'center' },
      { label: 'П',   key: 'Assists',        cls: 'center' },
      { label: 'О',   key: 'Points',         cls: 'center bold' },
      { label: 'ШВ',  key: 'PenaltyMinutes', cls: 'center' },
      { label: '+/-', key: 'PlusMinus',      cls: 'center' },
      { label: 'Бр',  key: 'Shots',          cls: 'center' },
      { label: 'ПШ',  key: 'GoalsAgainst',   cls: 'center' },
      { label: '%сейв', key: (r) => r.SavePct != null ? (r.SavePct * 100).toFixed(1) + '%' : '—', cls: 'center' },
      { label: 'Шатауты', key: 'Shutouts',   cls: 'center' },
    ];

    const transferCols = [
      { label: 'Дата',  key: (r) => fmtDate(r.TransferDate) },
      { label: 'Тип',   key: 'TransferType' },
      { label: 'Откуда', key: (r) => fmt(r.FromTeam) },
      { label: 'Куда',  key: 'ToTeam' },
      { label: 'Сумма', key: (r) => fmtMoney(r.TransferFee) },
    ];

    const matchCols = [
      { label: 'Дата',   key: (r) => fmtDate(r.MatchDate) },
      { label: 'Турнир', key: 'TournamentName' },
      { label: 'Хозяева', key: 'HomeTeam' },
      { label: 'Счёт',   key: (r) => `<b>${r.HomeScore} : ${r.AwayScore}</b>`, cls: 'center' },
      { label: 'Гости',  key: 'AwayTeam' },
    ];

    render(`
      <div class="page-header">
        <h1>${info.FullName}</h1>
        <span class="badge badge-pos">${info.Position}</span>
      </div>

      <div class="two-col">
        <section class="card">
          <h2 class="card-title">Личные данные</h2>
          <dl class="info-list">
            <dt>Дата рождения</dt><dd>${fmtDate(info.BirthDate)}</dd>
            <dt>Возраст</dt><dd>${fmt(info.Age)} лет</dd>
            <dt>Гражданство</dt><dd>${fmt(info.Citizenship)}</dd>
            <dt>Рост</dt><dd>${info.Height ? info.Height + ' см' : '—'}</dd>
            <dt>Вес</dt><dd>${info.Weight ? info.Weight + ' кг' : '—'}</dd>
          </dl>
        </section>

        <section class="card">
          <h2 class="card-title">Текущий контракт</h2>
          ${contract ? `
            <dl class="info-list">
              <dt>Команда</dt><dd>${contract.Team}</dd>
              <dt>Номер</dt><dd>${fmt(contract.JerseyNumber)}</dd>
              <dt>Зарплата</dt><dd>${fmtMoney(contract.Salary)}</dd>
              <dt>С</dt><dd>${fmtDate(contract.StartDate)}</dd>
              <dt>По</dt><dd>${fmtDate(contract.EndDate)}</dd>
            </dl>
          ` : '<p class="empty">Нет активного контракта</p>'}
        </section>
      </div>

      <section class="card">
        <h2 class="card-title">Статистика по сезонам</h2>
        ${table(statCols, stats)}
      </section>

      <section class="card">
        <h2 class="card-title">История трансферов</h2>
        ${table(transferCols, transfers)}
      </section>

      <section class="card">
        <h2 class="card-title">Последние матчи</h2>
        ${table(matchCols, recentMatches)}
      </section>
    `);
  } catch (e) {
    errorMsg(e);
  }
}
