/** @file functions.cpp
 * @author Alexander Smirnov
 *
 * This file is a part of the FIRE package
 */

#include "functions.h"

#include <algorithm>
#include <arpa/inet.h>
#include <condition_variable>
#include <mutex>
#include <omp.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <thread>

#include "common.h"
#include "parser.h"

/**
 * Mutex to protect interactions of workers with list of tasks worker_tasks.
 */
mutex worker_mutex;
/**
 * Condition is raised when there is some sector job to do for worker.
 */
condition_variable worker_cond;
/**
 * Condition is raised by worker to signal that he has finished a job.
 */
condition_variable worker_done_cond;
/**
 * To calculate the number of finished sectors
 */
int distributed_sectors = 0;

/**
 * Worker threads.
 */
thread worker[MAX_THREADS];
/**
 * Flag is raised, when all sector workers should be stopped.
 */
bool worker_stop = false; // time to stop for all workers
/**
 * List of tasks, protected by the worker_mutex.
 */
list<int> worker_tasks;

/**
 * Mutex that controls access to the set of jobs to be done.
 */
mutex level_mutex;

/**
 *  Array of threads that will have reduce_in_level() routine.
 */
thread level_worker[MAX_THREADS];

/**
 * List if levels to be done.
 */
list<pair<unsigned int, unsigned int>> level_tasks;

/**
 * Counter of levels inside sector that were starte and not finished
 */
int level_tasks_count = 0;

/**
 * Flag is raised, when work on level should be stopped.
 */
bool level_stop = false;
/**
 * Condition is raised, when there is some level to work with.
 */
condition_variable level_cond;
/**
 * Condition is raised to signal that level is done.
 */
condition_variable level_done_cond;

/** @name Memory-related statistics variables.*/
/**@{*/
/**
 * Virtual memory used by current thread (main or flame).
 */
__uint64_t max_vsize = 0;

/**
 * Resident memory used by current thread (main or flame).
 */
__uint64_t max_rss = 0;

/**
 * Maximum virtual memory used by main thread.
 */
__uint64_t max_vsi_main = 0;
/**
 * Maximum resident memory used by main thread.
 */
__uint64_t max_rss_main = 0;
/**
 * Thread virtual memory usage estimation by top sthreads_number sectors.
 */
__uint64_t max_vsi_est = 0;
/**
 * Thread resident memory usage estimation by top sthreads_number sectors.
 */
__uint64_t max_rss_est = 0;
/**@}*/

/**
 * Number of virtual points.
 */
atomic<uint64_t> virts_number{1};

/** @name Equation-related statistics variables.*/
/**@{*/
/**
 * Number of equations in a sector during a level
 */
atomic<unsigned long long> eqs_number_sector_level{};
/**
 * Number of used equations in a sector during a level.
 */
atomic<unsigned long long> used_number_sector_level{};

/**
 * Total number of equations in a sector by all threads in forward stage.
 */
unsigned long long eqs_number_sector_total{};
/**
 * Total number of used equations in a sector by all threads in forward stage.
 */
unsigned long long used_number_sector_total{};
/**@}*/

/**
 * Converts size in bytes to a string listing gigabytes
 * @param size size in bytes
 * @return string in gigabytes
 */
string size_in_gigabytes(int64_t size) {
    stringstream ss(stringstream::out);
    ss << double(size) / (1024 * 1024 * 1024) << " GB";
    return ss.str();
}

/**
 * Selfmade function that returns digit character representation.
 * @param i integer that should be in digit range
 * @return char representation
 */
inline char digit2char(const int i) {
    if (0 <= i && i <= 9) {
        return static_cast<char>('0' + i);
    }
    cout << "Error in digit2char" << endl;
    abort();
}

/**
 * Selfmade function that returns digit from it's character representation.
 * @param i char that should represent a number
 * @return the corresponding number
 */
inline unsigned int char2digit(const char i) {
    if ('0' <= i && i <= '9') {
        return static_cast<unsigned int>(i - '0');
    }
    cout << "Error in char2digit" << endl;
    abort();
}

/**
 * Substitute indices into a coefficient string without fermat calls, but with
 * string operations.
 * @param str string containing a[i] like insertions
 * @param v vector of substitutions
 */
void subs2(string &str, const t_index *v) {
    size_t length = str.size();
    for (unsigned int i = 0; i != length; ++i) {
        if ((i + 2) >= length) {
            continue;
        }
        if (!((str[i] == 'a') && (str[i + 1] == 'a'))) {
            continue;
        }
        unsigned int ind = 0;
        if ((str[i] == 'a') && (str[i + 1] == 'a') && (str[i + 2] == 'a') && (str[i + 3] == '(') &&
            (str[i + 5] == ')')) {
            ind = char2digit(str[i + 4]);
        } else if ((str[i] == 'a') && (str[i + 1] == 'a') && (str[i + 2] == 'a') && (str[i + 3] == '(') &&
                   (str[i + 6] == ')')) {
            ind = (10 * char2digit(str[i + 4])) + char2digit(str[i + 5]);
            str[i] = ' ';
            i++;
        }
        if (ind == 0) {
            cout << "subs2 error" << endl;
            cout << str << endl;
            cout << i << endl;
            abort();
        }
        ind--;
        str[i] = '(';
        if (v[ind] >= 100) {
            str[i + 1] = ' ';
            str[i + 2] = digit2char(v[ind] / 100);
            str[i + 3] = digit2char((v[ind] % 100) / 10);
            str[i + 4] = digit2char(v[ind] % 10);
        } else if (v[ind] >= 10) {
            str[i + 1] = ' ';
            str[i + 2] = ' ';
            str[i + 3] = digit2char(v[ind] / 10);
            str[i + 4] = digit2char(v[ind] % 10);
        } else if (v[ind] >= 0) {
            str[i + 1] = ' ';
            str[i + 2] = ' ';
            str[i + 3] = ' ';
            str[i + 4] = digit2char(v[ind]);
        } else if (v[ind] <= -100) {
            str[i + 1] = '-';
            str[i + 2] = digit2char(-v[ind] / 100);
            str[i + 3] = digit2char((-v[ind] % 100) / 10);
            str[i + 4] = digit2char(-v[ind] % 10);
        } else if (v[ind] <= -10) {
            str[i + 1] = ' ';
            str[i + 2] = '-';
            str[i + 3] = digit2char(-v[ind] / 10);
            str[i + 4] = digit2char(-v[ind] % 10);
        } else {
            str[i + 1] = ' ';
            str[i + 2] = ' ';
            str[i + 3] = '-';
            str[i + 4] = digit2char(-v[ind]);
        }
        i += 5;
    }
}

void generate_equation_term(Equation &eq, const Point &p, const FastPoint &pf, const vector<COEFF> &coeffs,
                            size_t &length) {

#ifdef PRIME
    COEFF res = coeffs[0];
    const t_index *ppos = pf.buf;
    for (unsigned short i = 0; i != Common::dimension; ++i, ++ppos) {
        if (*ppos >= 0) {
            COEFF temp = COEFF(mp_limb_t(*ppos));
            temp = temp * coeffs[i + 1];
            res = res + temp;
        } else {
            COEFF temp = COEFF(mp_limb_t(-*ppos));
            temp = temp * coeffs[i + 1];
            res = res - temp;
        }
    }
    COEFF zero(0);
    // check if there are some zeros
    if (!(res == zero)) {
        eq.terms.emplace_back(p, res);
        ++length;
    }
#else
    string cfast = coeffs[0].s; // the free coefficient;
    if (cfast.empty())
        cfast = "0";
    const t_index *ppos = pf.buf;
    char buf[16];
    for (unsigned short i = 0; i != Common::dimension; ++i, ++ppos) {
        if ((coeffs[i + 1].s != "") && (coeffs[i + 1].s != "0")) {
            cfast += "+(";
            cfast += coeffs[i + 1].s;
            cfast += ")*";
            snprintf(buf, sizeof(buf), "%d", int(*ppos));
            cfast += "(";
            cfast += buf;
            cfast += ") ";
        }
    }
    if (cfast != "0") {
        eq.terms.emplace_back(p, cfast);
        ++length;
    }
#endif
}

void group_equation_terms(Equation &eq) {
    unsigned int k = 0; // k is where we write to; i is where we read from;
    for (unsigned int i = 0; i != eq.terms.size(); ++i, ++k) {
        if (k != i) {
            eq.terms[k] = eq.terms[i]; // just changing the pointer to another portion of data
        }

        while (((i + 1) != eq.terms.size()) && (eq.terms[i + 1].first == eq.terms[k].first)) {
            // the next term is equal
#ifdef PRIME
            eq.terms[k].second = eq.terms[k].second + eq.terms[i + 1].second;
            if (eq.terms[k].second.Empty()) {
                --k;
                ++i;
                break; // out of the internal cycle. we will anyway increase i and k
            }
#else
            eq.terms[k].second.s += "+(" + eq.terms[i + 1].second.s + ")";
#endif
            ++i;
        }
    }
    if (k != eq.terms.size()) {
        eq.terms.erase(eq.terms.begin() + k, eq.terms.end());
    }
}

void generate_equation(Equation &eq, const ibp_type &ibp, FastPoint v, const SECTOR SectorFast) {
    size_t length = 0;
    sector_count_t sn = Common::sector_numbers_fast[SectorFast];
    Point p_orig(v, SectorFast);

    bool there_are_symmetries = (Common::symmetries.size() > 1);

    for (auto read = ibp.begin(); read != ibp.end(); ++read) {
        FastPoint new_v = read->second + v;
        SECTOR s1 = new_v.SectorFast();

        if ((s1 != SectorFast) && (~(SectorFast | (~s1)))) {
            continue;
        }
        // bitwise not to s1, or sSectorFast is full of 1 if SectorFast is over
        // s1. now again bitwise not, and it should become 0 only if SectorFast is
        // over s1

        Point new_p;

        if (Common::points_used != t_points::all) {
            int sum = 0;
            for (int i = 0; i != Common::dimension; ++i) {
                if (Common::parity_used[i]) {
                    sum += new_v.buf[i];
                }
            }
            if (Common::points_used == t_points::even) {
                if ((sum % 2) != 0)
                    continue;
            } else {
                if ((sum % 2) == 0)
                    continue;
            }
        }

        /*
        if (Common::no_positive_increase && s1 != SectorFast) {
            int cur_pos = 0;
            int new_pos = 0;
            for (int i = 0; i != Common::dimension; ++i) {
                if (v.buf[i] > 0) {
                    cur_pos += (v.buf[i] - 1);
                }
                if (new_v.buf[i] > 0) {
                    new_pos += (new_v.buf[i] - 1);
                }
            }
            if (new_pos > cur_pos) {
                eq.terms.clear();
                return;
            }
        }
        */

        if (!there_are_symmetries && (s1 == SectorFast)) {
            bool IsPreferred = Point::IsPreferred(new_v.GetVector(), sn);
            new_p = Point(p_orig, read->second, SectorFast, !IsPreferred);
        } else {
            new_p = point_reference_fast(new_v);
        }

        if (new_p.IsZero()) {
            continue;
        }

        generate_equation_term(eq, new_p, v, read->first, length);
    }

    std::sort(eq.terms.begin(), eq.terms.end(), pair_point_coeff_smaller);

    group_equation_terms(eq);
}

/**
 * Compare vectors of indices in sector with the use of sector ordering
 * @param lhs first vector
 * @param rhs second vector
 * @param s sector
 * @return true if lhs is smaller than rhs, false otherwise.
 */
bool vector_smaller_in_sector(const FastPoint &lhs, const FastPoint &rhs, SECTOR s) {
    if (lhs == rhs) {
        return false;
    }
    uint32_t *ordering_now = Common::orderings_fast[s].get();

    vector<t_index> d1;
    vector<t_index> d2;
    SECTOR bit = 1u << (Common::dimension - 1);
    for (unsigned int i = 0; i != Common::dimension; ++i, bit >>= 1) {
        if (s & bit) {
            d1.push_back(lhs.buf[i]);
            d2.push_back(rhs.buf[i]);
        } else {
            d1.push_back(-lhs.buf[i]);
            d2.push_back(-rhs.buf[i]);
        }
    }

    for (unsigned int i = 0; i != Common::dimension; ++i) {
        int pr = 0;
        uint32_t bit = 1;
        for (unsigned int j = 0; j != Common::dimension; ++j) {
            if (ordering_now[i] & bit)
                pr += (d1[j] - d2[j]);
            bit <<= 1;
        }
        if (pr < 0)
            return true;
        if (pr > 0)
            return false;
    }
    return false;
}

/**
 * Calculate final product from list of terms.
 * @param product the list of vectors of terms that are multipled
 * @param n dimension
 * @return resulting product
 */
map<FastPoint, COEFF> calculate_product(const list<vector<pair<COEFF, FastPoint>>> &product, unsigned int n) {
    // let's calculate the product
    map<FastPoint, COEFF> local_coeffs;
    for (const auto &v1 : product) {
        map<FastPoint, COEFF> new_local_coeffs;
        if (local_coeffs.empty()) {
            for (const auto &i1 : v1) {
                new_local_coeffs.emplace(i1.second, i1.first);
            }
        } else {
            for (const auto &i1 : v1) {
                for (const auto &local_coeff : local_coeffs) {
                    FastPoint new_v;
                    for (unsigned short u = 0; u != n; u++) {
                        new_v.buf[u] = i1.second.buf[u] + local_coeff.first.buf[u];
                    }
                    const auto i3 = new_local_coeffs.find(new_v);
#ifdef PRIME
                    // look like no need for MPRIME ifdef
                    if (i3 == new_local_coeffs.end()) {
                        COEFF new_c = i1.first * local_coeff.second;
                        new_local_coeffs.emplace_hint(i3, new_v, new_c);
                    } else {
                        i3->second = i1.first * local_coeff.second + i3->second;
                    }
#else
                    if (i3 == new_local_coeffs.end()) {
                        COEFF new_c;
                        new_c.s = "((" + i1.first.s + ")*(" + local_coeff.second.s + "))";
                        new_local_coeffs.emplace_hint(i3, new_v, new_c);
                    } else {
                        i3->second.s =
                            i3->second.s + "+" + "(" + "(" + i1.first.s + ")*(" + local_coeff.second.s + ")" + ")";
                    }
#endif
                }
            }
        }
        local_coeffs.clear();
        for (auto &&new_local_coeff : new_local_coeffs) {
#ifdef PRIME
            COEFF zero(0);
            if (!(new_local_coeff.second == zero)) {
                local_coeffs.insert(new_local_coeff);
            }
#else
            string &ss = new_local_coeff.second.s;
            calc_wrapper(ss, 0);
            if (ss != "0") {
                local_coeffs.insert(new_local_coeff);
            }
#endif
        }
    }
    return local_coeffs;
}

int write_symmetries(const Point &p_start, const unsigned int pos, const unsigned int neg,
                     std::optional<std::vector<std::vector<std::pair<Point, COEFF>>> *> eqs,
                     std::optional<std::function<bool(const FastPoint &)>> filter_function) {
    int result = 0;
    int n = p_start.GetVector().size();
    auto iitr = Point::ibases.find(p_start.SectorNumber());
    if (iitr != Point::ibases.end()) {
        FastPoint p_fast = FastPoint(p_start);
        set<FastPoint> s = level_points_fast(p_fast, pos, neg, filter_function);
        if (neg == 1) {
            set<FastPoint> s2 = level_points_fast(p_fast, pos, 0, filter_function);
            for (const auto &pp : s2)
                s.insert(pp);
        }
        if (pos == 1) {
            set<FastPoint> s2 = level_points_fast(p_fast, 0, neg, filter_function);
            for (const auto &pp : s2)
                s.insert(pp);
        }
        if ((neg == 1) && (pos == 1)) {
            set<FastPoint> s2 = level_points_fast(p_fast, 0, 0, filter_function);
            for (const auto &pp : s2)
                s.insert(pp);
        }
        leave_used_points(s);
        for (const auto &pp : s) {
            // go through points
            // no need for symmetries here more
            // y is pp.buf
            Point p = point_reference_fast(pp);
            if (!eqs && !p_is_empty(p)) {
                // in case of eqs for ext reduction we cannot check if there are more
                // relations for p
                continue;
            }

            for (const auto &ibasis : iitr->second) {
                // go through symmetries

                list<vector<pair<COEFF, FastPoint>>> product;
                FastPoint new_pp;
                for (int j = 0; j != n; ++j) { // here we use the permutation
                    if (ibasis.first[j] == 0) {
                        new_pp.buf[j] = 0;
                    } else {
                        new_pp.buf[j] = pp.buf[ibasis.first[j] - 1];
                    }
                }
                vector<pair<COEFF, FastPoint>> new_term;
#ifdef PRIME
                COEFF c(1);
#else
                COEFF c;
                c.s = "1";
#endif
                new_term.emplace_back(c, new_pp);
                product.push_back(new_term); // starting a product, next parts will be in a cycle

                for (const auto &pitr : ibasis.second) {
                    int power = -pp.buf[pitr.second - 1];
                    if (power < 0) {
                        cout << "Wrong internal symmetry rule: " << p << endl;
                        abort();
                    }
                    for (int j = 0; j != power; j++) {
                        product.push_back(pitr.first);
                    }
                }
                map<FastPoint, COEFF> local_coeffs =
                    calculate_product(product, n); // this is a shared function in external and internal
                                                   // symmetry generation

                // product calculated, now it is time to get the rule
                // let's add -p right here
                auto itr = local_coeffs.find(pp);
                if (itr == local_coeffs.end()) {
#ifdef PRIME
                    COEFF coeff(Common::prime - 1);
#else
                    COEFF coeff;
                    coeff.s = "-1";
#endif
                    local_coeffs.emplace(pp, coeff);
                } else {
#ifdef PRIME
                    COEFF one(1);
                    itr->second = itr->second - one;
#else
                    itr->second.s = itr->second.s + " -1";
#endif
                }

                // now we will convert here to strings, but...
                vector<pair<Point, COEFF>> mon;
                mon.reserve(local_coeffs.size());

                for (const auto &local_coeff : local_coeffs) {
#ifdef PRIME
                    COEFF zero(0);
                    if (!(local_coeff.second == zero))
#else
                    if (local_coeff.second.s != "0")
#endif
                    {
                        Point new_p = point_reference_fast(local_coeff.first);
                        if (new_p.IsZero())
                            continue;
                        if (new_p.SectorNumber() == 1) { // it can send to sector 1???
                            cout << "Incorrect internal symmetry for " << p << endl;
                            cout << "Sending to " << new_p << endl;
                            abort();
                        }

                        if ((new_p.SectorNumber() != p.SectorNumber())) { // internal symmetry should not map to another
                                                                  // sector of same level?
                            if (new_p.Level() >= p.Level()) {
                                cout << "Incorrect internal symmetry for " << p << endl;
                                cout << "Sending to " << new_p << endl;
                                abort();
                            }
                        }
                        mon.emplace_back(new_p, local_coeff.second);
                    }
                }

                // product ready, now sorting, joining, evaluating
                sort(mon.begin(), mon.end(), pair_point_coeff_smaller);
                mon = group_equal_in_sorted(mon);
#ifndef PRIME
                normalize(mon, 0); // symmetries are written in main thread, so no need
                                   // to pass number
#endif
                if ((mon.empty()) || mon[mon.size() - 1].first != p) {
                    continue;
                    // trivial or sending higher symmetries are simply ignored
                }
                if (eqs) {
                    (*eqs)->emplace_back(mon);
                } else {
                    p_set(p, mon, false);
                }
                ++result;
            }
        }
    }
    return result;
}

FastPoint lowest_in_sector_orbit_fast(const FastPoint &p, SECTOR s, const vector<vector<vector<t_index>>> &sym) {
    FastPoint result = p;
    for (const auto &values : sym) {
        const vector<t_index> &permutation = values[0];
        FastPoint p_new;

        for (unsigned int i = 0; i != Common::dimension; ++i) {
            p_new.buf[i] = p.buf[permutation[i] - 1];
        }

        // we only use the first part of symmetries, but I do not even know whether
        // the other parts used to work properly part 3 can be added only at parser
        // time and means something related to part 2 = conditional symmetries part
        // 1 i odd symmetries, but they did not work properly even in earlier
        // versions

        // now we need to compare the points and choose the lowest
        if ((p_new.SectorFast() == s) && fast_point_smaller_in_sector(p_new, result, s)) {
            result = p_new;
        }
    }
    return result;
}

unsigned int sort_ibps(const Point &p, const set<pair<unsigned int, unsigned int>> &current_levels,
                       vector<pair<Point, pair<FastPoint, unsigned short>>> &ibps_vector,
                       const vector<FastPoint> &IBPdegree, const vector<FastPoint> &IBPdegreeFull,
                       std::optional<std::function<bool(const FastPoint &)>> filter_function) {

    FastPoint p_fast(p);
    SECTOR sector = p_fast.SectorFast();
    set<FastPoint> s_fast;
    for (const auto &current_level : current_levels) {
        const unsigned int pos = current_level.first;
        const unsigned int neg = current_level.second;
        set<FastPoint> s0 = level_points_fast(p_fast, pos, neg, filter_function);
        for (const auto &fp : s0) {
            s_fast.insert(fp);
        }
        if (neg == 1) {
            set<FastPoint> s2 = level_points_fast(p_fast, pos, 0, filter_function);
            for (const auto &fp : s2)
                s_fast.insert(fp);
        }
        if (pos == 1) {
            set<FastPoint> s2 = level_points_fast(p_fast, 0, neg, filter_function);
            for (const auto &fp : s2)
                s_fast.insert(fp);
        }
        if ((neg == 1) && (pos == 1)) {
            set<FastPoint> s2 = level_points_fast(p_fast, 0, 0, filter_function);
            for (const auto &fp : s2)
                s_fast.insert(fp);
        }
    }

    if (Common::symmetries.size() > 1) { // there are symmetries
        vector<vector<vector<t_index>>> &sym = Common::symmetries;
        set<FastPoint> s_new_fast;

        // now taking only lowest in orbits
        for (const auto &fp : s_fast) {
            s_new_fast.insert(lowest_in_sector_orbit_fast(fp, sector, sym));
        }
        s_fast = s_new_fast;
    }

    ibps_vector.reserve(s_fast.size() * IBPdegree.size());
    unsigned int counter = 0;

    for (const auto &fp : s_fast) {
        FastPoint deg = fp.Degree();
        for (unsigned int i = 0; i != IBPdegree.size(); ++i) {
            vector<pair<Point, COEFF>> terms;
            FastPoint highest_fast;
            for (unsigned short j = 0; j != Common::dimension; ++j) {
                highest_fast.buf[j] = fp.buf[j] + IBPdegreeFull[i].buf[j];
            }
            SECTOR bit = 1u << (Common::dimension - 1);
            for (unsigned int j = 0; j < Common::dimension; ++j, bit >>= 1) {
                if (sector & bit) {
                    if (highest_fast.buf[j] <= 0)
                        highest_fast.buf[j] = 1;
                } else {
                    if (highest_fast.buf[j] > 0)
                        highest_fast.buf[j] = 0;
                }
            }
            ibps_vector.emplace_back(Point(highest_fast), make_pair(fp, static_cast<unsigned short>(i)));
            ++counter;
            if (!Common::all_ibps) {
                if (over_fast(deg, IBPdegree[i]))
                    break;
            }
        }
    }
    sort(ibps_vector.begin(), ibps_vector.end(),
         [](const auto &a, const auto &b) -> bool { return a.first < b.first; });
    return counter;
}

vector<pair<unsigned int, unsigned int>> under_levels(const unsigned int p0, const unsigned int m0) {
    unsigned int p = p0;
    unsigned int m = m0;
    vector<pair<unsigned int, unsigned int>> result;
    if (p0 == 0) {
        while (m > 0) {
            result.push_back(make_pair(p, m));
            m--;
        }
    }
    while ((m > 0) || (p > 0)) {
        while (p > 0) {
            if ((p <= p0) && (m <= m0) && (m > 0)) {
                result.push_back(make_pair(p, m));
            }
            p--;
            m++;
        }
        // p is now 0, m is positive
        p = m - 1;
        m = 0;
    }
    return result;
}

bool make_master(const Point &p, bool allow_new_master_in_split_mode) {
    if (Common::split_masters) {
        if (allow_new_master_in_split_mode) {
            cout << "Unspecified master integral in masters mode (will try again): " << p << endl;
            return false;
        } else {
            cout << "Unspecified master integral in masters mode: " << p << endl;
            abort();
        }
    } else if (!Common::silent) {
        cout << "New master integral: " << p << endl;
    }

    vector<t_index> v2 = p.GetVector();

    Point p2(v2, 0, -2);
#ifdef PRIME
    COEFF one(1);
    COEFF minus_one(Common::prime - 1);
#else
    COEFF one;
    COEFF minus_one;
    one.s = "1";
    minus_one.s = "-1";
#endif
    vector<pair<Point, COEFF>> t;
    t.emplace_back(p2, one);
    t.emplace_back(p, minus_one);
    p_set(p, t, true, p.SectorNumber());
    return true;
}

bool mark_master_integrals(const Point &Corner, const unsigned int pos, const unsigned int neg, bool first_pass,
                           bool only_preferred) {
    SECTOR s = FastPoint(Corner).SectorFast();
    sector_count_t sn = Common::sector_numbers_fast[s];
    if (neg > 0) {
        set<FastPoint> p_refs_fast = level_points_fast(FastPoint(Corner), (pos > 0) ? (pos - 1) : 0, neg - 1);
        leave_used_points(p_refs_fast);
        // now taking lower orbit values
        if (Common::symmetries.size() > 1) { // there are symmetries
            vector<vector<vector<t_index>>> &sym = Common::symmetries;
            set<FastPoint> p_refs_fast_new;
            // now taking only lowest in orbits
            for (const auto &fp : p_refs_fast) {
                FastPoint lowest = lowest_in_sector_orbit_fast(fp, s, sym);
                p_refs_fast_new.insert(lowest);
            }
            p_refs_fast = p_refs_fast_new;
        }
        for (const auto &fp : p_refs_fast) {
            if (!only_preferred || Point::IsPreferred(fp.GetVector(), sn)) {
                Point p = Point(fp, s);
                if (p_is_empty(p)) {
                    if (!make_master(p, first_pass))
                        return false; // we are in masters split mode, and there is a new
                                      // master, should try without hint if we had it
                }
            }
        }
    }
    return true;
}

/**
 * Functor for comparing levels of points (using dots and numerators).
 */
struct LevelSmaller {
    /**the internal comparator; levels are compared by their sums (total shift
     * from the corner), in case of equal the priority is to have less dots
     * @param lhs first level
     * @param rhs first level
     * @return compare result, true if first is smaller
     */
    bool operator()(const pair<unsigned int, unsigned int> &lhs, const pair<unsigned int, unsigned int> &rhs) const {
        if (lhs.first + lhs.second < rhs.first + rhs.second)
            return true;
        if (lhs.first + lhs.second > rhs.first + rhs.second)
            return false;
        return lhs.first < rhs.first;
    }
};

void timeval_subtract(timeval *result, timeval *x, timeval *y) {
    /* Perform the carry for the later subtraction by updating y. */
    if (x->tv_usec < y->tv_usec) {
        int nsec = (y->tv_usec - x->tv_usec) / 1000000 + 1;
        y->tv_usec -= 1000000 * nsec;
        y->tv_sec += nsec;
    }
    if (x->tv_usec - y->tv_usec > 1000000) {
        int nsec = (x->tv_usec - y->tv_usec) / 1000000;
        y->tv_usec += 1000000 * nsec;
        y->tv_sec -= nsec;
    }

    /* Compute the time remaining to wait.
    tv_usec is certainly positive. */
    result->tv_sec = x->tv_sec - y->tv_sec;
    result->tv_usec = x->tv_usec - y->tv_usec;
}

void add_needed(map<sector_count_t, set<Point>> &needed_lower, const Point &p) {
    sector_count_t new_sector = p.SectorNumber();
    if (new_sector == 1)
        return;
    auto itr = needed_lower.find(new_sector);
    if (itr == needed_lower.end()) {
        set<Point> s;
        s.insert(p);
        needed_lower.emplace(new_sector, s);
    } else {
        itr->second.insert(p);
    }
}

/**
 * Timestamp of beginning of work of a thread for statistics.
 */
chrono::time_point<chrono::steady_clock> thread_start_time;

void finish_sector(const set<Point> &needed_lower, sector_count_t sector_number,
                   set<Point, std::greater<Point>> *ivpl) {

    if (!needed_lower.empty()) {
        void *points = malloc(sizeof(Point) * needed_lower.size());
        if (!points) {
            cout << "Cannot malloc in finish_sector" << endl;
            abort();
        }
        int i = 0;
        for (auto sitr = needed_lower.begin(); sitr != needed_lower.end(); ++sitr, ++i) {
            reinterpret_cast<Point *>(points)[i] = *sitr;
        }
        if (!Common::points[sector_number]->set("lower", 5, static_cast<const char *>(points),
                                                needed_lower.size() * sizeof(Point))) {
            cout << "Can't write in finish_sector" << endl;
            abort();
        }
        free(points);
    }

    process_mem_usage(true);
    Common::points[sector_number]->set("eqs_max", 7, reinterpret_cast<const char *>(&used_number_sector_total), 8);
    Common::points[sector_number]->set("eqs_tot", 7, reinterpret_cast<const char *>(&eqs_number_sector_total), 8);
    Common::points[sector_number]->set("mem_vsi", 7, reinterpret_cast<const char *>(&max_vsize), 8);
    Common::points[sector_number]->set("mem_rss", 7, reinterpret_cast<const char *>(&max_rss), 8);
    Common::points[sector_number]->set("act_var", 7, Common::active_variables.c_str(), Common::active_variables.size());

    size_t records2 = Common::points[sector_number]->count();
    double records2log = log2(records2);
    if (!Common::silent) {
        cout << "Database " << sector_number << " has size "
             << size_in_gigabytes(Common::points[sector_number]->size()) << " and "
             << records2 << " entries (log = " << records2log << ")" << endl;
    }
    size_t ignored = close_database(
        sector_number, true,
        [ivpl, sector_number](const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz) -> bool {
            if (ivpl == nullptr)
                return true;
            if (ksiz < sizeof(Point))
                return true;
            const Point test = *reinterpret_cast<const Point *>(kbuf);
            if (Common::one_pass && test.SectorNumber() != sector_number)
                return true;
#ifdef PRIME
#ifdef MPRIME
            return ((ivpl->find(test) != ivpl->end()) ||
                    (Common::only_masters && (vsiz % (sizeof(Point) + MPRIME * sizeof(unsigned long long)))));
#else
            return ((ivpl->find(test) != ivpl->end()) ||
                    (Common::only_masters && (vsiz % (sizeof(Point) + sizeof(unsigned long long)))));
#endif
#else
            return ((ivpl->find(test) != ivpl->end()) ||
                    (Common::only_masters && (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & NEEDED_BIT)));
#endif
        });

    if (!Common::silent) {
        cout << "Thread (sector " << sector_number << "): ";
        cout << "saved " << records2 - ignored << " entries to disk" << endl;
    }
    auto thread_stop_time = chrono::steady_clock::now();

    if (!Common::silent) {
        cout << "Algerbra/total reduction time in sector " << sector_number << ": "
             << chrono::duration_cast<chrono::duration<float>>(chrono::microseconds(Common::simplify_time)).count()
             << "/" << chrono::duration_cast<chrono::duration<float>>(thread_stop_time - thread_start_time).count()
             << endl;
        cout << "Memory usage by sector " << sector_number << " (virtual|resident): ";
    }
    print_memory(max_vsize, 0);
    if (!Common::silent) {
        cout << " | ";
    }
    print_memory(max_rss, 1);
    if (!Common::silent) {
        cout << endl;
    }

    if (Common::cpath != "") {
        store_database(sector_number);
    }
}

void add_ibps(const COEFF &first_mul, const COEFF &second_mul, const ibp_type &first, const ibp_type &second,
              const SECTOR SectorFast, ibp_type &result) {
    result.clear();
    result.reserve(first.size() + second.size());
    unsigned int i = 0;
    unsigned int j = 0;
    while (i + j != first.size() + second.size()) {
        if ((j == second.size()) ||
            (((i != first.size())) && vector_smaller_in_sector(second[j].second, first[i].second, SectorFast))) {
            // second does not exist or i is bigger
            vector<COEFF> mult = first[i].first;
            for (COEFF &c : mult)
                c = first_mul * c;
            result.emplace_back(mult, first[i].second);
            ++i;
        } else if ((i == first.size()) || (((j != second.size())) &&
                                           vector_smaller_in_sector(first[i].second, second[j].second, SectorFast))) {
            // first does not exist or j is bigger
            vector<COEFF> mult = second[j].first;
            for (COEFF &c : mult)
                c = COEFF() - second_mul * c;
            result.emplace_back(mult, second[j].second);
            ++j;
        } else {
            // they are equal
            vector<COEFF> added;
            added.reserve(Common::dimension + 1);
            bool has_nonzero = false;
            for (int k = 0; k != Common::dimension + 1; ++k) {
                COEFF c = first_mul * first[i].first[k] - second_mul * second[j].first[k];
#ifndef PRIME
                calc_wrapper(c.s, 0);
#endif
                if (!c.Empty())
                    has_nonzero = true;
                added.push_back(c);
            }
            if (has_nonzero) {
                result.emplace_back(added, first[i].second);
            }
            ++i;
            ++j;
        }
    }
}

int matching_index(const vector<COEFF> &first, const vector<COEFF> &second) {
    int matching_index = -1;
    for (int k = 0; k != Common::dimension + 1; ++k) {
        if ((!first[k].Empty()) || (!second[k].Empty())) {
            if (matching_index >= 0) {
                matching_index = -1;
                break;
            } else {
                matching_index = k;
            }
        }
    }
    return matching_index;
}

void sort_unsibstituted_ibps(vector<ibp_type>::iterator begin, vector<ibp_type>::iterator end, SECTOR s) {
    sort(begin, end, [s](const auto &lhs, const auto &rhs) -> bool {
        auto &v1 = lhs[0].second;
        auto &v2 = rhs[0].second;
        if (vector_smaller_in_sector(v2, v1, s))
            return true;
        if (vector_smaller_in_sector(v1, v2, s))
            return false;
        return lhs.size() < rhs.size();
    });
}

void improve_ibps(vector<ibp_type> &ibps, SECTOR SectorFast) {
    for (auto &ibp : ibps) {
        sort(ibp.begin(), ibp.end(), [&SectorFast](const auto &a, const auto &b) -> bool {
            return vector_smaller_in_sector(b.second, a.second, SectorFast);
        });
    }
    // sorting each ibp, first are biggest

    if (Common::disable_presolve)
        return;
    if (Common::presolve_ibps == 0)
        Common::presolve_ibps = ibps.size();

    sort_unsibstituted_ibps(ibps.begin(), ibps.begin() + Common::presolve_ibps, SectorFast);
    FastPoint zero_point{};

    for (unsigned int i = 0; i != Common::presolve_ibps; ++i) {
        int k = ibps[i].size() - 1;
        while (true) {
            bool has_nonzero = false;
            for (int kk = 0; kk != Common::dimension + 1; ++kk) {
                if (!ibps[i][k].first[kk].Empty()) {
                    has_nonzero = true;
                    break;
                }
            }
            if (!has_nonzero) {
                ibps[i].erase(ibps[i].begin() + k);
            }
            if (k > 0) {
                --k;
            } else {
                break;
            }
        }
    }

    for (unsigned int i = 0; i != Common::presolve_ibps; ++i) {
        // forward pass
        for (unsigned int j = i + 1; j != Common::presolve_ibps; ++j) {
            if (ibps[i][0].second != ibps[j][0].second) {
                break;
            }
            int index = matching_index(ibps[i][0].first, ibps[j][0].first);
            if (index >= 0) {
                // only one index coeff differs
                // need to add i to j
                COEFF mul_i = ibps[j][0].first[index];
                COEFF mul_j = ibps[i][0].first[index];
                ibp_type res;
                add_ibps(mul_i, mul_j, ibps[i], ibps[j], SectorFast, res);
                // now res is the new relation that should replace j
                if (res.empty()) {
                    ibps.erase(ibps.begin() + j);
                } else if (res[0].second == zero_point) {
                    // we should not result in ibps with zero top shift since in can have
                    // cancelling coefficients!
                    ++j;
                } else {
                    ibps[j] = res;
                    sort_unsibstituted_ibps(ibps.begin() + j, ibps.begin() + Common::presolve_ibps, SectorFast);
                }
                --j;
            }
        }
    }
    if (Common::old_presolve) {
        if (Common::presolve_ibps != ibps.size()) {
            sort_unsibstituted_ibps(ibps.begin(), ibps.end(), SectorFast);
        }
        return;
    }
    for (unsigned int i = 0; i != Common::presolve_ibps; ++i) {
        for (unsigned int j = i + 1; j != Common::presolve_ibps; ++j) {
            for (unsigned int k = 1; k < ibps[i].size(); ++k) {
                if (ibps[i][k].second == ibps[j][0].second) {
                    int index = matching_index(ibps[i][k].first, ibps[j][0].first);
                    if (index >= 0) {

                        COEFF mul_i = ibps[j][0].first[index];
                        COEFF mul_j = ibps[i][k].first[index];
                        ibp_type res;
                        add_ibps(mul_i, mul_j, ibps[i], ibps[j], SectorFast, res);
                        ibps[i] = res;
                    }
                }
            }
        }
    }

    if (Common::presolve_ibps != ibps.size()) {
        for (unsigned int i = Common::presolve_ibps; i != ibps.size(); ++i) {
            for (unsigned int j = 0; j != Common::presolve_ibps; ++j) {
                for (unsigned int k = 1; k < ibps[i].size(); ++k) {
                    if (ibps[i][k].second == ibps[j][0].second) {
                        int index = matching_index(ibps[i][k].first, ibps[j][0].first);
                        if (index >= 0) {
                            COEFF mul_i = ibps[j][0].first[index];
                            COEFF mul_j = ibps[i][k].first[index];
                            ibp_type res;
                            add_ibps(mul_i, mul_j, ibps[i], ibps[j], SectorFast, res);
                            ibps[i] = res;
                        }
                    }
                }
            }
        }
        sort_unsibstituted_ibps(ibps.begin(), ibps.end(), SectorFast);
    }
}

void try_symmetries_with_lbasis(pair<vector<t_index>, vector<pair<vector<pair<COEFF, FastPoint>>, t_index>>> dbasis,
                                const FastPoint &y, const Point p, vector<pair<Point, COEFF>> &mon) {
    unsigned int n = Common::dimension;
    list<vector<pair<COEFF, FastPoint>>> product;
    FastPoint new_y;
    for (unsigned int j = 0; j != n; j++) {
        if (dbasis.first[j] == 0) {
            new_y.buf[j] = 0;
        } else {
            new_y.buf[j] = y.buf[dbasis.first[j] - 1];
        }
    }
    vector<pair<COEFF, FastPoint>> new_term;
#ifdef PRIME
    COEFF c1(1);
#else
    COEFF c1;
    c1.s = "1";
#endif
    new_term.emplace_back(c1,
                          new_y); // we start building a product of sums. first term is without sum
    product.push_back(new_term);

    for (const auto &pitr : dbasis.second) {
        int power = -y.buf[pitr.second - 1];
        if (power < 0) {
            cout << "Wrong delayed rule: " << p << endl;
            abort();
        }
        for (int j = 0; j != power; j++) {
            product.push_back(pitr.first); // product is created from lbases.
                                           // coefficients are strings
        }
    }

    // this is a shared function in external and internal symmetry generation
    map<FastPoint, COEFF> local_coeffs = calculate_product(product, n);

    // let's add -y right here
    auto itr = local_coeffs.find(y);
    if (itr == local_coeffs.end()) {
#ifdef PRIME
        COEFF c(Common::prime - 1);
#else
        COEFF c;
        c.s = "-1";
#endif
        local_coeffs.insert(make_pair(y, c));
    } else {
#ifdef PRIME
        COEFF one(1);
        itr->second = itr->second - one;
#else
        itr->second.s = itr->second.s + " -1";
#endif
    }

    mon.reserve(local_coeffs.size());

    for (const auto &local_coeff : local_coeffs) {
#ifdef PRIME
        COEFF zero(0);
        if (!(local_coeff.second == zero))
#else
        if (local_coeff.second.s != "0")
#endif
        {
            Point new_p = point_reference_fast(local_coeff.first);
            if (new_p.IsZero()) {
                continue;
            }
            if (new_p.SectorNumber() == 1) {
                cout << "Incorrect l-rule for " << p << endl;
                cout << "Sending to " << new_p << endl;
                abort();
            }
            if ((new_p.SectorNumber() == p.SectorNumber()) && (new_p != p)) {
                cout << "Incorrect l-rule for " << p << endl;
                cout << "Sending to " << new_p << endl;
                abort();
            }
            if (new_p.SectorNumber() != p.SectorNumber()) {
                if (new_p.Level() > p.Level()) {
                    cout << "Incorrect l-rule for " << p << endl;
                    cout << "Sending to " << new_p << endl;
                    abort();
                }
                if (new_p.Level() == p.Level()) {
                    if (Common::lsectors.find(sector_fast(new_p.GetVector())) == Common::lsectors.end()) {
                        cout << "Incorrect l-rule for " << p << endl;
                        cout << "Sending to " << new_p << endl;
                        abort();
                    }
                }
            }
            mon.emplace_back(new_p, local_coeff.second);
        }
    }

    // product ready, now sorting, joining, evaluating
    sort(mon.begin(), mon.end(), pair_point_coeff_smaller);
    mon = group_equal_in_sorted(mon);
    if ((mon.empty()) || mon[mon.size() - 1].first != p) {
        cout << "LSymmetry ordering error: " << p << " -> " << endl;
        for (const auto &it : mon) {
            cout << it.first << ", " << endl;
        }
        abort();
    }
}

bool try_reduce_with_lbasis(
    vector<pair<vector<pair<vector<t_index>, pair<short, bool>>>,
                vector<pair<std::vector<std::string>, vector<pair<vector<t_index>, short>>>>>> &lbasis,
    const FastPoint &y, const Point p, vector<pair<Point, COEFF>> &mon) {

    unsigned int n = Common::dimension;
    for (const auto &elem : lbasis) {
        const auto &conditions = elem.first;
        bool satisfies = true;
        for (const auto &condition : conditions) {
            int sum = condition.second.first;
            for (unsigned int i = 0; i != n; ++i) {
                sum += (y.buf[i] * (condition.first[i]));
            }
            if ((sum == 0) && condition.second.second == false)
                satisfies = false;
            if ((sum != 0) && condition.second.second == true)
                satisfies = false;
            if (!satisfies) {
                break;
            }
        }
        if (satisfies) { // rule satisfies all conditions
            const auto &terms = elem.second;
            mon.reserve(terms.size());
            map<vector<t_index>, COEFF> local_coeffs;
            for (const auto &term : terms) {
                vector<t_index> new_v;
                for (unsigned int i = 0; i != n; ++i) {
                    t_index sum = term.second[i].second;
                    for (unsigned int j = 0; j != n; ++j) {
                        sum += (y.buf[j] * term.second[i].first[j]);
                    }
                    new_v.push_back(sum);
                }
                std::vector<std::string> coeffs = term.first;
                // in MPRIME mode there will be multiple
                for (auto &coeff : coeffs) {
                    subs2(coeff, y.buf);
#ifdef PRIME
                    // in prime mode we imideately simplify them so that they are numbers
                    // ready for reading
                    if (fuel::getLibrary() == "symbolica") {
                        fuel::simplify(coeff, 0);
                    } else {
                        calc_wrapper(coeff, 0);
                    }
                    fuel::simplify(coeff, 0, true);
#endif
                }
                COEFF c;
#ifdef PRIME
#ifdef MPRIME
                for (size_t i = 0; i != MPRIME; ++i) {
                    c.N[i] = string_fraction_to_modular(coeffs[i]);
                }
#else
                c.n = string_fraction_to_modular(coeffs[0]);
#endif
#else
                c.s = coeffs[0];
#endif
                auto local_coeffs_itr = local_coeffs.find(new_v);
                if (local_coeffs_itr == local_coeffs.end()) {
                    local_coeffs.emplace_hint(local_coeffs_itr, new_v, c);
                } else {
                    local_coeffs_itr->second = local_coeffs_itr->second + c;
                }
            }
            for (auto &local_coeff : local_coeffs) {
                COEFF &c = local_coeff.second;
#ifndef PRIME
                // in poly mode this is the place to finally simplify
                if (fuel::getLibrary() == "symbolica") {
                    fuel::simplify(c.s, 0);
                } else {
                    calc_wrapper(c.s, 0);
                }
#endif
#ifdef PRIME
                COEFF zero(0);
                if (!(c == zero))
#else
                if (c.s != "0")
#endif
                {
                    Point new_p = point_reference(local_coeff.first);
                    if (new_p.IsZero()) {
                        continue;
                    }
                    if (new_p.SectorNumber() == 1) {
                        cout << "Incorrect l-basis-rule for " << p << endl;
                        cout << "Sending to " << new_p << endl;
                        abort();
                    }
                    if (new_p.SectorNumber() != p.SectorNumber()) {
                        if (new_p.Level() >= p.Level()) {
                            cout << "Incorrect l-basis-rule for " << p << endl;
                            cout << "Sending to " << new_p << endl;
                            abort();
                        }
                    }
                    mon.emplace_back(new_p, c);
                }
            }
#ifdef PRIME
            COEFF minus_one(Common::prime - 1);
#else
            COEFF minus_one;
            minus_one.s = "-1";
#endif
            mon.emplace_back(p, minus_one);
            sort(mon.begin(), mon.end(), pair_point_coeff_smaller);

            if ((mon.empty()) || mon[mon.size() - 1].first != p) {
                cout << "LBasis ordering error: " << p << " -> " << endl;
                for (const auto &it : mon) {
                    cout << it.first << ", " << endl;
                }
                abort();
            }
            return true;
        } // if satisfies
    } // rule cycle
    return false;
}

/* main worker in a sector
 * tries different methods
 * such as searching for an sbasis or lbases
 * if nothing uses Laporta
 */
void forward_stage(unsigned short thread_number, sector_count_t sector_number) {
    if (!Common::silent) {
        cout << "STARTING THREAD " << thread_number << " for {" << Common::global_pn << ",";
    }
    print_vector(Common::ssectors[sector_number]);
    if (!Common::silent) {
        cout << "} " << sector_number << endl;
    }

    //  thread number is now purely for printing information
    thread_start_time = chrono::steady_clock::now(); // laporta in sector
    set<Point, std::greater<Point>> needed_in_this_sector;

    open_database_and_scan(
        sector_number,
        [sector_number](const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz) -> bool {
            if (ksiz != sizeof(Point))
                return false;
            auto *p = reinterpret_cast<const Point *>(kbuf);
            if ((p->IsVirtual()) || (p->SectorNumber() != sector_number))
                return false;
#ifdef PRIME
#ifdef MPRIME
            return vsiz % (sizeof(Point) + MPRIME * sizeof(unsigned long long));
#else
            return vsiz % (sizeof(Point) + sizeof(unsigned long long));
#endif
#else
            return (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & NEEDED_BIT);
#endif
        },
        needed_in_this_sector);

    if (Common::wrap_databases) {
        remove((Common::path + int2string(sector_number) + ".tmp").c_str());
    }

    set<Point> set_needed_lower;

    vector<t_index> ssector = Common::ssectors[sector_number];

    Point Corner = point_reference(corner(ssector));
    bool first_pass = true;
    while (!needed_in_this_sector.empty()) {
        set<Point, std::greater<Point>> ivpl = needed_in_this_sector;
        set<Point>::iterator ivpl_counter;

        bool done = true;
        for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
            Point p = *ivpl_counter;
            vector<Point> monoms = p_get_monoms(p);
            if (!monoms.empty()) {
                for (const auto &monom : monoms) {
                    if (monom.SectorNumber() == sector_number) {
                        ivpl.insert(ivpl_counter, monom);
                    }
                }
            } else {
                done = false;
                break;
            }
        }
        if (done) {
            if (!Common::silent) {
                cout << "Thread " << thread_number << ": nothing to do." << endl;
            }
            ivpl.clear();
            for (const auto &read : needed_in_this_sector) {
                ivpl.insert(read);
            }
            for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                Point p = *ivpl_counter;
                vector<Point> monoms = p_get_monoms(p);
                if (!monoms.empty()) {
                    for (const auto &monom : monoms) {
                        if (monom.SectorNumber() == sector_number) {
                            ivpl.insert(ivpl_counter, monom);
                        }
                        if (p.SectorNumber() != monom.SectorNumber()) {
                            set_needed_lower.insert(monom);
                        }
                    }
                }
            }
            finish_sector(set_needed_lower, sector_number, &ivpl);
            return;
        }
        set<pair<unsigned int, unsigned int>> input_levels;
        set<pair<unsigned int, unsigned int>> real_input_levels;
        for (const auto &read : needed_in_this_sector) {
            const vector<t_index> v = read.GetVector();
            auto l = level(v);
            // real input levels is just for printing
            if (l.first == 0 && !Common::no_positive_increase) {
                l.first = 1;
            }
            if (l.second == 0) {
                l.second = 1;
            }
            real_input_levels.insert(l);
            l = level(v);
            // using needed_level right here
            if (first_pass) {
                if (!Common::no_positive_increase) {
                    l.first = l.first + 1;
                }
                if (l.second == 0) {
                    l.second = 1;
                }
            } else {
                if (!Common::no_positive_increase) {
                    l.first = l.first + 1;
                }
                l.second = l.second + 1;
            }
            input_levels.insert(l);
            ivpl.insert(read);
        }

        if (Common::preferred_produce_seeds) {
            for (const auto &read : Point::preferred_initial[sector_number]) {
                auto l = level(read);
                l.first = l.first + 1;
                l.second = l.second + 1;
                input_levels.insert(l);
            }
        }

        if (!Common::silent) {
            cout << "Thread " << thread_number << " requested: ";
            for (const auto &current_level : real_input_levels) {
                cout << "(" << current_level.first << "," << current_level.second << ") ";
            }
            cout << endl;
        }

        // now checking for a new LBASIS
        auto litr = Common::lbases.find(sector_number);

        if (litr != Common::lbases.end()) {
            if (!Common::silent) {
                cout << "L-basis found." << endl;
            }
#ifndef PRIME
            if (fuel::getLibrary() == "symbolica") {
#endif
                if (Common::send_to_parent) {
                    fuel::initialize(Common::variables, 1, Common::silent, Common::prime);
                }
#ifdef PRIME
                fuel::switchToConventional();
#endif
                for (const auto &option : Common::fuelOptions) {
                    fuel::setOption(option);
                }
#ifndef PRIME
            }
#endif
            if (fuel::getLibrary() == "symbolica") {
                fuel::setOption("rational_input");
            }

            auto lbasis = litr->second;
            for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                Point p = *ivpl_counter;
                if (!p_is_empty(p)) {
                    continue;
                }
                FastPoint y = FastPoint(p);

                vector<pair<Point, COEFF>> mon;
                bool is_reduced = try_reduce_with_lbasis(lbasis, y, p, mon);
                if (is_reduced) {
                    p_set(p, mon, false);
                    for (unsigned int j = 0; j != mon.size(); ++j) {
                        if (p.SectorNumber() != mon[j].first.SectorNumber()) {
                            set_needed_lower.insert(mon[j].first);
                        }
                        if ((mon[j].first != p) && (mon[j].first.SectorNumber() == sector_number)) {
                            ivpl.insert(ivpl_counter, mon[j].first);
                        }
                    }
                } else {
                    make_master(p);
                }
            }
#ifndef PRIME
            if (fuel::getLibrary() == "symbolica") {
#endif
                if (Common::send_to_parent) {
                    fuel::close();
                }
#ifndef PRIME
            }
#endif
            if (fuel::getLibrary() == "symbolica") {
                if (!Common::send_to_parent) {
                    fuel::setOption("rational_input");
                }
            }
            finish_sector(set_needed_lower, sector_number, nullptr);
            return;
        }

        // should not we change ivpl to FastPoint ???
        auto ditr = Point::dbases.find(sector_number);
        if (ditr != Point::dbases.end()) {
            pair<vector<t_index>, vector<pair<vector<pair<COEFF, FastPoint>>, t_index>>> dbasis = ditr->second;
            if (!Common::silent) {
                cout << "L-symmetry found." << endl;
            }
            for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                Point p = *ivpl_counter;
                if (!p_is_empty(p))
                    continue;
                FastPoint y = FastPoint(p);

                vector<pair<Point, COEFF>> mon;
                try_symmetries_with_lbasis(dbasis, y, p, mon);

                p_set(p, mon, false);
                for (unsigned int j = 0; j != mon.size(); ++j) {
                    if (p.SectorNumber() != mon[j].first.SectorNumber()) {
                        set_needed_lower.insert(mon[j].first);
                    }
                    if ((mon[j].first != p) && (mon[j].first.SectorNumber() == sector_number)) {
                        ivpl.insert(ivpl_counter, mon[j].first);
                    }
                }
            } // writing symmetries done
            finish_sector(set_needed_lower, sector_number, nullptr);
            return;
        }

        // ok, back to Laporta
        set<pair<unsigned int, unsigned int>, LevelSmaller> levels;
        for (const auto &input_level : input_levels) {
            auto here_levels = under_levels(input_level.first, input_level.second);
            for (const auto &current_level : here_levels) {
                char buf[128];
                snprintf(buf, sizeof(buf), "$USED_%d_%d", current_level.first, current_level.second);
                size_t size;
                char *res = Common::points[sector_number]->get(buf, strlen(buf), &size);
                if (res == nullptr) {
                    levels.insert(current_level);
                } else {
                    delete[] res;
                }
            }
        }

        if (levels.empty()) {
            if (!Common::silent) {
                cout << "No levels" << endl;
            }
            finish_sector(set_needed_lower, sector_number, nullptr);
            return;
        }

        FastPoint p_fast(Corner);
        SECTOR SectorFast = p_fast.SectorFast();

        auto ibps = Point::ibps;
        improve_ibps(ibps, SectorFast);

        if (Common::lthreads_number > 1)
            kyotocabinet::CacheDB::parallel_access = true;

        for (unsigned int i = 0; i != Common::lthreads_number; ++i) {
            level_worker[i] = thread(reduce_in_level, Corner, ibps, i);
        }

        auto itr = levels.begin();

        bool marked_lower_levels = false;

        for (unsigned int current_sum = 2; (itr != levels.end()); ++current_sum) {
            set<pair<unsigned int, unsigned int>> current_levels;
            while ((itr != levels.end()) && (((*itr).first) + ((*itr).second) <= current_sum)) {
                current_levels.insert(*itr);
                ++itr;
            }
            if (current_levels.empty()) {
                continue;
            }

            // time to check if database reopen is needed
            uint64_t entries = Common::points[sector_number]->count();
            if (entries > (1llu << Common::buckets[sector_number])) {
                Common::buckets[sector_number]++;
                reopen_database(sector_number);
            }

            if (!Common::silent) {
                cout << "Thread " << thread_number << " (sector " << sector_number << "): ";
                for (const auto &current_level : current_levels) {
                    cout << "(" << current_level.first << "," << current_level.second << ") ";
                }
                cout << endl;
            }

            auto start_time = chrono::steady_clock::now();

            int symmetries = 0;
            if (Common::pos_pref) {
                for (const auto &current_level : current_levels) {
                    if (Common::pos_pref > 0) {
                        if ((current_level.first <= static_cast<unsigned int>(abs(Common::pos_pref))) &&
                            (current_level.second == 1)) {
                            symmetries +=
                                write_symmetries(Corner, current_level.first, current_level.second, std::nullopt);
                        }
                    } else {
                        if ((current_level.first == 1) &&
                            (current_level.second <= static_cast<unsigned int>(abs(Common::pos_pref)))) {
                            symmetries +=
                                write_symmetries(Corner, current_level.first, current_level.second, std::nullopt);
                        }
                    }
                }
            }
            if (symmetries != 0) {
                if (!Common::silent)
                    cout << "Thread " << thread_number << ", sector " << sector_number << ": wrote " << symmetries
                         << " symmetries." << endl;
            }

            // finished writing symmetries --- directly to database

            eqs_number_sector_level = 0;
            used_number_sector_level = 0;

            {
                lock_guard<mutex> guard(level_mutex); // we will be putting tasks
                for (auto level_itr = current_levels.rbegin(); level_itr != current_levels.rend(); ++level_itr) {
                    level_tasks.push_back(*level_itr);
                    ++level_tasks_count;
                }
            }
            level_cond.notify_all(); // level threads can start

            {
                unique_lock<mutex> guard(level_mutex);
                level_done_cond.wait(
                    guard,
                    []() {
                        return level_tasks_count == 0;
                    }
                );
                // waiting for all work to be done
            }

            auto stop_time = chrono::steady_clock::now();

            if (!Common::silent) {
                cout << "Thread " << thread_number << " (sector " << sector_number << "): ";
                cout << "Equations: " << eqs_number_sector_level << ", ";
                cout << "used: " << used_number_sector_level << ", ";
                cout << "reduction time: "
                     << chrono::duration_cast<chrono::duration<float>>(stop_time - start_time).count() << endl;
            }

            eqs_number_sector_total += eqs_number_sector_level;
            used_number_sector_total += used_number_sector_level;

            bool good_mark = true;
            for (const auto &current_level : current_levels) {
                char buf[128];
                snprintf(buf, sizeof(buf), "$USED_%d_%d", current_level.first, current_level.second);
                Common::points[sector_number]->set(buf, strlen(buf), "True", 4);
                unsigned int local_pos_pref = 0;
                if (Common::pos_pref > 0) {
                    local_pos_pref = Common::pos_pref;
                }
                if ((!marked_lower_levels) && current_level.first < local_pos_pref &&
                    (current_level != *levels.rbegin())) {
                    // do not mark untill reaching pos_pref or last element
                    // there was a condition !Point::preferred[sector_number].empty(), but
                    // it was always true since they were always added may be we wanted
                    // preferred_initial?
                    mark_master_integrals(Corner, current_level.first, current_level.second, first_pass, true);
                } else if ((!marked_lower_levels) &&
                           ((local_pos_pref == current_level.first) || (current_level == *levels.rbegin()))) {
                    for (const auto &lpair : levels) {
                        // marking all untill current
                        if (!good_mark)
                            break;
                        if ((lpair.first < local_pos_pref) || (lpair == current_level)) {
                            good_mark = mark_master_integrals(Corner, lpair.first, lpair.second, first_pass, false);
                        }
                        if (lpair == current_level)
                            break;
                    }
                    if (good_mark) {
                        marked_lower_levels = true;
                    }
                } else {
                    good_mark =
                        mark_master_integrals(Corner, current_level.first, current_level.second, first_pass, false);
                }
                if (!good_mark) {
                    break;
                }
            }
            if (!good_mark) {
                break;
            }
            ivpl = needed_in_this_sector;
            bool done = true;
            for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                Point p = *ivpl_counter;
                vector<Point> monoms = p_get_monoms(p);
                if (!monoms.empty()) {
                    for (const auto &monom : monoms) {
                        if (monom.SectorNumber() == sector_number) {
                            ivpl.insert(ivpl_counter, monom);
                        }
                    }
                } else {
                    done = false;
                    break;
                }
            }

            if (done) {
                // we can stop the level queues here
                level_mutex.lock();
                level_stop = true;
                level_cond.notify_all(); // signal level threads to get them out of waiting
                level_mutex.unlock();
                for (unsigned int i = 0; i != Common::lthreads_number; ++i) {
                    level_worker[i].join();
                }

                ivpl = needed_in_this_sector;
                for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                    Point p = *ivpl_counter;
                    vector<Point> monoms = p_get_monoms(p);
                    if (!monoms.empty()) {
                        for (const auto &monom : monoms) {
                            if (monom.SectorNumber() == sector_number) {
                                ivpl.insert(ivpl_counter, monom);
                            }
                            if (p.SectorNumber() != monom.SectorNumber()) {
                                set_needed_lower.insert(monom);
                            }
                        }
                    } else {
                        make_master(p);
                    }
                }
                finish_sector(set_needed_lower, sector_number, &ivpl);
                return;
            }
        }

        kyotocabinet::CacheDB::parallel_access = false;

        if (!Common::silent) {
            cout << "Thread " << thread_number << ": ";
            cout << "FAILED TO RESOLVE ALL INTEGRALS, INCREASING LEVELS." << endl;
        }

        ivpl = needed_in_this_sector;

        for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
            Point p = *ivpl_counter;
            vector<Point> monoms = p_get_monoms(p);
            if (!monoms.empty()) {
                for (const auto &monom : monoms) {
                    if (monom.SectorNumber() == sector_number) {
                        ivpl.insert(ivpl_counter, monom);
                    }
                }
            } else {
                needed_in_this_sector.insert(p);
                if (!first_pass) {
                    cout << "Adding " << p << endl;
                }
            }
        }

        // we can stop the level queues here
        level_stop = true;
        level_cond.notify_all(); // signal level threads to get them out of waiting
        for (unsigned int i = 0; i != Common::lthreads_number; ++i) {
            level_worker[i].join();
        }
        level_stop = false;
        first_pass = false;
    }
    finish_sector(set_needed_lower, sector_number, nullptr);
}

void equation_generator_thread(const char *lhs, const char *hint_contents, const size_t max_len,
                               const vector<ibp_type> &ibps, SECTOR SectorFast, list<Equation> &equation_queue,
                               mutex &equation_mutex, condition_variable &equation_prepared,
                               condition_variable &equation_used, bool *time_to_stop) {

    while (true) {
        const char *pos = lhs;
        if (*pos != '{') {
            cout << "Wrong line start in hint" << endl;
            cout << string(hint_contents) << endl;
            abort();
        }
        ++pos;
        if (*pos != '{') {
            cout << "Wrong line start in hint" << endl;
            cout << string(hint_contents) << endl;
            abort();
        }
        ++pos;
        FastPoint p;
        int number;
        int i = 0;
        while (true) {
            int move = s2i(pos, number);
            p.buf[i] = number;
            pos += move;
            if (*pos == '}') {
                ++pos;
                break;
            }
            ++pos; // parsing the comma
            ++i;
        }
        if (*pos != ',') {
            cout << "Wrong line middle in hint;";
            abort();
        }
        ++pos;
        int move = s2i(pos, number);
        pos += move;
        if (*pos != '}') {
            cout << "Wrong line end in hint;";
            abort();
        }
        ++pos;

        unique_lock<mutex> guard(equation_mutex);
        equation_used.wait(guard, 
            [&equation_queue]() {
                return (equation_queue.size() < 16); 
            }
        );
        guard.unlock();

        Equation eq(max_len);
        generate_equation(eq, ibps[number], p, SectorFast);
        guard.lock();
        equation_queue.push_back(std::move(eq));
        guard.unlock();
        equation_prepared.notify_one();

        if (*pos == '}') {
            unique_lock<mutex> guard(equation_mutex);
            *time_to_stop = true;
            equation_prepared.notify_one();
            break; // final closing bracket
        }

        while (*pos != '\n')
            ++pos;

        lhs = ++pos;
    }
}

void reduce_in_level(Point Corner, vector<ibp_type> ibps, unsigned int thread_number) {
    sector_count_t sector_number = Corner.SectorNumber();

    vector<t_index> v = Corner.GetVector();
    FastPoint p_fast(Corner);
    SECTOR SectorFast = p_fast.SectorFast();

    while (true) {
        // waiting for tasks
        unique_lock<mutex> guard(level_mutex); // we lock the mutex to access the
                                               // std list and to start waiting
        level_cond.wait(guard, 
            []() {
                return level_stop || !level_tasks.empty();
            }
        );
        if (level_stop) {
            return; // no more levels in this sector, thread returns, mutex unlocked
        }

        set<pair<unsigned int, unsigned int>> current_levels;
        current_levels.insert(level_tasks.front()); // we take the first task from the queue
        level_tasks.pop_front();                    // and pop it from the queue

        guard.unlock(); // let other threads have jobs

        stringstream out;
        bool hint_exists = false;
        char hint_name_buf[256];

        bool hint_local = Common::hint;
        struct stat st;

        char *hint_contents;
        const char *lhs, *rhs;
        int fd;

        while (true) { // normally there is only one pass, two in case hint that did
                       // not properly help

            // we are expecting length 1 in current_levels now, keeping multiple for
            // easy checks
            if (hint_local) {

                snprintf(hint_name_buf, 256, "%s-%d-{%u,%u}.m", Common::hint_path.c_str(), int(sector_number),
                         current_levels.begin()->first, current_levels.begin()->second);
                fd = open(hint_name_buf, O_RDONLY);

                if (fd > 0) {
                    fstat(fd, &st);
                    hint_contents = static_cast<char *>(mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0));

                    hint_exists = true;
                    lhs = hint_contents;
                    rhs = strchr(lhs, '\n');
                    if (strncmp(lhs, "{", rhs - lhs - 1)) {
                        cout << "Incorrect hint, probably broken file" << endl << hint_name_buf << endl;
                        abort();
                    }
                } else {
                    // we print it even if silent mode, if multiple jobs are creating same
                    // hint, this is a mess, and we should know it
                    cout << "Creating hint file " << string(hint_name_buf) << endl;
                    // iout.open(buf, fstream::out); //moving to stringstream
                    out << "{" << endl;
                }
            }

            unsigned int eqs_number;
            if (hint_local && hint_exists) {
                unsigned int used_number = 0;
                unsigned int eqs_number = 0;
                lhs = ++rhs;

                size_t max_len = 0;
                for (const auto &ibp : ibps) {
                    if (ibp.size() > max_len)
                        max_len = ibp.size();
                }

                list<Equation> equation_queue;
                mutex equation_mutex;
                condition_variable equation_prepared;
                condition_variable equation_used;
                bool time_to_stop = false;

                thread equation_generator(equation_generator_thread, lhs, hint_contents, max_len, std::cref(ibps),
                                          SectorFast, std::ref(equation_queue), std::ref(equation_mutex),
                                          std::ref(equation_prepared), std::ref(equation_used), &time_to_stop);

                while (true) {
                    unique_lock<mutex> guard(equation_mutex);
                    equation_prepared.wait(guard, [&equation_queue, &time_to_stop]() {
                        return (time_to_stop || !equation_queue.empty());
                    });
                    if (equation_queue.empty())
                        break;
                    Equation eq(std::move(equation_queue.front()));
                    equation_queue.pop_front();
                    guard.unlock();
                    equation_used.notify_one();

                    ++eqs_number; // count it anyway, it should be used

                    if (!eq.terms.empty()) {
#ifndef PRIME
                        normalize(eq.terms, thread_number);
                        if (!eq.terms.empty()) {
#endif
                            bool used = work_with_equation(eq, thread_number, sector_number);
                            if (used) {
                                ++used_number;
                            }
#ifndef PRIME
                        }
#endif
                    }
                }

                equation_generator.join();

                munmap(hint_contents, st.st_size);
                close(fd);

                used_number_sector_level += used_number;
                if (eqs_number != used_number) {
                    cout << "Not all hinted equations were used, suspecting extra "
                            "irreducibles, rerunning {"
                         << current_levels.begin()->first << "," << current_levels.begin()->second << "} for sector "
                         << sector_number << " without hint" << endl;
                    hint_local = false;
                } else {
                    eqs_number_sector_level += eqs_number;
                    break;
                }

            } else {
                // preparing ibp lists
                vector<FastPoint> IBPdegree;
                vector<FastPoint> IBPdegreeFull;

                for (const auto &ibp : ibps) {
                    if (ibp.size() != 0) {
                        // we fill IBPdegree, sscc and mm based of ibps
                        FastPoint p;
                        FastPoint ah = ibp[0].second;
                        SECTOR bit = 1u << (Common::dimension - 1);
                        for (unsigned int i = 0; i < Common::dimension; ++i, bit >>= 1)
                            if (SectorFast & bit) {
                                p.buf[i] = max(ah.buf[i], t_index(0));
                            } else {
                                p.buf[i] = max(-ah.buf[i], 0);
                            }
                        IBPdegreeFull.emplace_back(ah);
                        IBPdegree.emplace_back(p);
                    }
                }

                vector<pair<Point, pair<FastPoint, unsigned short>>> ibps_vector;
                eqs_number = sort_ibps(Corner, current_levels, ibps_vector, IBPdegree, IBPdegreeFull);

                unsigned int used_number = 0;
                int print_counter = 0;

                for (vector<pair<Point, pair<FastPoint, unsigned short>>>::const_iterator ibps_itr =
                         ibps_vector.begin();
                     ibps_itr != ibps_vector.end(); ++ibps_itr) {
                    if (Common::print_step != 0) {
                        ++print_counter;
                        if (print_counter % Common::print_step == 0) {
                            if (!Common::silent) {
                                cout << "Sector " << sector_number << ": " << print_counter << "/" << eqs_number
                                     << endl;
                            }
                        }
                    }
                    auto itr2 = ibps_itr;
                    int k;
                    int write;

                    // moving until the highest member is changed
                    int dist = 0;
                    write = 0;
                    while ((itr2 != ibps_vector.end()) && (itr2->first == ibps_itr->first)) {
                        ++itr2;
                        ++dist;
                    }

                    vector<Equation> eqs;
                    eqs.reserve(dist); // maximal number having same highest member

                    size_t max_len = 0;
                    for (const auto &ibp : ibps) {
                        if (ibp.size() > max_len)
                            max_len = ibp.size();
                    }

                    for (k = 0; k != dist; ++k) {
                        unsigned short i = (ibps_itr + k)->second.second;
                        const FastPoint &p = (ibps_itr + k)->second.first;
                        Equation eq(max_len);
                        generate_equation(eq, ibps[i], p, SectorFast);
#ifndef PRIME
                        normalize(eq.terms, thread_number);
#endif
                        if (eq.terms.empty()) {
                            --eqs_number;
                        } else {
                            eqs.push_back(std::move(eq));
                            eqs[write++].source = (ibps_itr + k)->second;
                        }
                    }

                    // sorting those equations with same highest member
                    // equations with smaller higher member should be first, then length
                    // is compared
                    sort(eqs.begin(), eqs.end(), [](const Equation &lhs, const Equation &rhs) -> bool {
                        int i = lhs.terms.size();
                        int j = rhs.terms.size();
                        while ((i != 0) && (j != 0)) {
                            const Point &p1 = lhs.terms[i - 1].first;
                            const Point &p2 = rhs.terms[j - 1].first;
                            if ((p1) < (p2))
                                return true;
                            if ((p2) < (p1))
                                return false;
                            --i;
                            --j;
                        }
                        return (j != 0);
                    });

                    for (k = 0; k != write; ++k) { // cycle of same starting point
                        bool used = work_with_equation(eqs[k], thread_number, sector_number);
                        if (used) {
                            if (hint_local) {                            // hint does not exist in this branch
                                unsigned short i = eqs[k].source.second; // that's the Equation number
                                FastPoint &p = eqs[k].source.first;     // that's the substitution point
                                if (used_number)
                                    out << "," << endl;
                                out << "{{";
                                for (unsigned j = 0; j + 1 != Common::dimension; ++j) {
                                    out << int(p.buf[j]) << ",";
                                }
                                out << int(p.buf[Common::dimension - 1]) << "}" << "," << i << "}";
                            }
                            ++used_number;
                        }
                    }
                    ibps_itr = itr2;
                    --ibps_itr;
                } // Equation cycle

                if (hint_local) {
                    out << "}" << endl;
                    fstream fout;
                    fout.open(hint_name_buf, fstream::out);
                    fout << out.rdbuf();
                    fout.close();
                }

                used_number_sector_level += used_number;
                eqs_number_sector_level += eqs_number;
                break; // out of the true cycle
            }

        } // while (true) cycle that is run once or twice

        {
            lock_guard<mutex> guard(level_mutex);
            --level_tasks_count;
        }

        level_done_cond.notify_one(); // level worker finished, need to inform
    }
}

bool work_with_equation(const Equation &eq, unsigned short thread_number, sector_count_t sector_number) {
#ifdef PRIME
    bool used = false;
    list<pair<Point, COEFF>> result;
    for (const auto &term : eq.terms) {
        result.push_back(term);
    }

    list<list<pair<Point, COEFF>>> to_substitute;

    for (auto itr = result.rbegin(); itr != result.rend(); ++itr) {
        const Point &p = itr->first;
        if ((!Common::one_pass && ((p.SectorNumber() < sector_number) || (p.IsVirtual()))) || (p.SectorNumber() == 1)) {
            break; // no need to touch lower
        } else {
            list<pair<Point, COEFF>> terms2l;
            p_get(p, terms2l, sector_number);
            if (terms2l.empty()) {
                if (p.SectorNumber() < sector_number) {
                    // it's a lower sector Point that has no table, it should be a zero
                    result.erase(next(itr--).base());
                } else {
                    continue;
                }
            } else {
                COEFF zero(0);
                COEFF c = (zero - itr->second) / terms2l.back().second;
                add_to(result, terms2l, c, true); // last term still stays here
                result.erase(next(itr--).base());
                to_substitute.emplace_front(std::move(terms2l));
                if (result.empty())
                    break;
            }
        }
    }

    // let's write the table for the current Equation if needed
    if (!result.empty()) {
        const Point &p = result.rbegin()->first;
        if ((p.SectorNumber() == sector_number) && (!p.IsVirtual())) {
            if (Common::one_pass)
                p_set(result.back().first, result, false, sector_number);
            else
                split(result, sector_number);
            used = true;
        }
    }

    // now substituting back
    for (auto itrTo = to_substitute.begin(); itrTo != to_substitute.end(); ++itrTo) {
        bool changed = false;
        auto itrTerm = itrTo->begin();
        for (auto itrFrom = to_substitute.cbegin(); itrFrom != itrTo; ++itrFrom) {
            const Point &p = itrFrom->rbegin()->first;

            for (; itrTerm != itrTo->end(); ++itrTerm) {
                if (p == itrTerm->first) {
                    COEFF zero(0);
                    COEFF c = (zero - itrTerm->second) / itrFrom->back().second;
                    ++itrTerm; // we move it before, or it will be invalidated
                    add_to(*itrTo, *itrFrom, c, false);
                    changed = true;
                    break;
                } else if (p < itrTerm->first) {
                    break; // this relation does not go there
                }
            }
        }
        // top Point cannot be changed, so it's safe to split
        if (changed) {
            if (Common::one_pass) {
                p_set(itrTo->back().first, *itrTo, false, sector_number);
            } else {
                auto new_start = split(*itrTo, sector_number);
                while (itrTo->begin() != new_start)
                    itrTo->pop_front();
            }
        }
    }
    return used;

#else
    map<Point, vector<pair<Point, COEFF>>, std::greater<Point>> to_test;
    for (unsigned int i = 0; i != eq.terms.size(); ++i) {
        vector<pair<Point, COEFF>> v;
        to_test.emplace(eq.terms[i].first, v);
    }
    bool has_high = express_and_pass_back(to_test, sector_number, thread_number);

    if (!has_high) {
        return false;
    }

    vector<pair<Point, COEFF>> terms;
    terms.reserve(eq.terms.size());
    for (unsigned int i = 0; i != eq.terms.size(); ++i) {
        COEFF c;
        c.s = eq.terms[i].second.s;
        terms.emplace_back(eq.terms[i].first, c);
    }

    apply_table_poly(terms, true, false, sector_number, thread_number);
    return true;
#endif
}

void perform_substitution(unsigned short thread_number, sector_count_t sector_number) {
    // if((sector_number == 26) && (Common::send_to_parent)) abort();
    auto start_timeP = chrono::steady_clock::now();

    if (!Common::silent)
        cout << "THREAD " << thread_number << ": Substituting in {" << Common::global_pn << ",";
    print_vector(Common::ssectors[sector_number]);
    if (!Common::silent)
        cout << "} " << sector_number << endl;

    set<Point, std::greater<Point>> needed;
    open_database_and_scan(
        sector_number,
        [sector_number](const char *kbuf, size_t ksiz, [[maybe_unused]] const char *vbuf,
                        [[maybe_unused]] size_t vsiz) {
            return (
                    (ksiz == sizeof(Point)) &&
                    (reinterpret_cast<const Point *>(kbuf)->SectorNumber() == sector_number)
                );
        },
        needed);

    if (Common::wrap_databases) {
        remove((Common::path + int2string(sector_number) + ".tmp").c_str());
    }

#ifdef PRIME
    // backward prime substitution after a forward modular run
    if (Common::stages == t_stages::backward) {
        size_t size;
        char *active_variables_before_char = Common::points[sector_number]->get("act_var", 7, &size);
        set<string> active_variables_before;
        char *pos = active_variables_before_char;
        while (*pos != '\0') {
            char *pos2 = pos;
            while (*pos2 != '|')
                ++pos2;
            active_variables_before.insert(string(pos, pos2 - pos));
            pos = pos2 + 1;
        }
        delete[] (active_variables_before_char);
        map<string, std::vector<std::string>> needed_replacements;
        for (const auto &var : active_variables_before) {
            auto itr = Common::variable_replacements.find(var);
            if (itr == Common::variable_replacements.end()) {
                cerr << "Var missing a replacement: " << var << endl;
                abort();
            } else {
                needed_replacements.insert(std::make_pair(var, itr->second));
            }
        }

        class VisitorImpl : public kyotocabinet::DB::Visitor {
          private:
            const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz, size_t *sp) {
                if (ksiz < sizeof(Point)) {
                    return NOP;
                }
                // we perform substitutions from poly storage to prime storage
                Point p = *reinterpret_cast<const Point *>(kbuf);
                if (p.SectorNumber() != sector_number) {
                    // it's from a lower sector, so already a prime variant
                    return NOP;
                }

                const unsigned int len = (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & ~NEEDED_BIT);
                bool needed_higher = (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & NEEDED_BIT);
                size_t n = len;
#ifdef MPRIME
                size_t coeffs_size = MPRIME * n * sizeof(unsigned long long);
#else
                size_t coeffs_size = n * sizeof(unsigned long long);
#endif
                size_t points_size = n * sizeof(Point);
                size_t buf_size = points_size + coeffs_size;
                if (needed_higher) {
                    ++buf_size;
                }

                if ((buf_size > max_buf_size) || (!buf)) {
                    if (buf) {
                        free(buf);
                    }
                    if (buf_size > max_buf_size) {
                        max_buf_size = 2 * buf_size;
                    }
                    buf = static_cast<char *>(malloc(max_buf_size));
                    if (!buf) {
                        cout << "Cannot malloc in resubstitute" << endl;
                        abort();
                    }
                }
                if (needed_higher) {
                    buf[points_size + coeffs_size] = 1;
                }

                memcpy(buf, vbuf, len * sizeof(Point)); // copying points
                const char *pos = vbuf + len * sizeof(Point);
                char *pos_write = buf + points_size; // preparing a string of coeffs
                for (unsigned int j = 0; j != len; ++j) {
                    const char *end = pos;
                    while (*end != '|')
                        ++end;
                    string s = string(pos, end - pos);
                    // here we should fill n based on substitutions
                    pos = end;
                    ++pos;
                    if (Common::stages == t_stages::backward) {
                        calc_wrapper(s, 0); // to get in to the conventional format
                    }
#ifdef MPRIME
                    std::string ss = s;
                    for (size_t i = 0; i != MPRIME; ++i) {
                        for (const auto &variable_replacement : needed_replacements) {
                            ss =
                                replace_all(ss, variable_replacement.first, "(" + variable_replacement.second[i] + ")");
                        }
                        calc_wrapper(ss, 0);
                        fuel::simplify(ss, 0, true);
                        unsigned long long coeff_substituted = string_fraction_to_modular(ss);
                        *reinterpret_cast<unsigned long long *>(pos_write) = coeff_substituted;
                        pos_write += sizeof(unsigned long long);
                    }
#else
                    for (const auto &variable_replacement : needed_replacements) {
                        s = replace_all(s, variable_replacement.first, "(" + variable_replacement.second[0] + ")");
                    }
                    calc_wrapper(s, 0);
                    fuel::simplify(s, 0, true);
                    unsigned long long coeff_substituted = string_fraction_to_modular(s);
                    *reinterpret_cast<unsigned long long *>(pos_write) = coeff_substituted;
                    pos_write += sizeof(unsigned long long);
#endif
                }

                *sp = buf_size;
                return buf;
            }
            const char *visit_empty(const char *kbuf, size_t ksiz, size_t *sp) {
                cout << "Missing entry at iteration " << endl;
                abort();
                return NOP;
            }

          public:
            sector_count_t sector_number = {};
            char *buf = nullptr;
            size_t max_buf_size = 1024;
            map<string, std::vector<std::string>> needed_replacements;
        } substitution_visitor;
        substitution_visitor.sector_number = sector_number;
        substitution_visitor.needed_replacements = needed_replacements;
        substitution_visitor.buf = nullptr;
        if (!Common::points[sector_number]->iterate(&substitution_visitor, true)) {
            cout << "Cannot iterate substitution visitor " << endl;
            abort();
        }
        if (substitution_visitor.buf) {
            free(substitution_visitor.buf);
        }
    }
#endif
    pass_back(needed, sector_number);
    auto stop_timeP = chrono::steady_clock::now();
    if (!Common::silent) {
        cout << "Thread (sector " << sector_number << ")";
        cout << ": substituted " << needed.size() << " integrals ("
             << chrono::duration_cast<chrono::duration<float>>(stop_timeP - start_timeP).count() << " seconds)."
             << endl;
    }

    start_timeP = stop_timeP;
    process_mem_usage(true);
    if (!Common::silent)
        cout << "Memory by thread " << thread_number << " (sector " << sector_number << ")" << " on substitutions: ";
    print_memory(max_vsize, 0);
    if (!Common::silent)
        cout << " | ";
    print_memory(max_rss, 1);
    if (!Common::silent)
        cout << endl;

    if (!Common::one_pass) {
        Common::points[sector_number]->set("mem_vsi", 7, reinterpret_cast<const char *>(&max_vsize), 8);
        Common::points[sector_number]->set("mem_rss", 7, reinterpret_cast<const char *>(&max_rss), 8);
    }

    size_t records2 = Common::points[sector_number]->count();

    size_t ignored = close_database(
        sector_number, true, [sector_number](const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz) -> bool {
            if (Common::plan_file != "") {
                return true;
            }
#ifdef PRIME
#ifdef MPRIME
            return ((ksiz < sizeof(Point)) || ((vsiz % (sizeof(Point) + MPRIME * sizeof(unsigned long long))) &&
                                               reinterpret_cast<const Point *>(kbuf)->SectorNumber() == sector_number));
#else
        return ((ksiz < sizeof(Point)) ||
                ((vsiz % (sizeof(Point) + sizeof(unsigned long long))) &&
                 reinterpret_cast<const Point *>(kbuf)->SectorNumber() ==
                     sector_number));
#endif
#else
        return ((ksiz < sizeof(Point)) ||
                ((*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) &
                  NEEDED_BIT) &&
                 reinterpret_cast<const Point *>(kbuf)->SectorNumber() ==
                     sector_number));
#endif
        });

    if (Common::cpath != "") {
        if (Common::cpath_on_substitutions) {
            store_database(sector_number);
        }
    }
    stop_timeP = chrono::steady_clock::now();
    if (!Common::silent) {
        cout << "Thread (sector " << sector_number << ")";
        cout << ": saved " << records2 - ignored << " entries to disk ("
             << chrono::duration_cast<chrono::duration<float>>(stop_timeP - start_timeP).count() << " seconds)."
             << endl;
    }
}

void watch_child(int *pipe_from_child, int *pipe_to_child, int sector_number, int thread_ready, pid_t pid) {
    int status;
    close(pipe_from_child[1]);
    close(pipe_to_child[0]);
    FILE *stream_from_child = fdopen(pipe_from_child[0], "r");
    if (stream_from_child == nullptr) {
        cout << "Could not open stream from child" << endl;
        abort();
    }
    FILE *stream_to_child = fdopen(pipe_to_child[1], "w");
    if (stream_to_child == nullptr) {
        cout << "Could not open stream to child" << endl;
        abort();
    }

    string in;
    size_t buf_size = 3;
    char *buf = static_cast<char *>(malloc(buf_size));
    if (!buf) {
        cout << "Cannot malloc in watch_child" << endl;
        abort();
    }

    while (true) {
        read_from_stream(&buf, &buf_size, stream_from_child);
        if (feof(stream_from_child))
            break;
        int len;
        s2i(buf, len);
        list<pair<int, pair<Point, string>>> to_submit;

        // creating list to submit
        for (int i = 0; i != len; ++i) {
            read_from_stream(&buf, &buf_size, stream_from_child);
            buf[strlen(buf) - 1] = '\0';
            string ss = (buf + sizeof(Point) * 2);
            to_submit.emplace_back(thread_ready, pair<Point, string>(Point(buf), ss));
        }

        // submitting all
        {
            lock_guard<mutex> guard(Equation::f_submit_mutex[thread_ready % Common::f_queues]);
            for (const auto &itr : to_submit) {
                Equation::f_jobs[(thread_ready % Common::f_queues)].push_back(itr);
            }
        }

        // indicate the f workers they can start
        Equation::f_submit_cond[(thread_ready % Common::f_queues)].notify_all();

        // waiting for results and sending them back
        while (len != 0) {
            unique_lock<mutex> guard(Equation::f_receive_mutex[thread_ready]);
            Equation::f_receive_cond[thread_ready].wait(
                guard, [thread_ready]() { return !Equation::f_result[thread_ready].empty(); });
            pair<Point, string> res = *(Equation::f_result[thread_ready].begin());
            Equation::f_result[thread_ready].pop_front();
            guard.unlock();

            char rbuf[2 * sizeof(Point) + 1];
            rbuf[2 * sizeof(Point)] = '\0';
            res.first.SafeString(rbuf);

            fputs(rbuf, stream_to_child);
            fputs(res.second.c_str(), stream_to_child);
            fputs("\n", stream_to_child);
            fflush(stream_to_child);
            --len;
        }
    }
    free(buf);

    pid_t return_value = waitpid(pid, &status, 0);
    if ((return_value == -1) || (!WIFEXITED(status)) || (WEXITSTATUS(status))) {
        cout << "Child " << sector_number << " exited abnormally" << endl << "Status: " << status << endl;
        cout << "Signaled is " << WIFSIGNALED(status) << endl;
        cout << "Signal is " << WTERMSIG(status) << endl;
        cout << "Exited is " << WIFEXITED(status) << endl;
        cout << "Stopped is " << WIFSTOPPED(status) << endl;
        cout << "Exit status is " << WEXITSTATUS(status) << endl;
        abort();
    }

    if (Common::wrap_databases) {
        database_to_file_or_back(abs(sector_number), true);
    }

    fclose(stream_from_child);
    fclose(stream_to_child);
}

/**
 * List of sectors done by remote workers.
 */
list<int> remote_done_sectors;

/**
 * Worker thread, can be either used for forward reduction or for substitution.
 * Forks and creates child process, maintaining connection between main program
 * and forked process.
 * @param thread_ready the thread number
 */
void worker_thread(unsigned short thread_ready) {
    int sector_number; // yes, sign needed here
    string pid_folder = "/" + to_string(getpid());
    while (true) {
        unique_lock<mutex> guard(worker_mutex); // we lock the mutex to work with the list
        worker_cond.wait(guard, []() {
            return worker_stop || !worker_tasks.empty();
        }); // we wait until there is some job without lock
        if (worker_stop) {
            break; // time to stop
        }
        sector_number = *(worker_tasks.begin()); // take the sector to work with
        worker_tasks.pop_front();                // remove it from the queue
        guard.unlock();                          // we unlock it. other threads can pick up jobs
        if (Common::wrap_databases) {
            database_to_file_or_back(abs(sector_number), false);
        }

        auto start_timeA = chrono::steady_clock::now();

        int pipe_from_child[2];
        int pipe_to_child[2];
        if (pipe(pipe_from_child) < 0) {
            perror("pipe");
            cout << "pipe" << endl;
            abort();
        }
        if (pipe(pipe_to_child) < 0) {
            perror("pipe");
            cout << "pipe" << endl;
            abort();
        }

        char par[32][256] = {{}};
        unsigned short count = 0;

#ifdef PRIME
#ifdef MPRIME
        strcpy(par[count], (Common::FIRE_folder + "FLAME7mp").c_str());
#else
        strcpy(par[count], (Common::FIRE_folder + "FLAME7p").c_str());
#endif
#else
        strcpy(par[count], (Common::FIRE_folder + "FLAME7").c_str());
#endif

        ++count;
        snprintf(par[count], sizeof(par[count]), "--config");
        ++count;
        strcpy(par[count], Common::config_file.c_str());
        ++count;

        if (Common::variables_set_from_command_line) {
            snprintf(par[count], sizeof(par[count]), "--variables");
            ++count;
            snprintf(par[count], sizeof(par[count]), "%s", Common::tables_prefix.c_str());
            ++count;
        }

        if (Common::large_variables) {
            snprintf(par[count], sizeof(par[count]), "--large_variables");
            ++count;
        }

        if (Common::no_positive_increase) {
            snprintf(par[count], sizeof(par[count]), "-N");
            ++count;
        }

        if (Common::split_masters) {
            snprintf(par[count], sizeof(par[count]), "--masters");
            ++count;
            snprintf(par[count], sizeof(par[count]), "%u-%u", Common::master_number_min, Common::master_number_max);
            ++count;
        }

        snprintf(par[count], sizeof(par[count]), "--sector");
        ++count;
        snprintf(par[count], sizeof(par[count]), "%d", sector_number);
        ++count;

        snprintf(par[count], sizeof(par[count]), "--database");
        ++count;
        snprintf(par[count], sizeof(par[count]), "%s", Common::path.c_str());
        ++count;

        if (Common::parallel_mode) {
            snprintf(par[count], sizeof(par[count]), "--parallel");
            ++count;
        }

        if (Common::silent) {
            snprintf(par[count], sizeof(par[count]), "--quiet");
            ++count;
        }

        if (Common::stages == t_stages::backward) {
            snprintf(par[count], sizeof(par[count]), "--backward");
            ++count;
        }

        if (Common::stages == t_stages::forward) {
            snprintf(par[count], sizeof(par[count]), "--forward");
            ++count;
        }

        if (Common::positive_indices_option != "") {
            snprintf(par[count], sizeof(par[count]), "--positive");
            ++count;
            snprintf(par[count], sizeof(par[count]), "%s", Common::positive_indices_option.c_str());
            ++count;
        }

        snprintf(par[count], sizeof(par[count]), "--calc");
        ++count;
        snprintf(par[count], sizeof(par[count]), "%s", fuel::getLibrary().c_str());
        ++count;

        if (Common::fuelOptionsString != "") {
            snprintf(par[count], sizeof(par[count]), "--calc_options");
            ++count;
            snprintf(par[count], sizeof(par[count]), "%s", Common::fuelOptionsString.c_str());
            ++count;
        }

        snprintf(par[count], sizeof(par[count]), "--thread");
        ++count;
        snprintf(par[count], sizeof(par[count]), "%d", thread_ready);
        ++count;

        if (Common::bucket_override) {
            snprintf(par[count], sizeof(par[count]), "--bucket");
            ++count;
            snprintf(par[count], sizeof(par[count]), "%d", Common::bucket_override);
            ++count;
        } else if (sector_number < 0) {
            snprintf(par[count], sizeof(par[count]), "--bucket");
            ++count;
            snprintf(par[count], sizeof(par[count]), "%d", Common::buckets[-sector_number]);
            ++count;
        }

        if (Common::receive_from_child) {
            snprintf(par[count], sizeof(par[count]), "--out");
            ++count;
            snprintf(par[count], sizeof(par[count]), "%d", pipe_from_child[1]);
            ++count;

            snprintf(par[count], sizeof(par[count]), "--in");
            ++count;
            snprintf(par[count], sizeof(par[count]), "%d", pipe_to_child[0]);
            ++count;
        }

        char *nargv[32];
        for (int i = 0; i != count; ++i) {
            nargv[i] = reinterpret_cast<char *>(par) + (256 * i);
        }

        nargv[count] = nullptr;

        pid_t pid = vfork();
        if (pid == -1) {
            cout << "Error on fork" << endl;
            abort();
        } else if (pid > 0) {
            watch_child(pipe_from_child, pipe_to_child, sector_number, thread_ready, pid);
        } else {
            // close(pipe_from_child[0]);
            // close(pipe_to_child[1]);

            int rc = execv(par[0], nargv);

            // we do not get out here normally
            printf("CHILD LAUNCH ERROR: rc = %d, errno = %d\n", rc, errno);
            perror("execve");
            abort();
        }

        auto stop_timeA = chrono::steady_clock::now();

        Common::thread_time += chrono::duration_cast<chrono::microseconds>(stop_timeA - start_timeA).count();

        {
            lock_guard<mutex> guard(worker_mutex);
            distributed_sectors--; // worker thread is done
        }
        worker_done_cond.notify_one(); // job is done
    }
}

/** @brief Estimate and print memory usage of child FLAME processes
 * @param vsi array virtual memory usage
 * @param rss array of resident size
 * @param count number sectors used
 * @param threads_number number of simultaneous threads
 */
void estimate_memory_usage(uint64_t *vsi, uint64_t *rss, const unsigned int count, const unsigned int threads_number) {
    if (!count)
        return;

    qsort(vsi, count, sizeof(uint64_t), [](const void *p1, const void *p2) -> int {
        auto i1 = *static_cast<const uint64_t *>(p1);
        auto i2 = *static_cast<const uint64_t *>(p2);
        if (i1 < i2)
            return -1;
        if (i1 > i2)
            return 1;
        return 0;
    });
    qsort(rss, count, sizeof(uint64_t), [](const void *p1, const void *p2) -> int {
        auto i1 = *static_cast<const uint64_t *>(p1);
        auto i2 = *static_cast<const uint64_t *>(p2);
        if (i1 < i2)
            return -1;
        if (i1 > i2)
            return 1;
        return 0;
    });

    uint64_t vsi_tot = 0;
    uint64_t rss_tot = 0;

    for (size_t i = ((count < threads_number) ? 0 : (count - threads_number)); i != count; ++i) {
        vsi_tot += vsi[i];
        rss_tot += rss[i];
    }

    process_mem_usage(true);
    if (!Common::silent)
        cout << "Memory by main thread (virtual|resident): ";
    print_memory(max_vsize, 0);
    if (!Common::silent)
        cout << " | ";
    print_memory(max_rss, 1);
    if (!Common::silent)
        cout << endl << "Thread memory usage estimation by top " << threads_number << " sectors (virtual|resident): ";

    print_memory(vsi_tot, 0);
    if (!Common::silent)
        cout << " | ";
    print_memory(rss_tot, 1);
    if (!Common::silent)
        cout << endl;

    if (max_vsize > max_vsi_main)
        max_vsi_main = max_vsize;
    if (max_rss > max_rss_main)
        max_rss_main = max_rss;
    if (vsi_tot > max_vsi_est)
        max_vsi_est = vsi_tot;
    if (rss_tot > max_rss_est)
        max_rss_est = rss_tot;
}

void change_number_of_threads(unsigned int old_number, unsigned int new_number) {

    if (new_number == old_number)
        return;
    if (new_number < old_number) {
        // stopping
        worker_stop = true;
        worker_cond.notify_all();
        for (unsigned int i = 0; i != old_number; ++i) {
            worker[i].join();
        }
        worker_stop = false;
        // starting
        for (unsigned int i = 0; i != new_number; ++i) {
            worker[i] = thread(worker_thread, i);
        }
    } else {
        for (unsigned int i = old_number; i != new_number; ++i) {
            worker[i] = thread(worker_thread, i);
        }
    }
}

void perform_reduction() {
    unsigned long long eqs_total{};
    unsigned long long eqs_used{};

    if (Common::cpath != "") {
        completed_in_storage_read();
    }

    for (unsigned int i = 0; i != Common::threads_number; ++i) {
        worker[i] = thread(worker_thread, i);
    }
    int last_level = Common::abs_max_level;

    auto start_time = chrono::steady_clock::now();

    unsigned long long total_substituted{}; // we will be collecting this number when going down,
                                            // since all left in a sector will be substituted

    if (Common::stages != t_stages::backward) {
        // forward reduction level by level
        while (last_level >= Common::abs_min_level && last_level >= Common::target_level) {
            int inlsectors = 1;
            while (inlsectors != -1) {
                bool inlsectorsbool = (inlsectors == 0);
                inlsectors--;
                auto start_level_time = chrono::steady_clock::now();

                // If we are using storage and the current level and inlsectors is already done, skip:
                if (Common::cpath != "") {
                    if (find(Common::completed_in_storage.begin(), Common::completed_in_storage.end(), make_pair(last_level, inlsectors+1))
                        != Common::completed_in_storage.end() ) {

                        if (!Common::silent) cout << "SKIPPING LEVEL " << last_level << "." << inlsectors + 1 << " : FOUND IN STORAGE" << endl;
                        continue;
                    }
                }

                // list of sectors of this level
                set<sector_count_t> sector_set_this_level;
                set<sector_count_t>::reverse_iterator sector_set_this_level_itr;
                for (sector_count_t sector_number = 2; sector_number <= Common::abs_max_sector; ++sector_number) {
                    vector<t_index> ssector = Common::ssectors[sector_number];

                    unsigned short current_level = static_cast<unsigned short>(
                        std::count_if(ssector.begin(), ssector.end(), [&](const t_index &elem) { return elem == 1; }));

                    if (!Common::sector_numbers_fast[sector_fast(ssector)])
                        continue;

                    if ((inlsectorsbool == in_lsectors(sector_number)) && (current_level == last_level) &&
                        database_exists(sector_number)) {
                        sector_set_this_level.insert(sector_number);
                    }
                }

                if (sector_set_this_level.empty())
                    continue;

                if (!Common::silent) {
                    cout << "STARTING LEVEL " << last_level << "." << inlsectors + 1 << endl;
                }
                // here we will be writing the integral requests into lower sector
                // databases
                map<sector_count_t, set<Point>> needed_lower;
                auto stop_level_time = start_level_time;

                uint64_t vsi[1024];
                uint64_t rss[1024];
                size_t count = 0;
                if (!Common::one_pass) {

                    unsigned int needed_number_of_threads = Common::threads_default_number;
                    if (inlsectors) {
                        auto pos = Common::threads_level_number.find(last_level);
                        if (pos != Common::threads_level_number.end())
                            needed_number_of_threads = pos->second;
                    }
                    if (needed_number_of_threads != Common::threads_number) {
                        if (!Common::silent)
                            cout << "CHANGING NUMBER OF THREADS TO " << needed_number_of_threads << endl;
                        change_number_of_threads(Common::threads_number, needed_number_of_threads);
                        Common::threads_number = needed_number_of_threads;
                    }

                    {
                        lock_guard<mutex> guard(worker_mutex);
                        for (sector_set_this_level_itr = sector_set_this_level.rbegin();
                             sector_set_this_level_itr != sector_set_this_level.rend(); ++sector_set_this_level_itr) {
                            worker_tasks.push_back(*sector_set_this_level_itr); // we created the list of jobs
                            ++distributed_sectors;                              // distributing tasks
                        }
                    }

                    worker_cond.notify_all(); // we told the workers they can start

                    {
                        unique_lock<mutex> guard(worker_mutex);
                        worker_done_cond.wait(
                            guard, []() { return distributed_sectors == 0; }); // we need to wait until all are ready
                    }

                    // If we are using storage, record that this level and inlsectors is complete.
                    if (Common::cpath != "") {
                        Common::completed_in_storage.push_back(make_pair(last_level, inlsectors + 1));
                        completed_in_storage_update();
                    }

                    stop_level_time = chrono::steady_clock::now();
                    if (!Common::silent) {
                        cout << "FINISHED LEVEL " << last_level << "." << inlsectors + 1 << ": "
                             << chrono::duration_cast<chrono::duration<float>>(stop_level_time - start_level_time)
                                    .count()
                             << " seconds." << endl;
                    }

                    // let's estimate memory usage during level
                    memset(vsi, 0, 1024 * sizeof(uint64_t));
                    memset(rss, 0, 1024 * sizeof(uint64_t));

                    open_database(1);

                    // dot put pragma here, we are writing to the same set
                    for (sector_set_this_level_itr = sector_set_this_level.rbegin();
                         sector_set_this_level_itr != sector_set_this_level.rend(); ++sector_set_this_level_itr) {
                        sector_count_t sector_number = (*sector_set_this_level_itr);

                        // first we need the needed list from each higher level database and
                        // add it to the map
                        if (Common::wrap_databases) {
                            database_to_file_or_back(sector_number, false,
                                                     false); // do not remove from storage
                        }

                        size_t new_size = 0;
                        size_t entries =
                            scan_snapshot(
                                sector_number,
                                []([[maybe_unused]] const char *kbuf, size_t ksiz) -> bool { return (ksiz <= 7); },
                                [&new_size, &needed_lower, &eqs_total, &eqs_used, &vsi, &rss, &count,
                                 sector_number](const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz) -> void {
                                    if ((ksiz == 5) && !strncmp(kbuf, "lower", ksiz)) {
                                        new_size = vsiz;
                                        if (new_size) {
                                            Common::points[1]->set(
                                                    int2string(sector_number).c_str(),
                                                    SECTOR_NAME_LEN,
                                                    vbuf,
                                                    vsiz
                                            );
                                        }
                                        new_size /= sizeof(Point);
                                        for (size_t i = 0; i != new_size; ++i) {
                                            add_needed(needed_lower, reinterpret_cast<const Point *>(vbuf)[i]);
                                        }
                                    } else if ((ksiz == 7) && !strncmp(kbuf, "eqs_tot", ksiz))
                                        eqs_total += *reinterpret_cast<const uint64_t *>(vbuf);
                                    else if ((ksiz == 7) && !strncmp(kbuf, "eqs_max", ksiz))
                                        eqs_used += *reinterpret_cast<const uint64_t *>(vbuf);
                                    else if ((ksiz == 7) && !strncmp(kbuf, "mem_vsi", ksiz))
                                        vsi[count] += *reinterpret_cast<const uint64_t *>(vbuf);
                                    else if ((ksiz == 7) && !strncmp(kbuf, "mem_rss", ksiz))
                                        rss[count] += *reinterpret_cast<const uint64_t *>(vbuf);
                                })
                                .first;

                        ++count;
                        entries += new_size;
                        Common::buckets[sector_number] = smallest_bucket(entries);
                        total_substituted += entries;
                        if (Common::wrap_databases) {
                            remove((Common::path + int2string(sector_number) + "." + "tmp").c_str());
                        }
                    }

                    close_database(1, true);

                    if (Common::cpath != "") {
                        store_database(1);
                    }

                } else {
                    // one-pass way. We take information from the database number 1
                    scan_snapshot(
                        1,
                        [&sector_set_this_level](const char *kbuf, [[maybe_unused]] size_t ksiz) -> bool {
                            sector_count_t sector_number;
#ifdef MANY_SECTORS
                            sscanf(kbuf, "%u", &sector_number);
#else
                            sscanf(kbuf, "%hu", &sector_number);
#endif
                            // if (sector_set_this_level.find(sector_number) !=
                            // sector_set_this_level.end()) cout << "Got a request from
                            // sector " << sector_number << endl;
                            return sector_set_this_level.find(sector_number) != sector_set_this_level.end();
                        },
                        [&needed_lower]([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz,
                                        const char *vbuf, size_t vsiz) -> void {
                            size_t new_size = vsiz;
                            new_size /= sizeof(Point);
                            // cout << "Size of request is " << new_size << endl;
                            for (size_t i = 0; i != new_size; ++i) {
                                add_needed(needed_lower, reinterpret_cast<const Point *>(vbuf)[i]);
                            }
                        });
                }

                vector<pair<sector_count_t, set<Point>>> needed_lower_vector;
                needed_lower_vector.reserve(needed_lower.size());
                for (const auto &sector : needed_lower) {
                    needed_lower_vector.emplace_back(sector);
                }
                if (Common::wrap_databases) {
                    omp_set_dynamic(1);
                    omp_set_num_threads(1);
                } else {
                    omp_set_dynamic(Common::threads_default_number);
                    omp_set_num_threads(Common::threads_default_number);
                }
#pragma omp parallel for
                for (auto sector_itr = needed_lower_vector.cbegin(); sector_itr < needed_lower_vector.cend();
                     ++sector_itr) {
                    // now we go through all sectors and fill the lower-level databases
                    // with required input
                    if (Common::wrap_databases) {
                        database_to_file_or_back(sector_itr->first, false);
                    }
                    open_database(sector_itr->first);

                    vector<pair<Point, COEFF>> t;
                    for (const auto &pnt : sector_itr->second) {
                        p_set(pnt, t, true);
                    }
                    close_database(sector_itr->first, true);

                    if (Common::wrap_databases) {
                        database_to_file_or_back(sector_itr->first, true);
                    }
                    if (Common::cpath != "") {
                        store_database(sector_itr->first);
                    }
                }
                if (!Common::one_pass) {
                    estimate_memory_usage(vsi, rss, count, Common::threads_number);
                }
                auto stop_move_time = chrono::steady_clock::now();
                if (!Common::silent) {
                    cout << "Requests copied to lower sectors: "
                         << chrono::duration_cast<chrono::duration<float>>(stop_move_time - stop_level_time).count()
                         << " seconds." << endl;
                }
            }
            last_level--;
        }
    } else {
        // we need to set something related to variables that should be filled on
        // the forward stage
        last_level = 1;
    }

    auto subst_time = chrono::steady_clock::now();

    if (Common::sthreads_number != Common::threads_number)
        change_number_of_threads(Common::threads_number, Common::sthreads_number);

    // backward substitutions level by level
    if ((!Common::only_masters) && (Common::stages != t_stages::forward)) {

        while (last_level <= Common::abs_max_level &&
               ((last_level <= Common::target_level) || (Common::target_level == 0))) {
            int inlsectors = 0;
            while (inlsectors != 2) {
                bool inlsectorsbool = (inlsectors == 0);

                // If we are using storage and cpath_on_substitutions and the current level and inlsectors is already done, skip
                if (Common::cpath != "" && Common::cpath_on_substitutions) {
                    if (find(Common::completed_in_storage.begin(), Common::completed_in_storage.end(), make_pair(-last_level, inlsectors))
                        != Common::completed_in_storage.end() ) {

                        if (!inlsectorsbool) {
                            if (!Common::silent) cout << "SKIPPING LEVEL " << last_level << " : FOUND IN STORAGE" << endl;
                        }
                        else {
                            if (!Common::silent) cout << "SKIPPING HIGHER SECTORS OF SAME LEVEL : FOUND IN STORAGE" << endl;
                        }
                        inlsectors++;
                        continue;
                    }
                }

                // list of sectors of this level
                vector<sector_count_t> sector_set_this_level;

                for (sector_count_t i = 2; i != Common::abs_max_sector + 1; i++) {
                    if (!Common::sector_numbers_fast[sector_fast(Common::ssectors[i])])
                        continue;
                    if (database_exists(i) && (positive_index(Common::ssectors[i]) == last_level) &&
                        (in_lsectors(i) == inlsectorsbool)) {
                        sector_set_this_level.push_back(i);
                    }
                }

                inlsectors++;
                if (sector_set_this_level.empty()) {
                    continue;
                }

                fflush(stdout);

                auto start_timeP = chrono::steady_clock::now();

                kyotocabinet::CacheDB::parallel_access = true;
                open_database(1);

                vector<pair<sector_count_t, vector<pair<sector_count_t, set<Point>>>>> needed_lower_combined(
                    sector_set_this_level.end() - sector_set_this_level.begin());

                map<sector_count_t, size_t> sizes;
                for (auto sector_set_this_level_itr = sector_set_this_level.begin();
                     sector_set_this_level_itr < sector_set_this_level.end(); ++sector_set_this_level_itr) {
                    sizes.insert(make_pair(*sector_set_this_level_itr, 0));
                }

                omp_set_dynamic(Common::sthreads_number);
                omp_set_num_threads(Common::sthreads_number);
#pragma omp parallel for
                for (auto sector_set_this_level_itr = sector_set_this_level.begin();
                     sector_set_this_level_itr < sector_set_this_level.end(); ++sector_set_this_level_itr) {
                    sector_count_t sector_number = *sector_set_this_level_itr;

                    map<sector_count_t, set<Point>> needed_lower;

                    // here we read and fill needed the current sector
                    size_t new_size;
                    char *points = Common::points[1]->get(
                            int2string(sector_number).c_str(),
                            SECTOR_NAME_LEN,
                            &new_size
                        );
                    new_size /= sizeof(Point);
                    for (size_t i = 0; i != new_size; ++i) {
                        add_needed(needed_lower, reinterpret_cast<Point *>(points)[i]);
                    }
                    delete[] (points);

                    if (new_size) {
                        vector<pair<sector_count_t, set<Point>>> needed_lower_vector;
                        needed_lower_vector.reserve(needed_lower.size());
                        for (const auto &sector : needed_lower) {
                            needed_lower_vector.emplace_back(sector);
                        }
                        needed_lower_combined[sector_set_this_level_itr - sector_set_this_level.begin()] =
                            make_pair(sector_number, needed_lower_vector);
                        sizes[sector_number] = new_size;
                    } else
                        needed_lower_combined[sector_set_this_level_itr - sector_set_this_level.begin()].first = 0;
                }
                close_database(1, false);
                kyotocabinet::CacheDB::parallel_access = false;
                if (Common::wrap_databases) {
                    omp_set_dynamic(1);
                    omp_set_num_threads(1);
                } else {
                    omp_set_dynamic(Common::sthreads_number);
                    omp_set_num_threads(Common::sthreads_number);
                }
#pragma omp parallel for
                for (auto needed_lower_combined_itr = needed_lower_combined.begin();
                     needed_lower_combined_itr < needed_lower_combined.end(); ++needed_lower_combined_itr) {
                    sector_count_t sector_number = needed_lower_combined_itr->first;
                    if (!sector_number)
                        continue;

                    if (Common::wrap_databases) {
                        database_to_file_or_back(sector_number, false);
                    }
                    int saved_bucket = Common::buckets[sector_number];
                    Common::buckets[sector_number] = smallest_bucket(sizes.find(sector_number)->second);
                    open_database(sector_number, false);
                    auto &needed_lower_vector = needed_lower_combined_itr->second;
                    for (auto sector_itr = needed_lower_vector.cbegin(); sector_itr < needed_lower_vector.cend();
                         ++sector_itr) {
                        const auto &sector = *sector_itr;
                        if (Common::wrap_databases) {
                            database_to_file_or_back(sector.first, false,
                                                     false); // only for reading
                        }
                        size_t transfered =
                            scan_snapshot(
                                sector.first,
                                [&sector](const char *kbuf, size_t ksiz) -> bool {
                                    return ((ksiz == sizeof(Point)) &&
                                            (sector.second.find(*reinterpret_cast<const Point *>(kbuf)) !=
                                             sector.second.end()));
                                },
                                [&sector_number](const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz) -> void {
                                    if (!Common::points[sector_number]->set(kbuf, ksiz, vbuf, vsiz)) {
                                        cout << "Can't write on Point transfer" << endl;
                                        abort();
                                    }
                                })
                                .second;
                        if (transfered != sector.second.size()) {
                            cout << "Incorrect number of entries transfered for sector " << sector_number << ": "
                                 << transfered << " instead of " << sector.second.size() << endl;
                            abort();
                        }
                        if (Common::wrap_databases) {
                            remove((Common::path + int2string(sector.first) + "." + "tmp").c_str());
                        }
                    }

                    close_database(
                        sector_number, true,
                        []([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz,
                           [[maybe_unused]] const char *vbuf, [[maybe_unused]] size_t vsiz) { return true; },
                        true);
                    Common::buckets[sector_number] = saved_bucket;
                    if (Common::wrap_databases) {
                        database_to_file_or_back(sector_number, true);
                    }
                    if (Common::cpath != "") {
                        if (Common::cpath_on_substitutions)
                            store_database(sector_number);
                    }
                }

                auto stop_timeP = chrono::steady_clock::now();

                if (!Common::silent) {
                    cout << "Copying results from lower sectors: "
                         << chrono::duration_cast<chrono::duration<float>>(stop_timeP - start_timeP).count()
                         << " seconds." << endl;
                }

                {
                    lock_guard<mutex> guard(worker_mutex);
                    for (auto sector_set_this_level_itr = sector_set_this_level.begin();
                         sector_set_this_level_itr != sector_set_this_level.end(); ++sector_set_this_level_itr) {
                        if (Common::one_pass)
                            worker_tasks.push_back((*sector_set_this_level_itr));
                        else
                            worker_tasks.push_back(-(*sector_set_this_level_itr)); // we created the list of jobs
                        ++distributed_sectors;                                     // distributing tasks
                    }
                }

                worker_cond.notify_all(); // we told the workers they can start

                {
                    unique_lock<mutex> guard(worker_mutex);
                    worker_done_cond.wait(
                        guard, []() { return distributed_sectors == 0; }); // we need to wait until all are ready
                }

                // let's estimate memory usage during level substitutions
                uint64_t vsi[1024];
                uint64_t rss[1024];
                size_t count = 0;
                for (auto sector_set_this_level_itr = sector_set_this_level.begin();
                     sector_set_this_level_itr != sector_set_this_level.end(); ++sector_set_this_level_itr) {
                    sector_count_t sector_number = (*sector_set_this_level_itr);

                    if (Common::wrap_databases) {
                        database_to_file_or_back(sector_number, false, false);
                    }

                    vsi[count] = 0;
                    rss[count] = 0;
                    scan_snapshot(
                        sector_number,
                        []([[maybe_unused]] const char *kbuf, size_t ksiz) -> bool { return (ksiz <= 7); },
                        [&vsi, &rss, &count, &eqs_total, &eqs_used](const char *kbuf, size_t ksiz, const char *vbuf,
                                                                    [[maybe_unused]] size_t vsiz) -> void {
                            if ((ksiz == 7) && !strncmp(kbuf, "mem_vsi", ksiz))
                                vsi[count] += *reinterpret_cast<const uint64_t *>(vbuf);
                            else if ((ksiz == 7) && !strncmp(kbuf, "mem_rss", ksiz))
                                rss[count] += *reinterpret_cast<const uint64_t *>(vbuf);
                            else if (Common::one_pass) {
                                if ((ksiz == 7) && !strncmp(kbuf, "eqs_tot", ksiz))
                                    eqs_total += *reinterpret_cast<const uint64_t *>(vbuf);
                                else if ((ksiz == 7) && !strncmp(kbuf, "eqs_max", ksiz))
                                    eqs_used += *reinterpret_cast<const uint64_t *>(vbuf);
                            }
                        });

                    ++count;

                    if (Common::wrap_databases) {
                        remove((Common::path + int2string(sector_number) + "." + "tmp").c_str());
                    }
                }

                estimate_memory_usage(vsi, rss, count, Common::sthreads_number);
                auto stop_timePP = chrono::steady_clock::now();
                if (!Common::silent) {
                    cout << "Time for the current level: "
                         << chrono::duration_cast<chrono::duration<float>>(stop_timePP - stop_timeP).count()
                         << " seconds." << endl;
                }

                // If we are using storage and cpath_on_substitutions, record that this level and inlsectors is complete.
                if (Common::cpath != "" && Common::cpath_on_substitutions) {
                    Common::completed_in_storage.push_back(make_pair(-last_level, inlsectors - 1));
                    completed_in_storage_update();
                }

                if (inlsectorsbool) {
                    if (!Common::silent)
                        cout << "STARTING HIGHER SECTORS OF SAME LEVEL" << endl;
                }
                else {
                    if (!Common::silent) cout << "FINISHED LEVEL " << last_level << endl;
                }
            }

            if (!Common::silent) {
                cout << "FINISHED LEVEL " << last_level << endl;
            }
            last_level++;
        }

        if (!Common::silent) {
            cout << "Totally substituted " << total_substituted << " points" << endl;
        }
    } // if making substitutions

    auto stop_time = chrono::steady_clock::now();

    if (!Common::very_silent) {
        cout << "STATISTICS" << endl;
        cout << "Total time: " << chrono::duration_cast<chrono::duration<float>>(stop_time - start_time).count()
             << endl;
        cout << "Substitution time: " << chrono::duration_cast<chrono::duration<float>>(stop_time - subst_time).count()
             << endl;
        cout << "Thread time: "
             << chrono::duration_cast<chrono::duration<float>>(chrono::microseconds(Common::thread_time)).count()
             << endl;
        cout << "Eqs (total/used): " << eqs_total << " | " << eqs_used << endl;
        cout << "Maximal memory by the main process (virtual|resident): ";
        print_memory(max_vsi_main, 0, -1);
        cout << " | ";
        print_memory(max_rss_main, 1, -1);
        cout << endl;
        cout << "Thread memory usage estimation by top " << Common::sthreads_number << " sectors (virtual|resident): ";
        print_memory(max_vsi_est, 0, -1);
        cout << " | ";
        print_memory(max_rss_est, 1, -1);
        cout << endl;
    }
    worker_stop = true;
    worker_cond.notify_all();
    for (unsigned int i = 0; i != Common::sthreads_number; ++i) {
        worker[i].join();
    }
}

#ifndef PRIME
bool express_and_pass_back(map<Point, vector<pair<Point, COEFF>>, std::greater<Point>> &to_test,
                           const sector_count_t sector, const unsigned int thread_number) {
    bool has_high = false;
    auto ritr = to_test.rbegin();
    for (auto itr = to_test.begin(); itr != to_test.end();) {
        const Point &p = itr->first;
        if (!Common::one_pass && ((p.SectorNumber() != sector) || (p.IsVirtual()))) {
            // cout << p << endl;
            ritr = map<Point, vector<pair<Point, COEFF>>, std::greater<Point>>::reverse_iterator(itr);
            break;
        }
        p_get(p, itr->second, sector);
        if (!itr->second.empty()) {
            auto insert_itr = itr;
            vector<pair<Point, COEFF>>::const_reverse_iterator mitr =
                itr->second.rbegin(); // the highest, that will be skipped
            for (++mitr; mitr != itr->second.rend(); ++mitr) {
                // last is equal to p. not to check it all the time
                if (Common::one_pass || ((mitr->first.SectorNumber() == sector) && (!mitr->first.IsVirtual()))) {
                    vector<pair<Point, COEFF>> v;
                    insert_itr = to_test.insert(insert_itr,
                                                make_pair(mitr->first,
                                                          v)); // we keep moving to lower entries, they will come later
                } else {
                    break; // as soon as we see something out of the sector, there is no
                           // need to search more
                }
            }
            ++itr;
        } else {
            if (Common::one_pass && (p.SectorNumber() != sector)) {
                // cout << "Phantom request for lower " << p << endl;
                // it's an empty table of a lower sector, it should be set to zero
                vector<pair<Point, COEFF>> set_to_zero;
                COEFF one;
                one.s = "1";
                set_to_zero.push_back(make_pair(itr->first, one));
                itr->second = set_to_zero;
                p_set(itr->first, set_to_zero, false, sector);
                ++itr;
            } else {
                has_high = true;
                ++itr;
                // it's been an empty table, but we don't change anything, it will be
                // skipped on the back pass
            }
        }
    }

    if (!has_high) {
        return false;
    }

    // pass_back
    for (auto itr = ritr; itr != to_test.rend(); ++itr) {
        vector<pair<Point, COEFF>> &terms = itr->second;
        if (!terms.empty()) {
            apply_table_poly(terms, true, true, sector, thread_number);
        }
    }
    return true;
}
#endif

set<Point, std::greater<Point>>::reverse_iterator expressed_by(set<Point, std::greater<Point>> &to_test,
                                                               sector_count_t sector_number) {
    for (auto itr = to_test.begin(); itr != to_test.end();) {
        Point p = *itr;
        if (p.SectorNumber() != sector_number) {
            return set<Point, std::greater<Point>>::reverse_iterator(itr);
        }
        vector<Point> monoms = p_get_monoms(p, sector_number);
        if (!monoms.empty()) {
            auto last = monoms.end();
            last--;
            for (auto mitr = monoms.begin(); mitr != last; ++mitr) {
                if (mitr->SectorNumber() == sector_number) {
                    to_test.insert(itr, (*mitr));
                }
            }
            ++itr;
        } else {
            to_test.erase(itr++);
        }
    }
    return to_test.rbegin();
}

#ifdef PRIME
void add_to(list<pair<Point, COEFF>> &terms1, const vector<pair<Point, COEFF>> &terms2, const COEFF &coeff,
            bool skip_last) {
    add_to(terms1, terms2.begin(), terms2.end(), coeff, skip_last);
}

void add_to(list<pair<Point, COEFF>> &terms1, const list<pair<Point, COEFF>> &terms2, const COEFF &coeff,
            bool skip_last) {
    add_to(terms1, terms2.begin(), terms2.end(), coeff, skip_last);
}

// adding a vector to list
template <class I>
void add_to(list<pair<Point, COEFF>> &terms1, I termsB, I termsE, const COEFF &coeff, bool skip_last) {
    auto eq2end = termsE;
    if (skip_last) {
        eq2end--;
    }
    auto itr1 = terms1.begin();
    auto itr2 = termsB;
    while (itr2 != eq2end) {
        if ((itr1 != terms1.end()) && (itr1->first < itr2->first)) { // first Equation only. just adding to result
            ++itr1;
        } else if ((itr1 == terms1.end()) || (itr2->first < itr1->first)) { // second Equation only. have to multiply
            itr1 = terms1.emplace(itr1, itr2->first, itr2->second * coeff);
            ++itr1;
            ++itr2;
        } else { // both equations. have to multiply and add
            COEFF num1 = itr2->second * coeff + itr1->second;
            COEFF zero(0);
            if (!(num1 == zero)) {
                itr1->second = num1;
                ++itr1;
            } else {
                itr1 = terms1.erase(itr1);
            }
            ++itr2;
        }
    }
}
#else

void add(const vector<pair<Point, COEFF>> &terms1, const vector<pair<Point, COEFF>> &terms2,
         vector<pair<Point, COEFF>> &rterms, const COEFF &coeff, bool skip_last) {
    rterms.reserve(terms1.size() + terms2.size());
    rterms.clear();

    auto eq2end = terms2.end();
    if (skip_last) {
        eq2end--;
    }
    vector<pair<Point, COEFF>>::const_iterator itr1;
    vector<pair<Point, COEFF>>::const_iterator itr2;
    itr1 = terms1.begin();
    itr2 = terms2.begin();
    while (itr2 != eq2end) {
        if ((itr1 != terms1.end()) && (itr1->first < itr2->first)) { // first Equation only. just adding to result
            rterms.emplace_back(*itr1);
            ++itr1;
        } else if ((itr1 == terms1.end()) || (itr2->first < itr1->first)) { // second Equation only. have to multiply
            string s;
            s += coeff.s;
            s += "*(";
            s += itr2->second.s;
            s += ")";
            COEFF c;
            c.s = s;
            rterms.emplace_back(make_pair(itr2->first, c));
            ++itr2;
        } else { // both equations. have to multiply and add
            string s;
            s += itr1->second.s;
            if (fuel::getLibrary() == "flint") {
                s += "&";
            } else if (coeff.s[0] != '-') {
                s += "+";
            }
            s += coeff.s;
            s += "*(";
            s += itr2->second.s;
            s += ")";
            COEFF c;
            c.s = s;
            rterms.emplace_back(make_pair(itr2->first, c));
            ++itr1;
            ++itr2;
        }
    }

    while (itr1 != terms1.end()) {
        rterms.emplace_back(*itr1);
        ++itr1;
    }
}
#endif

#ifdef PRIME
bool apply_table_prime(const vector<pair<Point, COEFF>> &terms, sector_count_t sector_number,
                       list<pair<Point, COEFF>> *result, vector<pair<Point, COEFF>> *temporary_terms) {

    bool changed = false;
    auto end = terms.cend();
    --end;
    result->clear();
    for (auto itr = terms.cbegin(); itr != end; ++itr) {
        const Point &p = itr->first;
        if (p.SectorNumber() == 1) {
            result->emplace_back(*itr);
        } else {
            temporary_terms->clear();
            p_get(p, *temporary_terms, sector_number);
            if (temporary_terms->empty()) {
                result->emplace_back(*itr); // we just put the monomial at the end with no substitution
            } else {
                changed = true;
                COEFF zero(0);
                COEFF c = (zero - itr->second) / temporary_terms->back().second;
                add_to(*result, *temporary_terms, c,
                       true); // we add the second expression with the last term killed
            }
        }
    }

    if (!changed) {
        return false;
    }

    result->push_back(terms.back());
    return true;
}
#else

/**
 * Invert a coefficient if it is a pure fraction by exchanging numerator and
 * denominator
 * @param coeff the coeff to be inverted
 * @return inverted coeff
 */
string invert_coeff(string coeff) {
    if (coeff[0] == '[' && coeff[coeff.size() - 1] == ']') {
        auto pos = coeff.find(',');
        if (pos != string::npos && coeff.find(',', pos + 1) == string::npos) {
            return "*[" + coeff.substr(pos + 1, coeff.size() - pos - 2) + "," + coeff.substr(1, pos - 1) + "]";
        }
    } else {
        auto pos = coeff.find('/');
        if (pos != string::npos && coeff.find('/', pos + 1) == string::npos) {
            return "*((" + coeff.substr(pos + 1, coeff.size() - pos - 1) + ")/(" + coeff.substr(0, pos) + "))";
        }
    }
    return "/(" + coeff + ")";
}

void apply_table_poly(const vector<pair<Point, COEFF>> &terms, bool forward_mode, bool fixed_last,
                      sector_count_t sector_number, unsigned int thread_number) {

    bool changed = false;
    auto end = terms.cend();
    if (fixed_last) {
        --end;
    }
    vector<pair<Point, COEFF>> rterms1;
    rterms1.reserve(terms.size());
    bool first = true;
    vector<pair<Point, COEFF>> rterms2;
    for (auto itr = terms.cbegin(); itr != end; ++itr) {
        const Point &p = itr->first;
        if ((forward_mode && !Common::one_pass && ((p.SectorNumber() < sector_number) || p.IsVirtual())) ||
            (p.SectorNumber() == 1)) {
            if (first) {
                rterms1.push_back(*itr);
            } else {
                rterms2.push_back(*itr);
            }
        } else {
            vector<pair<Point, COEFF>> terms2;
            p_get(p, terms2, sector_number);
            if (terms2.empty()) {
                if (first) {
                    rterms1.push_back(*itr);
                } else {
                    rterms2.push_back(*itr);
                }
            } else {
                changed = true;
                COEFF c;
                c.s = "-(" + itr->second.s + ")" + invert_coeff(terms2.back().second.s);
                if (first) {
                    add(rterms1, terms2, rterms2, c, true);
                    first = false;
                } else {
                    add(rterms2, terms2, rterms1, c, true);
                    first = true;
                }
            }
        }
    }

    if (fixed_last) {
        if (first) {
            rterms1.push_back(terms.back());
        } else {
            rterms2.push_back(terms.back());
        }
    }

    vector<pair<Point, COEFF>> *rterms_p;
    if (first) {
        rterms_p = &rterms1;
    } else {
        rterms_p = &rterms2;
    }
    vector<pair<Point, COEFF>> &rterms = *rterms_p;
    if (rterms.empty())
        return;

    if (!changed) {
        if (!fixed_last) {
            // means that it is a pure Equation that should be checked for having at
            // lease something over the corner and set
            Point &after = rterms.back().first;
            if ((after.SectorNumber() >= sector_number) && (!after.IsVirtual())) {
                p_set(after, rterms, false, sector_number);
            }
        }
        return;
    }

    normalize(rterms, thread_number);

    if (rterms.empty())
        return;

    if (forward_mode && !Common::one_pass) {
        if ((rterms.back().first.SectorNumber() == sector_number) && (!(rterms.back().first.IsVirtual()))) {
            split(rterms, sector_number); // classical split with vectors
        }
    } else {
        p_set(rterms.back().first, rterms, false, sector_number);
    }
}
#endif

void pass_back(const set<Point, std::greater<Point>> &cur_set, sector_count_t sector_number) {
#ifdef PRIME
    class VisitorImpl : public kyotocabinet::DB::Visitor {
      private:
        const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz, size_t *sp) {
#ifdef MPRIME
            const unsigned int len = vsiz / (sizeof(Point) + MPRIME * sizeof(unsigned long long));
            bool needed_higher = vsiz % (sizeof(Point) + MPRIME * sizeof(unsigned long long));
#else
            const unsigned int len = vsiz / (sizeof(Point) + sizeof(unsigned long long));
            bool needed_higher = vsiz % (sizeof(Point) + sizeof(unsigned long long));
#endif
            if (len == 0) {
                return NOP;
            }
            terms.clear();
            terms.reserve(len);
            const Point *p = reinterpret_cast<const Point *>(kbuf);
            p_get_internal(*p, terms, len, vbuf);
            bool needs_setting;

            list<pair<Point, COEFF>> result;
            needs_setting = apply_table_prime(terms, sector_number, &result, &temporary_terms);
            if (!needs_setting)
                return NOP;

            size_t n = result.size();
#ifdef MPRIME
            size_t coeffs_size = MPRIME * n * sizeof(unsigned long long);
#else
            size_t coeffs_size = n * sizeof(unsigned long long);
#endif
            size_t points_size = n * sizeof(Point);
            size_t buf_size = points_size + coeffs_size;
            if (needed_higher) {
                ++buf_size;
            }

            if ((buf_size > max_buf_size) || (!buf)) {
                if (buf) {
                    free(buf);
                }
                if (buf_size > max_buf_size) {
                    max_buf_size = 2 * buf_size;
                }
                buf = static_cast<char *>(malloc(max_buf_size));
                if (!buf) {
                    cout << "Cannot malloc in pass_back" << endl;
                    abort();
                }
            }
            if (needed_higher) {
                buf[points_size + coeffs_size] = 1;
            }

            unsigned short j = 0;
            for (auto itr = result.begin(); itr != result.end(); ++itr) {
                reinterpret_cast<Point *>(buf)[j] = itr->first;
                ++j;
            }

            char *pos = buf + points_size; // preparing a string of coeffs
            for (auto itr = result.begin(); itr != result.end(); ++itr) {
#ifdef MPRIME
                for (size_t i = 0; i != MPRIME; ++i) {
                    *reinterpret_cast<unsigned long long *>(pos) = itr->second.N[i];
                    pos += sizeof(unsigned long long);
                }
#else
                *reinterpret_cast<unsigned long long *>(pos) = itr->second.n;
                pos += sizeof(unsigned long long);
#endif
            }
            *sp = buf_size;
            return buf;
        }
        const char *visit_empty(const char *kbuf, size_t ksiz, size_t *sp) {
            cout << "Missing entry at substitutions " << endl;
            abort();
            return NOP;
        }

      public:
        vector<pair<Point, COEFF>> terms;
        vector<pair<Point, COEFF>> temporary_terms;
        sector_count_t sector_number = {};
        char *buf = nullptr;
        size_t max_buf_size = 1024;
    } substitution_visitor;
    substitution_visitor.sector_number = sector_number;
    list<pair<Point, COEFF>> result;
    vector<pair<Point, COEFF>> temporary_terms;
    vector<pair<Point, COEFF>> terms;
    substitution_visitor.buf = nullptr;
    for (auto itr = cur_set.rbegin(); itr != cur_set.rend(); ++itr) {
        Point p = *itr;

        if (!Common::points[sector_number]->accept(reinterpret_cast<const char *>(&p), sizeof(p), &substitution_visitor,
                                                   true)) {
            cout << "Cannot accept substitution visitor " << endl;
            abort();
        }
    }
    if (substitution_visitor.buf) {
        free(substitution_visitor.buf);
    }

#else
    vector<pair<Point, COEFF>> terms;
    for (auto itr = cur_set.rbegin(); itr != cur_set.rend(); ++itr) {
        Point p = *itr;
        terms.clear();
        p_get(p, terms, sector_number);
        if (!terms.empty()) {
            apply_table_poly(terms, false, true, sector_number,
                             0); // backward reduction with 0 as sector and 0 as thread_number
        }
    }
#endif
}

#ifdef PRIME
list<pair<Point, COEFF>>::iterator split(list<pair<Point, COEFF>> &terms, sector_count_t sector_number)
#else
void split(vector<pair<Point, COEFF>> &terms, sector_count_t sector_number)
#endif
{
#ifdef PRIME
    if (terms.empty())
        return terms.begin();
#else
    if (terms.empty())
        return;
#endif
    auto itr = terms.begin();
    size_t size = 0;
    while ((itr->first.SectorNumber() < sector_number) || itr->first.IsVirtual()) {
        ++itr;
        ++size;
    }
    if ((itr != terms.begin()) && (itr != terms.end())) {
        // once I tries to remove the splitting in case of size==1
        // but it degrades performance in some cases
        // so do not touch this!

        // starting the split
        uint64_t virts_temp = ++virts_number; // atomic
        // virts_temp gets the old value, then virts_number gets increased

        Point p(Common::ssectors[sector_number], virts_temp); // virtual

        pair<Point, COEFF> save = *itr;
        // the pair at itr position is saved, then used to temporarily store the
        // pair with the new virtual definition

#ifdef PRIME
        COEFF c(Common::prime - 1);
#else
        COEFF c;
        c.s = "-1";
#endif
        *itr = make_pair(p, c);
        ++itr;
#ifdef PRIME
        p_set<list<pair<Point, COEFF>>::const_iterator>(p, size + 1, terms.begin(), itr, false, 0);
#else
        p_set<vector<pair<Point, COEFF>>::const_iterator>(p, size + 1, terms.begin(), itr, false, 0);
#endif

        --itr;
        *itr = save; // returning the original pair
        --itr;
#ifdef PRIME
        COEFF c2(1);
#else
        COEFF c2;
        c2.s = "1";
#endif
        *itr = make_pair(p, c2);

#ifdef PRIME
        p_set<list<pair<Point, COEFF>>::const_iterator>(terms.back().first, terms.size() - size + 1, itr, terms.end(),
                                                        false, 0);
        return itr;
#else
        p_set<vector<pair<Point, COEFF>>::const_iterator>(terms.back().first, terms.size() - size + 1, itr, terms.end(),
                                                          false, 0);
#endif
    } else
        p_set(terms.back().first, terms, false,
              0); // split won't happen in symmetries sector
#ifdef PRIME
    return terms.begin();
#endif
}

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

void print_memory(__uint64_t mem, int power_level, int silent) {
    if (silent == 1)
        return;
    if ((silent == 0) && Common::silent)
        return;

    if ((mem < 64) || (power_level == 3)) {
        cout << mem << mem_symbol(power_level);
    } else if (mem < 64 * 1024) {
        cout << setprecision(4) << (mem / 1024.) << setprecision(6) << mem_symbol(power_level + 1);
    } else {
        print_memory(mem / 1024, power_level + 1, silent);
    }
}

void process_mem_usage(bool silent) {
    using std::ifstream;
    using std::ios_base;
    using std::string;

    //  vm_usage     = 0.0;
    //  resident_set = 0.0;

    // 'file' stat seems to give the most reliable results
    //
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

    if ((!silent) && (!Common::silent)) {
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

vector<pair<Point, COEFF>> group_equal_in_sorted(const vector<pair<Point, COEFF>> &mon) {
    vector<pair<Point, COEFF>> terms;
    terms.reserve(mon.size());
    for (auto read = mon.begin(); read != mon.end(); ++read) {
        // there is already a check here for equal points due to symmetries
        COEFF c = read->second;
        auto read2 = read;
        read2++;
        while ((read2 != mon.end()) && (read2->first == read->first)) {
#ifdef PRIME
            c = c + read2->second;
#else
            c.s += "+(" + read2->second.s + ")";
#endif
            read2++;
        }
        read2--;
        read = read2;
#ifdef PRIME
        COEFF zero(0);
        if (!(c == zero)) {
            terms.emplace_back(read->first, c);
        }
#else
        terms.emplace_back(read->first, c);
#endif
    }
    return terms;
}
