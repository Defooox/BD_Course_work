#pragma once
// ============================================================
//  ApiRouter.h — регистрация маршрутов и вспомогательные
//  функции для формирования HTTP-ответов
// ============================================================
#include <httplib.h>
#include <nlohmann/json.hpp>
#include "db/Database.h"
#include <string>
#include <functional>
#include <optional>

// ────────────────────────────────────────────────────────────
// Вспомогательные функции работы с запросами/ответами
// ────────────────────────────────────────────────────────────
namespace api {

inline void sendJson(httplib::Response& res, const nlohmann::json& body, int status = 200)
{
    res.status = status;
    res.set_header("Content-Type", "application/json; charset=utf-8");
    res.body = body.dump(2);
}

inline void sendError(httplib::Response& res, const std::string& msg, int status = 400)
{
    sendJson(res, {{"error", msg}}, status);
}

// Извлечь query-параметр как int (nullable)
inline std::optional<int> queryInt(const httplib::Request& req, const std::string& key)
{
    if (!req.has_param(key)) return std::nullopt;
    try { return std::stoi(req.get_param_value(key)); }
    catch (...) { return std::nullopt; }
}

// Извлечь query-параметр как строку (nullable)
inline std::optional<std::string> queryStr(const httplib::Request& req, const std::string& key)
{
    if (!req.has_param(key) || req.get_param_value(key).empty()) return std::nullopt;
    return req.get_param_value(key);
}

// Сформировать стандартный успешный ответ
inline nlohmann::json ok(const std::string& msg = "ok") {
    return {{"status", "ok"}, {"message", msg}};
}

// ────────────────────────────────────────────────────────────
// Главный роутер
// ────────────────────────────────────────────────────────────
class ApiRouter {
public:
    explicit ApiRouter(db::Database& db) : db_(db) {}

    // Зарегистрировать все маршруты на сервер
    void registerRoutes(httplib::Server& srv,
                        const std::string& allowedOrigins);

private:
    db::Database& db_;

    // ── Команды ──────────────────────────────────────────────
    void handleGetTeamsBySeason       (const httplib::Request&, httplib::Response&);
    void handleGetPlayersByTeam       (const httplib::Request&, httplib::Response&);
    void handleGetTeamMatches         (const httplib::Request&, httplib::Response&);
    void handleGetTeamCoaches         (const httplib::Request&, httplib::Response&);
    void handleGetTeamStats           (const httplib::Request&, httplib::Response&);

    // ── Игроки ───────────────────────────────────────────────
    void handleGetPlayerSeasonStats   (const httplib::Request&, httplib::Response&);
    void handleGetTopPlayers          (const httplib::Request&, httplib::Response&);
    void handleGetMostPenalized       (const httplib::Request&, httplib::Response&);
    void handleGetTransferredPlayers  (const httplib::Request&, httplib::Response&);

    // ── Матчи ────────────────────────────────────────────────
    void handleGetHeadToHead          (const httplib::Request&, httplib::Response&);
    void handleGetMatchesByArena      (const httplib::Request&, httplib::Response&);
    void handleGetHighScoringMatches  (const httplib::Request&, httplib::Response&);
    void handleGetMatchParticipants   (const httplib::Request&, httplib::Response&);

    // ── Таблица / трансферы ──────────────────────────────────
    void handleGetStandings           (const httplib::Request&, httplib::Response&);
    void handleGetTransfers           (const httplib::Request&, httplib::Response&);

    // ── Отчёты ───────────────────────────────────────────────
    void handleGetSeasonReport        (const httplib::Request&, httplib::Response&);
    void handleGetPlayerCard          (const httplib::Request&, httplib::Response&);
    void handleGetMatchReport         (const httplib::Request&, httplib::Response&);
};

} // namespace api
