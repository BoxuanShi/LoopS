/** @file reconstruction.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  It performs table recostructions with various methods
 */

#include "reconstruction.h"

#include "primes.h"
#ifdef WITH_GPU
#include "gpu.h"
#endif

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <functional>
#include <getopt.h>
#include <iostream>
#include <limits.h>
#include <numeric>
#include <omp.h>
#include <sstream>
#include <string>
#include <unistd.h>
#include <vector>

using namespace fuel::mod_uni_ratfunc_flint;

/**
 * The exponents switch limit for Tables saving
 */
int folders_limit = 0;

/**
 * The number of threads for zippel parallel evaluation of a single coefficient
 */
int zippel_openmp_threads = 1;

/**
 * Prime number we use for modular arithmetic.
 */
uint64_t prime;
/**
 * Index of prime number in primes array in primes.cpp.
 */
unsigned short prime_number;

/**
 * the limb for flint prime
 */
mp_limb_t flint_prime = prime;

/**
 * the special flint structure for fast inverting modular prime
 */
nmod_t flint_mod = {};

bool big_prime = false; ///< whether we are using the bif primes mode indicated with p

/**
 * all variables in use
 */
std::vector<std::string> vars = {"d", "s", "t"};

std::string skel_var_value = "";  ///< for balancedZippel the base value of the skeleton variable
unsigned long skel_var_power = 0; ///< for balancedZippel it is the power we are reconstructing at,
                                  ///< for balancedZippelNewton it is the limit

/**
 * Performs thiele reconstruction of expressions
 * @param points the reconstruction points
 * @param values the function values in those points
 * @param symbol reconstruction variable
 * @param silent whether not to produce messages
 * @return result and the number of needed steps, -1 in case of failure
 */
std::pair<std::string, long> thiele(const std::vector<std::string> &points, const std::vector<std::string> &values,
                                    std::string symbol, bool silent) {
    std::pair<std::string, long> answer;
    int thread_number = 0; // what thread are we referring to
    long int NumberOfPoints = points.size();
    std::vector<std::string> coeffs(NumberOfPoints, "0");
    long int steps = 0;
    bool is_stable = false;
    std::string temp;
    long int n;
    long int i;
    std::string result;

    std::vector<rational_function> coeffs_rfun(NumberOfPoints, 0ul);
    std::vector<rational_function> points_rfun(NumberOfPoints, 0ul);
    rational_function temp_rfun, diff_rfun;
    if (prime) {
        rational_function zero(0ul);
        for (i = 0; i < NumberOfPoints; i++) {
            points_rfun[i] = rational_function(stoul(points[i]));
        }
        for (i = 0; i < NumberOfPoints; i++) {
            temp_rfun = rational_function(values[i].c_str());
            for (long int j = 0; j < i; j++) {
                diff_rfun = temp_rfun - coeffs_rfun[j];
                if (diff_rfun == zero) {
                    if (!silent) {
                        std::cout << "thiele reconstruction by " << symbol << " stable after " << i << " steps"
                                  << std::endl;
                    }
                    steps = i;
                    is_stable = true;
                    break;
                }
                temp_rfun = (points_rfun[i] - points_rfun[j]) / diff_rfun;
            }
            if (is_stable) {
                break;
            }
            coeffs_rfun[i] = temp_rfun;
        }
    } else {
        for (i = 0; i < NumberOfPoints; i++) {
            temp = values[i];
            for (long int j = 0; j < i; j++) {
                string diff = "(" + temp + "-(" + coeffs[j] + "))";
                fuel::simplify(diff, thread_number, prime != 0);
                if (diff == "0") {
                    if (!silent) {
                        std::cout << "thiele reconstruction by " << symbol << " stable after " << i << " steps"
                                  << std::endl;
                    }
                    steps = i;
                    is_stable = true;
                    break;
                }
                temp = "(" + points[i] + "-" + points[j] + ")" + "/" + "(" + diff + ")";
                fuel::simplify(temp, thread_number, prime != 0);
            }
            if (is_stable) {
                break;
            }
            coeffs[i] = temp;
        }
    }

    if (!is_stable) {
        if (!silent) {
            std::cout << "thiele reconstruction by " << symbol << " is unstable with " << NumberOfPoints << " points"
                      << std::endl;
        }
        answer = std::make_pair("", -1l); // None, -1
        return answer;
    }

    n = i - 1;

    if (prime) {
        rational_function result_rfun = coeffs_rfun[n];
        rational_function symbol_rfun = rational_function(symbol.c_str());
        for (long int i = (n - 1); i >= 0; i--) {
            result_rfun = coeffs_rfun[i] + ((symbol_rfun - points_rfun[i]) / result_rfun);
        }
        return std::make_pair(result_rfun.to_string(), steps);
    } else {
        result = coeffs[n];
        for (long int i = (n - 1); i >= 0; i--) {
            result = coeffs[i] + "+" + "(" + symbol + "-" + points[i] + ")" + "/" + "(" + result + ")";
            fuel::simplify(result, thread_number, prime != 0);
        }

        fuel::setOption("no_store_expressions");
        if (steps != -1) {
            fuel::simplify(result, thread_number, prime != 0);
        }
        fuel::setOption("clear_stored_expressions");
        fuel::setOption("store_expressions");
        answer = std::make_pair(result, steps);
        return answer;
    }
}

/**
 * Performs Newton reconstruction of expressions
 * @param ctx the flint context with variables
 * @param result_num the return parameter for numerator
 * @param result_denom the return parameter for denumenator (appears when a factor is passed)
 * @param vars_vector vector of variables
 * @param symbol_pos the position of reocnstruction variable in all variables
 * @param points_number the reconstruction points
 * @param coeffs_poly the function values in those points
 * @param symbol reconstruction variable
 * @param factor the multiplication factor for the values
 * @param silent whether not to produce messages
 * @return The number of needed steps, -1 in case of failure
 */
long newton_prime(nmod_mpoly_ctx_t &ctx, nmod_mpoly_t &result_num, nmod_mpoly_t &result_denom,
                  std::vector<const char *> &vars_vector, int symbol_pos, const std::vector<mp_limb_t> &points_number,
                  nmod_mpoly_struct *coeffs_poly, std::string symbol, std::string factor, bool silent) {

    long int NumberOfPoints = points_number.size();
    bool is_stable = false;
    std::string temp;
    long int n;
    long int i;
    nmod_mpoly_t temp_poly;
    nmod_mpoly_t temp2_poly;
    nmod_mpoly_t factor_poly;
    nmod_mpoly_init(temp_poly, ctx);
    nmod_mpoly_init(temp2_poly, ctx);
    nmod_mpoly_init(factor_poly, ctx);
    nmod_mpoly_set_str_pretty(factor_poly, factor.c_str(), &vars_vector[0], ctx);
    long int steps = 0;
    unsigned long exp[16];
    for (i = 0; i < NumberOfPoints; i++) {
        nmod_mpoly_set(temp_poly, coeffs_poly + i, ctx);
        if (factor != "1") {
            mp_limb_t subs = 0;
            unsigned len = nmod_mpoly_length(factor_poly, ctx);
            for (unsigned j = 0; j != len; ++j) {
                nmod_mpoly_get_term_exp_ui(exp, factor_poly, j, ctx);
                mp_limb_t prod = points_number[i];
                prod = nmod_pow_ui(prod, exp[symbol_pos], flint_mod);
                mp_limb_t coeff = nmod_mpoly_get_term_coeff_ui(factor_poly, j, ctx);
                prod = nmod_mul(prod, coeff, flint_mod);
                subs = nmod_add(subs, prod, flint_mod);
            }
            nmod_mpoly_scalar_mul_ui(temp_poly, temp_poly, subs, ctx);
        }
        for (long int j = 0; j < i; j++) {
            nmod_mpoly_sub(temp_poly, temp_poly, coeffs_poly + j, ctx);
            if (nmod_mpoly_is_zero(temp_poly, ctx)) {
                if (!silent) {
                    std::cout << "Newton reconstruction by " << symbol << " stable after " << i << " steps"
                              << std::endl;
                }
                steps = i;
                is_stable = true;
                break;
            }
            mp_limb_t p = nmod_sub(points_number[i], points_number[j], flint_mod);
            p = nmod_inv(p, flint_mod);
            nmod_mpoly_scalar_mul_ui(temp_poly, temp_poly, p, ctx);
        }
        if (is_stable) {
            break;
        }
        nmod_mpoly_set(coeffs_poly + i, temp_poly, ctx);
    }
    if (!is_stable) {
        if (!silent) {
            std::cout << "Newton reconstruction by " << symbol << " is unstable with " << NumberOfPoints << " points"
                      << std::endl;
        }
        nmod_mpoly_clear(temp_poly, ctx);
        nmod_mpoly_clear(temp2_poly, ctx);
        nmod_mpoly_clear(factor_poly, ctx);
        return -1l;
    }

    n = i - 1;
    nmod_mpoly_set(temp_poly, coeffs_poly + n, ctx);
    for (long int i = (n - 1); i >= 0; i--) {
        nmod_mpoly_set_str_pretty(temp2_poly, symbol.c_str(), &vars_vector[0], ctx);
        nmod_mpoly_sub_ui(temp2_poly, temp2_poly, points_number[i], ctx);
        nmod_mpoly_mul(temp2_poly, temp2_poly, temp_poly, ctx);
        nmod_mpoly_add(temp_poly, temp2_poly, coeffs_poly + i, ctx);
    }

    if (factor != "1") {
        nmod_mpoly_gcd(temp2_poly, temp_poly, factor_poly, ctx);
        nmod_mpoly_div(temp_poly, temp_poly, temp2_poly, ctx);
        nmod_mpoly_div(factor_poly, factor_poly, temp2_poly, ctx);
    }
    nmod_mpoly_set(result_num, temp_poly, ctx);
    nmod_mpoly_set(result_denom, factor_poly, ctx);
    nmod_mpoly_clear(temp_poly, ctx);
    nmod_mpoly_clear(temp2_poly, ctx);
    nmod_mpoly_clear(factor_poly, ctx);
    return steps;
}

/**
 * Performs Newton reconstruction of expressions
 * @param points the reconstruction points
 * @param values the function values in those points
 * @param symbol reconstruction variable
 * @param factor the multiplication factor for the values
 * @param silent whether not to produce messages
 * @return result and the number of needed steps, -1 in case of failure
 */
std::pair<std::string, long> newton(const std::vector<std::string> &points, const std::vector<std::string> &values,
                                    std::string symbol, std::string factor, bool silent) {

    std::pair<std::string, long> answer;
    int thread_number = 0; // what thread are we referring to
    long int NumberOfPoints = points.size();
    std::vector<std::string> coeffs(NumberOfPoints, "0");
    long int steps = 0;
    bool is_stable = false;
    std::string temp;
    long int n;
    long int i;

    nmod_mpoly_ctx_t ctx;
    nmod_mpoly_struct *coeffs_poly;
    std::vector<mp_limb_t> points_number;

    size_t nvars = vars.size();
    if (prime) {
        int symbol_pos = -1;
        for (unsigned i = 0; i != nvars; ++i) {
            if (vars[i] == symbol) {
                symbol_pos = i;
            }
        }
        if (symbol_pos == -1) {
            std::cout << "Reconstruction var not found in vars\n";
            abort();
        }
        nmod_mpoly_ctx_init(ctx, nvars, ORD_LEX, flint_prime);
        std::vector<const char *> vars_vector;
        vars_vector.resize(nvars);
        size_t i = 0;
        for (const auto &var : vars) {
            vars_vector[i] = var.c_str();
            ++i;
        }
        points_number.reserve(points.size());
        for (i = 0; i != points.size(); ++i) {
            mp_limb_t temp = stoul(points[i]);
            points_number.push_back(temp);
        }
        coeffs_poly = static_cast<nmod_mpoly_struct *>(malloc(values.size() * sizeof(nmod_mpoly_struct)));
        if (coeffs_poly == nullptr) {
            std::cout << "Cannot allocate memory\n";
            abort();
        }
        for (unsigned i = 0; i != values.size(); ++i) {
            nmod_mpoly_init(coeffs_poly + i, ctx);
        }
        for (unsigned i = 0; i < NumberOfPoints; i++) {
            nmod_mpoly_set_str_pretty(coeffs_poly + i, values[i].c_str(), &vars_vector[0], ctx);
        }
        nmod_mpoly_t result_num;
        nmod_mpoly_t result_denom;
        nmod_mpoly_init(result_num, ctx);
        nmod_mpoly_init(result_denom, ctx);
        int steps = newton_prime(ctx, result_num, result_denom, vars_vector, symbol_pos, points_number, coeffs_poly,
                                 symbol, factor, silent);
        for (unsigned i = 0; i != values.size(); ++i) {
            nmod_mpoly_clear(coeffs_poly + i, ctx);
        }
        std::string result;
        if (steps == -1) {
            result = "1";
        } else {
            char *res_num_char = nmod_mpoly_get_str_pretty(result_num, &vars_vector[0], ctx);
            char *res_denom_char = nmod_mpoly_get_str_pretty(result_denom, &vars_vector[0], ctx);
            if (std::string(res_denom_char) != "1") {
                result = std::string{"("} + std::string(res_num_char) + ")/(" + std::string(res_denom_char) + ")";
            } else {
                result = std::string(res_num_char);
            }
            free(res_num_char);
            free(res_denom_char);
        }
        nmod_mpoly_clear(result_num, ctx);
        nmod_mpoly_clear(result_denom, ctx);
        free(coeffs_poly);
        nmod_mpoly_ctx_clear(ctx);
        return std::make_pair(result, steps);
    } else {

        for (i = 0; i < NumberOfPoints; i++) {
            temp = values[i];

            if (factor != "1") {
                temp = "(" + temp + ")*(" + replace_all(factor, symbol, points[i]) + ")";
            }

            for (long int j = 0; j < i; j++) {
                temp = "(" + temp + "-(" + coeffs[j] + "))" + "/" + "(" + points[i] + "-" + points[j] + ")";
                fuel::simplify(temp, thread_number, prime != 0);
                if (temp == "0") {
                    if (!silent) {
                        std::cout << "Newton reconstruction by " << symbol << " stable after " << i << " steps"
                                  << std::endl;
                    }
                    steps = i;
                    is_stable = true;
                    break;
                }
            }
            if (is_stable) {
                break;
            }
            coeffs[i] = temp;
        }
        if (!is_stable) {
            if (!silent) {
                std::cout << "Newton reconstruction by " << symbol << " is unstable with " << NumberOfPoints
                          << " points" << std::endl;
            }
            answer = std::make_pair("1", -1l); // None, -1
            return answer;
        }

        n = i - 1;
        temp = coeffs[n];
        for (long int i = (n - 1); i >= 0; i--) {
            temp = coeffs[i] + "+" + "(" + symbol + "-" + points[i] + ")" + "*" + "(" + temp + ")";
            fuel::simplify(temp, thread_number, prime != 0);
        }
        if (factor != "1") {
            temp = "(" + temp + ")/(" + factor + ")";
            fuel::simplify(temp, thread_number, prime != 0);
        }
        answer = std::make_pair(temp, steps);
        return answer;
    }
}

/**
 * Restores an integer by its projection to mudular fields
 * @param res place for result
 * @param r remainders
 * @param m primes
 * @param size their number
 * @param buffer the tempory buffer that should be initilized with at least 4 numbers
 */
void chinese_remainder(fmpz *res, const fmpz *r, const fmpz *m, size_t size, fmpz *buffer) {
    fmpz *prod = buffer;
    fmpz *total = buffer + 1;
    fmpz *p = buffer + 2;
    fmpz *inv = buffer + 3;
    fmpz_one(prod);
    size_t length = size;
    for (size_t i = 0; i < length; ++i) {
        fmpz_mul(prod, prod, m + i);
    }
    fmpz_zero(total);
    for (size_t i = 0; i < length; i++) {
        fmpz_tdiv_q(p, prod, m + i);
        fmpz_invmod(inv, p, m + i);
        fmpz_mul(p, p, inv);
        fmpz_mul(p, p, r + i);
        fmpz_add(total, total, p);
    }
    fmpz_mod(res, total, prod);
}

/**
 * Improved algorithm to reconstruct a best possible rational by ints projection and fiels
 * @param num place to save result numerator
 * @param denom place to save result denumenator
 * @param a projection
 * @param p field definition
 * @param buffer the tempory buffer that should be initilized with at least 9 numbers
 */
void reconstruct_fraction_wang(fmpz *num, fmpz *denom, const fmpz *a, const fmpz *p, fmpz *buffer) {
    fmpz *g = buffer;
    fmpz *s = buffer + 1;
    fmpz *g1 = buffer + 2;
    fmpz *s1 = buffer + 3;
    fmpz *multiple = buffer + 4;
    fmpz *temp_g = buffer + 5;
    fmpz *temp_s = buffer + 6;
    fmpz *temp = buffer + 7;
    fmpz *zero = buffer + 8;

    fmpz_set(g, p);
    fmpz_zero(s);
    fmpz_set(g1, a);
    fmpz_one(s1);
    fmpz_zero(zero);
    while (true) {
        fmpz_mul(temp, g1, g1);
        fmpz_mul_si(temp, temp, 2);
        if (fmpz_cmp(temp, p) <= 0) {
            break;
        }
        fmpz_tdiv_q(multiple, g, g1);
        fmpz_set(temp_g, g);
        fmpz_set(temp_s, s);
        fmpz_set(g, g1);
        fmpz_set(s, s1);
        fmpz_mul(g1, multiple, g1);
        fmpz_neg(g1, g1);
        fmpz_add(g1, temp_g, g1);
        fmpz_mul(s1, multiple, s1);
        fmpz_neg(s1, s1);
        fmpz_add(s1, temp_s, s1);
    }
    if (fmpz_cmp(s1, zero) < 0) {
        fmpz_neg(g1, g1);
        fmpz_neg(s1, s1);
    }
    fmpz_set(num, g1);
    fmpz_set(denom, s1);
}

/**
 * Reconstructs a best possible rational by ints projection and fiels
 * @param num place to save result numerator
 * @param denom place to save result denumenator
 * @param a projection
 * @param p field definition
 * @param buffer the tempory buffer that should be initilized with at least 20 numbers (9 for Wang)
 */
void reconstruct_fraction(fmpz *num, fmpz *denom, const fmpz *a, const fmpz *p, fmpz *buffer) {
    if (fmpz_is_zero(a)) {
        fmpz_zero(num);
        fmpz_one(denom);
        return;
    }

    fmpz *g = buffer;
    fmpz *s = buffer + 1;
    fmpz *g1 = buffer + 2;
    fmpz *s1 = buffer + 3;
    fmpz *multiple = buffer + 4;
    fmpz *temp_g = buffer + 5;
    fmpz *temp_s = buffer + 6;
    fmpz *n = buffer + 7;
    fmpz *d = buffer + 8;
    fmpz *t_parameter = buffer + 9;
    fmpz *zero = buffer + 10;

    fmpz_set(g, p);
    fmpz_zero(s);
    fmpz_set(g1, a);
    fmpz_one(s1);
    fmpz_zero(n);
    fmpz_zero(d);
    fmpz_set_ui(t_parameter, 128);
    fmpz_zero(zero);

    while (!fmpz_is_zero(g1) && (fmpz_cmp(g, t_parameter) > 0)) {
        fmpz_tdiv_q(multiple, g, g1);
        if (fmpz_cmp(multiple, t_parameter) > 0) {
            fmpz_set(n, g1);
            fmpz_set(d, s1);
            fmpz_set(t_parameter, multiple);
        }
        fmpz_set(temp_g, g);
        fmpz_set(temp_s, s);
        fmpz_set(g, g1);
        fmpz_set(s, s1);
        fmpz_mul(g1, multiple, g1);
        fmpz_neg(g1, g1);
        fmpz_add(g1, temp_g, g1);
        fmpz_mul(s1, multiple, s1);
        fmpz_neg(s1, s1);
        fmpz_add(s1, temp_s, s1);
    }
    if (fmpz_is_zero(d)) // fall back to previous algorithm
        return reconstruct_fraction_wang(num, denom, a, p, buffer + 11);
    if (fmpz_cmp(d, zero) < 0) {
        fmpz_neg(n, n);
        fmpz_neg(d, d);
    }
    fmpz_set(num, n);
    fmpz_set(denom, d);
}

/**
 * Performs rational reconstruction of numbers
 * @param num place to save result numerator
 * @param denom place to save result denumenator
 * @param points the reconstruction points
 * @param values the function values in those points
 * @param size the size fo points and values
 * @param buffer the tempory buffer that should be initilized with at least 29 numbers (20 go for
 * reconstruct_fraction)
 * @param silent whether not to produce messages
 * @return the number of needed steps, -1 in case of failure
 */
int rational_reconstruct(fmpz_t num, fmpz_t denom, const fmpz *points, const fmpz *values, size_t size, fmpz *buffer,
                         bool silent) {
    int steps = 0;
    fmpz *prod = buffer;
    fmpz *res = buffer + 1;
    fmpz *num_prev = buffer + 2;
    fmpz *denom_prev = buffer + 3;
    fmpz *vec1 = buffer + 4;
    fmpz *vec2 = buffer + 6;
    fmpz_one(prod);
    fmpz_zero(res);
    fmpz_zero(num_prev);
    fmpz_zero(denom_prev); // they surely won't be equal in first cycle
    size_t aa_size = size;
    for (size_t i = 0; i < aa_size; i++) {
        fmpz_set(vec1 + 0, res);
        fmpz_set(vec1 + 1, values + i);
        fmpz_set(vec2 + 0, prod);
        fmpz_set(vec2 + 1, points + i);
        chinese_remainder(res, vec1, vec2, 2, buffer + 8);
        fmpz_mul(prod, prod, points + i);
        reconstruct_fraction(num, denom, res, prod, buffer + 8);
        if (fmpz_equal(num, num_prev) && fmpz_equal(denom, denom_prev)) {
            if (!silent)
                std::cout << "Rational reconstruction stable after " << steps << " steps" << std::endl;
            return steps;
        }
        fmpz_set(num_prev, num);
        fmpz_set(denom_prev, denom);
        steps++;
    }

    if (!silent)
        std::cout << "Rational reconstruction unstable" << std::endl;
    return -1;
}

/**
 * Performs rational reconstruction of coefficients in expressions
 * @param points the reconstruction points
 * @param values the function values in those points
 * @param silent whether not to produce messages
 * @return result and the number of needed steps, -1 in case of failure
 */
std::pair<std::string, long> rational_reconstruct_multiple(const fmpz *points, std::vector<string> &values,
                                                           bool silent) {

    fmpz *used_points = _fmpz_vec_init(values.size());
    fmpz *used_values = _fmpz_vec_init(values.size());
    size_t len = values.size();

    fmpz_mpoly_ctx_t ctx;
    size_t nvars = vars.size();
    fmpz_mpoly_ctx_init(ctx, nvars, ORD_LEX);
    fmpz_t coeff1, coeff2, lcm, lcm_limit, temp;
    fmpz_init(coeff1);
    fmpz_init(coeff2);
    fmpz_init(lcm_limit);
    fmpz_init(lcm);
    fmpz_init(temp);
    std::vector<const char *> vars_vector;
    vars_vector.resize(nvars);
    size_t i = 0;
    for (const auto &var : vars) {
        vars_vector[i] = var.c_str();
        ++i;
    }
    fmpz_mpoly_t num;
    fmpz_mpoly_t denom;
    fmpz_mpoly_t gcd;
    fmpz_mpoly_init(num, ctx);
    fmpz_mpoly_init(denom, ctx);
    fmpz_mpoly_init(gcd, ctx);
    auto nums = static_cast<fmpz_mpoly_struct *>(malloc(values.size() * sizeof(fmpz_mpoly_struct)));
    if (nums == nullptr) {
        std::cout << "Cannot allocate memory\n";
        abort();
    }
    auto denoms = static_cast<fmpz_mpoly_struct *>(malloc(values.size() * sizeof(fmpz_mpoly_struct)));
    if (denoms == nullptr) {
        std::cout << "Cannot allocate memory\n";
        abort();
    }
    size_t num_len = 0;
    size_t denom_len = 0;
    for (unsigned i = 0; i != values.size(); ++i) {
        // std::cout << i << std::endl;
        auto pair = numerator_denominator(values[i]);
        values[i] = "";
        fmpz_mpoly_init(nums + i, ctx);
        fmpz_mpoly_init(denoms + i, ctx);
        fmpz_mpoly_set_str_pretty(nums + i, pair.first.c_str(), &vars_vector[0], ctx);
        fmpz_mpoly_set_str_pretty(denoms + i, pair.second.c_str(), &vars_vector[0], ctx);
        size_t cur_num_len = fmpz_mpoly_length(nums + i, ctx);
        size_t cur_denom_len = fmpz_mpoly_length(denoms + i, ctx);
        if (cur_num_len > num_len) {
            num_len = cur_num_len;
        }
        if (cur_denom_len > denom_len) {
            denom_len = cur_denom_len;
        }
    }
    std::vector<int> used_indices;
    used_indices.reserve(len);

    for (unsigned i = 0; i != values.size(); ++i) {
        size_t cur_num_len = fmpz_mpoly_length(nums + i, ctx);
        size_t cur_denom_len = fmpz_mpoly_length(denoms + i, ctx);
        if ((cur_num_len == num_len) && (cur_denom_len == denom_len)) {
            used_indices.push_back(i);
            fmpz_set(used_points + i, points + i);
        }
    }
    if (used_indices.size() != len) {
        if (!silent) {
            std::cout << "Some of the Tables had less numbers in representations and were removed, "
                         "new length is "
                      << used_indices.size() << std::endl;
        }
    }
    len = used_indices.size();
    long ops = 0;
    fmpz_set_ui(lcm, 1);
    fmpz_set_ui(lcm_limit, 1);
    for (unsigned int j = 0; j != len; ++j) {
        fmpz_mul(lcm_limit, lcm_limit, used_points + j);
    }
    fmpz_mul(lcm_limit, lcm_limit, lcm_limit); // to be safe

    fmpz *num_nums = _fmpz_vec_init(num_len);
    fmpz *num_denoms = _fmpz_vec_init(num_len);
    fmpz *denom_nums = _fmpz_vec_init(denom_len);
    fmpz *denom_denoms = _fmpz_vec_init(denom_len);
    size_t buf_size = 30;
    fmpz *buffer = _fmpz_vec_init(buf_size);

    bool bad_lcm = false;
    for (int k = 1; k <= 2; ++k) {
        // checking correctness of exps
        int poly_len = ((k == 1) ? num_len : denom_len);
        // std::cout << k << "/" << poly_len << std::endl;
        fmpz_mpoly_struct *pols = ((k == 1) ? nums : denoms);
        fmpz *coeff_nums = ((k == 1) ? num_nums : denom_nums);
        fmpz *coeff_denoms = ((k == 1) ? num_denoms : denom_denoms);
        for (int i = 0; i != poly_len; ++i) {
            unsigned long exp[16];
            fmpz_mpoly_get_term_exp_ui(exp, pols + used_indices[0], i, ctx);
            for (unsigned int j = 0; j != len; ++j) {
                unsigned long cur_exp[16];
                fmpz_mpoly_get_term_exp_ui(cur_exp, pols + used_indices[j], i, ctx);
                for (unsigned int l = 0; l != vars.size(); ++l) {
                    if (exp[l] != cur_exp[l]) {
                        std::cout << "Serious reconstruction error, please report!!!!! \n";
                        abort();
                    }
                }
                fmpz_mpoly_get_term_coeff_fmpz(coeff1, pols + used_indices[j], i, ctx);
                fmpz_mpoly_get_term_coeff_fmpz(coeff2, nums + used_indices[j], 0,
                                               ctx); // that's the first numerator term, we are balancing
                fmpz_invmod(temp, coeff2, used_points + j);
                fmpz_mul(temp, temp, coeff1);
                fmpz_mod(used_values + j, temp, used_points + j);
            }
            long res =
                rational_reconstruct(coeff_nums + i, coeff_denoms + i, used_points, used_values, len, buffer, true);
            if (ops != -1l) {
                if (res == -1l) {
                    ops = -1l;
                } else if (res > ops) {
                    ops = res;
                }
            }
            // we are collecting ol coefficients of result, they are rationals
            fmpz_lcm(lcm, lcm, coeff_denoms + i); // calculating lcm of denominators
            if (fmpz_cmp(lcm, lcm_limit) > 0) {
                bad_lcm = true;
                break;
            }
        }
        if (bad_lcm) {
            break;
        }
    }

    std::string res_string;
    if (!bad_lcm) {
        for (int k = 1; k <= 2; ++k) {
            int poly_len = ((k == 1) ? num_len : denom_len);
            // std::cout << k << "/" << poly_len << std::endl;
            fmpz_mpoly_struct *pols = ((k == 1) ? nums : denoms);
            fmpz_mpoly_struct *poly = ((k == 1) ? num : denom);
            fmpz *coeff_nums = ((k == 1) ? num_nums : denom_nums);
            fmpz *coeff_denoms = ((k == 1) ? num_denoms : denom_denoms);
            fmpz_mpoly_resize(poly, poly_len, ctx);
            for (int i = 0; i != poly_len; ++i) {
                unsigned long exp[16];
                fmpz_mpoly_get_term_exp_ui(exp, pols + used_indices[0], i, ctx);
                fmpz_divexact(coeff_denoms + i, lcm, coeff_denoms + i);
                // we are multiplying by lcm; divided lcm by denominator, the quotient will go into
                // numerator
                fmpz_mul(coeff_nums + i, coeff_nums + i,
                         coeff_denoms + i); // now coeff 1 is the real coeff
                fmpz_mpoly_set_term_exp_ui(poly, i, exp, ctx);
                fmpz_mpoly_set_term_coeff_fmpz(poly, i, coeff_nums + i, ctx);
            }
        }

        for (unsigned i = 0; i != values.size(); ++i) {
            fmpz_mpoly_clear(nums + i, ctx);
            fmpz_mpoly_clear(denoms + i, ctx);
        }
        _fmpz_vec_clear(num_nums, num_len);
        _fmpz_vec_clear(num_denoms, num_len);
        _fmpz_vec_clear(denom_nums, denom_len);
        _fmpz_vec_clear(denom_denoms, denom_len);

        // canceling gcd; we have only num, denom and gcd as large objects
        fmpz_mpoly_gcd(gcd, num, denom, ctx);
        fmpz_mpoly_div(num, num, gcd, ctx);
        fmpz_mpoly_div(denom, denom, gcd, ctx);
        fmpz_mpoly_clear(gcd, ctx);
        char *res_num = fmpz_mpoly_get_str_pretty(num, &vars_vector[0], ctx);
        fmpz_mpoly_clear(num, ctx);
        res_string = "(" + std::string(res_num) + ")/(";
        free(res_num);
        char *res_denom = fmpz_mpoly_get_str_pretty(denom, &vars_vector[0], ctx);
        fmpz_mpoly_clear(denom, ctx);
        res_string += std::string(res_denom);
        res_string += ")";
        free(res_denom);
    } else {
        for (unsigned i = 0; i != values.size(); ++i) {
            fmpz_mpoly_clear(nums + i, ctx);
            fmpz_mpoly_clear(denoms + i, ctx);
        }
        _fmpz_vec_clear(num_nums, num_len);
        _fmpz_vec_clear(num_denoms, num_len);
        _fmpz_vec_clear(denom_nums, denom_len);
        _fmpz_vec_clear(denom_denoms, denom_len);
        fmpz_mpoly_clear(gcd, ctx);
        fmpz_mpoly_clear(num, ctx);
        fmpz_mpoly_clear(denom, ctx);
        res_string = "0";
        ops = -1l;
    }

    fmpz_clear(coeff1);
    fmpz_clear(coeff2);
    fmpz_clear(lcm_limit);
    fmpz_clear(lcm);
    fmpz_clear(temp);
    free(nums);
    free(denoms);
    fmpz_mpoly_ctx_clear(ctx);
    _fmpz_vec_clear(used_points, values.size());
    _fmpz_vec_clear(used_values, values.size());
    _fmpz_vec_clear(buffer, buf_size);

    if (!silent) {
        if (ops != -1l) {
            std::cout << "Rational reconstruction stable after " << ops << " steps" << std::endl;
        } else {
            std::cout << "Rational reconstruction unstable" << std::endl;
        }
    }

    return std::make_pair(res_string, ops);
}

/**
 * Performs Zippel reconstruction of multiple expressions for different powers in prime case
 * @param ctx the flint context with variables
 * @param skel skeleton reconstructed function
 * @param results the recosntructed values
 * @param points the reconstruction points
 * @param values the function values in those points
 * @param newton_values_size the number of values for following Newton reconstruction
 * @param balancing_vars the balancing variables and their base values
 * @param silent whether not to produce messages
 * @return the number of needed steps, -1 in case of failure
 */
long zippel_multiple_prime(nmod_mpoly_ctx_t &ctx, nmod_mpoly_struct *skel, nmod_mpoly_struct *results,
                           const std::vector<std::string> &points, const std::vector<mp_limb_t> &values,
                           size_t newton_values_size, const std::map<std::string, std::string> &balancing_vars,
                           bool silent) {

    auto start_time = std::chrono::steady_clock::now();
    unsigned long skel_length = nmod_mpoly_length(skel, ctx);
    if (skel_length > values.size() / newton_values_size) {
        if (!silent) {
            std::cout << "Zippel reconstruction unstable with " << values.size() / newton_values_size << " points "
                      << std::endl;
        }
        return -1l;
    }
    std::vector<mp_limb_t> balancing_values;
    unsigned long bvs = balancing_vars.size();
    balancing_values.reserve(bvs);
    for (const auto &pair : balancing_vars) {
        mp_limb_t temp = stoul(pair.second);
        if (big_prime) {
            temp = primes[temp + values_primes_start];
        }
        balancing_values.push_back(temp);
    }

    std::vector<mp_limb_t> base;
    base.reserve(skel_length);
    nmod_poly_t main_pol;
    nmod_poly_init(main_pol, flint_prime);
    nmod_poly_set_coeff_ui(main_pol, 0, 1);
    // going in cycle by degree of reconstruction variable
    base.clear();
    unsigned long exp[16];
    for (unsigned long i = 0; i != skel_length; ++i) {
        // going in cycle by all skeleton terms
        nmod_mpoly_get_term_exp_ui(exp, skel, i, ctx);
        mp_limb_t prod = 1;
        for (unsigned long j = 0; j != bvs; ++j) {
            mp_limb_t temp = nmod_pow_ui(balancing_values[j], exp[j], flint_mod);
            prod = nmod_mul(prod, temp, flint_mod);
        }
        base.push_back(prod);
    }
    nmod_poly_product_roots_nmod_vec(main_pol, base.data(), skel_length);
    // main_pol is of length skel_length + 1 or degree skel_length
    for (unsigned k = 0; k != newton_values_size; ++k) {
        nmod_mpoly_set(results + k, skel, ctx);
        // the reconstructed polynomials will have same terms but other coeffs
    }

#ifdef WITH_GPU
    if (skel_length > 512) {
        gpu::zippel_multiple_prime(skel_length, values, main_pol->coeffs, base, results, flint_mod);
    } else {
#endif
#pragma omp parallel for if (zippel_openmp_threads > 1) num_threads(zippel_openmp_threads)
        for (unsigned long i = 0; i != skel_length; ++i) {
            constexpr size_t MAX_VALUE_SIZE = 1024;
            if (newton_values_size >= MAX_VALUE_SIZE) {
                std::cerr << "Newton limit too big " << std::endl;
                abort();
            }
            // we are accumulating results in 3-limb combinations temp2[k], temp1[k], temp0[k]
            mp_limb_t temp2[MAX_VALUE_SIZE];
            mp_limb_t temp1[MAX_VALUE_SIZE];
            mp_limb_t temp0[MAX_VALUE_SIZE];
            // int thread_number = omp_get_thread_num();
            for (ulong k = 0; k < newton_values_size; k++) {
                temp2[k] = 0ul;
                temp1[k] = 0ul;
                temp0[k] = 0ul;
            }
            mp_limb_t prev_term = 0;
            mp_limb_t prod = 0;
            for (unsigned long j = skel_length; j != 0; --j) {
                mp_limb_t term = nmod_mul(prev_term, base[i], flint_mod);
                term = nmod_add(term, main_pol->coeffs[j], flint_mod);
                for (ulong k = 0; k != newton_values_size; k++) {
                    mp_limb_t p1, p0;
                    umul_ppmm(p1, p0, (term), (values[(skel_length - j) * newton_values_size + k]));
                    add_sssaaaaaa(temp2[k], temp1[k], temp0[k], temp2[k], temp1[k], temp0[k], 0, p1, p0);
                }
                prod = nmod_mul(prod, base[i], flint_mod);
                prod = nmod_add(prod, term, flint_mod);
                prev_term = term;
            }
            // now temp_pol is main_pol/(d-base[[i]])
            // mp_limb_t prod = nmod_poly_evaluate_nmod(temp_pol, base[i]);
            // that's a product of (base[[i]] - base[[j]]) by j excluding j = i
            prod = nmod_mul(prod, base[i], flint_mod);
            prod = nmod_inv(prod, flint_mod);
            // we will multiply by prod after matrix multiplication instead
            // matrix multiplication was replaced by vector now, resulting is actually a vector
            for (unsigned k = 0; k != newton_values_size; ++k) {
                // this is one of exponent terms, the power in d is correct, we are going to build
                // the polynomial
                NMOD_RED(temp2[k], temp2[k], flint_mod);
                NMOD_RED3(temp0[k], temp2[k], temp1[k], temp0[k], flint_mod);
                nmod_mpoly_set_term_coeff_ui(results + k, i, nmod_mul(prod, temp0[k], flint_mod), ctx);
            }
        }
#ifdef WITH_GPU
    }
#endif

    nmod_poly_clear(main_pol);

    auto stop_time = std::chrono::steady_clock::now();
    if (!silent) {
        std::cout << "Zippel reconstruction stable after " << skel_length << " steps and "
                  << std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count()
                  << " seconds." << std::endl;
    }
    return skel_length;
}

/**
 * Performs Zippel reconstruction of multiple expressions for different powers. Used only in
 * non-prime mode
 * @param skeleton skeleton reconstructed function
 * @param points the reconstruction points
 * @param values the function values in those points
 * @param balancing_vars the balancing variables and their base values
 * @param silent whether not to produce messages
 * @return result and the number of needed steps, -1 in case of failure
 */
std::pair<std::vector<std::string>, long> zippel_multiple(const std::string &skeleton,
                                                          const std::vector<std::string> &points,
                                                          const std::vector<std::vector<std::string>> &values,
                                                          const std::map<std::string, std::string> &balancing_vars,
                                                          bool silent) {

    // points should be always a range. They are powers
    // balancing_vars, note, that they also contain an entry for symbol, it should not be used

    std::string symbol = balancing_vars.begin()->first;
    // we will use the first of balancing vars for construction of temporary polynomial to stay in
    // same flint context
    if (prime == 0) {

        // here we do not use MULTIPLE, IT IS DUMMY FOR ONE!

        fmpq_mpoly_t skel;
        fmpq_mpoly_ctx_t ctx;
        size_t nvars = balancing_vars.size();
        fmpq_mpoly_ctx_init(ctx, nvars, ORD_LEX);
        std::vector<const char *> vars_vector;
        vars_vector.resize(nvars);
        size_t i = 0;
        for (const auto &pair : balancing_vars) {
            vars_vector[i] = pair.first.c_str();
            ++i;
        }
        fmpq_mpoly_init(skel, ctx);
        fmpq_mpoly_set_str_pretty(skel, skeleton.c_str(), &vars_vector[0], ctx);

        unsigned long skel_length = fmpq_mpoly_length(skel, ctx);
        if (skel_length > values[0].size()) {
            if (!silent) {
                std::cout << "Zippel reconstruction unstable with " << values[0].size() << " points " << std::endl;
            }
            fmpq_mpoly_clear(skel, ctx);
            fmpq_mpoly_ctx_clear(ctx);
            return std::make_pair(std::vector<std::string>{"1"}, -1l);
        }

        fmpq *balancing_values = _fmpq_vec_init(balancing_vars.size());
        i = 0;
        for (const auto &pair : balancing_vars) {
            fmpq_set_str(balancing_values + i, pair.second.c_str(), 10);
            ++i;
        }

        fmpq_t temp2, temp3;
        fmpq_init(temp2);
        fmpq_init(temp3);
        fmpq *base = _fmpq_vec_init(skel_length);
        fmpq_mpoly_t main_pol;
        fmpq_mpoly_init(main_pol, ctx);
        fmpq_mpoly_t temp_pol;
        fmpq_mpoly_init(temp_pol, ctx);
        fmpq_mpoly_t result;
        fmpq_mpoly_init(result, ctx);
        fmpq *values_num = _fmpq_vec_init(values.size() * values[0].size());
        for (unsigned i = 0; i != values.size(); ++i) {
            for (unsigned j = 0; j != values[0].size(); ++j) {
                fmpq_set_str(values_num + j + i * values[0].size(), values[i][j].c_str(), 10);
            }
        }
        fmpq_mpoly_set_str_pretty(main_pol, "1", &vars_vector[0], ctx);
        // going in cycle by degree of reconstruction variable
        unsigned long exp[16];
        for (unsigned long i = 0; i != skel_length; ++i) {
            // going in cycle by all skeleton terms
            fmpq_mpoly_get_term_exp_ui(exp, skel, i, ctx);
            fmpq_set_ui(base + i, 1,
                        1); // we build up the skeleton term after substituting balancing values
            for (unsigned long j = 0; j != balancing_vars.size(); ++j) {
                fmpq_pow_si(temp2, balancing_values + j, exp[j]);
                fmpq_mul(base + i, base + i, temp2);
            }
            fmpq_mpoly_set_str_pretty(temp_pol, symbol.c_str(), &vars_vector[0], ctx); // d
            fmpq_mpoly_sub_fmpq(temp_pol, temp_pol, base + i, ctx);                    // d - base[[i]]
            fmpq_mpoly_mul(main_pol, main_pol, temp_pol, ctx);
        }
        for (unsigned long i = 0; i != skel_length; ++i) {
            fmpq_mpoly_set_str_pretty(temp_pol, symbol.c_str(), &vars_vector[0], ctx); // d
            fmpq_mpoly_sub_fmpq(temp_pol, temp_pol, base + i, ctx);                    // d - base[[i]]
            fmpq_mpoly_div(temp_pol, main_pol, temp_pol, ctx);                         // dividing by it, it's exact
            for (unsigned long j = 0; j != skel_length; ++j) {
                if (j == i) {
                    fmpq_mpoly_scalar_div_fmpq(temp_pol, temp_pol, base + j, ctx);
                    // we need to divide by base[[j]]
                } else {
                    fmpq_sub(temp2, base + i, base + j);
                    // we need to divide by base[[i]] - base[[j]]
                    fmpq_mpoly_scalar_div_fmpq(temp_pol, temp_pol, temp2, ctx);
                }
            }
            unsigned long temp_length =
                fmpq_mpoly_length(temp_pol, ctx); // it's normally skel_length, but some terms can get zeroes
            fmpq_zero(temp3);
            for (unsigned k = 0; k != values.size(); ++k) {
                for (unsigned long j = 0; j != temp_length; ++j) {
                    fmpq_mpoly_get_term_exp_ui(exp, temp_pol, j, ctx);
                    // it's in first variable
                    auto val_number = exp[0];
                    fmpq_mpoly_get_term_coeff_fmpq(temp2, temp_pol, j, ctx);
                    // most time is spent in next two functions, but they should be much faster in
                    // prime field for numerical GCD won't be called
                    fmpq_mul(temp2, temp2, values_num + val_number + k * values[0].size());
                    fmpq_add(temp3, temp3, temp2);
                }
                // temp3 is bs[[i]], Inner product
                fmpq_mpoly_get_term_exp_ui(exp, skel, i, ctx);
                // this is one of exponent terms, the power in d is correct, we are going to build
                // the polynomial
                fmpq_mpoly_push_term_fmpq_ui(result, temp3, exp, ctx);
            }
        }
        char *res;
        std::string res_string;
        res = fmpq_mpoly_get_str_pretty(result, &vars_vector[0], ctx);
        res_string = std::string(res);
        free(res);
        fmpq_clear(temp2);
        fmpq_clear(temp3);
        fmpq_mpoly_clear(main_pol, ctx);
        fmpq_mpoly_clear(temp_pol, ctx);
        fmpq_mpoly_clear(result, ctx);
        _fmpq_vec_clear(base, skel_length);
        _fmpq_vec_clear(balancing_values, balancing_vars.size());
        _fmpq_vec_clear(values_num, values.size() * values[0].size());
        fmpq_mpoly_clear(skel, ctx);
        fmpq_mpoly_ctx_clear(ctx);

        if (!silent) {
            std::cout << "Zippel reconstruction stable after " << skel_length << " steps" << std::endl;
        }
        return std::make_pair(std::vector<std::string>{res_string}, skel_length);
    } else {
        abort();
    }
}

/**
 * Performs balanced Zippel reconstruction of expressions
 * @param skeleton the skeleton function by a number of reconstructed variables, also used as
 * balancing
 * @param points the reconstruction points
 * @param values the function values in those points
 * @param symbol the new variable being changed
 * @param balancing_vars the balancing variables and their base values
 * @param withNewton whether we are calling the Newton reconstruction afterwards
 * @param silent whether not to produce messages
 * @return result and the number of needed steps, -1 in case of failure; the number of steps encodes
 * Newton and Zippel parts as 32-bit integers
 */
std::pair<std::string, long> balanced_zippel(std::string &skeleton, std::vector<std::string> &points,
                                             std::vector<std::string> &values, std::string &symbol,
                                             std::map<std::string, std::string> &balancing_vars, bool withNewton,
                                             bool silent) {
    // if withNewton, uses a range for Zippel, then calls Newton
    // points should be always a range
    int thread_number = 0;
    std::vector<std::pair<std::string, std::string>> nums_denoms;
    nums_denoms.reserve(values.size());
    size_t valuesSize = values.size();

    bool has_nonzero = (skeleton != "0");
    for (const auto &value : values) {
        if (value != "0") {
            has_nonzero = true;
        }
        nums_denoms.emplace_back(numerator_denominator(value));
    };
    values.clear();

    if (!has_nonzero) {
        if (!silent) {
            std::cout << "That's a zero\n";
        }
        return std::make_pair("0", 1l);
    }

    std::vector<int> exponents;
    std::transform(nums_denoms.begin(), nums_denoms.end(), std::back_inserter(exponents),
                   [symbol](const auto &elem) -> auto { return exponent(elem.first, symbol); });
    std::map<int, size_t> sizes;
    for (auto exponent : exponents) {
        sizes[exponent]++;
    }
    int best_exponent = std::max_element(sizes.begin(), sizes.end(), [](const auto &a, const auto &b) {
                            return a.second < b.second;
                        })->first;

    if (sizes.size() != 1) {
        if (!silent) {
            std::cout << "Different exponents by " << symbol << "\n";
        }
        for (auto &[num, denom] : nums_denoms) {
            int curexp = exponent(num, symbol);
            if (curexp != best_exponent) {
                num = "0";
                denom = "1";
            }
        }
    }

    unsigned long minimal_power, maximal_power;
    if (withNewton) {
        minimal_power = 2;
        maximal_power = skel_var_power;
    } else {
        minimal_power = skel_var_power;
        maximal_power = skel_var_power;
    }

    auto [check_value_num, check_value_denom] = numerator_denominator(skeleton);
    // those are for different values of current power
    std::vector<std::vector<std::string>> good_points;
    good_points.resize(maximal_power - minimal_power + 1);

    if (prime) {
        nmod_mpoly_t check_pol_num, check_pol_denom;
        nmod_mpoly_ctx_t ctx;
        nmod_mpoly_ctx_t ctx_uni;
        size_t nvars = balancing_vars.size() + 1;
        std::vector<const char *> vars_vector;
        nmod_mpoly_ctx_init(ctx, nvars, ORD_LEX, flint_prime);
        nmod_mpoly_ctx_init(ctx_uni, 1, ORD_LEX, flint_prime);
        vars_vector.resize(nvars);
        size_t i = 0;
        for (const auto &pair : balancing_vars) {
            vars_vector[i] = pair.first.c_str();
            ++i;
        }
        vars_vector[i] = symbol.c_str();

        // structures or parsing d reconstructed fractions
        nmod_mpoly_struct *temp_num = nullptr;
        nmod_mpoly_struct *temp_denom = nullptr;
        temp_num = static_cast<nmod_mpoly_struct *>(malloc(zippel_openmp_threads * sizeof(nmod_mpoly_struct)));
        if (temp_num == nullptr) {
            std::cout << "Cannot allocate memory\n";
            abort();
        }
        temp_denom = static_cast<nmod_mpoly_struct *>(malloc(zippel_openmp_threads * sizeof(nmod_mpoly_struct)));
        if (temp_denom == nullptr) {
            std::cout << "Cannot allocate memory\n";
            abort();
        }
        nmod_poly_struct *temp_num_uni = nullptr;
        nmod_poly_struct *temp_denom_uni = nullptr;
        temp_num_uni = static_cast<nmod_poly_struct *>(malloc(zippel_openmp_threads * sizeof(nmod_poly_struct)));
        if (temp_num_uni == nullptr) {
            std::cout << "Cannot allocate memory\n";
            abort();
        }
        temp_denom_uni = static_cast<nmod_poly_struct *>(malloc(zippel_openmp_threads * sizeof(nmod_poly_struct)));
        if (temp_denom_uni == nullptr) {
            std::cout << "Cannot allocate memory\n";
            abort();
        }
        for (int i = 0; i != zippel_openmp_threads; ++i) {
            nmod_mpoly_init(temp_num + i, ctx_uni);
            nmod_mpoly_init(temp_denom + i, ctx_uni);
            nmod_poly_init(temp_num_uni + i, flint_prime);
            nmod_poly_init(temp_denom_uni + i, flint_prime);
        }
        // over

        nmod_mpoly_init(check_pol_num, ctx);
        nmod_mpoly_init(check_pol_denom, ctx);
        nmod_mpoly_set_str_pretty(check_pol_num, check_value_num.c_str(), &vars_vector[0], ctx);
        nmod_mpoly_set_str_pretty(check_pol_denom, check_value_denom.c_str(), &vars_vector[0], ctx);
        unsigned check_pol_num_len = nmod_mpoly_length(check_pol_num, ctx);
        unsigned check_pol_denom_len = nmod_mpoly_length(check_pol_denom, ctx);
        // base terms after substitution of base balancing values
        auto check_pol_num_term = new mp_limb_t[check_pol_num_len];
        auto check_pol_denom_term = new mp_limb_t[check_pol_denom_len];
        // previous values (starting with coeffs), so each step we multiply by base
        auto check_pol_num_term_prev = new mp_limb_t[check_pol_num_len * zippel_openmp_threads];
        auto check_pol_denom_term_prev = new mp_limb_t[check_pol_denom_len * zippel_openmp_threads];
        unsigned long exp[256];
        if (zippel_openmp_threads >= 256) {
            std::cout << "Too many zippel openmp threads" << std::endl;
            abort();
        }

#ifdef WITH_GPU
        // Array for gpu tests
        unique_ptr<mp_limb_t[]> check_pol_num_term_tmp(new mp_limb_t[check_pol_num_len]),
            check_pol_denom_term_tmp(new mp_limb_t[check_pol_denom_len]),
            check_pol_num_term_prev_tmp(new mp_limb_t[check_pol_num_len]),
            check_pol_denom_term_prev_tmp(new mp_limb_t[check_pol_denom_len]);
#endif

        // preparing terms of skel function with balancing variables in base powers
        for (unsigned ii = 0; ii != check_pol_num_len; ++ii) {
            check_pol_num_term[ii] = 1;
            nmod_mpoly_get_term_exp_ui(exp, check_pol_num, ii, ctx);
            unsigned int j = 0;
            for (const auto &pair : balancing_vars) {
                mp_limb_t temp = stoul(pair.second);
                if (big_prime) {
                    temp = primes[temp + values_primes_start];
                }
                temp = nmod_pow_ui(temp, exp[j], flint_mod);
                check_pol_num_term[ii] = nmod_mul(check_pol_num_term[ii], temp, flint_mod);
                ++j;
            }
            check_pol_num_term_prev[ii] =
                nmod_mul(nmod_mpoly_get_term_coeff_ui(check_pol_num, ii, ctx), check_pol_num_term[ii], flint_mod);

#ifdef WITH_GPU
            check_pol_num_term_prev_tmp[ii] = check_pol_num_term_prev[ii];
            check_pol_num_term_tmp[ii] = check_pol_num_term[ii];
#endif
            for (int i = 1; i != zippel_openmp_threads; ++i) {
                check_pol_num_term_prev[ii + i * check_pol_num_len] = nmod_mul(
                    check_pol_num_term_prev[ii + (i - 1) * check_pol_num_len], check_pol_num_term[ii], flint_mod);
            }
            check_pol_num_term[ii] = nmod_pow_ui(check_pol_num_term[ii], zippel_openmp_threads, flint_mod);
        }

        for (unsigned ii = 0; ii != check_pol_denom_len; ++ii) {
            check_pol_denom_term[ii] = 1;
            nmod_mpoly_get_term_exp_ui(exp, check_pol_denom, ii, ctx);
            unsigned int j = 0;
            for (const auto &pair : balancing_vars) {
                mp_limb_t temp = stoul(pair.second);
                if (big_prime) {
                    temp = primes[temp + values_primes_start];
                }
                temp = nmod_pow_ui(temp, exp[j], flint_mod);
                check_pol_denom_term[ii] = nmod_mul(check_pol_denom_term[ii], temp, flint_mod);
                ++j;
            }

            check_pol_denom_term_prev[ii] =
                nmod_mul(nmod_mpoly_get_term_coeff_ui(check_pol_denom, ii, ctx), check_pol_denom_term[ii], flint_mod);

#ifdef WITH_GPU
            check_pol_denom_term_tmp[ii] = check_pol_denom_term[ii];
            check_pol_denom_term_prev_tmp[ii] = check_pol_denom_term_prev[ii];
#endif

            for (int i = 1; i != zippel_openmp_threads; ++i) {
                check_pol_denom_term_prev[ii + i * check_pol_denom_len] = nmod_mul(
                    check_pol_denom_term_prev[ii + (i - 1) * check_pol_denom_len], check_pol_denom_term[ii], flint_mod);
            }

            check_pol_denom_term[ii] = nmod_pow_ui(check_pol_denom_term[ii], zippel_openmp_threads, flint_mod);
        }
        // the prev terms are coeffs time monomials in powers 1..zippel_openmp_threads
        // the terms are monomials in power zippel_openmp_threads
        size_t maxSize = max(check_pol_num_len, check_pol_denom_len);
        if (maxSize > valuesSize) {
            maxSize = valuesSize;
        }
        for (size_t i = 0; i != maxSize; ++i) {
            unsigned power = stoul(points[i]);
            if (power != i + 1) {
                std::cout << power << " | " << (i + 1) << std::endl;
                abort();
            }
        }
        auto start_time = std::chrono::steady_clock::now();
        std::vector<mp_limb_t> nums_substituted;
        std::vector<mp_limb_t> denoms_substituted;

#ifdef WITH_GPU
        if (maxSize > 512) {
            nums_substituted = gpu::prepare_coeffs(check_pol_num_term_tmp.get(), check_pol_num_term_prev_tmp.get(),
                                                   check_pol_num_len, valuesSize, flint_mod);
            denoms_substituted =
                gpu::prepare_coeffs(check_pol_denom_term_tmp.get(), check_pol_denom_term_prev_tmp.get(),
                                    check_pol_denom_len, valuesSize, flint_mod);
        } else {
#endif
            nums_substituted.resize(check_pol_num_len, 0);
            denoms_substituted.resize(check_pol_denom_len, 0);
#pragma omp parallel if (zippel_openmp_threads > 1) num_threads(zippel_openmp_threads)
            {
                int thread_number = omp_get_thread_num();
                for (size_t i = thread_number; i < maxSize; i += zippel_openmp_threads) {
                    mp_limb_t coeff;
                    // substituting balancing replacements into n1
                    coeff = 0;
                    if (i < check_pol_num_len) {
                        for (unsigned ii = 0; ii != check_pol_num_len; ++ii) {
                            coeff = nmod_add(coeff, check_pol_num_term_prev[ii + thread_number * check_pol_num_len],
                                             flint_mod);
                            check_pol_num_term_prev[ii + thread_number * check_pol_num_len] =
                                nmod_mul(check_pol_num_term_prev[ii + thread_number * check_pol_num_len],
                                         check_pol_num_term[ii], flint_mod);
                        }
                        nums_substituted[check_pol_num_len - i - 1] = coeff;
                    }
                    // substituting balancing replacements into d1
                    coeff = 0;
                    if (i < check_pol_denom_len) {
                        for (unsigned ii = 0; ii != check_pol_denom_len; ++ii) {
                            coeff = nmod_add(coeff, check_pol_denom_term_prev[ii + thread_number * check_pol_denom_len],
                                             flint_mod);
                            check_pol_denom_term_prev[ii + thread_number * check_pol_denom_len] =
                                nmod_mul(check_pol_denom_term_prev[ii + thread_number * check_pol_denom_len],
                                         check_pol_denom_term[ii], flint_mod);
                        }
                        denoms_substituted[check_pol_denom_len - i - 1] = coeff;
                    }
                }
            }
#ifdef WITH_GPU
        }
#endif
        std::vector<mp_limb_t> nums;
        std::vector<mp_limb_t> denoms;

        size_t newton_values_size = maximal_power - minimal_power + 1;
        nums.resize(newton_values_size * check_pol_num_len, 0);
        denoms.resize(newton_values_size * check_pol_denom_len, 0);

        auto stop_time = std::chrono::steady_clock::now();
        if (!silent) {
            printf("Coefficient prepared after %f seconds\n",
                   std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count());
        }
        bool bad_points = false;
#pragma omp parallel for if (zippel_openmp_threads > 1) num_threads(zippel_openmp_threads)
        for (size_t i = 0; i != maxSize; ++i) {
            int thread_number = omp_get_thread_num();
            if (nums_denoms[i].first != "0") {
                auto [num, denom] = nums_denoms[i];
                exp[thread_number] = stoul(skel_var_value);
                if (big_prime) {
                    exp[thread_number] = primes[exp[thread_number] + values_primes_start];
                }
                mp_limb_t n1_number = ((i < check_pol_num_len) ? nums_substituted[check_pol_num_len - i - 1] : 0);
                mp_limb_t d1_number = ((i < check_pol_denom_len) ? denoms_substituted[check_pol_denom_len - i - 1] : 0);
                mp_limb_t n2_number = 0;
                mp_limb_t d2_number = 0;
                if (n1_number != 0) {
                    // substituting symbol -> skel_value into num
                    nmod_mpoly_set_str_pretty(temp_num + thread_number, num.c_str(),
                                              &vars_vector[balancing_vars.size()], ctx_uni);
                    nmod_mpoly_get_nmod_poly(temp_num_uni + thread_number, temp_num + thread_number, 0, ctx_uni);
                    n2_number = nmod_poly_evaluate_nmod(temp_num_uni + thread_number, exp[thread_number]);
                }
                if (d1_number != 0) {
                    // substituting symbol -> skel_value into denom
                    nmod_mpoly_set_str_pretty(temp_denom + thread_number, denom.c_str(),
                                              &vars_vector[balancing_vars.size()], ctx_uni);
                    nmod_mpoly_get_nmod_poly(temp_denom_uni + thread_number, temp_denom + thread_number, 0, ctx_uni);
                    d2_number = nmod_poly_evaluate_nmod(temp_denom_uni + thread_number, exp[thread_number]);
                }
                for (unsigned long current_power = minimal_power; current_power <= maximal_power; ++current_power) {
                    exp[thread_number] = stoul(skel_var_value);
                    if (big_prime) {
                        exp[thread_number] = primes[exp[thread_number] + values_primes_start];
                    }
                    mp_limb_t spower = current_power;
                    exp[thread_number] = nmod_pow_ui(exp[thread_number], spower, flint_mod);
                    mp_limb_t temp_number;
                    if (n2_number != 0) {
                        // substituting symbol -> skel_current into num
                        mp_limb_t num_number =
                            nmod_poly_evaluate_nmod(temp_num_uni + thread_number, exp[thread_number]);
                        mp_limb_t n = nmod_mul(n1_number, num_number, flint_mod);
                        temp_number = nmod_inv(n2_number, flint_mod);
                        n = nmod_mul(n, temp_number, flint_mod);
                        nums[(check_pol_num_len - i - 1) * newton_values_size + current_power - minimal_power] = n;
                    }
                    if (d2_number != 0) {
                        // substituting symbol -> skel_current into denom
                        mp_limb_t denom_number =
                            nmod_poly_evaluate_nmod(temp_denom_uni + thread_number, exp[thread_number]);
                        mp_limb_t d = nmod_mul(d1_number, denom_number, flint_mod);
                        temp_number = nmod_inv(d2_number, flint_mod);
                        d = nmod_mul(d, temp_number, flint_mod);
                        denoms[(check_pol_denom_len - i - 1) * newton_values_size + current_power - minimal_power] = d;
                    }
                    if (!((n2_number != 0 || i >= check_pol_num_len) && (d2_number != 0 || i >= check_pol_denom_len))) {
                        // std::cout << "bad Point " << i << std::endl;
                        bad_points = true;
                    }
                } // powers
            } // non-zero
        } // values
        delete[] check_pol_num_term;
        delete[] check_pol_denom_term;
        delete[] check_pol_num_term_prev;
        delete[] check_pol_denom_term_prev;
        if (bad_points) {
            if (!silent) {
                std::cout << maxSize << " | " << points.size() << std::endl;
                std::cout << "Cannot run Zippel reconstruction with missing intermediate points" << std::endl;
            }
            for (int i = 0; i != zippel_openmp_threads; ++i) {
                nmod_mpoly_clear(temp_num + i, ctx_uni);
                nmod_mpoly_clear(temp_denom + i, ctx_uni);
                nmod_poly_clear(temp_num_uni + i);
                nmod_poly_clear(temp_denom_uni + i);
            }
            free(temp_num);
            free(temp_denom);
            free(temp_num_uni);
            free(temp_denom_uni);
            nmod_mpoly_clear(check_pol_num, ctx);
            nmod_mpoly_clear(check_pol_denom, ctx);
            nmod_mpoly_ctx_clear(ctx);
            nmod_mpoly_ctx_clear(ctx_uni);
            return std::make_pair("", -1l);
        }
        auto [skeleton_num, skeleton_denom] = numerator_denominator(skeleton);
        long countZippel = 0;
        long countNewton = 0;
        long count, count_num, count_denom;
        std::string res_num, res_denom;

        nmod_mpoly_struct *newton_nums_mpoly = nullptr;
        nmod_mpoly_struct *newton_denoms_mpoly = nullptr;
        // prepare vectors for zippel_multiple_prime results here
        newton_nums_mpoly =
            static_cast<nmod_mpoly_struct *>(malloc((newton_values_size + 1) * sizeof(nmod_mpoly_struct)));
        if (newton_nums_mpoly == nullptr) {
            std::cout << "Cannot allocate memory\n";
            abort();
        }
        for (unsigned i = 0; i != newton_values_size + 1; ++i) {
            nmod_mpoly_init(newton_nums_mpoly + i, ctx);
        }
        newton_denoms_mpoly =
            static_cast<nmod_mpoly_struct *>(malloc((newton_values_size + 1) * sizeof(nmod_mpoly_struct)));
        if (newton_denoms_mpoly == nullptr) {
            std::cout << "Cannot allocate memory\n";
            abort();
        }
        for (unsigned i = 0; i != newton_values_size + 1; ++i) {
            nmod_mpoly_init(newton_denoms_mpoly + i, ctx);
        }
        // the first one in newton_nums/denoms_mpoly is skel
        nmod_mpoly_set_str_pretty(newton_nums_mpoly + 0, skeleton_num.c_str(), &vars_vector[0], ctx);
        nmod_mpoly_set_str_pretty(newton_denoms_mpoly + 0, skeleton_denom.c_str(), &vars_vector[0], ctx);
        count_num = zippel_multiple_prime(ctx, newton_nums_mpoly, newton_nums_mpoly + 1, points, nums,
                                          newton_values_size, balancing_vars, silent);
        count_denom = zippel_multiple_prime(ctx, newton_denoms_mpoly, newton_denoms_mpoly + 1, points, denoms,
                                            newton_values_size, balancing_vars, silent);
        if (count_num == -1l || count_denom == -1l) {
            for (int i = 0; i != zippel_openmp_threads; ++i) {
                nmod_mpoly_clear(temp_num + i, ctx_uni);
                nmod_mpoly_clear(temp_denom + i, ctx_uni);
                nmod_poly_clear(temp_num_uni + i);
                nmod_poly_clear(temp_denom_uni + i);
            }
            free(temp_num);
            free(temp_denom);
            free(temp_num_uni);
            free(temp_denom_uni);
            nmod_mpoly_clear(check_pol_num, ctx);
            nmod_mpoly_clear(check_pol_denom, ctx);
            for (unsigned i = 0; i != newton_values_size + 1; ++i) {
                nmod_mpoly_clear(newton_nums_mpoly + i, ctx);
                nmod_mpoly_clear(newton_denoms_mpoly + i, ctx);
            }
            free(newton_nums_mpoly);
            free(newton_denoms_mpoly);
            nmod_mpoly_ctx_clear(ctx);
            nmod_mpoly_ctx_clear(ctx_uni);
        }
        if (count_num > countZippel) {
            countZippel = count_num;
        }
        if (count_denom > countZippel) {
            countZippel = count_denom;
        }
        nmod_mpoly_t result_num;
        nmod_mpoly_t result_denom;
        nmod_mpoly_t not_needed;
        nmod_mpoly_init(result_num, ctx);
        nmod_mpoly_init(result_denom, ctx);
        nmod_mpoly_init(not_needed, ctx);
        if (withNewton) {
            std::vector<mp_limb_t> points_number;
            for (unsigned long current_power = 1; current_power <= maximal_power; ++current_power) {
                unsigned long long v = stoul(skel_var_value);
                if (big_prime) {
                    v = primes[v + values_primes_start];
                }
                v = nmod_pow_ui(v, current_power, flint_mod);
                points_number.push_back(v);
            }
            count_num = newton_prime(ctx, result_num, not_needed, vars_vector, 0, points_number, newton_nums_mpoly,
                                     symbol, "1", silent);
            count_denom = newton_prime(ctx, result_denom, not_needed, vars_vector, 0, points_number,
                                       newton_denoms_mpoly, symbol, "1", silent);
            for (unsigned i = 0; i != newton_values_size + 1; ++i) {
                nmod_mpoly_clear(newton_nums_mpoly + i, ctx);
                nmod_mpoly_clear(newton_denoms_mpoly + i, ctx);
            }
            free(newton_nums_mpoly);
            free(newton_denoms_mpoly);
            nmod_mpoly_clear(not_needed, ctx);
            if (count_num == -1l || count_denom == -1l) {
                for (int i = 0; i != zippel_openmp_threads; ++i) {
                    nmod_mpoly_clear(temp_num + i, ctx_uni);
                    nmod_mpoly_clear(temp_denom + i, ctx_uni);
                    nmod_poly_clear(temp_num_uni + i);
                    nmod_poly_clear(temp_denom_uni + i);
                }
                free(temp_num);
                free(temp_denom);
                free(temp_num_uni);
                free(temp_denom_uni);
                nmod_mpoly_clear(check_pol_num, ctx);
                nmod_mpoly_clear(check_pol_denom, ctx);
                nmod_mpoly_clear(result_num, ctx);
                nmod_mpoly_clear(result_denom, ctx);
                nmod_mpoly_ctx_clear(ctx);
                nmod_mpoly_ctx_clear(ctx_uni);
                return std::make_pair("", -1l);
            }
            if (count_num > countNewton) {
                countNewton = count_num;
            }
            if (count_denom > countNewton) {
                countNewton = count_denom;
            }
            count = (countZippel << 32) + countNewton;
        } else {
            nmod_mpoly_set(result_num, newton_nums_mpoly + 1, ctx);
            nmod_mpoly_set(result_denom, newton_denoms_mpoly + 1, ctx);
            count = countZippel;
            for (unsigned i = 0; i != nums.size() + 1; ++i) {
                nmod_mpoly_clear(newton_nums_mpoly + i, ctx);
                nmod_mpoly_clear(newton_denoms_mpoly + i, ctx);
            }
            free(newton_nums_mpoly);
            free(newton_denoms_mpoly);
        }
        nmod_mpoly_gcd(check_pol_num, result_num, result_denom, ctx);
        nmod_mpoly_div(temp_num, result_num, check_pol_num, ctx);
        nmod_mpoly_div(temp_denom, result_denom, check_pol_num, ctx);
        char *res_num_char = nmod_mpoly_get_str_pretty(result_num, &vars_vector[0], ctx);
        char *res_denom_char = nmod_mpoly_get_str_pretty(result_denom, &vars_vector[0], ctx);
        std::string result;
        if (std::string(res_denom_char) != "1") {
            result = std::string{"("} + std::string(res_num_char) + ")/(" + std::string(res_denom_char) + ")";
        } else {
            result = std::string(res_num_char);
        }
        for (int i = 0; i != zippel_openmp_threads; ++i) {
            nmod_mpoly_clear(temp_num + i, ctx_uni);
            nmod_mpoly_clear(temp_denom + i, ctx_uni);
            nmod_poly_clear(temp_num_uni + i);
            nmod_poly_clear(temp_denom_uni + i);
        }
        free(temp_num);
        free(temp_denom);
        free(temp_num_uni);
        free(temp_denom_uni);
        nmod_mpoly_clear(result_num, ctx);
        nmod_mpoly_clear(result_denom, ctx);
        nmod_mpoly_clear(check_pol_num, ctx);
        nmod_mpoly_clear(check_pol_denom, ctx);
        nmod_mpoly_ctx_clear(ctx);
        nmod_mpoly_ctx_clear(ctx_uni);
        free(res_num_char);
        free(res_denom_char);
        return std::make_pair(result, count);
    } else { // not prime
        std::vector<std::vector<std::string>> nums;
        std::vector<std::vector<std::string>> denoms;
        nums.resize(maximal_power - minimal_power + 1);
        denoms.resize(maximal_power - minimal_power + 1);
        for (size_t i = 0; i != valuesSize; ++i) {
            if (nums_denoms[i].first != "0") {
                auto [num, denom] = nums_denoms[i];
                string n1 = check_value_num;
                string d1 = check_value_denom;
                string n2 = num;
                string d2 = denom;
                for (auto itr = balancing_vars.rbegin(); itr != balancing_vars.rend(); ++itr) {
                    // need to start from longest
                    n1 = replace_all(n1, itr->first, std::string{"(("} + itr->second + ")^" + points[i] + ")");
                    d1 = replace_all(d1, itr->first, std::string{"(("} + itr->second + ")^" + points[i] + ")");
                }
                n2 = replace_all(n2, symbol, std::string{"("} + skel_var_value + ")");
                d2 = replace_all(d2, symbol, std::string{"("} + skel_var_value + ")");
                for (unsigned long current_power = minimal_power; current_power <= maximal_power; ++current_power) {
                    num = replace_all(num, symbol,
                                      std::string{"(("} + skel_var_value + ")^" + std::to_string(current_power) + ")");
                    denom = replace_all(
                        denom, symbol, std::string{"(("} + skel_var_value + ")^" + std::to_string(current_power) + ")");
                    if (n2 != "0" && d2 != "0") {
                        // the denominator of the balancing table might get to zero for this point,
                        // should be ignored
                        std::string n, d;
                        n = std::string{"("} + n1 + ") * (" + num + ") / (" + n2 + ")";
                        d = std::string{"("} + d1 + ") * (" + denom + ") / (" + d2 + ")";
                        fuel::simplify(n, thread_number, prime != 0);
                        fuel::simplify(d, thread_number, prime != 0);
                        n = replace_all(n, "(", "");
                        d = replace_all(d, "(", "");
                        n = replace_all(n, ")", "");
                        d = replace_all(d, ")", "");
                        nums[current_power - minimal_power].push_back(n);
                        denoms[current_power - minimal_power].push_back(d);
                        good_points[current_power - minimal_power].push_back(points[i]);
                    }
                } // powers
            } // nonzero
        } // values
        for (unsigned long current_power = minimal_power; current_power <= maximal_power; ++current_power) {
            if (good_points[current_power - minimal_power].size() != points.size()) {
                if (!silent) {
                    std::cout << good_points[current_power - minimal_power].size() << " | " << points.size()
                              << std::endl;
                    std::cout << "Cannot run Zippel reconstruction with missing intermediate points" << std::endl;
                }
                return std::make_pair("", -1);
            }
        }
        auto [skeleton_num, skeleton_denom] = numerator_denominator(skeleton);
        long countZippel = 0;
        long countNewton = 0;
        long count, count_num, count_denom;
        std::string res_num, res_denom;
        std::vector<std::string> newton_points;
        std::vector<std::string> res_nums;
        std::vector<std::string> res_denoms;
        std::vector<std::string> newton_nums;
        std::vector<std::string> newton_denoms;
        if (withNewton) {
            // the skeleton table is the first newton value
            newton_nums.push_back(skeleton_num);
            newton_denoms.push_back(skeleton_denom);
        }
        auto res = zippel_multiple(skeleton_num, good_points[0], nums, balancing_vars, silent);
        res_nums = res.first;
        count_num = res.second;
        if (count_num == -1l) {
            return std::make_pair("", -1l);
        }
        res = zippel_multiple(skeleton_denom, good_points[0], denoms, balancing_vars, silent);
        res_denoms = res.first;
        count_denom = res.second;
        if (count_denom == -1l) {
            return std::make_pair("", -1l);
        }
        if (count_num > countZippel) {
            countZippel = count_num;
        }
        if (count_denom > countZippel) {
            countZippel = count_denom;
        }
        if (withNewton) {
            for (const auto &res_num : res_nums) {
                newton_nums.push_back(res_num);
            }
            for (const auto &res_denom : res_denoms) {
                newton_denoms.push_back(res_denom);
            }
            for (unsigned long current_power = 1; current_power <= maximal_power; ++current_power) {
                unsigned long long v = stoul(skel_var_value);
                if (big_prime) {
                    v = primes[v + values_primes_start];
                }
                v = nmod_pow_ui(v, current_power, flint_mod);
                newton_points.push_back(std::to_string(v));
            }
            auto res = newton(newton_points, newton_nums, symbol, "1", silent);
            res_num = res.first;
            count_num = res.second;
            res = newton(newton_points, newton_denoms, symbol, "1", silent);
            res_denom = res.first;
            count_denom = res.second;
            if (count_num == -1l || count_denom == -1l) {
                return std::make_pair("", -1l);
            }
            if (count_num > countNewton) {
                countNewton = count_num;
            }
            if (count_denom > countNewton) {
                countNewton = count_denom;
            }
            count = (countZippel << 32) + countNewton;
        } else {
            res_num = res_nums[0];
            res_denom = res_denoms[0];
            count = countZippel;
        }
        if (withNewton) {
            fuel::setOption("no_store_expressions");
        }
        std::string result = std::string{"("} + res_num + ")/(" + res_denom + ")";
        fuel::simplify(result, thread_number, prime != 0);
        if (withNewton) {
            fuel::setOption("clear_stored_expressions");
            fuel::setOption("store_expressions");
        }
        return std::make_pair(result, count);
    } // not prime
}

/**
 * Performs balanced Newton reconstruction of expressions
 * @param points the reconstruction points
 * @param values the function values in those points
 * @param symbol the reconstruction variable
 * @param check_value the balancing parameter
 * @param balancing_vars the balancing variables and their base values
 * @param silent whether not to produce messages
 * @return result and the number of needed steps, -1 in case of failure
 */
std::pair<std::string, long> balanced_newton(const std::vector<std::string> &points,
                                             const std::vector<std::string> &values, std::string symbol,
                                             std::string check_value, std::map<std::string, std::string> balancing_vars,
                                             bool silent) {

    int thread_number = 0;
    std::vector<std::pair<std::string, std::string>> nums_denoms;
    nums_denoms.reserve(values.size());

    for (const auto &value : values) {
        nums_denoms.emplace_back(numerator_denominator(value));
    };
    for (const auto &bvar_pair : balancing_vars) {
        std::vector<int> exponents;
        auto &bvar = bvar_pair.first;
        std::transform(nums_denoms.begin(), nums_denoms.end(), std::back_inserter(exponents),
                       [bvar](const auto &elem) -> auto { return exponent(elem.first, bvar); });
        std::map<int, size_t> sizes;
        for (auto exponent : exponents) {
            sizes[exponent]++;
        }
        int best_exponent = std::max_element(sizes.begin(), sizes.end(), [](const auto &a, const auto &b) {
                                return a.second < b.second;
                            })->first;

        if (sizes.size() != 1) {
            if (!silent) {
                std::cout << "Different exponents by " << bvar << "\n";
            }
            for (auto &[num, denom] : nums_denoms) {
                int curexp = exponent(num, bvar);
                if (curexp != best_exponent) {
                    num = "0";
                    denom = "1";
                }
            }
        }
    }

    std::vector<std::string> good_points;
    good_points.reserve(values.size());
    std::vector<std::string> nums;
    nums.reserve(values.size());
    std::vector<std::string> denoms;
    denoms.reserve(values.size());

    nmod_mpoly_ctx_t ctx;
    nmod_mpoly_t num_poly;
    nmod_mpoly_t denom_poly;
    nmod_mpoly_t check_num_poly;
    nmod_mpoly_t check_denom_poly;
    nmod_mpoly_t gcd_poly;
    size_t nvars = balancing_vars.size() + 1;
    std::vector<const char *> vars_vector;
    if (prime) {
        nmod_mpoly_ctx_init(ctx, nvars, ORD_LEX, flint_prime);
        vars_vector.resize(nvars);
        vars_vector[0] = symbol.c_str();
        size_t i = 1;
        for (const auto &pair : balancing_vars) {
            vars_vector[i] = pair.first.c_str();
            ++i;
        }
        nmod_mpoly_init(num_poly, ctx);
        nmod_mpoly_init(denom_poly, ctx);
        nmod_mpoly_init(check_num_poly, ctx);
        nmod_mpoly_init(check_denom_poly, ctx);
        nmod_mpoly_init(gcd_poly, ctx);
    }

    auto [check_value_num, check_value_denom] = numerator_denominator(check_value);

    if (prime) {
        nmod_mpoly_set_str_pretty(check_num_poly, check_value_num.c_str(), &vars_vector[0], ctx);
        nmod_mpoly_set_str_pretty(check_denom_poly, check_value_denom.c_str(), &vars_vector[0], ctx);
    }
    unsigned long exp[16];

    for (size_t i = 0; i != values.size(); ++i) {
        if (nums_denoms[i].first != "0") {
            if (prime) {
                auto [num, denom] = nums_denoms[i];
                nmod_mpoly_set_str_pretty(num_poly, num.c_str(), &vars_vector[0], ctx);
                nmod_mpoly_set_str_pretty(denom_poly, denom.c_str(), &vars_vector[0], ctx);
                unsigned len;
                mp_limb_t n1 = 0;
                // substituting Point value into balancing table num
                len = nmod_mpoly_length(check_num_poly, ctx);
                for (unsigned ii = 0; ii != len; ++ii) {
                    mp_limb_t prod = nmod_mpoly_get_term_coeff_ui(check_num_poly, ii, ctx);
                    nmod_mpoly_get_term_exp_ui(exp, check_num_poly, ii, ctx);
                    mp_limb_t temp = stoul(points[i]);
                    temp = nmod_pow_ui(temp, exp[0], flint_mod);
                    prod = nmod_mul(prod, temp, flint_mod);
                    n1 = nmod_add(n1, prod, flint_mod);
                }
                mp_limb_t d1 = 0;
                // substituting Point value into balancing table num
                len = nmod_mpoly_length(check_denom_poly, ctx);
                for (unsigned ii = 0; ii != len; ++ii) {
                    mp_limb_t prod = nmod_mpoly_get_term_coeff_ui(check_denom_poly, ii, ctx);
                    nmod_mpoly_get_term_exp_ui(exp, check_denom_poly, ii, ctx);
                    mp_limb_t temp = stoul(points[i]);
                    temp = nmod_pow_ui(temp, exp[0], flint_mod);
                    prod = nmod_mul(prod, temp, flint_mod);
                    d1 = nmod_add(d1, prod, flint_mod);
                }
                mp_limb_t n2 = 0;
                // substituting balancing replacements into num
                len = nmod_mpoly_length(num_poly, ctx);
                for (unsigned ii = 0; ii != len; ++ii) {
                    mp_limb_t prod = nmod_mpoly_get_term_coeff_ui(num_poly, ii, ctx);
                    nmod_mpoly_get_term_exp_ui(exp, num_poly, ii, ctx);
                    unsigned j = 1;
                    for (const auto &pair : balancing_vars) {
                        mp_limb_t temp = stoul(pair.second);
                        temp = nmod_pow_ui(temp, exp[j], flint_mod);
                        prod = nmod_mul(prod, temp, flint_mod);
                        ++j;
                    }
                    n2 = nmod_add(n2, prod, flint_mod);
                }
                mp_limb_t d2 = 0;
                // substituting balancing replacements into denom
                len = nmod_mpoly_length(denom_poly, ctx);
                for (unsigned ii = 0; ii != len; ++ii) {
                    mp_limb_t prod = nmod_mpoly_get_term_coeff_ui(denom_poly, ii, ctx);
                    nmod_mpoly_get_term_exp_ui(exp, denom_poly, ii, ctx);
                    unsigned j = 1;
                    for (const auto &pair : balancing_vars) {
                        mp_limb_t temp = stoul(pair.second);
                        temp = nmod_pow_ui(temp, exp[j], flint_mod);
                        prod = nmod_mul(prod, temp, flint_mod);
                        ++j;
                    }
                    d2 = nmod_add(d2, prod, flint_mod);
                }
                if (n2 != 0 && d2 != 0) {
                    n2 = nmod_inv(n2, flint_mod);
                    d2 = nmod_inv(d2, flint_mod);
                    nmod_mpoly_scalar_mul_ui(num_poly, num_poly, n2, ctx);
                    nmod_mpoly_scalar_mul_ui(denom_poly, denom_poly, d2, ctx);
                    nmod_mpoly_scalar_mul_ui(num_poly, num_poly, n1, ctx);
                    nmod_mpoly_scalar_mul_ui(denom_poly, denom_poly, d1, ctx);
                    char *num_char = nmod_mpoly_get_str_pretty(num_poly, &vars_vector[0], ctx);
                    char *denom_char = nmod_mpoly_get_str_pretty(denom_poly, &vars_vector[0], ctx);
                    nums.push_back(std::string(num_char));
                    denoms.push_back(std::string(denom_char));
                    good_points.push_back(points[i]);
                    free(num_char);
                    free(denom_char);
                }
            } else {
                auto [num, denom] = nums_denoms[i];
                string n1 = check_value_num;
                string d1 = check_value_denom;
                n1 = replace_all(n1, symbol, std::string{"("} + points[i] + ")");
                d1 = replace_all(d1, symbol, std::string{"("} + points[i] + ")");
                string n2 = num;
                string d2 = denom;
                for (auto itr = balancing_vars.rbegin(); itr != balancing_vars.rend(); ++itr) {
                    // need to start from longest
                    n2 = replace_all(n2, itr->first, std::string{"("} + itr->second + ")");
                    d2 = replace_all(d2, itr->first, std::string{"("} + itr->second + ")");
                }
                if (prime) {
                    fuel::simplify(n2, thread_number, true);
                    fuel::simplify(d2, thread_number, true);
                }
                if (n2 != "0" && d2 != "0") {
                    // the denominator of the balancing table might get to zero for this point,
                    // should be ignored
                    std::string n, d;
                    n = std::string{"("} + n1 + ") * (" + num + ") / (" + n2 + ")";
                    d = std::string{"("} + d1 + ") * (" + denom + ") / (" + d2 + ")";
                    fuel::simplify(n, thread_number, prime != 0);
                    fuel::simplify(d, thread_number, prime != 0);
                    // (Numerator[check_value] with substitution symbol->key) * num / (num with
                    // bvars substitution)
                    nums.push_back(n);
                    // cout<<"n: "<<n<<endl<<"d: "<<d<<endl;
                    denoms.push_back(d);
                    // std::cout << points[i] << ": " << n1 << " | " << num << " | " << d1 << " | "
                    // << denom << " | " << n << " | " << d << std::endl;
                    good_points.push_back(points[i]);
                }
            }
        }
    }

    auto [res_num, count_num] = newton(good_points, nums, symbol, "1", silent);
    auto [res_denom, count_denom] = newton(good_points, denoms, symbol, "1", silent);

    long count;
    if (count_num == -1l) {
        count = -1l;
    } else if (count_denom == -1l) {
        count = -1l;
    } else if (count_num > count_denom) {
        count = count_num;
    } else {
        count = count_denom;
    }

    if (!prime) {
        auto res = std::string{"("} + res_num + ")/(" + res_denom + ")";
        fuel::setOption("no_store_expressions");
        if (count != -1) {
            fuel::simplify(res, thread_number, prime != 0);
        }
        fuel::setOption("clear_stored_expressions");
        fuel::setOption("store_expressions");
        return make_pair(res, count);
    } else {
        if (count != -1l) {
            auto res = std::string{"("} + res_num + ")/(" + res_denom + ")";
            return make_pair(res, count);
        }

        nmod_mpoly_set_str_pretty(num_poly, res_num.c_str(), &vars_vector[0], ctx);
        nmod_mpoly_set_str_pretty(denom_poly, res_denom.c_str(), &vars_vector[0], ctx);
        nmod_mpoly_gcd(gcd_poly, num_poly, denom_poly, ctx);
        nmod_mpoly_div(num_poly, num_poly, gcd_poly, ctx);
        nmod_mpoly_gcd(denom_poly, denom_poly, gcd_poly, ctx);
        char *res_num_char = nmod_mpoly_get_str_pretty(num_poly, &vars_vector[0], ctx);
        char *res_denom_char = nmod_mpoly_get_str_pretty(denom_poly, &vars_vector[0], ctx);
        auto res = std::string{"("} + std::string(res_num_char) + ")/(" + std::string(res_denom_char) + ")";
        nmod_mpoly_clear(num_poly, ctx);
        nmod_mpoly_clear(denom_poly, ctx);
        nmod_mpoly_clear(gcd_poly, ctx);
        free(res_num_char);
        free(res_denom_char);
        nmod_mpoly_ctx_clear(ctx);
        return make_pair(res, count);
    }
}

/**
 * Calls an appropriate reconstruction methos
 * @param points the reconstruction points
 * @param values the reconstruction values
 * @param method reconstruction method
 * @param var the reconstruction variable
 * @param balancing_vars the balancing variables and their base values
 * @param verbose whether to produce messages
 * @return result and the number of needed steps, -1 in case of failure
 */
std::pair<std::string, long> evaluate_coefficient(std::vector<std::string> points, std::vector<std::string> &values,
                                                  std::string method, std::string var,
                                                  std::map<std::string, std::string> balancing_vars,
                                                  bool verbose = false) {
    if (method == "combine" || method == "combinePrime") {
        std::string coeffCombined = "{";
        for (size_t i = 0; i != points.size(); ++i) {
            coeffCombined += "{";
            coeffCombined += points[i];
            coeffCombined += ", ";
            coeffCombined += values[i];
            coeffCombined += "}";
            coeffCombined += ", ";
        };
        if (coeffCombined.size() > 1) {
            coeffCombined = coeffCombined.substr(0, coeffCombined.size() - 2);
        }
        coeffCombined += "}";
        return std::make_pair(coeffCombined, 0);
    } else {
        if (values[0].find("|") != std::string::npos) {
            // the balancing table is not split the same way as other tables. It should be copied!
            // this meand that we have multitable coefficients here, each of those should be
            // reconstructed
            std::vector<std::string_view> value_views;
            value_views.reserve(values.size());
            for (const auto &value : values) {
                value_views.push_back(std::string_view(value));
            }
            int res_count = 0;
            std::string res = "";
            bool last = false;
            while (!last) {
                std::vector<std::string> current_values;
                current_values.reserve(values.size());
                if (value_views[0].find("|") == std::string::npos) {
                    // that's the last portions of coefficients
                    last = true;
                    for (auto sw : value_views) {
                        current_values.push_back(std::string(sw));
                    }
                } else {
                    // picking another part untill the separator
                    for (auto &sw : value_views) {
                        auto pos = sw.find("|");
                        if (pos == std::string::npos) {
                            // this is a balancing table, we copy it
                            current_values.push_back(std::string(sw));
                        } else {
                            // normal table, take a part and leave the remainder
                            current_values.push_back(std::string(sw.substr(0, pos)));
                            sw = sw.substr(pos + 1);
                        }
                    }
                }
                auto [current_res, current_count] =
                    evaluate_coefficient(points, current_values, method, var, balancing_vars, verbose);
                res = res + current_res;
                if (!last) {
                    res = res + "|";
                }
                if (res_count == -1l || current_count == -1l) {
                    res_count = -1l;
                } else if (current_count > res_count) {
                    res_count = current_count;
                }
            }
            return std::make_pair(res, res_count);
        }
        if (method == "thiele") {
            auto res = thiele(points, values, var, !verbose);
            return res;
        } else if (method == "balancedNewton") {
            std::string bpoint = points[points.size() - 1];
            if (bpoint != "-1") {
                std::cout << "Internal balancing error in logic \n";
                abort();
            }
            std::string bvalue = values[values.size() - 1];
            points.pop_back();
            values.pop_back();
            auto res = balanced_newton(points, values, var, bvalue, balancing_vars, !verbose);
            return res;
        } else if (method == "numeratorNewton") {
            std::string bpoint = points[points.size() - 1];
            if (bpoint != "-1") {
                std::cout << "Internal balancing error in logic \n";
                abort();
            }
            std::string bvalue = values[values.size() - 1];
            points.pop_back();
            values.pop_back();
            auto pair = numerator_denominator(bvalue);
            auto res = newton(points, values, var, pair.second, !verbose);
            return res;
        } else if (method == "balancedZippel" || method == "balancedZippelNewton") {
            std::string bpoint = points[points.size() - 1];
            if (bpoint != "-1") {
                std::cout << "Internal balancing error in logic \n";
                abort();
            }
            std::string bvalue = values[values.size() - 1];
            points.pop_back();
            values.pop_back();
            size_t i = 0;
            auto Point = points[i];
            while (i + 1 < points.size()) {
                if (stoi(points[i + 1]) == stoi(points[i]) + 1) {
                    ++i;
                } else {
                    break;
                }
            }
            ++i;
            if (i < points.size()) {
                if (verbose) {
                    std::cout << "Using only " << i << "consequent points for balanced Zippel" << std::endl;
                }
                while (i != points.size()) {
                    points.pop_back();
                    values.pop_back();
                }
            }
            auto res = balanced_zippel(bvalue, points, values, var, balancing_vars, (method == "balancedZippelNewton"),
                                       !verbose);
            return res;
        } else if (method == "newton") {
            auto res = newton(points, values, var, "1", !verbose);
            return res;
        } else if (method == "rational") {
            fmpz *fmpz_primes = _fmpz_vec_init(points.size());
            size_t i = 0;
            for (const auto &point : points) {
                fmpz_set_ui(fmpz_primes + i, primes[stoi(point)]);
                ++i;
            }
            auto res = rational_reconstruct_multiple(fmpz_primes, values, !verbose);
            _fmpz_vec_clear(fmpz_primes, points.size());
            return res;
        } else {
            std::cout << " Unknown method " << std::endl;
            abort();
        }
    }
}

/**
 * Prints help on program usage
 * @param longOptions The struct containing options of the program
 */
void show_help(const option *longOptions) {
    std::cout << "Usage: reconstruct [options] filename range\n"
                 "\t filename should be a pattern containing variable name between underscores or "
                 "_0.tables in the end for rational\n"
                 "\t range should be a number indicating how many Tables should be used maximally "
                 "starting from starting value. For rational could be n:m use n..n+m-1\n";

    std::map<std::string, std::string> expl;
    expl.emplace("help", "Show this help.");
    expl.emplace("parallel", "Indicates that multiple coefficients will be reconstricted by different OpenMP threads");
    expl.emplace("parallel_zippel", "Indicates that Zippel reconstruction of a single coefficient "
                                    "should be performed by different OpenMP threads. If with an "
                                    "optional paraeter, specifies the number of those threads");
    expl.emplace("quiet", "Suppress most of output");
    expl.emplace("prime", "Specifies prime number index for modular reconstruction");
    expl.emplace("calc", "Specifies siplification library");
    expl.emplace("variables", "Underscore_separated_values to be passes to calculation library, d_s_t by default");
    expl.emplace("method", "one of: rational, newton, numeratorNewton, thiele, balancedNewton, "
                           "balancedZippel, balancedZippelNewton");
    expl.emplace("reconstruction_variable",
                 "variable to be reconstucted, underscore separated with starting value, needed "
                 "for all methods but rational");
    expl.emplace("balancing_variables",
                 "balancing variables and their values for the balancing method of reconstruction, "
                 "should be a comma-separated list of underscore separated variables and values, "
                 "can be in curly brackets");
    expl.emplace("skeleton_variable", "skeleton variable setting for balanced Zippel. Shoud be var_value_power, where "
                                      "var is variable name, value is the value used to pick skeleton table, power is "
                                      "the power where we are running reconstruction");
    expl.emplace("delete_tables", "deletes Tables used for reconstruction after succsesfull reconstruction."
                                  "If an option is passed it is the starting table number for deletion"
                                  "If two underscore_separatied options are passes in case of balancedNewon, the "
                                  "balanced replaced Tables are also deleted starting from that number");
    expl.emplace("geometric", "if set the starting value is taken to the power instead of being "
                              "increased. Is automatically set for balancedZippelNewton");
    expl.emplace("unstable_filename", "if reconstruction is unstable, safe result to the specified file");
    expl.emplace("steps_as_error_code",
                 "return the number of steps as error code. 0 if too many >=255, still 1 if unstable");
    expl.emplace("thiele_surplus", "addidional thiele values to auto detected");
    expl.emplace("newton_surplus", "addidional newton values to auto detected");
    expl.emplace("fixed_initial_values_of_variables", "fixed variables existing in config like s_5,t_10");
    expl.emplace("all_tables_needed", "specifies that all Tables are required");
    expl.emplace("no_override", "do not write target file if it exists at start or appeared during reconstruction");
    expl.emplace("big_prime", "use big prime Tables for reconstruction marked with letter p");
#ifdef WITH_MPI
    expl.emplace("reconstructor_per_node",
                 "only for MPI, the number of processes per node taking part in reconstruction; "
                 "set to 1 by default to reduce memory usage, mostly compencated by the --parallel "
                 "or --parallel_zippel setting");
    expl.emplace("reconstructor_nodes",
                 "only for MPI, the maximal number of nodes participating in joint reconstruction");
#endif
    expl.emplace("multitables", "treat each of the ranged Tables as multitables for different "
                                "indices; if the argument is specified, it is the count");
    expl.emplace("multitables_first", "sets specifically how many values the first table contains");
    expl.emplace("save_trules", "changes the output format to trules");
    expl.emplace("load_trules", "use trules format loading for all Tables but first");
    expl.emplace("folders", "Specify whether the Tables should be saved into a subfolder depending "
                            "on passed variables powers");
    expl.emplace("relations", "Specify either a single relation (starting from 1) that has to be "
                              "reconstructed or a underscore_separated range");
    expl.emplace("masters", "Specify either a single master (starting from 1) coefficients at which have to be "
                            "reconstructed or a underscore_separated range");
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

#ifdef WITH_MPI

void load_tables_mpi(MPI_Comm &communicator, const std::string &filename, Tables &t, bool loadTrules) {
    MPI_File file;
    int RANK, NET_SIZE;
    MPI_Comm_rank(communicator, &RANK);
    MPI_Comm_size(communicator, &NET_SIZE);
    int errorcode = MPI_File_open(communicator, filename.c_str(),
                                  MPI_MODE_RDONLY | (loadTrules ? MPI_MODE_SEQUENTIAL : 0), MPI_INFO_NULL, &file);
    if (errorcode != MPI_SUCCESS) {
        char error[MPI_MAX_ERROR_STRING + 1];
        int errorlen;
        MPI_Error_string(errorcode, error, &errorlen);
        Tables::errorMessage = error;
        return;
    }
    if (loadTrules) {
        int count;
        int maxLength = 0;
        std::vector<int> allLengths;
        std::vector<int> lengths;
        if (RANK == 0) {
            int dataLength;
            char ibuf[64];
            errorcode = MPI_File_read_shared(file, ibuf, 64, MPI_CHAR, MPI_STATUS_IGNORE);
            if (errorcode != MPI_SUCCESS) {
                char error[MPI_MAX_ERROR_STRING + 1];
                int errorlen;
                MPI_Error_string(errorcode, error, &errorlen);
                Tables::errorMessage = error;
                return;
            }
            // we got the first line, parsing it
            const char *pos = ibuf;
            const char *end = ibuf + 64;
            char c = '\0';

            while ((pos != end && (c = *(pos++))) && c != '{') {
            }
            if (c != '{') {
                Tables::errorMessage = "No relations starting {";
                return;
            }
            while ((pos != end && (c = *(pos++))) && c != '{') {
            }
            if (c != '{') {
                Tables::errorMessage = "No relations starting second {";
                return;
            }
            std::string temp = "";
            while ((pos != end && (c = *(pos++))) && c != ',') {
                if (c > ' ' && c != '\\')
                    temp += c;
            }
            count = stoi(temp);
            if (c != ',') {
                Tables::errorMessage = "No relation pair comma";
                return;
            }
            temp = "";
            while ((pos != end && (c = *(pos++))) && c != ',') {
                if (c > ' ' && c != '\\')
                    temp += c;
            }
            dataLength = stoi(temp);
            if (c != ',') {
                Tables::errorMessage = "No relation pair comma";
                return;
            }
            char *buf = new char[dataLength + 1];
            errorcode = MPI_File_read_shared(file, buf, dataLength, MPI_CHAR, MPI_STATUS_IGNORE);
            if (errorcode != MPI_SUCCESS) {
                char error[MPI_MAX_ERROR_STRING + 1];
                int errorlen;
                MPI_Error_string(errorcode, error, &errorlen);
                Tables::errorMessage = error;
                return;
            }
            buf[dataLength] = '\0';
            // we got the line with coeffs, parsing
            pos = buf;
            end = buf + dataLength;
            while ((pos != end && (c = *(pos++))) && c != '{') {
            }
            if (c != '{') {
                Tables::errorMessage = "No relations starting second {";
                return;
            }
            int per_node = (count / NET_SIZE) + ((count % NET_SIZE == 0) ? 0 : 1);
            size_t minimal_size = 64 + dataLength;
            allLengths.resize(per_node * NET_SIZE);
            for (int i = 0; i != count; ++i) {
                std::string temp = "";
                while ((pos != end && (c = *(pos++))) && c != ',' && c != '}') {
                    if (c > ' ' && c != '\\')
                        temp += c;
                }
                allLengths[(i / NET_SIZE) + (i % NET_SIZE) * per_node] = stoi(temp);
                minimal_size += stoi(temp);
                if (((i != count - 1) && c != ',') || ((i == count - 1) && c != '}')) {
                    Tables::errorMessage = "Incorrect relation lengts line";
                    return;
                }
            }
            MPI_Offset off;
            MPI_File_get_size(file, &off);
            if (off < static_cast<MPI_Offset>(minimal_size)) {
                if (RANK == 0) {
                    printf("File too small %lld needed %lu %s\n", static_cast<long long int>(off), minimal_size,
                           filename.c_str());
                }
                MPI_Abort(communicator, 1);
            }

            for (int i = 0; i != per_node * NET_SIZE; ++i) {
                if (allLengths[i] > maxLength) {
                    maxLength = allLengths[i];
                }
            }
            delete[] buf;
            count = per_node;
        }

        MPI_Bcast(&count, 1, MPI_INT, 0, communicator);
        MPI_Bcast(&maxLength, 1, MPI_INT, 0, communicator);
        lengths.resize(count);
        // printf("RANK %d has %d and %d and %lu\n", RANK, count, maxLength, allLengths.size());
        MPI_Scatter(allLengths.data(), count, MPI_INT, lengths.data(), count, MPI_INT, 0, communicator);

        char *buf = new char[maxLength + 1];
        buf[maxLength] = '\0';
        for (int i = 0; i != count; ++i) {
            int portion = lengths[i];
            // printf("RANK %d going to read %d\n", RANK, portion);
            errorcode = MPI_File_read_ordered(file, buf, portion, MPI_CHAR, MPI_STATUS_IGNORE);
            if (errorcode != MPI_SUCCESS) {
                char error[MPI_MAX_ERROR_STRING + 1];
                int errorlen;
                MPI_Error_string(errorcode, error, &errorlen);
                Tables::errorMessage = error;
                return;
            }
            if (portion != 0) {
                const char *pos = t.LoadRelationLine(buf, maxLength);
                // printf("RANK %d read\n", RANK);
                if (pos == nullptr) {
                    return;
                }
            }
        }
        // printf("RANK %d out\n", RANK);
        MPI_File_close(&file);
        delete[] buf;
    } else {
        MPI_Offset size;
        MPI_File_get_size(file, &size);
        char *buf = new char[size];
        MPI_Offset pos = 0;
        while (pos != size) {
            MPI_Offset portion = size - pos;
            if (portion > 1l << 30) {
                portion = 1l << 30;
            }
            errorcode = MPI_File_read_all(file, buf + pos, portion, MPI_CHAR, MPI_STATUS_IGNORE);
            if (errorcode != MPI_SUCCESS) {
                char error[MPI_MAX_ERROR_STRING + 1];
                int errorlen;
                MPI_Error_string(errorcode, error, &errorlen);
                Tables::errorMessage = error;
                return;
            }
            pos += portion;
        }
        MPI_File_close(&file);
        t.Load(buf, size);
        int count = 0;
        for (size_t i = 0; i != t.relations.size(); ++i) {
            for (size_t j = 0; j != t.relations[i].second.size(); ++j) {
                if (count != RANK) {
                    t.relations[i].second[j].second = "";
                }
                ++count;
                if (count == NET_SIZE) {
                    count = 0;
                }
            }
        }
        delete[] buf;
    }
}

std::pair<bool, MPI_Comm> create_partial_communicator(int RANK, int NET_SIZE, size_t reconstructionPerNode,
                                                      int reconstructionNodes) {

    char NodeName[MPI_MAX_PROCESSOR_NAME];
    int NodeNameLen;
    MPI_Get_processor_name(NodeName, &NodeNameLen);
    NodeNameLen++;
    std::vector<int> NodeNameCountVect(NET_SIZE);
    std::vector<int> NodeNameOffsetVect(NET_SIZE);
    std::vector<char> NodeNameList; // it is not a string intentionally since it can contain multiple \0

    //  Gather node name lengths to master to prepare c-array
    MPI_Gather(&NodeNameLen, 1, MPI_INT, NodeNameCountVect.data(), 1, MPI_INT, 0, MPI_COMM_WORLD);

    if (RANK == 0) {
        NodeNameOffsetVect[0] = 0;
        int NodeNameTotalLen = NodeNameCountVect[0];

        //  build offset vector and total char count for all node names
        for (int i = 1; i != NET_SIZE; ++i) {
            NodeNameOffsetVect[i] = NodeNameCountVect[i - 1] + NodeNameOffsetVect[i - 1];
            NodeNameTotalLen += NodeNameCountVect[i];
        }
        //  char-array for all node names
        NodeNameList.resize(NodeNameTotalLen);
    }

    //  Gatherv node names to char-array in master
    MPI_Gatherv(NodeName, NodeNameLen, MPI_CHAR, NodeNameList.data(), NodeNameCountVect.data(),
                NodeNameOffsetVect.data(), MPI_CHAR, 0, MPI_COMM_WORLD);

    std::vector<int> usedForReconstructionVector(NET_SIZE);
    // they will only be used at master, but need to be everywhere due to MPI syntax

    if (RANK == 0) {
        std::unordered_map<std::string, std::vector<int>> sameNodeNameNumbers;
        std::vector<int> proc_number; // in_node
        proc_number.reserve(NET_SIZE);

        std::string s;

        // we count equal nodes
        for (int i = 0; i != NET_SIZE; ++i) {
            s = std::string(NodeNameList.data() + NodeNameOffsetVect[i]);
            auto itr = sameNodeNameNumbers.find(s);
            if (itr == sameNodeNameNumbers.end()) {
                sameNodeNameNumbers.emplace(s, std::vector<int>(1, i));
            } else {
                itr->second.push_back(i);
            }
        }

        // now setting who is first
        int nodeCount = 0;
        for (const auto &member : sameNodeNameNumbers) {
            for (size_t threadIndex = 0; threadIndex != member.second.size(); ++threadIndex) {
                if (threadIndex < reconstructionPerNode) {
                    if (reconstructionNodes == -1 || nodeCount < reconstructionNodes) {
                        usedForReconstructionVector[member.second[threadIndex]] = 1;
                    } else {
                        usedForReconstructionVector[member.second[threadIndex]] = 0;
                    }
                } else {
                    usedForReconstructionVector[member.second[threadIndex]] = 0;
                }
            }
            ++nodeCount;
        }
    }

    int usedForReconstruction;
    MPI_Scatter(usedForReconstructionVector.data(), 1, MPI_INT, &usedForReconstruction, 1, MPI_INT, 0, MPI_COMM_WORLD);

    // std::cout << "RANK " << RANK << ": " << usedForReconstruction << std::endl;

    MPI_Comm partialCommunicator;

    MPI_Comm_split(MPI_COMM_WORLD, usedForReconstruction, RANK, &partialCommunicator);

    if (!usedForReconstruction) {
        MPI_Comm_free(&partialCommunicator);
    }

    return std::make_pair(usedForReconstruction, partialCommunicator);
}

#endif

#ifdef WITH_MPI
void save_result(const std::string &filename, const std::vector<std::pair<size_t, size_t>> &all_positions,
                 const Tables &res, int RANK, int NET_SIZE, MPI_Comm partialCommunicator) {
    if (RANK == 0) {
        MPI_File_delete(filename.c_str(), MPI_INFO_NULL);
    }
    MPI_File file;
    MPI_File_open(partialCommunicator, filename.c_str(), MPI_MODE_CREATE | MPI_MODE_WRONLY | MPI_MODE_SEQUENTIAL,
                  MPI_INFO_NULL, &file);
    for (size_t k = RANK; k < (all_positions.size() / (NET_SIZE) + 1) * (NET_SIZE); k += NET_SIZE) {
        std::stringstream fout_local;
        if (k < all_positions.size()) {
            size_t j = all_positions[k].first;
            size_t i = all_positions[k].second;
            if (k == 0) {
                // initial writer
                fout_local << "{" << std::endl;
                fout_local << "    {";
                for (unsigned int l = 0; l != j; ++l) {
                    // we are writing starting zero relations
                    fout_local << "\n        {" << res.relations[l].first << ", {}},";
                }
                fout_local << "\n        {" << res.relations[j].first << ",\n            {";
            } else if (all_positions[k - 1].first != j) {
                // new relation
                fout_local << "\n        {" << res.relations[j].first << ",\n            {";
            }
            fout_local << "\n                {" << res.relations[j].second[i].first << ",\""
                       << res.relations[j].second[i].second << "\"}";
            if (k == all_positions.size() - 1) {
                // last term in last relation
                fout_local << "\n            }";
                fout_local << "\n        }";
                for (unsigned int l = j + 1; l != res.relations.size(); ++l) {
                    // we are writing final zero relations
                    fout_local << ",\n        {" << res.relations[l].first << ", {}}";
                }
                fout_local << "\n    }\n,\n    {";
                auto rcount = res.representations.size();
                for (const auto &representation : res.representations) {
                    fout_local << "\n        {" << representation.first << ", " << representation.second << "}";
                    if (--rcount)
                        fout_local << ",";
                }
                fout_local << "\n    }\n}\n";
            } else if (all_positions[k + 1].first == j) {
                // not last term in relation
                fout_local << ",";
            } else {
                // relation is over, but it is not the last one
                fout_local << "\n            }\n        },";
                for (unsigned int l = j + 1; l != all_positions[k + 1].first; ++l) {
                    // we are writing middle zero relations
                    fout_local << "\n        {" << res.relations[l].first << ", {}},";
                }
            }
        }
        auto expr = fout_local.str();
        MPI_File_write_ordered(file, expr.c_str(), expr.size(), MPI_CHAR, MPI_STATUS_IGNORE);
    }
    MPI_File_close(&file);
    if (all_positions.size() == 0 && RANK == 0) {
        std::ofstream fout(filename);
        fout << res << std::endl;
        fout.close();
    }
}
#endif

/**
 * Entry api Point for reconstruct.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @param ORIGINAL_RANK optional parameter, for MPI calls only
 * @param ORIGINAL_NET_SIZE optional parameter, for MPI calls only
 * @return 0 on success, but if steps_as_error_code is passed, then the number of steps
 */
int reconstruct(int argc, char *argv[], std::optional<int> ORIGINAL_RANK, std::optional<int> ORIGINAL_NET_SIZE) {

    auto start_time = std::chrono::steady_clock::now();
    big_prime = false;
    option longOptions[] = {{"calc", required_argument, nullptr, 'l'},
                            {"variables", required_argument, nullptr, 'v'},
                            {"method", required_argument, nullptr, 'm'},
                            {"reconstruction_variable", required_argument, nullptr, 'r'},
                            {"balancing_variables", required_argument, nullptr, 'b'},
                            {"skeleton_variable", required_argument, nullptr, 's'},
                            {"unstable_filename", required_argument, nullptr, 'u'},
                            {"verbose", no_argument, nullptr, 'V'},
                            {"steps_as_error_code", no_argument, nullptr, 'S'},
                            {"delete_tables", optional_argument, nullptr, 'D'},
                            {"prime", required_argument, nullptr, 'p'},
                            {"geometric", no_argument, nullptr, 'g'},
                            {"big_prime", no_argument, nullptr, 'B'},
                            {"all_tables_needed", no_argument, nullptr, 'a'},
                            {"no_override", no_argument, nullptr, 'n'},
                            {"multitables", optional_argument, nullptr, 'M'},
                            {"multitables_first", required_argument, nullptr, 'F'},
                            {"parallel", no_argument, nullptr, 'P'},
                            {"parallel_zippel", optional_argument, nullptr, 'Z'},
                            {"save_trules", no_argument, nullptr, 'T'},
                            {"load_trules", no_argument, nullptr, 't'},
                            {"relations", required_argument, nullptr, 1},
                            {"masters", required_argument, nullptr, 2},
#ifdef WITH_MPI
                            {"reconstructor_per_node", required_argument, nullptr, 'R'},
                            {"reconstructor_nodes", required_argument, nullptr, 'N'},
#endif
                            {"folders", required_argument, nullptr, 'f'},
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
#ifdef WITH_MPI
    int reconstructor_per_node = 1;
    int reconstructor_nodes = -1;
#endif
    Tables::saveTrules = false;
    bool parallel = false;
    bool all_tables_needed = false;
    bool no_override = false;
    bool steps_as_error_code = false;
    bool verbose = false;
    bool delete_tables = false;
    int multitables = 1;
    int multitables_first = 0;
#ifndef WITH_MPI
    size_t relations_from = 0;
    size_t relations_to = 1ul << 63;
    size_t masters_from = 0;
    size_t masters_to = 1ul << 63;
#endif
    size_t delete_tables_from = 0;
    size_t delete_replaced_tables_from = 65536;
    bool geometric = false;
    std::string method = "combine";
    std::string var = "";
    std::map<std::string, std::string> balancing_vars = {};
    size_t min = 1, max;
    bool skel_syntax = false;
    std::string unstable_filename;
    bool load_trules = false;
    while ((c = getopt_long(argc, argv, shortOptions.str().c_str(), longOptions, nullptr)) != -1) {
        switch (c) {
        case 0:
            break;
        case 'V':
            verbose = true;
            break;
        case 'P':
            parallel = true;
            break;
        case 'T':
            Tables::saveTrules = true;
            break;
        case 't':
            load_trules = true;
            break;
        case 'n':
            no_override = true;
            break;
        case 'B':
            big_prime = true;
            break;
        case 'Z':
            if (optarg == NULL && optind < argc && std::isdigit(argv[optind][0])) {
                optarg = argv[optind++];
            }
            if (optarg != nullptr) {
                zippel_openmp_threads = stoi(optarg);
            } else {
                zippel_openmp_threads = omp_get_max_threads();
            }
            break;
        case 'D':
            delete_tables = true;
            if (optarg == NULL && optind < argc && std::isdigit(argv[optind][0])) {
                optarg = argv[optind++];
            }
            if (optarg != nullptr) {
                std::istringstream iss(optarg);
                string rr;
                getline(iss, rr, '_');
                delete_tables_from = stoi(rr);
                if (getline(iss, rr, '_')) {
                    delete_replaced_tables_from = stoi(rr);
                }
            }
            break;
#ifndef WITH_MPI
        case 1: {
            std::istringstream iss(optarg);
            string rr;
            getline(iss, rr, '_');
            relations_from = stoul(rr);
            relations_to = relations_from;
            if (getline(iss, rr, '_')) {
                relations_to = stoul(rr);
            }
        } break;
        case 2: {
            std::istringstream iss(optarg);
            string rr;
            getline(iss, rr, '_');
            masters_from = stoul(rr);
            masters_to = masters_from;
            if (getline(iss, rr, '_')) {
                masters_to = stoul(rr);
            }
        } break;
#endif
        case 'M':
            multitables = MPRIME;
            if (optarg == NULL && optind < argc && std::isdigit(argv[optind][0])) {
                optarg = argv[optind++];
            }
            if (optarg != nullptr) {
                multitables = stoi(optarg);
            }
            break;
        case 'F':
            multitables_first = stoi(optarg);
            break;
        case 'f':
            folders_limit = stoi(optarg);
            break;
        case 'l':
            fuel::setLibrary(std::string(optarg));
            break;
        case 'u':
            unstable_filename = std::string(optarg);
            break;
#ifdef WITH_MPI
        case 'R':
            reconstructor_per_node = stoi(optarg);
            break;
        case 'N':
            reconstructor_nodes = stoi(optarg);
            break;
#endif
        case 'S':
            steps_as_error_code = true;
            break;
        case 'a':
            all_tables_needed = true;
            break;
        case 'p':
            sscanf(optarg, "%hu", &prime_number);
            if (prime_number > 383) {
                cout << "Index for a prime should be in range from 0 to 383, refer to primes.cpp" << endl;
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
        case 'g':
            geometric = true;
            break;
        case 'b': {
            balancing_vars.clear();
            std::istringstream iss(optarg);
            string setting;
            while (getline(iss, setting, ',')) {
                if (setting[0] == '{') {
                    setting = setting.substr(1);
                }
                if (setting[setting.size() - 1] == '}') {
                    setting = setting.substr(0, setting.size() - 1);
                }
                size_t setting_pos = setting.find("_");
                if (setting_pos == std::string::npos) {
                    std::cout << "The setting for balancing should be of form var_value, ...\n";
                    return 1;
                }
                balancing_vars.emplace(setting.substr(0, setting_pos), setting.substr(setting_pos + 1));
            }
        } break;
        case 's': {
            std::istringstream iss(optarg);
            string rvar;
            getline(iss, rvar, '_');
            var = rvar;
            getline(iss, rvar, '_');
            skel_var_value = rvar;
            getline(iss, rvar, '_');
            skel_var_power = stoul(rvar);
            skel_syntax = true;
        } break;
        case 'r': {
            std::string a(optarg);
            auto count = std::count(a.begin(), a.end(), '_');
            std::istringstream iss(optarg);
            string rvar;
            getline(iss, rvar, '_');
            var = rvar;
            getline(iss, rvar, '_');
            if (count == 2) {
                skel_var_value = rvar;
                getline(iss, rvar, '_');
                skel_var_power = stoul(rvar);
            } else {
                min = stoul(rvar);
            }
        } break;
        case 'm':
            method = std::string(optarg);
            break;
        default:
            printf("Unknown option!\n");
            return 1;
        }
    }

    if (argc - optind != 2) {
        show_help(longOptions);
#ifdef WITH_GPU
        gpu::getGPUData();
#endif
        return 1;
    }

    if (multitables_first == 0) {
        multitables_first = multitables;
    }

    if (argc - optind != 2) {
        show_help(longOptions);
        return 1;
    }

    std::string filenamePattern = argv[optind];
    if (no_override && std::filesystem::exists(filenamePattern)) {
        std::cout << "Target file already exists, not running reconstruction \n";
        return 1;
    }

    if (var == "" && method != "rational") {
        std::cout << "Reconstruction variable not set \n";
        return 1;
    }

    if (geometric && prime == 0) {
        std::cout << "Geometric can be set only when prime is set \n";
        return 1;
    }

    if (method == "balancedZippelNewton" && prime == 0) {
        std::cout << "balancedZippelNewton can be used only when prime is set \n";
        return 1;
    }

    if (method != "balancedZippel" && skel_syntax) {
        std::cout << "Skeleton syntax should be used only for balancedZippel\n";
        return 1;
    }

    if (geometric && method == "rational") {
        std::cout << "Geometric should not be used for rational reconstruction \n";
        return 1;
    }

    if ((method == "balancedNewton" || method == "balancedZippel" || method == "balancedZippelNewton") &&
        balancing_vars.empty()) {
        std::cout << "balancing_variables should be set for balancing method \n";
        return 1;
    }

    if (method == "balancedZippel") {
        if (var == "" || skel_var_value == "" || skel_var_power == 0) {
            std::cout << "skeleton_variable should be properly set for balanced Zippel\n";
            return 1;
        }
        if (skel_var_power == 1) {
            std::cout << "skeleton_variable power should not be 1 since it is used as base "
                         "(skeleton + balancing)\n";
            return 1;
        }
    }

    if (method == "balancedZippelNewton") {
        if (var == "" || skel_var_value == "" || skel_var_power == 0) {
            std::cout << "reconstruction_variable should be properly set for balanced "
                         "Zippel+Newton (var_base_newtonLimit)\n";
            return 1;
        }
        if (skel_var_power == 1) {
            std::cout << "skeleton_variable power should not be 1 since it is used as base "
                         "(skeleton + balancing)\n";
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
    srun = srun.substr(0, srun.length() - strlen("reconstruct"));

    std::string FIRE_folder;
    if (srun[0] == '/') { // running with full path
        FIRE_folder = srun;
    } else { // relative path, using current dir
        FIRE_folder = scurrent + "/" + srun;
    }

    std::string rep;
    if (method == "combinePrime" || method == "rational") {
        rep = "_0.";
    } else {
        rep = "_" + var + "_";
    }
    auto pos = filenamePattern.find(rep);

    if (pos == string::npos) {
        std::cout << "Filename should be a pattern containing " << rep << "\n";
        return 1;
    }

    ++pos;

    std::string range = argv[optind + 1];
    auto posS = range.find(":");

    if (posS != std::string::npos && method != "rational") {
        std::cout << "Please refer to new range syntax\n";
        return 1;
    }

#ifdef WITH_MPI
    auto [used, partialCommunicator] =
        create_partial_communicator(*ORIGINAL_RANK, *ORIGINAL_NET_SIZE, reconstructor_per_node, reconstructor_nodes);
    if (!used) {
        // other processes are not participating
        return 0;
    }
    int RANK, NET_SIZE;
    MPI_Comm_rank(partialCommunicator, &RANK);
    MPI_Comm_size(partialCommunicator, &NET_SIZE);
    if (RANK == 0) {
        std::cout << "Using " << NET_SIZE << " MPI processes out of " << *ORIGINAL_NET_SIZE << std::endl;
    }
    MPI_Barrier(partialCommunicator);
    if (used) {
        printf("Process %d has local rank %d\n", *ORIGINAL_RANK, RANK);
    }
    bool main_node = (RANK == 0);
#else
    bool main_node = true;
    int RANK;
    if (ORIGINAL_RANK) {
        RANK = *ORIGINAL_RANK;
    } else {
        RANK = 0;
    }
#endif

    if (posS != std::string::npos) {
        min = std::stoi(range);
        range = range.substr(posS + 1);
    }

    size_t shift = std::stoi(range);
    max = min + shift - 1;

    size_t originalNumber = max - min + 1;

    if (prime != 0) {
        flint_prime = prime;
        nmod_init(&flint_mod, flint_prime);
    }

    size_t tables_count = 0;
    if (tables_count + multitables_first < shift) {
        tables_count += multitables_first;
    }
    while (tables_count + multitables < shift) {
        tables_count += multitables;
    }
    if (all_tables_needed) {
        for (int i = tables_count; i >= 0; i -= ((i == multitables_first) ? multitables_first : multitables)) {
            std::string filename = filenamePattern;
            size_t rep_length = 2;
            if (method == "combinePrime" || method == "rational") {
                rep_length = 1;
            } else {
                rep_length = var.size();
            }
            Tables t;
            std::string multi_prefix = "";
            if (i != 0 && multitables != 1) {
                multi_prefix = "+";
            }
            if (method == "balancedZippel" || method == "balancedZippelNewton") {
                for (auto balancing_replacement : balancing_vars) {
                    if (balancing_replacement.first != var) {
                        size_t pos_balanced = filename.find(std::string{"_"} + balancing_replacement.first + "_");
                        if (pos_balanced == string::npos) {
                            std::cout << "No pattern _" << balancing_replacement.first << "_ for balancing in filename"
                                      << std::endl;
#ifdef WITH_MPI
                            MPI_Comm_free(&partialCommunicator);
#endif
                            return 1;
                        }
                        pos_balanced++;
                        filename.replace(pos_balanced, balancing_replacement.first.size(),
                                         (big_prime ? "p" : "") + balancing_replacement.second + "^" +
                                             std::to_string(1 + i) + multi_prefix);
                    }
                }
            } else {
                if (geometric) {
                    filename.replace(pos, rep_length,
                                     (big_prime ? "p" : "") + std::to_string(min) + "^" + std::to_string(i + 1) +
                                         multi_prefix);
                } else {
                    filename.replace(pos, rep_length, (big_prime ? "p" : "") + std::to_string(min + i) + multi_prefix);
                }
            }
            filename = subfolder_path(filename, folders_limit);
            if (verbose) {
                std::cout << "Checking " << filename << std::endl;
            }

            if (!std::filesystem::exists(filename)) {
                std::cout << "Table " << (i + 1) << " is missing, not running reconstruction" << std::endl;
                fuel::close();
                flint_cleanup_master();
#ifdef WITH_MPI
                MPI_Comm_free(&partialCommunicator);
#endif
                return 1;
            }
        }
    }

    std::vector<std::pair<std::vector<std::string>, Tables>>
        allTables; // we store Point as string, there can be multiple for the case of multitables

    std::map<size_t, string> filenames;

    if (all_tables_needed) {
        allTables.resize(1 + (shift - multitables_first) / multitables +
                         (((shift - multitables_first) % multitables) ? 1 : 0));
    }
    bool should_return = false;
    Tables::loadTrules = false;

#ifndef WITH_MPI
#pragma omp parallel for if (parallel && !load_trules && all_tables_needed)
#endif
    for (int i = multitables_first - multitables; i < static_cast<int>(shift); i += multitables) {
        std::string filename = filenamePattern;
        size_t rep_length = 2;
        if (method == "combinePrime" || method == "rational") {
            rep_length = 1;
        } else {
            rep_length = var.size();
        }
        Tables t;
        size_t current_i = (i < 0) ? 0 : i;
        std::string multi_prefix = "";
        if ((current_i != 0 || multitables_first != 1) && multitables != 1) {
            multi_prefix = "+";
        }
        if (method == "balancedZippel" || method == "balancedZippelNewton") {
            for (auto balancing_replacement : balancing_vars) {
                if (balancing_replacement.first != var) {
                    size_t pos_balanced = filename.find(std::string{"_"} + balancing_replacement.first + "_");
                    if (pos_balanced == string::npos) {
                        std::cout << "No pattern _" << balancing_replacement.first << "_ for balancing in filename"
                                  << std::endl;
                        should_return = true;
                    }
                    pos_balanced++;
                    filename.replace(pos_balanced, balancing_replacement.first.size(),
                                     (big_prime ? "p" : "") + balancing_replacement.second + "^" +
                                         std::to_string(1 + current_i) + multi_prefix);
                }
            }
        } else {
            if (geometric) {
                filename.replace(pos, rep_length,
                                 (big_prime ? "p" : "") + std::to_string(min) + "^" + std::to_string(current_i + 1) +
                                     multi_prefix);
            } else {
                filename.replace(pos, rep_length,
                                 (big_prime ? "p" : "") + std::to_string(min + current_i) + multi_prefix);
            }
        }
        filename = subfolder_path(filename, folders_limit);
#ifdef WITH_MPI
        // if (RANK == 0)
        //{
        //     printf("Loading table %lu\n", current_i);
        // }
        if (!load_trules || current_i == 0) {
            load_tables_mpi(partialCommunicator, filename, t, false);
        } else {
            t = allTables[0].second;
            load_tables_mpi(partialCommunicator, filename, t, true);
        }
#else
        if (load_trules && current_i != 0) {
            Tables::loadTrules = true;
        }
        std::ifstream f(filename);
        try {
            f >> t;
            for (unsigned int j = 0; j != t.relations.size(); ++j) {
                if (j + 1 < relations_from || j + 1 > relations_to) {
                    for (unsigned int k = 0; k != t.relations[j].second.size(); ++k) {
                        t.relations[j].second[k].second = "0";
                    }
                } else {
                    for (unsigned int k = 0; k != t.relations[j].second.size(); ++k) {
                        if (k + 1 < masters_from || k + 1 > masters_to) {
                            t.relations[j].second[k].second = "0";
                        }
                    }
                }
            }
            if (verbose) {
                std::cout << "Loaded table " << (current_i + 1) << std::endl;
            }
        } catch (...) {
            std::cout << "Cannot load table " << (current_i + 1) << " due to an exception \n";
            std::cout << filename << endl;
            if (all_tables_needed) {
                should_return = true;
            }
            continue;
        }
        f.close();
#endif
        if (Tables::errorMessage != "") {
            if (verbose || method == "rational") {
                if (main_node) {
                    std::cout << "Cannot load table " << (current_i + 1) << " for reason: " << Tables::errorMessage
                              << "\n";
                    std::cout << filename << endl;
                }
            }
            if (all_tables_needed) {
                should_return = true;
            }
            continue;
        }
#pragma omp critical
        {
            filenames.emplace(current_i, filename); // for deleting later
            if (!t.representations.empty()) {
                std::vector<std::string> table_numbers;
                int multi_shift = (current_i == 0) ? multitables_first : multitables;
                table_numbers.reserve(multi_shift);
                for (size_t j = current_i; j != current_i + multi_shift; ++j) {
                    unsigned long long table_number = 0;
                    if (prime != 0 && geometric && method != "balancedZippelNewton") {
                        unsigned long long v = min;
                        if (big_prime) {
                            v = primes[v + values_primes_start];
                        }
                        v = nmod_pow_ui(v, j + 1, flint_mod);
                        table_number = v;
                    } else if (method == "balancedZippel" || method == "balancedZippelNewton") {
                        table_number = 1 + j;
                    } else {
                        table_number = min + j;
                    }
                    table_numbers.push_back(std::to_string(table_number));
                }
                if (all_tables_needed) {
                    allTables[(i == 0) ? 0 : ((i - multitables_first) / multitables + 1)] =
                        std::make_pair(table_numbers, t);
                } else {
                    allTables.emplace_back(table_numbers, t);
                }
            } else {
                if (main_node) {
                    std::cout << "Empty table " << current_i << std::endl;
                }
                if (all_tables_needed) {
                    should_return = true;
                }
            }
        }
    }
    Tables::loadTrules = false;
    if (should_return) {
#ifdef WITH_MPI
        MPI_Comm_free(&partialCommunicator);
#endif
        std::cout << "Cannot continue with reconstruction" << std::endl;
        return 1;
    }

    if (allTables.empty()) {
        filenamePattern = subfolder_path(filenamePattern, folders_limit);
        std::cout << "No Tables found for " << filenamePattern << ", not running reconstruction" << std::endl;
#ifdef WITH_MPI
        MPI_Comm_free(&partialCommunicator);
#endif
        return 1;
    }

    size_t allTablesSize = 0;
    for (const auto &elem : allTables) {
        allTablesSize += elem.first.size();
    }

    if (allTablesSize == 1 && method != "rational" && method != "balancedZippelNewton") {
        std::cout << "Only 1 table exists, not running reconstruction " << std::endl;
#ifdef WITH_MPI
        MPI_Comm_free(&partialCommunicator);
#endif
        return 1;
    }

    if (allTablesSize < originalNumber) {
        if (all_tables_needed) {
            std::cout << "Some of the Tables are missing, length is " << allTablesSize << ", not running reconstruction"
                      << std::endl;
            fuel::close();
            flint_cleanup_master();
#ifdef WITH_MPI
            MPI_Comm_free(&partialCommunicator);
#endif
            return 1;
        }
        if (main_node) {
            std::cout << "Some of the Tables are missing, new length is " << allTablesSize << std::endl;
        }
    }
    originalNumber = allTablesSize;

    if (method == "balancedNewton" || method == "numeratorNewton" || method == "balancedZippel" ||
        method == "balancedZippelNewton") {
        // loading additional balancing table
        std::string filename = filenamePattern;
        if (method == "balancedNewton") {
            for (auto balancing_replacement : balancing_vars) {
                size_t pos_balanced = filename.find(std::string{"_"} + balancing_replacement.first + "_");
                if (pos_balanced == string::npos) {
                    std::cout << "No pattern _" << balancing_replacement.first << "_ for balancing in filename"
                              << std::endl;
#ifdef WITH_MPI
                    MPI_Comm_free(&partialCommunicator);
#endif
                    return 1;
                }
                pos_balanced++;
                if (geometric) {
                    filename.replace(pos_balanced, balancing_replacement.first.size(),
                                     balancing_replacement.second + "^1");
                } else {
                    filename.replace(pos_balanced, balancing_replacement.first.size(), balancing_replacement.second);
                }
            }
        } else if (method == "numeratorNewton") {
            size_t pos = 0;
            while (true) {
                pos = filename.find("^", pos);
                if (pos == string::npos) {
                    break;
                }
                size_t pos2 = pos + 1;
                while (filename[pos2] != '\0' && filename[pos2] != '_' && filename[pos2] != '.') {
                    ++pos2;
                }
                filename.replace(pos + 1, pos2 - pos - 1, "1");
                pos = pos + 1;
            }
        } else {
            size_t pos_balanced = filename.find(std::string{"_"} + var + "_");
            if (pos_balanced == string::npos) {
                std::cout << "No pattern _" << var << "_ for balancing in filename" << std::endl;
#ifdef WITH_MPI
                MPI_Comm_free(&partialCommunicator);
#endif
                return 1;
            }
            pos_balanced++;
            filename.replace(pos_balanced, var.size(), (big_prime ? "p" : "") + skel_var_value + "^1");
        }
        filename = subfolder_path(filename, folders_limit);
        Tables t;
        if (verbose) {
            std::cout << "Balancing is " << filename << std::endl;
        }
#ifdef WITH_MPI
        // if (RANK == 0)
        //{
        //     printf("Loading balancing\n");
        // }
        load_tables_mpi(partialCommunicator, filename, t, false);
#else
        std::ifstream f(filename);
        try {
            f >> t;
            for (unsigned int j = 0; j != t.relations.size(); ++j) {
                if (j + 1 < relations_from || j + 1 > relations_to) {
                    for (unsigned int k = 0; k != t.relations[j].second.size(); ++k) {
                        t.relations[j].second[k].second = "0";
                    }
                } else {
                    for (unsigned int k = 0; k != t.relations[j].second.size(); ++k) {
                        if (k + 1 < masters_from || k + 1 > masters_to) {
                            t.relations[j].second[k].second = "0";
                        }
                    }
                }
            }
        } catch (...) {
            std::cout << "Cannot load balancing table due to an exception \n";
            std::cout << filename << endl;
            f.close();
#ifdef WITH_MPI
            MPI_Comm_free(&partialCommunicator);
#endif
            return 1;
        }
        f.close();
#endif
        if (Tables::errorMessage != "") {
            std::cout << "Cannot load balancing table for reason: " << Tables::errorMessage << "\n";
            std::cout << filename << std::endl;
#ifdef WITH_MPI
            MPI_Comm_free(&partialCommunicator);
#endif
            return 1;
        }
        allTables.push_back(std::make_pair(std::vector<std::string>{"-1"}, t));
        ++originalNumber;
    }

#ifdef WITH_MPI
    MPI_Barrier(partialCommunicator);
#endif
    auto stop_time = std::chrono::steady_clock::now();
    if (verbose || method == "balancedZippelNewton") {
        if (main_node) {
            printf("Tables loaded after %f seconds\n",
                   std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count());
        }
    }

    std::vector<size_t> lengths;
    std::transform(allTables.begin(), allTables.end(), std::back_inserter(lengths),
                   [](const auto &elem) -> auto { return elem.second.representations.size(); });
    std::map<size_t, size_t> sizes;
    for (auto length : lengths) {
        sizes[length]++;
    }
    size_t length = std::max_element(sizes.begin(), sizes.end(), [](const auto &a, const auto &b) {
                        return a.second < b.second;
                    })->first;

    allTables.erase(
        std::remove_if(allTables.begin(), allTables.end(),
                       [length](const auto &elem) -> bool { return (elem.second.representations.size() != length); }),
        allTables.end());
    allTablesSize = 0;
    for (const auto &elem : allTables) {
        allTablesSize += elem.first.size();
    }
    if (allTablesSize < originalNumber) {
        std::cout << "Some of the Tables had different number of integrals in representations and "
                     "were removed, new length is "
                  << allTablesSize << std::endl;
        if ((method == "balancedNewton" || method == "numeratorNewton" || method == "balancedZippel" ||
             method == "balancedZippelNewton") &&
            allTables[allTables.size() - 1].first[0] != "-1") {
            std::cout << "Balancing table was removed, cannot continue" << std::endl;
#ifdef WITH_MPI
            MPI_Comm_free(&partialCommunicator);
#endif
            return 1;
        }
    }

    // hard part. For some values there can be another master. We need to leave only Tables with
    // equal structure.

    Tables::compareRelations = false;
    size_t good_index;

    if (method == "balancedNewton" || method == "numeratorNewton" || method == "balancedZippel" ||
        method == "balancedZippelNewton") {
        good_index = allTables.size() - 1;
    } else if (allTables.size() <= 2) {
        good_index = 0;
    } else if (allTables[0].second == allTables[1].second) {
        good_index = 0;
    } else if (allTables[0].second == allTables[2].second) {
        good_index = 0;
    } else if (allTables[1].second == allTables[2].second) {
        good_index = 1;
    } else {
        std::cout << "Not finding a proper pair of tables! \n";
#ifdef WITH_MPI
        MPI_Comm_free(&partialCommunicator);
#endif
        return 1;
    }

    size_t countdown = allTables.size() - 1;
    while (true) {
        if (allTables[countdown].second != allTables[good_index].second) {
            allTables.erase(allTables.begin() + countdown);
            std::cout << "Removing table " << allTables[countdown].first[0] << " as it is not matching the structure\n";
        }
        if (countdown == 0)
            break;
        --countdown;
    }

    Tables::compareRelations = true;

    // now we know that representations coincide and left-hand sides of relations coincide. But
    // there can be missing parts on right-hand sides of relations

    bool badBalancing = false;
    for (size_t i = 0; i != allTables[0].second.relations.size(); ++i) {
        std::vector<std::vector<std::string>> rightPartNumbers;
        std::transform(
            allTables.begin(), allTables.end(), std::back_inserter(rightPartNumbers), [i](const auto &elem) -> auto {
                std::vector<std::string> rightPartNumbersCurrent;
                std::transform(elem.second.relations[i].second.begin(), elem.second.relations[i].second.end(),
                               std::back_inserter(rightPartNumbersCurrent),
                               [](const auto &term) -> auto { return term.first; });
                return rightPartNumbersCurrent;
            });
        const auto &maxElement = *std::max_element(
            rightPartNumbers.begin(), rightPartNumbers.end(),
            [](const auto &first, const auto &second) -> bool { return first.size() < second.size(); });
        for_each(allTables.begin(), allTables.end(), [i, &maxElement, &badBalancing](auto &elem) {
            auto &currentElement = elem.second.relations[i].second;
            auto itr = currentElement.begin();
            if (currentElement.size() < maxElement.size()) {
                if (elem.first[0] == "-1") {
                    badBalancing = true;
                }
                // we need to insert missing elements into currentElement with coefficient 0
                // we assume that if we found an element in maxElement and it is missing in
                // currentElement, it has to be inserted and we move on
                for_each(maxElement.begin(), maxElement.end(), [&currentElement, &itr, &elem](const string number) {
                    if (number == itr->first) {
                        ++itr;
                    } else {
                        std::string zero = "0";
                        // here we take into account that there might be multitables of
                        // different size
                        for (size_t i = 1; i != elem.first.size(); ++i) {
                            zero += "|0";
                        }
                        itr = ++currentElement.insert(itr, make_pair(number, zero));
                    }
                });
            }
        });
    }

    if ((method == "balancedNewton" || method == "numeratorNewton" || method == "balancedZippel" ||
         method == "balancedZippelNewton") &&
        badBalancing) {
        std::cout << "ERROR! BALANCING OR SKELETON TABLE HAS ZERO COEFFICIENT!!!" << std::endl;
#ifdef WITH_MPI
        MPI_Comm_free(&partialCommunicator);
#endif
        return 2;
    }

    // now all relations should be of equal right-hand side numbers (only coefficients differ), but
    // let us check it
    Tables::compareCoefficients = false;
    const auto &firstTable = allTables[0].second;
    for (auto itr = allTables.begin(); itr != allTables.end(); ++itr) {
        if (firstTable != itr->second) {
            std::cout << "Some strange order in integrals in right-hand side relations\n";
#ifdef WITH_MPI
            MPI_Comm_free(&partialCommunicator);
#endif
            return 1;
        }
    }
    Tables::compareCoefficients = true;
    // now everything is of same form and we need to combine coefficients

    Tables res;
    res.representations = allTables[0].second.representations;
    for (auto itr = allTables.begin(); itr != allTables.end(); ++itr) {
        itr->second.representations.clear();
    }
    // sleep(1);
    std::vector<std::pair<std::string, std::vector<std::pair<std::string, std::vector<std::string>>>>> relations;
    // maps numbers to vectors of terms, where term is a number and combined coefficient (vector of
    // real coeffs)

    std::vector<std::string> allNumbers;
    allNumbers.reserve(allTablesSize);
    for (size_t k = 0; k != allTables.size(); ++k) {
        for (auto number : allTables[k].first) {
            allNumbers.push_back(number);
        }
    }

    relations.resize(allTables[0].second.relations.size());
    for (size_t j = allTables[0].second.relations.size() - 1;; --j) {
        relations[j].first.swap(allTables[0].second.relations[j].first);
        relations[j].second.resize(allTables[0].second.relations[j].second.size());
        for (size_t i = 0; i != allTables[0].second.relations[j].second.size(); ++i) {
            // that is the number of terms in rhs
            relations[j].second[i].first.swap(allTables[0].second.relations[j].second[i].first);
            if (multitables == 1) {
                relations[j].second[i].second.resize(allNumbers.size());
            } else {
                relations[j].second[i].second.reserve(allNumbers.size());
            }
            for (size_t k = 0; k != allTables.size(); ++k) {
                if (multitables == 1) {
                    relations[j].second[i].second[k].swap(allTables[k].second.relations[j].second[i].second);
                } else {
                    std::string s;
                    s.swap(allTables[k].second.relations[j].second[i].second);
                    std::string_view sw(s);
                    while (true) {
                        size_t pos = sw.find("|");
                        if (pos == string::npos) {
                            relations[j].second[i].second.push_back(std::string(sw));
                            break;
                        } else {
                            relations[j].second[i].second.push_back(std::string(sw.substr(0, pos)));
                            sw = sw.substr(pos + 1);
                        }
                    }
                }
            }
        }
        for (size_t k = 0; k != allTables.size(); ++k) {
            allTables[k].second.relations.pop_back();
        }
        if (j == 0) {
            break;
        }
    }
    allTables.clear();
    //    sleep(1);return 1;
    fuel::readLibraryPathsFromFile(FIRE_folder + "../extra/fuel/libraryBinarySettings");
    fuel::initialize(vars, 1, true, prime);
    fuel::setOption("u16exp");
    if (!prime && method != "balancedZippel" && method != "rational") {
        fuel::setOption("store_expressions");
    } else {
        fuel::switchToConventional();
    }
    if (prime && method == "thiele") {
        rational_function::initialize_vars(vars, prime);
    }
    res.relations.resize(relations.size());
    std::vector<std::vector<long>> total_steps;
    std::vector<std::pair<size_t, size_t>> all_positions;
    total_steps.resize(relations.size());
    for (size_t j = 0; j != relations.size(); ++j) {
        res.relations[j] = std::make_pair(relations[j].first,
                                          std::vector<std::pair<std::string, std::string>>(relations[j].second.size()));
        total_steps[j].resize(relations[j].second.size());
        for (size_t i = 0; i != relations[j].second.size(); ++i) {
            all_positions.push_back(std::make_pair(j, i));
        }
    }
#ifdef WITH_MPI
    MPI_Barrier(partialCommunicator);
#endif
    stop_time = std::chrono::steady_clock::now();
    if (verbose || method == "balancedZippelNewton") {
        if (main_node) {
            printf("Evaluation prepared after %f seconds\n",
                   std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count());
        }
    }
    if (zippel_openmp_threads > 1 && method == "balancedZippelNewton") {
        parallel = false;
    }
#ifdef WITH_MPI
    size_t ev_shift = NET_SIZE;
#pragma omp parallel for if (parallel)
    for (size_t k = RANK; k < all_positions.size(); k += ev_shift) {
#else
#pragma omp parallel for if (parallel)
    for (size_t k = 0; k != all_positions.size(); ++k) {
        // for (size_t k = 366; k != 367; ++k) {
        // for (size_t k = 241; k != 242; ++k) {
#endif
        if (method == "balancedZippelNewton" && verbose) {
            std::cout << "Reconstructing coefficient " << (k + 1) << "/" << all_positions.size() << std::endl;
        }
        size_t j = all_positions[k].first;
        size_t i = all_positions[k].second;
        auto allPointsCopy = allNumbers;
        auto coeffCombined =
            evaluate_coefficient(allPointsCopy, relations[j].second[i].second, method, var, balancing_vars, verbose);
        relations[j].second[i].second.clear();
        total_steps[j][i] = coeffCombined.second;
        res.relations[j].second[i].first.swap(relations[j].second[i].first);
        res.relations[j].second[i].second.swap(coeffCombined.first);
    }
#ifdef WITH_MPI
    MPI_Barrier(partialCommunicator);
#endif
    stop_time = std::chrono::steady_clock::now();
    if (verbose || method == "balancedZippelNewton") {
        if (main_node) {
            printf("Reconstruction is over after %f seconds\n",
                   std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count());
        }
    }
    long steps = 0;
    // we have the number of steps for each call, now combining
#ifdef WITH_MPI
    for (size_t k = RANK; k < all_positions.size(); k += NET_SIZE)
#else
    for (size_t k = 0; k != all_positions.size(); ++k)
#endif
    {
        size_t j = all_positions[k].first;
        size_t i = all_positions[k].second;
        long stepsCurrent = total_steps[j][i];
        if (steps >= 0) {
            if (stepsCurrent == -1l) {
                steps = -1l;
            } else {
                if (method == "balancedZippelNewton") {
                    long low_mask = (1l << 32) - 1;
                    steps = (((steps >> 32 > stepsCurrent >> 32) ? (steps >> 32) : (stepsCurrent >> 32)) << 32) +
                            (((steps & low_mask) > (stepsCurrent & low_mask)) ? (steps & low_mask)
                                                                              : (stepsCurrent & low_mask));
                } else {
                    steps = (steps > stepsCurrent) ? steps : stepsCurrent;
                }
            }
        }
    }
#ifdef WITH_MPI
    long *steps_multiple = new long[NET_SIZE];
    MPI_Allgather(&steps, 1, MPI_LONG, steps_multiple, 1, MPI_LONG, partialCommunicator);
    for (int k = 0; k != NET_SIZE; ++k) {
        long stepsCurrent = steps_multiple[k];
        if (steps >= 0) {
            if (stepsCurrent == -1) {
                steps = -1;
            } else {
                if (method == "balancedZippelNewton") {
                    long low_mask = (1l << 32) - 1;
                    steps = (((steps >> 32 > stepsCurrent >> 32) ? (steps >> 32) : (stepsCurrent >> 32)) << 32) +
                            (((steps & low_mask) > (stepsCurrent & low_mask)) ? (steps & low_mask)
                                                                              : (stepsCurrent & low_mask));
                } else {
                    steps = (steps > stepsCurrent) ? steps : stepsCurrent;
                }
            }
        }
    }
    delete[] steps_multiple;
#endif
    if (!prime && method != "balancedZippel" && method != "rational") {
        fuel::switchToConventional();
    }
    std::string rank_message = (ORIGINAL_RANK ? "(" + std::to_string(RANK) + ") " : "");
    if (steps >= 0) {
        if (steps > 0) {
            // not combining
            if (main_node) {
                if (method == "balancedZippelNewton") {
                    long low_mask = (1l << 32) - 1;
                    std::cout << "Reconstruction " << rank_message << "(" << method << ", " + var << ") stable after "
                              << (steps >> 32) << "-" << (steps & low_mask) << " steps\n";
                } else if (method == "rational") {
                    std::cout << "Reconstruction " << rank_message << "(" << method << ") stable after " << steps
                              << " steps\n";
                } else {
                    std::cout << "Reconstruction " << rank_message << "(" << method << ", " + var << ") stable after "
                              << steps << " steps\n";
                }
            }
        }
        if (!prime && method != "balancedZippel" && method != "rational") {
            for (auto &relation : res.relations) {
                for (auto &term : relation.second) {
                    fuel::simplify(term.second, 0, prime != 0);
                }
            }
        }
        std::string filename = filenamePattern;
        if (method == "balancedZippel") {
            size_t pos_skeleton = filename.find(std::string{"_"} + var + "_");
            if (pos_skeleton == string::npos) {
                std::cout << "No pattern _" << var << "_ for skeleton in filename" << std::endl;
#ifdef WITH_MPI
                MPI_Comm_free(&partialCommunicator);
#endif
                return 1;
            }
            pos_skeleton++;
            filename.replace(pos_skeleton, var.size(),
                             (big_prime ? "p" : "") + skel_var_value + "^" + std::to_string(skel_var_power));
        }
        bool should_save = true;
        if (no_override && std::filesystem::exists(filename)) {
            should_save = false;
        }
        filename = subfolder_path(filename, folders_limit, true);
#ifdef WITH_MPI
        MPI_Barrier(partialCommunicator);
#endif
        if (should_save && no_override && main_node) {
            std::ofstream fout(filename);
            fout.close();
            // saved a file. Other processes will see it and avoid saving
        }
        if (should_save) {
#ifdef WITH_MPI
            save_result(filename, all_positions, res, RANK, NET_SIZE, partialCommunicator);
#else
            std::ofstream fout(filename);
            fout << res << std::endl;
            fout.close();
#endif
        } else {
            std::cout << "Reconstruction " << rank_message << "succesfull, but file already appeared\n";
        }
        fuel::close();
#ifdef WITH_MPI
        if (RANK != 0) {
            delete_tables = false;
        }
#endif
        if (steps > 0 && delete_tables) {
            if (method == "rational" || method == "thiele" || method == "balancedNewton" ||
                method == "balancedZippelNewton" || method == "numeratorNewton") {
                for (auto [index, filename] : filenames) {
                    if (index >= delete_tables_from) {
                        if (std::filesystem::remove(filename)) {
                            std::cout << "Removing " << filename << std::endl;
                        }
                    }
                    if (method == "balancedNewton" && index >= delete_replaced_tables_from) {
                        for (auto balancing_replacement : balancing_vars) {
                            size_t pos_balanced = filename.find(std::string{"_"} + balancing_replacement.first + "_");
                            if (pos_balanced != string::npos) {
                                pos_balanced++;
                                if (geometric) {
                                    filename.replace(pos_balanced, balancing_replacement.first.size(),
                                                     balancing_replacement.second + "^1");
                                } else {
                                    filename.replace(pos_balanced, balancing_replacement.first.size(),
                                                     balancing_replacement.second);
                                }
                            }
                        }
                        std::cout << "Removing replaced " << filename << std::endl;
                        remove(filename.c_str());
                    }
                }
            }
        }
        if (!should_save) {
#ifdef WITH_MPI
            MPI_Comm_free(&partialCommunicator);
#endif
            return 1;
        }
    } else {
        if (main_node) {
            std::cout << "Reconstruction " << rank_message << "(" << method << ") unstable with "
                      << (allNumbers.size() - 1) << " steps\n";
        }
        flint_cleanup_master();
        if (unstable_filename != "") {
#ifdef WITH_MPI
            save_result(unstable_filename, all_positions, res, RANK, NET_SIZE, partialCommunicator);
#else
            std::ofstream fout(unstable_filename);
            fout << res << std::endl;
            fout.close();
#endif
        }
        fuel::close();
#ifdef WITH_MPI
        MPI_Comm_free(&partialCommunicator);
#endif
        return 1;
    }
    flint_cleanup_master();
#ifdef WITH_MPI
    MPI_Comm_free(&partialCommunicator);
#endif
    if (steps_as_error_code && steps > 1 && steps <= 255) {
        return steps;
    } else {
        return 0;
    }
}
