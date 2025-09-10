/** @file functions.h
 * @author Alexander Smirnov
 *
 * This file is a part of the FIRE package
*/


#ifndef FUNCTIONS_H_INCLUDED
#define FUNCTIONS_H_INCLUDED

#include "equation.h"
#include "FSBAllocator.hh"

// for function implementations see functions.cpp
/**
 * Fork and run the FLAME child on sector.
 * @param pipe_from_child pipe that child will write to
 * @param pipe_to_child pipe that child will read from
 * @param test_sector sector that child will work in -- negative sector numbers are used during backsub
 * @param thread_ready thread number for the child (fuel usage and diagnostics)
 */
void run_child(int *pipe_from_child, int *pipe_to_child, int test_sector, int thread_ready);

/**
 * Master thread watching the child and using fuel for it.
 * @param pipe_from_child pipe that child will write to
 * @param pipe_to_child pipe that child will read from
 * @param test_sector sector that child will work in  -- negative sector numbers are used during backsub
 * @param thread_ready thread number for the child (fuel usage and diagnostics)
 * @param pid child process id
 */
void watch_child(int *pipe_from_child, int *pipe_to_child, int test_sector, int thread_ready, pid_t pid);

/**
 * Formatting size for output in gigabytes
 * @param size in bytes
 * @return resulting string
 */
string GBsize(int64_t size);

/**
 * Get real database size on disk.
 * @param number sector number
 * @return size on disk in bytes
 */
int64_t realsize(sector_count_t number);

/**
 * UNIX way to read memory usage to the global vsize and rss variables.
 * @param silent if true, do not print anything
 */
void process_mem_usage(bool silent = false);

/**
 * Print used memory.
 * @param mem memory ammount measured in bytes
 * @param power_level make output in: 0=bytes, 1=kilo, 2=mega, 3=giga
 * @param silent 1 - force silent, -1 - force non-silent, 0 - executable default (common::silent)
 */
void print_memory(__uint64_t mem, int power_level, int silent = 0);

/**
 * @param power_level level to print, 0->bytes, 1->kilo, 2->mega, 3->giga
 * @return abbreviation of used unit of memory measurement
 */
string mem_symbol(int power_level);

/**
 * Substitute lower table values into a given table expression.
 * @param terms the sum of points with coeffcients
 * @param forward_mode indication whether everything lower than this sector should be masked
 * @param fixed_last indication whether the highest term should not be touched and loaded from the database
 * @param fixed_database_sector sector where work is done
 * @param sector_level level of this sector
 * @param thread_number number of the working thread
 */
void apply_table(const vector<pair<point, COEFF> > &terms, bool forward_mode, bool fixed_last,
                 sector_count_t fixed_database_sector, unsigned short sector_level, unsigned int thread_number);

/**
 * The whole list of integrals "recursively" obtained by table forward pass from a given integral or a set
 * @param to_test integrals that are to be expressed, this set is changed by the function call
 * @param sector_number sector to work in
 * @return a return iterator from where to start substitutions from
 */
set<point, indirect_more>::reverse_iterator expressed_by(set<point, indirect_more> &to_test, sector_count_t sector_number);

/**
 * Obtain the list of integrals a set of integrals is expressed by,
 * then substitute everything possible starting from smallest integrals.
 * Works in a sector. With forward mode masks lower points with split.
 * @param to_test set of integrals coming as a map for optimization reasons, values should be empty
 * @param sector sector we work in
 * @param thread_number thread number to print and use fuel properly
 * @return indication whether this relation does not completely reduce to lower sectors and should be thrown away
 */
bool express_and_pass_back(map<point, vector<pair<point, COEFF> >, indirect_more, ALLOCATOR1 > &to_test,
                           sector_count_t sector, unsigned int thread_number);

/**
 * Backward reduction stage after the whole reduction.
 * Only substitutions are made but they have to be done from lowest integrals upwards.
 * @param cur_set set of points we are traversing for substitutions
 * @param ritr revers iterator indicating the position to start
 * @param fixed_database_sector sector we are substituting in
 */
void pass_back(const set<point, indirect_more> &cur_set, set<point, indirect_more>::const_reverse_iterator ritr,
          sector_count_t fixed_database_sector);

#if defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
/**
 * @brief Create tail masking and virtual integrals.
 *
 * The table expression for an integral is split into two parts -
 * the terms corresponding to the same sector and lower terms, the tail;
 * a new virtual integral is introduced and its table is set to be equal to the tail.
 * The tail in the original expression is replaced by this new integral.
 * Used in PRIME version of FIRE.
 * @param terms the set of terms to be split
 * @param sector_number sector to work in
 * @return iterator indicating the first element of the list to be left
 */
list<pair<point, COEFF>, ALLOCATOR2 >::iterator
split(list<pair<point, COEFF>, ALLOCATOR2 > &terms, sector_count_t sector_number);
#endif
#if !defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
/**
 * @brief Create tail masking and virtual integrals.
 *
 * The table expression for an integral is split into two parts -
 * the terms corresponding to the same sector and lower terms, the tail;
 * a new virtual integral is introduced and its table is set to be equal to the tail.
 * The tail in the original expression is replaced by this new integral.
 * Used in non-PRIME version of FIRE.
 * @param terms the set of terms to be split
 * @param sector_number sector to work in
 */
void split(vector<pair<point, COEFF> > &terms, sector_count_t sector_number);
#endif

#if defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
/**
 * Wrapper for templated add_to(), for case when the added terms are in vector. Only in PRIME version of FIRE.
 * @param terms1 equation that is to be changed (a -> a + c*b)
 * @param terms2 second equation in form of vector (b)
 * @param coeff coefficient (c)
 * @param skip_last indication whether to ignore last element of (b)
 */
void add_to(list<pair<point, COEFF>, ALLOCATOR2 > &terms1, const vector<pair<point, COEFF> > &terms2, const COEFF &coeff, bool skip_last);

/**
 * Wrapper for templated add_to(), for case when the added terms are in list. Only in PRIME version of FIRE.
 * @param terms1 equation that is to be changed (a -> a + c*b)
 * @param terms2 second equation in form of list (b)
 * @param coeff coefficient (c)
 * @param skip_last indication whether to ignore last element of (b)
 */
void add_to(list<pair<point, COEFF>, ALLOCATOR2 > &terms1, const list<pair<point, COEFF>, ALLOCATOR2 > &terms2, const COEFF &coeff, bool skip_last);

/**
 * Add terms starting at termsB and ending at termsE to terms1.
 * It is assumed, that termsB and termsE are beginning and end of the same STL container.
 * Only in PRIME version of FIRE.
 * @param terms1 equation that is to be changed (a -> a + c*b)
 * @param termsB start of second equation (b)
 * @param termsE end of second equation (b)
 * @param coeff coefficient (c)
 * @param skip_last indication whether to ignore last element of (b)
 */
template<class I>
void add_to(list<pair<point, COEFF>, ALLOCATOR2 > &terms1, I termsB, I termsE, const COEFF &coeff, bool skip_last);
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
void add(const vector<pair<point, COEFF> > &terms1, const vector<pair<point, COEFF> > &terms2,
         vector<pair<point, COEFF> > &rterms, const COEFF &coeff, bool skip_last);
#endif

/**
 * Apply an IBP (index substitution).
 * @param ibp the ibp to be applied
 * @param v point to apply in
 * @param ssector_fast sector where ibp is applied
 * @param thread_number number of thread for fuel usage
 * @return resulting equation, nullptr if trivial
 */
equation* apply(const vector<pair<vector<COEFF>, point_fast > >& ibp, point_fast v, const SECTOR ssector_fast, unsigned int thread_number);

/**
 * Fast way to find lowest in sector under the assumption that it is the lowest sector in orbit.
 * @param p point in question
 * @param s a sector corresponding to p
 * @param sym symmetries
 * @return lowest point in sector
 */
point_fast lowest_in_sector_orbit_fast(const point_fast &p, SECTOR s, const vector<vector<vector<t_index> > > &sym);


/**
 * This function is used for the forward reduction, that can be different
 * In case LiteRed rules (covering all the sector) or LiteRed external symmetries are found, they are used
 * Otherwise it used the Laporta algorithm for reduction.
 * @param thread_number thread number to use proper fuel and for diagnostic
 * @param ssector_number number of sector to work in
 */
void forward_stage(unsigned short thread_number, sector_count_t ssector_number);

/**
 * This function is used for the backward substitution.
 * It is pretty strainforward, simply substituting integrals in theis accending order.
 * However with multple variables this can be pretty memory-consuming.
 * @param thread_number thread number to use proper fuel and for diagnostic
 * @param ssector_number number of sector to work in
 */
void perform_substitution(unsigned short thread_number, sector_count_t ssector_number);

/**
 * Main evaluation routine used in the main FIRE process.
 * First goes downward, running the FLAME processes that use forward_stage.
 * Then goes upwards, and called FLAME processes use perform_substitution.
 */
void Evaluate();

/**
 * Main payload of FLAME binary, implements connection to master process and setting up all
 * communication threads and worker threads.
 */
void work_with_master();

/**
 * Sort IBPs using all relevant information without generating them (we know the highest member)
 * @param p corner of the sector to work in
 * @param current_levels levels that IBPs are generated in
 * @param ibps_vector location to write data to generate IBPs to (pairs of points and equation numbers)
 * @param IBPdegree vector if ibp degrees without index substitution (non-negative shift)
 * @param IBPdegreeFull vector if ibp degrees without index substitution (any shift)
 * @return number of IBPs to be generated
 */
unsigned int sort_ibps(const point &p, const set<pair<unsigned int, unsigned int> > &current_levels,
                       vector<pair<point, pair<point_fast, unsigned short> > > &ibps_vector,
                       const vector<point_fast> &IBPdegree,
                       const vector<point_fast> &IBPdegreeFull);


/**
 * Print “new master integral message”, add the integral to preferred,
 * create a rule mapping it to sector 1.
 * As a result the master integral will be masked during the forward stage.
 * @param p the point being set a master
 */
void make_master(const point &p);

/**
 * Take a linear combination of two ibps
 * @param first_mul the first coefficient
 * @param second_mul the second coefficient
 * @param first the first ibp
 * @param second the second ibp
 * @param sector_fast sector we work in, used for sorting
 * @param result the place to write first_mul*first+second_mul*second
 */
void add_ibps(const COEFF& first_mul, const COEFF& second_mul, const ibp_type& first, const ibp_type& second, const SECTOR sector_fast, ibp_type& result);

/**
 * Find the matching index for two vectors of coefficients at multiplication operators if it is single
 * @param first the first vector
 * @param second the second vector
 * @return -1 if there are no indices or if they are multiple, the index if it single
 */
int matching_index(const vector<COEFF>& first, const vector<COEFF>& second);

/**
 * Resolve ibps without substtuting indices. ONLY linear combinations/
 * @param ibps the set of ibps that will be changed
 * @param sector_fast sector we work in
 */
void improve_ibps(vector<ibp_type>& ibps,SECTOR sector_fast);

/**
 * Thread routine, works in a particular level (here in means the number of dots and the number of numerators)
 * Performs actual Laporta reduction with ibps generated in this level.
 * Mostly independent from other level workers, but they share the database and the virtual number.
 * @param Corner the corner point of the sector
 * @param ibps the relations, alredy sorted and improved; COEFFs are split by indices
 * @param thread_number thread number to separate fuel requests
 */
void reduce_in_level(point Corner, vector<ibp_type> ibps, unsigned int thread_number);

/**
 * Run through points of corresponding levels and call make_master for those that do not have tables.
 * This is called when there is no more chance to obtan a table for those.
 * @param Corner corner point of the sector
 * @param pos number of dots - the level we stopped working with
 * @param neg number of numerators
 */
void mark_master_integrals(const point &Corner, const unsigned int pos, const unsigned int neg);

/**
 * Get complexity levels less than the current one.
 * @param p0 number of dots
 * @param m0 number of numerators
 * @return vector of resulting levels (pairs)
 */
vector<pair<unsigned int, unsigned int> > under_levels(const unsigned int p0, const unsigned int m0);

/**
 * Add the point to the list of points needed in lower sectors.
 * They will be passed to lower databases and used there as a list of points for reduction.
 * @param needed_lower map of lower sectors to needed in those sectora points
 * @param p point to add to this map
 */
void add_needed(map<sector_count_t, set<point> > &needed_lower, const point &p);

/**
 * Remove unneeded integrals after the sector is over.
 * @param sn sector number
 * @param ivpl either a nullptr, or a point to a set of integrals that should be kept
 */
void clear_sector(sector_count_t sn, set<point, indirect_more> *ivpl);

/**
 * Functor for comparing monoms (pair of point and coeff) by point.
 * @param lhs first pair
 * @param rhs second pait
 * @return true if first is less
 */
bool sort_pair_point_coeff_by_point(const pair<point, COEFF> &lhs, const pair<point, COEFF> &rhs);

/**
 * Join monoms that have same point and update coefficient by it.
 * Return vector of grouped monoms, meaning there are no two elements in it with the same point.
 * Works on sorted vector of monoms.
 * @param mon vector of pairs of points and coeffs
 * @return joint vector of points and coefs
 */
vector<pair<point, COEFF> > group_equal_in_sorted(const vector<pair<point, COEFF> > &mon);

/**
 * Calculate difference between two time stamps.
 * @param result resulting timeval struct that is the difference
 * @param x end time
 * @param y beginning time
 */
void timeval_subtract(timeval *result, timeval *x, timeval *y);

#endif // FUNCTIONS_H_INCLUDED
