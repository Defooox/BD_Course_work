#pragma once
// ============================================================
//  Config.h — чтение INI-подобного конфига server.cfg
// ============================================================
#include <string>
#include <unordered_map>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <algorithm>

class Config {
public:
    explicit Config(const std::string& path) {
        std::ifstream f(path);
        if (!f) throw std::runtime_error("Cannot open config: " + path);

        std::string section, line;
        while (std::getline(f, line)) {
            // Trim
            line.erase(0, line.find_first_not_of(" \t\r\n"));
            line.erase(line.find_last_not_of(" \t\r\n") + 1);

            if (line.empty() || line[0] == '#') continue;

            if (line.front() == '[' && line.back() == ']') {
                section = line.substr(1, line.size() - 2);
                continue;
            }

            auto eq = line.find('=');
            if (eq == std::string::npos) continue;

            std::string key = line.substr(0, eq);
            std::string val = line.substr(eq + 1);
            // Trim key/val
            key.erase(key.find_last_not_of(" \t") + 1);
            val.erase(0, val.find_first_not_of(" \t"));
            // Remove inline comment
            auto hash = val.find(" #");
            if (hash != std::string::npos) val = val.substr(0, hash);

            data_[section + "." + key] = val;
        }
    }

    std::string get(const std::string& section,
                    const std::string& key,
                    const std::string& def = "") const
    {
        auto it = data_.find(section + "." + key);
        return (it != data_.end()) ? it->second : def;
    }

    int getInt(const std::string& section,
               const std::string& key,
               int def = 0) const
    {
        auto s = get(section, key);
        return s.empty() ? def : std::stoi(s);
    }

private:
    std::unordered_map<std::string, std::string> data_;
};
