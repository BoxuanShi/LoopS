#ifndef GPU_H
#define GPU_H

#include "gpu.h"

#ifdef __HIP__
#include <hip/hip_runtime.h>

#include "hip_t.h"
#else
#include <cuda_runtime.h>
#endif

#define CHECK(func)                                                                                                    \
    e = (func);                                                                                                        \
    if (e) {                                                                                                           \
        std::cout << "[Warning] GPU Error: " << e << " " << cudaGetErrorString(e) << std::endl;                        \
    }

using ulong = unsigned long;

using namespace std;

template <typename T> struct memory_t {
    T *data;
    size_t size;
    __device__ inline T &operator[](size_t pos) { return data[pos]; }
};

template <typename T> class memory {
  public:
    memory(const std::vector<T> &v) {
        _size = v.size();
        e = cudaMalloc((void **)&_data, v.size() * sizeof(T));
        e = cudaMemcpy(_data, v.data(), v.size() * sizeof(T), cudaMemcpyHostToDevice);
    }

    memory(T *pt, size_t size) {
        _size = size;
        e = cudaMalloc((void **)&_data, _size * sizeof(T));
        e = cudaMemcpy(_data, pt, _size * sizeof(T), cudaMemcpyHostToDevice);
    }

    ~memory() {
        if (_data) {
            e = cudaFree(_data);
        }
    }
    inline T *data() { return _data; }
    inline size_t size() const { return _size; }

    T *copy(T *dest = nullptr, size_t len = -1) {
        if (!dest)
            dest = new T[len];
        if (len == size_t(-1))
            len = size();
        e = cudaMemcpy(dest, data(), len * sizeof(T), cudaMemcpyDeviceToHost);
        return dest;
    }

    T *move(T *dest = nullptr, size_t len = -1) {
        if (!dest)
            dest = new T[len];
        if (len == size_t(-1))
            len = size();
        e = cudaMemcpy(dest, data(), len * sizeof(T), cudaMemcpyDeviceToHost);
        e = cudaFree(data());
        return dest;
    }

    operator std::vector<T>() {
        std::vector<T> ret(size());
        e = cudaMemcpy(ret.data(), data(), size() * sizeof(T), cudaMemcpyDeviceToHost);
        return ret;
    }

    operator memory_t<T>() {
        memory_t<T> ret = {data(), size()};
        return ret;
    }

  protected:
    cudaError_t e;

  private:
    T *_data = nullptr;
    size_t _size = 0;
};

template <typename T> struct pitch_memory_t {
    T *data;
    size_t _vsize;
    size_t hsize;
    size_t pitch;

    struct pitch_memory_offset {
        T *data;
        __device__ inline T &operator[](size_t pos) { return data[pos]; }
    };

    __device__ inline pitch_memory_offset operator[](size_t pos) { return {data + pitch * pos}; }
};

template <typename T> class pitch_memory {
  public:
    pitch_memory(size_t Ncols, size_t Nrows) {
        _vsize = Nrows;
        _hsize = Ncols;
        e = cudaMallocPitch((void **)&_data, &_pitch, Ncols * sizeof(T), Nrows);
    }
    ~pitch_memory() { e = cudaFree(_data); }
    inline operator pitch_memory_t<T>() { return {_data, _vsize, _hsize, _pitch / sizeof(T)}; }

  protected:
    cudaError_t e;

  private:
    T *_data;
    size_t _pitch;
    size_t _vsize;
    size_t _hsize;
};

__device__ mp_limb_t nmod_add_d(mp_limb_t a, mp_limb_t b, nmod_t mod) {
    const mp_limb_t neg = mod.n - a;
    if (neg > b)
        return a + b;
    else
        return b - neg;
}

__device__ void umul_ppmm_d(ulong &w1, ulong &w0, const ulong &u, const ulong &v) {
    do {
        ulong __x0, __x1, __x2, __x3;
        ulong __ul, __vl, __uh, __vh;
        __ul = __ll_lowpart(u);
        __uh = __ll_highpart(u);
        __vl = __ll_lowpart(v);
        __vh = __ll_highpart(v);
        __x0 = __ul * __vl;
        __x1 = __ul * __vh;
        __x2 = __uh * __vl;
        __x3 = __uh * __vh;
        __x1 += __ll_highpart(__x0); /* this can't give carry */
        __x1 += __x2;                /* but this indeed can */
        if (__x1 < __x2)
            __x3 += __ll_B;
        (w1) = __x3 + __ll_highpart(__x1);
        (w0) = (__x1 << (FLINT_BITS / 2)) + __ll_lowpart(__x0);
    } while (0);
}

__device__ void add_ssaaaa_d(ulong &s1, ulong &s0, const ulong &a1, const ulong &a0, const ulong &b1, const ulong &b0) {
    do {
        ulong __t0 = (a0);
        (s0) = (a0) + (b0);
        (s1) = (a1) + (b1) + ((ulong)(s0) < __t0);
    } while (0);
}

__device__ mp_limb_t nmod_mul_d(mp_limb_t a, mp_limb_t b, nmod_t mod) {
    b <<= mod.norm;
    mp_limb_t res;
    do {
        mp_limb_t q0xx, q1xx, rxx, p_hixx, p_loxx;
        mp_limb_t nxx, ninvxx;
        unsigned int normxx;
        ninvxx = (mod).ninv;
        normxx = (mod).norm;
        nxx = (mod).n << normxx;
        umul_ppmm_d(p_hixx, p_loxx, (a), (b));
        umul_ppmm_d(q1xx, q0xx, ninvxx, p_hixx);
        add_ssaaaa_d(q1xx, q0xx, q1xx, q0xx, p_hixx, p_loxx);
        rxx = (p_loxx - (q1xx + 1) * nxx);
        if (rxx > q0xx)
            rxx += nxx;
        rxx = (rxx < nxx ? rxx : rxx - nxx) >> normxx;
        (res) = rxx;
    } while (0);
    return res;
}

__device__ void NMOD_RED2_d(mp_limb_t &r, mp_limb_t &a_hi, mp_limb_t &a_lo, nmod_t &mod) {
    do {
        mp_limb_t q0xx, q1xx, r1xx;
        const mp_limb_t u1xx = ((a_hi) << (mod).norm) + r_shift((a_lo), FLINT_BITS - (mod).norm);
        const mp_limb_t u0xx = ((a_lo) << (mod).norm);
        const mp_limb_t nxx = ((mod).n << (mod).norm);
        umul_ppmm_d(q1xx, q0xx, (mod).ninv, u1xx);
        add_ssaaaa_d(q1xx, q0xx, q1xx, q0xx, u1xx, u0xx);
        r1xx = (u0xx - (q1xx + 1) * nxx);
        if (r1xx > q0xx)
            r1xx += nxx;
        if (r1xx < nxx)
            r = (r1xx >> (mod).norm);
        else
            r = ((r1xx - nxx) >> (mod).norm);
    } while (0);
}

__device__ void NMOD_RED3_d(mp_limb_t &r, mp_limb_t &a_hi, mp_limb_t &a_me, mp_limb_t &a_lo, nmod_t &mod) {
    do {
        mp_limb_t v_hi;
        NMOD_RED2_d(v_hi, a_hi, a_me, mod);
        NMOD_RED2_d(r, v_hi, a_lo, mod);
    } while (0);
}

__device__ ulong n_gcdinv_d(ulong *s, ulong x, ulong y) {
    slong v1, v2, t2;
    ulong d, r, quot, rem;

    FLINT_ASSERT(y > x);

    v1 = 0;
    v2 = 1;
    r = x;
    x = y;

    /* y and x both have top bit set */
    if ((slong)(x & r) < 0) {
        d = x - r;
        t2 = v2;
        x = r;
        v2 = v1 - v2;
        v1 = t2;
        r = d;
    }

    /* second value has second msb set */
    while ((slong)(r << 1) < 0) {
        d = x - r;
        if (d < r) /* quot = 1 */
        {
            t2 = v2;
            x = r;
            v2 = v1 - v2;
            v1 = t2;
            r = d;
        } else if (d < (r << 1)) /* quot = 2 */
        {
            x = r;
            t2 = v2;
            v2 = v1 - (v2 << 1);
            v1 = t2;
            r = d - x;
        } else /* quot = 3 */
        {
            x = r;
            t2 = v2;
            v2 = v1 - 3 * v2;
            v1 = t2;
            r = d - (x << 1);
        }
    }

    while (r) {
        /* overflow not possible due to top 2 bits of r not being set */
        if (x < (r << 2)) /* if quot < 4 */
        {
            d = x - r;
            if (d < r) /* quot = 1 */
            {
                t2 = v2;
                x = r;
                v2 = v1 - v2;
                v1 = t2;
                r = d;
            } else if (d < (r << 1)) /* quot = 2 */
            {
                x = r;
                t2 = v2;
                v2 = v1 - (v2 << 1);
                v1 = t2;
                r = d - x;
            } else /* quot = 3 */
            {
                x = r;
                t2 = v2;
                v2 = v1 - 3 * v2;
                v1 = t2;
                r = d - (x << 1);
            }
        } else {
            quot = x / r;
            rem = x - r * quot;
            x = r;
            t2 = v2;
            v2 = v1 - quot * v2;
            v1 = t2;
            r = rem;
        }
    }

    if (v1 < WORD(0))
        v1 += y;

    (*s) = v1;

    return x;
}

__device__ ulong nmod_pow_d(ulong source, ulong pow, nmod_t mod) {
    ulong ret{1};
    ulong n{pow};
    while (n) {
        if (n & 1) {
            ret = nmod_mul_d(source, ret, mod);
        }
        source = nmod_mul_d(source, source, mod);
        n >>= 1;
    }
    return ret;
}

__device__ ulong n_invmod_d(ulong x, ulong y) {
    ulong r, g;

    g = n_gcdinv_d(&r, x, y);
    if (g != 1)
        printf("Cannot invert modulo %lu*%lu\n", g, y / g);

    return r;
}

__device__ mp_limb_t nmod_inv_d(mp_limb_t a, nmod_t mod) {
    return n_invmod_d(a, mod.n);
}

__global__ void resultsDevice(ulong *results, ulong *base, ulong *mainPol, ulong *values, size_t skel_length,
                              size_t newton_values_size, nmod_t flint_mod, size_t pitch, size_t blsize) {
    unsigned int id = threadIdx.x + blockIdx.x * blockDim.x;

    ulong term, prod;
    ulong tempAccumLow[2 * 1024]; // 2 to store low and mid
    extern __shared__ unsigned tempAccumHigh[];

    for (size_t i = id, n = blockDim.x * gridDim.x; i < skel_length; i += n) {
        for (size_t k = 0; k < newton_values_size; k++) {
            tempAccumLow[2 * k] = 0ul;
            tempAccumLow[2 * k + 1] = 0ul;
            tempAccumHigh[blsize * k + threadIdx.x] = 0;
        }
        term = 0ul;
        prod = 0ul;
        for (size_t j = skel_length; j != 0; --j) {
            term = nmod_mul_d(term, base[i], flint_mod);
            term = nmod_add_d(term, mainPol[j], flint_mod);
            for (size_t k = 0; k != newton_values_size; k++) {
                ulong p1, p0;
                umul_ppmm_d(p1, p0, (term), (values[(skel_length - j) * pitch + k]));
                add_ssaaaa_d(tempAccumLow[2 * k + 1], tempAccumLow[2 * k], tempAccumLow[2 * k + 1], tempAccumLow[2 * k],
                             p1, p0);
                if (p1 > tempAccumLow[2 * k + 1])
                    tempAccumHigh[blsize * k + threadIdx.x]++;
            }
            prod = nmod_mul_d(prod, base[i], flint_mod);
            prod = nmod_add_d(prod, term, flint_mod);
        }

        prod = nmod_mul_d(prod, base[i], flint_mod);
        prod = n_invmod_d(prod, flint_mod.n);

        for (size_t k = 0; k < newton_values_size; k++) {
            ulong res;
            ulong temp = tempAccumHigh[blsize * k + threadIdx.x];
            NMOD_RED3_d(res, temp, tempAccumLow[2 * k + 1], tempAccumLow[2 * k], flint_mod);
            results[k * skel_length + i] = nmod_mul_d(prod, res, flint_mod);
        }
    }
}

__global__ void updateTerm(memory_t<ulong> check_pol_term, pitch_memory_t<ulong> check_pol_term_prev_2d,
                           memory_t<ulong> check_pol_term_prev, nmod_t flint_mod) {
    size_t len = check_pol_term.size;
    unsigned id = threadIdx.x + blockIdx.x * blockDim.x;

    for (size_t i = id, n = blockDim.x * gridDim.x; i < len; i += n) {
        check_pol_term_prev_2d[0][i] = check_pol_term_prev[i];
    }

    for (size_t i = 1; i < check_pol_term_prev_2d._vsize; ++i) {
        for (size_t ii = id, n = blockDim.x * gridDim.x; ii < len; ii += n) {
            check_pol_term_prev_2d[i][ii] =
                nmod_mul_d(check_pol_term_prev_2d[i - 1][ii], check_pol_term[ii], flint_mod);
        }
    }
    for (size_t i = id, n = blockDim.x * gridDim.x; i < len; i += n) {
        check_pol_term[i] = nmod_pow_d(check_pol_term[i], check_pol_term_prev_2d._vsize, flint_mod);
    }
}

__inline__ __device__ mp_limb_t warpReduceSum(ulong val, nmod_t flint_mod) {
    for (int shift = warpSize / 2; shift > 0; shift /= 2) {
        val = nmod_add_d(val, __shfl_down_sync(warpSize - 1, val, shift), flint_mod);
    }
    return val;
}

__global__ void SetCoeff(memory_t<ulong> val, memory_t<ulong> check_pol_term, pitch_memory_t<ulong> check_pol_term_prev,
                         nmod_t flint_mod, size_t blockSizePrepare) {
    size_t len = check_pol_term.size;
    extern __shared__ mp_limb_t coeffLow[];
    mp_limb_t *coeffHigh = coeffLow + blockSizePrepare;

    for (size_t i = blockIdx.x; i < len; i += gridDim.x) {
        coeffLow[threadIdx.x] = 0;
        coeffHigh[threadIdx.x] = 0;
        if (i < len) {
            for (size_t ii = threadIdx.x; ii < len; ii += blockDim.x) {
                coeffLow[threadIdx.x] += check_pol_term_prev[blockIdx.x][ii];
                if (coeffLow[threadIdx.x] < check_pol_term_prev[blockIdx.x][ii])
                    ++coeffHigh[threadIdx.x];
                check_pol_term_prev[blockIdx.x][ii] =
                    nmod_mul_d(check_pol_term_prev[blockIdx.x][ii], check_pol_term[ii], flint_mod);
            }
            NMOD_RED2_d(coeffLow[threadIdx.x], coeffHigh[threadIdx.x], coeffLow[threadIdx.x], flint_mod);
            __syncthreads();
            if (threadIdx.x < warpSize) {
                mp_limb_t summ = coeffLow[threadIdx.x];
                for (int k = threadIdx.x + warpSize; k < blockSizePrepare; k += warpSize) {
                    summ = nmod_add_d(summ, coeffLow[k], flint_mod);
                }
                summ = warpReduceSum(summ, flint_mod);
                if (threadIdx.x == 0) {
                    val[len - i - 1] = summ;
                }
            }
            __syncthreads();
        }
    }
}

namespace gpu {

void zippel_multiple_prime(size_t skel_length, const std::vector<mp_limb_t> &values, const mp_limb_t *main_pol_coeffs,
                         const std::vector<mp_limb_t> &base, nmod_mpoly_struct *results, nmod_t flint_mod) {
    // init device
    cudaError_t e;
    size_t newton_values_size = values.size() / skel_length;

    size_t blsize = 32;

    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    size_t BlocksPerGrid = 8 * prop.multiProcessorCount;
    dim3 ThreadsPerBlock = blsize;

    CHECK(cudaSetDevice(0));
    ulong *cudaResults, *cudaBase, *cudaMainPoly, *cudaValues;

    size_t pitch;
    CHECK(cudaMallocPitch((void **)&cudaValues, &pitch, newton_values_size * sizeof(ulong), skel_length));
    CHECK(cudaMalloc((void **)&cudaResults, skel_length * newton_values_size * sizeof(ulong)));
    CHECK(cudaMalloc((void **)&cudaBase, skel_length * sizeof(ulong)));
    CHECK(cudaMalloc((void **)&cudaMainPoly, (skel_length + 1) * sizeof(ulong)));
    CHECK(cudaMemcpy2D(cudaValues, pitch, values.data(), newton_values_size * sizeof(ulong),
                       newton_values_size * sizeof(ulong), skel_length, cudaMemcpyHostToDevice));
    pitch /= sizeof(ulong);

    // copy base and main_pol to device
    CHECK(cudaMemcpy(cudaMainPoly, main_pol_coeffs, (skel_length + 1) * sizeof(ulong), cudaMemcpyHostToDevice));
    CHECK(cudaMemcpy(cudaBase, base.data(), skel_length * sizeof(ulong), cudaMemcpyHostToDevice));

    // start GPU
    CHECK(cudaDeviceSynchronize());
    unsigned align_size = 16;
    unsigned vsize = align_size * ((newton_values_size + align_size - 1) / align_size);
    resultsDevice<<<BlocksPerGrid, ThreadsPerBlock, blsize * vsize * sizeof(unsigned)>>>(
        cudaResults, cudaBase, cudaMainPoly, cudaValues, skel_length, newton_values_size, flint_mod, pitch, blsize);
    CHECK(cudaDeviceSynchronize());
    // copy results to host
    for (size_t i = 0; i != newton_values_size; ++i) {
        auto pt = results + i;
        CHECK(
            cudaMemcpy(pt->coeffs, cudaResults + skel_length * i, skel_length * sizeof(ulong), cudaMemcpyDeviceToHost));
    }
    // free device memory
    CHECK(cudaFree(cudaResults));
    CHECK(cudaFree(cudaBase));
    CHECK(cudaFree(cudaMainPoly));
    CHECK(cudaFree(cudaValues));
}

std::vector<mp_limb_t> prepare_coeffs(mp_limb_t *check_pol_term, mp_limb_t *check_pol_num_prev, size_t check_pol_len,
                                     size_t valuesSize, nmod_t flint_mod) {
    size_t blockSizePrepare = 32 * 2;

    // we will need memory skel_length * blocksPerGridPrepare for prepared 2d
    // array

    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    size_t blocksPerGridPrepare = 4 * prop.multiProcessorCount;

    cudaError_t e;
    dim3 BlocksPerGrid = blocksPerGridPrepare, ThreadsPerBlock = blockSizePrepare;

    std::vector<mp_limb_t> result;

    pitch_memory<ulong> deviceTermPrev2D(check_pol_len, BlocksPerGrid.x);
    memory<ulong> deviceResult(result.data(), check_pol_len), deviceTermPrev(check_pol_num_prev, check_pol_len),
        deviceTerm(check_pol_term, check_pol_len);

    updateTerm<<<BlocksPerGrid, ThreadsPerBlock>>>(deviceTerm, deviceTermPrev2D, deviceTermPrev, flint_mod);
    CHECK(cudaDeviceSynchronize());

    SetCoeff<<<BlocksPerGrid, ThreadsPerBlock, blockSizePrepare * 2 * sizeof(mp_limb_t)>>>(
        deviceResult, deviceTerm, deviceTermPrev2D, flint_mod, blockSizePrepare);
    CHECK(cudaDeviceSynchronize());

    result = deviceResult;
    return result;
}

// Returns the number of CUDA cores depending on the architecture
int getSPcores(cudaDeviceProp devProp) {
    int cores = 0;
    int mp = devProp.multiProcessorCount;
    switch (devProp.major) {
    case 2: // Fermi
        if (devProp.minor == 1)
            cores = mp * 48;
        else
            cores = mp * 32;
        break;
    case 3: // Kepler
        cores = mp * 192;
        break;
    case 5: // Maxwell
        cores = mp * 128;
        break;
    case 6: // Pascal
        if ((devProp.minor == 1) || (devProp.minor == 2))
            cores = mp * 128;
        else if (devProp.minor == 0)
            cores = mp * 64;
        else
            printf("Unknown device type\n");
        break;
    case 7: // Volta and Turing
        if ((devProp.minor == 0) || (devProp.minor == 5))
            cores = mp * 64;
        else
            printf("Unknown device type\n");
        break;
    case 8: // Ampere
        if (devProp.minor == 0)
            cores = mp * 64;
        else if (devProp.minor == 6)
            cores = mp * 128;
        else
            printf("Unknown device type\n");
        break;
    default:
        printf("Unknown device type\n");
        break;
    }
    return cores;
}

void getGPUData() {
    int i, nDevices;

    cudaDeviceProp prop;

    cudaGetDeviceCount(&nDevices);

    printf("\nGPUs: %d\n\n", nDevices);

    for (i = 0; i < nDevices; i++) {
        cudaGetDeviceProperties(&prop, i);

        printf("Device Number: %d\n", i);
        printf("  Device name:                  %s\n", prop.name);
        printf("  Number of multiprocessors:    %d\n", prop.multiProcessorCount);
        printf("  Number of CUDA cores:         %d\n", getSPcores(prop));
        printf("  Total global memory (Mb):     %g\n", prop.totalGlobalMem / 1024.0 / 1024.0);
        printf("  Total constant memory (Kb):   %g\n", prop.totalConstMem / 1024.0);
        printf("  Shared memory per block (Kb): %g\n", prop.sharedMemPerBlock / 1024.0);
        printf("  32-bit registers per block:   %d\n", prop.regsPerBlock);
        printf("  Warp size in threads:         %d\n", prop.warpSize);
        printf("  Memory Clock Rate (MHz):      %g\n", prop.memoryClockRate / 1000.0);
        printf("  Memory Bus Width (bits):      %d\n", prop.memoryBusWidth);
        printf("  Peak Memory Bandwidth (Gb/s): %g\n\n",
               2.0 * prop.memoryClockRate * (prop.memoryBusWidth / 8) / 1024.0 / 1024.0);
    }
}

} // namespace gpu

#endif
