/** @file lcm.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  Calculated the lesser common multiple of all denominators in table
 */
#include <../../extra/fuel/usr/include/flint/fmpz_mpoly.h>
#include <../../extra/fuel/usr/include/flint/nmod_mpoly.h>
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
    std::cout << "Usage: lcm [options] filename. Calculates the least common "
                 "multiple of all denominators and prints it\n";

    std::map<std::string, std::string> expl;
    expl.emplace("help", "Show this help.");
    expl.emplace("prime", "Set a prime number for modular arithmetics");
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
 * Entry Point for lcm.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return successfullness
 */
int main(int argc, char *argv[]) {

    option longOptions[] = {//                {"calc",  required_argument,      nullptr, 'l'},
                            {"variables", required_argument, nullptr, 'v'},
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

    std::vector<std::string> vars = {"d", "s", "t", "y"};
    while ((c = getopt_long(argc, argv, shortOptions.str().c_str(), longOptions, nullptr)) != -1) {
        switch (c) {
        case 0:
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

    fuel::initialize(vars, 1, true, prime);

    char current[PATH_MAX];
    if (!getcwd(current, PATH_MAX)) {
        cout << "Can't get current dir name" << endl;
        return 1;
    }
    std::string scurrent = string(current);
    std::string srun = string(argv[0]);
    srun = srun.substr(0, srun.length() - strlen("lcm"));

    std::string FIRE_folder;
    if (srun[0] == '/') { // running with full path
        FIRE_folder = srun;
    } else { // relative path, using current dir
        FIRE_folder = scurrent + "/" + srun;
    }

    if (argc - optind != 1) {
        show_help(longOptions);
        return 1;
    }

    Tables t;
    std::ifstream f(argv[optind]);
    f >> t;
    f.close();
    if (Tables::errorMessage != "") {
        std::cout << "Cannot load table for reason: " << Tables::errorMessage << "\n";
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
    if (prime == 0) {
        fmpz_mpoly_t res, temp1, temp2;
        fmpz_mpoly_ctx_t ctx;
        fmpz_mpoly_ctx_init(ctx, nvars, ORD_LEX);
        fmpz_mpoly_init(res, ctx);
        fmpz_mpoly_init(temp1, ctx);
        fmpz_mpoly_init(temp2, ctx);
        fmpz_mpoly_set_str_pretty(res, "1", &vars_vector[0], ctx);
        for (const auto &relation : t.relations) {
            for (const auto &term : relation.second) {
                auto pair = numerator_denominator(term.second);
                fmpz_mpoly_set_str_pretty(temp1, pair.second.c_str(), &vars_vector[0], ctx);
                fmpz_mpoly_gcd(temp2, res, temp1, ctx);
                fmpz_mpoly_div(temp1, temp1, temp2, ctx);
                fmpz_mpoly_mul(res, res, temp1, ctx);
            }
        }
        fmpz_mpoly_print_pretty(res, &vars_vector[0], ctx);
        std::cout << std::endl;
        fmpz_mpoly_clear(res, ctx);
        fmpz_mpoly_clear(temp1, ctx);
        fmpz_mpoly_clear(temp2, ctx);
        fmpz_mpoly_ctx_clear(ctx);
    } else {
        nmod_mpoly_t res, temp1, temp2;
        nmod_mpoly_ctx_t ctx;
        nmod_mpoly_ctx_init(ctx, nvars, ORD_LEX, prime);
        nmod_mpoly_init(res, ctx);
        nmod_mpoly_init(temp1, ctx);
        nmod_mpoly_init(temp2, ctx);
        nmod_mpoly_set_str_pretty(res, "1", &vars_vector[0], ctx);
        for (const auto &relation : t.relations) {
            for (const auto &term : relation.second) {
                auto pair = numerator_denominator(term.second);
                nmod_mpoly_set_str_pretty(temp1, pair.second.c_str(), &vars_vector[0], ctx);
                nmod_mpoly_gcd(temp2, res, temp1, ctx);
                nmod_mpoly_div(temp1, temp1, temp2, ctx);
                nmod_mpoly_mul(res, res, temp1, ctx);
            }
        }
        nmod_mpoly_print_pretty(res, &vars_vector[0], ctx);
        std::cout << std::endl;
        nmod_mpoly_clear(res, ctx);
        nmod_mpoly_clear(temp1, ctx);
        nmod_mpoly_clear(temp2, ctx);
        nmod_mpoly_ctx_clear(ctx);
    }

    fuel::close();
    flint_cleanup_master();

    return 0;
}
