#include <../../extra/fuel/usr/include/flint/nmod.h>
#include <iostream>
#include <vector>

namespace gpu {
/**
 * Performs GPU part of Zippel reconstruction of multiple expressions for
 * different powers in prime case
 * @param skel_length the length of the skeleton polynomial
 * @param values the 2-dimensional array of values for Zippel reconstruction
 * @param main_pol_coeffs the coefficients of the skeleton
 * @param base the constructed polynomial produce (x-a[i]) for Zippel logit
 * @param results the array of results (coefficients of reconstructed
 * polynomials)
 * @param flint_mod the base for fast nmod operations
 */
void zippel_multiple_prime(size_t skel_length, const std::vector<mp_limb_t> &values, const mp_limb_t *main_pol_coeffs,
                           const std::vector<mp_limb_t> &base, nmod_mpoly_struct *results, nmod_t flint_mod);

/**
 * Prepares coefficients for Zippel reconstruction by substituting powers into
 * the skeleton (balancing)
 * @param check_pol_term the monomials with first power substituted
 * @param check_pol_term_prev the coefficients
 * @param check_pol_len length of skeleton
 * @param valuesSize the number of Newton values
 * @param flint_mod the base for fast nmod operations
 * @return the coefficients that are prepared for following reconstruction
 */
std::vector<mp_limb_t> prepare_coeffs(mp_limb_t *check_pol_term, mp_limb_t *check_pol_term_prev, size_t check_pol_len,
                                      size_t valuesSize, nmod_t flint_mod);

/**
 * Prints GPU parameters
 */
void getGPUData();
} // namespace gpu
