/** @file add.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  Adds two Tables saving sum as a third one. They should have same structure
 */

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
    std::cout << "Usage: add [options] filename1 filename2 filename_result\n";

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
    expl.emplace("prime", "Set a prime number for modular arithmetics");
    expl.emplace("substract", "Substract instead of adding");
    expl.emplace("variables", "Underscore_separated_values to be passes to "
                              "calculation library, d_s_t_y by default");
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
 * Entry Point for add.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return 0 if Tables are equal
 */
int main(int argc, char *argv[]) {

    option longOptions[] = {{"calc", required_argument, nullptr, 'l'},
                            {"variables", required_argument, nullptr, 'v'},
                            {"prime", required_argument, nullptr, 'p'},
                            {"verbose", no_argument, nullptr, 'V'},
                            {"substract", no_argument, nullptr, 's'},
                            {nullptr, 0, nullptr, 0}};
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

    fuel::setLibrary("flint");
    bool substract = false;
    std::vector<std::string> vars = {"d", "s", "t", "y"};
    bool verbose = false;
    bool nonzero_output = false;
    while ((c = getopt_long(argc, argv, shortOptions.str().c_str(), longOptions, nullptr)) != -1) {
        switch (c) {
        case 0:
            break;
        case 'V':
            verbose = true;
            break;
        case 'l':
            fuel::setLibrary(std::string(optarg));
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
        case 's':
            substract = true;
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
    srun = srun.substr(0, srun.length() - 4);

    std::string FIRE_folder;
    if (srun[0] == '/') { // running with full path
        FIRE_folder = srun;
    } else { // relative path, using current dir
        FIRE_folder = scurrent + "/" + srun;
    }

    if (argc - optind != 3) {
        show_help(longOptions);
        return 1;
    }

    Tables t1;
    std::ifstream f1(argv[optind]);
    f1 >> t1;
    f1.close();
    if (Tables::errorMessage != "") {
        std::cout << "Cannot load table 1 for reason: " << Tables::errorMessage << "\n";
        return 1;
    }
    Tables t2;
    std::ifstream f2(argv[optind + 1]);
    f2 >> t2;
    f2.close();
    if (Tables::errorMessage != "") {
        std::cout << "Cannot load table 2 for reason: " << Tables::errorMessage << "\n";
        return 1;
    }

    std::map<std::string, std::string> representations_map;

    for (size_t i = 0; i != t1.representations.size(); ++i) {
        representations_map.insert(t1.representations[i]);
    }

    for (size_t i = 0; i != t2.representations.size(); ++i) {
        representations_map.insert(t2.representations[i]);
    }

    t1.representations.clear();

    for (auto &pair : representations_map) {
        t1.representations.push_back(pair);
    }

    std::map<std::string, std::map<std::string, std::string>> relations_map;

    for (size_t i = 0; i != t1.relations.size(); ++i) {
        std::map<std::string, std::string> right;
        for (size_t j = 0; j != t1.relations[i].second.size(); ++j) {
            right.insert(t1.relations[i].second[j]);
        }
        relations_map.insert(std::make_pair(t1.relations[i].first, right));
    }

    for (size_t i = 0; i != t2.relations.size(); ++i) {
        auto itr = relations_map.find(t2.relations[i].first);
        if (itr == relations_map.end()) {
            // relation for something not existing in first table
            std::map<std::string, std::string> right;
            for (size_t j = 0; j != t2.relations[i].second.size(); ++j) {
                right.insert(t2.relations[i].second[j]);
            }
            relations_map.insert(std::make_pair(t2.relations[i].first, right));
        } else {
            // mixing
            auto right = itr->second;
            for (size_t j = 0; j != t2.relations[i].second.size(); ++j) {
                auto term = right.find(t2.relations[i].second[j].first);
                if (term == right.end()) {
                    // again just adding term
                    right.insert(t2.relations[i].second[j]);
                } else {
                    // combining coefficient
                    if (substract)
                        term->second += "-";
                    else
                        term->second += "+";
                    term->second += "(";
                    term->second += t2.relations[i].second[j].second;
                    term->second += ")";
                }
            }
            itr->second = right;
        }
    }

    if (fuel::getLibrary() != "none") {
        fuel::readLibraryPathsFromFile(FIRE_folder + "../extra/fuel/libraryBinarySettings");
        fuel::initialize(vars, 1, true, prime);
        fuel::switchToConventional();
        if (prime != 0) {
            Tables::primeSet = true;
        }
        for (auto &relation : relations_map) {
            for (auto &term : relation.second) {
                fuel::simplify(term.second, 0, prime);
            }
        }
    }
    fuel::close();

    t1.relations.clear();

    for (auto &pair : relations_map) {
        std::vector<std::pair<std::string, std::string>> right;
        for (auto &term : pair.second) {
            if (term.second != "0") {
                right.push_back(term);
                nonzero_output = true;
            }
        }
        t1.relations.push_back(std::make_pair(pair.first, right));
    }

    std::ofstream f3(argv[optind + 2]);
    f3 << t1;
    f3.close();

    if (verbose) {
        if (nonzero_output)
            std::cout << "Nonzero table written" << std::endl;
        else
            std::cout << "Zero table written" << std::endl;
    }

    return nonzero_output ? 1 : 0;
}
