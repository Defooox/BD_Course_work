#pragma once

// ============================================================
//  Database.h — тонкая обёртка над Windows ODBC для вызова
//  хранимых процедур MS SQL Server и получения JSON-результатов
// ============================================================

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <sql.h>
#include <sqlext.h>

#include <string>
#include <vector>
#include <stdexcept>
#include <nlohmann/json.hpp>

namespace db {

// ────────────────────────────────────────────────────────────
// Тип параметра хранимой процедуры
// ────────────────────────────────────────────────────────────
struct Param {
    enum class Type { Null, Int, Double, String };

    Type        type  = Type::Null;
    int         ival  = 0;
    double      dval  = 0.0;
    std::string sval;

    static Param null()                      { return {}; }
    static Param of(int v)                   { Param p; p.type = Type::Int;    p.ival = v;  return p; }
    static Param of(double v)                { Param p; p.type = Type::Double; p.dval = v;  return p; }
    static Param of(const std::string& v)   { Param p; p.type = Type::String; p.sval = v;  return p; }
    static Param of(const char* v)          { return of(std::string(v)); }
};

// ────────────────────────────────────────────────────────────
// Исключение уровня базы данных
// ────────────────────────────────────────────────────────────
class DatabaseError : public std::runtime_error {
public:
    explicit DatabaseError(const std::string& msg) : std::runtime_error(msg) {}
};

// ────────────────────────────────────────────────────────────
// Основной класс соединения
// ────────────────────────────────────────────────────────────
class Database {
public:
    explicit Database(const std::string& connectionString);
    ~Database();

    // Некопируемый
    Database(const Database&)            = delete;
    Database& operator=(const Database&) = delete;

    // Вызвать хранимую процедуру.
    // Возвращает вектор result-set'ов (каждый — массив объектов JSON).
    // Параметры передаются позиционно в том же порядке, что в DECLARE.
    std::vector<nlohmann::json> execProc(
        const std::string&       procName,
        const std::vector<Param>& params = {}
    );

    // Проверить наличие соединения
    bool isConnected() const;

    // Переподключиться
    void reconnect();

private:
    std::string connStr_;
    SQLHENV     henv_ = SQL_NULL_HENV;
    SQLHDBC     hdbc_ = SQL_NULL_HDBC;

    void connect();
    void disconnect() noexcept;

    // Прочитать один result-set из открытого statement
    nlohmann::json fetchResultSet(SQLHSTMT hstmt);

    // Выбросить DatabaseError с диагностикой ODBC
    [[noreturn]] static void throwOdbcError(
        SQLSMALLINT handleType, SQLHANDLE handle, const std::string& context
    );

    static void checkRC(SQLRETURN rc, SQLSMALLINT ht, SQLHANDLE h, const std::string& ctx) {
        if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
            throwOdbcError(ht, h, ctx);
    }
};

} // namespace db
