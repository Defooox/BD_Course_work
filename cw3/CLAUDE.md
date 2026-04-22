# Hockey League Information System

## Что это за проект
Информационная система хоккейной лиги. Клиент-серверное приложение:
- **Сервер** — C++17, httplib, nlohmann/json, ODBC → MS SQL Server
- **База данных** — MS SQL Server, все операции только через хранимые процедуры
- **Клиент** — JavaScript (веб-интерфейс, пока не реализован)

## Структура репозитория

```
cw3/
├── CLAUDE.md                  ← этот файл
├── hockey_league_db.sql       ← полная схема БД (таблицы, view, процедуры, триггеры)
└── server/
    ├── CMakeLists.txt
    ├── config/
    │   └── server.cfg         ← хост, порт, строка подключения ODBC, CORS
    └── src/
        ├── main.cpp           ← точка входа, Config, httplib::Server, сигналы
        ├── Config.h           ← INI-парсер (без зависимостей)
        ├── db/
        │   ├── Database.h
        │   └── Database.cpp   ← ODBC-обёртка: connect, execProc, fetchResultSet
        └── api/
            ├── ApiRouter.h
            └── ApiRouter.cpp  ← все 18 HTTP-маршрутов + обработчики
```

## База данных (MS SQL Server — HockeyLeague)

### Таблицы (20 штук)
Справочники: `Seasons`, `Cities`, `Arenas`, `Positions`, `CoachRoles`, `EventTypes`  
Сущности: `Players`, `Teams`, `Coaches`, `Referees`, `Tournaments`  
Кадровые: `Contracts`, `CoachAssignments`, `Transfers`  
Матчи: `Matches`, `MatchReferees`, `MatchLineups`, `MatchEvents`  
Статистика: `PlayerSeasonStats`, `TeamSeasonStats`

### Представления (6 штук)
- `vw_CurrentRoster` — активный состав команды
- `vw_Standings` — турнирная таблица с RANK()
- `vw_TopScorers` — бомбардиры (Goals+Assists=Points вычисляемая колонка)
- `vw_MatchResults` — сводка матчей с WinnerTeamID
- `vw_ActiveCoaches` — действующий тренерский штаб
- `vw_MatchEventsFull` — лента событий матча с именами

### Хранимые процедуры (18 штук)
| Процедура | Маршрут API |
|-----------|-------------|
| sp_GetTeamsBySeason | GET /api/teams?seasonId= |
| sp_GetPlayersByTeam | GET /api/teams/:id/players |
| sp_GetTeamMatches | GET /api/teams/:id/matches |
| sp_GetTeamCoaches | GET /api/teams/:id/coaches |
| sp_GetTeamStats | GET /api/teams/:id/stats |
| sp_GetPlayerSeasonStats | GET /api/players/:id/stats |
| sp_GetTopPlayers | GET /api/players/top |
| sp_GetMostPenalizedPlayers | GET /api/players/penalized |
| sp_GetTransferredPlayers | GET /api/players/transferred |
| sp_GetHeadToHead | GET /api/matches/head-to-head |
| sp_GetMatchesByArena | GET /api/arenas/:id/matches |
| sp_GetHighScoringMatches | GET /api/matches/high-scoring |
| sp_GetMatchParticipants | GET /api/matches/:id/participants |
| sp_GetStandings | GET /api/standings |
| sp_GetTransfers | GET /api/transfers |
| sp_GetSeasonReport | GET /api/reports/season/:id |
| sp_GetPlayerCard | GET /api/players/:id/card |
| sp_GetMatchReport | GET /api/matches/:id/report |

### Триггеры (4 штуки)
- `tr_MatchEvents_AfterGoal` — при вставке гола обновляет HomeScore/AwayScore в Matches
- `tr_Transfers_CloseOldContract` — при трансфере завершает старый контракт
- `tr_Matches_PreventScoreEdit` — запрещает менять счёт завершённого матча (INSTEAD OF UPDATE)
- `tr_Matches_UpdateTeamStats` — при Status→Finished пересчитывает TeamSeasonStats через MERGE

## C++ сервер

### Зависимости (FetchContent, скачиваются автоматически)
- `cpp-httplib v0.15.3` — HTTP-сервер (header-only)
- `nlohmann/json v3.11.3` — JSON (header-only)
- `odbc32` — системная Windows ODBC

### Сборка
```powershell
cmake -B build -G "Visual Studio 17 2022"
cmake --build build --config Release
.\build\Release\hockey_server.exe
```

### Конфигурация (server.cfg)
```ini
[server]
host = 0.0.0.0
port = 8080
threads = 4

[database]
connection_string = Driver={ODBC Driver 17 for SQL Server};Server=localhost\SQLEXPRESS;Database=HockeyLeague;Trusted_Connection=yes;

[cors]
allowed_origins = http://localhost:3000,http://localhost:5173

[log]
level = info
```

### Ключевые архитектурные решения
- `db::Database::execProc()` принимает имя процедуры + `vector<db::Param>`, возвращает `vector<nlohmann::json>` (один элемент = один result-set)
- `db::Param` — union-подобная структура: `Param::of(int)`, `Param::of(double)`, `Param::of(string)`, `Param::null()`
- `ApiRouter::packResults()` — если один result-set, отдаёт массив напрямую; если несколько — объект `{rs0:[...], rs1:[...]}`
- Процедуры возвращающие несколько SELECT (карточка игрока, отчёт матча и т.д.) распаковываются в ApiRouter вручную по индексам rs[0], rs[1]...
- CORS preflight обрабатывается через `srv.Options(".*", ...)`

## Что ещё не сделано
- [ ] JavaScript клиент (веб-интерфейс)
- [ ] Тестовые данные (INSERT-скрипт)
- [ ] Аутентификация/авторизация
- [ ] HTTPS (сейчас HTTP)

## Соглашения
- Все идентификаторы в БД — PascalCase
- Хранимые процедуры: префикс `sp_`, view: `vw_`, триггеры: `tr_`
- API отдаёт `{"error": "..."}` при ошибках (400 или 500)
- Nullable параметры в API передаются как query-string, отсутствие = NULL в процедуру
- Кодировка БД: `Cyrillic_General_CI_AS`, строки в SQL — N'...'
