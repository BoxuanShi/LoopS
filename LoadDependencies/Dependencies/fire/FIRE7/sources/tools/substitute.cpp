/** @file substitute.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  Substitutes values for variables into a table and possibly brings in to
 * modular arithmetics
 */

#include <../../extra/fuel/usr/include/flint/fmpq_mpoly.h>
#include <../../extra/fuel/usr/include/flint/nmod.h>
#include <getopt.h>
#include <iostream>
#include <limits.h>
#include <sstream>
#include <unistd.h>

#include "primes.h"
#include "tables.h"
#include "tools.h"

/**
 * Prime number we use for modular arithmetic.
 */
uint64_t prime;
/**
 * Index of prime number in primes array in primes.cpp.
 */
unsigned short prime_number;

/**
 * Prints help on program usage
 * @param longOptions The struct containing options of the program
 */
void show_help(const option *longOptions) {
    std::cout << "Usage: substitute [options] filename. The output filename is "
                 "generated automatically based on substitutions\n"
              << "Alternatevely pass a config file argument with -c and omit the "
                 "filename. The filename will be taken from the config, all variables "
                 "should be replaced, values will be prepended before .tables\n";

    std::map<std::string, std::string> expl;
    expl.emplace("help", "Show this help.");
    std::stringstream calcExpl;
    calcExpl << "Specifies siplification library. \nPossible values are: ";
    for (const auto &lib : fuel::libraryBinaries) {
        calcExpl << lib.first;
        if (lib.second[0] != '/') {
            calcExpl << "(*)";
        }
        calcExpl << "; ";
    }
    calcExpl << "\n(*) - is shipped with FIRE but might require a ./configure "
                "option to work\n(for example, for libraries such as cocoa and "
                "ginac not having a built-in prompt we build a wrapper)";
    expl.emplace("calc", calcExpl.str().c_str());
    expl.emplace("prime", "Substitute a prime number for modular arithmetics");
    expl.emplace("variables", "Like d_41,s_53,t; all variables should be listed. The ones not followed "
                              "with an underscore won't be substituted. If a config is provided, no "
                              "names are needed, values are underscore_separated");
    expl.emplace("config", "Path to file with config, one should omit extension '.config'. "
                           "If it is provided, all variables should be substituted");
    expl.emplace("suffix", "Appended suffix to the file read from config");
    expl.emplace("parallel", "Dummy option to be compatible with FIRE calls");
    expl.emplace("large_variables", "Dummy option to be compatible with FIRE calls");
    expl.emplace("quiet", "Dummy option to be compatible with FIRE calls");
    expl.emplace("QUIET", "Dummy option to be compatible with FIRE calls");

    for (auto current_option = longOptions; current_option->name != nullptr; ++current_option) {
        auto expl_itr = expl.find(current_option->name);
        std::string value;
        if (expl_itr != expl.end()) {
            value = expl_itr->second;
        } else {
            value = "NO EXPLANATION YET!";
        }
        printf("\t");
        size_t spaces = 0;
        if (current_option->val > 32) {
            printf("-%c", static_cast<char>(current_option->val));
            spaces += 2;
            if (current_option->has_arg == required_argument) {
                printf(" <value>");
                spaces += 8;
            }
            printf(", ");
            spaces += 2;
        }
        printf("--%s", current_option->name);
        spaces += 2;
        spaces += strlen(current_option->name);
        if (current_option->has_arg == required_argument) {
            printf(" <value>");
            spaces += 8;
        }
        while (spaces < 27) {
            printf(" ");
            ++spaces;
        }
        printf("\t");
        std::string info{value};
        info = replace_all(info, "\n", "\n\t");
        while (spaces) {
            info = replace_all(info, "\n", "\n ");
            --spaces;
        }
        info = replace_all(info, "\n", "\n\t");
        std::cout << info << std::endl;
    }
}

/**
 * Entry Point for substitute.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return 0 if Tables are equal
 */
int main(int argc, char *argv[]) {

    option longOptions[] = {
        {"calc", required_argument, nullptr, 'l'},      {"variables", required_argument, nullptr, 'v'},
        {"prime", required_argument, nullptr, 'p'},     {"config", required_argument, nullptr, 'c'},
        {"suffix", required_argument, nullptr, 's'},    {"parallel", no_argument, nullptr, '1'},
        {"large_variables", no_argument, nullptr, 'V'}, {"quiet", no_argument, nullptr, 'q'},
        {"QUIET", no_argument, nullptr, 'Q'},           {nullptr, 0, nullptr, 0}};
    int c = 0;

    std::stringstream shortOptions;
    for (auto current_option = longOptions; current_option->name != nullptr; ++current_option) {
        if (current_option->val > 32) {
            shortOptions << static_cast<char>(current_option->val);
            if (current_option->has_arg == required_argument) {
                shortOptions << ':';
            } else if (current_option->has_arg == optional_argument) {
                shortOptions << "::";
            }
        }
    }

    std::string suffix = {};
    std::string masters_split_string = {};  ///< the suffix due to partial masters in the table name
    std::string path_to_tables = {};        ///< the starting part of table name
    std::string database_path = "temp/db/"; ///< the place for temporary files
    std::vector<std::string> vars;          ///< the variables
    fuel::setLibrary("flint");
    std::map<std::string, std::string> variable_replacements = {};
    std::string variable_setting = "";
    bool config_provided = false;
    std::string folder;
    while ((c = getopt_long(argc, argv, shortOptions.str().c_str(), longOptions, nullptr)) != -1) {
        switch (c) {
        case 0:
            break;
        case 'l':
            fuel::setLibrary(std::string(optarg));
            break;
        case 'c':
            config_provided = true;
            if (!parse_config(std::string(optarg) + ".config", folder, path_to_tables, masters_split_string,
                              database_path, vars)) {
                return 1;
            }
            break;
        case 'p':
            sscanf(optarg, "%hu", &prime_number);
            if (prime_number > 255) {
                cout << "Index for a prime should be in range from 0 to 255, refer to "
                        "primes.cpp"
                     << endl;
                return 1;
            } else {
                prime = primes[prime_number];
            }
            break;
        case 'v':
            variable_setting = optarg;
            break;
        case 's':
            suffix = optarg;
            break;
        default:
            break;
            //                printf("Unknown option (%s)!\n", optarg);
            //                return 1;
        }
    }

    char current[PATH_MAX];
    if (!getcwd(current, PATH_MAX)) {
        cout << "Can't get current dir name" << endl;
        return 1;
    }
    std::string scurrent = string(current);
    std::string srun = string(argv[0]);
    srun = srun.substr(0, srun.length() - strlen("substitute"));

    std::string FIRE_folder;
    if (srun[0] == '/') { // running with full path
        FIRE_folder = srun;
    } else { // relative path, using current dir
        FIRE_folder = scurrent + "/" + srun;
    }

    if (argc - optind + config_provided != 1) {
        show_help(longOptions);
        return 1;
    }

    size_t vars_index = 0;
    if (!variable_setting.empty()) {
        if (!config_provided) {
            vars.clear();
        }
        variable_replacements.clear();
        std::istringstream iss(variable_setting);
        string setting;
        while (getline(iss, setting, (config_provided ? '_' : ','))) {
            if (setting[0] == '{') {
                setting = setting.substr(1);
            }
            if (setting[setting.size() - 1] == '}') {
                setting = setting.substr(0, setting.size() - 1);
            }
            if (config_provided) {
                if (vars_index < vars.size()) {
                    variable_replacements.emplace(vars[vars_index], setting);
                } else if (vars_index == vars.size()) {
                    sscanf(setting.c_str(), "%hu", &prime_number);
                    if (prime_number > 255) {
                        cout << "Index for a prime should be in range from 0 to 255, refer "
                                "to primes.cpp"
                             << endl;
                        return 1;
                    } else {
                        prime = primes[prime_number];
                    }
                } else {
                    std::cout << "Too many variable values with a config passed\n";
                    return 1;
                }
                ++vars_index;
            } else {
                size_t setting_pos = setting.find("_");
                if (setting_pos == std::string::npos) {
                    vars.push_back(setting);
                } else {
                    vars.push_back(setting.substr(0, setting_pos));
                    variable_replacements.emplace(setting.substr(0, setting_pos), setting.substr(setting_pos + 1));
                }
            }
        }
    }

    if (config_provided && vars_index != vars.size() + 1) {
        std::cout << "All variables and prime number should be set with a config "
                     "provided\n";
        return 1;
    }

    if (variable_replacements.empty() && prime_number == 0) {
        std::cout << "No replacements were set\n";
        return 1;
    }

    std::string old_filename;
    std::string filename;

    if (config_provided) {
        old_filename = path_to_tables + suffix;
        if (path_to_tables.substr(path_to_tables.size() - 7) == ".tables") {
            path_to_tables = path_to_tables.substr(0, path_to_tables.size() - 7);
        }
        std::stringstream res;
        res << path_to_tables;
        for (size_t i = 0; i != vars.size(); ++i) {
            res << "_";
            res << variable_replacements.find(vars[i])->second;
        }
        res << "_";
        res << prime_number;
        res << masters_split_string;
        res << ".tables";
        res << suffix;
        filename = res.str();
    } else {
        old_filename = argv[optind];
        filename = argv[optind];
        if (prime_number != 0) {
            size_t pos_replacement = filename.find(std::string{"_0."});
            if (pos_replacement == string::npos) {
                std::cout << "No pattern _0. for replacement in filename" << std::endl;
                return 1;
            }
            pos_replacement++;
            filename.replace(pos_replacement, 1, std::to_string(prime_number));
        }

        for (const auto &replacement : variable_replacements) {
            size_t pos_replacement = filename.find(std::string{"_"} + replacement.first + "_");
            if (pos_replacement == string::npos) {
                std::cout << "No pattern _" << replacement.first << "_ for replacement in filename" << std::endl;
                return 1;
            }
            pos_replacement++;
            filename.replace(pos_replacement, replacement.first.size(), replacement.second);
        }
    }

    Tables t;
    std::ifstream f(old_filename);
    f >> t;
    f.close();
    if (Tables::errorMessage != "") {
        std::cout << "Cannot load table for reason: " << Tables::errorMessage << "\n";
        return 1;
    }

    fmpz_mpoly_t temp_pol;
    fmpz_mpoly_ctx_t ctx;
    fmpz_t orig_coeff;
    size_t nvars = variable_replacements.size();
    std::vector<const char *> vars_vector;
    nmod_t flint_mod = {};
    if (prime) {
        nmod_init(&flint_mod, prime);
        for (auto itr = variable_replacements.rbegin(); itr != variable_replacements.rend(); ++itr) {
            bool big_prime = false;
            auto value = itr->second;
            if (value[0] == 'p') {
                big_prime = true;
                value = value.substr(1);
            }
            auto pos = value.find("^");
            if (pos != std::string::npos) {
                unsigned long base = stoul(value);
                if (big_prime) {
                    base = primes[base + values_primes_start];
                }
                unsigned long exp = stoul(value.c_str() + pos + 1);
                itr->second = std::to_string(nmod_pow_ui(base, exp, flint_mod));
            }
        }
    }

    if (config_provided) {
        fmpz_mpoly_ctx_init(ctx, nvars, ORD_LEX);
        vars_vector.resize(nvars);
        size_t i = 0;
        for (const auto &pair : variable_replacements) {
            vars_vector[i] = pair.first.c_str();
            ++i;
        }
        fmpz_mpoly_init(temp_pol, ctx);
        fmpz_init(orig_coeff);
    }

    fuel::readLibraryPathsFromFile(FIRE_folder + "../extra/fuel/libraryBinarySettings");
    fuel::initialize(vars, 1, true, prime);
    fuel::switchToConventional();

    unsigned long exp[16];
    for (auto &relation : t.relations) {
        for (auto &term : relation.second) {
            if (config_provided) {
                auto pair = numerator_denominator(term.second, true);
                fmpz_mpoly_set_str_pretty(temp_pol, pair.first.c_str(), &vars_vector[0], ctx);
                unsigned len = fmpz_mpoly_length(temp_pol, ctx);
                mp_limb_t num = 0;
                for (unsigned ii = 0; ii != len; ++ii) {
                    fmpz_mpoly_get_term_coeff_fmpz(orig_coeff, temp_pol, ii, ctx);
                    mp_limb_t prod = fmpz_mod_ui(orig_coeff, orig_coeff, prime);
                    fmpz_mpoly_get_term_exp_ui(exp, temp_pol, ii, ctx);
                    size_t i = 0;
                    for (const auto &pair : variable_replacements) {
                        mp_limb_t temp = stoul(pair.second);
                        temp = nmod_pow_ui(temp, exp[i], flint_mod);
                        prod = nmod_mul(prod, temp, flint_mod);
                        ++i;
                    }
                    num = nmod_add(num, prod, flint_mod);
                }
                fmpz_mpoly_set_str_pretty(temp_pol, pair.second.c_str(), &vars_vector[0], ctx);
                len = fmpz_mpoly_length(temp_pol, ctx);
                mp_limb_t denom = 0;
                for (unsigned ii = 0; ii != len; ++ii) {
                    fmpz_mpoly_get_term_coeff_fmpz(orig_coeff, temp_pol, ii, ctx);
                    mp_limb_t prod = fmpz_mod_ui(orig_coeff, orig_coeff, prime);
                    fmpz_mpoly_get_term_exp_ui(exp, temp_pol, ii, ctx);
                    size_t i = 0;
                    for (const auto &pair : variable_replacements) {
                        mp_limb_t temp = stoul(pair.second);
                        temp = nmod_pow_ui(temp, exp[i], flint_mod);
                        prod = nmod_mul(prod, temp, flint_mod);
                        ++i;
                    }
                    denom = nmod_add(denom, prod, flint_mod);
                }
                denom = nmod_inv(denom, flint_mod);
                num = nmod_mul(num, denom, flint_mod);
                term.second = std::to_string(num);
            } else {
                for (auto itr = variable_replacements.rbegin(); itr != variable_replacements.rend(); ++itr) {
                    term.second = replace_all(term.second, itr->first, std::string{"("} + itr->second + ")");
                }
                fuel::simplify(term.second, 0, prime);
            }
        }
    }

    if (config_provided) {
        fmpz_mpoly_clear(temp_pol, ctx);
        fmpz_mpoly_ctx_clear(ctx);
        fmpz_clear(orig_coeff);
    }

    fuel::close();

    std::ofstream of(filename);
    of << t;
    of.close();

    return 0;
}
