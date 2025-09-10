/** @file equation.h
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 */

#ifndef EQUATION_H_INCLUDED
#define EQUATION_H_INCLUDED

#include "point.h"

#include "../extra/fuel/library/fuel.h"

#include <semaphore.h>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <chrono>

#include "FSBAllocator.hh"

#define ALLOCATOR1 FSBAllocator2<pair<const point, vector<pair<point,COEFF> > > >
///<faster allocation for maps
#define ALLOCATOR2 allocator<pair<point,COEFF> >
///<currently a placeholder for the default allocator

/**
 * @brief Elementary term of a equation.
 *
 * Consists of a point and COEFF of the point.
 */
struct MONOM {
    point p; /**< point (integral) */
    COEFF c; /**< coefficient which can be either a string or a number */
};

/**
 * @brief Equation class is for temporary equations not stored in final tables.
 *
 * Usually equations are generated IBP's.
 * The equations are NOT stored in databases.
 */
class equation {
public:
    /**
     * Global storage for requested initial integrals.
     */
    static map<vector<t_index>, point> initial;

    /** @name fuel mutexes, semaphores and threads. */
    /**@{*/
    /**
    *  Array of mutexes for each fuel thread that control submission of job to queue.
    */
    static mutex f_submit_mutex[MAX_THREADS];
    /**
  *  Array of mutexes for each fuel thread that control receiving of job to queue.
  */
    static mutex f_receive_mutex[MAX_THREADS];
    /**
    *  Array of conditional variables for each fuel queue that control submission of job to queue. Used to wait for availability of tasks.
    */
    static condition_variable f_submit_cond[MAX_THREADS];
    /**
    *  Array of condition variables for each fuel queue that control submission of job to queue. Used to wait for availability of results
    */
    static condition_variable f_receive_cond[MAX_THREADS];
    /**
    *  Array of threads that will have f_worker() routine.
    */
    static thread f_threads[MAX_THREADS];
    /**@}*/

    /**
     * List of jobs for fuel workers.
     */
    static list<pair<int, pair<point, string> > > f_jobs[MAX_THREADS];

    /**
     * Flag that indicates whether fuel jobs should stop.
     */
    static bool f_stop;

    /**
     * List of calculated results from fuel workers.
     */
    static list<pair<point, string> > f_result[MAX_THREADS];


    equation() {
        cout << "no default construction for equation" << endl;
        abort();
    }

    /**
     * Constructor for equation of n-th order.
     * Here we only create an array of pointers.
     * Length is set to 0 because n is capacity, real length has to be set later.
     * @param n order of equation.
     */
    explicit equation(unsigned int n) {
        this->length = 0; // not setting length
        this->terms = static_cast<MONOM **>(malloc(sizeof(MONOM *) * n));
        if (!this->terms) {
            cout<<"Cannot malloc in equation constructor"<<endl;
            abort();
        }
        this->data = new MONOM[n];
        for (unsigned int i = 0; i != n; ++i) terms[i] = data + i;

    }

    ~equation() {
        delete[](this->data);
        free(this->terms);
    };

    /**
     * Pointers to data members. See equation(n) for details.
     */
    MONOM **terms{};

    /**
     * Actual allocated terms.
     */
    MONOM *data{}; // the actual terms. The terms members are initially pointing at data members;

    /**
     * IBP indication.
     */
    pair<point_fast, unsigned short> source;

    /**
     * Real size of equation.
     */
    unsigned int length{};
};

/**
 * Compare pairs of points and coefficients by points only.
 * @param lhs first point.
 * @param rhs second point.
 * @return true if point in first pair is smaller than point in second pair.
 */
bool pair_point_COEFF_smaller(const pair<point, COEFF> &lhs, const pair<point, COEFF> &rhs);

/**
 * Checks whether a point is empty in the database (no entry or 0-length monom).
 * @param p the point being checked
 * @param fixed_database_sector sector where we are looking, 0 if we need point's default.
 * @return true if point is empty in the database, false otherwise.
 */
bool p_is_empty(const point &p, sector_count_t fixed_database_sector = 0);

/**
* Get monoms and coefficients from a point (Feynman integral).
* We accessed database and got record starting at res with length len.
* @param p point, from which we get monoms and coefficients.
* @param terms container of monoms which we fill from database
* @param dsector destination sector where we are working
* @param len the size of terms
* @param res buffer being analyzed (obtained from database)
*/
template<class I>
void p_get_internal(const point &p, I& terms, sector_count_t dsector, unsigned short len, char* res);

/**
 * Wrapper for template p_get_internal(), for vectors.
 * Performs access to database and finds needed record.
 * @param p point, from which we get monoms and coefficients.
 * @param terms container of monoms which we fill from database
 * @param fixed_database_sector sector where we are looking, 0 if we need point's default.
 */
void p_get(const point &p, vector<pair<point, COEFF> > &terms, sector_count_t fixed_database_sector = 0);

/**
 * Wrapper for template p_get_internal(), for lists.
 * Performs access to database and finds needed record.
 * @param p point, from which we get monoms and coefficients.
 * @param terms container of monoms which we fill from database
 * @param fixed_database_sector sector where we are looking, 0 if we need point's default.
*/
void p_get(const point &p, list<pair<point, COEFF>, ALLOCATOR2> &terms, sector_count_t fixed_database_sector = 0);


/**
 * Wrapper for template p_set(), for vectors.
 * @param p point, for which we set monoms and coefficients.
 * @param terms vector of terms to be set
 * @param level level needed up to, where 127 is master, 126 is absolutely needed, for other cases it is level*2, but for lsymmetries level*2+1
 * @param fixed_database_sector sector where we are looking, 0 if we need point's default.
 */
void p_set(const point &p, const vector<pair<point, COEFF> > &terms, unsigned char level,
           sector_count_t fixed_database_sector = 0);

/**
 * Wrapper for template p_set(), for lists.
 * @param p point, for which we set monoms and coefficients.
 * @param terms list of terms to be set
 * @param level level needed up to, where 157 is master, 126 is absolutely needed, for other cases it is level*2, but for lsymmetries level*2+1
 * @param fixed_database_sector sector where we are looking, 0 if we need point's default.
 */
void p_set(const point &p, const list<pair<point, COEFF>, ALLOCATOR2 > &terms, unsigned char level,
           sector_count_t fixed_database_sector = 0);

/**
 * Set monoms and coefficients for a point (Feynman integral).
 * We use database access for this.
 * @tparam I iterator template for STL containers.
 * @param p point, for which we set monoms and coefficients.
 * @param n size of equation.
 * @param termsB beginning of container of monoms which we will write to database.
 * @param termsE end of container of monoms which we will write to database.
 * @param level level needed up to, where 127 is master, 126 is absolutely needed, for other cases it is level*2, but for lsymmetries level*2+1
 * @param fixed_database_sector sector where we are looking, 0 if we need point's default.
 */
template<class I>
void p_set(const point &p, unsigned int n, I termsB, I termsE,
           unsigned char level, sector_count_t fixed_database_sector);

#include "equation.inl"

/**
 * Get monoms from a point (Feynman integral).
 * We access database for this.
 * @param p point, from which we get monoms and coefficients.
 * @param fixed_database_sector sector where we are looking, 0 if we need point's default.
 * @return vector of points, essentially monoms with coefficients equal to 1.
 */
vector<point> p_get_monoms(const point &p, sector_count_t fixed_database_sector = 0);

/**
 * Submit equation to fuel evaluation queue and wait for the result.
 * @param s string to be evaluated. Result is also written in this string.
 * @param thread_number fuel thread, in which queue we submit equation.
 */
void calc_wrapper(string &s, unsigned short thread_number);// if null, not clearing

#if !defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)

/**
 * Usual terms normalization via fuel.
 * Used in non modular arithmetic version.
 * Used in non-PRIME version of FIRE.
 * @param terms terms to be normalized. Result is also written here.
 * @param thread_number fuel thread, in which queue we submit equation.
 */
void normalize(vector<pair<point, COEFF> > &terms, unsigned short thread_number);

/**
 * Usual equation normalization.
 * Used in non modular arithmetic version.
 * Used in non-PRIME version of FIRE.
 * @param eq pointer to equation to be normalized.
 * @param thread_number fuel thread, in which queue we submit equation.
 */
void normalize_eq(equation *eq, unsigned short thread_number);
#endif

/**
 * Get the right symmetry point by the vector of coordinates.
 * @param v simple vector of coordinates.
 * @return correct symmetry point.
 */
point point_reference(const vector<t_index> &v);

/**
 * Get the right symmetry point by point_fast object.
 * @param v simple point_fast object, which contains array of coordinates.
 * @return correct symmetry point.
 */
point point_reference_fast(const point_fast &v);

/**
 * Correctly compare point_fast objects in a specific sector.
 * @param pf1 first point_fast object.
 * @param pf2 second point_fast object.
 * @param s number of sector where comparison is made.
 * @return true if pf1 < pf2 in this sector, false otherwise.
 */
bool point_fast_smaller_in_sector(const point_fast & pf1, const point_fast & pf2, SECTOR s);


/**
 * A special function choosing the lowest vector in its symmetry orbit.
 * @param lhs first vector of coordinates.
 * @param rhs second vector of coordinates.
 * @return true, if lhs is lower than rhs, false otherwise.
 */
bool is_lower_in_orbit(const vector<t_index> &lhs, const vector<t_index> &rhs);


/**
 * @brief A functor for comparing points by their values in STL sets.
 */
struct indirect_more {
    /**
     * Indirect more.
     * @param lhs first point.
     * @param rhs second point.
     * @return true if first point is smaller than second, false otherwise.
     */
    bool operator()(const point &lhs, const point &rhs) const {
        return (rhs) < (lhs);
    }
};


/**
 * fuel worker thread. Receives tasks from queue, used fuel to calculate, puts results back
 * @param fnum number of fuel process to be used
 * @param qnum number of the queue to receive tasks from
 */
void f_worker(unsigned short fnum, unsigned short qnum);

#endif // EQUATION_H_INCLUDED
