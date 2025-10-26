/** @file parser.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package.
 */
#include "common.h"
#include "parser.h"

#include <cinttypes>
#include <filesystem>
#include <getopt.h>

#include "tools/tools.h"
#ifdef PRIME
#include <../../extra/fuel/usr/include/flint/nmod_mpoly.h>
#endif

constexpr size_t LOAD_STR_SIZE = {1024};  ///< size of the string loaded from files
constexpr size_t COEFF_BUF_SIZE = {1024}; ///< size of buffer for parsing coefficients

/**
 * Values of variables from config or command line.
 */
vector<string> var_values_from_arv;
/**
 * Matrix of sector needed by sector relations
 */
static vector<vector<bool>> dependencies{};
/**
 * Sectors that contain non-zero master integrals in master split mode
 */
static vector<bool> needed_sectors{};
/**
 * Contains the list of non-zero masters in parser. Used in \#masters and adding
 * rules
 */
static set<Point> masters;
/**
 * Indication whether lbases have been loaded
 */
static bool lbases_loaded = false;

/**
 * The config passed indices that should be positive
 */
std::vector<int> positive_indices;

/**
 * In-place inversion of ordering matrix, called only during parsing.
 * @tparam M allocated dimension.
 * @param m pointer to square matrix of size M*M.
 * @param N real dimension of matrix.
 */
template <int M> inline static void invers(int m[M][M], const int N) {
    int gaus_ostatok;
    long gaus_deter;
    long gaus_minved;
    int *rn = new int[N];
    int *cn = new int[N];
    int j, k;

    for (j = N; j--;) {
        rn[j] = cn[j] = j;
    }
    gaus_minved = 1l << 62;
    gaus_deter = 1;
    for (gaus_ostatok = N; gaus_ostatok; gaus_ostatok--) {
        int jved{}, kved{};
        long vved = -1, t;

        // search of leading element
        for (j = N; j--;) {
            if (~rn[j]) {
                for (k = N; k--;) {
                    if ((~cn[k]) && (vved < abs(m[j][k]))) {
                        vved = fabs(m[j][k]), jved = j, kved = k;
                    }
                }
            }
        }

        if (gaus_minved > vved) {
            gaus_minved = vved;
        }
        gaus_deter *= m[jved][kved];
        if (abs(gaus_deter) != 1) {
            cout << "error in invers: " << abs(gaus_deter) << endl;
            throw std::exception();
        }

        int jt = rn[jved], kt = cn[kved];

        // rearrangement
        for (j = N; j--;)
            t = m[kt][j], m[kt][j] = m[jved][j], m[jved][j] = t;
        for (j = N; j--;)
            t = m[j][jt], m[j][jt] = m[j][kved], m[j][kved] = t;

        rn[jved] = rn[kt];
        cn[kved] = cn[jt];
        rn[kt] = cn[jt] = -1;

        vved = m[kt][jt];
        if (abs(vved) != 1) {
            cout << "error in invers another: " << abs(vved) << endl;
            throw std::exception();
        }
        m[kt][jt] = 1;
        for (j = N; j--;) {
            if (j == kt) {
                continue;
            }
            long mul = m[j][jt] / vved;

            m[j][jt] = 0;
            for (k = N; k--;) {
                m[j][k] -= m[kt][k] * mul;
            }
        }
        for (k = N; k--;) {
            m[kt][k] /= vved;
        }
    }
    delete[] rn;
    delete[] cn;
}

/** Compare sector priority:
 * 1) total number of positive entries
 * 2) existence of an sbasis
 * 3) lsectors - make sectors without Lee symmetries lower
 * 4) compare by indices
 * @param v1 first sector vector
 * @param v2 second second vector
 * @return true if first is smaller
 */
bool sector_sort_function(const vector<t_index> &v1, const vector<t_index> &v2) {
    unsigned long l = v1.size();
    int c = 0;

    for (unsigned int i = 0; i != l; ++i) {
        c = c + v1[i] - v2[i];
    }
    if (c < 0)
        return true;
    if (c > 0)
        return false;

    auto it1 = Common::lsectors.find(sector_fast(v1));
    auto it2 = Common::lsectors.find(sector_fast(v2));

    if ((it1 == Common::lsectors.end()) && (it2 != Common::lsectors.end()))
        return false;
    if ((it2 == Common::lsectors.end()) && (it1 != Common::lsectors.end()))
        return true;

    for (int i = l - 1; i != -1; --i) {
        c = v1[i] - v2[i];
        if (c < 0)
            return true;
        if (c > 0)
            return false;
    }
    return false;
}

int s2i(const char *digit, int &result) {
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

int s2u(const char *digit, unsigned int &result) {
    result = 0;
    int move = 0;
    //--- Convert each digit char and add into result.
    while ((*(digit + move) >= '0' && *(digit + move) <= '9') || *(digit + move) == '-') {
        if (*(digit + move) == '-') {
            if (!move) {
                cout << "Unexpected -" << endl;
                abort();
            } else {
                break;
            }
        } else {
            result = (result * 10) + (*(digit + move) - '0');
        }
        move++;
    }
    return move;
}

int s2lu(const char *digit, unsigned long &result) {
    result = 0;
    int move = 0;
    //--- Convert each digit char and add into result.
    while ((*(digit + move) >= '0' && *(digit + move) <= '9') || *(digit + move) == '-') {
        if (*(digit + move) == '-') {
            if (!move) {
                cout << "Unexpected -" << endl;
                abort();
            } else {
                break;
            }
        } else {
            result = (result * 10) + (*(digit + move) - '0');
        }
        move++;
    }
    return move;
}

int s2v(const char *digit, vector<t_index> &result) {
    result.clear();
    result.reserve(Common::dimension);
    int move = 0;
    while (*(digit + move) == ' ') {
        move++;
    }
    if (*(digit + move) != '{') {
        cout << "!error in s2v" << string(digit) << "!" << endl;
        cout << endl;
        abort();
    }
    move++;
    while (*(digit + move) == ' ') {
        move++;
    }
    while (*digit != '}') {
        int number;
        int move_now = s2i(digit + move, number);
        result.push_back(number);
        move += move_now;

        while (*(digit + move) == ' ') {
            move++;
        }
        if (*(digit + move) == '}') {
            move++;
            break;
        }
        if (*(digit + move) != ',') {
            cout << "!error in s2v" << string(digit) << "!" << endl;
            cout << endl;
            abort();
        }
        move++;
        while (*(digit + move) == ' ') {
            move++;
        }
    }
    return move;
}

int s2sf(const char *digit, SECTOR &result) {
    result = 0;
    int move = 0;
    while (*(digit + move) == ' ') {
        move++;
    }
    if (*(digit + move) != '{') {
        cout << "!error in s2v" << string(digit) << "!" << endl;
        cout << endl;
        abort();
    }
    move++;
    while (*(digit + move) == ' ') {
        move++;
    }
    while (*digit != '}') {
        int number;
        int move_now = s2i(digit + move, number);
        if (number > 0) {
            result = ((result << 1) ^ 1);
        } else {
            result = result << 1;
        }
        move += move_now;

        while (*(digit + move) == ' ') {
            move++;
        }
        if (*(digit + move) == '}') {
            move++;
            break;
        }
        if (*(digit + move) != ',') {
            cout << "!error in s2sf" << string(digit) << "!" << endl;
            cout << endl;
            abort();
        }
        move++;
        while (*(digit + move) == ' ') {
            move++;
        }
    }
    return move;
}

int s2vv(const char *digit, vector<vector<t_index>> &result) {
    result.clear();
    int move = 0;
    while (*(digit + move) == ' ') {
        move++;
    }
    if (*(digit + move) != '{') {
        cout << "error in s2vv";
        abort();
    }
    move++;
    if (*(digit + move) == '}') {
        return 2;
    }
    while (*digit != '}') {
        vector<t_index> small;
        int move_now = s2v(digit + move, small);
        result.push_back(small);
        {
            move += move_now;
        }

        while (*(digit + move) == ' ') {
            move++;
        }
        if (*(digit + move) == '}') {
            move++;
            break;
        }
        if (*(digit + move) != ',') {
            cout << "error in s2vv" << *(digit + move) << endl;
            abort();
        }
        {
            move++;
        }
        while (*(digit + move) == ' ') {
            move++;
        }
    }
    return move;
}

int s2vvv(const char *digit, vector<vector<vector<t_index>>> &result) {
    result.clear();
    int move = 0;
    while (*(digit + move) == ' ') {
        move++;
    }
    if (*digit != '{') {
        cout << "error in s2vvv" << endl;
        abort();
    }
    move++;
    while (*digit != '}') {
        vector<vector<t_index>> small;
        int move_now = s2vv(digit + move, small);
        result.push_back(small);
        {
            move += move_now;
        }

        while (*(digit + move) == ' ') {
            move++;
        }
        if (*(digit + move) == '}') {
            move++;
            break;
        }
        if (*(digit + move) != ',') {
            cout << "error in s2vvv" << *(digit + move) << endl;
            abort();
        }
        {
            move++;
        }
        while (*(digit + move) == ' ') {
            move++;
        }
    }
    return move;
}

/**
 * @brief Generate coefficient from coefficient string in LiteRed
 * @param cc coefficient string.
 * @param ssector the ssector we are working in
 * The coefficient is free meaning it does not contain any index dependencies as
 * most things in LiteRed do Variable substitutions are performed and fermat is
 * called in the prime version to simplify it to a number.
 * @return coefficient.
 */
COEFF generate_free_coeff_from_string(string cc, [[maybe_unused]] const sector_count_t ssector) {
    for (const char &symb : cc) {
        if (symb == '[' || symb == ']') {
            cout << "strange symbol in internal symmetries coefficient\n";
            abort();
        }
    }
    cc.erase(remove(cc.begin(), cc.end(), ' '), cc.end());

    COEFF c;
#ifdef PRIME
#ifdef MPRIME
    for (size_t i = 0; i != MPRIME; ++i) {
#else
        size_t i = 0;
#endif
        std::string cc_res = replace_all_variables(cc, i);
        // the coefficient is a number but it can be a fraction
        if (ssector == 0) {
            fuel::simplify(cc_res, 0);
        } else {
            calc_wrapper(cc_res, 0);
        }
        if (Common::large_variables) {
            fuel::simplify(cc_res, 0, true);
        }
        unsigned long num = string_fraction_to_modular(cc_res);
#ifndef MPRIME
        c.n = num;
#else
        c.N[i] = num;
    }
#endif
#else
    c.s = replace_all_variables(cc);
#endif
    return c;
}

/**
 * Analyse internal or external symmetries to write out sector dependencies
 * @param sn of sector we are working in.
 * @param right the right-hand side of the symmetry that is a permutation and
 * list of sums in different powers
 */
void store_symmetry_dependencies(
        const sector_count_t sn,
        const pair<vector<t_index>, vector<pair<vector<pair<COEFF, FastPoint>>, t_index>>> &right) {
    vector<t_index> &v = Common::ssectors[sn];
    vector<t_index> vres;
    vres.reserve(Common::dimension);
    for (unsigned int j = 0; j != Common::dimension; j++) {
        if (right.first[j] == 0) {
            vres.push_back(-1); // no index goes there and sums can have only negative
        } else {
            vres.push_back(v[right.first[j] - 1]); // here we get the current index
        }
    }
    for (const auto &sum : right.second) {
        for (const auto &term : sum.first) {
            for (unsigned int i = 0; i != Common::dimension; ++i) {
                if ((term.second.buf[i] < 0) && (vres[i] == 1)) {
                    vres[i] = 0; // meaning that this index can be positive and negative
                }
            }
        }
    }
    // we have this vres, now we need to build all sectors where 0 goes to -1 or
    // 1;
    int zeros = count(vres.begin(), vres.end(), 0);
    vector<vector<t_index>> lower_secs;
    lower_secs.reserve(1 << zeros);
    lower_secs.emplace_back(vres);
    while (zeros) {
        unsigned int pos = 0;
        while (lower_secs[0][pos])
            ++pos;
        for (auto &vec : lower_secs) {
            if (!vec[pos]) { // this check is needed because we are adding new
                vector<t_index> vec2 = vec;
                vec[pos] = -1;
                vec2[pos] = 1;
                lower_secs.emplace_back(vec2);
            }
        }
        --zeros;
    }
    for (auto &vec : lower_secs) {
        sector_count_t sn2 = Common::sector_numbers_fast[sector_fast(vec)];
        if (sn2 && sn != sn2) {
            dependencies[sn][sn2] = true;
            // cout<<sn<<"->"<<sn2<<endl;
        }
    }
}

/**
 * Parse lbases (Lee rules and symmetries) file.
 * @param c lbases file filename.
 * @param ssector number of sector we are working in.
 * @return true if lbases were parsed successfully, false otherwise.
 */
bool add_lbases(const char *c, const sector_count_t ssector) {
    FILE *file;
    char load_string[LOAD_STR_SIZE] = "none";
    string str;
    vector<t_index> v;
    int move;
    int n;
    unsigned int pn;
    lbases_loaded = true;

    file = fopen(c, "r");
    if (file == nullptr) {
        cerr << string(c) << endl << "Invalid lbases filename, exiting" << endl;
        return false;
    }

    while (fgets(load_string, sizeof(load_string), file)) {
        str += load_string;
    }

    for (auto &symb : str) {
        if ((symb == '\r') || (symb == '\n') || (symb == '\\')) {
            symb = ' ';
        }
    }

    const char *it = str.c_str();
    if (*it != '{') {
        cout << "wrong start (should be a pair)" << endl;
        abort();
    }
    it++;
    if (*it != '{') {
        cout << "wrong start of normal rules (should be a list)" << endl;
        abort();
    }
    it++;
    while (*it != '}') {
        if (*it != '{') {
            cout << "wrong start of rule (should be a triple)" << endl;
            abort();
        }
        it++;
        if (*it != '{') {
            cout << "wrong start of Point (should be a pair)" << endl;
            abort();
        }
        it++;
        move = s2u(it, pn);
        if (pn != Common::global_pn) {
            cout << "wrong problem number" << endl;
            abort();
        }
        it += move;
        if (*it != ',') {
            cout << "no comma after problem number" << endl;
            it -= 3;
            for (int i = 1; i <= 20; i++) {
                cout << *it;
                it++;
            }
            cout << endl;
            abort();
        }
        it++;
        while (*it == ' ')
            it++;
        if (*it != '{') {
            cout << "wrong start of sector" << endl;
            abort();
        }
        SECTOR sf;
        move = s2sf(it, sf);
        it += move;
        sector_count_t sn = Common::sector_numbers_fast[sf];
        if ((sn == 0) && (ssector == 0)) {
            cout << "Undefined sector: {" << pn << ", ";
            print_sector_fast(sf);
            cout << "}" << endl;
        }
        if (*it != '}') {
            cout << "closing bracket after sector missing" << endl;
            abort();
        }
        it++;
        if (*it != ',') {
            cout << "no comma after sector" << endl;
            abort();
        }
        it++;
        while (*it == ' ')
            it++;
        if (*it != '{') {
            cout << "wrong start of conditions" << endl;
            abort();
        }
        it++;
        vector<pair<vector<t_index>, pair<short, bool>>> conditions;
        while (*it != '}') {
            pair<short, bool> p2;                        // free term and condition
            pair<vector<t_index>, pair<short, bool>> p1; // complete condition
            if (*it != '{') {
                cout << "wrong start of condition (should be a triple)" << endl;
                abort();
            }
            it++;
            if (*it != '{') {
                cout << "wrong start of indices coefficients list" << endl;
                abort();
            }
            move = s2v(it, v);
            p1.first = v;
            it += move;
            if (*it != ',') {
                cout << "no comma after indices coefficients" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            move = s2i(it, n);
            p2.first = n;
            it += move;
            if (*it != ',') {
                cout << "no comma after free term" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            move = s2i(it, n);
            if (n == 1) {
                p2.second = true;
            } else if (n == 0) {
                p2.second = false;
            } else {
                cout << "incorrect condition" << endl;
                abort();
            }
            p1.second = p2;
            conditions.push_back(p1);
            it += move;
            if (*it != '}') {
                cout << "no closing bracket after bool check" << endl;
                abort();
            }
            it++;
            if (*it == ',')
                it++;
            while (*it == ' ')
                it++;
        }
        it++;
        if (*it != ',') {
            cout << "comma missing after conditions" << *it << endl;
            abort();
        }
        it++;
        while (*it == ' ')
            it++;
        if (*it != '{') {
            cout << "wrong start of right side" << endl;
            abort();
        }
        it++;
        vector<pair<std::vector<std::string>, vector<pair<vector<t_index>, short>>>> right;
        while (*it != '}') {
            pair<std::vector<std::string>, vector<pair<vector<t_index>, short>>> term;
            while (*it == ' ') {
                it++;
            }
            if (*it != '{') {
                cout << "wrong start of a term (should be a pair)" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it != '"') {
                cout << "starting quote missing for a coefficient" << endl;
                abort();
            }
            it++;
            move = 0;
            while (*(it + move) != '"')
                move++;
            std::string coeff = std::string(it, move);
            for (char &sit : coeff) {
                if (sit == '[')
                    sit = '(';
                if (sit == ']')
                    sit = ')';
            }
            coeff.erase(remove(coeff.begin(), coeff.end(), ' '), coeff.end());
            coeff = replace_all(coeff, "xxx", "aaa");

#ifdef MPRIME
            for (size_t i = 0; i != MPRIME; ++i) {
                std::string coeff_current = replace_all_variables(coeff, i);
                term.first.push_back(coeff_current);
            }
#else
            coeff = replace_all_variables(coeff);
            term.first.push_back(coeff);
#endif
            // cout << term.first << endl;
            // if you ever decide to rewrite lbases with Common::prime, uncomment it
            // and have a look at the v2l example the coefficients here are rational
            // functions of multiple a[i]
            it += move;
            it++;
            while (*it == ' ') {
                it++;
            }
            if (*it != ',') {
                cout << "no comma after coefficient" << endl;
                abort();
            }
            it++;
            while (*it == ' ') {
                it++;
            }
            if (*it != '{') {
                cout << "wrong start of target indices (should be a list)" << endl;
                abort();
            }
            it++;
            vector<pair<vector<t_index>, short>> indices;

            while (*it != '}') {
                pair<vector<t_index>, short> index;
                if (*it != '{') {
                    cout << "wrong start of index definition (should be a pair)" << endl;
                    abort();
                }
                it++;
                if (*it != '{') {
                    cout << "wrong start of index row" << endl;
                    abort();
                }
                move = s2v(it, v);
                index.first = v;
                it += move;
                if (*it != ',') {
                    cout << "no comma after index row" << endl;
                    abort();
                }
                it++;
                while (*it == ' ') {
                    it++;
                }
                move = s2i(it, n);
                index.second = n;
                it += move;
                while (*it == ' ')
                    it++;
                if (*it != '}') {
                    cout << "missing closing bracket after index definition" << endl;
                    abort();
                }
                it++;
                if (*it == ',')
                    it++;
                while (*it == ' ')
                    it++;
                indices.push_back(index);
            }
            term.second = indices;
            it++;
            if (*it != '}') {
                cout << "missing closing bracket after a term" << endl;
                abort();
            }
            it++;
            if (*it == ',')
                it++;
            while (*it == ' ')
                it++;
            right.push_back(term);
        }
        it++;
        if (*it != '}') {
            cout << "missing closing bracket after a rule" << endl;
            abort();
        }
        it++;
        if (*it == ',')
            it++;
        while (*it == ' ')
            it++;
        // if ((ssector == 0) || (ssector == sn)) {   // loading it only for our
        // sector and for main to work with preferred properly cout << "ADDING
        // LBASES FOR SECTOR " << sn << endl;
        auto it0 = Common::lbases.find(sn);
        vector<pair<vector<pair<vector<t_index>, pair<short, bool>>>,
            vector<pair<std::vector<std::string>, vector<pair<vector<t_index>, short>>>>>>
                lbasis;
        if (it0 != Common::lbases.end()) {
            lbasis = it0->second;
        }
        lbasis.emplace_back(conditions, right);
        if (it0 != Common::lbases.end()) {
            it0->second = lbasis;
        } else {
            Common::lbases.emplace(sn, lbasis);
        }
        Common::has_lbases[sn] = true;
        //}
    }

    it++;
    while (*it == ' ') {
        it++;
    }
    if (*it != ',') {
        cout << "missing comma after normal rules" << endl;
        abort();
    }
    it++;

    // here we started the second part
    while (*it == ' ') {
        it++;
    }
    if (*it != '{') {
        cout << "wrong start of delayed rules (should be a list)" << endl;
        abort();
    }
    it++;
    while (*it != '}') {
        while (*it == ' ') {
            it++;
        }
        if (*it != '{') {
            cout << "wrong start of a delayed term (should be a triple)" << endl;
            abort();
        }
        it++;
        while (*it == ' ') {
            it++;
        }

        unsigned int here_pn;
        if (*it != '{') {
            cout << "wrong start of a Point in delayed rule" << *it << endl;
            abort();
        }
        it++;
        move = s2u(it, here_pn);
        if (here_pn != Common::global_pn) {
            cout << "wrong problem number" << endl;
            abort();
        }
        it += move;
        while (*it == ' ')
            it++;
        if (*it != ',') {
            cout << "missing comma after a problem number in delayed rule" << endl;
            abort();
        }
        it++;
        while (*it == ' ')
            it++;
        if (*it != '{') {
            cout << "wrong start of a sector" << *it << endl;
            abort();
        }
        SECTOR sf;
        move = s2sf(it, sf);
        it += move;
        while (*it == ' ')
            it++;
        if (*it != '}') {
            cout << "missing closing bracket after a sector" << endl;
            abort();
        }
        it++;
        while (*it == ' ')
            it++;
        if (*it != ',') {
            cout << "missing comma after a point" << endl;
            abort();
        }
        it++;
        sector_count_t sn = Common::sector_numbers_fast[sf];
        if (((sn == 0) || (sn == 1) || (sn == Common::virtual_sector)) &&
                (ssector == 0)) { // printing only in main thread
            cout << "Ignoring rule for sector: {" << Common::global_pn << ", ";
            print_sector_fast(sf);
            cout << "}, reason: ";
            if (sn == 0) {
                cout << "zero sector";
            }
            if (sn == 1) {
                cout << "sector does not exist";
            }
            if (sn == Common::virtual_sector) {
                cout << "global symmetry used";
            }
            cout << endl;
        }
        while (*it == ' ')
            it++;
        vector<t_index> permutation;
        if (*it != '{') {
            cout << "wrong start of a permutation" << *it << endl;
            abort();
        }
        move = s2v(it, permutation);
        it += move;
        while (*it == ' ')
            it++;
        if (*it != ',') {
            cout << "missing comma after a permutation" << endl;
            abort();
        }
        it++;
        while (*it == ' ')
            it++;
        if (*it != '{') {
            cout << "wrong start of product (should be a list)" << *it << endl;
            abort();
        }
        it++;
        pair<vector<t_index>, vector<pair<vector<pair<COEFF, FastPoint>>, t_index>>> right;
        right.first = permutation;
        while (*it != '}') { // product
            pair<vector<pair<COEFF, FastPoint>>, t_index> pterm;
            while (*it == ' ')
                it++;
            if (*it != '{') {
                cout << "wrong start of a product term (should be a pair)" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it != '{') {
                cout << "wrong start of a sum (should be a list)" << endl;
                abort();
            }
            it++;
            while (*it != '}') { // sum
                pair<COEFF, FastPoint> term;
                while (*it == ' ')
                    it++;
                if (*it != '{') {
                    cout << "wrong start of a sum term (should be a pair)" << endl;
                    abort();
                }
                it++;
                while (*it == ' ')
                    it++;
                if (*it != '"') {
                    cout << "starting quote missing for a coefficient" << *it << endl;
                    abort();
                }
                it++;
                move = 0;
                while (*(it + move) != '"')
                    move++;

                string cc = string(it, move);
                if (sn == ssector || ssector == 1 || (ssector == 0 && Common::plan_file != ""))
                    term.first = generate_free_coeff_from_string(cc, ssector);

                it += move;
                it++;
                while (*it == ' ')
                    it++;
                if (*it != ',') {
                    cout << "no comma after coefficient" << endl;
                    abort();
                }
                it++;
                while (*it == ' ')
                    it++;
                if (*it != '{') {
                    cout << "wrong start of a sum term indices (should be a list)" << endl;
                    abort();
                }
                vector<t_index> tempv;
                move = s2v(it, tempv);
                term.second = FastPoint(tempv);

                it += move;
                while (*it == ' ')
                    it++;
                if (*it != '}') {
                    cout << "wrong end of a sum term (should be a pair)" << endl;
                    abort();
                }
                it++;
                while (*it == ' ')
                    it++;
                if (*it == ',')
                    it++;
                while (*it == ' ')
                    it++;
                pterm.first.push_back(term);
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it != ',') {
                cout << "comma missing after sum" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            move = s2i(it, n);
            pterm.second = n;
            it += move;
            while (*it == ' ')
                it++;
            if (*it != '}') {
                cout << "missing closing bracket after product term" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it == ',')
                it++;
            while (*it == ' ')
                it++;
            right.second.push_back(pterm);
        }
        if ((ssector == 1) || (ssector == 0 && Common::plan_file != "") ||
                ((sn != 0) && (sn != 1) && (sn != Common::virtual_sector) &&
                 (ssector == sn))) { // loading only our sector
            auto it0 = Point::dbases.find(sn);
            if (it0 != Point::dbases.end()) {
                cout << "Repeated delayed rule!!!";
                abort();
            }
            Point::dbases.emplace(sn, right);
        }
        if ((sn != 0) && (sn != 1) && (sn != Common::virtual_sector)) {
            if (Common::split_masters) {
                store_symmetry_dependencies(sn, right);
            }
        }
        it++;
        while (*it == ' ')
            it++;
        if (*it != '}') {
            cout << "missing closing bracket after delayed rule" << endl;
            abort();
        }
        it++;
        while (*it == ' ')
            it++;
        if (*it == ',')
            it++;
        while (*it == ' ')
            it++;
    }
    it++;

    if (*it != '}') { // old files had only 2 members
        int internal_count = 0;
        if (*it != ',') {
            cout << "wrong end" << endl;
            abort();
        }
        it++;
        while (*it == ' ')
            it++;
        if (*it != '{') {
            cout << "wrong start of symmetry rules (should be a list)" << endl;
            abort();
        }
        it++;
        while (*it != '}') {
            while (*it == ' ')
                it++;
            if (*it != '{') {
                cout << "wrong start of a symmetry term (should be a triple)" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            unsigned int here_pn;
            if (*it != '{') {
                cout << "wrong start of a Point in symmetry rule" << *it << endl;
                abort();
            }
            it++;
            move = s2u(it, here_pn);
            if (here_pn != Common::global_pn) {
                cout << "wrong problem number" << endl;
                abort();
            }
            it += move;
            while (*it == ' ')
                it++;
            if (*it != ',') {
                cout << "missing comma after a problem number in symmetry rule" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it != '{') {
                cout << "wrong start of a sector" << *it << endl;
                abort();
            }
            SECTOR sf;
            move = s2sf(it, sf);
            it += move;
            while (*it == ' ')
                it++;
            if (*it != '}') {
                cout << "missing closing bracket after a sector" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it != ',') {
                cout << "missing comma after a point" << endl;
                abort();
            }
            it++;
            sector_count_t sn = Common::sector_numbers_fast[sf];
            if (((sn == 0) || (sn == 1) || (sn == Common::virtual_sector)) &&
                    (ssector == 0)) { // printing only in main thread
                cout << "Ignoring rule for sector: {" << Common::global_pn << ", ";
                print_sector_fast(sf);
                cout << "}, reason: ";
                if (sn == 0)
                    cout << "zero sector";
                if (sn == 1)
                    cout << "sector does not exist";
                if (sn == Common::virtual_sector)
                    cout << "global symmetry used";
                cout << endl;
            }
            while (*it == ' ')
                it++;
            vector<t_index> permutation;
            if (*it != '{') {
                cout << "wrong start of a permutation" << *it << endl;
                abort();
            }
            move = s2v(it, permutation);
            it += move;
            while (*it == ' ')
                it++;
            if (*it != ',') {
                cout << "missing comma after a permutation" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it != '{') {
                cout << "wrong start of product (should be a list)" << *it << endl;
                abort();
            }
            it++;
            pair<vector<t_index>, vector<pair<vector<pair<COEFF, FastPoint>>, t_index>>> right;
            right.first = permutation;
            while (*it != '}') { // product
                pair<vector<pair<COEFF, FastPoint>>, t_index> pterm;
                while (*it == ' ')
                    it++;
                if (*it != '{') {
                    cout << "wrong start of a product term (should be a pair)" << endl;
                    abort();
                }
                it++;
                while (*it == ' ')
                    it++;
                if (*it != '{') {
                    cout << "wrong start of a sum (should be a list)" << endl;
                    abort();
                }
                it++;
                while (*it != '}') { // sum
                    pair<COEFF, FastPoint> term;
                    while (*it == ' ')
                        it++;
                    if (*it != '{') {
                        cout << "wrong start of a sum term (should be a pair)" << endl;
                        abort();
                    }
                    it++;
                    while (*it == ' ')
                        it++;
                    if (*it != '"') {
                        cout << "starting quote missing for a coefficient" << *it << endl;
                        abort();
                    }
                    it++;
                    move = 0;
                    while (*(it + move) != '"')
                        move++;

                    string cc = string(it, move);
                    if (sn == ssector || ssector == 1 || (ssector == 0 && Common::plan_file != ""))
                        term.first = generate_free_coeff_from_string(cc, ssector);

                    it += move;
                    it++;
                    while (*it == ' ')
                        it++;
                    if (*it != ',') {
                        cout << "no comma after coefficient" << endl;
                        abort();
                    }
                    it++;
                    while (*it == ' ')
                        it++;
                    if (*it != '{') {
                        cout << "wrong start of a sum term indices (should be a list)" << endl;
                        abort();
                    }
                    vector<t_index> tempv;
                    move = s2v(it, tempv);
                    term.second = FastPoint(tempv);
                    it += move;
                    while (*it == ' ')
                        it++;
                    if (*it != '}') {
                        cout << "wrong end of a sum term (should be a pair)" << endl;
                        abort();
                    }
                    it++;
                    while (*it == ' ')
                        it++;
                    if (*it == ',')
                        it++;
                    while (*it == ' ')
                        it++;
                    pterm.first.push_back(term);
                }
                it++;
                while (*it == ' ')
                    it++;
                if (*it != ',') {
                    cout << "comma missing after sum" << endl;
                    abort();
                }
                it++;
                while (*it == ' ')
                    it++;
                move = s2i(it, n);
                pterm.second = n;
                it += move;
                while (*it == ' ')
                    it++;
                if (*it != '}') {
                    cout << "missing closing bracket after product term" << endl;
                    abort();
                }
                it++;
                while (*it == ' ')
                    it++;
                if (*it == ',')
                    it++;
                while (*it == ' ')
                    it++;
                right.second.push_back(pterm);
            }

            // loading only our sector
            if ((ssector == 1) || (ssector == 0 && Common::plan_file != "") ||
                    ((sn != 0) && (sn != 1) && (sn != Common::virtual_sector) &&
                     (ssector == sn))) { // loading only our sector
                auto it0 = Point::ibases.find(sn);
                vector<pair<vector<t_index>, vector<pair<vector<pair<COEFF, FastPoint>>, t_index>>>> irules;
                if (it0 != Point::ibases.end()) {
                    irules = it0->second;
                }
                irules.push_back(right);
                ++internal_count;
                if (it0 != Point::ibases.end()) {
                    it0->second = irules;
                } else {
                    Point::ibases.emplace(sn, irules);
                }
            }

            if ((sn != 0) && (sn != 1) && (sn != Common::virtual_sector)) {
                if (Common::split_masters) {
                    store_symmetry_dependencies(sn, right);
                }
            }

            it++;
            while (*it == ' ')
                it++;
            if (*it != '}') {
                cout << "missing closing bracket after delayed rule" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it == ',')
                it++;
            while (*it == ' ')
                it++;
        }
        it++;
        if (internal_count && !Common::ftool && !Common::silent) {
            cout << "Found " << internal_count << " internal symmetries for sector " << ssector << endl;
        }
    }

    if (*it != '}') {
        cout << "missing final closing bracket" << endl;
        abort();
    }

    fclose(file);
    return true;
}

/**
 * Add a Point to list of preferred points in point's sector.
 * @param v vector of point's simple coefficients.
 * @return True if it is a new integral
 */
bool add_single_preferred(const vector<t_index> &v) {
    SECTOR s = sector_fast(v);
    // cout << "ADDING PREFERRED ";
    // print_vector(v);
    // cout<<endl;
    sector_count_t sn = Common::sector_numbers_fast[s];
    bool result = (Point::preferred[sn].find(v) == Point::preferred[sn].end());
    Point::preferred[sn].insert(v);
    Point::preferred_fast[sn].insert(FastPoint(v));
    return result;
}

/**
 * Read the list of prefered integrals (or masters in case of split master
 * mode) and write them to memory
 * @param c preferred file filename.
 * @return the number of integrals in the file
 */
int load_preferred(const char *c) {
    FILE *preferred_int_file = fopen(c, "r");
    char load_string[LOAD_STR_SIZE] = "none";
    string contents;
    if (preferred_int_file == nullptr) {
        cout << "File with preferred integrals could not be opened, exiting" << endl;
        return -1;
    }
    while (fgets(load_string, sizeof(load_string), preferred_int_file)) {
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
    int pref_count = 0;
    while (all[move] != '}') {
        while (all[move] == ' ')
            move++;
        if (all[move] != '{') {
            cout << "Error in pref:" << all[move] << endl;
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;
        unsigned int i;
        move += s2u(all + move, i);
        if (i != Common::global_pn) {
            cerr << "Unknown problem number " << i << endl;
            fclose(preferred_int_file);
            return -1;
        }
        while (all[move] == ' ')
            move++;
        if (all[move] != ',') {
            cout << "Error in pref:";
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;
        vector<t_index> v;
        move += s2v(all + move, v);

        // the set of manually set preferred
        bool new_pref = add_single_preferred(v);
        if (Common::split_masters && new_pref) {
            cout << "WARNING: PREFERED INTEGRAL THAT IS NOT IN THE LIST OF "
                "MASTERS: ";
            print_vector(v);
            cout << endl;
        }
        ++pref_count;

        while (all[move] == ' ')
            move++;
        if (all[move] != '}') {
            cout << "Error in pref:";
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;
        if (all[move] == '}')
            break;
        if (all[move] != ',') {
            cout << "Error in pref:";
            abort();
        }
        move++;
    }
    fclose(preferred_int_file);
    return pref_count;
}

/**
 * Read the list of masters and set most of them to zero
 * @param c masters file filename.
 * @param sector the sector number
 */
void set_masters_to_zero(const char *c, const sector_count_t sector) {
    FILE *file;
    char load_string[LOAD_STR_SIZE] = "none";
    string str;
    string str_p;
    // size_t found;
    unsigned int master_counter = 1;

    file = fopen(c, "r");
    if (file == nullptr) {
        cout << string(c) << endl << "Invalid masters filename, exiting" << endl;
        abort();
    }

    string contents{};
    while (fgets(load_string, sizeof(load_string), file)) {
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
    while (all[move] != '}') {
        while (all[move] == ' ')
            move++;
        if (all[move] != '{') {
            cout << "Error in masters: " << all[move] << endl;
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;
        unsigned int i;
        move += s2u(all + move, i);
        if (i != Common::global_pn) {
            cout << "Unknown problem number in master" << i << endl;
            abort();
        }

        while (all[move] == ' ')
            move++;
        if (all[move] != ',') {
            cout << "Error in integrals, missing comma";
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;
        vector<t_index> v;
        move += s2v(all + move, v);

        Point p = point_reference(v);
        if (!p.IsZero()) {
            add_single_preferred(v);
            vector<pair<Point, COEFF>> terms;

            p = point_reference(v); // once again, now preferred
            if ((master_counter >= Common::master_number_min) && (master_counter <= Common::master_number_max)) {
                needed_sectors[p.SectorNumber()] = true;
                if (!Common::silent && (sector == 0 || sector == 1))
                    cout << "New master integral: " << p << endl;
                masters.insert(p);
#ifdef PRIME
                COEFF one(1);
#else
                COEFF one;
                one.s = "1";
#endif
                Point p1(p.GetVector(), 0, -2); // sending to sector 1
                terms.emplace_back(p1, one);
            } else {
                if (!Common::silent && (sector == 0 || sector == 1))
                    cout << "Setting master integral to zero: " << p << endl;
            }

#ifdef PRIME
            COEFF minus_one(Common::prime - 1);
#else
            COEFF minus_one;
            minus_one.s = "-1";
#endif
            terms.emplace_back(p, minus_one);
            if (sector == 0 && Common::stages != t_stages::backward) {
                if (Common::wrap_databases) {
                    database_to_file_or_back(p.SectorNumber(), false);
                }
                open_database(p.SectorNumber());
                p_set(p, terms, true);
                close_database(p.SectorNumber());
                if (Common::wrap_databases) {
                    database_to_file_or_back(p.SectorNumber(), true);
                }
            } else if (sector == 1) {
                Equation::initial_rules.emplace_back(terms);
            }
            ++master_counter;
        }

        while (all[move] == ' ')
            move++;
        if (all[move] != '}') {
            cout << "Error in masters, missing closing bracket ";
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;
        if (all[move] == '}')
            break;
        if (all[move] != ',') {
            cout << "Error in masters, missing comma between integrals";
            abort();
        }
        move++;
    }
    if (master_counter <= Common::master_number_max) {
        cout << "Specified maximal master number (" << Common::master_number_max
            << ") is bigger than the number of masters in file (" << master_counter - 1 << ")" << endl;
        abort();
    }
    fclose(file);
}

/**
 * Parse rules (master integral mappings) file.
 * @param c rules file filename.
 * @param sector number of sector we are working in.
 * @return true if lbases were parsed successfully, false otherwise.
 */
bool add_rules(const char *c, const sector_count_t sector) {
    FILE *file;
    char load_string[LOAD_STR_SIZE] = "none";
    string str;
    string str_p;
    size_t found;

    file = fopen(c, "r");
    if (file == nullptr) {
        cerr << string(c) << endl << "Invalid rules filename, exiting" << endl;
        return false;
    }

    int rule_counter = 0;
    while (fgets(load_string, sizeof(load_string), file)) {
        for (int j = 0; j != sizeof(load_string); ++j) {
            if (load_string[j] == '\r') {
                load_string[j] = '\n';
            }
        }

        if ((load_string[1] == '\n' || load_string[0] == '\n') && str != "") {
            for (auto &symb : str) {
                if (symb == '\n')
                    symb = ' ';
            }

            int n, n2;
            rule_counter++;
            found = str.find('G');
            str = str.substr(found + 2);
            int move = s2i(str.c_str(), n);

            str = str.substr(move + 2);
            vector<t_index> v;
            s2v(str.c_str(), v);
            found = str.find("->");
            str = str.substr(found + 2);

            // left-hand side of the rule
            add_single_preferred(v);

            Point p = point_reference(v);
            if ((p.IsZero()) && (sector == 0)) {
                cout << "Attempt to create a rule for {" << n << ", ";
                print_vector(v);
                cout << "} ignored" << endl;
                rule_counter--;
                continue;
            }

            if ((p.SectorNumber() == 1) && (sector == 0)) {
                cout << "Attempt to create a rule for {" << n << ", ";
                print_vector(v);
                cout << "} ignored" << endl;
                rule_counter--;
                continue;
            }

            vector<pair<Point, COEFF>> mon;
            if (str.find('{') < str.find('G')) {     //"}"
                str = str.substr(str.find('{') + 1); //"}"
            }
            while (str.find('G') != string::npos) { // here we build it just with strings
                while ((str[0] == ' ') || (str[0] == '{') || (str[0] == '}') || (str[0] == ',')) {
                    str = str.substr(1);
                }
                found = str.find('G');
                string current_coeff = found ? str.substr(0, found) : "1";
                if (current_coeff.find(',') != string::npos) {
                    current_coeff = current_coeff.substr(0, current_coeff.find(','));
                }
                str = str.substr(found + 2);
                move = s2i(str.c_str(), n2);
                str = str.substr(move + 2);
                vector<t_index> v2;
                move = s2v(str.c_str(), v2);
                str = str.substr(move + 2);

                // right-hand side
                add_single_preferred(v2);
                Point p2 = point_reference(v2);

                if (Common::split_masters) {
                    dependencies[p.SectorNumber()][p2.SectorNumber()] = true;
                    // if (!sector) cout<<p.SectorNumber()<<"->"<<p2.SectorNumber()<<endl;
                }

                // reading is done, preferred is set, that's all we need for other
                // sectors
                if ((sector == 0 && Common::stages != t_stages::backward) || sector == 1) {

                    Point p3(v2, 0, -2); // sending to sector 1

#ifdef PRIME
                    COEFF current_COEFF;
#ifdef MPRIME
                    for (size_t i = 0; i != MPRIME; ++i) {
#else
                        size_t i = 0;
#endif
                        std::string current_coeff_main = replace_all_variables(current_coeff, i);
                        if ((sector == 0) && (!Common::receive_from_child)) {
                            fuel::simplify(current_coeff_main, 0);
                        } else {
                            calc_wrapper(current_coeff_main, 0);
                        }
                        fuel::simplify(current_coeff_main, 0, true);
#ifndef MPRIME
                        current_COEFF.n = string_fraction_to_modular(current_coeff_main);
#else
                        current_COEFF.N[i] = string_fraction_to_modular(current_coeff_main);
                    }
#endif
                    COEFF one(1);
                    COEFF minus_one(Common::prime - 1);
#else
                    std::string current_coeff_main = replace_all_variables(current_coeff);
                    COEFF one;
                    COEFF minus_one;
                    one.s = "1";
                    minus_one.s = "-1";
                    if ((sector == 0) && (!Common::receive_from_child)) {
                        fuel::simplify(current_coeff_main, 0);
                    } else {
                        calc_wrapper(current_coeff_main, 0);
                    }
                    COEFF current_COEFF;
                    current_COEFF.s = current_coeff_main;
#endif
                    if (masters.find(p2) == masters.end()) {
                        // it's not listed in masters
                        // either it is split mode, and we have to check if it is zero
                        // or it is normal mode and we need to write a relation
                        vector<pair<Point, COEFF>> t;
                        t.emplace_back(p3, one);
                        t.emplace_back(p2, minus_one);
                        if (sector != 1) {
                            if (Common::wrap_databases) {
                                database_to_file_or_back(p2.SectorNumber(), false);
                            }
                            open_database(p2.SectorNumber());
                        }

                        if (Common::split_masters && sector != 1) {
                            if (p_get_monoms(p2, p2.SectorNumber()).size() != 1) {
                                cout << "Master integral in right-hand side of rules not "
                                    "listed in masters file"
                                    << endl;
                                abort();
                            }
                        } else {
                            if (sector == 1) {
                                Equation::initial_rules.emplace_back(t);
                                Equation::initial_masters.insert(p3);
                            } else {
                                p_set(p2, t, true);
                                // the rule right-hand sides are masters
                            }
                            masters.insert(p2);
                            mon.emplace_back(p3, current_COEFF);
                            if (!Common::silent)
                                cout << "New master integral: " << (p2) << endl;
                        }
                        if (sector != 1) {
                            close_database(p2.SectorNumber());
                            if (Common::wrap_databases) {
                                database_to_file_or_back(p2.SectorNumber(), true);
                            }
                        }
                    } else {
                        mon.emplace_back(p3, current_COEFF);
                    }
                }
            }

            if ((sector == 0 && Common::stages != t_stages::backward) || sector == 1) {
                // no need to write entry for the rule for other sectors
                sort(mon.begin(), mon.end(), pair_point_coeff_smaller);

                vector<pair<Point, COEFF>> terms;

                for (auto read = mon.begin(); read != mon.end(); ++read) {
                    COEFF coeff2 = read->second;
                    auto read2 = read;
                    read2++;
                    while ((read2 != mon.end()) && (read2->first == read->first)) {
                        coeff2 = coeff2 + read2->second;
                        read2++;
                    }
                    read2--;
                    read = read2;
#ifdef PRIME
                    COEFF zero(0);
                    if (!(coeff2 == zero)) {
                        terms.emplace_back(read->first, coeff2);
                    }
#else
                    if (!Common::receive_from_child) {
                        fuel::simplify(coeff2.s, 0);
                    } else {
                        calc_wrapper(coeff2.s, 0);
                    }
                    if (!(coeff2.s == "0")) {
                        terms.emplace_back(read->first, coeff2);
                    }
#endif
                }

#ifdef PRIME
                COEFF minus_one(Common::prime - 1);
#else
                COEFF minus_one;
                minus_one.s = "-1";
#endif

                terms.emplace_back(p, minus_one);

                if (Common::wrap_databases) {
                    database_to_file_or_back(p.SectorNumber(), false);
                }
                open_database(p.SectorNumber());
                if (sector == 1) {
                    Equation::initial_rules.emplace_back(terms);
                } else {
                    p_set(p, terms, true); // the left rule side is not really
                                           // needed... but should not hurt
                }
                close_database(p.SectorNumber());
                if (Common::wrap_databases) {
                    database_to_file_or_back(p.SectorNumber(), true);
                }
            }
            str = "";
        }
        else {
            str += load_string;
            if (str == string("Null\n")) {
                str = "";
            }
        }
    }
    if ((sector == 0) && !Common::silent) {
        cout << "Loaded " << rule_counter << " rules." << endl;
    }
    fclose(file);
    return true;
}

/**
 * Add corresponding problem to global data, parsing of start file or sbases
 * file.
 * @param problem_number number of problem.
 * @param cc problem specification.
 * @param positive_indices the indices that are restricted to be positive
 * @param sector number of sector.
 * @return true if problem was added successfully, false otherwise.
 */
bool add_problem(const unsigned int problem_number, const char *cc, const std::vector<int> &positive_indices,
        const sector_count_t sector) {
    Common::global_pn = problem_number;
    int positive = 0;
    int positive_start = 1;
    int move = 0;
    if (*cc == '|') {
        move = s2i(cc + 1, positive) + 1;
        if (*(cc + move) == ',') {
            positive_start = positive;
            positive = 0;
            move += (s2i(cc + move + 1, positive) + 2);
        } else if (*(cc + move) == '|') {
            move++;
        } else {
            cerr << "Incorrect problem syntax" << endl;
            abort();
        }
    }
    const char *c;
    string tmp;
    if (*cc == '/') {
        c = cc;
    } else {
        tmp = Common::folder + string(cc + move);
        c = tmp.c_str();
    }

    FILE *file;
    char load_string[LOAD_STR_SIZE] = "none";
    string str;
    string str_p;
    size_t found;

    int n, m;
    file = fopen(c, "r");
    if (file == nullptr) {
        cerr << string(c) << endl << "Invalid problem filename, exiting" << endl;
        return false;
    }

    str = "";

    vector<vector<vector<t_index>>> local_symmetries;

    unsigned int dimension = 0;
    bool read;
    while (true) {
        read = fgets(load_string, sizeof(load_string), file);
        if (!read || load_string[1] == '\n' || load_string[0] == '\n' || load_string[0] == '\r' ||
                load_string[1] == '\r') {
            for (auto &symb : str) {
                if ((symb == '\n') || (symb == '\r')) {
                    symb = ' ';
                }
            }
            string substr = ("ExampleDimension");
            if (str.substr(0, substr.size()) == substr) {
                found = str.find('=');
                str = str.substr(found + 2);
                s2i(str.c_str(), n);
                dimension = n;
                if (positive == 0) {
                    positive = dimension;
                }

                vector<vector<t_index>> all = all_sectors(n, positive, positive_start);

                if (dimension > MAX_IND) {
                    cout << "Maximal dimension with current options is " << MAX_IND
                        << ", see configure script for details and possible variants"<< endl;
                    abort();
                }

                Common::dimension = n;
                if (Common::index_ordering.empty()) {
                    for (unsigned short i = 0; i != Common::dimension; ++i) {
                        Common::index_ordering.push_back(i + 1);
                    }
                }
                Common::orderings_fast = make_unique<unique_ptr<uint32_t[]>[]>(1 << (n));

                size_t max_sectors = (1u << n);
                Common::sector_numbers_fast = make_unique<sector_count_t[]>(max_sectors);

                Point::preferred.reserve(max_sectors + 1);
                Point::preferred_fast.reserve(max_sectors + 1);
                for (unsigned int i = 0; i != max_sectors + 1; ++i) {
                    Point::preferred.emplace_back();
                    Point::preferred_fast.emplace_back();
                }
                Point::preferred_initial = Point::preferred;

                // for fast getting sector numbers
                // we fill it with -1 now and set 0 for non-existing sectors
                for (uint32_t i = 0; i != max_sectors; ++i) {
                    if (i >> (n - positive_start + 1)) {
                        // highest bits correspond to first indices
                        Common::sector_numbers_fast[i] = 0;
                    } else if (i & ((1 << (n - positive)) - 1)) {
                        Common::sector_numbers_fast[i] = 0;
                    } else
                        Common::sector_numbers_fast[i] =
                            static_cast<sector_count_t>(-1); // number will be given later
                }
                str = "";
                continue;
            }
            substr = ("SBasis0L");
            if (str.substr(0, substr.size()) == substr) {
                if (sector > 0) {
                    found = str.find('=');
                    str = str.substr(found + 2);
                    s2i(str.c_str(), n);
                    for (int i = 0; i < n; ++i) {
                        Point::ibps.emplace_back();
                    }
                }
                str = "";
                continue;
            }
            substr = ("SBasisR[");
            if (str.substr(0, substr.size()) == substr) {
                bool IsZero = false;
                found = str.find("True");
                SECTOR sf = 0;
                if (found != string::npos) {
                    IsZero = true;
                }
                found = str.find(',');
                str_p = str.substr(found + 2);
                s2sf(str_p.c_str(), sf);
                if (!IsZero) {
                    for (auto ind : positive_indices) {
                        if ((sf & (SECTOR(1) << (Common::dimension - ind))) == 0) {
                            IsZero = true;
                            // std::cout << "We got zero for " << str << std::endl;
                            break;
                        }
                    }
                }
                if (IsZero) {
                    Common::sector_numbers_fast[sf] = 0; // zero, unnumbered are -1
                }
                str = "";
                continue;
            }
            substr = ("SBasis0C");
            if (str.substr(0, substr.size()) == substr) {
                if (sector > 0) {
                    found = str.find(',');
                    str = str.substr(found + 2);
                    s2i(str.c_str(), m);

                    found = str.find(',');
                    str = str.substr(found + 3);
                    found = str.find(']');
                    str_p = str.substr(0, found - 1);
                    str = str.substr(found + 4);
                    vector<t_index> v;
                    while (found != string::npos) {
                        s2i(str_p.c_str(), n);
                        v.push_back(n);
                        found = str_p.find(',');
                        str_p = str_p.substr(found + 2);
                        while (str_p[0] == ' ')
                            str_p = str_p.substr(1, str_p.size() - 1);
                    }

                    // now it should be just the whole coefficient, that should be
                    // better parsed here due to substitutions some of the
                    // coefficients might become 0. we have to get them away
                    str = replace_all(str, ",", "|");
                    std::vector<COEFF> coeffs = split_coeff(str);
                    bool good_term = false;
                    for (const auto &coeff : coeffs) {
                        if (!coeff.Empty()) {
                            good_term = true;
                            break;
                        }
                    }
                    if (good_term) {
                        Point::ibps[m - 1].emplace_back(coeffs, FastPoint(v));
                    }
                }
                str = "";
                continue;
            }
            substr = ("SBasisS");
            if (str.substr(0, substr.size()) == substr) {
                found = str.find('{'); //"}"
                str = str.substr(found);
                s2vvv(str.c_str(), local_symmetries);
                str = "";
                continue;
            }

            substr = ("SBasisN");
            if (str.substr(0, substr.size()) == substr) {
                found = str.find(',');
                str = str.substr(found + 1);
                const char *pos = str.c_str();
                SECTOR sf;
                s2sf(pos, sf);
                if (Common::sector_numbers_fast[sf]) {
                    Common::lsectors.emplace(sf); // only if this is a non-zero sector
                                                  // (actually -1 at this point);
                }
                str = "";
                continue;
            }

            substr = ("SBasisO");
            if (str.substr(0, substr.size()) == substr) {
                found = str.find(',');
                str = str.substr(found + 2);
                vector<t_index> sec;

                int new_move = s2v(str.c_str(), sec);

                found = str.find('{', new_move); //"}"
                str = str.substr(found);

                vector<vector<t_index>> ord;
                s2vv(str.c_str(), ord);

                Common::orderings_fast[sector_fast(sec)] = make_unique<uint32_t[]>(Common::dimension);
                auto mat = Common::orderings_fast[sector_fast(sec)].get();
                int row = 0;
                for (auto itr_row = ord.begin(); itr_row != ord.end(); ++itr_row, ++row) {
                    // now we stopped using vectors, moving to arrays, it's much
                    // faster and array of vectors leads to crashes
                    int column = 0;
                    uint32_t bit = 1;
                    uint32_t res = 0;
                    for (auto itr_column = itr_row->begin(); itr_column != itr_row->end();
                            ++itr_column, ++column) {
                        if (*itr_column) {
                            res += bit;
                        }
                        bit <<= 1;
                    }
                    mat[row] = res;
                }
                //}
                str = "";
                continue;
        }
        str = "";
        if (!read)
            break;
    } else {
        str += load_string;
        if (str == string("Null\n")) {
            str = string("");
        }
    }
}

vector<t_index> uuuu;
uuuu.push_back(positive);
for (auto &local_symmetry : local_symmetries) {
    local_symmetry.push_back(uuuu);
}

Common::symmetries = local_symmetries;
if (dimension == 0) {
    cout << "Something weird in add_problem - dimension wasn't set!" << endl;
    abort();
}
vector<vector<t_index>> all0 = all_sectors(dimension, positive, positive_start);
vector<vector<t_index>> all;
all.reserve(all0.size());

for (const auto &sector_in_all : all0) {
    if (Common::sector_numbers_fast[sector_fast(sector_in_all)] == static_cast<sector_count_t>(-1)) {
        all.push_back(sector_in_all);
    }
    // non-zero sectors
    // we will enumerate later, so not changing sector_numbers_fast
}

std::sort(all.begin(), all.end(), sector_sort_function);

Common::ssectors.emplace_back();
Common::ssectors.emplace_back();
sector_count_t current_sector = 2;

for (const auto &l_sector : all) {
    // we do not enumerate sectors with level 16+
    if (positive_index(l_sector) <= 15) {
        vector<vector<t_index>> orbit;
        symmetry_orbit(l_sector, orbit, local_symmetries);
        vector<t_index> *lowest = &(*orbit.begin());
        auto itr = orbit.begin();
        itr++;
        while (itr != orbit.end()) {
            if (sector_sort_function(*itr, *lowest))
                lowest = &(*itr);
            itr++;
        }

        if (Common::sector_numbers_fast[sector_fast(*lowest)] == static_cast<sector_count_t>(-1)) {
            Common::sector_numbers_fast[sector_fast(*lowest)] = current_sector;
            Common::ssectors.push_back(*lowest);
            if (positive_index(*lowest) < Common::abs_min_level) {
                Common::abs_min_level = positive_index(*lowest);
            }

            ++current_sector;
            if (current_sector == MAX_SECTORS - 2) {
                cerr << "Too many non-zero sectors with current options";
                cerr << "see the configure script for details and variants!" << endl;
                fclose(file);
                return false;
            }
        }
    }
};

Common::virtual_sector = current_sector;
for (const auto &l_sector : all) {
    // we do not enumerate sectors with level 16+
    if (positive_index(l_sector) <= 15) {
        if (Common::sector_numbers_fast[sector_fast(l_sector)] == static_cast<sector_count_t>(-1)) {
            Common::sector_numbers_fast[sector_fast(l_sector)] = Common::virtual_sector;
            // all sectors in higher symmetry orbits are marked as
            // Common::virtual_sector for faster comparing
        }
    }
}

// virtual
vector<t_index> *v;
if (all.empty()) {
    v = &(*all0.rbegin());
} else {
    v = &(*all.rbegin());
}
Common::ssectors.push_back(*v);

Common::abs_max_sector = current_sector - 1;
if (Common::abs_min_level == 0) {
    cout << "Non-zero zero sector (no restrictions at all)" << endl;
    abort();
}

// invert orderings
int sn = 0;
Common::iorderings.resize(Common::abs_max_sector + 2);

for (const auto &ssector : Common::ssectors) {
    if (sn > 1) {
        if (Common::orderings_fast[sector_fast(ssector)] == nullptr) {
            Common::orderings_fast[sector_fast(ssector)] = make_unique<uint32_t[]>(Common::dimension);
            // if (sn == 484)
            make_ordering(Common::orderings_fast[sector_fast(ssector)].get(), ssector,
                    Common::ordering_string);
            // else
            //     make_ordering(Common::orderings_fast[sector_fast(ssector)].get(),
            //     ssector, "ANm");
        }
        if (dimension == 0) {
            cout << "Something weird in add_problem - dimension wasn't set!" << endl;
            abort();
        }
        int matrix[MAX_IND][MAX_IND];
        int matrix_orig[MAX_IND][MAX_IND];
        for (unsigned int i = 0; i != dimension; ++i) {
            uint32_t bit = 1;
            for (unsigned int j = 0; j != dimension; ++j) {
                if (Common::orderings_fast[sector_fast(ssector)][i] & bit) {
                    matrix[i][j] = 1;
                } else {
                    matrix[i][j] = 0;
                }
                matrix_orig[i][j] = matrix[i][j];
                bit <<= 1;
            }
        }
        try {
            invers(matrix, dimension);
            for (unsigned int i = 0; i != dimension; ++i) {
                for (unsigned int j = 0; j != dimension; ++j) {
                    int res = 0;
                    for (unsigned int k = 0; k != dimension; ++k) {
                        res += matrix_orig[i][k] * matrix[k][j];
                    }
                    if (i == j)
                        --res;
                    if (res != 0) {
                        cout << "incorrect invers " << endl;
                        throw std::exception();
                    }
                }
            }
        } catch (...) {
            cout << "{" << endl;
            for (unsigned int i = 0; i != dimension; ++i) {
                cout << "{";
                uint32_t bit = 1;
                for (unsigned int j = 0; j != dimension; ++j) {
                    if (Common::orderings_fast[sector_fast(ssector)][i] & bit) {
                        cout << 1;
                    } else {
                        cout << 0;
                    }
                    if (j != dimension - 1)
                        cout << ", ";
                    bit <<= 1;
                }
                cout << "}";
                if (i != dimension - 1)
                    cout << ",";
                cout << endl;
            }
            cout << "}" << endl;
            abort();
        }
        vector<vector<t_index>> &iord = Common::iorderings[sn];
        for (unsigned int i = 0; i != dimension; ++i) {
            vector<t_index> temp;
            for (unsigned int j = 0; j != dimension; ++j) {
                temp.push_back(t_index(matrix[i][j]));
            }
            iord.push_back(temp);
        }
    }
    ++sn;
}
fclose(file);
return true;
}

/**
 * @brief Initialies dependency relations by sectors
 * Knowing the sector numbers creates proper matrices
 * For normal sectors writes out the IBP go down relations
 */
void initialize_dependencies() {
    dependencies.reserve(Common::abs_max_sector + 1);
    needed_sectors.reserve(Common::abs_max_sector + 1);
    for (sector_count_t i = 0; i != Common::abs_max_sector + 1; ++i) {
        vector<bool> dependency;
        if (i > 1) {
            dependency.reserve(Common::abs_max_sector + 1);
            for (sector_count_t j = 0; j != Common::abs_max_sector + 1; ++j) {
                dependency.push_back(false);
            }
            if (in_lsectors(i)) {
                // normal sector, lets set down dependency right now
                vector<t_index> v = Common::ssectors[i];
                for (int k = 0; k != Common::dimension; ++k) {
                    if (v[k] == 1) {
                        auto v2(v);
                        v2[k] = -1;
                        auto num = Common::sector_numbers_fast[sector_fast(v2)];
                        if (num == static_cast<sector_count_t>(-1)) {
                            // that's a non lowest sector in an orbit
                            vector<vector<t_index>> orbit;
                            symmetry_orbit(v2, orbit, Common::symmetries);
                            vector<t_index> *lowest = &(*orbit.begin());
                            auto itr = orbit.begin();
                            itr++;
                            while (itr != orbit.end()) {
                                if (sector_sort_function(*itr, *lowest))
                                    lowest = &(*itr);
                                itr++;
                            }
                            num = Common::sector_numbers_fast[sector_fast(*lowest)];
                        }
                        if (num)
                            dependency[num] = true;
                    }
                }
            }
        }
        dependencies.emplace_back(dependency);
        needed_sectors.push_back(false);
    }
}

/**
 * Advanced recursive mkdir.
 * @param s path to create.
 * @param mode file permission.
 * @return error code, 0 on success.
 */
int mkpath(std::string s, mode_t mode) {
    size_t pre = 0, pos;
    std::string dir;
    int mdret;
    if (s[s.size() - 1] != '/') {
        // force trailing / so we can handle everything in loop
        s += '/';
    }
    while ((pos = s.find_first_of('/', pre)) != std::string::npos) {
        dir = s.substr(0, pos++);
        pre = pos;
        if (dir == "")
            continue; // if leading / first time is 0 length
        if ((mdret = mkdir(dir.c_str(), mode)) && errno != EEXIST) {
            return mdret;
        }
    }
    return 0;
}

int parse_long(const char *digit, int64_t &result) {
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

int parse_vector(const char *digit, vector<int64_t> &result) {
    result.clear();
    result.reserve(Common::dimension);
    int move = 0;
    while (*(digit + move) == ' ') {
        move++;
    }
    if (*(digit + move) != '{') {
        cout << "!error in parse_vector" << string(digit) << "!" << endl;
        cout << endl;
        abort();
    }
    move++;
    while (*(digit + move) == ' ') {
        move++;
    }
    while (*digit != '}') {
        int64_t number;
        int move_now = parse_long(digit + move, number);
        result.push_back(number);
        move += move_now;

        while (*(digit + move) == ' ') {
            move++;
        }
        if (*(digit + move) == '}') {
            move++;
            break;
        }
        if (*(digit + move) != ',') {
            cout << "!error in parse_vector" << string(digit) << "!" << endl;
            cout << endl;
            abort();
        }
        move++;
        while (*(digit + move) == ' ') {
            move++;
        }
    }
    return move;
}

void leave_used_points(set<FastPoint> & s_fast) {
    if (Common::points_used == t_points::all) {
        return;
    }
    set<FastPoint> res;
    for (const auto &p : s_fast) {
        int sum = 0;
        for (int pos = 0; pos != Common::dimension; ++pos) {
            if (Common::parity_used[pos]) {
                sum += p.buf[pos];
            }
        }
        if ((sum % 2) == 0) {
            if (Common::points_used == t_points::even) {
                res.insert(p);
            }
        } else {
            if (Common::points_used == t_points::odd) {
                res.insert(p);
            }
        }
    }
    s_fast = res;
}

int load_integrals(const string &filename, set<Point, std::greater<Point>> &points) {
    FILE *integral_file;
    if (filename[0] == '/') {
        integral_file = fopen((filename).c_str(), "r");
    } else {
        integral_file = fopen((Common::folder + filename).c_str(), "r");
    }
    char load_string[LOAD_STR_SIZE] = "none";
    string contents;
    if (integral_file == nullptr) {
        cerr << "File with integral list could not be opened, exiting" << endl;
        return -1;
    }

#ifdef PRIME
    std::vector<const char *> vars_vector;
    size_t nvars = Common::variable_replacements.size();
    vars_vector.resize(nvars);
    size_t i = 0;
    for (const auto &par : Common::variable_replacements) {
        vars_vector[i] = par.first.c_str();
        ++i;
    }
    nmod_mpoly_t num, denom;
    nmod_mpoly_ctx_t ctx;
    nmod_mpoly_ctx_init(ctx, nvars, ORD_LEX, Common::prime);
    nmod_mpoly_init(num, ctx);
    nmod_mpoly_init(denom, ctx);
#endif

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
    bool loading_combination = false;
    std::vector<std::pair<Point, COEFF>> combination;
    std::vector<std::pair<Point, string>> combination_unsubstituted;
    while (all[move] != '}' || loading_combination) {
        if (all[move] == '}') {
            // end of combination loading.
            Equation::combinations.push_back(combination);
            Equation::combinations_unsubstituted.push_back(combination_unsubstituted);
            combination.clear();
            combination_unsubstituted.clear();
            loading_combination = false;
            ++move;
            while (all[move] == ' ')
                move++;
            if (all[move] == '}')
                break;
            if (all[move] != ',') {
                cout << "error in integrals after combination: ";
                abort();
            }
            move++;
        }

        while (all[move] == ' ')
            move++;
        if (all[move] != '{') {
            cout << "error in integrals: " << all[move] << endl;
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;

        if (!loading_combination && all[move] == '{') {
            // if there is a bracket inside a bracket and we were not loading
            // before, then this bracket is an integral start (for now)
            // std::cout << "starting combination " << std::endl;
            loading_combination = true;
            ++move;
        }

        std::string current_coeff;
        if (loading_combination) {
            // pair was started, need to read COEFF
            while (all[move] == ' ')
                move++;
            int new_move = move;
            while (all[new_move] != ',')
                new_move++;
            current_coeff = std::string(all + move, new_move - move);
            move = new_move;
            move++;
            while (all[move] == ' ')
                move++;
            if (all[move] != '{') {
                cout << "error in integrals inside combination: " << all[move] << endl;
                abort();
            }
            move++;
        }

        unsigned int i;
        move += s2u(all + move, i);
        if (i != Common::global_pn) {
            cerr << "Unknown problem number " << i << endl;
            fclose(integral_file);
            return -1;
        }

        while (all[move] == ' ')
            move++;
        if (all[move] != ',') {
            cout << "error in integrals: ";
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;
        vector<t_index> v;
        int new_move = s2v(all + move, v);

        Point p;
        if (v.size() > 2) {
            p = point_reference(v);
            move += new_move;
        } else {
            vector<int64_t> res;
            move += parse_vector(all + move, res);
            vector<t_index> empty;
            SECTOR s;
            if (res[0] == 1) {
                s = static_cast<SECTOR>(-2);
                // this is the SECTOR notation for virtual 1 sector
            } else {
                vector<t_index> sector = Common::ssectors[res[0]];
                s = sector_fast(sector);
            }
            p = Point(empty, res[1], s);
        }
        if (!p.IsZero()) {
            if (v.size() > 2) {
                set<FastPoint> sfast;
                sfast.insert(FastPoint(v));
                leave_used_points(sfast);
                if (sfast.size() == 1) {
                    // proper even condition
                    points.insert(p);
                }
            } else {
                points.insert(p);
            }
            int level = positive_index(Common::ssectors[p.SectorNumber()]);
            sector_count_t s_number = p.SectorNumber();
            if (level > Common::abs_max_level) {
                Common::abs_max_level = level;
            }
            if (s_number > Common::abs_max_sector) {
                cout << "Integral in a sector that does not exist!" << endl;
                abort();
            }
        }
        // std::cout << "got " << p  << " (" << p.Number() << ")" << std::endl;
        auto itr = Equation::initial.find(v);
        if (itr == Equation::initial.end()) {
            Equation::initial.emplace(v, std::make_pair(p, !loading_combination));
            // mapping from requested vectors to our points
        } else {
            if (!loading_combination) {
                itr->second.second = true;
            }
        }

        while (all[move] == ' ')
            move++;
        if (all[move] != '}') {
            cout << "error in integrals: ";
            abort();
        }
        move++;

        if (loading_combination) {
            if (!p.IsZero())
                combination_unsubstituted.push_back(std::make_pair(p, current_coeff));
#ifdef PRIME
            COEFF current_COEFF;
            auto current_coeff_copy = replace_all(current_coeff, " ", "");
            auto [num_string, denom_string] = numerator_denominator(current_coeff_copy, true);
            nmod_mpoly_set_str_pretty(num, num_string.c_str(), &vars_vector[0], ctx);
            nmod_mpoly_set_str_pretty(denom, denom_string.c_str(), &vars_vector[0], ctx);

#ifdef MPRIME
            for (size_t i = 0; i != MPRIME; ++i) {
#else
                size_t i = 0;
#endif
                ulong vals[16];
                size_t vari = 0;
                for (const auto &par : Common::variable_replacements) {
                    vals[vari] = stoull(par.second[i]);
                    ++vari;
                }
                mp_limb_t num_number = nmod_mpoly_evaluate_all_ui(num, vals, ctx);
                mp_limb_t denom_number = nmod_mpoly_evaluate_all_ui(denom, vals, ctx);
                denom_number = nmod_inv(denom_number, Common::flint_mod);
                num_number = nmod_mul(num_number, denom_number, Common::flint_mod);

#ifndef MPRIME
                current_COEFF.n = num_number;
#else
                current_COEFF.N[i] = num_number;
            }
#endif
#else
            std::string current_coeff_main = replace_all_variables(current_coeff);
            fuel::simplify(current_coeff_main, 0);
            COEFF current_COEFF;
            current_COEFF.s = current_coeff_main;
#endif
            if (!p.IsZero())
                combination.emplace_back(p, current_COEFF);
            while (all[move] == ' ')
                move++;
            if (all[move] != '}') {
                cout << "error in combination pair end: ";
                abort();
            }
            move++;
        }

        while (all[move] == ' ')
            move++;
        if (all[move] == '}') {
            if (loading_combination)
                continue;
            else
                break;
        }
        if (all[move] != ',') {
            cout << "error in integrals: ";
            abort();
        }
        move++;
        while (all[move] == ' ')
            move++;
        // printf("%s\n", all + move);
    }
    fclose(integral_file);

#ifdef PRIME
    nmod_mpoly_clear(num, ctx);
    nmod_mpoly_clear(denom, ctx);
    nmod_mpoly_ctx_clear(ctx);
#endif
    return 0;
}

int parse_config(const string &filename, set<Point, std::greater<Point>> &points, string &output,
        const int sector, const bool force_no_send_to_parent) {
    if (sector == 0) {
        Common::receive_from_child = true;
        Common::send_to_parent = false;
    } else {
        Common::receive_from_child = false;
        Common::send_to_parent = true;
    }

    if (force_no_send_to_parent)
        Common::send_to_parent = false;

    FILE *config_file = fopen(filename.c_str(), "r");
    if (config_file == nullptr) {
        cerr << "No " << filename << ", exiting!" << endl;
        return 1;
    }

    string pid_folder;

    char hostname[64];
    gethostname(hostname, 64);

    if (sector == 0) {
        pid_folder = "/" + string(hostname) + "-" + to_string(getpid()); // master job in mpi_mode appends
                                                                         // pid to database folder
    } else {
        pid_folder = "/" + string(hostname) + "-" +
            to_string(getppid()); // end the sector job appends parent pid folder
    }
    string cdatabase;
    Common::threads_number = 0;
    Common::f_queues = 1; // always one queue now, either in thread, or general pool
    Common::fthreads_number = 0;
    bool started = false;
    char finput[LOAD_STR_SIZE] = "none";
    int bucket_value = {};
#ifdef PRIME
    bool not_all_replaced = false;
#endif

    bool loaded_rules = false;     // we should not load rules before preferred
    bool loaded_integrals = false; // we should not load integrals before rules

    for (int ind = 0; ind != MAX_IND; ++ind) {
        Common::parity_used[ind] = false;
    }

    unsigned int max_exponent = 0;
    bool fermat_separate = false;
    while (fgets(finput, sizeof(finput), config_file)) {
        string str = finput;
        for (char &c : str) {
            if (c == '\r') {
                c = '\n';
                break;
            }
        }
        if (str.substr(0, 2) == "##") {
            continue; // comment
        } else if (str.substr(0, 5) == "#calc") {
            size_t pos = 5;
            while (str[pos] == ' ')
                pos++;
            string library = str.substr(pos);
            library[library.find('\n')] = '\0';
            library = string(library.c_str());
            fuel::setLibrary(library);
        } else if (str.substr(0, 9) == "#positive") {
            positive_indices.clear();
            size_t pos = 9;
            while (str[pos] == ' ')
                pos++;
            std::string temp = str.substr(pos);
            pos = temp.find('\n');
            if (pos != string::npos)
                temp = temp.substr(0, pos);
            std::istringstream iss(temp);
            string portion;
            while (getline(iss, portion, ',')) {
                int ind = stoi(portion);
                positive_indices.push_back(ind);
            }
        } else if (str.substr(0, 9) == "#printall") {
            size_t pos = 9;
            while (str[pos] == ' ')
                pos++;
            str = str.substr(pos);
            s2i(str.c_str(), Common::print_all_up_to_complexity);
            if (Common::print_all_up_to_complexity < 0) {
                cout << "Error: #print_all must be followed by a non-negative "
                    "integer\n";
                abort();
            }
        } else if (str.substr(0, 11) == "#bottomonly") {
            Common::bottom_sector_only = true;
        } else if (str.substr(0, 9) == "#ordering") {
            size_t pos = 9;
            while (str[pos] == ' ')
                pos++;
            Common::ordering_string = str.substr(pos);
            pos = Common::ordering_string.find('\n');
            if (pos != string::npos)
                Common::ordering_string = Common::ordering_string.substr(0, pos);
            if (!Common::silent && sector == 0)
                cout << "Using ordering specification: " << Common::ordering_string << endl;
        } else if (str.substr(0, 15) == "#index_ordering") {
            size_t pos = 15;
            while (str[pos] == ' ')
                pos++;
            s2v(str.c_str() + pos, Common::index_ordering);
            if (!Common::silent && sector == 0) {
                cout << "Using index ordering ";
                print_vector(Common::index_ordering);
                cout << endl;
            }
        } else if (str.substr(0, 11) == "#compressor") {
            size_t pos = 11;
            while (str[pos] == ' ')
                pos++;
            string compressor = str.substr(pos);
            compressor[compressor.find('\n')] = '\0';

            if (!compressor.compare(0, 5, "lz4hc"))
                Common::compressor = t_compressor::C_LZ4HC;
            else if (!compressor.compare(0, 7, "lz4fast"))
                Common::compressor = t_compressor::C_LZ4FAST;
            else if (!compressor.compare(0, 3, "lz4"))
                Common::compressor = t_compressor::C_LZ4;
#ifdef WITH_ZLIB
            else if (!compressor.compare(0, 4, "zlib"))
                Common::compressor = t_compressor::C_ZLIB;
#endif
            else if (!compressor.compare(0, 4, "none"))
                Common::compressor = t_compressor::C_NONE;
#ifdef WITH_SNAPPY
            else if (!compressor.compare(0, 6, "snappy"))
                Common::compressor = t_compressor::C_SNAPPY;
#endif
#ifdef WITH_ZSTD
            else if (!compressor.compare(0, 4, "zstd")) {
                Common::compressor = t_compressor::C_ZSTD;
                if (compressor[4] == ':') {
                    sscanf(compressor.c_str(), "zstd:%d", &Common::compressor_level);
                } else {
                    Common::compressor_level = 3;
                }
            }
#endif
            else {
                cerr << "Incorrect compressor: " << compressor << "|" << endl
                    << "Options that are are always valid are lz4 (default), "
                    "lz4fast, lz4hc, none."
                    << endl
                    << "Depending on the ./configure options one can also have "
                    "zlib, snappy, zstd."
                    << endl;
                abort();
            }
        } else if (str.substr(0, 8) == "#threads") {
            size_t pos = 8;
            while (str[pos] == ' ')
                pos++;
            if (str[pos] == '{') {
                ++pos;
                str = str.substr(pos);
                pos = s2u(str.c_str(), Common::threads_number);

                Common::threads_default_number = Common::threads_number;
                if (sector == 0 && !Common::silent)
                    cout << "Default threads: " << Common::threads_number << endl;
                while (str[pos] == ' ')
                    pos++;
                while (str[pos] != '}') {
                    if (str[pos] != ',') {
                        cout << "Incorrect threads syntax" << endl;
                        abort();
                    }
                    pos++;
                    while (str[pos] == ' ')
                        pos++;
                    unsigned int n;
                    str = str.substr(pos);
                    pos = s2u(str.c_str(), n);
                    while (str[pos] == ' ')
                        pos++;
                    if (str[pos] != '-') {
                        cout << "Incorrect threads syntax" << endl;
                        abort();
                    }
                    ++pos;
                    if (str[pos] != '>') {
                        cout << "Incorrect threads syntax" << endl;
                        abort();
                    }
                    ++pos;
                    while (str[pos] == ' ')
                        pos++;
                    unsigned int m;
                    str = str.substr(pos);
                    pos = s2u(str.c_str(), m);
                    while (str[pos] == ' ')
                        pos++;
                    if (sector == 0 && !Common::silent)
                        cout << "Will be using " << m << " threads at level " << n << endl;
                    Common::threads_level_number.insert(make_pair(n, m));
                }
            } else {
                str = str.substr(pos);
                s2u(str.c_str(), Common::threads_number);

                Common::threads_default_number = Common::threads_number;
                if (sector == 0 && !Common::silent)
                    cout << "Threads: " << Common::threads_number << endl;
            }
            if (Common::sthreads_number == 0)
                Common::sthreads_number = Common::threads_number;
            if (Common::fthreads_number == 0)
                Common::fthreads_number = Common::threads_number;
        } else if (str.substr(0, 9) == "#sthreads") {
            size_t pos = 9;
            while (str[pos] == ' ')
                pos++;
            str = str.substr(pos);
            s2u(str.c_str(), Common::sthreads_number);
        } else if (str.substr(0, 9) == "#lthreads") {
            size_t pos = 9;
            while (str[pos] == ' ')
                pos++;
            str = str.substr(pos);
            s2u(str.c_str(), Common::lthreads_number);
            if (sector == 0 && !Common::silent)
                cout << "Level threads: " << Common::lthreads_number << endl;
        } else if (str.substr(0, 8) == "#forward") {
            Common::stages = t_stages::forward;
        } else if (str.substr(0, 9) == "#backward") {
            Common::stages = t_stages::backward;
        } else if (str.substr(0, 21) == "#no_positive_increase") {
            Common::no_positive_increase = true;
        } else if (str.substr(0, 9) == "#pos_pref") {
            size_t pos = 10;
            while (str[pos] == ' ')
                pos++;
            str = str.substr(pos);
            int pos_pref;
            s2i(str.c_str(), pos_pref);
            Common::pos_pref = pos_pref;
        } else if (str.substr(0, 9) == "#fthreads") {
            size_t pos = 9;
            while (str[pos] == ' ')
                pos++;
            if (str[pos] == 's') {
                fermat_separate = true;
                pos++;
            }
            str = str.substr(pos);
            s2u(str.c_str(), Common::fthreads_number);

            if ((sector == 0) && (!Common::silent)) {
                cout << "Library threads: " << Common::fthreads_number;
            }

            if (fermat_separate) {
                Common::receive_from_child = false;
                Common::send_to_parent = false;
                if ((sector == 0) && (!Common::silent)) {
                    cout << " separate";
                }
            }
            if ((sector == 0) && (!Common::silent)) {
                cout << endl;
            }
        } else if (str.substr(0, 10) == "#variables") {
            size_t pos = 10;
            while (str[pos] == ' ')
                pos++;
            char variables_temp[COEFF_BUF_SIZE];
            strcpy(variables_temp, (str.substr(pos)).c_str());
            char *begin = variables_temp;
            char *now = variables_temp;
            bool mode_right = false;
            string left;
            unsigned short count_replaced_vars = 0;
            while (*now != '\0') {
                if (*now == '\n') {
                    *now = ',';
                }
                if (*now == ',') {
                    *now = '\0';
                    if (mode_right) { // now making a variable replacement rule
                        string right = begin;
                        mode_right = false;
                        if (count_replaced_vars >= var_values_from_arv.size()) {
                            // untouched replacement
                            if (sector == 0 && !Common::very_silent)
                                cout << "Using config replacement " << right << " for " << left << endl;
                            Common::variable_replacements.emplace(left, std::vector{right});
                        } else if (*begin == '/') {
                            // a special case when #variables contains something like
                            // var->/?? and a number is passed from command line then
                            // these parts get concatenated
                            auto joined_value = var_values_from_arv[count_replaced_vars] + begin;
                            Common::variable_replacements.emplace(left, std::vector{joined_value});
                            if (sector == 0 && !Common::very_silent)
                                cout << "Using joined value " << joined_value << " for " << left << endl;
                            ++count_replaced_vars;
                        } else {
                            if (sector == 0 && !Common::very_silent)
                                cout << "Using config replacement " << right << " for " << left << endl;
                            Common::variable_replacements.emplace(left, std::vector{right});
                        }
                        left = "";
                    } else { // just adding a variable
                        if (count_replaced_vars < var_values_from_arv.size()) {
                            Common::variable_replacements.emplace(
                                    begin, std::vector{var_values_from_arv[count_replaced_vars]});
                            if (sector == 0 && !Common::very_silent)
                                cout << "Using arg value " << var_values_from_arv[count_replaced_vars]
                                    << " for " << begin << endl;
                            ++count_replaced_vars;
                        } else {
                            Common::active_variables += begin;
                            Common::active_variables += '|';
                            Common::variables.push_back(begin);
#ifdef PRIME
                            not_all_replaced = true;
#endif
                        }
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
                    if (std::tolower(*now) != *now) {
                        cout << "Variables contain a capital letter: " << variables_temp << endl;
                        abort();
                    }
                    now++;
                }
            }
            if (count_replaced_vars < var_values_from_arv.size()) {
                cout << "Too many variables in command line" << endl;
                abort();
            }
        } else if (str.substr(0, 9) == "#database") {
            if (Common::path == "") {
                size_t pos = 9;
                while (str[pos] == ' ')
                    pos++;
                Common::path = str.substr(pos);
                Common::path.erase(Common::path.find('\n'));
            } else {
                if (!sector)
                    cout << "#database setting ignored" << endl;
            }
        } else if (str.substr(0, 8) == "#storage") {
            size_t pos = 8;
            while (str[pos] == ' ')
                pos++;
            if (str[pos] == '!') {
                Common::cpath_on_substitutions = true;
                ++pos;
            }
            cdatabase = str.substr(pos);
            cdatabase.erase(cdatabase.find('\n'));
        } else if (str.substr(0, 7) == "#bucket") {
            if (Common::bucket_override) {
                // if (!Common::silent) cout << "Bucket option in file ignored,
                // using " << Common::bucket_override << endl;
            } else {
                size_t pos = 7;
                while (str[pos] == ' ')
                    pos++;
                str = str.substr(pos);
                s2i(str.c_str(), bucket_value);
                if ((sector == 0) && (!Common::silent)) {
                    cout << "Bucket: " << bucket_value << " for sector databases" << endl;
                }
            }
        } else if (str.substr(0, 6) == "#print") {
            size_t pos = 7;
            while (str[pos] == ' ')
                pos++;
            str = str.substr(pos);
            s2i(str.c_str(), Common::print_step);
        } else if (str.substr(0, 5) == "#wrap") {
            Common::wrap_databases = true;
        } else if (str.substr(0, 6) == "#prime") {
#ifdef PRIME
            if (Common::prime) {
                cout << "Option #prime ignored: either duplicate line or "
                    "provided as an option"
                    << endl
                    << "Current prime number: " << Common::prime << ", by index " << Common::prime_number
                    << endl;
            } else {
                int pos = 7;
                while (str[pos] == ' ')
                    pos++;
                str = str.substr(pos);
                sscanf(str.c_str(), "%hu", &Common::prime_number);
                if (Common::prime_number > 255) {
                    cout << "Option #prime ignored: index for a prime should be in "
                        "range from 0 to 255, refer to primes.cpp"
                        << endl;
                } else {
                    Common::prime = primes[Common::prime_number];
                    mp_limb_t flint_prime = Common::prime;
                    nmod_init(&Common::flint_mod, flint_prime);
                    if (sector == 0 && !Common::very_silent)
                        cout << "Prime index is: " << Common::prime_number << endl
                            << "Prime number is: " << Common::prime << endl;
                }
            }
#else
            cerr << "FIRE7 is not running prime mode, ignoring #prime parameter." << endl;
            continue;
#endif
        } else if (str.substr(0, 7) == "#memory") {
            if ((sector == 0) && (!Common::silent)) {
                cout << "OPTION MEMORY HAS NO LONGER ANY MEANING" << endl;
            }
        } else if (str.substr(0, 9) == "#external") {
            if ((sector == 0) && (!Common::silent)) {
                cout << "Saving external relations (Deprecated, has no effect)" << endl;
            }
        } else if (str.substr(0, 8) == "#keepall") {
            if ((sector == 0) && (!Common::silent)) {
                cout << "Keeping all entries (Deprecated, has no effect)" << endl;
            }
        } else if (str.substr(0, 6) == "#small") {
            if ((sector == 0) && (!Common::silent)) {
                cout << "#small OPTION REMOVED AS UNSAFE FOR REAL CALCULATIONS!!!!" << endl;
            }
        } else if (str.substr(0, 5) == "#port") {
            if ((sector == 0) && (!Common::silent)) {
                cout << "#port OPTION REMOVED AS UNSAFE FOR REAL CALCULATIONS!!!!" << endl;
            }
        } else if (str.substr(0, 16) == "#clean_databases") {
            if ((sector == 0) && (!Common::silent)) {
                cout << "Temporary databases will be cleaned after work" << endl;
            }
            Common::clean_databases = true;
        } else if (str.substr(0, 5) == "#ksub") {
            // Common::ksub = true; // we ignore this option for this release
            // if ((sector == 0) && (!Common::silent)) { cout << "Using
            // KIRA-inspired backward substitution technique" << endl; }
        } else if (str.substr(0, 7) == "#allIBP") {
            Common::all_ibps = true;
            if ((sector == 0) && (!Common::silent)) {
                cout << "Using all IBPs" << endl;
            }
        } else if (str.substr(0, 7) == "#nolock") {
            if ((sector == 0) && (!Common::silent)) {
                cout << "#nolock OPTION REMOVED without disk database" << endl;
            }
        } else if (str.substr(0, 12) == "#no_presolve") {
            Common::disable_presolve = true;
            if ((sector == 0) && (!Common::silent)) {
                cout << "IBP presolving will be switched off" << endl;
            }
        } else if (str.substr(0, 13) == "#old_presolve") {
            Common::old_presolve = true;
            if ((sector == 0) && (!Common::silent)) {
                cout << "IBP presolving will be partial" << endl;
            }
            size_t pos = 13;
            while (str[pos] == ' ')
                pos++;
            str = str.substr(pos);
            s2u(str.c_str(), Common::presolve_ibps);
            if ((sector == 0) && (!Common::silent) && Common::presolve_ibps) {
                cout << "Actively presolving first " << Common::presolve_ibps << " IBPs" << endl;
            }
        } else if ((str.substr(0, 5) == "#even") || (str.substr(0, 4) == "#odd")) {
            size_t pos;
            if (str.substr(0, 5) == "#even") {
                Common::points_used = t_points::even;
                pos = 6;
            } else {
                Common::points_used = t_points::odd;
                pos = 5;
            }
            while (str[pos] == ' ')
                pos++;
            str = str.substr(pos);
            for (auto &c : str) {
                if (c == '-') {
                    c = '_';
                }
            }
            int count;
            while (true) {
                int move = s2i(str.c_str(), count);
                int begin, end;
                if (str[move] == '_') {
                    begin = count;
                    str = str.substr(move + 1);
                    move = s2i(str.c_str(), end);
                } else {
                    begin = 1;
                    end = count;
                }
                for (int ind = begin - 1; ind != end; ++ind) {
                    Common::parity_used[ind] = true;
                }
                if (str[move] == ',') {
                    str = str.substr(move + 1);
                } else {
                    break;
                }
            }
        } else if (str.substr(0, 14) == "#full_presolve") {
            if ((sector == 0) && (!Common::silent)) {
                cout << "Default IBP presolving" << endl;
            }
            size_t pos = 14;
            while (str[pos] == ' ')
                pos++;
            str = str.substr(pos);
            s2u(str.c_str(), Common::presolve_ibps);
            if ((sector == 0) && (!Common::silent) && Common::presolve_ibps) {
                cout << "Actively presolving first " << Common::presolve_ibps << " IBPs" << endl;
            }

        } else if (str.substr(0, 6) == "#start") {
            if (started) {
                cerr << "extra #start directive, exiting" << endl;
                fclose(config_file);
                return 1;
            }
#ifdef PRIME
            if (!Common::prime) {
                cerr << "no proper #prime setting, exiting" << endl;
                fclose(config_file);
                return 1;
            }
            if (not_all_replaced) {
                cerr << "not all variables have values, exiting" << endl;
                for (const auto &var : Common::variables)
                    cout << var << endl;
                fclose(config_file);
                return 1;
            }
            for (auto &[key, values] : Common::variable_replacements) {
                std::string value = values[0];
                bool big_prime = false;
                if (value[0] == 'p') {
                    big_prime = true;
                    value = value.substr(1);
                }
#ifdef MPRIME
                auto pos = value.find("^");
                if (pos != std::string::npos) {
                    unsigned long long v;
                    unsigned int exp;
                    sscanf(value.c_str(), "%llu^%u", &v, &exp);
                    if (exp > max_exponent) {
                        max_exponent = exp;
                    }
                    if (big_prime) {
                        v = primes[v + values_primes_start];
                    }
                    bool has_different_values = false;
                    if (value.find("+") != std::string::npos) {
                        has_different_values = true;
                    }
                    values.clear();
                    for (size_t i = 0; i != MPRIME; ++i) {
                        unsigned long long final_v = nmod_pow_ui(v, exp, Common::flint_mod);
                        values.push_back(std::to_string(final_v));
                        if (has_different_values) {
                            ++exp;
                        }
                    }
                    if (sector == 0 && !Common::very_silent) {
                        if (has_different_values) {
                            cout << "Using " << (big_prime ? "p" : "") << value << " = " << values[0]
                                << ", ... , " << values[values.size() - 1] << " for " << key << endl;
                        } else {
                            cout << "Using " << (big_prime ? "p" : "") << value << " = " << values[0]
                                << " for " << key << endl;
                        }
                    }
                } else {
                    if (value[value.size() - 1] == '+') {
                        values.clear();
                        int int_value = stoi(value);
                        for (size_t i = 0; i != MPRIME; ++i) {
                            values.push_back(std::to_string(int_value));
                            ++int_value;
                        }
                        if (sector == 0 && !Common::very_silent) {
                            cout << "Using " << values[0] << ", ... , " << values[values.size() - 1]
                                << " for " << key << endl;
                        }
                    } else {
                        // just making copies
                        for (size_t i = 1; i != MPRIME; ++i) {
                            values.push_back(value);
                        }
                        if (sector == 0 && !Common::very_silent) {
                            cout << "Using " << value << " for " << key << endl;
                        }
                    }
                }
#else
                auto pos = value.find("^");
                if (pos != std::string::npos) {
                    unsigned long long v;
                    unsigned int exp;
                    sscanf(value.c_str(), "%llu^%u", &v, &exp);
                    if (exp > max_exponent) {
                        max_exponent = exp;
                    }
                    if (big_prime) {
                        v = primes[v + values_primes_start];
                    }
                    v = nmod_pow_ui(v, exp, Common::flint_mod);
                    if (sector == 0 && !Common::silent) {
                        cout << "Using " << (big_prime ? "p" : "") << value << " = " << v << " for " << key << endl;
                    }
                    values[0] = std::to_string(v);
                }
#endif
            }
#endif
            if (Common::stages != t_stages::all && cdatabase == "") {
                cerr << "Running only one of the stages is possible only with "
                    "the storage option"
                    << endl;
                fclose(config_file);
                return 1;
            }
            if (Common::stages == t_stages::forward) {
                if (sector == 0 && !Common::silent)
                    cout << "Running only forward stage " << endl;
            }
            if (Common::stages == t_stages::backward) {
                if (sector == 0 && !Common::silent)
                    cout << "Running only backward stage " << endl;
            }
            if (Common::path == "") {
                Common::path = "temp/db";
            }
            if (bucket_value <= 0) {
                if (Common::bucket_override) {
                    bucket_value = Common::bucket_override;
                    if (!Common::silent)
                        cout << "Sector " << sector
                            << ": using command line bucket value = " << bucket_value << endl;
                } else {
                    bucket_value = 16;
                    if (!Common::silent)
                        cout << "Using default #bucket value = 16" << endl;
                }
            }
            if (Common::threads_number <= 0) {
                cerr << "No proper #threads setting, exiting" << endl;
                fclose(config_file);
                return 1;
            }
#ifndef PRIME
            if (Common::send_to_parent && Common::lthreads_number > 1) {
                cerr << "Level threads in poly version require separate fermat "
                    "workers";
                fclose(config_file);
                return 1;
            }
#endif

#ifdef PRIME
            if (Common::stages == t_stages::backward) {
                // variables should be passed to calc for resubstitution
                for (const auto &par : Common::variable_replacements) {
                    Common::variables.push_back(par.first);
                }
            }
#endif

            if (sector != 0) {
                // Common::fthreads_number /= Common::threads_number; // child has
                // less workers
                Common::threads_number = 1; // only one thread inside
                                            // however if sending parent, we are not even launching those
                                            // workers
            }

            if (fuel::getLibrary() == "ginac" || fuel::getLibrary() == "cocoa") {
                Common::fthreads_number = 1;
                if (!fermat_separate) {
                    if (sector == 0) {
                        Common::receive_from_child = false;
                        if (!Common::silent) {
                            cout << "Switching to library separate mode since "
                                "ginac/cocoa do not work multithreaded"
                                << endl;
                        }
                    } else {
                        Common::send_to_parent = false;
                    }
                }
            }
            fuel::readLibraryPathsFromFile(Common::FIRE_folder + "../extra/fuel/libraryBinarySettings");
            if (((sector != 0) && (!Common::send_to_parent)) ||
                    ((sector == 0) && (Common::receive_from_child))) {
                if (!fuel::initialize(Common::variables, Common::fthreads_number, Common::silent,
                            Common::prime)) {
                    fclose(config_file);
                    return 1;
                }
                for (const auto &option : Common::fuelOptions) {
                    fuel::setOption(option);
                }
#ifdef PRIME
                fuel::switchToConventional();
#endif
                for (unsigned int i = 0; i != Common::fthreads_number; ++i) {
                    Equation::f_threads[i] = thread(f_worker, i, i % Common::f_queues);
                }
            } else if ((sector == 0) && (!Common::receive_from_child)) {
                // only if the fermat is distributed among children but parent has
                // to use it for parsing
                if (!fuel::initialize(Common::variables, 1, Common::silent, Common::prime)) {
                    fclose(config_file);
                    return 1;
                }
                for (const auto &option : Common::fuelOptions) {
                    fuel::setOption(option);
                }
#ifdef PRIME
                fuel::switchToConventional();
#endif
#ifdef PRIME
            } else if (Common::stages == t_stages::backward || Common::large_variables ||
                    Common::plan_file != "") {
                // we are initializing at least 1 fuel thread in case of prime if
                // it is not here
                if (!fuel::initialize(Common::variables, 1, Common::silent, Common::prime)) {
                    fclose(config_file);
                    return 1;
                }
                for (const auto &option : Common::fuelOptions) {
                    fuel::setOption(option);
                }
                fuel::switchToConventional();
#endif
            }

            switch (Common::compressor) {
#ifdef WITH_SNAPPY
                case t_compressor::C_SNAPPY:
                    if (sector == 0 && !Common::silent)
                        cout << "Compressor: snappy" << endl;
                    Common::compressor_class = unique_ptr<kyotocabinet::Compressor>(new SnappyCompressor());
                    break;
#endif
#ifdef WITH_ZLIB
                case t_compressor::C_ZLIB:
                    if (sector == 0 && !Common::silent)
                        cout << "Compressor: zlib" << endl;
                    Common::compressor_class = unique_ptr<kyotocabinet::Compressor>(
                            new kyotocabinet::ZLIBCompressor<kyotocabinet::ZLIB::RAW>);
                    break;
#endif
                case t_compressor::C_NONE:
                    if (sector == 0 && !Common::silent)
                        cout << "Compressor: none" << endl;
                    break;
                case t_compressor::C_LZ4:
                    if (sector == 0 && !Common::silent)
                        cout << "Compressor: lz4" << endl;
                    Common::compressor_class = unique_ptr<kyotocabinet::Compressor>(new LZ4Compressor);
                    break;
                case t_compressor::C_LZ4FAST:
                    if (sector == 0 && !Common::silent)
                        cout << "Compressor: lz4fast" << endl;
                    Common::compressor_class = unique_ptr<kyotocabinet::Compressor>(new LZ4FastCompressor);
                    break;
                case t_compressor::C_LZ4HC:
                    if (sector == 0 && !Common::silent)
                        cout << "Compressor: lz4hc" << endl;
                    Common::compressor_class = unique_ptr<kyotocabinet::Compressor>(new LZ4HCCompressor);
                    break;
#ifdef WITH_ZSTD
                case t_compressor::C_ZSTD:
                    if (sector == 0 && !Common::silent)
                        cout << "Compressor: zstd, level " << Common::compressor_level << endl;
                    Common::compressor_class = unique_ptr<kyotocabinet::Compressor>(new ZstdCompressor);
                    break;
#endif
                default:
                    cerr << "Incorrect compressor" << endl;
                    abort();
            }

            if (Common::path[Common::path.size() - 1] == '/') {
                Common::path = Common::path.substr(0, Common::path.size() - 1);
            }
            if (cdatabase[cdatabase.size() - 1] == '/') {
                cdatabase = cdatabase.substr(0, cdatabase.size() - 1);
            }

            // pid folder is this process pid in case of FIRE and parent pid in
            // case of FLAME
            if (Common::parallel_mode) {
                if (!sector)
                    Common::path += pid_folder;
                cdatabase += pid_folder;
            }
            Common::cpath = cdatabase + "/";
            if (cdatabase == "" || cdatabase == pid_folder) {
                Common::cpath = "";
            }

            if (sector == 0) {
                umask(0);
                if (!Common::silent)
                    cout << "Database path: " << Common::path << endl;
                if (access(Common::path.c_str(), 0) == 0) {
                    struct stat status{};
                    stat(Common::path.c_str(), &status);
                    if (status.st_mode & S_IFDIR) {
                        if (!Common::silent) {
                            cout << "Temporary directory exists" << endl;
                        }
                    } else {
                        if (!Common::silent) {
                            cout << "The specified path is a file, trying to remove." << endl;
                        }
                        if (remove(Common::path.c_str()) != 0) {
                            cerr << "Error removing" << endl;
                            abort();
                        }
                        if (!Common::silent) {
                            cout << "Removed, creating a directory" << endl;
                        }
                        if (mkpath(Common::path, 0777) != 0) {
                            cerr << "Error creating directory" << endl;
                            abort();
                        }
                        if (!Common::silent) {
                            cout << "Created" << endl;
                        }
                    }
                } else {
                    if (!Common::silent) {
                        cout << "Creating temporary directory" << endl;
                    }
                    int res = mkpath(Common::path, 0777);
                    if (res != 0) {
                        cerr << "Error creating directory " << Common::path << " with code " << res << endl;
                        abort();
                    }
                    if (!Common::silent) {
                        cout << "Created" << endl;
                    }
                }
                FILE *f = fopen((Common::path + "/test").c_str(), "w");
                if (f == nullptr) {
                    cerr << "Error creating temporary file" << endl;
                    abort();
                }
                fclose(f);
                if (remove((Common::path + "/test").c_str()) != 0) {
                    cerr << "Error removing temporary file" << endl;
                    abort();
                }

                DIR *dp;
                struct dirent *ep;
                struct stat st{};

                dp = opendir((Common::path + "/").c_str());
                if (dp != nullptr) {
                    while ((ep = readdir(dp)) != nullptr) {
                        stat((Common::path + "/" + ep->d_name).c_str(), &st);
                        if (S_ISDIR(st.st_mode) == 0) {
                            if (!Common::silent) {
                                cout << "Deleting file \"" << ep->d_name << "\"" << endl;
                            }
                            remove((Common::path + "/" + ep->d_name).c_str());
                        }
                    }
                    closedir(dp);
                } else {
                    cerr << "Couldn't open the directory." << endl;
                    abort();
                }

                if (cdatabase != "" && cdatabase != pid_folder) {
                    if (!Common::silent) {
                        cout << "Storage path: " << cdatabase << endl;
                    }
                    if (access(cdatabase.c_str(), 0) == 0) {
                        struct stat status{};
                        stat(cdatabase.c_str(), &status);
                        if (status.st_mode & S_IFDIR) {
                            if (!Common::silent) {
                                cout << "Storage directory located" << endl;
                            }
                        } else {
                            if (!Common::silent) {
                                cout << "The specified storage path is a file, exiting." << endl;
                            }
                            abort();
                        }
                    } else {
                        if (!Common::silent) {
                            cout << "Creating storage directory" << endl;
                        }
                        if (mkpath(cdatabase, 0777) != 0) {
                            cerr << "Error creating directory" << endl;
                            abort();
                        }
                        if (!Common::silent) {
                            cout << "Created" << endl;
                        }
                    }

                    dp = opendir(Common::cpath.c_str());
                    if (dp != nullptr) {
                        while ((ep = readdir(dp)) != nullptr) {
                            stat((Common::cpath + ep->d_name).c_str(), &st);
                            if (S_ISDIR(st.st_mode) == 0 && strcmp(ep->d_name, Common::completed_in_storage_fname.c_str()) != 0) {
                                if (!Common::silent) {
                                    cout << "Copying file \"" << ep->d_name << "\"" << endl;
                                }
                                ifstream src(Common::cpath + ep->d_name, ios::binary);
                                ofstream dst(Common::path + "/" + ep->d_name, ios::binary);
                                dst << src.rdbuf();
                            }
                        }
                        closedir(dp);
                    } else {
                        cerr << "Couldn't open storage folder." << endl;
                        abort();
                    }
                }
            }
            Common::path = Common::path + "/";

            if ((sector == 0) && Common::wrap_databases) {
                if (Common::cpath != "") {
                    cout << "Storage and wrap options are incompatible" << endl;
                    abort();
                }
                if (!Common::silent) {
                    cout << "Using database wrapping to a single file" << endl;
                }
                database_to_file_or_back(0, false); // start the database wrapper thread, only by FIRE,
                                                    // not FLAME
            }
            started = true;
        } else {
            if (!started) {
                cerr << "#start directive missing, exiting" << endl;
                fclose(config_file);
                return 1;
            }

            if (str.substr(0, 7) == "#folder") {
                size_t pos = 7;
                while (str[pos] == ' ')
                    pos++;
                str = str.substr(pos);
                str.erase(str.find('\n'));
                Common::folder = str;
                if (Common::plan_file != "" && (sector == 0 || sector == 1)) {
                    if (Common::plan_file[0] != '/') {
                        Common::plan_file = Common::folder + Common::plan_file;
                    }
                    if (sector == 0 && !Common::silent) {
                        cout << "Plan file will be saved to or loaded from " << Common::plan_file << endl;
                    }
                }
            } else if (str.substr(0, 8) == "#problem") {
                // problem should be parsed even for substitutions, however
                // coefficients should not be loaded
                size_t pos = 8;
                unsigned int pn;
                while (str[pos] == ' ')
                    pos++;
                str = str.substr(pos);

                str.erase(str.find('\n'));
                const char *r = str.c_str();

                int move = s2u(r, pn);
                while (*(r + move) == ' ')
                    move++;

                if (!add_problem(pn, (string(r + move)).c_str(), positive_indices, sector)) {
                    fclose(config_file);
                    return 1;
                }

                Common::buckets[1] = 12;
                for (sector_count_t i = 2; i != Common::abs_max_sector + 1; i++) {
                    Common::buckets[i] = bucket_value;
                }
                Common::has_lbases.resize(Common::abs_max_sector + 1, false);
            } else if (str.substr(0, 5) == "#hint") {
                size_t pos = 6;
                while (str[pos] == ' ')
                    pos++;
                Common::hint = true;
                Common::hint_path = str.substr(pos);
                Common::hint_path.erase(Common::hint_path.find('\n'));
                if (Common::hint_path[0] != '/') {
                    Common::hint_path = Common::folder + Common::hint_path;
                }
                if ((sector == 0) && (!Common::silent)) {
                    cout << "Using hint files " << Common::hint_path << endl;
                }
            } else if (str.substr(0, 6) == "#rules") {
                if (loaded_integrals) {
                    cout << "List of rules should be loaded before requested "
                        "integrals!"
                        << endl;
                    return 1;
                }
                // we need to load preferred from rules anyway
                size_t pos = 6;
                while (str[pos] == ' ')
                    pos++;
                str = str.substr(pos);
                str.erase(str.find('\n'));
                const char *r;
                string tmp;
                if (str[0] == '/') {
                    r = str.c_str();
                } else {
                    tmp = Common::folder + str;
                    r = tmp.c_str();
                }
                if (!add_rules(r, sector)) {
                    fclose(config_file);
                    return 1;
                }
                loaded_rules = true;
            } else if (str.substr(0, 7) == "#lbases") {
                if (sector >= 0) { // only for particular sector work, but still
                                   // for the main thread to produce warnings
                    size_t pos = 7;
                    while (str[pos] == ' ')
                        pos++;
                    str = str.substr(pos);
                    str.erase(str.find('\n'));
                    const char *r;
                    string tmp;
                    if (str[0] == '/') {
                        r = str.c_str();
                    } else {
                        tmp = Common::folder + str;
                        r = tmp.c_str();
                    }
                    if (!add_lbases(r, sector)) {
                        return 1;
                    }
                }
            } else if (str.substr(0, 7) == "#output") {
                if (sector == 0 || sector == 1) {
                    size_t pos = 7;
                    while (str[pos] == ' ')
                        pos++;
                    bool norepeat = false;
                    if (str[pos] == '!') {
                        ++pos;
                        norepeat = true;
                    }
                    str = Common::output_override.empty() ? str.substr(pos) : Common::output_override;
                    if (str.find('\n') != string::npos) {
                        str.erase(str.find('\n'));
                    }
                    if (str[0] == '/') {
                        output = str;
                    } else {
                        output = Common::folder + str;
                    }
                    Common::only_masters = false;
                    if (Common::tables_prefix != "") {
                        output = replace_all(output, ".tables", "_" + Common::tables_prefix + ".tables");
                    }
                    if (Common::split_masters) {
                        char mnb[32];
                        snprintf(mnb, sizeof(mnb), "%u-%u", Common::master_number_min,
                                Common::master_number_max);
                        output = replace_all(output, ".tables", "." + string(mnb) + ".tables");
                    }
                    std::filesystem::path output_path = output;
                    std::filesystem::create_directories(output_path.parent_path());
                    if (norepeat) {
#ifdef PRIME
                        if (Common::tables_prefix != "") {
                            auto sep_position = Common::tables_prefix.find_last_of('_');
                            if (sep_position != string::npos) {
                                string tables_prefix_without_prime =
                                    Common::tables_prefix.substr(0, sep_position);
                                string checked_reconstructed_file = "";
                                if (str[0] == '/') {
                                    checked_reconstructed_file = str;
                                } else {
                                    checked_reconstructed_file = Common::folder + str;
                                }
                                checked_reconstructed_file =
                                    replace_all(checked_reconstructed_file, ".tables",
                                            "_" + tables_prefix_without_prime + ".tables");
                                if (Common::split_masters) {
                                    char mnb[32];
                                    snprintf(mnb, sizeof(mnb), "%u-%u", Common::master_number_min,
                                            Common::master_number_max);
                                    checked_reconstructed_file =
                                        replace_all(checked_reconstructed_file, ".tables",
                                                "." + string(mnb) + ".tables");
                                }
                                FILE *file = fopen(checked_reconstructed_file.c_str(), "r");
                                if (file != nullptr) {
                                    printf("Reconstructed Tables are already created! %s\n",
                                            checked_reconstructed_file.c_str());
                                    fclose(file);
                                    return -1;
                                }
                            }
                        }
#endif
                        FILE *file = fopen(output.c_str(), "r");
                        if (file != nullptr) {
                            fgetc(file);
                            if (feof(file)) {
                                printf("Tables are reserved! %s\n", output.c_str());
                            } else {
                                printf("Tables are already created! %s\n", output.c_str());
                            }
                            fclose(file);
                            return -1;
                        }
                    }
                    auto path = std::filesystem::path(output);
                    auto folder_path = path.parent_path();
                    std::filesystem::create_directory(folder_path);
                    if (Common::folders_limit != 0) {
                        folder_path /= std::to_string(max_exponent / Common::folders_limit);
                        std::filesystem::create_directory(folder_path);
                        folder_path /= path.filename();
                        output = folder_path.string();
                    }
                    if (!Common::very_silent)
                        cout << "Tables will be saved to " << output << endl;
                }
            } else if (str.substr(0, 9) == "#dep_file") {
                if (sector == 0) {
                    size_t pos = 9;
                    while (str[pos] == ' ')
                        pos++;
                    Common::dep_file = str.substr(pos);
                    Common::dep_file.erase(Common::dep_file.find('\n'));
                    if (Common::dep_file[0] != '/') {
                        Common::dep_file = Common::folder + Common::dep_file;
                    }
                    if (!Common::silent) {
                        cout << "Dependency file will be saved to " << Common::dep_file << endl;
                    }
                }
            } else if (str.substr(0, 5) == "#plan") {
                if (sector == 0 || sector == 1) {
                    size_t pos = 5;
                    while (str[pos] == ' ')
                        pos++;
                    Common::plan_file = str.substr(pos);
                    Common::plan_file.erase(Common::plan_file.find('\n'));
                    if (Common::plan_file[0] != '/') {
                        Common::plan_file = Common::folder + Common::plan_file;
                    }
                    if (sector == 0 && !Common::silent) {
                        cout << "Plan file will be saved to " << Common::plan_file << endl;
                    }
                }
            } else if (str.substr(0, 7) == "#warmup") {
                if (sector == 0 || sector == 1) {
                    size_t pos = 7;
                    while (str[pos] == ' ')
                        pos++;
                    Common::warmup_file = str.substr(pos);
                    Common::warmup_file.erase(Common::warmup_file.find('\n'));
                    if (sector == 0 && !Common::silent) {
                        cout << "Warmup file will be saved to " << Common::warmup_file << endl;
                    }
                }
            } else if (str.substr(0, 8) == "#masters") {
                size_t pos{};
                if (str.substr(0, 15) == "#masters_no_dep") {
                    Common::split_masters_no_dep = true;
                    pos = 15;
                } else
                    pos = 8;
                while (str[pos] == ' ')
                    pos++;
                str = str.substr(pos);
                if (str.find('\n') != string::npos) {
                    str.erase(str.find('\n'));
                }
                if ((str[0] == '|') || (Common::master_number_min)) {
                    // that's the split masters mode
                    if (lbases_loaded) {
                        cout << "Lbases should be loaded after masters in split "
                            "master mode"
                            << endl;
                        abort();
                    }

                    Common::split_masters = true;
                    if (loaded_rules) {
                        cout << "Masters file for split master mode should be "
                            "specified before rules!"
                            << endl;
                        abort();
                    }
                    char buf[256];
                    if (Common::master_number_min) {
                        const char *poss = str.c_str();
                        if (*poss != '|') {
                            // no vertical line in config, just taking the path
                        } else {
                            ++poss;
                            while ((*poss) && (*poss != '|'))
                                ++poss;
                            if (!(*poss)) {
                                cout << "Incorrect syntax for master file with master "
                                    "numbers passed (no second |)"
                                    << endl;
                                abort();
                            }
                            str = str.substr(poss + 1 - str.c_str());
                        }
                        sscanf(str.c_str(), "%255s", buf);
                    } else {
                        const char *poss = str.c_str();
                        ++poss;
                        while ((*poss) && (*poss != '|') && (*poss != '-'))
                            ++poss;
                        if (!(*poss)) {
                            cout << "Incorrect syntax for master file (no second |)" << endl;
                            abort();
                        }
                        if (*poss == '-') {
                            sscanf(str.c_str(), "|%u-%u|%255s", &Common::master_number_min,
                                    &Common::master_number_max, buf);
                        } else {
                            sscanf(str.c_str(), "|%u|%255s", &Common::master_number_min, buf);
                            Common::master_number_max = Common::master_number_min;
                        }
                        if (!Common::master_number_min) {
                            cout << "Incorrect syntax for master file" << endl;
                            abort();
                        }
                        if (Common::master_number_max < Common::master_number_min) {
                            cout << "Incorrect range of master integrals" << endl;
                            abort();
                        }
                    }
                    string masters_list_file(buf);
                    if (masters_list_file[0] != '/') {
                        masters_list_file = Common::folder + masters_list_file;
                    }
                    const char *r = masters_list_file.c_str();

                    initialize_dependencies();

                    set_masters_to_zero(r, sector);

                } else {
                    if (!sector) {
                        if (str[0] == '/') {
                            output = str;
                        } else {
                            output = Common::folder + str;
                        }
                    }
                    Common::only_masters = true;
                }
            } else if ((str.substr(0, 9) == "#prefered") ||
                    (str.substr(0, 10) == "#preferred")) { // parse preferred right here
                if (sector >= 0) {                            // on main for rules and in Laporta. it is
                                                              // needed for points creation
                    if (str.substr(0, 9) == "#prefered") {
                        cout << "WARNING: Please fix config file, this option should "
                            "be named '#preferred'"
                            << endl
                            << "For now '#prefered' is supported, but will be "
                            "removed later"
                            << endl;
                    }
                    if (loaded_rules) {
                        cout << "List of preferred master-integrals should be loaded "
                            "before rules!"
                            << endl;
                        return 1;
                    }
                    size_t pos = 10;
                    while (str[pos] == ' ')
                        pos++;
                    if (str[pos] == '!') {
                        Common::preferred_produce_seeds = true;
                        ++pos;
                    }
                    str = str.substr(pos);
                    if (str.find('\n') != string::npos)
                        str.erase(str.find('\n'));
                    if (str[0] != '/')
                        str = Common::folder + str;
                    const char *r = str.c_str();
                    int pref_count = load_preferred(r);
                    if (pref_count == -1) {
                        abort();
                    }
                    if (!sector && !Common::silent)
                        cout << "Loaded " << pref_count << " preferred points" << endl;
                }
            } else if (str.substr(0, 9) == "#one_pass") {
                size_t pos = 9;
                while (str[pos] == ' ')
                    pos++;
                str = str.substr(pos);
                if (str.find('\n') != string::npos) {
                    str.erase(str.find('\n'));
                }
                if (str[0] == '/') {
                    Common::one_pass_database = str;
                } else {
                    Common::one_pass_database = Common::folder + str;
                }
                FILE *one_pass_file = fopen(Common::one_pass_database.c_str(), "r");
                if (one_pass_file == nullptr) {
                    if (!sector)
                        cout << "FIRE is going to save one-pass database in the end" << endl;
                    // no such file, we need only to save database in the end
                } else {
                    Common::one_pass = true;
                    fclose(one_pass_file);
                    if (!sector && !Common::silent)
                        cout << "Going to work in one pass" << endl;
                    std::ifstream src(Common::one_pass_database, std::ios::binary);
                    std::ofstream dst(Common::path + "0001.tmp", std::ios::binary);
                    dst << src.rdbuf();
                }
            } else if (str.substr(0, 10) == "#integrals") { // parse integrals right here
                loaded_integrals = true;
                for (sector_count_t i = 2; i <= Common::abs_max_sector; ++i) {
                    Point::preferred_initial[i] = Point::preferred[i];
                }
                size_t pos = 10;
                while (str[pos] == ' ')
                    pos++;
                str = str.substr(pos);
                if (str.find('\n') != string::npos) {
                    str.erase(str.find('\n'));
                }
                Common::abs_max_level = Common::abs_min_level;
                if (Common::target_level > Common::abs_max_level) {
                    Common::abs_max_level = Common::target_level;
                }

                if ((str[0] == '\0') && (Common::inputSpecifiedArgument != "")) {
                    str = Common::inputSpecifiedArgument;
                }

                if ((sector == 0 || sector == 1) && str[0] != '\0') {

                    if (load_integrals(str, points)) {
                        return -1;
                    }
                }
            } else if (str.substr(0, 14) == "#single_sector") {
                size_t pos = 15;
                while (str[pos] == ' ')
                    pos++;
                str = str.substr(pos);
                unsigned int single_sector;
                s2u(str.c_str(), single_sector);
                Common::single_sector = single_sector; // yes, bytes can be lost technically
                initialize_dependencies();
            } else if (str.length() > 1 && str[0] != '\n' && str[1] != '\n') {
                cout << "Met strange option, ignoring it. Line:" << endl << str << endl;
            }
        }
    }
    if (!Common::split_masters && Common::master_number_min) {
        cout << "Master numbers set from command line, but #master option "
            "missing"
            << endl;
        abort();
    }

    if ((Common::split_masters && !Common::split_masters_no_dep) || Common::single_sector) {
        // recursvely building dependencies
        while (true) {
            bool changed = false;
            for (sector_count_t i = 2; i != Common::abs_max_sector + 1; ++i) {
                for (sector_count_t j = 2; j != Common::abs_max_sector + 1; ++j) {
                    if (dependencies[i][j]) {
                        // i depends on j, let's look further
                        for (sector_count_t k = 2; k != Common::abs_max_sector + 1; ++k) {
                            if (dependencies[j][k] && !dependencies[i][k]) {
                                dependencies[i][k] = true;
                                changed = true;
                            }
                        }
                    }
                }
            }
            if (!changed)
                break;
        }

        if (Common::dep_file != "") {
            std::ofstream out;
            out.open(Common::dep_file);
            out << "{{";
            for (sector_count_t i = 2; i != Common::abs_max_sector + 1; ++i) {
                out << "{" << i << ",";
                vector<t_index> &v = Common::ssectors[i];
                auto it = v.begin();
                out << "{" << int(*it);
                for (it++; it != v.end(); it++) {
                    out << "," << int(*it);
                }
                out << "}}";
                if (i != Common::abs_max_sector)
                    out << ", " << endl;
            }
            out << "}," << endl << "{";
            for (sector_count_t i = 2; i != Common::abs_max_sector + 1; ++i) {
                out << "{";
                for (sector_count_t j = 2; j != Common::abs_max_sector + 1; ++j) {
                    if (i == j)
                        out << 1;
                    else
                        out << dependencies[i][j];
                    if (j != Common::abs_max_sector)
                        out << ",";
                }
                out << "}";
                if (i != Common::abs_max_sector)
                    out << "," << endl;
            }
            out << "}}" << endl;
            out.close();
            cout << "Dependency file saved!" << endl;
        }

        // create the list of sectors where reduction is needed, set others to
        // zero
        for (sector_count_t i = 2; i != Common::abs_max_sector + 1; ++i) {
            bool needed = false;
            if (Common::single_sector) {
                needed = (i == Common::single_sector);
            } else {
                if (needed_sectors[i]) {
                    needed = true;
                } else {
                    for (sector_count_t j = 2; j != Common::abs_max_sector + 1; ++j) {
                        if (dependencies[i][j] && needed_sectors[j]) {
                            needed = true;
                            break;
                        }
                    }
                }
            }
            if (needed) {
                // if (!sector) cout<<"Needed sector: "<<i<<endl;
            } else {
                if (!sector && !Common::silent)
                    cout << "Setting sector to zero: " << i << endl;
                vector<vector<t_index>> orbit;
                vector<t_index> v = Common::ssectors[i];
                symmetry_orbit(v, orbit, Common::symmetries);
                for (auto v2 : orbit) {
                    Common::sector_numbers_fast[sector_fast(v2)] = 0;
                }
            }
        }

        // resetting some of requested points to zero
        for (auto &vp : Equation::initial) {
            if (!Common::sector_numbers_fast[
                    sector_fast(Common::ssectors[vp.second.first.SectorNumber()])
            ]) {
                points.erase(vp.second.first);
                vp.second.first = Point();
            }
        }
    }

    fclose(config_file);
    return 0;
}

vector<COEFF> split_coeff(const string &s) {
    // and now here we get to splitting a string into coeffs at individual
    // a[i]
    vector<COEFF> cc;
    cc.reserve(MAX_IND + 1);
#ifdef PRIME
    COEFF c0(0);
#else
    COEFF c0;
    c0.s = "";
#endif
    cc.push_back(c0);
    for (unsigned int i = 0; i != MAX_IND; ++i) {
        cc.push_back(c0);
    }
    const char *pos = s.c_str();
    while ((*pos != '\0') && (*pos != '{')) ++pos; //}
    if (*pos != '{') {
        cout << "No opening bracket at coefficient start, perhaps old form "
            "of start file"
            << endl;
        abort();
    }
    ++pos;
while (true) { // a cycle to find all pairs in coeff - coefficient and
               // number of a
    while ((*pos != '\0') && (*pos != '{') && (*pos != '}'))
        ++pos; //{
    if (*pos == '}')
        break; // closing bracket of all the list
    if (*pos != '{') {
        cout << "No opening bracket inside coefficient";
        abort();
    } // for internal pair
    ++pos;
    string coeff;
    while (*pos != '|') {
        coeff += *pos;
        ++pos;
    }
    ++pos; //,
    int n;
    sscanf(pos, "%d", &n); //{
    while (*pos != '}')
        ++pos;
    COEFF c;
#ifdef PRIME
#ifdef MPRIME
    for (size_t i = 0; i != MPRIME; ++i) {
#else
        size_t i = 0;
#endif
        std::string coeff_current = replace_all_variables(coeff, i);
        coeff_current = replace_all(coeff_current, " ", "");
        calc_wrapper(coeff_current, 0);
        if (Common::large_variables) {
            fuel::simplify(coeff_current, 0, true);
        }
#ifndef MPRIME
        c.n = string_fraction_to_modular(coeff_current);
#else
        c.N[i] = string_fraction_to_modular(coeff_current);
    }
#endif
#else
    c.s = replace_all_variables(coeff);
#endif
    cc[n] = c; // n is 0 means free coeff
    ++pos;     // passing closing bracket; //{
    while ((*pos != '|') && (*pos != '}'))
        ++pos;
    if (*pos == '|')
        ++pos;
}
return cc;
}

/**
 * Prints help on program usage
 * @param longOptions The struct containing options of the program
 * @param helpCalc If true, shows detailed help on libraries
 */
void show_help(const option *longOptions, bool helpCalc) {
    printf("Usage: ./bin/(FIRE7|FIRE7p|FLAME7|FLAME7p) [options]\n");

    if (helpCalc) {
        printf("The default binary paths for libraries are:\n");
        for (const auto &lib : fuel::libraryBinaries) {
            cout << "\t" << lib.first << ": ";
            if (lib.second[0] != '/') {
                cout << Common::FIRE_folder << "../";
            }
            cout << lib.second;
            cout << endl;
        }
    } else {
        std::map<std::string, std::string> expl;
        expl.emplace("help", "Show this help.");
        expl.emplace("parallel", "Indicates that multiple instances of FIRE can be "
                "called and forces change of database paths");
        expl.emplace("quiet", "Suppress most of output");
        expl.emplace("QUIET", "Suppress even more of output");
        std::stringstream calcExpl;
        calcExpl << "Specifies siplification library (equal to #calc setting) \nPossible values are: ";
        for (const auto &lib : fuel::libraryBinaries) {
            calcExpl << lib.first;
            if (lib.second[0] != '/') {
                calcExpl << "(*)";
            }
            calcExpl << "; ";
        }
        calcExpl << "\n(*) - is shipped with FIRE but might require a "
            "./configure option to work\n(for example, for libraries "
            "such as cocoa and ginac not having a built-in prompt we "
            "build a wrapper)"
            "\nuse --help calc to see the list of default binary paths";
        expl.emplace("calc", calcExpl.str().c_str());
        expl.emplace("calc_path", "User-set path to the library binary, "
                "overrides default values");
        expl.emplace("calc_options", "Comma-separated options to be passed to calc library "
                "with fuel::setOption");
        expl.emplace("config", "Obligatory option, provide path to the config file");
        expl.emplace("in", "Pipe number for writing data from the master process");
        expl.emplace("out", "Pipe number for writing data to the master process");
        expl.emplace("sector", "Obligatory option for the FLAME process, indicates the sector "
                "to work in. Negative numbers are used for substitutions");
        expl.emplace("thread", "Thread number to print for the FLAME process");
        expl.emplace("bucket", "Kyotocabinet bucket setting, overrides config value (equal to the #bucket setting)");
        expl.emplace("database", "Provides path to the database folder, overrides config value");
        expl.emplace("variables", "Underscore_separated_values, gives values to "
                "variables, in prime mode laste number is used as the "
                "number of the hardcoded big primes");
        expl.emplace("masters", "If without argument, sets saving only masters, not "
                "results. If with argument, (number-number) specifies "
                "a range of master integrals that are to be non-zero (equal to #masters)");
        expl.emplace("forward", "Run only the forward stage (reduction) (equal to #forward)");
        expl.emplace("backward", "Run only the backward stage (substitutions) (equal to #backward)");
        expl.emplace("large_variables", "Variables passed from arguments can be big and thus "
                "external library should be used for modular");
        expl.emplace("integrals", "Specify the path to the file with input integrals. "
                "The config file should have the #integrals line "
                "without file specification");
        expl.emplace("plan", "Specify the path to the file with plan.");
        expl.emplace("warmup", "Specify the path to the file saving warmup "
                "information for linear system (Defaults to "
                "appending .warmup to the plan file).");
        expl.emplace("positive", "Specify the positive indices. (equal to #positive)");
        expl.emplace("folders", "Specify whether the Tables should be saved into a "
                "subfolder depending on passed variables powers");
        expl.emplace("generate_warmup", "!");
        expl.emplace("use_warmup", "!");
        expl.emplace("record_steps", "!");
        expl.emplace("topo_sort", "!");
        expl.emplace("printall", "for debugging, prints integrals involved");
        expl.emplace("output_override", "overrides path to the output table");
        expl.emplace("no_positive_increase", "experimental, try to force to get no positive increase when seeding");
        expl.emplace("ids_first", "changes tables format putting ids at first place");

        for (auto current_option = longOptions; current_option->name != nullptr; ++current_option) {
            auto expl_itr = expl.find(current_option->name);
            std::string value;
            if (expl_itr != expl.end()) {
                value = expl_itr->second;
            } else {
                value = "NO EXPLANATION YET!";
            }
            if (value == "!") {
                continue;
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
}

pair<int, int> parse_argc_argv(int argc, char *argv[], [[maybe_unused]] bool main) {
    int thread_number = -1;
    int sector = 0;
    bool help_flag = false;
    bool help_calc = false;
    option longOptions[] = {{"help", optional_argument, nullptr, 'h'},
        {"parallel", no_argument, nullptr, 'p'},
        {"quiet", no_argument, nullptr, 'q'},
        {"QUIET", no_argument, nullptr, 'Q'},
        {"calc", required_argument, nullptr, 'l'},
        {"calc_options", required_argument, nullptr, 3},
        {"calc_path", required_argument, nullptr, 'L'},
        {"config", required_argument, nullptr, 'c'},
        {"in", required_argument, nullptr, 'i'},
        {"out", required_argument, nullptr, 'o'},
        {"sector", required_argument, nullptr, 's'},
        {"thread", required_argument, nullptr, 't'},
        {"bucket", required_argument, nullptr, 'b'},
        {"database", required_argument, nullptr, 'd'},
        {"variables", required_argument, nullptr, 'v'},
        {"plan", required_argument, nullptr, 'P'},
        {"warmup", required_argument, nullptr, 'W'},
        {"generate_warmup", no_argument, nullptr, 5},
        {"use_warmup", no_argument, nullptr, 6},
        {"record_steps", required_argument, nullptr, 'r'},
        {"topo_sort", required_argument, nullptr, 7},
        {"positive", required_argument, nullptr, 4},
        {"masters", optional_argument, nullptr, 'm'},
        {"printall", required_argument, nullptr, 'a'},
        {"output_override", required_argument, nullptr, 'O'},
        {"large_variables", no_argument, nullptr, 'V'},
        {"no_positive_increase", no_argument, nullptr, 'N'},
        {"integrals", required_argument, nullptr, 'I'},
        {"forward", optional_argument, nullptr, 1},
        {"backward", optional_argument, nullptr, 2},
        {"folders", required_argument, nullptr, 'F'},
        {"ids_first", no_argument, nullptr, 8},
        {nullptr, 0, nullptr, 0}};
    int c = 0;
    int fd;
    int pos;

    const char *argvpos, *curpos, *rpos;

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

#ifdef PRIME
    mp_limb_t flint_prime;
#endif

    fuel::setLibrary("flint");

    while ((c = getopt_long(argc, argv, shortOptions.str().c_str(), longOptions, nullptr)) != -1) {
        switch (c) {
            case 0:
                break;
            case 'h':
                help_flag = true;
                if (optarg == NULL && optind < argc && argv[optind][0] != '-') {
                    optarg = argv[optind++];
                }
                if (optarg != nullptr && string(optarg) == "calc") {
                    help_calc = true;
                }
                break;
            case 4: {
                          Common::positive_indices_option = optarg;
                          positive_indices.clear();
                          std::istringstream iss(optarg);
                          string portion;
                          while (getline(iss, portion, ',')) {
                              int ind = stoi(portion);
                              positive_indices.push_back(ind);
                          }
                      } break;
            case 'p':
                      Common::parallel_mode = true;
                      break;
            case 'N':
                      Common::no_positive_increase = true;
                      break;
            case 'F':
                      Common::folders_limit = stoi(optarg);
                      break;
            case 1:
                      Common::stages = t_stages::forward;
                      if (optarg == NULL && optind < argc && argv[optind][0] != '-') {
                          optarg = argv[optind++];
                      }
                      if (optarg != nullptr) {
                          s2i(optarg, Common::target_level);
                      }
                      break;
            case 2:
                      Common::stages = t_stages::backward;
                      if (optarg == NULL && optind < argc && argv[optind][0] != '-') {
                          optarg = argv[optind++];
                      }
                      if (optarg != nullptr) {
                          s2i(optarg, Common::target_level);
                      }
                      break;
            case 3: {
                        Common::fuelOptionsString = string(optarg);
                        std::string temp = Common::fuelOptionsString;
                        Common::fuelOptions.clear();
                        while (true) {
                            auto pos = temp.find(",");
                            if (pos != string::npos) {
                                Common::fuelOptions.push_back(temp.substr(0, pos));
                                temp = temp.substr(pos + 1);
                            } else {
                                Common::fuelOptions.push_back(temp);
                                break;
                            }
                        }
                    } break;
            case 'q':
                    Common::silent = true;
                    break;
            case 'Q':
                    Common::very_silent = true;
                    Common::silent = true;
                    break;
            case 'l': {
                          fuel::setLibrary(optarg);
                          break;
                      }
            case 'P': {
                          Common::plan_file = optarg;
                          break;
                      }
            case 'W': {
                          Common::warmup_file = optarg;
                          break;
                      }
            case 5: {
                          Common::generate_warmup_file = true;
                          break;
                      }
            case 6: {
                          Common::use_warmup_file = true;
                          break;
                      }
            case 'r': {
                          Common::step_file = optarg;
                          break;
                      }
            case 7: {
                          Common::topo_sorting_file = optarg;
                          break;
                      }
            case 8: {
                          Common::ids_first = true;
                          break;
                      }
            case 'O':
                      Common::output_override = optarg;
                      break;
            case 'c':
                      Common::config_file = optarg;
                      break;
            case 'V':
                      Common::large_variables = true;
                      break;
            case 'i':
                      s2i(optarg, fd);
                      Common::child_stream_to_child = fdopen(fd, "r");
                      Common::send_to_parent = true;
                      break;
            case 'o':
                      s2i(optarg, fd);
                      Common::child_stream_from_child = fdopen(fd, "w");
                      Common::send_to_parent = true;
                      break;
            case 's':
                      s2i(optarg, sector);
                      break;
            case 'I':
                      Common::inputSpecifiedArgument = std::string(optarg);
                      break;
            case 't':
                      s2i(optarg, thread_number);
                      break;
            case 'b':
                      s2i(optarg, Common::bucket_override);
                      break;
            case 'd':
                      Common::path = optarg;
                      break;
            case 'm':
                      if (optarg == NULL && optind < argc && argv[optind][0] != '-') {
                          optarg = argv[optind++];
                      }
                      if (optarg != nullptr) {
                          pos = s2u(optarg, Common::master_number_min);
                          if (optarg[pos]) {
                              s2u(optarg + pos + 1, Common::master_number_max);
                          } else {
                              Common::master_number_max = Common::master_number_min;
                          }
                      } else {
                          Common::only_masters = true;
                      }
                      break;
            case 'a':
                      if (optarg == NULL && optind < argc && argv[optind][0] != '-') {
                          optarg = argv[optind++];
                      }
                      if (optarg != nullptr)
                          s2i(optarg, Common::print_all_up_to_complexity);
                      break;
            case 'v': {
                          argvpos = optarg;
                          Common::tables_prefix = string(argvpos);
                          Common::variables_set_from_command_line = true;
                          curpos = argvpos;
                          while (true) {
                              if (*curpos == '_') {
                                  cout << "Leading or double _" << endl;
                                  abort();
                              }
                              rpos = curpos;

                              // going to accept any number of variables
                              while ((*rpos != '\0') && (*rpos != ' ')) { // searching for a separator
                                  if (*rpos == '_')
                                      break;
                                  ++rpos;
                              }
                              if (*rpos == '_') {
                                  // there will be more after
                                  var_values_from_arv.push_back(std::string(curpos, rpos - curpos));
                                  curpos = ++rpos;
                              } else
                                  break;
                          }
                          if (*curpos == '\0') {
                              cout << "--variables option should not end with a trailing _" << endl;
                              abort();
                          }
#ifdef PRIME
                          int parse_prime_number_success = sscanf(curpos, "%hu", &Common::prime_number);
                          if (parse_prime_number_success > 0) {
                              if (Common::prime_number > 255)
                                  cout << "Option #prime ignored: index for a prime should be "
                                      "in range from 0 to 255, refer to primes.cpp"
                                      << endl;
                              if (main && !Common::very_silent)
                                  printf("Using prime number %d\n", Common::prime_number);
                              Common::prime = primes[Common::prime_number];
                          } else {
                              int parse_custom_prime_success = sscanf(curpos, "mod%" SCNu64, &Common::prime);
                              if (parse_custom_prime_success < 1)
                                  throw std::runtime_error("Invalid prime number in --variable option");
                              if (main && !Common::very_silent)
                                  printf("Using user-specified prime modulus %" PRIu64 "\n", Common::prime);
                          }
                          flint_prime = Common::prime;
                          nmod_init(&Common::flint_mod, flint_prime);
#else
                          var_values_from_arv.push_back(std::string(curpos));
#endif
                          break;
                      }
            default:
                      printf("Unknown option!\n");
                      abort();
        }
    }

    if (help_flag || argc == 1) {
        show_help(longOptions, help_calc);
    }

    if (help_flag || Common::config_file == "") {
        if (!help_flag)
            cout << "Missing --config/-c option" << endl;
        exit(0);
    }

    return make_pair(thread_number, sector);
}
