/** @file functions.h
 * @author Alexander Smirnov
 *
 * This file is a part of the FIRE package
 */

#ifndef FUNCTIONS_H_INCLUDED
#define FUNCTIONS_H_INCLUDED

#include <functional>
#include <optional>

#include "equation.h"

// for function implementations see functions.cpp

/**
 * Finish calculations in sector, save results in database and print statistics.
 * @param needed_lower set in integrals at are needed in lower sectors and
 * should be written to corresponding databases
 * @param sector_number sector we work in
 * @param ivpl set of points to be kept in disk snapshot, all if nullptr
 */
void finish_sector(const set<Point> &needed_lower, sector_count_t sector_number, set<Point, std::greater<Point>> *ivpl);

/**
 * Master thread watching the child and using fermat for it.
 * @param pipe_from_child pipe that child will write to
 * @param pipe_to_child pipe that child will read from
 * @param sector_number sector that child will work in -- negative sector numbers are used during backsub
 * @param thread_ready thread number for the child (fermat usage and
 * diagnostics)
 * @param pid child process id
 */
void watch_child(int *pipe_from_child, int *pipe_to_child, int sector_number, int thread_ready, pid_t pid);

/**
 * Formatting size for output in gigabytes
 * @param size in bytes
 * @return resulting string
 */
string GBsize(int64_t size);

/**
 * UNIX way to read memory usage to the global vsize and rss variables.
 * @param silent if true, do not print anything
 */
void process_mem_usage(bool silent = false);

/**
 * Print used memory.
 * @param mem memory ammount measured in bytes
 * @param power_level make output in: 0=bytes, 1=kilo, 2=mega, 3=giga
 * @param silent 1 - force silent, -1 - force non-silent, 0 - executable default
 * (Common::silent)
 */
void print_memory(__uint64_t mem, int power_level, int silent = 0);

/**
 * @param power_level level to print, 0->bytes, 1->kilo, 2->mega, 3->giga
 * @return abbreviation of used unit of memory measurement
 */
string mem_symbol(int power_level);

/**
 * Function used to change the number of active sector threads
 * @param old_number old number of threads
 * @param new_number new number of threads
 */
void change_number_of_threads(unsigned int old_number, unsigned int new_number);

#if defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
/**
 * Substitute lower table values into a given table expression in prime mode
 * @param terms the sum of points with coeffcients
 * @param sector_number sector where work is done
 * @param result where to place resulting expression
 * @param temporary_terms a pointer to a vector with a capacity for terms
 * @return true if expression changed and needs to be saved into database
 */
bool apply_table_prime(const vector<pair<Point, COEFF>> &terms, sector_count_t sector_number,
                       list<pair<Point, COEFF>> *result, vector<pair<Point, COEFF>> *temporary_terms);
#endif

#if (!defined(PRIME)) || defined(DOXYGEN_DOCUMENTATION)
/**
 * Substitute lower table values into a given table expression in poly mode.
 * @param terms the sum of points with coeffcients
 * @param forward_mode indication whether everything lower than this sector
 * should be masked
 * @param fixed_last indication whether the highest term should not be touched
 * and loaded from the database
 * @param sector_number sector where work is done
 * @param thread_number number of the working thread
 */
void apply_table_poly(const vector<pair<Point, COEFF>> &terms, bool forward_mode, bool fixed_last,
                      sector_count_t sector_number, unsigned int thread_number);
#endif

/**
 * The whole list of integrals "recursively" obtained by table forward pass from
 * a given integral or a set
 * @param to_test integrals that are to be expressed, this set is changed by the
 * function call
 * @param sector_number sector to work in
 * @return a return iterator from where to start substitutions from
 */
set<Point, std::greater<Point>>::reverse_iterator expressed_by(set<Point, std::greater<Point>> &to_test,
                                                               sector_count_t sector_number);

#ifndef PRIME
/**
 * Obtain the list of integrals a set of integrals is expressed by,
 * then substitute everything possible starting from smallest integrals.
 * Works in a sector. With forward mode masks lower points with split.
 * @param to_test set of integrals coming as a map for optimization reasons,
 * values should be empty
 * @param sector sector we work in
 * @param thread_number thread number to print and use fermat properly
 * @return indication whether this relation does not completely reduce to lower
 * sectors and should be thrown away
 */
bool express_and_pass_back(map<Point, vector<pair<Point, COEFF>>, std::greater<Point>> &to_test, sector_count_t sector,
                           unsigned int thread_number);
#endif

/**
 * Backward reduction stage after the whole reduction.
 * Only substitutions are made but they have to be done from lowest integrals
 * upwards.
 * @param cur_set set of points we are traversing for substitutions
 * @param sector_number sector we are substituting in
 */
void pass_back(const set<Point, std::greater<Point>> &cur_set, sector_count_t sector_number);

#if defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
/**
 * @brief Create tail masking and virtual integrals.
 *
 * The table expression for an integral is split into two parts -
 * the terms corresponding to the same sector and lower terms, the tail;
 * a new virtual integral is introduced and its table is set to be equal to the
 * tail. The tail in the original expression is replaced by this new integral.
 * Used in PRIME version of FIRE.
 * @param terms the set of terms to be split
 * @param sector_number sector to work in
 * @return iterator indicating the first element of the list to be left
 */
list<pair<Point, COEFF>>::iterator split(list<pair<Point, COEFF>> &terms, sector_count_t sector_number);
#endif
#if !defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
/**
 * @brief Create tail masking and virtual integrals.
 *
 * The table expression for an integral is split into two parts -
 * the terms corresponding to the same sector and lower terms, the tail;
 * a new virtual integral is introduced and its table is set to be equal to the
 * tail. The tail in the original expression is replaced by this new integral.
 * Used in non-PRIME version of FIRE.
 * @param terms the set of terms to be split
 * @param sector_number sector to work in
 */
void split(vector<pair<Point, COEFF>> &terms, sector_count_t sector_number);
#endif

#if defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
/**
 * Wrapper for templated add_to(), for case when the added terms are in vector.
 * Only in PRIME version of FIRE.
 * @param terms1 Equation that is to be changed (a -> a + c*b)
 * @param terms2 second Equation in form of vector (b)
 * @param coeff coefficient (c)
 * @param skip_last indication whether to ignore last element of (b)
 */
void add_to(list<pair<Point, COEFF>> &terms1, const vector<pair<Point, COEFF>> &terms2, const COEFF &coeff,
            bool skip_last);

/**
 * Wrapper for templated add_to(), for case when the added terms are in list.
 * Only in PRIME version of FIRE.
 * @param terms1 Equation that is to be changed (a -> a + c*b)
 * @param terms2 second Equation in form of list (b)
 * @param coeff coefficient (c)
 * @param skip_last indication whether to ignore last element of (b)
 */
void add_to(list<pair<Point, COEFF>> &terms1, const list<pair<Point, COEFF>> &terms2, const COEFF &coeff,
            bool skip_last);

/**
 * Add terms starting at termsB and ending at termsE to terms1.
 * It is assumed, that termsB and termsE are beginning and end of the same STL
 * container. Only in PRIME version of FIRE.
 * @param terms1 Equation that is to be changed (a -> a + c*b)
 * @param termsB start of second Equation (b)
 * @param termsE end of second Equation (b)
 * @param coeff coefficient (c)
 * @param skip_last indication whether to ignore last element of (b)
 */
template <class I>
void add_to(list<pair<Point, COEFF>> &terms1, I termsB, I termsE, const COEFF &coeff, bool skip_last);
#endif
#if !defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
/**
 * Sum terms1 and terms2 and write result to rterms.
 * Used in non-PRIME version of FIRE.
 * @param terms1 first summant a
 * @param terms2 second summant b
 * @param rterms place to write a + c*b
 * @param coeff coefficient c
 * @param skip_last indication whether to skip the last term of b
 */
void add(const vector<pair<Point, COEFF>> &terms1, const vector<pair<Point, COEFF>> &terms2,
         vector<pair<Point, COEFF>> &rterms, const COEFF &coeff, bool skip_last);
#endif

/**
 * Generate an IBP (index substitution).
 * @param eq Equation to be generated; if trivial, length is set to zero
 * @param ibp the ibp to be applied
 * @param v Point to apply in
 * @param SectorFast sector where ibp is applied
 */
void generate_equation(Equation &eq, const ibp_type &ibp, FastPoint v, const SECTOR SectorFast);

/**
 * Writes Lee symmetries with the given complexity level to the database.
 * @param p_start corner of the sector
 * @param pos number of dots
 * @param neg number of numerators
 * @param eqs options argument, if present, make new equations pushed to it,
 * otherwise saves to database
 * @param filter_function optional parameter, a filter function that returns
 * `true` only for seed points that need to be used
 * @return number of symmetries written
 */
int write_symmetries(const Point &p_start, const unsigned int pos, const unsigned int neg,
                     std::optional<std::vector<std::vector<std::pair<Point, COEFF>>> *> eqs,
                     std::optional<std::function<bool(const FastPoint &)>> filter_function = std::nullopt);

/**
 * Tries to apply litered external symmetries in a point
 * @param dbasis the symmetries in that sector
 * @param y the point
 * @param p also the point
 * @param mon the result
 */
void try_symmetries_with_lbasis(pair<vector<t_index>, vector<pair<vector<pair<COEFF, FastPoint>>, t_index>>> dbasis,
                                const FastPoint &y, const Point p, vector<pair<Point, COEFF>> &mon);

/**
 * Tries to apply litered rules in a point
 * @param lbasis the rules in that sector
 * @param y the point
 * @param p also the point
 * @param mon the result
 * @return whether it was succesfull (it is not a master)
 */
bool try_reduce_with_lbasis(
    vector<pair<vector<pair<vector<t_index>, pair<short, bool>>>,
                vector<pair<std::vector<std::string>, vector<pair<vector<t_index>, short>>>>>> &lbasis,
    const FastPoint &y, const Point p, vector<pair<Point, COEFF>> &mon);

/**
 * Generate an IBP term (index substitution).
 * @param eq being generated;
 * @param p Point to be put into the Equation for non-zero coefficient
 * @param pf shiftpoint for faster evaluation
 * @param coeffs index-sepated coefficients;
 * @param length current eq length;
 */
void generate_equation_term(Equation &eq, const Point &p, const FastPoint &pf, const vector<COEFF> &coeffs,
                            size_t &length);

/**
 * A thread that goes through the hintn and generates equations
 * @param lhs start of the hint buffer reading point
 * @param hint_contents start of the whole hint, used for error printing
 * @param max_len maximum ibp length
 * @param ibps vector of ibps (not substituted)
 * @param SectorFast current sector
 * @param equation_queue queue of equations put by this thread
 * @param equation_mutex mutex for working with the Equation queue
 * @param equation_prepared conditional variable to signal that a new equation
 * is there
 * @param equation_used conditional variable to receive a signal that the
 * Equation queue has a slot
 * @param time_to_stop used to pass information to the caller thread that there
 * are no more equations left
 */
void equation_generator_thread(const char *lhs, const char *hint_contents, const size_t max_len,
                               const vector<ibp_type> &ibps, SECTOR SectorFast, list<Equation> &equation_queue,
                               mutex &equation_mutex, condition_variable &equation_prepared,
                               condition_variable &equation_used, bool *time_to_stop);

/**
 * Group Equation terms having equal point. Needed normally in case of
 * symmetries in a sector.
 * @param eq equation
 */
void group_equation_terms(Equation &eq);

/**
 * Take a prepared Equation and use it for IBP reduction resulting in tables
 * @param eq equation
 * @param thread_number current thread number
 * @param sector_number current sector number
 * @result indication whether the Equation was used
 */
bool work_with_equation(const Equation &eq, unsigned short thread_number, sector_count_t sector_number);

/**
 * Fast way to find lowest in sector under the assumption that it is the lowest
 * sector in orbit.
 * @param p Point in question
 * @param s a sector corresponding to p
 * @param sym symmetries
 * @return lowest Point in sector
 */
FastPoint lowest_in_sector_orbit_fast(const FastPoint &p, SECTOR s, const vector<vector<vector<t_index>>> &sym);

/**
 * This function is used for the forward reduction, that can be different
 * In case LiteRed rules (covering all the sector) or LiteRed external
 * symmetries are found, they are used Otherwise it used the Laporta algorithm
 * for reduction.
 * @param thread_number thread number to use proper fermat and for diagnostic
 * @param sector_number number of sector to work in
 */
void forward_stage(unsigned short thread_number, sector_count_t sector_number);

/**
 * This function is used for the backward substitution.
 * It is pretty strainforward, simply substituting integrals in theis accending
 * order. However with multple variables this can be pretty memory-consuming.
 * @param thread_number thread number to use proper fermat and for diagnostic
 * @param sector_number number of sector to work in
 */
void perform_substitution(unsigned short thread_number, sector_count_t sector_number);

/**
 * Main evaluation routine used in the main FIRE process.
 * First goes downward, running the FLAME processes that use forward_stage.
 * Then goes upwards, and called FLAME processes use perform_substitution.
 */
void perform_reduction();

/**
 * Sort a range of IBPs without substituted indices
 * The criteria is the highest member and the size if they are equal
 * @param begin the start of the range
 * @param end Point after the range
 * @param s sector where sorting is done
 */
void sort_unsibstituted_ibps(vector<ibp_type>::iterator begin, vector<ibp_type>::iterator end, SECTOR s);

/**
 * Sort IBPs using all relevant information without generating them (we know the
 * highest member)
 * @param p corner of the sector to work in
 * @param current_levels levels that IBPs are generated in
 * @param ibps_vector location to write data to generate IBPs to (pairs of
 * points and Equation numbers)
 * @param IBPdegree vector if ibp degrees without index substitution
 * (non-negative shift)
 * @param IBPdegreeFull vector if ibp degrees without index substitution (any
 * shift)
 * @param filter_function optional parameter, a filter function that returns
 * `true` only for seed points that need to be used
 * @return number of IBPs to be generated
 */
unsigned int sort_ibps(const Point &p, const set<pair<unsigned int, unsigned int>> &current_levels,
                       vector<pair<Point, pair<FastPoint, unsigned short>>> &ibps_vector,
                       const vector<FastPoint> &IBPdegree, const vector<FastPoint> &IBPdegreeFull,
                       std::optional<std::function<bool(const FastPoint &)>> filter_function = std::nullopt);

/**
 * Print “new master integral message”, add the integral to preferred,
 * create a rule mapping it to sector 1.
 * As a result the master integral will be masked during the forward stage.
 * @param p the integral to be set as master
 * @param allow_new_master_in_split_mode self-explaining, false by default
 * @return false if it is master split mode, and we got a new master
 */
bool make_master(const Point &p, bool allow_new_master_in_split_mode = false);

/**
 * Take a linear combination of two ibps
 * @param first_mul the first coefficient
 * @param second_mul the second coefficient
 * @param first the first ibp
 * @param second the second ibp
 * @param SectorFast sector we work in, used for sorting
 * @param result the place to write first_mul*first+second_mul*second
 */
void add_ibps(const COEFF &first_mul, const COEFF &second_mul, const ibp_type &first, const ibp_type &second,
              const SECTOR SectorFast, ibp_type &result);

/**
 * Find the matching index for two vectors of coefficients at multiplication
 * operators if it is single
 * @param first the first vector
 * @param second the second vector
 * @return -1 if there are no indices or if they are multiple, the index if it
 * single
 */
int matching_index(const vector<COEFF> &first, const vector<COEFF> &second);

/**
 * Resolve ibps without substtuting indices. ONLY linear combinations/
 * @param ibps the set of ibps that will be changed
 * @param SectorFast sector we work in
 */
void improve_ibps(vector<ibp_type> &ibps, SECTOR SectorFast);

/**
 * Thread routine, works in a particular level (here in means the number of dots
 * and the number of numerators) Performs actual Laporta reduction with ibps
 * generated in this level. Mostly independent from other level workers, but
 * they share the database and the virtual number.
 * @param Corner the corner Point of the sector
 * @param ibps the relations, alredy sorted and improved; COEFFs are split by
 * indices
 * @param thread_number thread number to separate fermat requests
 */
void reduce_in_level(Point Corner, vector<ibp_type> ibps, unsigned int thread_number);

/**
 * Run through points of corresponding levels and call make_master for those
 * that do not have tables. This is called when there is no more chance to obtan
 * a table for those.
 * @param Corner corner Point of the sector
 * @param pos number of dots - the level we stopped working with
 * @param neg number of numerators
 * @param first_pass whether we are on first pass and should not crash
 * imidiately on a new master in split masters mode
 * @param only_preferred whether we are marking only prefered integrals
 * @return true in most cases, false if there is a new master in masters split
 * mode
 */
bool mark_master_integrals(const Point &Corner, const unsigned int pos, const unsigned int neg, bool first_pass,
                           bool only_preferred);

/**
 * Get complexity levels less than the current one.
 * @param p0 number of dots
 * @param m0 number of numerators
 * @return vector of resulting levels (pairs)
 */
vector<pair<unsigned int, unsigned int>> under_levels(const unsigned int p0, const unsigned int m0);

/**
 * Add the Point to the list of points needed in lower sectors.
 * They will be passed to lower databases and used there as a list of points for
 * reduction.
 * @param needed_lower map of lower sectors to needed in those sectora points
 * @param p Point to add to this map
 */
void add_needed(map<sector_count_t, set<Point>> &needed_lower, const Point &p);

/**
 * Join monoms that have same Point and update coefficient by it.
 * Return vector of grouped monoms, meaning there are no two elements in it with
 * the same point. Works on sorted vector of monoms.
 * @param mon vector of pairs of points and coeffs
 * @return joint vector of points and coefs
 */
vector<pair<Point, COEFF>> group_equal_in_sorted(const vector<pair<Point, COEFF>> &mon);

/**
 * Calculate difference between two time stamps.
 * @param result resulting timeval struct that is the difference
 * @param x end time
 * @param y beginning time
 */
void timeval_subtract(timeval *result, timeval *x, timeval *y);

#endif // FUNCTIONS_H_INCLUDED
