/** @file tools.h
 *
 *  This file is a part of the FIRE package and contains some universal
 * functions implementations
 */
#include "tools.h"

#include <filesystem>
#include <iostream>
#include <string>

std::vector<std::string> global_params; ///< for safer fork-exec

std::string subfolder_path(std::string filename, int folders_limit, bool create) {
    if (folders_limit == 0) {
        return filename;
    }
    auto path = std::filesystem::path(filename);
    auto folder_path = path.parent_path();
    unsigned int max_exponent = 0;
    std::string name = path.filename();
    for (size_t pos = 0; pos != name.size(); ++pos) {
        if (name[pos] == '^') {
            unsigned int exponent;
            sscanf(name.c_str() + pos + 1, "%u", &exponent);
            if (exponent > max_exponent) {
                max_exponent = exponent;
            }
        }
    }
    if (max_exponent != 0) {
        folder_path /= std::to_string(max_exponent / folders_limit);
        if (create) {
            std::filesystem::create_directory(folder_path);
        }
    }
    folder_path /= path.filename();
    return folder_path.string();
}

int s2i_tools(const char *digit, int &result) {
    int sign = 1;
    result = 0;
    int move = 0;
    //--- Convert each digit char and add into result.
    while ((*(digit + move) >= '0' && *(digit + move) <= '9') || *(digit + move) == '-') {
        if (*(digit + move) == '-') {
            sign = -1;
        } else {
            result = (result * 10) + (*(digit + move) - '0');
        }
        move++;
    }
    result = result * sign;
    return move;
}

int exponent(const std::string &function, const std::string &var) {
    size_t pos = 0;
    int res = 0;
    size_t var_size = var.size();
    size_t function_size = function.size();
    while (true) {
        pos = function.find(var, pos);
        if (pos == std::string::npos) {
            break;
        }
        if (pos > 0 && isalpha(function[pos - 1])) {
            ++pos;
            continue;
        }
        if (pos + var_size < function_size && isalpha(function[pos + var_size])) {
            ++pos;
            continue;
        }
        int current_degree = 1;
        if (pos + var_size < function_size && function[pos + var_size] == '^') {
            s2i_tools(function.c_str() + pos + var_size + 1, current_degree);
        }
        if (current_degree > res) {
            res = current_degree;
        }
        ++pos;
    }
    return res;
}

std::pair<std::string, std::string> numerator_denominator(const std::string &function, bool allowFuelCall) {
    if (function == "0") {
        return std::make_pair("0", "1");
    }
    size_t pos = 0;
    pos = function.find("/");
    if (pos == std::string::npos) {
        if (function.size() >= 6 && function[0] == '(' && function.substr(function.size() - 6) == ")^(-1)") {
            // (4 - d)^(-1)
            return std::make_pair("1", function.substr(1, function.size() - 7));
        }
        if (function.size() >= 6 && function.substr(function.size() - 5) == "^(-1)") {
            // d^(-1)
            return std::make_pair("1", function.substr(0, function.size() - 5));
        }
        // no division on a normal function
        return std::make_pair(function, "1");
    }
    if (function.find("/", pos + 1) == std::string::npos) {
        if (function[0] == '-') {
            // std::cout << "Changing sing: " << function << std::endl;
            auto res = numerator_denominator(std::string(function.c_str() + 1), allowFuelCall);
            return std::make_pair("-(" + res.first + ")", res.second);
        }
        if (function[0] == '(' && function[pos - 1] == ')' && function[pos + 1] == '(' &&
            function[function.size() - 1] == ')') {
            return std::make_pair(std::string(function.c_str() + 1, pos - 2),
                                  std::string(function.c_str() + pos + 2, function.size() - pos - 3));
        } else if (function[0] == '(' && function[pos - 1] == ')') {
            bool good = true;
            for (size_t pos_check = pos + 1; pos_check != function.size(); ++pos_check) {
                if (!std::isalpha(function[pos_check]) && !std::isdigit(function[pos_check])) {
                    good = false;
                    break;
                }
            }
            if (good) {
                // that's a number or variable after the /
                return std::make_pair(std::string(function.c_str() + 1, pos - 2),
                                      std::string(function.c_str() + pos + 1, function.size() - pos - 1));
            }
        } else if (function[pos + 1] == '(' && function[function.size() - 1] == ')') {
            bool good = true;
            for (size_t pos_check = 0; pos_check != pos; ++pos_check) {
                if (!std::isalpha(function[pos_check]) && !std::isdigit(function[pos_check])) {
                    good = false;
                    break;
                }
            }
            if (good) {
                // that's a number or variable before the /
                return std::make_pair(std::string(function.c_str(), pos),
                                      std::string(function.c_str() + pos + 2, function.size() - pos - 3));
            }
        } else {
            bool good = true;
            for (size_t pos_check = 0; pos_check != function.size(); ++pos_check) {
                if (pos_check != pos) {
                    if (!std::isalpha(function[pos_check]) && !std::isdigit(function[pos_check])) {
                        good = false;
                        break;
                    }
                }
            }
            if (good) {
                // that's a number or variable both before and after the /
                return std::make_pair(std::string(function.c_str(), pos),
                                      std::string(function.c_str() + pos + 1, function.size() - pos - 1));
            }
        }
    }

    if (allowFuelCall) {
        std::string local_function = function;
        std::cout << "Calling fuel: " << local_function << std::endl;
        fuel::simplify(local_function, 0, false);
        std::cout << "Called fuel: " << local_function << std::endl;
        return numerator_denominator(local_function, false);
    }
    std::cout << "NumeratorDenumenator internal logic error: " << std::endl << function << std::endl;
    abort();
}

std::string replace_all(std::string str, const std::string &from, const std::string &to) {
    size_t start_pos = 0;
    while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length(); // Handles case where 'to' is a substring of 'from'
    }
    return str;
}

bool parse_config(const std::string &filename, std::string &folder, std::string &path_to_tables,
                  std::string &masters_split_string, std::string &database_path, std::vector<std::string> &vars) {

    FILE *file;
    file = fopen(filename.c_str(), "r");
    if (file == nullptr) {
        std::cout << "No " << filename << ", exiting!\n";
        return false;
    }
    vars.clear();
    char load_string[1000] = "none";
    while (fgets(load_string, 1000, file)) {
        if (!strncmp(load_string, "#folder", 7)) {
            int pos = 7;
            while (load_string[pos] == ' ')
                pos++;
            folder = std::string(load_string + pos);
            auto poss = folder.find('\n');
            if (poss != std::string::npos) {
                folder = folder.substr(0, poss);
            }
            path_to_tables = folder;
        }
        if (!strncmp(load_string, "#database", 9)) {
            int pos = 9;
            while (load_string[pos] == ' ')
                pos++;
            database_path = std::string(load_string + pos);
            auto poss = database_path.find('\n');
            if (poss != std::string::npos) {
                database_path = database_path.substr(0, poss);
            }
            if (database_path[database_path.size() - 1] != '/') {
                database_path = database_path + "/";
            }
        }
        if (!strncmp(load_string, "#output", 7)) {
            int pos = 7;
            while (load_string[pos] == ' ')
                pos++;
            if (load_string[pos] == '/')
                path_to_tables = ""; // ignoring folder settings for absolute paths
            path_to_tables = path_to_tables + std::string(load_string + pos);
            auto poss = path_to_tables.find('\n');
            if (poss != std::string::npos) {
                path_to_tables = path_to_tables.substr(0, poss);
            }
        }
        if (!strncmp(load_string, "#masters", 8)) {
            unsigned int master_number_min = 0;
            unsigned int master_number_max = 0;

            size_t pos = 8;
            while (load_string[pos] == ' ')
                pos++;

            if (load_string[pos] == '|') {
                // that's the split masters mode
                const char *poss = load_string + pos;
                ++poss;
                while ((*poss) && (*poss != '|') && (*poss != '-'))
                    ++poss;
                if (!(*poss)) {
                    printf("Incorrect syntax for master file (no second |)\n");
                    return false;
                }
                if (*poss == '-') {
                    sscanf(load_string + pos, "|%u-%u|", &master_number_min, &master_number_max);
                } else {
                    sscanf(load_string + pos, "|%u|", &master_number_min);
                    master_number_max = master_number_min;
                }
                if (!master_number_min) {
                    printf("Incorrect syntax for master file\n");
                    return false;
                }
                if (master_number_max < master_number_min) {
                    printf("Incorrect range of master integrals\n");
                    return false;
                }
                masters_split_string =
                    "." + std::to_string(master_number_min) + "-" + std::to_string(master_number_max);
            }
        } else if (!strncmp(load_string, "#variables", 10)) {
            size_t pos = 10;
            while (load_string[pos] == ' ')
                pos++;
            constexpr size_t COEFF_BUF_SIZE = 128;
            char variables_temp[COEFF_BUF_SIZE];
            strcpy(variables_temp, (load_string + pos));
            char *begin = variables_temp;
            char *now = variables_temp;
            bool mode_right = false;
            std::string left;
            while (*now != '\0') {
                if (*now == '\n') {
                    *now = ',';
                }
                if (*now == ',') {
                    *now = '\0';
                    if (mode_right) { // a variable replacement rule
                        std::string right = begin;
                        mode_right = false;
                        left = "";
                    } else {
                        vars.push_back(std::string(begin));
                    }
                    now++;
                    begin = now;
                } else if (*now == ' ') {
                    now++;
                    begin++;
                } else if ((*now == '-') && (now[1] == '>')) { // left side of a rule
                    *now = '\0';
                    left = begin;
                    now++;
                    now++;
                    begin = now;
                    mode_right = true;
                } else {
                    now++;
                }
            }
        }
    }
    fclose(file);
    return true;
}

int run_process(std::vector<std::string> params, int RANK, pid_t &pid, bool verbose) {
    if (params.size() > 32) {
        printf("Internal error, call to process with 32 or more parameters\n");
        abort();
    }
    auto start_time = std::chrono::steady_clock::now();
    char *run_args[32];
    unsigned int i = 0;
    global_params = params;
    while (i != global_params.size()) {
        // const_cast due to old style of execv syntax
        run_args[i] = const_cast<char *>(global_params[i].c_str());
        ++i;
    }
    run_args[i] = nullptr;
    if (verbose) {
        printf("CALLING (%d): ", RANK);
        for (i = 0; run_args[i] != nullptr; ++i)
            printf("%s ", run_args[i]);
        printf("\n");
    }
    pid = vfork();
    if (pid == -1) {
        printf("Error on fork\n");
        abort();
    } else if (pid > 0) {
        // that's the parent process
        int status;
        waitpid(pid, &status, 0);
        if (WIFSIGNALED(status)) {
            printf("CALLED PROCESS %d EXITED AFTER SIGNAL %d: %s\n", RANK, WTERMSIG(status),
                   strsignal(WTERMSIG(status)));
            return -1;
        } else if (!WIFEXITED(status)) {
            printf("CALLED PROCESS %d EXITED WITH ERROR STATUS %d\n", RANK, status);
            return -1;
        } else {
            auto stop_time = std::chrono::steady_clock::now();
            if (verbose) {
                printf("CALL (%d) ended with return value %d after %f seconds\n", RANK, WEXITSTATUS(status),
                       std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count());
            }
            return WEXITSTATUS(status);
        }
    } else {
        // that's the child process
        execv(run_args[0], run_args);
        perror("execve");
        for (i = 0; run_args[i] != nullptr; ++i)
            fprintf(stderr, "%s ", run_args[i]);
        fprintf(stderr, "\n");
        abort();
    }
}
