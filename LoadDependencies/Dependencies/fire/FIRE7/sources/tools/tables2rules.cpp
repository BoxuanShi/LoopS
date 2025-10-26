/** @file tables2rules.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  Converts Tables to Mathematica rules
 */

#include <getopt.h>
#include <iomanip>
#include <iostream>
#include <limits.h>
#include <sstream>
#include <unistd.h>

#include "tables.h"
#include "tools.h"

/**
 * Prime number we use for modular arithmetic.
 */
unsigned long long prime;

/**
 * Virtual memory used by current thread (main or flame).
 */
__uint64_t max_vsize = 0;

/**
 * Resident memory used by current thread (main or flame).
 */
__uint64_t max_rss = 0;

/**
 * @param power_level level to print, 0->bytes, 1->kilo, 2->mega, 3->giga
 * @return abbreviation of used unit of memory measurement
 */
inline string mem_symbol(int power_level) {
    switch (power_level) {
    case 0:
        return "b";
        break;
    case 1:
        return "Kb";
        break;
    case 2:
        return "Mb";
        break;
    default:
        return "Gb";
        break;
    }
}

/**
 * Print used memory.
 * @param mem memory ammount measured in bytes
 * @param power_level make output in: 0=bytes, 1=kilo, 2=mega, 3=giga
 */
void print_memory(__uint64_t mem, int power_level) {

    if ((mem < 64) || (power_level == 3)) {
        std::cout << mem << mem_symbol(power_level);
    } else if (mem < 64 * 1024) {
        std::cout << std::setprecision(4) << (mem / 1024.) << std::setprecision(6) << mem_symbol(power_level + 1);
    } else {
        print_memory(mem / 1024, power_level + 1);
    }
}

/**
 * UNIX way to read memory usage to the global vsize and rss variables.
 * @param silent if true, do not print anything
 */
void process_mem_usage(bool silent) {
    using std::ifstream;
    using std::ios_base;
    using std::string;

    ifstream stat_stream("/proc/self/stat", ios_base::in);

    // dummy vars for leading entries in stat that we don't care about
    //
    string pid, comm, state, ppid, pgrp, session, tty_nr;
    string tpgid, flags, minflt, cminflt, majflt, cmajflt;
    string utime, stime, cutime, cstime, priority, nice;
    string O, itrealvalue, starttime;

    // the two fields we want
    //
    __uint64_t vsize;
    __int64_t rss;

    stat_stream >> pid >> comm >> state >> ppid >> pgrp >> session >> tty_nr >> tpgid >> flags >> minflt >> cminflt >>
        majflt >> cmajflt >> utime >> stime >> cutime >> cstime >> priority >> nice >> O >> itrealvalue >> starttime >>
        vsize >> rss; // don't care about the rest

    __int32_t page_size_kb = sysconf(_SC_PAGE_SIZE) / 1024; // in case x86-64 is configured to use 2MB pages
    rss *= page_size_kb;

    __uint64_t urss = rss;

    if ((!silent)) {
        cout << "Memory (virtual|resident): ";
        print_memory(vsize, 0);
        cout << " | ";
        print_memory(rss, 1);
        cout << endl;
    }

    if (vsize > max_vsize)
        max_vsize = vsize;
    if (urss > max_rss)
        max_rss = urss;
    //   vm_usage     = vsize / 1024.0;
    //   resident_set = rss * page_size_kb;
}

/**
 * Prints help on program usage
 * @param longOptions The struct containing options of the program
 */
void show_help(const option *longOptions) {
    std::cout << "Usage: tables2Rules input_filename output_filename\n";

    std::map<std::string, std::string> expl;
    expl.emplace("help", "Show this help.");
    expl.emplace("pairs", "Print pairs of coefficient and integrals instead of multiplications");
    expl.emplace("verbose", "Print more information");

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
 * Entry Point for tables2rules.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return successfullness
 */
int main(int argc, char *argv[]) {

    option longOptions[] = {
        {"verbose", no_argument, nullptr, 'V'}, {"pairs", no_argument, nullptr, 'p'}, {nullptr, 0, nullptr, 0}};
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
    bool verbose = false;
    bool pairs = false;

    while ((c = getopt_long(argc, argv, shortOptions.str().c_str(), longOptions, nullptr)) != -1) {
        switch (c) {
        case 0:
            break;
        case 'V':
            verbose = true;
            break;
        case 'p':
            pairs = true;
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
    if (srun[0] == '/') { // running with full path
        FIRE_folder = srun;
    } else { // relative path, using current dir
        FIRE_folder = scurrent + "/" + srun;
    }

    if (argc - optind != 2) {
        show_help(longOptions);
        return 1;
    }

    Tables t1;
    std::ifstream f1(argv[optind]);
    f1 >> t1;
    f1.close();
    if (Tables::errorMessage != "") {
        std::cout << "Cannot load table for reason: " << Tables::errorMessage << "\n";
        return 1;
    }

    if (verbose) {
        std::cout << "Loaded table \n";
        process_mem_usage(false);
    }
    /**
     * Maps Point numbers to their real representations with indices
     */
    std::map<std::string, std::string> representations;

    for (const auto &[key, value] : t1.representations) {
        representations.emplace(key, value);
    }

    if (verbose) {
        std::cout << "Created a map\n";
        process_mem_usage(false);
    }
    std::ofstream rules(argv[optind + 1]);
    rules << "{\n";

    bool firstRelation = true;

    size_t countPrint = t1.relations.size() / 100;
    size_t count = 0;

    for (const auto &[left, right] : t1.relations) {
        if (!firstRelation) {
            rules << ",\n";
        } else {
            firstRelation = false;
        }
        auto repr = representations[left];
        if (repr[0] == '{' && repr[repr.size() - 1] == '}') {
            rules << "G[" << std::string_view(repr).substr(1, repr.size() - 2) << "]";
        } else {
            rules << repr;
        }
        rules << " -> ";
        bool firstTerm = true;
        if (pairs) {
            rules << "{";
        }
        for (const auto &[term, coeff] : right) {
            if (!firstTerm) {
                if (pairs) {
                    rules << ", ";
                } else {
                    rules << " + ";
                }
            } else {
                firstTerm = false;
            }
            if (pairs) {
                rules << "{" << coeff << ", ";
            } else {
                rules << "(" << coeff << ") * ";
            }
            auto repr = representations[term];
            if (repr[0] == '{' && repr[repr.size() - 1] == '}') {
                rules << "G[" << std::string_view(repr).substr(1, repr.size() - 2) << "]";
            } else {
                rules << repr;
            }
            if (pairs) {
                rules << "}";
            }
        }
        if (pairs) {
            rules << "}";
        }
        if (!pairs && right.empty()) {
            rules << "0";
        }
        ++count;
        if (count == countPrint) {
            if (verbose) {
                process_mem_usage(false);
            }
            count = 0;
        }
    }

    rules << "\n}\n";

    rules.close();

    return 0;
}
