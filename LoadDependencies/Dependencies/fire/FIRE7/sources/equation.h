/** @file equation.h
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 */

#ifndef EQUATION_H_INCLUDED
#define EQUATION_H_INCLUDED

#include <chrono>
#include <condition_variable>
#include <mutex>
#include <semaphore.h>
#include <thread>

#include "../extra/fuel/library/fuel.h"
#include "point.h"

/**
 * @brief Equation class is for temporary equations not stored in final tables.
 *
 * Usually equations are generated from IBP's.
 * The equations are NOT stored in databases.
 */
class Equation {
  public:
    /**
     * Global storage for requested initial integrals. Second is true if it is not
     * only in combinations
     */
    inline static map<vector<t_index>, pair<Point, bool>> initial;

    /**
     * Global storage for combinations read from input file
     */
    inline static std::vector<std::vector<std::pair<Point, COEFF>>> combinations = {};

    /**
     * Global storage for unsubstituted combinations read from input file to be
     * saved to tables
     */
    inline static std::vector<std::vector<std::pair<Point, string>>> combinations_unsubstituted = {};

    /**
     * Global storage for initial rules so that they can be used as equations.
     */
    inline static std::vector<std::vector<std::pair<Point, COEFF>>> initial_rules = {};

    /**
     * Global storage for initial masters that come from rules and masters
     * settings.
     */
    inline static std::set<Point> initial_masters = {};

    /** @name Fermat mutexes, semaphores and threads. */
    /**@{*/
    /**
     *  Array of mutexes for each fermat thread that control submission of job to
     * queue.
     */
    static mutex f_submit_mutex[MAX_THREADS];
    /**
     *  Array of mutexes for each fermat thread that control receiving of job to
     * queue.
     */
    static mutex f_receive_mutex[MAX_THREADS];
    /**
     *  Array of conditional variables for each fermat queue that control
     * submission of job to queue. Used to wait for availability of tasks.
     */
    static condition_variable f_submit_cond[MAX_THREADS];
    /**
     *  Array of condition variables for each fermat queue that control submission
     * of job to queue. Used to wait for availability of results
     */
    static condition_variable f_receive_cond[MAX_THREADS];
    /**
     *  Array of threads that will have f_worker() routine.
     */
    static thread f_threads[MAX_THREADS];
    /**@}*/

    /**
     * List of jobs for fermat workers.
     */
    static list<pair<int, pair<Point, string>>> f_jobs[MAX_THREADS];

    /**
     * Flag that indicates whether fermat jobs should stop.
     */
    static bool f_stop;

    /**
     * List of calculated results from fermat workers.
     */
    static list<pair<Point, string>> f_result[MAX_THREADS];

    Equation() = default;

    /** Copy assignment is removed
     * @return nothing
     */
    Equation &operator=(const Equation &) = delete;

    /** Copy constructor is removed
     */
    Equation(const Equation &) = delete;

    /** Move assignment. Leaves the source Equation empty
     * @param eq source equation
     * @return out equation
     */
    Equation &operator=(Equation &&eq) {
        this->terms.swap(eq.terms);
        this->source.swap(eq.source);
        return *this;
    };

    /** Move constructor.
     * @param eq the source equation, that is left empty
     */
    Equation(Equation &&eq) {
        this->terms.swap(eq.terms);
        this->source.swap(eq.source);
    }

    /**
     * Constructor for Equation of n-th order.
     * Reserving a vector size, setting maximal size
     * @param n order of equation.
     */
    explicit Equation(unsigned int n) { this->terms.reserve(n); }

    /**
     * Constructor for Equation by terms
     * @param input_terms the terms.
     */
    Equation(vector<pair<Point, COEFF>> &input_terms) { terms = input_terms; }
    /**
     * Actual terms.
     */
    vector<pair<Point, COEFF>> terms;

    /**
     * IBP indication.
     */
    pair<FastPoint, unsigned short> source;
};

/**
 * Compare pairs of points and coefficients by points only.
 * @param lhs first point.
 * @param rhs second point.
 * @return true if Point in first pair is smaller than Point in second pair.
 */
bool pair_point_coeff_smaller(const pair<Point, COEFF> &lhs, const pair<Point, COEFF> &rhs);

/**
 * Checks whether a Point is empty in the database (no entry or 0-length monom).
 * @param p point
 * @param sector_number sector where we are looking, 0 if we need point's
 * default.
 * @return true if Point is empty in the database, false otherwise.
 */
bool p_is_empty(const Point &p, sector_count_t sector_number = 0);

/**
 * Get monoms and coefficients from a Point (Feynman integral).
 * We accessed database and got record starting at res with length len.
 * @param p point, from which we get monoms and coefficients.
 * @param terms container of monoms which we fill from database
 * @param len the size of terms
 * @param res buffer being analyzed (obtained from database)
 */
template <class I> void p_get_internal(const Point &p, I &terms, unsigned int len, const char *res);

/**
 * Wrapper for template p_get_internal(), for vectors.
 * Performs access to database and finds needed record.
 * @param p point, from which we get monoms and coefficients.
 * @param terms container of monoms which we fill from database
 * @param sector_number sector where we are looking, 0 if we need point's
 * default.
 */
void p_get(const Point &p, vector<pair<Point, COEFF>> &terms, sector_count_t sector_number = 0);

/**
 * Wrapper for template p_get_internal(), for lists.
 * Performs access to database and finds needed record.
 * @param p point, from which we get monoms and coefficients.
 * @param terms container of monoms which we fill from database
 * @param sector_number sector where we are looking, 0 if we need point's
 * default.
 */
void p_get(const Point &p, list<pair<Point, COEFF>> &terms, sector_count_t sector_number = 0);

/**
 * Wrapper for template p_set(), for vectors.
 * @param p point, for which we set monoms and coefficients.
 * @param terms vector of terms to be set
 * @param needed_higher whether this Point is needed in upper sectors or is a
 * master
 * @param sector_number sector where we are looking, 0 if we need point's
 * default.
 */
void p_set(const Point &p, const vector<pair<Point, COEFF>> &terms, bool needed_higher,
           sector_count_t sector_number = 0);

/**
 * Wrapper for template p_set(), for lists.
 * @param p point, for which we set monoms and coefficients.
 * @param terms list of terms to be set
 * @param needed_higher whether this Point is needed in upper sectors or is a
 * master
 * @param sector_number sector where we are looking, 0 if we need point's
 * default.
 */
void p_set(const Point &p, const list<pair<Point, COEFF>> &terms, bool needed_higher, sector_count_t sector_number = 0);

/**
 * Set monoms and coefficients for a Point (Feynman integral).
 * We use database access for this.
 * @tparam I iterator template for STL containers.
 * @param p point, for which we set monoms and coefficients.
 * @param n size of equation.
 * @param termsB beginning of container of monoms which we will write to
 * database.
 * @param termsE end of container of monoms which we will write to database.
 * @param needed_higher whether this Point is needed in upper sectors or is a
 * master
 * @param sector_number sector where we are looking, 0 if we need point's
 * default.
 */
template <class I>
void p_set(const Point &p, unsigned int n, I termsB, I termsE, bool needed_higher, sector_count_t sector_number);

#include "equation.inl"

/**
 * Get monoms from a Point (Feynman integral).
 * We access database for this.
 * @param p point, from which we get monoms and coefficients.
 * @param sector_number sector where we are looking, 0 if we need point's
 * default.
 * @return vector of points, essentially monoms with coefficients equal to 1.
 */
vector<Point> p_get_monoms(const Point &p, sector_count_t sector_number = 0);

/**
 * Submit Equation to fermat evaluation queue and wait for the result.
 * @param s string to be evaluated. Result is also written in this string.
 * @param thread_number fermat thread, in which queue we submit equation.
 */
void calc_wrapper(string &s, unsigned short thread_number); // if null, not clearing

#if !defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)

/**
 * Usual terms normalization via fermat.
 * Used in non modular arithmetic version.
 * Used in non-PRIME version of FIRE.
 * @param terms terms to be normalized. Result is also written here.
 * @param thread_number fermat thread, in which queue we submit equation.
 */
void normalize(vector<pair<Point, COEFF>> &terms, unsigned short thread_number);

#endif

/**
 * Get the right symmetry Point by the vector of coordinates.
 * @param v simple vector of coordinates.
 * @return correct symmetry point.
 */
Point point_reference(const vector<t_index> &v);

/**
 * Get the right symmetry Point by FastPoint object.
 * @param v simple FastPoint object, which contains array of coordinates.
 * @return correct symmetry point.
 */
Point point_reference_fast(const FastPoint &v);

/**
 * Correctly compare FastPoint objects in a specific sector.
 * @param pf1 first FastPoint object.
 * @param pf2 second FastPoint object.
 * @param s number of sector where comparison is made.
 * @return true if pf1 < pf2 in this sector, false otherwise.
 */
bool fast_point_smaller_in_sector(const FastPoint &pf1, const FastPoint &pf2, SECTOR s);

/**
 * A special function choosing the lowest vector in its symmetry orbit.
 * @param lhs first vector of coordinates.
 * @param rhs second vector of coordinates.
 * @return true, if lhs is lower than rhs, false otherwise.
 */
bool is_lower_in_orbit(const vector<t_index> &lhs, const vector<t_index> &rhs);

/**
 * Fermat worker thread. Receives tasks from queue, used fermat to calculate,
 * puts results back
 * @param fnum number of fermat process to be used
 * @param qnum number of the queue to receive tasks from
 */
void f_worker(unsigned short fnum, unsigned short qnum);

#endif // EQUATION_H_INCLUDED
