cmake_minimum_required(VERSION 3.20)
project(HockeyLeagueServer CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Зависимости через FetchContent ────────────────────────────
include(FetchContent)

FetchContent_Declare(
    httplib
    GIT_REPOSITORY https://github.com/yhirose/cpp-httplib.git
    GIT_TAG        v0.15.3
)
FetchContent_Declare(
    nlohmann_json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG        v3.11.3
)
FetchContent_MakeAvailable(httplib nlohmann_json)

# ── Исходники ─────────────────────────────────────────────────
add_executable(hockey_server
    src/main.cpp
    src/db/Database.cpp
    src/api/ApiRouter.cpp
)

target_include_directories(hockey_server PRIVATE src)

target_link_libraries(hockey_server PRIVATE
    httplib::httplib
    nlohmann_json::nlohmann_json
    odbc32          # Windows ODBC
)

# ── Конфигурация для разработки ───────────────────────────────
if(MSVC)
    target_compile_options(hockey_server PRIVATE /W4 /utf-8)
    target_compile_definitions(hockey_server PRIVATE
        _WIN32_WINNT=0x0A00   # Windows 10+
        NOMINMAX
        WIN32_LEAN_AND_MEAN
    )
else()
    target_compile_options(hockey_server PRIVATE -Wall -Wextra)
endif()

# копируем конфиг рядом с исполняемым файлом
configure_file(config/server.cfg ${CMAKE_BINARY_DIR}/server.cfg COPYONLY)
