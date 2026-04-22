import './style.css';
import { route, initRouter, navigate } from './router.js';
import { render } from './ui.js';

import { standingsPage }   from './pages/standings.js';
import { teamsPage }       from './pages/teams.js';
import { teamDetailPage }  from './pages/team-detail.js';
import { playerPage }      from './pages/player.js';
import { matchPage }       from './pages/match.js';
import { transfersPage }   from './pages/transfers.js';
import { seasonReportPage} from './pages/season-report.js';
import { topScorersPage }  from './pages/top-scorers.js';

route('/',                     () => navigate('/standings'));
route('/standings',            standingsPage);
route('/teams',                teamsPage);
route('/teams/(\\d+)',         teamDetailPage);
route('/players/(\\d+)',       playerPage);
route('/matches/(\\d+)',       matchPage);
route('/transfers',            transfersPage);
route('/season/(\\d+)',        seasonReportPage);
route('/top-scorers',          topScorersPage);

initRouter((hash) => {
  render(`<div class="error-box"><span class="error-icon">⚠</span><p>Страница не найдена: <code>${hash}</code></p></div>`);
});
