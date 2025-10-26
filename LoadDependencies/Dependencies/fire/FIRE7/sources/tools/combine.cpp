/** @file combine.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  Combines integrals from a table into a linear combination
 */
#include <../../extra/fuel/usr/include/flint/fmpz_mpoly.h>
#include <../../extra/fuel/usr/include/flint/nmod_mpoly.h>
#include <chrono>
#include <getopt.h>
#include <iostream>
#include <limits.h>
#include <omp.h>
#include <sstream>
#include <unistd.h>

#include "primes.h"
#include "tables.h"
#include "tools.h"

/**
 * Prime number we use for modular arithmetic.
 */
uint64_t prime = 0;
/**
 * Index of prime number in primes array in primes.cpp.
 */
unsigned short prime_number;

/**
 * Prints help on program usage
 * @param longOptions The struct containing options of the program
 */
void show_help(const option *longOptions) {
    std::cout << "Usage: combine [options] file_combination file_tables file_output. "
                 "Combines integrals from Tables into the combination and prints "
                 "the simplified result\n";

    std::map<std::string, std::string> expl;
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
    expl.emplace("help", "Show this help.");
    expl.emplace("prime", "Set a prime number for modular arithmetics");
    expl.emplace("variables", "Underscore_separated_values to be passes to "
                              "calculation library, d_s_t_y by default");
    expl.emplace("fixed_initial_values_of_variables", "Sets values for some variables like d_100,y_3");
    expl.emplace("parallel", "Simplify in parallel with the use of OpenMP");
    expl.emplace("verbose", "print more information");

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
 * Entry Point for combine.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return successfullness
 */
int main(int argc, char *argv[]) {

    auto start_time = std::chrono::steady_clock::now();

    option longOptions[] = {{"calc", required_argument, nullptr, 'l'},
                            {"variables", required_argument, nullptr, 'v'},
                            {"verbose", no_argument, nullptr, 'V'},
                            {"parallel", no_argument, nullptr, 'P'},
                            {"fixed_initial_values_of_variables", required_argument, nullptr, 'F'},
                            {"prime", required_argument, nullptr, 'p'},
                            {nullptr, 0, nullptr, 0}};
    int c = 0;

    fuel::setLibrary("flint");

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

    bool parallel = false;
    bool verbose = false;
    std::vector<std::string> vars = {"d", "s", "t", "y"};
    std::map<std::string, std::string> fixed_initial_values_of_variables;
    std::string output = "";

    while ((c = getopt_long(argc, argv, shortOptions.str().c_str(), longOptions, nullptr)) != -1) {
        switch (c) {
        case 0:
            break;
        case 'l':
            fuel::setLibrary(std::string(optarg));
            break;
        case 'P':
            parallel = true;
            break;
        case 'V':
            verbose = true;
            break;
        case 'F': {
            fixed_initial_values_of_variables.clear();
            std::istringstream iss(optarg);
            std::string variable;
            while (getline(iss, variable, ',')) {
                size_t pos = variable.find('_');
                if (pos != std::string::npos) {
                    std::string value = variable.substr(pos + 1);
                    if (value[0] == 'p' && value.size() > 1 && value[1] >= '0' && value[1] <= '9') {
                        if (value.size() > 2) {
                            if (value[2] != '^') {
                                cout << "error: the value should be either pN or pN^M, \
with a single-digit N between 0 and 9."
                                     << endl;
                            }
                        }
                        value = std::to_string(primes[values_primes_start + stoi(&value[1])]) + value.substr(2);
                        // value.substr(2) in the line above is the exponent part, e.g. "^5".
                    }
                    fixed_initial_values_of_variables[variable.substr(0, pos)] = value;
                }
            }
        } break;
        case 'p':
            sscanf(optarg, "%hu", &prime_number);
            if (prime_number > 383) {
                cout << "Index for a prime should be in range from 0 to 255, refer to "
                        "primes.cpp"
                     << endl;
                return 1;
            } else {
                prime = primes[prime_number];
            }
            break;
        case 'v': {
            vars.clear();
            std::istringstream iss(optarg);
            string var;
            while (getline(iss, var, '_')) {
                vars.push_back(var);
            }
        } break;
        default:
            printf("Unknown option!\n");
            return 1;
        }
    }

    char current[PATH_MAX];
    if (!getcwd(current, PATH_MAX)) {
        cout << "Can't get current dir name" << endl;
        return 1;
    }
    std::string scurrent = string(current);
    std::string srun = string(argv[0]);
    srun = srun.substr(0, srun.length() - strlen("combine"));

    std::string FIRE_folder;
    if (srun[0] == '/') { // running with full path
        FIRE_folder = "";
    } else { // relative path, using current dir
        FIRE_folder = scurrent + "/";
    }

    if (argc - optind != 3) {
        show_help(longOptions);
        return 1;
    }

    fuel::readLibraryPathsFromFile(FIRE_folder + "../extra/fuel/libraryBinarySettings");
    fuel::initialize(vars, parallel ? omp_get_max_threads() : 1, true, prime);
    fuel::switchToConventional();

    Tables t;
    std::ifstream f(argv[optind + 1]);
    f >> t;
    f.close();
    if (Tables::errorMessage != "") {
        std::cout << "Cannot load table for reason: " << Tables::errorMessage << "\n";
        return 1;
    }

    std::ofstream out(argv[optind + 2]);
    if (out.fail()) {
        std::cout << "Cannot write to output file" << std::endl;
        return 1;
    }

    std::vector<const char *> vars_vector;
    size_t nvars = vars.size();
    vars_vector.resize(nvars);
    size_t i = 0;
    for (const auto &var : vars) {
        vars_vector[i] = var.c_str();
        ++i;
    }

    std::string filename = argv[optind];
    FILE *integral_file;
    if (filename[0] == '/') {
        integral_file = fopen((filename).c_str(), "r");
    } else {
        integral_file = fopen((FIRE_folder + filename).c_str(), "r");
    }
    constexpr size_t LOAD_STR_SIZE = 1024;
    char load_string[LOAD_STR_SIZE] = "none";
    string contents;
    if (integral_file == nullptr) {
        cerr << "File with integral list could not be opened, exiting" << endl;
        return -1;
    }
    while (fgets(load_string, sizeof(load_string), integral_file)) {
        contents += load_string;
    }
    contents = contents.substr(contents.find('{') + 1); //"}"
    for (unsigned int i = 0; i != contents.size(); ++i) {
        if (contents[i] == '\n')
            contents[i] = ' ';
    }
    for (unsigned int i = 0; i != contents.size(); ++i) {
        if (contents[i] == '\r')
            contents[i] = ' ';
    }
    const char *all = contents.c_str();
    int move = 0;
    while (all[move] == ' ') {
        move++;
    }
    std::vector<std::pair<std::string, std::string>> combination;

    while (all[move] != '}') {

        while (all[move] == ' ')
            move++;
        if (all[move] != '{') { // first opening bracket of pair
            cout << "error in integrals: " << all[move] << endl;
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;

        if (all[move] != 'G') {
            cout << "error in integrals: " << all[move] << endl;
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;

        if (all[move] != '[') {
            cout << "error in integrals: " << all[move] << endl;
            abort();
        }
        move++;

        std::string integral = "{";

        while (all[move] != ']') {
            if (all[move] != ' ')
                integral += all[move];
            move++;
        }
        integral += "}";

        move++; // got integral, coming to the coefficient;
        while (all[move] == ' ')
            move++;

        if (all[move] != ',') {
            cout << "error in integrals: " << all[move] << endl;
            abort();
        }
        move++;

        std::string coeff = "";

        while (all[move] != '}') {
            if (all[move] != ' ' && all[move] != '[' && all[move] != ']' && all[move] != '\"')
                coeff += all[move];
            move++;
        }

        move++;

        for (auto itr = fixed_initial_values_of_variables.begin(); itr != fixed_initial_values_of_variables.end();
             ++itr) {
            coeff = replace_all(coeff, itr->first, "(" + itr->second + ")");
        }

        combination.push_back(std::make_pair(integral, coeff));

        while (all[move] != ',' && all[move] != '}')
            ++move;

        if (all[move] == ',')
            ++move;
    }

    std::map<std::string, std::string> inversed_representations;
    std::map<std::string, std::string> representations;
    std::map<std::string, std::vector<std::pair<std::string, std::string>>> relations;

    for (auto &[number, integral] : t.representations) {
        representations.emplace(number, integral);
        inversed_representations.emplace(integral, number);
    }
    for (auto &[number, right] : t.relations) {
        relations.emplace(number, right);
    }

    std::map<std::string, std::string> substituted_combination;
    for (auto &[integral, coeff] : combination) {
        auto titr = inversed_representations.find(integral);
        if (titr == inversed_representations.end()) {
            // integral does not appear in representations
            substituted_combination.emplace(integral, coeff);
        } else {
            std::string number = titr->second;
            auto ritr = relations.find(number);
            if (ritr == relations.end()) {
                // integral does not appear in relations
                auto itr = substituted_combination.find(integral);
                if (itr == substituted_combination.end()) {
                    substituted_combination.emplace(integral, coeff);
                } else {
                    itr->second = itr->second + "+(" + coeff + ")";
                }
            } else {
                const auto &rhs = ritr->second;
                // need to multiply and sum
                for (auto &[number2, coeff2] : rhs) {
                    auto itr2 = representations.find(number2);
                    if (itr2 == representations.end()) {
                        std::cout << "Number not found in table representations " << number2 << endl;
                        abort();
                    }
                    std::string integral2 = itr2->second;
                    auto itr = substituted_combination.find(integral2);
                    if (itr == substituted_combination.end()) {
                        substituted_combination.emplace(integral2, "(" + coeff + ")*(" + coeff2 + ")");
                    } else {
                        itr->second = itr->second + "+(" + coeff + ")*(" + coeff2 + ")";
                    }
                }
            }
        }
    }

    std::vector<std::pair<std::string, std::string>> substituted_combination_vector;
    substituted_combination_vector.resize(substituted_combination.size());

    i = 0;
    for (auto &[integral, coeff] : substituted_combination) {
        substituted_combination_vector[i].first = integral;
        substituted_combination_vector[i].second.swap(coeff);
        ++i;
    }

    auto stop_time = std::chrono::steady_clock::now();
    if (verbose) {
        std::cout << "Combination prepared in "
                  << std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count()
                  << " seconds." << std::endl;
    }

#pragma omp parallel for if (parallel)
    for (size_t i = 0; i != substituted_combination_vector.size(); ++i) {
        auto start_time_local = std::chrono::steady_clock::now();
        auto &[integral, coeff] = substituted_combination_vector[i];
        fuel::simplify(coeff, omp_get_thread_num(), prime);
        if (verbose) {
            auto stop_time_local = std::chrono::steady_clock::now();
            std::cout
                << "Coefficient " << (i + 1) << "/" << substituted_combination_vector.size() << " simplified in "
                << std::chrono::duration_cast<std::chrono::duration<float>>(stop_time_local - start_time_local).count()
                << " seconds." << std::endl;
        }
    }

    stop_time = std::chrono::steady_clock::now();
    if (verbose) {
        std::cout << "Result ready in "
                  << std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count()
                  << " seconds." << std::endl;
    }

    out << "{" << std::endl;
    bool first = true;
    for (auto &[integral, coeff] : substituted_combination_vector) {
        if (first) {
            first = false;
        } else {
            out << "," << std::endl;
        }
        out << "{" << "G[" << integral.substr(1, integral.size() - 2) << "]" << ", " << coeff << "}";
    }
    out << std::endl << "}" << std::endl;
    out.close();

    fuel::close();
    flint_cleanup_master();

    return 0;
}
