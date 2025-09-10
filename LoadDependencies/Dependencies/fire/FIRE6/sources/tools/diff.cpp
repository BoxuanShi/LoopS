#include "tables.h"

#include <iostream>
#include <sstream>
#include <unistd.h>
#include <limits.h>
#include <getopt.h>

string replace_all(string str, const string &from, const string &to) {
    size_t start_pos = 0;
    while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length(); // Handles case where 'to' is a substring of 'from'
    }
    return str;
}

std::pair<std::string, std::string> NumeratorDenominator(const std::string& function) {
    if (function == "0") {
        return make_pair("0", "1");
    }
    std::string function_inv = std::string{"1/("} + function + ")";
    int thread_number = 0;
    fuel::simplify(function_inv, thread_number);
    int brackets = 0;
    size_t pos = 0;
    while (pos != function_inv.size()) {
        if (function_inv[pos] == '(') {
            ++brackets;
        } else if (function_inv[pos] == ')') {
            --brackets;
        } else if (function_inv[pos] == '/' &&brackets == 0) {
            return make_pair(function_inv.substr(pos + 1), function_inv.substr(0, pos));
        }
        ++pos;
    }
    return make_pair("1", function_inv);
}

/**
 * Prints help on program usage
 * @param longOptions The struct containing options of the program
 * @param helpCalc If true, shows detailed help on libraries
 */
void ShowHelp(const option* longOptions) {
    std::cout << "Usage: diff [options] filename1 filename2\n";

    std::map<std::string, std::string> expl;
    expl.emplace("help", "Show this help.");
    std::stringstream calcExpl;
    calcExpl << "Specifies siplification library. \nPossible values are: ";
    for (const auto& lib:  fuel::libraryBinaries) {
        calcExpl << lib.first;
        if (lib.second[0] != '/') {
            calcExpl << "(*)";
        }
        calcExpl << "; ";
    }
    calcExpl << "\n(*) - is shipped with FIRE but might require a ./configure option to work\n(for example, for libraries such as cocoa and ginac not having a built-in prompt we build a wrapper)";
    expl.emplace("calc", calcExpl.str().c_str());
    expl.emplace("variables", "Underscore_separated_values to be passes to calculation library, d_s_t_y by default");
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
        info = replace_all(info, "\n","\n\t");
        while (spaces) {
            info = replace_all(info, "\n","\n ");
            --spaces;
        }
        info = replace_all(info, "\n","\n\t");
        std::cout << info << std::endl;
    }
}

int main(int argc, char * argv[]) {

    option longOptions[] =
        {
                {"calc",  required_argument,      nullptr, 'l'},
                {"variables",  required_argument, nullptr, 'v'},
                {"verbose", no_argument, nullptr, 'V'},
                {nullptr,     0,                  nullptr,  0 }
        };
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

    fuel::setLibrary("fermat");
    bool verbose = false;
    std::vector<std::string> vars = {"d", "s", "t", "y"};
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
            case 'v':
                {
                    vars.clear();
                    std::istringstream iss(optarg);
                    string var;
                    while (getline(iss, var, '_')) {
                        vars.push_back(var);
                    }
                }
                break;
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
    if (srun[0] == '/') {  // running with full path
        FIRE_folder = srun;
    } else { //relative path, using current dir
        FIRE_folder = scurrent + "/" + srun;
    }

    if (argc - optind != 2) {
        ShowHelp(longOptions);
        return 1;
    }

    tables t1;
    std::ifstream f1(argv[optind]);
    f1 >> t1;
    f1.close();
    if (tables::errorMessage != "") {
        std::cout << "Cannot load table 1 for reason: " << tables::errorMessage << "\n";
        return 1;
    }
    tables t2;
    std::ifstream f2(argv[optind + 1]);
    f2 >> t2;
    f2.close();
    if (tables::errorMessage != "") {
        std::cout << "Cannot load table 2 for reason: " << tables::errorMessage << "\n";
        return 1;
    }

    fuel::readLibraryPathsFromFile(FIRE_folder + "../extra/fuel/libraryBinarySettings");
    fuel::initialize(vars, 1, true);
    if (t1 != t2) {
        std::cout << tables::errorMessage << std::endl;
        return 1;
    }
    fuel::close();

    if (verbose) {
        std::cout << "Tables are identical \n";
    }

    return 0;
}
