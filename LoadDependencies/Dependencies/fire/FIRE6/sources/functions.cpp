/** @file functions.cpp
 * @author Alexander Smirnov
 *
 * This file is a part of the FIRE package
*/

#include "functions.h"
#include "common.h"
#include "parser.h"
#include <algorithm>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <thread>
#include <mutex>
#include <condition_variable>

/**
 * Database size.
 */
uint64_t total_size = 0;

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
 * Flag is raised, when all manually started FLAME jobs should be stopped.
 */
bool child_stop = false;
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
list<pair<unsigned int, unsigned int> > level_tasks;

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

string GBsize(int64_t size) {
    stringstream ss(stringstream::out);
    ss << double(size) / (1024 * 1024 * 1024) << " GB";
    return ss.str();
}


int64_t realsize(sector_count_t number) {
    std::map<std::string, std::string> status;
    if (common::points[number]->status(&status)) {
        int64_t realsize = kyotocabinet::atoi(status["realsize"].c_str());
        return realsize;
    } else {
        cout << "Can't get real size" << endl;
        abort();
    }
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
 * Substitute indices into a coefficient string without fuel calls, but with string operations.
 * @param str string containing a[i] like insertions
 * @param v vector of substitutions
 */
void subs2(string &str, const vector<t_index> &v) {
    size_t length = str.size();
    for (unsigned int i = 0; i != length; ++i) {
        if ((i + 2) >= length) { continue; }
        if (!((str[i] == 'a') && (str[i + 1] == 'a'))) { continue; }
        unsigned int ind = 0;
        if ((str[i] == 'a') &&
            (str[i + 1] == 'a') &&
            (str[i + 2] == 'a') &&
            (str[i + 3] == '(') &&
            (str[i + 5] == ')')) {
            ind = char2digit(str[i + 4]);
        } else if ((str[i] == 'a') &&
                   (str[i + 1] == 'a') &&
                   (str[i + 2] == 'a') &&
                   (str[i + 3] == '(') &&
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


/**
 * Compare pairs of points and coefficients by points only.
 * @param lhs first pair.
 * @param rhs second pair.
 * @return true if point in first pair is smaller than point in second pair.
 */
bool MONOM_smaller(const MONOM *lhs, const MONOM *rhs) {
    return (lhs->p) < (rhs->p);
}


equation* apply(const vector<pair<vector<COEFF>, point_fast > >& ibp, point_fast v, const SECTOR ssector_fast, unsigned int thread_number) {
    auto result = new equation(ibp.size());
    unsigned int length = 0;
    sector_count_t sn = common::sector_numbers_fast[ssector_fast];
    point p_orig(v,ssector_fast);

    bool there_are_symmetries = (common::symmetries.size() > 1);

    for (auto read = ibp.begin(); read != ibp.end(); ++read) {
        point_fast new_v = read->second + v;
        SECTOR s1 = new_v.sector_fast();

        if ((s1 != ssector_fast) && (~(ssector_fast | (~s1)))) { continue; }
        //bitwise not to s1, or ssector_fast is full of 1 if sector_fast is over s1. now again bitwise not, and it should become 0 only if sector_fast is over s1

        point new_p;

        if (!there_are_symmetries && (s1 == ssector_fast))  {
            new_p = point(p_orig,read->second,ssector_fast, point::preferred_fast[sn].find(new_v) == point::preferred_fast[sn].end());
        } else {
            new_p = point_reference_fast(new_v);
        }

        if (new_p.is_zero()) { continue; }
#ifdef PRIME
        int128_t res = (read->first)[0].n;
        t_index *pos = v.buf;
        for (unsigned short i = 0; i != common::dimension; ++i, ++pos) {
            res += (int128_t(*pos) * (read->first)[i + 1].n);
        }
        res %= common::prime;
        if (res < 0) res += common::prime;
        if (res) {
            COEFF c;
            c.n = res;
            result->terms[length]->p = new_p;
            result->terms[length]->c = c;
            ++length;
        }
#else
        string cfast = (read->first)[0].s; // the free coefficient;
        if (cfast.empty()) cfast = "0";
        t_index *pos = v.buf;
        char buf[16];
        for (unsigned short i = 0; i != common::dimension; ++i, ++pos) {
            if (!(read->first)[i + 1].s.empty()) {
                cfast += "+(";
                cfast += (read->first)[i + 1].s;
                cfast += ")*";
                sprintf(buf, "%d", int(*pos));
                cfast += "(";
                cfast += buf;
                cfast += ") ";
            }
        }
        if (cfast != "0") {
            COEFF c;
            c.s = cfast;
            result->terms[length]->p = new_p;
            result->terms[length]->c = c;
            ++length;
        }
#endif
    }

    result->length = length;
    sort(result->terms, result->terms + length, MONOM_smaller);

    unsigned int k = 0; // k is where we write to; i is where we read from;
    for (unsigned int i = 0; i != result->length; ++i, ++k) {
        if (k != i) {
            result->terms[k] = result->terms[i]; // just changing the pointer to another portion of data
        }

        while (((i + 1) != result->length) && (result->terms[i + 1]->p == result->terms[k]->p)) {
            // the next term is equal
#ifdef PRIME
            uint128_t nB = result->terms[k]->c.n;
            nB += result->terms[i + 1]->c.n;
            nB %= common::prime;
            result->terms[k]->c.n = nB;
            if (result->terms[k]->c.n == 0) {
                --k;
                ++i;
                break; // out of the internal cycle. we will anyway increase i and k
            }
#else
            result->terms[k]->c.s += "+(" + result->terms[i + 1]->c.s + ")";
#endif
            ++i;
        }
    }
    result->length -= (result->length - k);

#ifndef PRIME
    normalize_eq(result, thread_number);
    sort(result->terms, result->terms + result->length, MONOM_smaller);
#endif

    if ((result->length) == 0) {
        delete result;
        result = nullptr;
    }
    return result;
}

/**
 * Compare vectors of indices in sector with the use of sector ordering
 * @param lhs first vector
 * @param rhs second vector
 * @param s sector
 * @return true if lhs is smaller than rhs, false otherwise.
 */
bool vector_smaller_in_sector(const point_fast &lhs, const point_fast &rhs, SECTOR s) {
    if (lhs == rhs){
        return false;
    }
    t_index *ordering_now = common::orderings_fast[s].get();

    vector<t_index> d1;
    vector<t_index> d2;
    SECTOR bit = 1u << (common::dimension - 1);
    for (unsigned int i = 0; i != common::dimension; ++i, bit >>= 1) {
        if (s & bit) {
            d1.push_back(lhs.buf[i]);
            d2.push_back(rhs.buf[i]);
        } else {
            d1.push_back(-lhs.buf[i]);
            d2.push_back(-rhs.buf[i]);
        }
    }

    for (unsigned int i = 0; i != common::dimension; ++i) {
        int pr = 0;
        for (unsigned int j = 0; j != common::dimension; ++j) {
            if (ordering_now[i * common::dimension + j] == 1) pr += (d1[j] - d2[j]);
        }
        if (pr < 0) return true;
        if (pr > 0) return false;
    }
    return false;
}

/**
 * Calculate final product from list of terms.
 * @param product the list of vectors of terms that are multipled
 * @param n dimension
 * @return resulting product
 */
map<point_fast, COEFF> calculate_product(const list<vector<pair<COEFF, point_fast> > > &product, unsigned int n) {
    // let's calculate the product
    map<point_fast, COEFF> local_coeffs;
    for (const auto &v1 : product) {
        map<point_fast, COEFF> new_local_coeffs;
        if (local_coeffs.empty()) {
            for (const auto &i1 : v1) {
                new_local_coeffs.emplace(i1.second, i1.first);
            }
        } else {
            for (const auto &i1 : v1) {
                for (const auto &local_coeff : local_coeffs) {
                    point_fast new_v;
                    for (unsigned short u = 0; u != n; u++) {
                        new_v.buf[u] = i1.second.buf[u] + local_coeff.first.buf[u];
                    }
                    const auto i3 = new_local_coeffs.find(new_v);
#ifdef PRIME
                    if (i3 == new_local_coeffs.end()) {
                        COEFF new_c;
                        uint128_t nB = i1.first.n;
                        nB *= uint128_t(local_coeff.second.n);
                        nB %= common::prime;
                        new_c.n = nB;
                        new_local_coeffs.emplace_hint(i3, new_v, new_c);
                    } else {
                        uint128_t nB = i1.first.n;
                        nB *= uint128_t(local_coeff.second.n);
                        nB += i3->second.n;
                        nB %= common::prime;
                        i3->second.n = nB;
                    }
#else
                    if (i3 == new_local_coeffs.end()) {
                        COEFF new_c;
                        new_c.s = "((" + i1.first.s + ")*(" + local_coeff.second.s + "))";
                        new_local_coeffs.emplace_hint(i3, new_v, new_c);
                    } else {
                        i3->second.s = i3->second.s + "+" + "(" + "(" + i1.first.s + ")*(" + local_coeff.second.s + ")" + ")";
                    }
#endif
                }
            }
        }
        local_coeffs.clear();
        for (auto &&new_local_coeff : new_local_coeffs) {
#ifdef PRIME
            if (new_local_coeff.second.n) {
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

/**
 * Writes Lee symmetries with the given complexity level to the database.
 * @param p_start corner of the sector
 * @param pos number of dots
 * @param neg number of numerators
 * @param sector_level number of positive indices in this sector
 * @return number of symmetries written
 */
int write_symmetries(const point &p_start, const unsigned int pos, const unsigned int neg, int sector_level) {
    int result = 0;
    int n = p_start.get_vector().size();
    auto iitr = point::ibases.find(p_start.s_number());
    if (iitr != point::ibases.end()) {
        point_fast p_fast = point_fast(p_start);
        set<point_fast> s = level_points_fast(p_fast, pos, neg);
        if (neg == 1) {
            set<point_fast> s2 = level_points_fast(p_fast, pos, 0);
            for (const auto &pp : s2) s.insert(pp);
        }
        if (pos == 1) {
            set<point_fast> s2 = level_points_fast(p_fast, 0, neg);
            for (const auto &pp : s2) s.insert(pp);
        }
        if ((neg == 1) && (pos == 1)) {
            set<point_fast> s2 = level_points_fast(p_fast, 0, 0);
            for (const auto &pp : s2) s.insert(pp);
        }
        for (const auto &pp : s) {
            // go through points
            // no need for symmetries here more
            // y is pp.buf
            point p = point_reference_fast(pp);
            if (!p_is_empty(p)) {
                continue;
            }

            for (const auto &ibasis : iitr->second) {
                // go through symmetries

                list<vector<pair<COEFF, point_fast> > > product;
                point_fast new_pp;
                for (int j = 0; j != n; ++j) {  // here we use the permutation
                    if (ibasis.first[j] == 0) {
                        new_pp.buf[j] = 0;
                    } else {
                        new_pp.buf[j] = pp.buf[ibasis.first[j] - 1];
                    }
                }
                vector<pair<COEFF, point_fast> > new_term;
                COEFF c;
#ifdef PRIME
                c.n = 1;
#else
                c.s = "1";
#endif
                new_term.emplace_back(c, new_pp);
                product.push_back(new_term);  // starting a product, next parts will be in a cycle

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
                map<point_fast, COEFF> local_coeffs = calculate_product(product, n); // this is a shared function in external and internal symmetry generation

                // product calculated, now it is time to get the rule
                // let's add -p right here
                auto itr = local_coeffs.find(pp);
                if (itr == local_coeffs.end()) {
                    COEFF coeff;
#ifdef PRIME
                    coeff.n = common::prime - 1;
#else
                    coeff.s = "-1";
#endif
                    local_coeffs.emplace(pp, coeff);
                } else {
#ifdef PRIME
                    if (itr->second.n)
                        itr->second.n = (itr->second.n - 1) % common::prime;
                    else
                        itr->second.n = (common::prime - 1);
#else
                    itr->second.s = itr->second.s + " -1";
#endif
                }

                // now we will convert here to strings, but...
                vector<pair<point, COEFF> > mon;
                mon.reserve(local_coeffs.size());

                for (const auto &local_coeff : local_coeffs) {
#ifdef PRIME
                    if (local_coeff.second.n != 0)
#else
                    if (local_coeff.second.s != "0")
#endif
                    {
                        point new_p = point_reference_fast(local_coeff.first);
                        if (new_p.is_zero()) continue;
                        if (new_p.s_number() == 1) { // it can send to sector 1???
                            cout << "Incorrect internal symmetry for " << p << endl;
                            cout << "Sending to " << new_p << endl;
                            abort();
                        }

                        if ((new_p.s_number() != p.s_number())) { // internal symmetry should not map to another sector of same level?
                            if (new_p.level() >= p.level()) {
                                cout << "Incorrect internal symmetry for " << p << endl;
                                cout << "Sending to " << new_p << endl;
                                abort();
                            }
                        }
                        mon.emplace_back(new_p, local_coeff.second);
                    }
                }

                // product ready, now sorting, joining, evaluating
                sort(mon.begin(), mon.end(), sort_pair_point_coeff_by_point);
                mon = group_equal_in_sorted(mon);
#ifndef PRIME
                normalize(mon, 0);  // symmetries are written in main thread, so no need to pass number
#endif
                if ((mon.empty()) || mon[mon.size() - 1].first != p) {
                    continue;
                    // trivial or sending higher symmetries are simply ignored
                }
                p_set(p, mon, 2 * sector_level);
                ++result;
            }
        }
    }
    return result;
}


point_fast lowest_in_sector_orbit_fast(const point_fast &p, SECTOR s, const vector<vector<vector<t_index> > > &sym) {
    point_fast result = p;
    for (const auto &values : sym) {
        const vector<t_index> &permutation = values[0];
        point_fast p_new;

        for (unsigned int i = 0; i != common::dimension; ++i) { p_new.buf[i] = p.buf[permutation[i] - 1]; }

        // we only use the first part of symmetries, but I do not even know whether the other parts used to work properly
        // part 3 can be added only at parser time and means something related to part 2 = conditional symmetries
        // part 1 i odd symmetries, but they did not work properly even in earlier versions

        // now we need to compare the points and choose the lowest
        if ((p_new.sector_fast() == s) && point_fast_smaller_in_sector(p_new, result, s)) {
            result = p_new;
        }
    }
    return result;
}


/**
 * Comparison functor - to compare ibps applied in a sector according to the current ordering
 * Assumes that every ibp is internally sorted with first being biggest
 */
struct ibp_comparator {
    SECTOR s; ///< sector passes to the comparator
    /**the internal comparator; compares highest term shifts from the corner
    * @param lhs first vector
    * @param rhs first vector
    * @return compare result, true if second is smaller
    */
    bool operator()(const vector<pair<vector<COEFF>, point_fast > >& lhs, const vector<pair<vector<COEFF>, point_fast > >& rhs) {
        auto& v1 = lhs[0].second;
        auto& v2 = rhs[0].second;
        if (vector_smaller_in_sector(v2,v1,s)) return true;
        if (vector_smaller_in_sector(v1,v2,s)) return false;
        return lhs.size()<rhs.size();
    }
} ibpcompare; ///< Instance of ibp_comparator.


unsigned int sort_ibps(const point &p, const set<pair<unsigned int, unsigned int> > &current_levels,
                       vector<pair<point, pair<point_fast, unsigned short> > > &ibps_vector,
                       const vector<point_fast> &IBPdegree,
                       const vector<point_fast> &IBPdegreeFull) {

    point_fast p_fast(p);
    SECTOR sector = p_fast.sector_fast();
    set<point_fast> s_fast;
    for (const auto &current_level : current_levels) {
        const unsigned int pos = current_level.first;
        const unsigned int neg = current_level.second;
        set<point_fast> s0 = level_points_fast(p_fast, pos, neg);
        for (const auto &fp : s0) { s_fast.insert(fp); }
        if (neg == 1) {
            set<point_fast> s2 = level_points_fast(p_fast, pos, 0);
            for (const auto &fp : s2) s_fast.insert(fp);
        }
        if (pos == 1) {
            set<point_fast> s2 = level_points_fast(p_fast, 0, neg);
            for (const auto &fp : s2) s_fast.insert(fp);
        }
        if ((neg == 1) && (pos == 1)) {
            set<point_fast> s2 = level_points_fast(p_fast, 0, 0);
            for (const auto &fp : s2) s_fast.insert(fp);
        }
    }

    if (common::symmetries.size() > 1) {  //there are symmetries
        vector<vector<vector<t_index> > > &sym = common::symmetries;
        set<point_fast> s_new_fast;

        // now taking only lowest in orbits
        for (const auto &fp : s_fast) {
            s_new_fast.insert(lowest_in_sector_orbit_fast(fp, sector, sym));
        }
        s_fast = s_new_fast;
    }

    ibps_vector.reserve(s_fast.size() * IBPdegree.size());
    unsigned int counter = 0;

    for (const auto &fp : s_fast) {
        point_fast deg = fp.degree();
        for (unsigned int i = 0; i != IBPdegree.size(); ++i) {
            vector<pair<point, COEFF> > terms;
            point_fast highest_fast;
            for (unsigned short j = 0; j != common::dimension; ++j) {
                highest_fast.buf[j] = fp.buf[j] + IBPdegreeFull[i].buf[j];
            }
            SECTOR bit = 1u << (common::dimension - 1);
            for (unsigned int j = 0; j < common::dimension; ++j, bit >>= 1) {
                if (sector & bit) {
                    if (highest_fast.buf[j] <= 0) highest_fast.buf[j] = 1;
                } else {
                    if (highest_fast.buf[j] > 0) highest_fast.buf[j] = 0;
                }
            }
            ibps_vector.emplace_back(point(highest_fast), make_pair(fp, static_cast<unsigned short>(i)));
            ++counter;
            if (!common::all_ibps) {
                if (over_fast(deg, IBPdegree[i])) break;
            }
        }
    }
    sort(ibps_vector.begin(), ibps_vector.end(), [](const pair<point, pair<point_fast, unsigned short> > &a,
                                                    const pair<point, pair<point_fast, unsigned short> > &b) -> bool {
        return a.first < b.first;
    });
    return counter;
};


vector<pair<unsigned int, unsigned int> > under_levels(const unsigned int p0, const unsigned int m0) {
    unsigned int p = p0;
    unsigned int m = m0;
    vector<pair<unsigned int, unsigned int> > result;
    while ((m > 0) || (p > 0)) {
        while (p > 0) {
            if ((p <= p0) && (m <= m0) && (m > 0)) {
                result.push_back(make_pair(p,m));
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

void make_master(const point &p) {
    if (common::split_masters) {
        cout<<"Unspecified master integral in masters mode: "<<p<<endl;
        abort();
    } else if (!common::silent) {
        cout << "New master integral: " << p << endl;
    }

    vector<t_index> v2 = p.get_vector();

    point p2(v2, 0, -2);
    COEFF one;
    COEFF minus_one;
#ifdef PRIME
    one.n = 1;
    minus_one.n = common::prime - 1;
#else
    one.s = "1";
    minus_one.s = "-1";
#endif
    vector<pair<point, COEFF> > t;
    if (!common::split_masters) t.emplace_back(p2, one);
    t.emplace_back(p, minus_one);
    p_set(p, t, 127, p.s_number());
}


void mark_master_integrals(const point &Corner, const unsigned int pos, const unsigned int neg) {
    SECTOR s = point_fast(Corner).sector_fast();
    if ((pos > 0) && (neg > 0)) {
        set<point_fast> p_refs_fast = level_points_fast(point_fast(Corner), pos - 1, neg - 1);
        // now taking lower orbit values
        if (common::symmetries.size() > 1) {  //there are symmetries
            vector<vector<vector<t_index> > > &sym = common::symmetries;
            set<point_fast> p_refs_fast_new;
            // now taking only lowest in orbits
            for (const auto &fp : p_refs_fast) {
                point_fast lowest = lowest_in_sector_orbit_fast(fp, s, sym);
                p_refs_fast_new.insert(lowest);
            }
            p_refs_fast = p_refs_fast_new;
        }
        for (const auto &fp : p_refs_fast) {
            point p = point(fp, s);
            if (p_is_empty(p)) {
                make_master(p);
            }
        }
    }
}


/**
 * Functor for comparing levels of points (using dots and numerators).
 */
struct level_smaller {
    /**the internal comparator; levels are compared by their sums (total shift from the corner), in case of equal the priority is to have less dots
    * @param lhs first level
    * @param rhs first level
    * @return compare result, true if first is smaller
    */
    bool operator()(const pair<unsigned int, unsigned int> &lhs, const pair<unsigned int, unsigned int> &rhs) const {
        if (lhs.first + lhs.second < rhs.first + rhs.second) return true;
        if (lhs.first + lhs.second > rhs.first + rhs.second) return false;
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


void add_needed(map<sector_count_t, set<point> > &needed_lower, const point &p) {
    sector_count_t new_sector = p.s_number();
    auto itr = needed_lower.find(new_sector);
    if (itr == needed_lower.end()) {
        set<point> s;
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


/**
 * Finish calculations in sector, save results in database and print statistics.
 * @param needed_lower_temp set in integrals at are needed in lower sectors and should be written to corresponding databases
 * @param test_sector sector we work in
 */
void finish_sector(const set<point> &needed_lower_temp, sector_count_t test_sector) {
    if (!needed_lower_temp.empty()) {
        void *points = malloc(sizeof(point) * needed_lower_temp.size());
        if (!points) {
            cout<<"Cannot malloc in finish_sector"<<endl;
            abort();
        }
        int i = 0;
        for (auto sitr = needed_lower_temp.begin(); sitr != needed_lower_temp.end(); ++sitr, ++i) {
            reinterpret_cast<point*>(points)[i] = *sitr;
        }

        if (!common::points[test_sector]->set("lower", 5, static_cast<const char *>(points), needed_lower_temp.size() * sizeof(point))) {
            cout << "Can't write in finish_sector" << endl;
            abort();
        }
        free(points);
    }

    common::points[test_sector]->increment(string("eqs_max"), used_number_sector_total, INT64_MAX);
    common::points[test_sector]->increment(string("eqs_tot"), eqs_number_sector_total, INT64_MAX);

    // INT64_MAX means override anyway
    common::points[test_sector]->increment(string("lower_size"), needed_lower_temp.size(), INT64_MAX);

    process_mem_usage(true);
    common::points[test_sector]->increment(string("mem_vsi"), max_vsize, INT64_MAX);
    common::points[test_sector]->increment(string("mem_rss"), max_rss, INT64_MAX);

    close_database(test_sector);

    auto thread_stop_time = chrono::steady_clock::now();

    if (!common::silent) {
        cout << "fuel/total reduction time in sector " << test_sector << ": "
            << chrono::duration_cast<chrono::duration<float>>(chrono::microseconds(common::fuel_time)).count() << "/"
            << chrono::duration_cast<chrono::duration<float>>(thread_stop_time - thread_start_time).count() << endl;
        cout << "Memory usage by sector " << test_sector << " (virtual|resident): ";
    }
    print_memory(max_vsize, 0);
    if (!common::silent) {
        cout << " | ";
    }
    print_memory(max_rss, 1);
    if (!common::silent) {
        cout << endl;
    }

    //set_needed_lower_sector is not currently used, but it could be another entry
    if (common::cpath != "") {
        copy_database(test_sector, false);
    }
}

void add_ibps(const COEFF& first_mul, const COEFF& second_mul, const ibp_type& first, const ibp_type& second, const SECTOR sector_fast, ibp_type& result) {
    result.clear();
    result.reserve(first.size()+second.size());
    unsigned int i=0;
    unsigned int j=0;
    while (i+j != first.size()+second.size()) {
        if ((j == second.size()) || (((i != first.size())) && vector_smaller_in_sector(second[j].second,first[i].second,sector_fast))) {
            // second does not exist or i is bigger
            vector<COEFF> mult = first[i].first;
            for (COEFF &c : mult) c = first_mul*c;
            result.emplace_back(mult,first[i].second);
            ++i;
        } else if ((i == first.size()) || (((j != second.size())) && vector_smaller_in_sector(first[i].second,second[j].second,sector_fast))) {
            // first does not exist or j is bigger
            vector<COEFF> mult = second[j].first;
            for (COEFF &c : mult) c = COEFF()-second_mul*c;
            result.emplace_back(mult,second[j].second);
            ++j;
        } else {
            // they are equal
            vector<COEFF> added;
            added.reserve(common::dimension + 1);
            bool has_nonzero = false;
            for (int k = 0; k!=common::dimension + 1; ++k) {
                COEFF c = first_mul*first[i].first[k] - second_mul*second[j].first[k];
                #ifndef PRIME
                    calc_wrapper(c.s,0);
                #endif
                if (!c.empty()) has_nonzero = true;
                added.push_back(c);
            }
            if (has_nonzero) {
                result.emplace_back(added,first[i].second);
            }
            ++i;
            ++j;
        }
    }
}

int matching_index(const vector<COEFF>& first, const vector<COEFF>& second) {
    int matching_index = -1;
    for (int k = 0; k!=common::dimension + 1; ++k) {
        if ((!first[k].empty()) || (!second[k].empty())) {
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

void improve_ibps(vector<ibp_type>& ibps,SECTOR sector_fast) {
    for (auto& ibp: ibps) {
        sort(ibp.begin(),ibp.end(), [&sector_fast](const pair<vector<COEFF>, point_fast > &a,
                                                    const pair<vector<COEFF>, point_fast > &b) -> bool {
            return vector_smaller_in_sector(b.second, a.second, sector_fast);
        });
    }
    // sorting each ibp, first are biggest

    if (common::disable_presolve) return;

    ibpcompare.s = sector_fast;
    sort(ibps.begin(), ibps.end(), ibpcompare);
    point_fast zero_point{};

    for (unsigned int i = 0; i!=ibps.size(); ++i) {
        //forward pass
        for (unsigned int j = i + 1; j!=ibps.size(); ++j) {
            if (ibps[i][0].second != ibps[j][0].second) {
                break;
            }
            int index = matching_index(ibps[i][0].first,ibps[j][0].first);
            if (index >= 0) {
                // only one index coeff differs
                // need to add i to j
                COEFF mul_i = ibps[j][0].first[index];
                COEFF mul_j = ibps[i][0].first[index];
                ibp_type res;
                add_ibps(mul_i, mul_j, ibps[i], ibps[j], sector_fast, res);
                // now res is the new relation that should replace j
                if (res.empty()) {
                    ibps.erase(ibps.begin()+j);
                } else if (res[0].second == zero_point) {
                    // we should not result in ibps with zero top shift since in can have cancelling coefficients!
                    ++j;
                } else {
                    ibps[j] = res;
                    sort(ibps.begin() + j, ibps.end(), ibpcompare);
                }
                --j;
            }
        }
    }
}


/* main worker in a sector
* tries different methods
* such as searching for an sbasis or lbases
* if nothing uses Laporta
*/
void forward_stage(unsigned short thread_number, sector_count_t ssector_number) {
    if (!common::silent) {
        cout << "STARTING THREAD " << thread_number << " for {" << common::global_pn << ",";
    }
    print_vector(common::ssectors[ssector_number]);
    if (!common::silent) {
        cout << "} " << ssector_number << endl;
    }

    //  thread number is now purely for printing information
    thread_start_time = chrono::steady_clock::now(); // laporta in sector
    open_database(ssector_number);

    if (common::wrap_databases) {
        remove((common::path + int2string(ssector_number) + ".tmp").c_str());
    }

    set<point> set_needed_lower;
    set<sector_count_t> set_needed_lower_sector;

    vector<t_index> ssector = common::ssectors[ssector_number];
    unsigned short sector_level = static_cast<unsigned short>(std::count_if(ssector.begin(), ssector.end(),
            [&](const t_index &elem) {
                return elem == 1;
            }));

    auto *pdb = common::points[ssector_number];

    class VisitorImpl : public kyotocabinet::DB::Visitor {
        // call back function for an existing record
        const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz, size_t *sp) override {
            if (ksiz < sizeof(point)) {
                return NOP;
            }
            const point& test = *reinterpret_cast<const point *>(kbuf);
            if ((test.virt()) || (test.s_number() != sector)) {
                return NOP;
            }
            if (vbuf[2] > 2 * sector_level) {
                needed.insert(test);
            }
            // if it is a lower sector that is needed for a symmetry sector, it surely happens
            // if it is a higher symmetry sector it is also ok, because they are never needed for their level, only for higher
            return NOP;
        }

        // call back function for an empty record space
        const char *visit_empty(const char *kbuf, size_t ksiz, size_t *sp) override {
            return NOP;
        }

    public:
        set<point> needed;
        sector_count_t sector{};
        unsigned short sector_level{};
    } visitor;

    visitor.sector_level = sector_level;
    visitor.sector = ssector_number;

    if (!pdb->iterate(&visitor, false)) {
        cout << "Iterate error on Laporta start: " << ssector_number << endl;
        abort();
    }

    set<point> *needed = &visitor.needed;
    point Corner = point_reference(corner(ssector));
    unsigned int n = ssector.size();
    bool first_pass = true;

    while (!needed->empty()) {
        set<point, indirect_more> ivpl;
        set<point>::iterator ivpl_counter;
        {
            for (const auto &read : *needed) {
                ivpl.insert(read);
            }
            bool done = true;
            for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                point p = *ivpl_counter;
                vector<point> monoms = p_get_monoms(p);
                if (!monoms.empty()) {
                    for (const auto &monom : monoms) {
                        if (monom.s_number() == ssector_number) {
                            ivpl.insert(ivpl_counter, monom);
                        }
                    }
                } else {
                    done = false;
                    break;
                }
            }
            if (done) {
                if (!common::silent) {
                    cout << "Thread " << thread_number << ": nothing to do." << endl;
                }
                ivpl.clear();
                for (const auto &read : *needed) {
                    ivpl.insert(read);
                }
                for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                    point p = *ivpl_counter;
                    vector<point> monoms = p_get_monoms(p);
                    if (!monoms.empty()) {
                        for (const auto &monom : monoms) {
                            if (monom.s_number() == ssector_number) {
                                ivpl.insert(ivpl_counter, monom);
                            }
                            if (p.s_number() != monom.s_number()) {
                                set_needed_lower.insert(monom);
                                set_needed_lower_sector.insert(monom.s_number());
                            }
                        }
                    }
                }
                clear_sector(ssector_number, &ivpl);
                finish_sector(set_needed_lower, ssector_number);
                return;
            }
        }
        set<pair<unsigned int, unsigned int> > input_levels;
        set<pair<unsigned int, unsigned int> > real_input_levels;
        for (const auto &read : *needed) {
            const vector<t_index> v = read.get_vector();
            auto l = level(v);
            if (l.first == 0) {
                l.first = 1;
            }
            if (l.second == 0) {
                l.second = 1;
            }
            real_input_levels.insert(l);
            l = level(v);
            // using needed_level right here
            if (first_pass) {
                l.first = l.first + 1;
                if (l.second == 0) {
                    l.second = 1;
                }
            } else {
                l.first = l.first + 1;
                l.second = l.second + 1;
            }
            input_levels.insert(l);
            ivpl.insert(read);
        }

        // now checking for a new LBASIS
        auto litr = common::lbases.find(ssector_number);

        if (litr != common::lbases.end()) {
            if (!common::silent) {
                cout << "L-basis found." << endl;
            }
            vector<pair<vector<pair<vector<t_index>, pair<short, bool> > >, vector<pair<string, vector<pair<vector<t_index>, short> > > > > > lbasis = litr->second;
            for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                point p = *ivpl_counter;
                if (!p_is_empty(p)) {
                    continue;
                }
                vector<t_index> y = p.get_vector();
                bool made_table = false;
                for (const auto &elem : lbasis) {
                    vector<pair<vector<t_index>, pair<short, bool> > > conditions = elem.first;
                    bool satisfies = true;
                    for (const auto &condition : conditions) {
                        int sum = condition.second.first;
                        for (unsigned int i = 0; i != n; ++i) {
                            sum += (y[i] * (condition.first[i]));
                        }
                        if ((sum == 0) && condition.second.second == false) satisfies = false;
                        if ((sum != 0) && condition.second.second == true) satisfies = false;
                        if (!satisfies) {
                            break;
                        }
                    }
                    if (satisfies) { //rule satisfies all conditions
                        vector<pair<point, COEFF> > mon;
                        vector<pair<string, vector<pair<vector<t_index>, short> > > > terms = elem.second;
                        mon.reserve(terms.size());
                        map<vector<t_index>, string> local_coeffs;
                        for (const auto &term : terms) {
                            vector<t_index> new_v;
                            for (unsigned int i = 0; i != n; ++i) {
                                t_index sum = term.second[i].second;
                                for (unsigned int j = 0; j != n; ++j) {
                                    sum += (y[j] * term.second[i].first[j]);
                                }
                                new_v.push_back(sum);
                            }
                            string coeff = term.first;
                            subs2(coeff, y);
                            if (coeff != "0") {
                                auto local_coeffs_itr = local_coeffs.find(new_v);
                                if (local_coeffs_itr == local_coeffs.end()) {
                                    local_coeffs.emplace_hint(local_coeffs_itr, new_v, "(" + coeff + ")");
                                } else {
                                    local_coeffs_itr->second = local_coeffs_itr->second + "+" + "(" + coeff + ")";
                                }
                            }
                        }  // substituted all terms, joining equal
                        for (auto &&local_coeff : local_coeffs) {
                            string &ss = local_coeff.second;
                            calc_wrapper(ss, 0);   // we are not using thread number here
#ifdef PRIME
                            unsigned long long n = mod(ss);
                            char res[32];
                            sprintf(res, "%llu", n);
                            ss = string(res);
#endif
                            if (ss != "0") {
                                point new_p = point_reference(local_coeff.first);
                                if (new_p.is_zero()) {
                                    continue;
                                }
                                if (new_p.s_number() == 1) {
                                    cout << "Incorrect l-basis-rule for " << p << endl;
                                    cout << "Sending to " << new_p << endl;
                                    abort();
                                }
                                if (new_p.s_number() != p.s_number()) {
                                    if (new_p.level() >= p.level()) {
                                        cout << "Incorrect l-basis-rule for " << p << endl;
                                        cout << "Sending to " << new_p << endl;
                                        abort();
                                    }
                                }
#ifdef PRIME
                                COEFF c;
                                long long num;
                                sscanf(ss.c_str(), "%lld", &num);
                                while (num < 0) num += common::prime;
                                num %= common::prime;
                                c.n = num;
                                if (c.n) mon.emplace_back(new_p, c);
#else
                                COEFF c;
                                c.s = ss;
                                mon.emplace_back(new_p, c);
#endif
                            }
                        }
                        COEFF minus_one;
#ifdef PRIME
                        minus_one.n = common::prime - 1;
#else
                        minus_one.s = "-1";
#endif
                        mon.emplace_back(p, minus_one);
                        sort(mon.begin(), mon.end(), pair_point_COEFF_smaller);

                        if ((mon.empty()) || mon[mon.size() - 1].first != p) {
                            cout << "LBasis ordering error: " << p << " -> " << endl;
                            for (const auto &it : mon) {
                                cout << it.first << ", " << endl;
                            }
                            abort();
                        }
                        made_table = true;
                        p_set(p, mon, 2 * sector_level);
                        for (unsigned int j = 0; j != mon.size(); ++j) {
                            if (p.s_number() != mon[j].first.s_number()) {
                                set_needed_lower.insert(mon[j].first);
                                set_needed_lower_sector.insert(mon[j].first.s_number());
                            }
                            if ((mon[j].first != p) && (mon[j].first.s_number() == ssector_number)) {
                                ivpl.insert(ivpl_counter, mon[j].first);
                            }
                        }
                        break;
                    }  // if satisfies
                } // rule cycle
                if (!made_table) {
                    make_master(p);
                }
            }
            clear_sector(ssector_number, nullptr);
            finish_sector(set_needed_lower, ssector_number);
            return;
        }

        // should not we change ivpl to point_fast ???
        auto ditr = point::dbases.find(ssector_number);
        if (ditr != point::dbases.end()) {
            pair<vector<t_index>, vector<pair<vector<pair<COEFF, point_fast> >, t_index> > > dbasis = ditr->second;
            if (!common::silent) {
                cout << "L-symmetry found." << endl;
            }
            for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                point p = *ivpl_counter;
                if (!p_is_empty(p)) continue;
                point_fast y = point_fast(p);
                list<vector<pair<COEFF, point_fast> > > product;
                point_fast new_y;
                for (unsigned int j = 0; j != n; j++) {
                    if (dbasis.first[j] == 0) {
                        new_y.buf[j] = 0;
                    } else {
                        new_y.buf[j] = y.buf[dbasis.first[j] - 1];
                    }
                }
                vector<pair<COEFF, point_fast> > new_term;
                COEFF c1;
#ifdef PRIME
                c1.n = 1;
#else
                c1.s = "1";
#endif
                new_term.emplace_back(c1, new_y); // we start building a product of sums. first term is without sum
                product.push_back(new_term);

                for (const auto &pitr : dbasis.second) {
                    int power = -y.buf[pitr.second - 1];
                    if (power < 0) {
                        cout << "Wrong delayed rule: " << p << endl;
                        abort();
                    }
                    for (int j = 0; j != power; j++) {
                        product.push_back(pitr.first);  // product is created from lbases. coefficients are strings
                    }
                }

                map<point_fast, COEFF> local_coeffs = calculate_product(product,
                                                                        n); // this is a shared function in external and internal symmetry generation

                // let's add -y right here
                auto itr = local_coeffs.find(y);
                if (itr == local_coeffs.end()) {
                    COEFF c;
#ifdef PRIME
                    c.n = common::prime - 1;
#else
                    c.s = "-1";
#endif
                    local_coeffs.insert(make_pair(y, c));
                } else {
#ifdef PRIME
                    if (itr->second.n)
                        itr->second.n = (itr->second.n - 1) % common::prime;
                    else
                        itr->second.n = (common::prime - 1);
#else
                    itr->second.s = itr->second.s + " -1";
#endif
                }

                vector<pair<point, COEFF> > mon;
                mon.reserve(local_coeffs.size());

                for (const auto &local_coeff : local_coeffs) {
#ifdef PRIME
                    if (local_coeff.second.n != 0)
#else
                    if (local_coeff.second.s != "0")
#endif
                    {
                        point new_p = point_reference_fast(local_coeff.first);
                        if (new_p.is_zero()) {
                            continue;
                        }
                        if (new_p.s_number() == 1) {
                            cout << "Incorrect l-rule for " << p << endl;
                            cout << "Sending to " << new_p << endl;
                            abort();
                        }
                        if ((new_p.s_number() == p.s_number()) && (new_p != p)) {
                            cout << "Incorrect l-rule for " << p << endl;
                            cout << "Sending to " << new_p << endl;
                            abort();
                        }
                        if (new_p.s_number() != p.s_number()) {
                            if (new_p.level() > p.level()) {
                                cout << "Incorrect l-rule for " << p << endl;
                                cout << "Sending to " << new_p << endl;
                                abort();
                            }
                            if (new_p.level() == p.level()) {
                                if (common::lsectors.find(sector_fast(new_p.get_vector())) == common::lsectors.end()) {
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
                sort(mon.begin(), mon.end(), sort_pair_point_coeff_by_point);
                mon = group_equal_in_sorted(mon);
                if ((mon.empty()) || mon[mon.size() - 1].first != p) {
                    cout << "LSymmetry ordering error: " << p << " -> " << endl;
                    for (const auto &it : mon) {
                        cout << it.first << ", " << endl;
                    }
                    abort();
                }

                p_set(p, mon, 2 * sector_level + 1);
                for (unsigned int j = 0; j != mon.size(); ++j) {
                    if (p.s_number() != mon[j].first.s_number()) {
                        set_needed_lower.insert(mon[j].first);
                        set_needed_lower_sector.insert(mon[j].first.s_number());
                    }
                    if ((mon[j].first != p) && (mon[j].first.s_number() == ssector_number)) {
                        ivpl.insert(ivpl_counter, mon[j].first);
                    }
                }
            } // writing symmetry done
            clear_sector(ssector_number, nullptr);
            finish_sector(set_needed_lower, ssector_number);
            return;
        }

        // ok, back to Laporta
        if (!common::silent) {
            cout << "Thread " << thread_number << " requested: ";
            for (const auto &current_level : real_input_levels) {
                cout << "(" << current_level.first << "," << current_level.second << ") ";
            }
            cout << endl;
        }

        set<pair<unsigned int, unsigned int>, level_smaller> levels;
        for (const auto &input_level : input_levels) {
            auto here_levels = under_levels(input_level.first, input_level.second);
            for (const auto &current_level : here_levels) {
                char buf[128];
                sprintf(buf, "$USED_%d_%d", current_level.first, current_level.second);
                size_t size;
                char *res = common::points[ssector_number]->get(buf, strlen(buf), &size);
                if (res == nullptr) {
                    levels.insert(current_level);
                } else {
                    delete[] res;
                }
            }
        }

        if (levels.empty()) {
            if (!common::silent) {
                cout << "No levels" << endl;
            }
            finish_sector(set_needed_lower, ssector_number);
            return;
        }

        point_fast p_fast(Corner);
        SECTOR sector_fast = p_fast.sector_fast();

        auto ibps = point::ibps;
        improve_ibps(ibps,sector_fast);

        for (unsigned int i = 0; i != common::lthreads_number; ++i) {
            level_worker[i] = thread(reduce_in_level, Corner, ibps, i);
        }

        auto itr = levels.begin();

        for (unsigned int current_sum = 2; (itr != levels.end()); ++current_sum) {
            set<pair<unsigned int, unsigned int> > current_levels;
            while ((itr != levels.end()) && (((*itr).first) + ((*itr).second) <= current_sum)) {
                current_levels.insert(*itr);
                ++itr;
            }
            if (current_levels.empty()) {
                continue;
            }

            // time to check if database reopen is needed
            int64_t entries = common::points[ssector_number]->count();
            if (2 * entries > common::buckets_full[ssector_number]) {
                common::buckets[ssector_number]++;
                reopen_database(ssector_number);
            }

            if (!common::silent) {
                cout << "Thread " << thread_number << " (sector " << ssector_number << "): ";
                for (const auto &current_level : current_levels) {
                    cout << "(" << current_level.first << "," << current_level.second << ") ";
                }
                cout << endl;
            }

            auto start_time = chrono::steady_clock::now();

            int symmetries = 0;
            if (common::pos_pref) {
                for (const auto &current_level : current_levels) {
                    if (common::pos_pref > 0) {
                        if ((current_level.first <= static_cast<unsigned int>(abs(common::pos_pref))) && (current_level.second == 1)) {
                            symmetries += write_symmetries(Corner, current_level.first, current_level.second, sector_level);
                        }
                    } else {
                        if ((current_level.first == 1) && (current_level.second <= static_cast<unsigned int>(abs(common::pos_pref)))) {
                            symmetries += write_symmetries(Corner, current_level.first, current_level.second, sector_level);
                        }
                    }
                }
            }
            if (symmetries != 0) {
                if (!common::silent)
                    cout << "Thread " << thread_number << ", sector " << ssector_number << ": wrote " << symmetries
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
                level_done_cond.wait(guard,[](){return level_tasks_count==0;}); // waiting for all work to be done
            }

            auto stop_time = chrono::steady_clock::now();

            if (!common::silent) {
                cout << "Thread " << thread_number << " (sector " << ssector_number << "): ";
                cout << "Equations: " << eqs_number_sector_level << ", ";
                cout << "used: " << used_number_sector_level << ", ";
                cout << "reduction time: " << chrono::duration_cast<chrono::duration<float>>(stop_time - start_time).count() << endl;
            }

            eqs_number_sector_total += eqs_number_sector_level;
            used_number_sector_total += used_number_sector_level;

            for (const auto &current_level : current_levels) {
                char buf[128];
                sprintf(buf, "$USED_%d_%d", current_level.first, current_level.second);
                common::points[ssector_number]->set(buf, strlen(buf), "True", 4);
                if (common::pos_pref > 1 && current_level.first == 1 && current_level.second == 1 && levels.size() > 1) {
                    // do not mark corner
                } else if (common::pos_pref > 1 && current_level.first + current_level.second == 3) {
                    mark_master_integrals(Corner, 1, 1);
                    mark_master_integrals(Corner, current_level.first, current_level.second);
                } else {
                    mark_master_integrals(Corner, current_level.first, current_level.second);
                }
            }

            ivpl.clear();
            for (const auto &read : *needed) {
                ivpl.insert(read);
            }
            bool done = true;
            for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                point p = *ivpl_counter;
                vector<point> monoms = p_get_monoms(p);
                if (!monoms.empty()) {
                    for (const auto &monom : monoms) {
                        if (monom.s_number() == ssector_number) {
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
                level_stop = true;
                level_cond.notify_all();// signal level threads to get them out of waiting
                for (unsigned int i = 0; i != common::lthreads_number; ++i) {
                    level_worker[i].join();
                }

                ivpl.clear();
                for (const auto &read : *needed) {
                    ivpl.insert(read);
                }
                for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
                    point p = *ivpl_counter;
                    vector<point> monoms = p_get_monoms(p);
                    if (!monoms.empty()) {
                        for (const auto &monom : monoms) {
                            if (monom.s_number() == ssector_number) {
                                ivpl.insert(ivpl_counter, monom);
                            }
                            if (p.s_number() != monom.s_number()) {
                                set_needed_lower.insert(monom);
                                set_needed_lower_sector.insert(monom.s_number());
                            }
                        }
                    } else {
                        make_master(p);
                    }
                }
                clear_sector(ssector_number, &ivpl);
                finish_sector(set_needed_lower, ssector_number);
                return;
            }
        }

        if (!common::silent) {
            cout << "Thread " << thread_number << ": ";
            cout << "FAILED TO RESOLVE ALL INTEGRALS, INCREASING LEVELS." << endl;
        }

        ivpl.clear();
        for (const auto &read : *needed) {
            ivpl.insert(read);
        }

        for (ivpl_counter = ivpl.begin(); ivpl_counter != ivpl.end(); ++ivpl_counter) {
            point p = *ivpl_counter;
            vector<point> monoms = p_get_monoms(p);
            if (!monoms.empty()) {
                for (const auto &monom : monoms) {
                    if (monom.s_number() == ssector_number) {
                        ivpl.insert(ivpl_counter, monom);
                    }
                }
            } else {
                needed->insert(p);
            }
        }

        // we can stop the level queues here
        level_stop = true;
        level_cond.notify_all();  // signal level threads to get them out of waiting
        for (unsigned int i = 0; i != common::lthreads_number; ++i) {
            level_worker[i].join();
        }
        level_stop = false;
        first_pass = false;
    }
    finish_sector(set_needed_lower, ssector_number);
}

/**
 * Function that compares two equations.
 * @param lhs first equation
 * @param rhs second equation
 * @return true if lhs is less than rhs, false otherwise.
 */
bool equations_less(const equation *lhs, const equation *rhs) {
    int i = lhs->length;
    int j = rhs->length;
    while ((i != 0) && (j != 0)) {
        const point &p1 = lhs->terms[i - 1]->p;
        const point &p2 = rhs->terms[j - 1]->p;
        if ((p1) < (p2)) return true;
        if ((p2) < (p1)) return false;
        --i;
        --j;
    }
    return (j!=0);
}


void reduce_in_level(point Corner, vector<ibp_type> ibps, unsigned int thread_number) {
    sector_count_t ssector_number = Corner.s_number();

    vector<t_index> v = Corner.get_vector();
    point_fast p_fast(Corner);
    SECTOR sector_fast = p_fast.sector_fast();

#ifndef PRIME
    unsigned short sector_level = 0;
    sector_level = static_cast<unsigned short>(std::count_if(v.begin(), v.end(),
            [&](const t_index& elem) {
                    return elem == 1;
                }));
#endif

    while (true) {
        // waiting for tasks
        unique_lock<mutex> guard(level_mutex); // we lock the mutex to access the std list and to start waiting
        level_cond.wait(guard,[](){return level_stop || !level_tasks.empty();});
        if (level_stop) {
            return; // no more levels in this sector, thread returns, mutex unlocked
        }

        set<pair<unsigned int, unsigned int> > current_levels;
        current_levels.insert(level_tasks.front()); // we take the first task from the queue
        level_tasks.pop_front(); // and pop it from the queue

        guard.unlock(); // let other threads have jobs

        fstream out;
        fstream in;
        char readbuf[128];
        bool hint_exists = false;
        char buf[256];
        // we are expecting length 1 in current_levels now, keeping multiple for easy checks
        if (common::hint) {
            snprintf(buf, 256, "%s-%d-{%u,%u}.m", common::hint_path.c_str(), int(ssector_number),
                    current_levels.begin()->first, current_levels.begin()->second);
            in.open(buf, fstream::in);
            if (in.good()) {
                hint_exists = true;
                in.getline(readbuf, 64);
                if (strcmp(readbuf, "{") != 0) {
                    cout << "incorrect hint" << endl;
                    abort();
                }//}
            } else {
                in.close();
                out.open(buf, fstream::out);
                out << "{" << endl;//}
            }
        }

        vector<pair<point, pair<point_fast, unsigned short> > > ibps_vector; // the first point is just for sorting by sort_ibps; when loaded from file it can be filled with empty
        unsigned int eqs_number;

        if (common::hint && hint_exists) {
            // using the hint file to create lists of ibps
            eqs_number = 0;
            ibps_vector.reserve(std::count(std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>(), '\n'));
            in.close();
            in.open(buf, fstream::in);
            in.getline(readbuf, 64);
            while (true) {
                in.getline(readbuf, 64);
                point_fast p;
                const char *pos = readbuf;
                if (*pos != '{') {
                    cout << "Wrong line start in hint;";
                    abort();
                } //}
                ++pos;
                if (*pos != '{') {
                    cout << "Wrong line start in hint;";
                    abort();
                } //}
                ++pos;
                int number;
                int i = 0;
                while (true) {
                    int move = s2i(pos, number);
                    p.buf[i] = number;
                    pos += move; //{
                    if (*pos == '}') {
                        ++pos;
                        break;
                    }
                    ++pos; // passing the comma
                    ++i;
                }
                if (*pos != ',') {
                    cout << "Wrong line middle in hint;";
                    abort();
                }
                ++pos;
                int move = s2i(pos, number);
                pos += move; //{
                if (*pos != '}') {
                    cout << "Wrong line end in hint;";
                    abort();
                }
                ++pos; //{
                ibps_vector.emplace_back(make_pair(point(), make_pair(p, number)));
                ++eqs_number;
                if (*pos == '}') break; // final closing bracket
            }
        } else {
            // preparing ibp lists
            vector<point_fast> IBPdegree;
            vector<point_fast> IBPdegreeFull;

            for (const auto &ibp : ibps) {
                // we fill IBPdegree, sscc and mm based of ibps
                point_fast p;
                point_fast ah = ibp[0].second;
                SECTOR bit = 1u << (common::dimension - 1);
                for (unsigned int i = 0; i < common::dimension; ++i, bit >>= 1)
                    if (sector_fast & bit) {
                        p.buf[i] = max(ah.buf[i], char(0));
                    } else {
                        p.buf[i] = max(-ah.buf[i], 0);
                    }

                IBPdegreeFull.emplace_back(ah);
                IBPdegree.emplace_back(p);
            }

            eqs_number = sort_ibps(Corner, current_levels, ibps_vector, IBPdegree, IBPdegreeFull);
        }

        unsigned int used_number = 0;
        int print_counter = 0;
        equation **eqs = nullptr;

        if (hint_exists) {
            eqs = static_cast<equation **>(malloc(sizeof(equation *))); // no need to all this sorting if we already have a hint
            if (!eqs) {
                cout<<"Cannot malloc in reduce_in_level"<<endl;
                abort();
            }
        }
        for (vector<pair<point, pair<point_fast, unsigned short> > >::const_iterator ibps_itr = ibps_vector.begin(); ibps_itr != ibps_vector.end(); ++ibps_itr) {
            if (common::print_step != 0) {
                ++print_counter;
                if (print_counter % common::print_step == 0) {
                    if (!common::silent) {
                        cout << "Sector " << ssector_number << ": " << print_counter << "/" << eqs_number << endl;
                    }
                }
            }
            auto itr2 = ibps_itr;
            int k;
            int write;

            if (hint_exists) {
                // just generating the first equation from hint
                unsigned short i = (ibps_itr)->second.second;
                const point_fast &p = (ibps_itr)->second.first;
                eqs[0] = apply(ibps[i], p, sector_fast, thread_number);
                write = 1; //there is just one equation
            } else { // moving until the highest member is changed
                int dist = 0;
                write = 0;
                while ((itr2 != ibps_vector.end()) && (itr2->first == ibps_itr->first)) {
                    ++itr2;
                    ++dist;
                }
                eqs = static_cast<equation **>(malloc(sizeof(equation *) * dist)); // with same highest member
                if (!eqs) {
                    cout<<"Cannot malloc in reduce_in_level"<<endl;
                    abort();
                }
                for (k = 0; k != dist; ++k) {
                    unsigned short i = (ibps_itr + k)->second.second;
                    const point_fast &p = (ibps_itr + k)->second.first;
                    eqs[write] = nullptr;
                    // apply will call new
                    eqs[write] = apply(ibps[i], p, sector_fast, thread_number);
                    // generating
                    if (eqs[write]) {
                        eqs[write]->source = (ibps_itr + k)->second;
                        ++write;
                    }
                }
                sort(eqs, eqs + write, equations_less); // sorting those with same highest member
            }

            for (k = 0; k != write; ++k) {  //cycle of same starting point

#ifdef PRIME

                list<pair<point, COEFF>, ALLOCATOR2 > result;
                for (unsigned int i = 0; i != eqs[k]->length; ++i) {
                    result.emplace_back(make_pair(eqs[k]->terms[i]->p, eqs[k]->terms[i]->c));
                }

                list<list<pair<point, COEFF>, ALLOCATOR2> > to_substitute;
                //list<vector<pair<point, COEFF> > > to_substitute;

                for (auto itr = result.rbegin(); itr != result.rend(); ++itr) {
                    const point &p = itr->first;
                    if ((p.s_number() < ssector_number) ||
                        (p.virt()) ||
                        (p.s_number() == 1)) {
                        break; // no need to touch lower
                    } else {
                        list<pair<point, COEFF>, ALLOCATOR2> terms2l;
                        p_get(p, terms2l, ssector_number);
                        if (terms2l.empty()) {
                            continue;
                        } else {
                            uint128_t num, denum;
                            num = itr->second.n;
                            denum = terms2l.back().second.n;
                            num = common::prime - num;
                            denum = mul_inv(denum, common::prime);
                            num = (num * denum) % common::prime;
                            COEFF c;
                            c.n = num;
                            add_to(result, terms2l, c, true); // last term still stays here
                            result.erase(next(itr--).base());
                            to_substitute.emplace_front(terms2l);
                            if (result.empty()) break;
                        }
                    }
                }

                // let's write the table for the current equation if needed
                if (!result.empty()) {
                    const point &p = result.rbegin()->first;
                    if ((p.s_number() == ssector_number) && (!p.virt())) {
                        split(result, ssector_number);
                        if (common::hint && !hint_exists) {
                            unsigned short i = eqs[k]->source.second;
                            point_fast &p = eqs[k]->source.first;
                            if (used_number) out << "," << endl;
                            out << "{{";
                            for (unsigned j = 0; j + 1 != common::dimension; ++j) {
                                out << int(p.buf[j]) << ",";
                            }
                            out << int(p.buf[common::dimension - 1]) << "}" << "," << i << "}";
                        }
                        ++used_number;
                    }
                }
                delete eqs[k];

                // preparing for backward substitution on those we encountered
                vector<list<pair<point, COEFF>, ALLOCATOR2>::iterator> to_substitute_iterators; // not to search from start each time
                to_substitute_iterators.reserve(to_substitute.size());
                for (auto itrTo = to_substitute.begin(); itrTo != to_substitute.end(); ++itrTo) {
                    to_substitute_iterators.emplace_back(itrTo->begin());
                }

                // now substituting back
                auto itrToIteraror = to_substitute_iterators.begin();
                for (auto itrTo = to_substitute.begin(); itrTo != to_substitute.end(); ++itrTo,++itrToIteraror) {
                    bool changed = false;
                    for (auto itrFrom = to_substitute.cbegin(); itrFrom != itrTo; ++itrFrom) {
                        const point& p = itrFrom -> rbegin()->first;

                        auto itrTerm = *itrToIteraror;
                        for (; itrTerm != itrTo->end(); ++itrTerm) {
                            if (p == itrTerm -> first) {
                                uint128_t num, denum;
                                num = itrTerm -> second.n;
                                denum = itrFrom -> back().second.n;
                                num = common::prime - num;
                                denum = mul_inv(denum, common::prime);
                                num = (num * denum) % common::prime;
                                COEFF c;
                                c.n = num;
                                ++itrTerm; // we move it before, or it will be invalidated
                                add_to(*itrTo, *itrFrom, c, false);
                                changed = true;
                                break;
                            } else if (p < itrTerm -> first) {
                                break; // this relation does not go there
                            }
                        }
                        *itrToIteraror = itrTerm;
                    }
                    // top point cannot be changed, so it's safe to split
                    if (changed) {
                        auto new_start = split(*itrTo, ssector_number);
                        while (itrTo->begin() != new_start) itrTo->pop_front();
                    }
                }


#else
                map<point, vector<pair<point, COEFF> >, indirect_more, ALLOCATOR1> to_test;
                for (unsigned int i = 0; i != eqs[k]->length; ++i) {
                    vector<pair<point, COEFF> > v;
                    to_test.emplace(eqs[k]->terms[i]->p, v);
                }
                bool has_high = express_and_pass_back(to_test, ssector_number, thread_number);
                if (!has_high) {
                    delete eqs[k];
                    continue;
                }

                if (common::hint && !hint_exists) {
                    unsigned short i = eqs[k]->source.second;
                    point_fast &p = eqs[k]->source.first;
                    if (used_number) out << "," << endl;
                    out << "{{";
                    for (unsigned j = 0; j + 1 != common::dimension; ++j) {
                        out << int(p.buf[j]) << ",";
                    }
                    out << int(p.buf[common::dimension - 1]) << "}" << "," << i << "}";
                }

                ++used_number;
                vector<pair<point, COEFF> > terms;
                terms.reserve(eqs[k]->length);
                for (unsigned int i = 0; i != eqs[k]->length; ++i) {
                    terms.emplace_back(eqs[k]->terms[i]->p, eqs[k]->terms[i]->c);
                }

                apply_table(terms, true, false, ssector_number, sector_level, thread_number);
                delete eqs[k];
#endif
            }
            if (!hint_exists) {
                free(eqs);
                ibps_itr = itr2;
                --ibps_itr;
            }
        } //equation cycle

        if (hint_exists) {
            free(eqs);
        }

        if (common::hint) {
            if (hint_exists) {
                in.close();
            } else { //{
                out << "}" << endl;
                out.close();
            }
        }

        eqs_number_sector_level += eqs_number;
        used_number_sector_level += used_number;

        {
            lock_guard<mutex> guard(level_mutex);
            --level_tasks_count;
        }

        level_done_cond.notify_one(); // level worker finished, need to inform
    }
}


void clear_sector(sector_count_t sn, set<point, indirect_more> *ivpl) {
    // if we do not clear, there are too many extra entries in the database for relations we started solving
    // and they hurt at the substitution stage... unless we rewrite it with finding a list of needed for higher and then building the tree
    // and since we clear, the rules points are marked as absolutely needed
    int64_t records2;
    records2 = common::points[sn]->count();
    double records2log;
    records2log = log2(records2);
    if (!common::silent) {
        cout << "Database " << sn << " has size ";
        #ifdef DISK_DB
            cout  << GBsize(realsize(sn));
        #else
            cout  << GBsize(common::points[sn]->size());
        #endif
        cout << " and " << records2 << " entries (log = " << records2log << ")" << endl;
    }
    if (common::keep_all) {
        return;
    }

    if (ivpl != nullptr) {
        auto *pdb = common::points[sn];
        class VisitorImpl : public kyotocabinet::DB::Visitor {
            // call back function for an existing record
            const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz, size_t *sp) override {
                if (ksiz < sizeof(point)) {
                    return NOP;
                }
                const point test = *reinterpret_cast<const point *>(kbuf);
                if ((ivpl->find(test) == ivpl->end()) && (!common::only_masters || vbuf[2] != 127)) {
                    // should not clean masters and absolutely needed anyway
                    return REMOVE;
                } else {
                    return NOP;
                }
            }

            // call back function for an empty record space
            const char *visit_empty(const char *kbuf, size_t ksiz, size_t *sp) override {
                return NOP;
            }

        public:
            sector_count_t sn{};
            set<point, indirect_more> *ivpl{};

        } visitor;

        visitor.sn = sn;
        visitor.ivpl = ivpl;

        if (!pdb->iterate(&visitor, false)) {
            cout << "iterate error: " << sn << endl;
            abort();
        }
    };
}


void perform_substitution(unsigned short thread_number, sector_count_t ssector_number) {

    auto start_timeP = chrono::steady_clock::now();

    if (!common::silent) cout << "THREAD " << thread_number << ": Substituting in {" << common::global_pn << ",";
    print_vector(common::ssectors[ssector_number]);
    if (!common::silent) cout << "} " << ssector_number << endl;

    open_database(ssector_number);
    if (common::wrap_databases) {
        remove((common::path + int2string(ssector_number) + ".tmp").c_str());
    }

    auto *pdb = common::points[ssector_number];
    class VisitorImpl : public kyotocabinet::DB::Visitor {
        // call back function for an existing record
        const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz, size_t *sp) override {
            if (print_step != 0) {
                ++print_counter;
                if (print_counter % print_step == 0) {
                    if (!common::silent) {
                        cout << "Thread " << thread_number << ", sector " << ssector_number << ": " << print_counter
                             << "/" << total << endl;
                    }
                }
            }
            if (ksiz < sizeof(point)) {
                return NOP;
            }
            const point test = *reinterpret_cast<const point *>(kbuf);
            if (vbuf[2] <= level) {
                return NOP;
            }
            if (test.s_number() == ssector_number) {
                s.insert(test);
            }
            return NOP;
        }

        const char *visit_empty(const char *kbuf, size_t ksiz, size_t *sp) override {
            return NOP;
        }

    public:
        int print_counter{};
        set<point, indirect_more> s;
        sector_count_t ssector_number{};
        unsigned short level{};
        int print_step{};
        int total{};
        unsigned short thread_number{};
    } visitor;

    if (common::keep_all) {
        visitor.level = (1 - in_lsectors(ssector_number)) + 2 * positive_index(common::ssectors[ssector_number]);
    } else {
        visitor.level = 0;
        // if we do not keep all entries, we just can pick all
    }
    visitor.ssector_number = ssector_number;
    visitor.print_counter = 0;
    visitor.print_step = common::print_step;
    visitor.total = pdb->count();
    visitor.thread_number = thread_number;
    if (!pdb->iterate(&visitor, false)) {
        cout << "iterate error: " << ssector_number << endl;
        abort();
    }
    set<point, indirect_more> &needed = visitor.s;
    set<point, indirect_more>::reverse_iterator ritr;
    if (common::keep_all) {
        ritr = expressed_by(needed, ssector_number);  // if all entries are kept we have to pick the remaining
    } else {
        ritr = needed.rbegin();
    }
    pass_back(needed, ritr, ssector_number);

    // clearing here
    auto stop_timeP = chrono::steady_clock::now();
    if (!common::silent) {
        cout << "THREAD " << thread_number << " (" << needed.size() << " integrals): substituted ("
             << chrono::duration_cast<chrono::duration<float>>(stop_timeP - start_timeP).count() << " seconds)." << endl;
    }

    start_timeP = stop_timeP;
    process_mem_usage(true);
    if (!common::silent) cout << "Memory by thread " << thread_number << " on substitutions: ";
    print_memory(max_vsize, 0);
    if (!common::silent) cout << " | ";
    print_memory(max_rss, 1);
    if (!common::silent) cout << endl;

    common::points[ssector_number]->increment(string("mem_vsi"), max_vsize, INT64_MAX);
    common::points[ssector_number]->increment(string("mem_rss"), max_rss, INT64_MAX);

    class ClearingVisitorImpl : public kyotocabinet::DB::Visitor {
        // call back function for an existing record
        const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz, size_t *sp) override {
            if (print_step != 0) {
                ++print_counter;
                if (print_counter % print_step == 0) {
                    if (!common::silent) {
                        cout << "Thread " << thread_number << ", sector " << ssector_number << ": " << print_counter
                             << "/" << total << endl;
                    }
                }
            }
            if (ksiz < sizeof(point)) {
                return NOP;
            }
            if (vbuf[2] <= level) {
                ++removed;
                return REMOVE;
            }
            return NOP;
        }

        const char *visit_empty(const char *kbuf, size_t ksiz, size_t *sp) override {
            return NOP;
        }

    public:
        int print_counter{};
        set<point, indirect_more> s;
        sector_count_t ssector_number{};
        unsigned short level{};
        int print_step{};
        int total{};
        int removed{};
        unsigned short thread_number{};
    } clearing_visitor;

    if (common::keep_all) {
        clearing_visitor.level = 0;
    } else {
        clearing_visitor.level = (1 - in_lsectors(ssector_number)) + 2 * positive_index(common::ssectors[ssector_number]);
        // if we do not keep all entries, we just can pick all
    }
    clearing_visitor.ssector_number = ssector_number;
    clearing_visitor.print_counter = 0;
    clearing_visitor.print_step = common::print_step;
    clearing_visitor.total = pdb->count();
    clearing_visitor.thread_number = thread_number;
    clearing_visitor.removed = 0;
    if (!pdb->iterate(&clearing_visitor, false)) {
        cout << "iterate error on clearing: " << ssector_number << endl;
        abort();
    }
    close_database(ssector_number);

    if (common::cpath != "") {
        if (common::cpath_on_substitutions) {
            copy_database(ssector_number, false);
        }
    }

    stop_timeP = chrono::steady_clock::now();
    if (!common::silent) {
        cout << "THREAD " << thread_number << " (" << needed.size() << " integrals): removed "
            << clearing_visitor.removed << " (" << chrono::duration_cast<chrono::duration<float>>(stop_timeP - start_timeP).count() << " seconds)." << endl;
        }
}


void run_child(int *pipe_from_child, int *pipe_to_child, int test_sector, int thread_ready) {
    close(pipe_from_child[0]);
    close(pipe_to_child[1]);


    char par[32][256] = {{}};
    unsigned short count = 0;

    #ifdef PRIME
        strcpy(par[count], (common::FIRE_folder + "FLAME6p").c_str());
    #else
        strcpy(par[count], (common::FIRE_folder + "FLAME6").c_str());
    #endif

    ++count;
    sprintf(par[count], "-c");
    ++count;
    strcpy(par[count], common::config_file.c_str());
    ++count;

    snprintf(par[count], sizeof(par[count]), "--calc");
    ++count;
    snprintf(par[count], sizeof(par[count]), "%s", fuel::getLibrary().c_str());
    ++count;

    if (common::variables_set_from_command_line) {
        sprintf(par[count], "--variables");
        ++count;
        sprintf(par[count], "%s", common::tables_prefix.c_str());
        ++count;
    }

    if (common::fuelOptionsString != "") {
        snprintf(par[count], sizeof(par[count]), "--calc_options");
        ++count;
        snprintf(par[count], sizeof(par[count]), "%s", common::fuelOptionsString.c_str());
        ++count;
    }

    if (common::split_masters) {
        sprintf(par[count], "--masters");
        ++count;
        sprintf(par[count], "%u-%u", common::master_number_min, common::master_number_max);
        ++count;
    }

    sprintf(par[count], "--sector");
    ++count;
    sprintf(par[count], "%d", test_sector);
    ++count;

    sprintf(par[count], "--database");
    ++count;
    sprintf(par[count], "%s", common::path.c_str());
    ++count;

    if (common::parallel_mode) {
        sprintf(par[count], "--parallel");
        ++count;
    }

    if (common::silent) {
        sprintf(par[count], "--silent");
        ++count;
    }

    sprintf(par[count], "--thread");
    ++count;
    sprintf(par[count], "%d", thread_ready);
    ++count;

    if (common::receive_from_child) {
        sprintf(par[count], "--out");
        ++count;
        sprintf(par[count], "%d", pipe_from_child[1]);
        ++count;

        sprintf(par[count], "--in");
        ++count;
        sprintf(par[count], "%d", pipe_to_child[0]);
        ++count;
    }

    //par[count][0] = '\0';
    //++count;

    char *nargv[32];
    for (int i=0; i!= count; ++i) {
        nargv[i] = reinterpret_cast<char*>(par) + (256*i);
    }

    nargv[count] = nullptr;

    int rc = execv(par[0], nargv);

    printf("CHILD LAUNCH ERROR: rc = %d, errno = %d\n", rc, errno);
    perror("execve");
    abort();
}


void watch_child(int *pipe_from_child, int *pipe_to_child, int test_sector, int thread_ready, pid_t pid) {
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
    int buf_size = 3;
    char *buf = static_cast<char *>(malloc(buf_size));
    if (!buf) {
        cout<<"Cannot malloc in watch_child"<<endl;
        abort();
    }

    while (true) {
        read_from_stream(&buf, &buf_size, stream_from_child);
        if (feof(stream_from_child)) break;
        int len;
        s2i(buf, len);
        list<pair<int, pair<point, string> > > to_submit;

        // creating list to submit
        for (int i = 0; i != len; ++i) {
            read_from_stream(&buf, &buf_size, stream_from_child);
            buf[strlen(buf) - 1] = '\0';
            string ss = (buf + sizeof(point) * 2);
            to_submit.emplace_back(thread_ready, pair<point, string>(point(buf), ss));
        }

        // submitting all
        {
            lock_guard<mutex> guard(equation::f_submit_mutex[thread_ready % common::f_queues]);
            for (const auto &itr : to_submit) {
                equation::f_jobs[(thread_ready % common::f_queues)].push_back(itr);
            }
        }

        // indicate the f workers they can start
        equation::f_submit_cond[(thread_ready % common::f_queues)].notify_all();

        // waiting for results and sending them back
        while (len != 0) {
            unique_lock<mutex> guard(equation::f_receive_mutex[thread_ready]);
            equation::f_receive_cond[thread_ready].wait(guard,[thread_ready](){return !equation::f_result[thread_ready].empty();});
            pair<point, string> res = *(equation::f_result[thread_ready].begin());
            equation::f_result[thread_ready].pop_front();
            guard.unlock();

            char rbuf[2*sizeof(point) + 1];
            rbuf[2*sizeof(point)] = '\0';
            res.first.safe_string(rbuf);

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
        cout << "Child " << test_sector << " exited abnormally" << endl << "Status: " << status << endl;
        cout << "Signaled is " << WIFSIGNALED(status) << endl;
        cout << "Signal is " << WTERMSIG(status) << endl;
        cout << "Exited is " << WIFEXITED(status) << endl;
        cout << "Stopped is " << WIFSTOPPED(status) << endl;
        cout << "Exit status is " << WEXITSTATUS(status) << endl;
        abort();
    }

    if (common::wrap_databases) {
        database_to_file_or_back(abs(test_sector), true);
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
 * Forks and creates child process, maintaining connection between main program and forked process.
 * @param thread_ready the thread number
 */
void worker_thread(unsigned short thread_ready) {
    int test_sector;
    string pid_folder = "/" + to_string(getpid());
    while (true) {
        unique_lock<mutex> guard(worker_mutex); // we lock the mutex to work with the list
        worker_cond.wait(guard,[](){return worker_stop || !worker_tasks.empty();});  // we wait until there is some job without lock
        if (worker_stop) {
            break; // time to stop
        }
        test_sector = *(worker_tasks.begin()); // take the sector to work with
        worker_tasks.pop_front(); // remove it from the queue
        guard.unlock(); // we unlock it. other threads can pick up jobs
        if ((common::cpath != "" && common::cpath != pid_folder) && (common::remote_worker)) {   // we need the file here locally
            copy_database(abs(test_sector), true);
        }
        if (common::wrap_databases) {
            database_to_file_or_back(abs(test_sector), false);
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

        pid_t pid = fork();
        if (pid == -1) {
            cout << "Error on fork" << endl;
            abort();
        } else if (pid > 0) {
            watch_child(pipe_from_child, pipe_to_child, test_sector, thread_ready, pid);
        } else {
            run_child(pipe_from_child, pipe_to_child, test_sector, thread_ready);
            // we do not get out here
        }

        if (common::remote_worker) {
            lock_guard<mutex> guard(worker_mutex); // we lock the mutex to work with the list
            remote_done_sectors.push_back(test_sector); // fill the list of done sectors for the remote
            // we unlock it. other threads can pick up jobs
        }

        auto stop_timeA = chrono::steady_clock::now();

        common::thread_time += chrono::duration_cast<chrono::microseconds>(stop_timeA - start_timeA).count();

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
void estimate_memory_usage(uint64_t* vsi, uint64_t* rss,const unsigned int count, const unsigned int threads_number) {
    if (!count) return;

    qsort(vsi, count, sizeof(uint64_t),
        [](const void *p1, const void *p2) -> int {
            auto i1 = *static_cast<const uint64_t *>(p1);
            auto i2 = *static_cast<const uint64_t *>(p2);
            if (i1 < i2) return -1;
            if (i1 > i2) return 1;
            return 0;
        });
    qsort(rss, count, sizeof(uint64_t),
        [](const void *p1, const void *p2) -> int {
        auto i1 = *static_cast<const uint64_t *>(p1);
        auto i2 = *static_cast<const uint64_t *>(p2);
        if (i1 < i2) return -1;
        if (i1 > i2) return 1;
        return 0;
    });

    uint64_t vsi_tot = 0;
    uint64_t rss_tot = 0;

    for (size_t i = ((count < threads_number) ? 0 : (count - threads_number)); i != count; ++i) {
        vsi_tot += vsi[i];
        rss_tot += rss[i];
    }

    process_mem_usage(true);
    if (!common::silent) cout << "Memory by main thread (virtual|resident): ";
    print_memory(max_vsize, 0);
    if (!common::silent) cout << " | ";
    print_memory(max_rss, 1);
    if (!common::silent) cout << endl << "Thread memory usage estimation by top " << threads_number << " sectors (virtual|resident): ";

    print_memory(vsi_tot, 0);
    if (!common::silent) cout << " | ";
    print_memory(rss_tot, 1);
    if (!common::silent) cout << endl;

    if (max_vsize > max_vsi_main) max_vsi_main = max_vsize;
    if (max_rss > max_rss_main)   max_rss_main = max_rss;
    if (vsi_tot > max_vsi_est)    max_vsi_est = vsi_tot;
    if (rss_tot > max_rss_est)    max_rss_est = rss_tot;
}


void Evaluate() {
    unsigned long long eqs_total{};
    unsigned long long eqs_used{};

    for (unsigned int i = 0; i != common::threads_number; ++i) {
        worker[i] = thread(worker_thread, i);
    }
    int last_level = common::abs_max_level;

    auto start_time = chrono::steady_clock::now();

    // forward reduction level by level
    while (last_level >= common::abs_min_level) {
        int inlsectors = 1;
        while (inlsectors != -1) {
            bool inlsectorsbool = (inlsectors == 0);
            inlsectors--;

            // list of sectors of this level
            set<sector_count_t> sector_set_this_level;
            set<sector_count_t>::reverse_iterator sector_set_this_level_itr;
            for (sector_count_t test_sector = 2; test_sector <= common::abs_max_sector; ++test_sector) {
	      
                vector<t_index> ssector = common::ssectors[test_sector];

                unsigned short current_level = static_cast<unsigned short>(std::count_if(ssector.begin(), ssector.end(),
                        [&](const t_index &elem) {
                            return elem == 1;
                        }));

                if (!common::sector_numbers_fast[sector_fast(ssector)]) continue;

                if ((inlsectorsbool == in_lsectors(test_sector)) && (current_level == last_level) &&
                    database_exists(test_sector)) {
                    sector_set_this_level.insert(test_sector);
                }
            }

            if (!common::silent) {
                cout << "STARTING LEVEL " << last_level << "." << inlsectors + 1 << endl;
            }

            {
                lock_guard<mutex> guard(worker_mutex);
                for (sector_set_this_level_itr = sector_set_this_level.rbegin();
                    sector_set_this_level_itr != sector_set_this_level.rend(); ++sector_set_this_level_itr) {
                        worker_tasks.push_back(*sector_set_this_level_itr);  // we created the list of jobs
                        ++distributed_sectors; //distributing tasks
                    }
            }

            worker_cond.notify_all(); // we told the workers they can start

            {
                unique_lock<mutex> guard(worker_mutex);
                worker_done_cond.wait(guard,[](){return distributed_sectors==0;}); // we need to wait until all are ready
            }

            // here we will be writing the integral requests into lower sector databases
            map<sector_count_t, set<point> > needed_lower;

            // let's estimate memory usage during level
            uint64_t vsi[1024];
            uint64_t rss[1024];
            size_t count = 0;

            for (sector_set_this_level_itr = sector_set_this_level.rbegin(); sector_set_this_level_itr != sector_set_this_level.rend(); ++sector_set_this_level_itr) {
              sector_count_t test_sector = (*sector_set_this_level_itr);

                // first we need the needed list from each higher level database and add it to the map
                if (common::wrap_databases) {
                    database_to_file_or_back(test_sector, false, false); // do not remove from storage
                }
                open_database(test_sector);

                // we want to read out the original entry;
                int64_t new_size = common::points[test_sector]->increment(string("lower_size"), 0, INT64_MIN);

                if (new_size > 0) {
                    char *points = static_cast<char *>(malloc(sizeof(point) * new_size));
                    if (!points) {
                        cout<<"Cannot malloc in Evaluate"<<endl;
                        abort();
                    }
                    if (!common::points[test_sector]->get("lower", 5, points, new_size * sizeof(point))) {
                        cout << "Can't read in Evaluate" << endl;
                        abort();
                    }
                    for (int i = 0; i != new_size; ++i) {
                        add_needed(needed_lower, reinterpret_cast<point*>(points)[i]);
                    }
                    free(points);
                }

                eqs_total += common::points[test_sector]->increment(string("eqs_tot"), 0, INT64_MIN);
                eqs_used += common::points[test_sector]->increment(string("eqs_max"), 0, INT64_MIN);
                vsi[count] = 0;
                rss[count] = 0;
                vsi[count] += common::points[test_sector]->increment(string("mem_vsi"), 0, INT64_MIN);
                rss[count] += common::points[test_sector]->increment(string("mem_rss"), 0, INT64_MIN);
                ++count;

                close_database(test_sector);
                if (common::wrap_databases) {
                    remove((common::path + int2string(test_sector) + "." + "tmp").c_str());
                }
            }

            for (const auto &sector : needed_lower) {
              // now we go through all sectors and fill the lower-level databases with required input

                if (common::wrap_databases) {
                    database_to_file_or_back(sector.first, false);
                }
                open_database(sector.first);

                vector<pair<point, COEFF> > t;
                for (const auto &pnt : sector.second) {
                    p_set(pnt, t, 2 * last_level + inlsectors + 1);
                }
                close_database(sector.first);

                if (common::wrap_databases) {
                    database_to_file_or_back(sector.first, true);
                }
                if (common::cpath != "") {
                    copy_database(sector.first, false);
                }
            }
            estimate_memory_usage(vsi,rss,count,common::threads_number);

            if (!common::silent) {
                cout << "FINISHED LEVEL " << last_level << "." << inlsectors + 1 << endl;
            }
        }
        last_level--;
    }

    auto subst_time = chrono::steady_clock::now();

    if (common::sthreads_number != common::threads_number) {
        // stopping
        worker_stop = true;
        worker_cond.notify_all();
        for (unsigned int i = 0; i != common::threads_number; ++i) {
            worker[i].join();
        }
        worker_stop = false;

        // starting
        for (unsigned int i = 0; i != common::sthreads_number; ++i) {
            worker[i] = thread(worker_thread, i);
        }
    }

    // backward substitutions level by level
    if (not common::only_masters) {
        unsigned long long total_substituted{};

        if (!common::cpath_on_substitutions) child_stop = true; // no storage on substitutions means no child communication
        while (last_level <= common::abs_max_level) {
            int inlsectors = 0;
            while (inlsectors != 2) {
                bool inlsectorsbool = (inlsectors == 0);

                // list of sectors of this level
                set<sector_count_t> sector_set_this_level;
                set<sector_count_t>::iterator sector_set_this_level_itr;

                for (sector_count_t i = 2; i != common::abs_max_sector + 1; i++) {
                    if (!common::sector_numbers_fast[sector_fast(common::ssectors[i])]) continue;
                    if (database_exists(i) && (positive_index(common::ssectors[i]) == last_level) && (in_lsectors(i) == inlsectorsbool)) {
                        sector_set_this_level.insert(i);
                    }
                }

                inlsectors++;
                if (sector_set_this_level.empty()) {
                    continue;
                }

                fflush(stdout);

                auto start_timeP = chrono::steady_clock::now();

                for (sector_set_this_level_itr = sector_set_this_level.begin(); sector_set_this_level_itr != sector_set_this_level.end(); ++sector_set_this_level_itr) {
                    sector_count_t test_sector = *sector_set_this_level_itr;
                    if (common::wrap_databases) {
                        database_to_file_or_back(test_sector, false);
                    }
                    open_database(test_sector);
                    total_substituted += common::points[test_sector]->count();
                    map<sector_count_t, set<point> > needed_lower;

                    // here we read and fill needed_for for the current sector
                    int64_t new_size = common::points[test_sector]->increment(string("lower_size"), 0, INT64_MIN);
                    if (new_size > 0) {
                        char *points = static_cast<char *>(malloc(sizeof(point) * new_size));
                        if (!points) {
                            cout<<"Cannot malloc in Evaluate"<<endl;
                            abort();
                        }
                        if (!common::points[test_sector]->get("lower", 5, points, new_size * sizeof(point))) {
                            cout << "Can't read in Evaluate" << endl;
                            abort();
                        }
                        for (int i = 0; i != new_size; ++i) {
                            needed_for[test_sector].insert(reinterpret_cast<point*>(points)[i].s_number());
                            add_needed(needed_lower, reinterpret_cast<point*>(points)[i]);
                        }
                        free(points);
                    }

                    // we are moving entries from lower database to higher
                    for (const auto &sector : needed_lower) {
                        if (common::wrap_databases) {
                            database_to_file_or_back(sector.first, false, false); // only for reading
                        }
                        open_database(sector.first);
                        total_size += realsize(test_sector);
                        for (const auto &p : sector.second) {
                            size_t size;
                            char *res = common::points[sector.first]->get(p.ww, sizeof(point), &size);
                            if (res == nullptr) {
                                cout << "Error on point transfer: " << p.s_number() << p
                                     << string(common::points[sector.first]->error().message()) << endl;
                                abort();
                            }
                            if (!common::points[test_sector]->set(p.ww, sizeof(point), res, size)) {
                                cout << "Can't write on point transfer" << endl;
                                abort();
                            }
                            delete[] res;
                        }

                        close_database(sector.first);
                        if (common::wrap_databases) {
                            remove((common::path + int2string(sector.first) + "." + "tmp").c_str());
                        }
                    }
                    close_database(test_sector);
                    if (common::wrap_databases) {
                        database_to_file_or_back(test_sector, true);
                    }
                    if (common::cpath != "") {
                        if (common::cpath_on_substitutions) copy_database(test_sector, false);
                    }
                }

                auto stop_timeP = chrono::steady_clock::now();

                if (!common::silent) {
                    cout << "Copying results from lower sectors: "
                        << chrono::duration_cast<chrono::duration<float>>(stop_timeP - start_timeP).count() << " seconds." << endl;
                }

                {
                    lock_guard<mutex> guard(worker_mutex);
                    for (sector_set_this_level_itr = sector_set_this_level.begin(); sector_set_this_level_itr != sector_set_this_level.end(); ++sector_set_this_level_itr) {
                        worker_tasks.push_back(-(*sector_set_this_level_itr));  // we created the list of jobs
                        ++distributed_sectors; // distributing tasks
                    }
                }

                worker_cond.notify_all(); // we told the workers they can start

                {
                    unique_lock<mutex> guard(worker_mutex);
                    worker_done_cond.wait(guard,[](){return distributed_sectors==0;}); // we need to wait until all are ready
                }

                // let's estimate memory usage during level substitutions
                uint64_t vsi[1024];
                uint64_t rss[1024];
                size_t count = 0;
                for (sector_set_this_level_itr = sector_set_this_level.begin(); sector_set_this_level_itr != sector_set_this_level.end(); ++sector_set_this_level_itr) {
                    sector_count_t test_sector = (*sector_set_this_level_itr);

                    if (common::wrap_databases) {
                        database_to_file_or_back(test_sector, false, false);
                    }
                    open_database(test_sector);

                    vsi[count] = 0;
                    rss[count] = 0;
                    vsi[count] += common::points[test_sector]->increment(string("mem_vsi"), 0, INT64_MIN);
                    rss[count] += common::points[test_sector]->increment(string("mem_rss"), 0, INT64_MIN);
                    ++count;

                    close_database(test_sector);
                    if (common::wrap_databases) {
                        remove((common::path + int2string(test_sector) + "." + "tmp").c_str());
                    }
                }

                estimate_memory_usage(vsi,rss,count,common::sthreads_number);

                if (inlsectorsbool) {
                    if (!common::silent) cout << "STARTING HIGHER SECTORS OF SAME LEVEL" << endl;
                }

            }

            if (!common::silent) {
                cout << "FINISHED LEVEL " << last_level << endl;
            }
            last_level++;
        }

        if (!common::silent) {
            cout << "Totally substituted " << total_substituted << " points" << endl;
        }
    }  // if making substitutions

    auto stop_time = chrono::steady_clock::now();

    cout << "STATISTICS" << endl;
    cout << "Total time: " << chrono::duration_cast<chrono::duration<float>>(stop_time - start_time).count() << endl;
    cout << "Substitution time: " << chrono::duration_cast<chrono::duration<float>>(stop_time - subst_time).count() << endl;
    cout << "Thread time: " << chrono::duration_cast<chrono::duration<float>>(chrono::microseconds(common::thread_time)).count() << endl;
    cout << "Eqs (total/used): " << eqs_total << " | " << eqs_used << endl;
    cout << "Maximal memory by the main process (virtual|resident): ";
    print_memory(max_vsi_main, 0, -1);
    cout << " | ";
    print_memory(max_rss_main, 1, -1);
    cout << endl;
    cout << "Thread memory usage estimation by top " << common::sthreads_number << " sectors (virtual|resident): ";
    print_memory(max_vsi_est, 0, -1);
    cout << " | ";
    print_memory(max_rss_est, 1, -1);
    cout << endl;

    #ifdef DISK_DB
        cout << "Maximum total size of databases: " << GBsize(total_size) << endl;
    #endif

    child_stop = true;
    worker_stop = true;
    worker_cond.notify_all();
    for (unsigned int i = 0; i != common::sthreads_number; ++i) {
        worker[i].join();
    }
}

bool express_and_pass_back(map<point, vector<pair<point, COEFF> >, indirect_more, ALLOCATOR1 > &to_test,
                           const sector_count_t sector, const unsigned int thread_number) {
    bool has_high = false;
    auto ritr = to_test.rbegin();
    for (auto itr = to_test.begin(); itr != to_test.end();) {
        const point &p = itr->first;
        if ((p.s_number() != sector) || (p.virt())) {
            ritr = map<point, vector<pair<point, COEFF> >, indirect_more, ALLOCATOR1 >::reverse_iterator(itr);
            break;
        }
        p_get(p, itr->second, sector);
        if (!itr->second.empty()) {
            auto insert_itr = itr;
            vector<pair<point, COEFF> >::const_reverse_iterator mitr = itr->second.rbegin(); // the highest, that will be skipped
            for (++mitr; mitr != itr->second.rend(); ++mitr) {
                // last is equal to p. not to check it all the time
                if ((mitr->first.s_number() == sector) && (!mitr->first.virt())) {
                    vector<pair<point, COEFF> > v;
                    insert_itr = to_test.insert(insert_itr, make_pair(mitr->first, v)); // we keep moving to lower entries, they will come later
                } else {
                    break; // as soon as we see something out of the sector, there is no need to search more
                }
            }
            ++itr;
        } else {
            has_high = true;
            // it's been an empty table, but we don't change anything, it will be skipped on the back pass
            ++itr;
        }
    }

    if (!has_high) {
        return false;
    }

    //pass_back
    for (auto itr = ritr; itr != to_test.rend(); ++itr) {
        vector<pair<point, COEFF> > &terms = itr->second;
        if (!terms.empty()) {
            apply_table(terms, true, true, sector, 0, thread_number);
        }
    }
    return true;
}


set<point, indirect_more>::reverse_iterator expressed_by(set<point, indirect_more> &to_test, sector_count_t sector_number) {
    for (auto itr = to_test.begin(); itr != to_test.end(); ) {
        point p = *itr;
        if (p.s_number() != sector_number) {
            return set<point, indirect_more>::reverse_iterator(itr);
        }
        vector<point> monoms = p_get_monoms(p, sector_number);
        if (!monoms.empty()) {
            auto last = monoms.end();
            last--;
            for (auto mitr = monoms.begin(); mitr != last; ++mitr) {
                if (mitr->s_number() == sector_number) {
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
void add_to(list<pair<point, COEFF>, ALLOCATOR2 > &terms1, const vector<pair<point, COEFF> > &terms2, const COEFF &coeff, bool skip_last) {
    add_to(terms1, terms2.begin(), terms2.end(), coeff, skip_last);
}

void add_to(list<pair<point, COEFF>, ALLOCATOR2 > &terms1, const list<pair<point, COEFF>, ALLOCATOR2 > &terms2, const COEFF &coeff, bool skip_last) {
    add_to(terms1, terms2.begin(), terms2.end(), coeff, skip_last);
}

//adding a vector to list
template<class I>
void add_to(list<pair<point, COEFF>, ALLOCATOR2 > &terms1, I termsB, I termsE, const COEFF &coeff, bool skip_last) {
    auto eq2end = termsE;
    if (skip_last) {
        eq2end--;
    }
    auto itr1 = terms1.begin();
    auto itr2 = termsB;
    while (itr2 != eq2end) {
        if ((itr1 != terms1.end()) && (itr1->first < itr2->first)) { // first equation only. just adding to result
            ++itr1;
        } else if ((itr1 == terms1.end()) || (itr2->first < itr1->first)) { // second equation only. have to multiply
            uint128_t nB = itr2->second.n;
            nB *= uint128_t(coeff.n);
            nB %= common::prime;
            if (nB) {
                COEFF c;
                c.n = nB;
                itr1 = terms1.emplace(itr1, make_pair(itr2->first, c));
                ++itr1;
            }
            ++itr2;
        } else { // both equations. have to multiply and add
            uint128_t num1, num2;
            num1 = itr1->second.n;
            num2 = itr2->second.n;
            num2 *= uint128_t(coeff.n);
            num1 += num2;
            num1 %= common::prime;
            if (num1) {
                itr1->second.n = num1;
                ++itr1;
            } else {
                itr1 = terms1.erase(itr1);
            }
            ++itr2;
        }
    }
}
#else

void add(const vector<pair<point, COEFF> > &terms1, const vector<pair<point, COEFF> > &terms2,
         vector<pair<point, COEFF> > &rterms, const COEFF &coeff, bool skip_last) {
    rterms.reserve(terms1.size() + terms2.size());
    rterms.clear();

    auto eq2end = terms2.end();
    if (skip_last) {
        eq2end--;
    }
    vector<pair<point, COEFF> >::const_iterator itr1;
    vector<pair<point, COEFF> >::const_iterator itr2;
    itr1 = terms1.begin();
    itr2 = terms2.begin();
    while (itr2 != eq2end) {
        if ((itr1 != terms1.end()) && (itr1->first < itr2->first)) { // first equation only. just adding to result
            rterms.emplace_back(*itr1);
            ++itr1;
        } else if ((itr1 == terms1.end()) || (itr2->first < itr1->first)) { // second equation only. have to multiply
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
            s += "+(";
            s += coeff.s;
            s += "*(";
            s += itr2->second.s;
            s += "))";
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

void apply_table(const vector<pair<point, COEFF> > &terms, bool forward_mode, bool fixed_last,
                 sector_count_t fixed_database_sector, unsigned short sector_level, unsigned int thread_number) {

    bool changed = false;
    auto end = terms.cend();
    if (fixed_last) {
        --end;
    }
#ifdef PRIME
    list<pair<point, COEFF>, ALLOCATOR2 > result;
    for (auto itr = terms.cbegin(); itr != end; ++itr) {
        const point &p = itr->first;
        if ((forward_mode && ((p.s_number() < fixed_database_sector) || p.virt())) || (p.s_number() == 1)) {
            result.emplace_back(*itr);
        } else {
            vector<pair<point, COEFF> > terms2;
            p_get(p, terms2, fixed_database_sector);
            if (terms2.empty()) {
                result.emplace_back(*itr);  // we just put the monomial at the end with no substitution
            } else {
                changed = true;
                uint128_t num, denum;
                num = itr->second.n;
                denum = terms2.back().second.n;
                num = common::prime - num;
                denum = mul_inv(denum, common::prime);
                num = (num * denum) % common::prime;
                COEFF c;
                c.n = num;
                add_to(result, terms2, c, true); // we add the second expression with the last term killed
            }
        }
    }
    if (fixed_last) {
        result.push_back(terms.back());
    }

    if (!changed) {
        if (!fixed_last) {
            // means that it is a pure equation that should be checked for having at lease something over the corner and set
            point &after = result.back().first;
            if ((after.s_number() >= fixed_database_sector) && (!after.virt())) {
                p_set(after, result, 2 * sector_level, fixed_database_sector);  // p_set_list
            }
        }
        return;
    }

    if (forward_mode) {
        if ((result.back().first.s_number() == fixed_database_sector) && (!(result.back().first.virt()))) {
            split(result, fixed_database_sector);      // split should work with a list
        }
    } else {
        p_set(result.back().first, result, 2 * sector_level, fixed_database_sector);
    }
#else
    vector<pair<point, COEFF> > rterms1;
    rterms1.reserve(terms.size());
    bool first = true;
    vector<pair<point, COEFF> > rterms2;
    for (auto itr = terms.cbegin(); itr != end; ++itr) {
        const point &p = itr->first;
        if ((forward_mode && ((p.s_number() < fixed_database_sector) || p.virt())) || (p.s_number() == 1)) {
            if (first) {
                rterms1.push_back(*itr);
            } else {
                rterms2.push_back(*itr);
            }
        } else {
            vector<pair<point, COEFF> > terms2;
            p_get(p, terms2, fixed_database_sector);
            if (terms2.empty()) {
                if (first) {
                    rterms1.push_back(*itr);
                } else {
                    rterms2.push_back(*itr);
                }
            } else {
                changed = true;
                COEFF c;
                c.s = "-(" + itr->second.s + ")/(" + terms2.back().second.s + ")";
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

    vector<pair<point, COEFF> > *rterms_p;
    if (first) {
        rterms_p = &rterms1;
    } else {
        rterms_p = &rterms2;
    }

    vector<pair<point, COEFF> > &rterms = *rterms_p;

    if (rterms.empty()) return;

    if (!changed) {
        if (!fixed_last) {
            // means that it is a pure equation that should be checked for having at lease something over the corner and set
            point &after = rterms.back().first;
            if ((after.s_number() >= fixed_database_sector) && (!after.virt())) {
                p_set(after, rterms, 2 * sector_level, fixed_database_sector);
            }
        }
        return;
    }

    normalize(rterms, thread_number);

    if (rterms.empty()) return;

    if (forward_mode) {
        if ((rterms.back().first.s_number() == fixed_database_sector) && (!(rterms.back().first.virt()))) {
            split(rterms, fixed_database_sector); // classical split with vectors
        }
    } else {
        p_set(rterms.back().first, rterms, 2 * sector_level, fixed_database_sector);
    }
#endif
}

void pass_back(const set<point, indirect_more> &cur_set, set<point, indirect_more>::const_reverse_iterator ritr,
               sector_count_t fixed_database_sector) {
    for (auto itr = ritr; itr != cur_set.rend(); ++itr) {
        point p = *itr;
        vector<pair<point, COEFF> > terms;
        p_get(p, terms, fixed_database_sector);
        if (!terms.empty()) {
            apply_table(terms, false, true, fixed_database_sector, 0, 0);  // backward reduction with 0 as sector and 0 as thread_number
        }
    }
}


#ifdef PRIME
list<pair<point, COEFF>, ALLOCATOR2 >::iterator split(list<pair<point, COEFF>, ALLOCATOR2 > &terms, sector_count_t sector_number)
#else
void split(vector<pair<point, COEFF> > &terms, sector_count_t sector_number)
#endif
{
#ifdef PRIME
    if (terms.empty()) return terms.begin();
#else
    if (terms.empty()) return;
#endif
    auto itr = terms.begin();
    size_t size = 0;
    while ((itr->first.s_number() < sector_number) || itr->first.virt()) {
        ++itr;
        ++size;
    }
    if ((itr != terms.begin()) && (itr != terms.end())) {
        // once I tries to remove the splitting in case of size==1
        // but it degrades performance in some cases
        // so do not touch this!

        // starting the split
        uint64_t virts_temp = ++virts_number; //atomic
        // virts_temp gets the old value, then virts_number gets increased

        point p(common::ssectors[sector_number], virts_temp); // virtual

        pair<point, COEFF> save = *itr;
        // the pair at itr position is saved, then used to temporarily store the pair with the new virtual definition

        COEFF c;
#ifdef PRIME
        c.n = common::prime - 1;
#else
        c.s = "-1";
#endif
        *itr = make_pair(p, c);
        ++itr;
#ifdef PRIME
        p_set<list<pair<point, COEFF>, ALLOCATOR2 >::const_iterator>(p, size + 1, terms.begin(), itr, 2 *
                                                                                                      positive_index(
                                                                                                              common::ssectors[sector_number]),
                                                                     0);  // split won't happen in symmetries sector
#else
        p_set<vector<pair<point, COEFF> >::const_iterator>(p, size + 1, terms.begin(), itr,
                                                           2 * positive_index(common::ssectors[sector_number]),
                                                           0);  // split won't happen in symmetries sector
#endif

        --itr;
        *itr = save; // returning the original pair
        --itr;
#ifdef PRIME
        c.n = 1;
#else
        c.s = "1";
#endif
        *itr = make_pair(p, c);

#ifdef PRIME
        p_set<list<pair<point, COEFF>, ALLOCATOR2 >::const_iterator>(terms.back().first, terms.size() - size + 1, itr,
                                                                     terms.end(), 2 * positive_index(
                        common::ssectors[sector_number]), 0);
        return itr;
#else
        p_set<vector<pair<point, COEFF> >::const_iterator>(terms.back().first, terms.size() - size + 1, itr,
                                                           terms.end(),
                                                           2 * positive_index(common::ssectors[sector_number]),
                                                           0);
#endif
    } else
        p_set(terms.back().first, terms, 2 * positive_index(common::ssectors[sector_number]), 0);  // split won't happen in symmetries sector
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
    if (silent == 1) return;
    if ((silent == 0) && common::silent) return;

    if ((mem < 64) || (power_level == 3)) {
        cout << mem << mem_symbol(power_level);
    } else if (mem < 64 * 1024) {
        cout << setprecision(4) << (mem / 1024.) << setprecision(6) << mem_symbol(power_level + 1);
    } else {
        print_memory(mem / 1024, power_level + 1, silent);
    }
}


void process_mem_usage(bool silent) {
    using std::ios_base;
    using std::ifstream;
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

    stat_stream >> pid >> comm >> state >> ppid >> pgrp >> session >> tty_nr
                >> tpgid >> flags >> minflt >> cminflt >> majflt >> cmajflt
                >> utime >> stime >> cutime >> cstime >> priority >> nice
                >> O >> itrealvalue >> starttime >> vsize >> rss; // don't care about the rest

    __int32_t page_size_kb = sysconf(_SC_PAGE_SIZE) / 1024; // in case x86-64 is configured to use 2MB pages
    rss *= page_size_kb;

    __uint64_t urss = rss;

    if ((!silent) && (!common::silent)) {
        cout << "Memory (virtual|resident): ";
        print_memory(vsize, 0);
        cout << " | ";
        print_memory(rss, 1);
        cout << endl;
    }

    if (vsize > max_vsize) max_vsize = vsize;
    if (urss > max_rss) max_rss = urss;
    //   vm_usage     = vsize / 1024.0;
    //   resident_set = rss * page_size_kb;
}


bool sort_pair_point_coeff_by_point(const pair<point, COEFF> &lhs, const pair<point, COEFF> &rhs) {
    return lhs.first < rhs.first;
}

vector<pair<point, COEFF> > group_equal_in_sorted(const vector<pair<point, COEFF> > &mon) {
    vector<pair<point, COEFF> > terms;
    terms.reserve(mon.size());
    for (auto read = mon.begin(); read != mon.end(); ++read) {
        // there is already a check here for equal points due to symmetries
        COEFF c = read->second;
        auto read2 = read;
        read2++;
        while ((read2 != mon.end()) && (read2->first == read->first)) {
#ifdef PRIME
            uint128_t nB = c.n;
            nB += read2->second.n;
            nB %= common::prime;
            c.n = nB;
#else
            c.s += "+(" + read2->second.s + ")";
#endif
            read2++;
        }
        read2--;
        read = read2;
#ifdef PRIME
        if (c.n) {
            terms.emplace_back(read->first, c);
        }
#else
        terms.emplace_back(read->first, c);
#endif
    }
    return terms;
}
