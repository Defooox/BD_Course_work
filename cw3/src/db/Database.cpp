// ============================================================
//  Database.cpp — реализация ODBC-обёртки
// ============================================================
#include "Database.h"

#include <sstream>
#include <stdexcept>
#include <algorithm>

namespace db {

// ────────────────────────────────────────────────────────────
// Конструктор / деструктор
// ────────────────────────────────────────────────────────────
Database::Database(const std::string& connectionString)
    : connStr_(connectionString)
{
    connect();
}

Database::~Database()
{
    disconnect();
}

// ────────────────────────────────────────────────────────────
// Подключение
// ────────────────────────────────────────────────────────────
void Database::connect()
{
    // Allocate environment
    SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &henv_);
    SQLSetEnvAttr(henv_, SQL_ATTR_ODBC_VERSION, (SQLPOINTER)SQL_OV_ODBC3, 0);

    // Allocate connection
    SQLAllocHandle(SQL_HANDLE_DBC, henv_, &hdbc_);

    // Connect
    SQLCHAR outConnStr[1024] = {};
    SQLSMALLINT outLen = 0;

    SQLRETURN rc = SQLDriverConnectA(
        hdbc_,
        nullptr,
        (SQLCHAR*)connStr_.c_str(),
        SQL_NTS,
        outConnStr,
        sizeof(outConnStr),
        &outLen,
        SQL_DRIVER_NOPROMPT
    );

    if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO) {
        throwOdbcError(SQL_HANDLE_DBC, hdbc_, "SQLDriverConnect");
    }

    // Autocommit включён по умолчанию — нам подходит
    SQLSetConnectAttr(hdbc_, SQL_ATTR_AUTOCOMMIT, (SQLPOINTER)SQL_AUTOCOMMIT_ON, 0);
}

void Database::disconnect() noexcept
{
    if (hdbc_ != SQL_NULL_HDBC) {
        SQLDisconnect(hdbc_);
        SQLFreeHandle(SQL_HANDLE_DBC, hdbc_);
        hdbc_ = SQL_NULL_HDBC;
    }
    if (henv_ != SQL_NULL_HENV) {
        SQLFreeHandle(SQL_HANDLE_ENV, henv_);
        henv_ = SQL_NULL_HENV;
    }
}

bool Database::isConnected() const
{
    if (hdbc_ == SQL_NULL_HDBC) return false;
    SQLUINTEGER dead = SQL_CD_FALSE;
    SQLGetConnectAttr(hdbc_, SQL_ATTR_CONNECTION_DEAD, &dead, 0, nullptr);
    return dead == SQL_CD_FALSE;
}

void Database::reconnect()
{
    disconnect();
    connect();
}

// ────────────────────────────────────────────────────────────
// Вызов хранимой процедуры
// ────────────────────────────────────────────────────────────
std::vector<nlohmann::json> Database::execProc(
    const std::string&        procName,
    const std::vector<Param>& params)
{
    // Проверяем соединение
    if (!isConnected()) reconnect();

    SQLHSTMT hstmt = SQL_NULL_HSTMT;
    SQLAllocHandle(SQL_HANDLE_STMT, hdbc_, &hstmt);

    // Строим ODBC escape-синтаксис: {CALL sp_Name(?,?,?)}
    std::string call = "{CALL " + procName + "(";
    for (size_t i = 0; i < params.size(); ++i) {
        call += (i > 0 ? ",?" : "?");
    }
    call += ")}";

    // Привязываем параметры
    // Значения должны жить до завершения SQLExecute — храним буферы здесь
    struct ParamBuf {
        SQLLEN  ind    = 0;
        int     ival   = 0;
        double  dval   = 0.0;
        std::string sval;
    };
    std::vector<ParamBuf> bufs(params.size());

    for (size_t i = 0; i < params.size(); ++i) {
        const auto& p = params[i];
        auto& b = bufs[i];
        SQLUSMALLINT col = static_cast<SQLUSMALLINT>(i + 1);

        if (p.type == Param::Type::Null) {
            b.ind = SQL_NULL_DATA;
            SQLBindParameter(hstmt, col,
                SQL_PARAM_INPUT, SQL_C_CHAR, SQL_VARCHAR,
                0, 0, nullptr, 0, &b.ind);
        }
        else if (p.type == Param::Type::Int) {
            b.ival = p.ival;
            b.ind  = 0;
            SQLBindParameter(hstmt, col,
                SQL_PARAM_INPUT, SQL_C_LONG, SQL_INTEGER,
                0, 0, &b.ival, 0, &b.ind);
        }
        else if (p.type == Param::Type::Double) {
            b.dval = p.dval;
            b.ind  = 0;
            SQLBindParameter(hstmt, col,
                SQL_PARAM_INPUT, SQL_C_DOUBLE, SQL_DOUBLE,
                0, 0, &b.dval, 0, &b.ind);
        }
        else { // String
            b.sval = p.sval;
            b.ind  = SQL_NTS;
            SQLBindParameter(hstmt, col,
                SQL_PARAM_INPUT, SQL_C_CHAR, SQL_WVARCHAR,
                b.sval.size(), 0,
                const_cast<char*>(b.sval.c_str()),
                b.sval.size() + 1, &b.ind);
        }
    }

    // Выполняем
    SQLRETURN rc = SQLExecDirectA(hstmt, (SQLCHAR*)call.c_str(), SQL_NTS);
    if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO && rc != SQL_NO_DATA) {
        std::string err = "SQLExecDirect [" + procName + "]";
        // Сохраняем ошибку до освобождения statement
        SQLCHAR state[6], msg[SQL_MAX_MESSAGE_LENGTH];
        SQLINTEGER native; SQLSMALLINT len;
        std::string details;
        SQLSMALLINT rec = 1;
        while (SQLGetDiagRecA(SQL_HANDLE_STMT, hstmt, rec++, state, &native,
                               msg, sizeof(msg), &len) == SQL_SUCCESS) {
            details += std::string((char*)state) + ": " + std::string((char*)msg, len) + "\n";
        }
        SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
        throw DatabaseError(err + " — " + details);
    }

    // Читаем все result-set'ы
    std::vector<nlohmann::json> results;
    do {
        SQLSMALLINT colCount = 0;
        SQLNumResultCols(hstmt, &colCount);
        if (colCount > 0) {
            results.push_back(fetchResultSet(hstmt));
        }
    } while (SQLMoreResults(hstmt) == SQL_SUCCESS);

    SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
    return results;
}

// ────────────────────────────────────────────────────────────
// Чтение одного result-set в JSON-массив
// ────────────────────────────────────────────────────────────
nlohmann::json Database::fetchResultSet(SQLHSTMT hstmt)
{
    SQLSMALLINT colCount = 0;
    SQLNumResultCols(hstmt, &colCount);

    // Получаем имена и типы колонок
    struct ColInfo {
        std::string name;
        SQLSMALLINT sqlType;
        SQLULEN     colSize;
    };
    std::vector<ColInfo> cols(colCount);

    for (SQLSMALLINT i = 0; i < colCount; ++i) {
        SQLCHAR colName[256] = {};
        SQLSMALLINT nameLen, dataType, decDigits, nullable;
        SQLULEN colSize;

        SQLDescribeColA(hstmt, i + 1,
            colName, sizeof(colName), &nameLen,
            &dataType, &colSize, &decDigits, &nullable);

        cols[i].name    = std::string((char*)colName, nameLen);
        cols[i].sqlType = dataType;
        cols[i].colSize = (colSize == 0 || colSize > 4096) ? 4096 : colSize;
    }

    // Читаем строки
    nlohmann::json rows = nlohmann::json::array();

    while (SQLFetch(hstmt) == SQL_SUCCESS) {
        nlohmann::json row = nlohmann::json::object();

        for (SQLSMALLINT i = 0; i < colCount; ++i) {
            const auto& col = cols[i];
            SQLLEN ind = 0;

            // Числовые типы
            if (col.sqlType == SQL_INTEGER  || col.sqlType == SQL_SMALLINT ||
                col.sqlType == SQL_TINYINT  || col.sqlType == SQL_BIGINT)
            {
                SQLBIGINT val = 0;
                SQLGetData(hstmt, i + 1, SQL_C_SBIGINT, &val, 0, &ind);
                row[col.name] = (ind == SQL_NULL_DATA) ? nlohmann::json(nullptr)
                                                       : nlohmann::json((int64_t)val);
            }
            else if (col.sqlType == SQL_REAL   || col.sqlType == SQL_FLOAT ||
                     col.sqlType == SQL_DOUBLE  || col.sqlType == SQL_NUMERIC ||
                     col.sqlType == SQL_DECIMAL)
            {
                double val = 0.0;
                SQLGetData(hstmt, i + 1, SQL_C_DOUBLE, &val, 0, &ind);
                row[col.name] = (ind == SQL_NULL_DATA) ? nlohmann::json(nullptr)
                                                       : nlohmann::json(val);
            }
            else if (col.sqlType == SQL_BIT) {
                SQLCHAR val = 0;
                SQLGetData(hstmt, i + 1, SQL_C_BIT, &val, 0, &ind);
                row[col.name] = (ind == SQL_NULL_DATA) ? nlohmann::json(nullptr)
                                                       : nlohmann::json(val != 0);
            }
            else {
                // Строки, даты, время — всё конвертируем в строку
                std::vector<char> buf(col.colSize + 2);
                SQLGetData(hstmt, i + 1, SQL_C_CHAR,
                    buf.data(), (SQLLEN)buf.size(), &ind);
                if (ind == SQL_NULL_DATA)
                    row[col.name] = nullptr;
                else
                    row[col.name] = std::string(buf.data(),
                        std::min((SQLLEN)(buf.size() - 1), ind));
            }
        }
        rows.push_back(std::move(row));
    }

    return rows;
}

// ────────────────────────────────────────────────────────────
// Формирование сообщения об ошибке ODBC
// ────────────────────────────────────────────────────────────
void Database::throwOdbcError(SQLSMALLINT ht, SQLHANDLE h, const std::string& ctx)
{
    std::ostringstream oss;
    oss << "ODBC error in [" << ctx << "]: ";

    SQLCHAR   state[6], msg[SQL_MAX_MESSAGE_LENGTH];
    SQLINTEGER native;
    SQLSMALLINT len;
    SQLSMALLINT rec = 1;

    while (SQLGetDiagRecA(ht, h, rec++, state, &native,
                          msg, sizeof(msg), &len) == SQL_SUCCESS) {
        oss << "[" << state << "] " << std::string((char*)msg, len) << " ";
    }

    throw DatabaseError(oss.str());
}

} // namespace db
