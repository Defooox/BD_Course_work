// ============================================================
//  ApiRouter.cpp — реализация всех обработчиков маршрутов
//
//  Каждый обработчик:
//    1. Читает параметры из URL / query string
//    2. Формирует вектор db::Param
//    3. Вызывает execProc()
//    4. Упаковывает result-set'ы в JSON и отвечает клиенту
// ============================================================
#include "ApiRouter.h"

#include <stdexcept>
#include <sstream>

using json = nlohmann::json;
using db::Param;

namespace api {

// ────────────────────────────────────────────────────────────
// Макрос-обёртка: ловит исключения и отвечает 500
// ────────────────────────────────────────────────────────────
#define CATCH_DB_ERRORS                                         \
    catch (const db::DatabaseError& e) {                        \
        sendError(res, std::string("Database error: ") + e.what(), 500); \
    } catch (const std::exception& e) {                         \
        sendError(res, std::string("Internal error: ") + e.what(), 500); \
    }

// ────────────────────────────────────────────────────────────
// Вспомогательная функция: результат одной процедуры → JSON
// Если у процедуры один result-set — возвращаем массив.
// Если несколько — возвращаем объект с ключами rs0, rs1, ...
// ────────────────────────────────────────────────────────────
static json packResults(const std::vector<json>& rs)
{
    if (rs.empty())           return json::array();
    if (rs.size() == 1)       return rs[0];
    json obj = json::object();
    for (size_t i = 0; i < rs.size(); ++i)
        obj["rs" + std::to_string(i)] = rs[i];
    return obj;
}

// ────────────────────────────────────────────────────────────
// Регистрация маршрутов
// ────────────────────────────────────────────────────────────
void ApiRouter::registerRoutes(httplib::Server& srv,
                                const std::string& allowedOrigins)
{
    // CORS preflight + заголовки
    srv.Options(".*", [&allowedOrigins](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin",  allowedOrigins);
        res.set_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        res.set_header("Access-Control-Allow-Headers", "Content-Type");
        res.status = 204;
    });
    auto cors = [&allowedOrigins](httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", allowedOrigins);
    };

    // Обёртка: добавляем CORS ко всем GET-ответам
    #define ROUTE(path, handler)                                           \
        srv.Get(path, [this, cors](const httplib::Request& req,            \
                                   httplib::Response& res) {               \
            cors(res);                                                     \
            handler(req, res);                                             \
        });

    // ── Команды ──────────────────────────────────────────────
    // GET /api/teams?seasonId=1
    ROUTE("/api/teams",                  handleGetTeamsBySeason)
    // GET /api/teams/:id/players?positionId=&citizenship=&minAge=&maxAge=
    ROUTE(R"(/api/teams/(\d+)/players)", handleGetPlayersByTeam)
    // GET /api/teams/:id/matches?dateFrom=&dateTo=&seasonId=
    ROUTE(R"(/api/teams/(\d+)/matches)", handleGetTeamMatches)
    // GET /api/teams/:id/coaches?seasonId=&current=1
    ROUTE(R"(/api/teams/(\d+)/coaches)", handleGetTeamCoaches)
    // GET /api/teams/:id/stats?seasonId=
    ROUTE(R"(/api/teams/(\d+)/stats)",   handleGetTeamStats)

    // ── Игроки ───────────────────────────────────────────────
    // GET /api/players/:id/stats?seasonId=
    ROUTE(R"(/api/players/(\d+)/stats)", handleGetPlayerSeasonStats)
    // GET /api/players/:id/card
    ROUTE(R"(/api/players/(\d+)/card)",  handleGetPlayerCard)
    // GET /api/players/top?seasonId=&statField=Points&topN=10&teamId=
    ROUTE("/api/players/top",            handleGetTopPlayers)
    // GET /api/players/penalized?seasonId=&topN=10&teamId=
    ROUTE("/api/players/penalized",      handleGetMostPenalized)
    // GET /api/players/transferred?seasonId=&dateFrom=&dateTo=
    ROUTE("/api/players/transferred",    handleGetTransferredPlayers)

    // ── Матчи ────────────────────────────────────────────────
    // GET /api/matches/head-to-head?team1=&team2=&seasonId=
    ROUTE("/api/matches/head-to-head",      handleGetHeadToHead)
    // GET /api/matches/high-scoring?seasonId=&minGoals=6&topN=20
    ROUTE("/api/matches/high-scoring",      handleGetHighScoringMatches)
    // GET /api/matches/:id/participants
    ROUTE(R"(/api/matches/(\d+)/participants)", handleGetMatchParticipants)
    // GET /api/matches/:id/report
    ROUTE(R"(/api/matches/(\d+)/report)",       handleGetMatchReport)

    // ── Арены ────────────────────────────────────────────────
    // GET /api/arenas/:id/matches?dateFrom=&dateTo=&seasonId=
    ROUTE(R"(/api/arenas/(\d+)/matches)", handleGetMatchesByArena)

    // ── Турнирная таблица ────────────────────────────────────
    // GET /api/standings?tournamentId=&seasonId=
    ROUTE("/api/standings",              handleGetStandings)

    // ── Трансферы ────────────────────────────────────────────
    // GET /api/transfers?dateFrom=&dateTo=&teamId=&playerId=&type=
    ROUTE("/api/transfers",              handleGetTransfers)

    // ── Отчёты ───────────────────────────────────────────────
    // GET /api/reports/season/:id
    ROUTE(R"(/api/reports/season/(\d+))", handleGetSeasonReport)

    #undef ROUTE

    // Health-check
    srv.Get("/api/health", [](const httplib::Request&, httplib::Response& res) {
        res.set_content(R"({"status":"ok"})", "application/json");
    });
}

// ============================================================
//  КОМАНДЫ
// ============================================================

// GET /api/teams?seasonId=1
void ApiRouter::handleGetTeamsBySeason(const httplib::Request& req,
                                        httplib::Response& res)
{
    try {
        auto sid = queryInt(req, "seasonId");
        if (!sid) { sendError(res, "seasonId is required"); return; }

        auto rs = db_.execProc("sp_GetTeamsBySeason", { Param::of(*sid) });
        // Процедура возвращает 2 result-set: список команд + totalTeams
        json out;
        out["teams"]      = rs.size() > 0 ? rs[0] : json::array();
        out["totalTeams"] = rs.size() > 1 && !rs[1].empty()
                            ? rs[1][0].value("TotalTeams", 0) : 0;
        sendJson(res, out);
    } CATCH_DB_ERRORS
}

// GET /api/teams/:id/players
void ApiRouter::handleGetPlayersByTeam(const httplib::Request& req,
                                        httplib::Response& res)
{
    try {
        int teamId = std::stoi(req.matches[1]);
        auto posId  = queryInt(req, "positionId");
        auto cit    = queryStr(req, "citizenship");
        auto minAge = queryInt(req, "minAge");
        auto maxAge = queryInt(req, "maxAge");

        auto rs = db_.execProc("sp_GetPlayersByTeam", {
            Param::of(teamId),
            posId  ? Param::of(*posId)        : Param::null(),
            cit    ? Param::of(*cit)          : Param::null(),
            minAge ? Param::of(*minAge)       : Param::null(),
            maxAge ? Param::of(*maxAge)       : Param::null()
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// GET /api/teams/:id/matches
void ApiRouter::handleGetTeamMatches(const httplib::Request& req,
                                      httplib::Response& res)
{
    try {
        int teamId   = std::stoi(req.matches[1]);
        auto dateFrom = queryStr(req, "dateFrom");
        auto dateTo   = queryStr(req, "dateTo");
        auto sid      = queryInt(req, "seasonId");

        auto rs = db_.execProc("sp_GetTeamMatches", {
            Param::of(teamId),
            dateFrom ? Param::of(*dateFrom) : Param::null(),
            dateTo   ? Param::of(*dateTo)   : Param::null(),
            sid      ? Param::of(*sid)      : Param::null()
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// GET /api/teams/:id/coaches
void ApiRouter::handleGetTeamCoaches(const httplib::Request& req,
                                      httplib::Response& res)
{
    try {
        int teamId  = std::stoi(req.matches[1]);
        auto sid    = queryInt(req, "seasonId");
        auto cur    = queryInt(req, "current");

        auto rs = db_.execProc("sp_GetTeamCoaches", {
            Param::of(teamId),
            sid ? Param::of(*sid) : Param::null(),
            Param::of(cur.value_or(1))
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// GET /api/teams/:id/stats
void ApiRouter::handleGetTeamStats(const httplib::Request& req,
                                    httplib::Response& res)
{
    try {
        int teamId = std::stoi(req.matches[1]);
        auto sid   = queryInt(req, "seasonId");

        auto rs = db_.execProc("sp_GetTeamStats", {
            Param::of(teamId),
            sid ? Param::of(*sid) : Param::null()
        });
        // rs[0] = таблица stats, rs[1] = топ-3 бомбардира (если seasonId передан)
        json out;
        out["stats"]     = rs.size() > 0 ? rs[0] : json::array();
        out["topScorers"]= rs.size() > 1 ? rs[1] : json::array();
        sendJson(res, out);
    } CATCH_DB_ERRORS
}

// ============================================================
//  ИГРОКИ
// ============================================================

// GET /api/players/:id/stats
void ApiRouter::handleGetPlayerSeasonStats(const httplib::Request& req,
                                            httplib::Response& res)
{
    try {
        int playerId = std::stoi(req.matches[1]);
        auto sid     = queryInt(req, "seasonId");

        auto rs = db_.execProc("sp_GetPlayerSeasonStats", {
            Param::of(playerId),
            sid ? Param::of(*sid) : Param::null()
        });
        // rs[0] = карточка игрока, rs[1] = статистика по сезонам
        json out;
        out["player"] = rs.size() > 0 && !rs[0].empty() ? rs[0][0] : json(nullptr);
        out["stats"]  = rs.size() > 1 ? rs[1] : json::array();
        sendJson(res, out);
    } CATCH_DB_ERRORS
}

// GET /api/players/:id/card
void ApiRouter::handleGetPlayerCard(const httplib::Request& req,
                                     httplib::Response& res)
{
    try {
        int playerId = std::stoi(req.matches[1]);
        auto rs = db_.execProc("sp_GetPlayerCard", { Param::of(playerId) });

        // 5 result-set'ов: личные данные, контракт, статистика, трансферы, последние матчи
        json out;
        out["info"]        = rs.size() > 0 && !rs[0].empty() ? rs[0][0] : json(nullptr);
        out["contract"]    = rs.size() > 1 && !rs[1].empty() ? rs[1][0] : json(nullptr);
        out["stats"]       = rs.size() > 2 ? rs[2] : json::array();
        out["transfers"]   = rs.size() > 3 ? rs[3] : json::array();
        out["recentMatches"]= rs.size() > 4 ? rs[4] : json::array();
        sendJson(res, out);
    } CATCH_DB_ERRORS
}

// GET /api/players/top
void ApiRouter::handleGetTopPlayers(const httplib::Request& req,
                                     httplib::Response& res)
{
    try {
        auto sid   = queryInt(req, "seasonId");
        if (!sid) { sendError(res, "seasonId is required"); return; }
        auto field = queryStr(req, "statField");
        auto topN  = queryInt(req, "topN");
        auto tid   = queryInt(req, "teamId");

        auto rs = db_.execProc("sp_GetTopPlayers", {
            Param::of(*sid),
            field ? Param::of(*field) : Param::of(std::string("Points")),
            Param::of(topN.value_or(10)),
            tid   ? Param::of(*tid)   : Param::null()
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// GET /api/players/penalized
void ApiRouter::handleGetMostPenalized(const httplib::Request& req,
                                        httplib::Response& res)
{
    try {
        auto sid  = queryInt(req, "seasonId");
        if (!sid) { sendError(res, "seasonId is required"); return; }
        auto topN = queryInt(req, "topN");
        auto tid  = queryInt(req, "teamId");

        auto rs = db_.execProc("sp_GetMostPenalizedPlayers", {
            Param::of(*sid),
            Param::of(topN.value_or(10)),
            tid ? Param::of(*tid) : Param::null()
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// GET /api/players/transferred
void ApiRouter::handleGetTransferredPlayers(const httplib::Request& req,
                                             httplib::Response& res)
{
    try {
        auto sid      = queryInt(req, "seasonId");
        auto dateFrom = queryStr(req, "dateFrom");
        auto dateTo   = queryStr(req, "dateTo");

        auto rs = db_.execProc("sp_GetTransferredPlayers", {
            sid      ? Param::of(*sid)      : Param::null(),
            dateFrom ? Param::of(*dateFrom) : Param::null(),
            dateTo   ? Param::of(*dateTo)   : Param::null()
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// ============================================================
//  МАТЧИ
// ============================================================

// GET /api/matches/head-to-head
void ApiRouter::handleGetHeadToHead(const httplib::Request& req,
                                     httplib::Response& res)
{
    try {
        auto t1 = queryInt(req, "team1");
        auto t2 = queryInt(req, "team2");
        if (!t1 || !t2) { sendError(res, "team1 and team2 are required"); return; }
        auto sid = queryInt(req, "seasonId");

        auto rs = db_.execProc("sp_GetHeadToHead", {
            Param::of(*t1),
            Param::of(*t2),
            sid ? Param::of(*sid) : Param::null()
        });
        json out;
        out["matches"] = rs.size() > 0 ? rs[0] : json::array();
        out["summary"] = rs.size() > 1 && !rs[1].empty() ? rs[1][0] : json(nullptr);
        sendJson(res, out);
    } CATCH_DB_ERRORS
}

// GET /api/arenas/:id/matches
void ApiRouter::handleGetMatchesByArena(const httplib::Request& req,
                                         httplib::Response& res)
{
    try {
        int arenaId   = std::stoi(req.matches[1]);
        auto dateFrom = queryStr(req, "dateFrom");
        auto dateTo   = queryStr(req, "dateTo");
        auto sid      = queryInt(req, "seasonId");

        auto rs = db_.execProc("sp_GetMatchesByArena", {
            Param::of(arenaId),
            dateFrom ? Param::of(*dateFrom) : Param::null(),
            dateTo   ? Param::of(*dateTo)   : Param::null(),
            sid      ? Param::of(*sid)      : Param::null()
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// GET /api/matches/high-scoring
void ApiRouter::handleGetHighScoringMatches(const httplib::Request& req,
                                             httplib::Response& res)
{
    try {
        auto sid      = queryInt(req, "seasonId");
        auto minGoals = queryInt(req, "minGoals");
        auto topN     = queryInt(req, "topN");

        auto rs = db_.execProc("sp_GetHighScoringMatches", {
            sid      ? Param::of(*sid)          : Param::null(),
            Param::of(minGoals.value_or(6)),
            Param::of(topN.value_or(20))
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// GET /api/matches/:id/participants
void ApiRouter::handleGetMatchParticipants(const httplib::Request& req,
                                            httplib::Response& res)
{
    try {
        int matchId = std::stoi(req.matches[1]);
        auto rs = db_.execProc("sp_GetMatchParticipants", { Param::of(matchId) });

        // rs[0]=инфо о матче, rs[1]=состав, rs[2]=судьи, rs[3]=события
        json out;
        out["match"]   = rs.size() > 0 && !rs[0].empty() ? rs[0][0] : json(nullptr);
        out["lineups"] = rs.size() > 1 ? rs[1] : json::array();
        out["referees"]= rs.size() > 2 ? rs[2] : json::array();
        out["events"]  = rs.size() > 3 ? rs[3] : json::array();
        sendJson(res, out);
    } CATCH_DB_ERRORS
}

// GET /api/matches/:id/report
void ApiRouter::handleGetMatchReport(const httplib::Request& req,
                                      httplib::Response& res)
{
    try {
        int matchId = std::stoi(req.matches[1]);
        auto rs = db_.execProc("sp_GetMatchReport", { Param::of(matchId) });

        // rs[0]=инфо, rs[1]=голы, rs[2]=счёт по периодам, rs[3]=удаления, rs[4]=судьи
        json out;
        out["match"]          = rs.size() > 0 && !rs[0].empty() ? rs[0][0] : json(nullptr);
        out["goals"]          = rs.size() > 1 ? rs[1] : json::array();
        out["periodScores"]   = rs.size() > 2 ? rs[2] : json::array();
        out["penalties"]      = rs.size() > 3 ? rs[3] : json::array();
        out["referees"]       = rs.size() > 4 ? rs[4] : json::array();
        sendJson(res, out);
    } CATCH_DB_ERRORS
}

// ============================================================
//  ТАБЛИЦА / ТРАНСФЕРЫ
// ============================================================

// GET /api/standings
void ApiRouter::handleGetStandings(const httplib::Request& req,
                                    httplib::Response& res)
{
    try {
        auto tid = queryInt(req, "tournamentId");
        auto sid = queryInt(req, "seasonId");

        auto rs = db_.execProc("sp_GetStandings", {
            tid ? Param::of(*tid) : Param::null(),
            sid ? Param::of(*sid) : Param::null()
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// GET /api/transfers
void ApiRouter::handleGetTransfers(const httplib::Request& req,
                                    httplib::Response& res)
{
    try {
        auto dateFrom = queryStr(req, "dateFrom");
        auto dateTo   = queryStr(req, "dateTo");
        auto teamId   = queryInt(req, "teamId");
        auto playerId = queryInt(req, "playerId");
        auto type     = queryStr(req, "type");

        auto rs = db_.execProc("sp_GetTransfers", {
            dateFrom ? Param::of(*dateFrom) : Param::null(),
            dateTo   ? Param::of(*dateTo)   : Param::null(),
            teamId   ? Param::of(*teamId)   : Param::null(),
            playerId ? Param::of(*playerId) : Param::null(),
            type     ? Param::of(*type)     : Param::null()
        });
        sendJson(res, packResults(rs));
    } CATCH_DB_ERRORS
}

// ============================================================
//  ОТЧЁТЫ
// ============================================================

// GET /api/reports/season/:id
void ApiRouter::handleGetSeasonReport(const httplib::Request& req,
                                       httplib::Response& res)
{
    try {
        int sid = std::stoi(req.matches[1]);
        auto rs = db_.execProc("sp_GetSeasonReport", { Param::of(sid) });

        // rs[0]=мета, rs[1]=таблица, rs[2]=бомбардиры, rs[3]=штрафники, rs[4]=матчи
        json out;
        out["meta"]          = rs.size() > 0 && !rs[0].empty() ? rs[0][0] : json(nullptr);
        out["standings"]     = rs.size() > 1 ? rs[1] : json::array();
        out["topScorers"]    = rs.size() > 2 ? rs[2] : json::array();
        out["topPenalized"]  = rs.size() > 3 ? rs[3] : json::array();
        out["highScoringMatches"] = rs.size() > 4 ? rs[4] : json::array();
        sendJson(res, out);
    } CATCH_DB_ERRORS
}

} // namespace api
