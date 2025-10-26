/** @file equation.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package.
 */

#include "equation.h"

#include <chrono>
#include <condition_variable>
#include <mutex>

mutex Equation::f_submit_mutex[MAX_THREADS];
mutex Equation::f_receive_mutex[MAX_THREADS];
condition_variable Equation::f_submit_cond[MAX_THREADS];
condition_variable Equation::f_receive_cond[MAX_THREADS];
list<pair<int, pair<Point, string>>> Equation::f_jobs[MAX_THREADS];
bool Equation::f_stop = false;
list<pair<Point, string>> Equation::f_result[MAX_THREADS];
thread Equation::f_threads[MAX_THREADS];

// get monoms from a Point (Feynman integral). database access used
vector<Point> p_get_monoms(const Point &p, sector_count_t sector_number) {
    vector<Point> result;
    if (!sector_number)
        sector_number = p.SectorNumber();

    class VisitorImpl : public kyotocabinet::DB::Visitor {
        const char *visit_full([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz, const char *vbuf,
                               size_t vsiz, [[maybe_unused]] size_t *sp) {
#ifdef PRIME
#ifdef MPRIME
            const unsigned int len = vsiz / (sizeof(Point) + MPRIME * sizeof(long long int));
#else
            const unsigned int len = vsiz / (sizeof(Point) + sizeof(long long int));
#endif
#else
            const unsigned int len = (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & ~NEEDED_BIT);
#endif
            if (len == 0) {
                terms->clear();
                return NOP;
            }
            terms->reserve(len);
            for (unsigned int i = 0; i != len; ++i) {
                terms->emplace_back((reinterpret_cast<const Point *>(vbuf))[i]);
            }
            return NOP;
        }

        const char *visit_empty([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz,
                                [[maybe_unused]] size_t *sp) {
            terms->clear();
            return NOP;
        }

      public:
        vector<Point> *terms;
    } get_monoms_visitor;

    get_monoms_visitor.terms = &result;

    if (!Common::points[sector_number]->accept(reinterpret_cast<const char *>(&p), sizeof(Point), &get_monoms_visitor,
                                               false)) {
        cout << p.SectorNumber() << p << string(Common::points[sector_number]->error().message()) << endl;
        abort();
    }

    if ((!result.empty()) && (p != result.back())) {
        cout << "get_monoms error" << endl;
        cout << p << endl;
        cout << result.size() << endl;
        for (const auto &pnt : result) {
            cout << pnt << endl;
        }
        abort();
    }
    return result;
}

bool p_is_empty(const Point &p, sector_count_t sector_number) {

    if (!sector_number)
        sector_number = p.SectorNumber();
    class VisitorImpl : public kyotocabinet::DB::Visitor {
        const char *visit_full([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz, const char *vbuf,
                               size_t vsiz, [[maybe_unused]] size_t *sp) {
#ifdef PRIME
#ifdef MPRIME
            const unsigned int len = vsiz / (sizeof(Point) + MPRIME * sizeof(long long int));
#else
            const unsigned int len = vsiz / (sizeof(Point) + sizeof(long long int));
#endif
#else
            const unsigned int len = (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & ~NEEDED_BIT);
#endif
            result = !len;
            return NOP;
        }

        const char *visit_empty([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz,
                                [[maybe_unused]] size_t *sp) {
            result = true;
            return NOP;
        }

      public:
        bool result;
    } check_empty_visitor;

    if (!Common::points[sector_number]->accept(reinterpret_cast<const char *>(&p), sizeof(Point), &check_empty_visitor,
                                               false)) {
        cout << p.SectorNumber() << p << string(Common::points[sector_number]->error().message()) << endl;
        abort();
    }
    return check_empty_visitor.result;
}

void p_get(const Point &p, vector<pair<Point, COEFF>> &terms, sector_count_t sector_number) {
    if (!sector_number)
        sector_number = p.SectorNumber();

    class VisitorImpl : public kyotocabinet::DB::Visitor {
        const char *visit_full([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz, const char *vbuf,
                               size_t vsiz, [[maybe_unused]] size_t *sp) {
#ifdef PRIME
#ifdef MPRIME
            const unsigned int len = vsiz / (sizeof(Point) + MPRIME * sizeof(long long int));
#else
            const unsigned int len = vsiz / (sizeof(Point) + sizeof(long long int));
#endif
#else
            const unsigned int len = (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & ~NEEDED_BIT);
#endif
            if (len == 0) {
                terms->clear();
                return NOP;
            }
            terms->reserve(len); // THIS IS THE ONLY IMPORTANT DIFFERENCE
            p_get_internal(*p, *terms, len, vbuf);
            return NOP;
        }

        const char *visit_empty([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz,
                                [[maybe_unused]] size_t *sp) {
            terms->clear();
            return NOP;
        }

      public:
        vector<pair<Point, COEFF>> *terms;
        const Point *p;
        sector_count_t *sector_number;
    } get_visitor;

    get_visitor.terms = &terms;
    get_visitor.p = &p;
    get_visitor.sector_number = &sector_number;

    if (!Common::points[sector_number]->accept(reinterpret_cast<const char *>(&p), sizeof(Point), &get_visitor,
                                               false)) {
        cout << p.SectorNumber() << p << string(Common::points[sector_number]->error().message()) << endl;
        abort();
    }
}

void p_get(const Point &p, list<pair<Point, COEFF>> &terms, sector_count_t sector_number) {
    if (!sector_number)
        sector_number = p.SectorNumber();
    class VisitorImpl : public kyotocabinet::DB::Visitor {
        const char *visit_full([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz, const char *vbuf,
                               size_t vsiz, [[maybe_unused]] size_t *sp) {
#ifdef PRIME
#ifdef MPRIME
            const unsigned int len = vsiz / (sizeof(Point) + MPRIME * sizeof(long long int));
#else
            const unsigned int len = vsiz / (sizeof(Point) + sizeof(long long int));
#endif
#else
            const unsigned int len = (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & ~NEEDED_BIT);
#endif
            if (len == 0) {
                terms->clear();
                return NOP;
            }
            p_get_internal(*p, *terms, len, vbuf);
            return NOP;
        }

        const char *visit_empty([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz,
                                [[maybe_unused]] size_t *sp) {
            terms->clear();
            return NOP;
        }

      public:
        list<pair<Point, COEFF>> *terms;
        const Point *p;
        sector_count_t *sector_number;
    } get_visitor;

    get_visitor.terms = &terms;
    get_visitor.p = &p;
    get_visitor.sector_number = &sector_number;

    if (!Common::points[sector_number]->accept(reinterpret_cast<const char *>(&p), sizeof(Point), &get_visitor,
                                               false)) {
        cout << p.SectorNumber() << p << string(Common::points[sector_number]->error().message()) << endl;
        abort();
    }
}

// get monoms and coefficients from a Point (Feynman integral). database access
// used
template <class I> void p_get_internal(const Point &p, I &terms, unsigned int len, const char *res) {

    const char *pos = res + len * sizeof(Point);

    for (unsigned int j = 0; j != len; ++j) {
        COEFF c;
#ifdef PRIME
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            c.N[i] = *reinterpret_cast<const unsigned long long *>(pos);
            pos += sizeof(unsigned long long);
        }
#else
        c.n = *reinterpret_cast<const unsigned long long *>(pos);
        pos += sizeof(unsigned long long);
#endif
#else
        const char *end = pos;
        while (*end != '|')
            ++end;
        c.s = string(pos, end - pos);
        pos = end;
        ++pos;
#endif
        terms.emplace_back(reinterpret_cast<const Point *>(res)[j], c);
    }

    if ((len != 0) && (p != terms.back().first)) {
        cout << "p_get error" << endl;
        cout << p << endl;
        cout << terms.size() << endl;
        for (const auto &term : terms) {
            cout << term.first << endl;
        }
        abort();
    }
}

#if !defined(DOXYGEN_DOCUMENTATION)
template void p_get_internal(const Point &p, vector<pair<Point, COEFF>> &terms, unsigned int len, const char *res);
#endif

void p_set(const Point &p, const vector<pair<Point, COEFF>> &terms, bool needed_higher, sector_count_t sector_number) {
    p_set(p, static_cast<unsigned int>(terms.size()), terms.begin(), terms.end(), needed_higher, sector_number);
}

void p_set(const Point &p, const list<pair<Point, COEFF>> &terms, bool needed_higher, sector_count_t sector_number) {
    p_set(p, static_cast<unsigned int>(terms.size()), terms.begin(), terms.end(), needed_higher, sector_number);
}

bool is_lower_in_orbit(const vector<t_index> &lhs, const vector<t_index> &rhs) {
    if (lhs == rhs)
        return false;
    vector<t_index> s1 = sector(lhs);
    vector<t_index> s2 = sector(rhs);
    if (s1 != s2) {
        sector_count_t sn1 = Common::sector_numbers_fast[sector_fast(s1)];
        sector_count_t sn2 = Common::sector_numbers_fast[sector_fast(s2)];
        if (sn1 < sn2)
            return (true);
        if (sn1 > sn2)
            return (false);
    }

    uint32_t *ordering_now = Common::orderings_fast[sector_fast(lhs)].get();
    vector<t_index> d1 = degree(lhs);
    vector<t_index> d2 = degree(rhs);
    unsigned int n = lhs.size();
    for (unsigned int i = 0; i != n; ++i) {
        int pr = 0;
        uint32_t bit = 1;
        for (unsigned int j = 0; j != n; ++j) {
            if (ordering_now[i] & bit) {
                pr += (d1[j] - d2[j]);
            }
            bit <<= 1;
        }
        if (pr < 0)
            return true;
        if (pr > 0)
            return false;
    }
    return false;
}

bool pair_point_coeff_smaller(const pair<Point, COEFF> &lhs, const pair<Point, COEFF> &rhs) {
    return lhs.first < rhs.first;
}

bool fast_point_smaller_in_sector(const FastPoint &pf1, const FastPoint &pf2, SECTOR s) {
    if (pf1 == pf2)
        return false;
    uint32_t *ordering_now = Common::orderings_fast[s].get();
    FastPoint d1 = pf1.Degree();
    FastPoint d2 = pf2.Degree();

    for (unsigned int i = 0; i != Common::dimension; ++i) {
        int pr = 0;
        uint32_t bit = 1;
        for (unsigned int j = 0; j != Common::dimension; ++j) {
            if (ordering_now[i] & bit)
                pr += (d1.buf[j] - d2.buf[j]);
            bit <<= 1;
        }
        if (pr < 0)
            return true;
        if (pr > 0)
            return false;
    }
    cout << "impossible Point compare" << endl;
    for (unsigned int i = 0; i != Common::dimension; ++i)
        cout << int(pf1.buf[i]) << ";";
    cout << endl;
    for (unsigned int i = 0; i != Common::dimension; ++i)
        cout << int(pf2.buf[i]) << ";";
    cout << endl;
    cout << "impossible Point compare" << endl;
    abort(); // this should not happen
}

// Point reference version without std
Point point_reference_fast(const FastPoint &v) {
    SECTOR ssector = v.SectorFast();
    sector_count_t sn = Common::sector_numbers_fast[ssector];
    if (sn == 0) {
        return Point();
    }
    if (sn == 1) {
        return Point(v, ssector);
    }

    if (Common::symmetries.size() > 1) { // there are symmetries
        vector<vector<vector<t_index>>> &sym = Common::symmetries;
        FastPoint best = v;
        SECTOR best_sector = ssector;
        unsigned short best_sn = sn;
        for (const auto &values : sym) {
            const vector<t_index> &permutation = values[0];
            FastPoint p_new;

            for (unsigned int i = 0; i != Common::dimension; ++i) {
                p_new.buf[i] = v.buf[permutation[i] - 1];
            }

            // we only use the first part of symmetries, but I do not even know
            // whether the other parts used to work properly part 3 can be added only
            // at parser time and means something related to part 2 = conditional
            // symmetries part 1 i odd symmetries, but they did not work properly even
            // in earlier versions

            // now we need to compare the points and choose the lowest
            // best_sector is either Common::virtual_sector or some good sector;

            SECTOR new_sector = p_new.SectorFast();
            sector_count_t new_sn = Common::sector_numbers_fast[new_sector];
            if (new_sn == Common::virtual_sector) {
                continue; // it is a higher virtual point
            }

            if (best_sn == Common::virtual_sector) { // the old one was virtual, but
                                                     // now a real Point comes
                best_sn = new_sn;
                best_sector = new_sector;
                best = p_new;
                continue;
            }

            // here we are left with the case when both new and old are virtual; this
            // means they are in the same sector
            if (fast_point_smaller_in_sector(p_new, best, best_sector)) {
                best = p_new;
            }
        }
        return Point(best, best_sector);
    } else {
        return Point(v, ssector);
    }
}

// get the right symmetry Point by the vector of coordinates
Point point_reference(const vector<t_index> &v) {
    SECTOR ssector = sector_fast(v);
    sector_count_t sn = Common::sector_numbers_fast[ssector];
    if (sn == 0) {
        return Point();
    }
    if (sn == 1) {
        return Point(v, 0, ssector);
    }

    if (Common::symmetries.size() > 1) { // there are symmetries
        vector<vector<vector<t_index>>> &sym = Common::symmetries;
        vector<vector<t_index>> orbit;
        symmetry_orbit(v, orbit, sym);
        vector<t_index> *lowest = &(*orbit.begin());
        auto itr = orbit.begin();
        itr++;
        while (itr != orbit.end()) {
            if (is_lower_in_orbit(*itr, *lowest)) {
                lowest = &(*itr);
            }
            itr++;
        }
        return Point(*lowest);
    } else {
        return Point(v, 0, ssector);
    }
}

/* time to normalize an Equation - to use the GCD everywhere and throw away zero
 * members calls to fermat come from here
 */

#ifndef PRIME

void normalize(vector<pair<Point, COEFF>> &terms, unsigned short thread_number) {
    if (Common::send_to_parent) {
        auto start_time = chrono::steady_clock::now();

        char lbuf[10];
        snprintf(lbuf, sizeof(lbuf), "%d\n", int(terms.size()));
        fputs(lbuf, Common::child_stream_from_child);
        fflush(Common::child_stream_from_child);
        char buf[sizeof(Point) * 2 + 1];
        buf[sizeof(Point) * 2] = '\0';
        int submitted = 0;

        auto itr = terms.begin();
        while (itr != terms.end()) {
            // we put the point
            itr->first.SafeString(buf);
            fputs(buf, Common::child_stream_from_child);
            // we put the coefficient
            fputs(itr->second.s.c_str(), Common::child_stream_from_child);
            fputs("\n", Common::child_stream_from_child);
            fflush(Common::child_stream_from_child);
            submitted++;
            ++itr;
        }

        terms.clear();

        while (submitted != 0) {
            size_t buf_size = 3;
            char *bbuf = static_cast<char *>(malloc(buf_size));
            if (!bbuf) {
                cout << "Cannot malloc in normalize" << endl;
                abort();
            }

            read_from_stream(&bbuf, &buf_size, Common::child_stream_to_child);

            bbuf[strlen(bbuf) - 1] = '\0';
            string ss = (bbuf + sizeof(Point) * 2);
            if (ss != "0") {
                terms.emplace_back(bbuf, ss);
            }
            submitted--;
            free(bbuf);
        }
        auto stop_time = chrono::steady_clock::now();

        Common::simplify_time += chrono::duration_cast<chrono::microseconds>(stop_time - start_time).count();

    } else {
        list<pair<int, pair<Point, string>>> to_submit;
        int submitted = 0;
        auto itr = terms.begin();
        while (itr != terms.end()) {
            to_submit.emplace_back(thread_number, pair<Point, string>(itr->first, itr->second.s));
            ++itr;
            submitted++;
        }

        {
            lock_guard<mutex> guard(Equation::f_submit_mutex[thread_number % Common::f_queues]);
            for (auto &f_job : to_submit) {
                Equation::f_jobs[(thread_number % Common::f_queues)].push_back(f_job);
            }
        }

        Equation::f_submit_cond[(thread_number % Common::f_queues)].notify_all();

        to_submit.clear();
        terms.clear();

        while (submitted != 0) {
            auto start_timeA = chrono::steady_clock::now();
            unique_lock<mutex> guard(Equation::f_receive_mutex[thread_number]); // mutex is locked
            Equation::f_receive_cond[thread_number].wait(
                guard, [thread_number]() { return !Equation::f_result[thread_number].empty(); });
            // mutex is unlocked while waiting, then locked again
            pair<Point, string> res = *(Equation::f_result[thread_number].begin()); // take the result
            Equation::f_result[thread_number].pop_front();                          // remove result from queue
            guard.unlock();                                                         // unlock guard, proceed to work;
            auto stop_timeA = chrono::steady_clock::now();
            Common::thread_time -= chrono::duration_cast<chrono::microseconds>(stop_timeA - start_timeA).count();

            if (res.second != "0") {
                terms.emplace_back(res.first, res.second);
            }
            submitted--;
        }
    }
    sort(terms.begin(), terms.end(), pair_point_coeff_smaller);
}

#endif

// submit to fermat evaluation queue and wait for the result
void calc_wrapper(string &s, unsigned short thread_number) {
    if (s == "")
        return;
    // cout<< "INPUT IS " << s << endl;
    if (Common::send_to_parent) {
        fputs("1\n", Common::child_stream_from_child);
        fflush(Common::child_stream_from_child);
        char buf[sizeof(Point) * 2 + 1];
        buf[sizeof(Point) * 2] = '\0';
        Point p;
        p.SafeString(buf);

        fputs(buf, Common::child_stream_from_child);
        fputs(s.c_str(), Common::child_stream_from_child);
        fputs("\n", Common::child_stream_from_child);
        fflush(Common::child_stream_from_child);

        size_t buf_size = 3;
        char *bbuf = static_cast<char *>(malloc(buf_size));
        if (!bbuf) {
            cout << "Cannot malloc in calc_wrapper" << endl;
            abort();
        }

        read_from_stream(&bbuf, &buf_size, Common::child_stream_to_child);
        bbuf[strlen(bbuf) - 1] = '\0';
        s = (bbuf + sizeof(Point) * 2);
        free(bbuf);
    } else {
        {
            lock_guard<mutex> guard(Equation::f_submit_mutex[thread_number % Common::f_queues]);
            Equation::f_jobs[(thread_number % Common::f_queues)].emplace_back(thread_number,
                                                                              pair<Point, string>(Point(), s));
        }

        Equation::f_submit_cond[(thread_number % Common::f_queues)]
            .notify_one(); // one because there is only one evaluation task

        unique_lock<mutex> guard(Equation::f_receive_mutex[thread_number]);
        Equation::f_receive_cond[thread_number].wait(
            guard, [thread_number]() { return !Equation::f_result[thread_number].empty(); });
        pair<Point, string> res = *(Equation::f_result[thread_number].begin());
        Equation::f_result[thread_number].pop_front();
        guard.unlock();
        s = res.second;
    }
}

void f_worker(unsigned short fnum, unsigned short qnum) {

    while (true) {
        unique_lock<mutex> guard(Equation::f_submit_mutex[qnum]); // it's locked
        Equation::f_submit_cond[qnum].wait(guard,
                                           [qnum]() { return (Equation::f_stop || !Equation::f_jobs[qnum].empty()); });
        // predicate is checked on locked mutex. if we are out, is is still locked,
        // but while we are waiting, it's not
        if (Equation::f_stop) {
            break; // time to stop, and the mutex get's unlocked on contex end
        }
        int t_number = Equation::f_jobs[qnum].begin()->first;
        pair<Point, string> f_submit = Equation::f_jobs[qnum].begin()->second;
        Equation::f_jobs[qnum].pop_front(); // we take the data out of the queue
        guard.unlock();                     // mutex is unlocked for other threads, and we start working

        auto start_time = chrono::steady_clock::now();
        fuel::simplify(f_submit.second, fnum);
        auto stop_time = chrono::steady_clock::now();
        Common::simplify_time += chrono::duration_cast<chrono::microseconds>(stop_time - start_time).count();

        {
            lock_guard<mutex> receive_guard(Equation::f_receive_mutex[t_number]);
            Equation::f_result[t_number].push_back(f_submit);
        }
        Equation::f_receive_cond[t_number].notify_one(); // only one should be waiting
    }
}
