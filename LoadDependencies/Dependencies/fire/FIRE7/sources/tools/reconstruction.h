#pragma once

#include "tables.h"
#include "tools.h"

#ifdef WITH_MPI
#include "mpi.h"
#endif

#include <../../extra/fuel/usr/include/flint/fmpq_mpoly.h>
#include <../../extra/fuel/usr/include/flint/fmpq_vec.h>
#include <../../extra/fuel/usr/include/flint/fmpz_mpoly.h>
#include <../../extra/fuel/usr/include/flint/nmod.h>
#include <../../extra/fuel/usr/include/flint/nmod_mat.h>
#include <../../extra/fuel/usr/include/flint/nmod_mpoly.h>
#include <../../extra/fuel/usr/include/flint/nmod_poly.h>
#include <../../extra/fuel/usr/include/flint/nmod_vec.h>
#include <optional>

#include "../../extra/fuel/library/mod_uni_ratfunc_flint.h"

/**
 * Prime number we use for modular arithmetic.
 */
extern uint64_t prime;
/**
 * Index of prime number in primes array in primes.cpp.
 */
extern unsigned short prime_number;

/**
 * the limb for flint prime
 */
extern mp_limb_t flint_prime;

/**
 * the special flint structure for fast inverting modular prime
 */
extern nmod_t flint_mod;

/**
 * all variables in use
 */
extern std::vector<std::string> vars;

extern std::string skel_var_value;   ///< for balancedZippel the base value of the skeleton variable
extern unsigned long skel_var_power; ///< for balancedZippel it is the power we are reconstructing at

/**
 * Entry api Point for reconstruct.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @param ORIGINAL_RANK optional parameter, for MPI calls only
 * @param ORIGINAL_NET_SIZE optional parameter, for MPI calls only
 * @return 0 on success, but if steps_as_error_code is passed, then the number of steps
 */
int reconstruct(int argc, char *argv[], std::optional<int>, std::optional<int>);
