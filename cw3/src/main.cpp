// ============================================================
//  main.cpp — точка входа HTTP-сервера хоккейной лиги
//
//  Запуск:   hockey_server [путь_к_конфигу]
//  По умолчанию конфиг ищется рядом с exe: server.cfg
// ============================================================
#define CPPHTTPLIB_OPENSSL_SUPPORT 0   // без TLS для упрощения; добавить при prod
#include <httplib.h>
#include <nlohmann/json.hpp>

#include "Config.h"
#include "db/Database.h"
#include "api/ApiRouter.h"

#include <iostream>
#include <string>
#include <csignal>
#include <atomic>

// ────────────────────────────────────────────────────────────
// Простой логгер
// ────────────────────────────────────────────────────────────
enum class LogLevel { Debug, Info, Warn, Error };

static LogLevel g_logLevel = LogLevel::Info;

static void log(LogLevel lvl, const std::string& msg)
{
    if (lvl < g_logLevel) return;
    const char* tag[] = { "[DEBUG]", "[INFO] ", "[WARN] ", "[ERROR]" };
    std::cout << tag[static_cast<int>(lvl)] << " " << msg << "\n";
}

// ────────────────────────────────────────────────────────────
// Обработка сигналов
// ────────────────────────────────────────────────────────────
static httplib::Server* g_server = nullptr;

static void onSignal(int) {
    log(LogLevel::Info, "Shutdown signal received, stopping server...");
    if (g_server) g_server->stop();
}

// ────────────────────────────────────────────────────────────
// main
// ────────────────────────────────────────────────────────────
int main(int argc, char* argv[])
{
    const std::string cfgPath = (argc > 1) ? argv[1] : "server.cfg";

    // 1. Конфигурация
    Config cfg(cfgPath);

    const std::string host    = cfg.get("server", "host",    "0.0.0.0");
    const int         port    = cfg.getInt("server", "port",  8080);
    const int         threads = cfg.getInt("server", "threads", 4);
    const std::string connStr = cfg.get("database", "connection_string");
    const std::string origins = cfg.get("cors", "allowed_origins", "*");
    const std::string logLvl  = cfg.get("log", "level", "info");

    if      (logLvl == "debug") g_logLevel = LogLevel::Debug;
    else if (logLvl == "warn")  g_logLevel = LogLevel::Warn;
    else if (logLvl == "error") g_logLevel = LogLevel::Error;

    if (connStr.empty()) {
        std::cerr << "[ERROR] database.connection_string is not set in " << cfgPath << "\n";
        return 1;
    }

    // 2. БД
    log(LogLevel::Info, "Connecting to database...");
    db::Database database(connStr);
    if (!database.isConnected()) {
        log(LogLevel::Error, "Failed to connect to database");
        return 1;
    }
    log(LogLevel::Info, "Database connected OK");

    // 3. HTTP-сервер
    httplib::Server server;
    server.new_task_queue = [threads] {
        return new httplib::ThreadPool(threads);
    };

    // Логирование входящих запросов
    server.set_logger([](const httplib::Request& req, const httplib::Response& res) {
        log(LogLevel::Info,
            req.method + " " + req.path + " → " + std::to_string(res.status));
    });

    // Обработчик ошибок (404, 500 и пр.)
    server.set_error_handler([](const httplib::Request& req, httplib::Response& res) {
        nlohmann::json err = {
            {"error", "Not found"},
            {"path",  req.path}
        };
        res.set_content(err.dump(), "application/json");
    });

    // Таймауты
    server.set_read_timeout(30);
    server.set_write_timeout(30);

    // 4. Маршруты
    api::ApiRouter router(database);
    router.registerRoutes(server, origins);

    // 5. Сигналы
    g_server = &server;
    std::signal(SIGINT,  onSignal);
    std::signal(SIGTERM, onSignal);

    // 6. Старт
    log(LogLevel::Info, "Server listening on " + host + ":" + std::to_string(port));
    log(LogLevel::Info, "Worker threads: " + std::to_string(threads));

    if (!server.listen(host.c_str(), port)) {
        log(LogLevel::Error, "Failed to start server on port " + std::to_string(port));
        return 1;
    }

    log(LogLevel::Info, "Server stopped cleanly");
    return 0;
}
