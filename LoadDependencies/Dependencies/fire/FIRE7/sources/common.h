/** @file common.h
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package.
 *
 *  It contains multiple definitions of static variables, gathered in class
 * common.
 */

#ifndef COMMON_H_INCLUDED
#define COMMON_H_INCLUDED

#include <algorithm>
#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <fcntl.h>
#include <fstream>
#include <iostream>
#include <kccachedb.h>
#include <kcdb.h>
#include <kchashdb.h>
#include <list>
#include <lz4.h>
#include <lz4hc.h>
#include <map>
#include <mutex>
#include <omp.h>
#include <set>
#include <string>
#include <thread>
#include <unistd.h>
#include <vector>

#include "tools/tools.h"

#ifdef PRIME
#include "../extra/fuel/usr/include/flint/nmod.h"
#endif

/** Used for storing indices of integrals */
using t_index = signed char;

constexpr unsigned int NEEDED_BIT = 1u << 31;
///< The bit of the Equation size in database used to store that expression is
///< needed in a higher sector

#ifndef SMALL_POINT
#ifdef LARGE_POINT
constexpr size_t MAX_IND = {28};
using sector_count_t = uint32_t; // note that the last bit is still for sign in some places
constexpr sector_count_t MAX_SECTORS  = {1<<MANY_SECTORS};
#else
#ifdef MANY_SECTORS
constexpr size_t MAX_IND = {20};
using sector_count_t = uint32_t;
constexpr sector_count_t MAX_SECTORS  = {1<<MANY_SECTORS};
#else
constexpr size_t MAX_IND = {22}; ///< the number of indices we can work with, can be different with some settings
using sector_count_t = uint16_t; ///< the sector count type to hold non-zero sector numbers
constexpr sector_count_t MAX_SECTORS  = {1<<15};
#endif
#endif
///< Typedef for variables that involve the number of sectors.
///< point::ww and database functions have compile-time constants defined
///< based on the size of the type
#else
constexpr size_t MAX_IND = {18};
constexpr size_t BITS_PER_INDEX = {6};
using sector_count_t = uint16_t;
constexpr sector_count_t MAX_SECTORS  = {1<<15};
#endif
/**< @brief
 * 22 indices should be enough for most problems;
 * 5-loop propagator = 20;
 * 6-loop bubble = 21;
 */

constexpr size_t MAX_THREADS = {64};
///< Maximal number of threads, 64 is just a number
constexpr size_t MAX_SOCKET_THREADS = {64};
///< Maximal number of socket threads (child communication), 64 is just a number

///< It is possible to increase the allowed MAX_SECTORS by changing
///< the associated sector_count_t to uint32_t.  However, because
///< there are a number of statically-allocated data structures
///< sized by MAX_SECTORS, there are potential linker/assembler problems
///< when using values larger than ~2^21.  Any possible need to use
///< values greater than 2^31 will also require some type promotions
///< in the signatures of functions::run/watch_child (which take negative
///< sector numbers during back substitution), and for a few variables
///< in functions::Evaluate

/**
 * @param ii a uint32_t
 * @return the number of decimal digits in the number
 * Compile-time computation of the number of decimal digits of a uint32.
 * Used for a compile-time computation of the needed length for sector
 * name strings
 */
constexpr size_t power_of_ten(const uint32_t ii) {
    size_t digits = 0;
    uint32_t curr = ii;
    while(curr >= 10){
        curr /= 10;
        digits++;
    }
    return digits + 1;
}  

/**
 * Compile-time computed length for the sector name strings
 */
constexpr size_t SECTOR_NAME_LEN = power_of_ten(MAX_SECTORS);

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpedantic"
/**
 * 128-but signed int with a standard name
 */
using int128_t = __int128;

/**
 * 128-but unsigned int with a standard name
 */
using uint128_t = unsigned __int128;
#pragma GCC diagnostic pop

/** SECTOR type uses a bit for each coordinate, 1 being positing, 0 - negative.
 *   Virtual sectors also have a preceding 1 bit, corresponding to sector 1 and
 * used for right-hand sides of rules
 */
using SECTOR = uint32_t;

using namespace std;

/**
 * For litered rules in same sector
 */
using common_lbases_t = map<unsigned short,
               vector<pair<vector<pair<vector<t_index>, pair<short, bool>>>,
                           vector<pair<std::vector<std::string>, vector<pair<vector<t_index>, short>>>>>>>;

/**
 * Type of compressor used in database.
 */
enum class t_compressor {
    C_NONE = 0, ///< no compressor
    C_SNAPPY = 1, ///< snappy compressor
    C_ZLIB = 2, ///< zlib compressor
    C_LZ4FAST = 3, ///< lz4 compressor, fast version
    C_LZ4 = 4, ///< lz4 compressor, default mode
    C_LZ4HC = 5, ///< lz4 compressor, high compression
    C_ZSTD = 6 ///< zstd compressor
};

/**
 * Type of evaluation stages.
 */
enum class t_stages {
    all, ///< both forward and backward
    forward, ///< only forward reduction pass
    backward ///< only backward pass (substitutions)
};

/**
 * Type of used points for seeding and solving
 */
enum class t_points {
    all, ///< all points used for reduction (default)
    even, ///< even points used
    odd ///< odd points used
};

#ifdef WITH_SNAPPY

#include <snappy.h>

/**
 * @brief Snappy Compressor extension for the kyotocabinet.
 */
class SnappyCompressor : public kyotocabinet::Compressor {
  private:
    char *compress(const void *buf, size_t size, size_t *sp) {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        *sp = snappy::MaxCompressedLength(size);
        char *out = new char[*sp + 1];
        snappy::RawCompress(static_cast<const char *>(buf), size, out, sp);
        out[*sp] = '\0';
        return out;
    }

    char *decompress(const void *buf, size_t size, size_t *sp) {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        if (!snappy::GetUncompressedLength(static_cast<const char *>(buf), size, sp)) {
            return nullptr;
        }
        char *out = new char[*sp + 1];
        if (!snappy::RawUncompress(static_cast<const char *>(buf), size, out)) {
            delete[] out;
            return nullptr;
        }
        out[*sp] = '\0';
        return out;
    }
};
#endif

/**
 * @brief LZ4 Fast Compressor extension for the kyotocabinet.
 */
class LZ4FastCompressor : public kyotocabinet::Compressor {
  private:
    char *compress(const void *buf, size_t size, size_t *sp) override {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        *sp = LZ4_COMPRESSBOUND(size);
        char *out = new char[*sp + 2];
        int written_bytes = LZ4_compress_fast(static_cast<const char *>(buf), out + 1, size, *sp, 5);
        if (written_bytes == 0) {
            delete[] out;
            fprintf(stderr, "Can't compress\n");
            return nullptr;
        }
        *sp = static_cast<size_t>(written_bytes);
        auto ratio = static_cast<unsigned char>(static_cast<unsigned int>(size) / static_cast<unsigned int>(*sp));
        ++ratio;
        ++(*sp);
        out[0] = ratio;
        out[*sp + 1] = '\0';
        return out;
    }

    char *decompress(const void *buf, size_t size, size_t *sp) override {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        auto lim = static_cast<unsigned int>(size * static_cast<const unsigned char *>(buf)[0]);
        char *out = new char[lim];
        int decompressed_bytes = LZ4_decompress_safe(static_cast<const char *>(buf) + 1, out, size - 1, lim);
        if (decompressed_bytes < 0) {
            delete[] out;
            fprintf(stderr, "Can't decompress\n");
            return nullptr;
        }
        *sp = static_cast<size_t>(decompressed_bytes);
        out[*sp] = '\0';
        return out;
    }
};

/**
 * @brief LZ4 Compressor extension for the kyotocabinet.
 */
class LZ4Compressor : public kyotocabinet::Compressor {
  private:
    char *compress(const void *buf, size_t size, size_t *sp) override {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        *sp = LZ4_COMPRESSBOUND(size);
        char *out = new char[*sp + 2];
        int written_bytes = LZ4_compress_default(static_cast<const char *>(buf), out + 1, size, *sp);
        if (written_bytes == 0) {
            delete[] out;
            fprintf(stderr, "Can't compress\n");
            return nullptr;
        }
        *sp = static_cast<size_t>(written_bytes);
        auto ratio = static_cast<unsigned char>(static_cast<unsigned int>(size) / static_cast<unsigned int>(*sp));
        ++ratio;
        ++(*sp);
        out[0] = ratio;
        out[*sp + 1] = '\0';
        return out;
    }

    char *decompress(const void *buf, size_t size, size_t *sp) override {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        auto lim = static_cast<unsigned int>(size * static_cast<const unsigned char *>(buf)[0]);
        char *out = new char[lim];
        int decompressed_bytes = LZ4_decompress_safe(static_cast<const char *>(buf) + 1, out, size - 1, lim);
        if (decompressed_bytes < 0) {
            delete[] out;
            fprintf(stderr, "Can't decompress\n");
            return nullptr;
        }
        *sp = static_cast<size_t>(decompressed_bytes);
        out[*sp] = '\0';
        return out;
    }
};

/**
 * @brief LZ4HC Compressor extension for the kyotocabinet.
 */
class LZ4HCCompressor : public kyotocabinet::Compressor {
  private:
    char *compress(const void *buf, size_t size, size_t *sp) override {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        *sp = LZ4_COMPRESSBOUND(size);
        char *out = new char[*sp + 2];
        int written_bytes = LZ4_compress_HC(static_cast<const char *>(buf), out + 1, size, *sp, 9);
        if (written_bytes == 0) {
            delete[] out;
            fprintf(stderr, "Can't compress\n");
            return nullptr;
        }
        *sp = static_cast<size_t>(written_bytes);
        auto ratio = static_cast<unsigned char>(static_cast<unsigned int>(size) / static_cast<unsigned int>(*sp));
        ++ratio;
        ++(*sp);
        out[0] = ratio;
        out[*sp + 1] = '\0';
        return out;
    }

    char *decompress(const void *buf, size_t size, size_t *sp) override {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        auto lim = static_cast<unsigned int>(size * static_cast<const unsigned char *>(buf)[0]);
        char *out = new char[lim];
        int decompressed_bytes = LZ4_decompress_safe(static_cast<const char *>(buf) + 1, out, size - 1, lim);
        if (decompressed_bytes < 0) {
            delete[] out;
            fprintf(stderr, "Can't decompress\n");
            return nullptr;
        }
        *sp = static_cast<size_t>(decompressed_bytes);
        out[*sp] = '\0';
        return out;
    }
};

// declarations of functions
/**
 * Calculate number of positive indices in a sector.
 * @param v vector of indices
 * @return the number of positive indices
 */
int positive_index(vector<t_index> v);

/**
 * Calculate the sector corresponding the current integral.
 * @param v vector of indices
 * @return corresponding vector of 1 and -1
 */
vector<t_index> sector(const vector<t_index> &v);

/**
 * Calculate corner - the corner integral corresponding the current integral.
 * @param v vector of indices
 * @return corresponding vector of 1 and 0
 */
vector<t_index> corner(const vector<t_index> &v);

/**
 * Calculate degree. Degree is the shift from the corner integral.
 * @param v vector of indices
 * @return corresponding vector of degrees
 */
vector<t_index> degree(const vector<t_index> &v);

/**
 * Calculate level.
 * @param v vector of indices
 * @return complexity of a Point - the number of dots and the number of
 * irreducible denominators.
 */
pair<unsigned int, unsigned int> level(const vector<t_index> &v);

/**
 * Print vector of indices.
 * @param v vector of indices
 */
void print_vector(const vector<t_index> &v);

/**
 * Print indices stored in SECTOR variable.
 * @param sf compressed vector of indices.
 */
void print_sector_fast(const SECTOR &sf);

/**
 * Generate symmetry orbit of a point.
 * @param v Point for which we generate orbit
 * @param orbit orbit to be updated
 * @param sym symmetries which we use for generation
 */
void symmetry_orbit(const vector<t_index> &v, vector<vector<t_index>> &orbit, vector<vector<vector<t_index>>> &sym);

/**
 * Create an ordering for the sector. Called in the initialization stage.
 * @param mat preallocated one-dimensional array of size sector.length *
 * sector.length
 * @param sector sector where the ordering is created
 * @param local_ordering_string sets the ordering type, see help for
 * Common::ordering_string
 */
void make_ordering(uint32_t *mat, const vector<t_index> &sector, const string local_ordering_string);

/**
 * List all sectors to be considered during solution.
 * @param d dimension
 * @param positive maximal index that can be positive
 * @param positive_start minimal index that can be positive
 * @return vector of all sectors
 */
vector<vector<t_index>> all_sectors(unsigned int d, int positive, int positive_start);

/**
 * Self-made conversion from int to string with leading zeroes.
 * @param i number
 * @return resulting string
 */
string int2string(int i);

// fast versions
/**
 * Calculate the sector corresponding the current integral and store it in
 * compressed manner.
 * @param v vector of indices
 * @return compressed sector
 */
SECTOR sector_fast(const vector<t_index> &v);

/**
 * @brief Contains only static members used globally in FIRE.
 */
class Common {
  public:
#ifdef PRIME
    static nmod_t flint_mod;
#endif

    /**
     * A passed option for positive indices
     */
    inline static string positive_indices_option = "";

    /**
     * The exponents switch limit for Tables saving
     */
    inline static int folders_limit = 0;

    /**
     * A setting asking not to increase positive shift when seeding integrals
     */
    inline static bool no_positive_increase{};

    /**
     * Stores a string with integrals file specified from command line
     */
    inline static string inputSpecifiedArgument{};

    /**
     * Stores a path to the "plan" file to be saved after normal run and used by
     * external component
     */
    inline static string plan_file{};

    /**
     * Stores a user-specified path to the "warmup" file which caches information
     * about the linear system to speedup future runs.
     */
    inline static string warmup_file{};

    /**
     * Regenerating and overwriting the warmup file
     */
    inline static bool generate_warmup_file{};

    /**
     * Require pre-existing warmup file
     */
    inline static bool use_warmup_file{};

    /**
     * Stores a path to the "warmup" file which caches information about the
     * linear system to speedup future runs. It is equal to the string warmup_file
     * if the user has specified the latter through .config file or command-line
     * options, but otherwise, plan_file + ".warmup" will be stored
     */
    inline static string actual_warmup_file{};

    /**
     * File for recording reduction steps; only valid when running with a plan file
     */
    inline static string step_file{};

    /**
     * File for topological sorting of computation steps, generated by an external program that analyzes the
     * `step_file`; only valid when running with a plan file
     */
    inline static string topo_sorting_file{};

    /**
     * Stores the folder for other files
     */
    inline static string folder{};

    /**
     * Inverses the order of relations and rules in tables
     */
    inline static bool ids_first{};

    /**
     * Whether the preferred integrals lead to new seeds
     */
    inline static bool preferred_produce_seeds = false;

    /** Non-substituted variables */
    static std::vector<std::string> variables;

    /** Options to be passes to fuel */
    static std::vector<std::string> fuelOptions;

    /** Options to be passes to fuel in initial form */
    static std::string fuelOptionsString;
    /**
     * Path to the file to save sector depenencies
     */
    static string dep_file;
    /**
     * Setting that allows to tweak the choice of master integrals. See #pos_pref
     * in configuration file.
     */
    static int pos_pref;
    /**
     * Array of sector numbers, takes SECTOR as index.
     */
    static unique_ptr<sector_count_t[]> sector_numbers_fast;
    /**
     * Array of pointers to ordering matrices, NULL initially. Each matrix
     * contains 1 and 0 entries so it is one int32_t per row
     */
    static unique_ptr<unique_ptr<uint32_t[]>[]> orderings_fast;
    /**
     * Number of indices.
     */
    static unsigned short dimension;
    /**
     * Number of indices used for calculation of parity if points_used is not all.
     */
    static bool parity_used[MAX_IND];

    /**
     * A = total sum
     * P = sum of positive
     * N = sum of negative (module)
     * r = reverse (stands before l, a, p or n)
     * i - inverse lexicographic (stands before a, p or n)
     * l = Lee (following positive and negative mixed, special)
     * a = all from first to last (module)
     * p = positive from first to last
     * n = negative from first to last (module)
     *
     */
    static string ordering_string;

    /**
     * the ordering of indices, default is from 1 to dimension
     */
    static vector<t_index> index_ordering;

    /**
     * True if this is Ftool executable.
     */
    static bool ftool;

    /**
     * Whether we are working only forward, backward or both
     */
    static t_stages stages;

    /**
     * Whether we are using all points (default), odd or even
     */
    static t_points points_used;

    /**
     * If non-zero, all other sectors are set to zero
     */
    static sector_count_t single_sector;

    /**
     * In case forward run, the level after which FIRE should stop
     */
    static int target_level;

    /**
     * Passed from command line to override the bucket parameter for the current
     * sector
     */
    static int bucket_override;

    /**
     * Whether to clean temporary databases after work
     */
    static bool clean_databases;

    /**
     * True to disable IBP presolving without index substitution
     */
    static bool disable_presolve;
    /**
     * Use partial presolve like in version 6.4, without backward substitution
     */
    static bool old_presolve;
    /**
     * The number of ibps that are actively presolved. Used to separate normal
     * IBPs from LI identities. Has no sense in case disable_presolve = true
     */
    static unsigned int presolve_ibps;

    /**
     * Self-describing. To pass them to FLAME.
     */
    static bool variables_set_from_command_line;
    /**
     * Prefix added to Tables in PRIME mode.
     */
    static string tables_prefix;

    /**
     * Compressor choice for database entries.
     */
    static t_compressor compressor;
    /**
     * Compressor level for database entries.
     */
    static int compressor_level;
    /**
     * Compressor for database entries.
     */
    static unique_ptr<kyotocabinet::Compressor> compressor_class;
    /**
     * The number of a non-sector - the highest one that is used for all global
     * symmetry mappings.
     */
    static sector_count_t virtual_sector;

    /**
     * Option indicating whether we are using a one-pass approach (bottom to top)
     * for sectors
     */
    static bool one_pass;

    /**
     * Location of the database with information for the one-pass approcah (or
     * location where to save the result_
     */
    static string one_pass_database;

    /** @name Limits for levels and sectors.
     *  Maximal and minimal levels and sectors encountered.
     */
    /**@{*/
    /**
     * Positive index of lowest level.
     */
    static int abs_min_level;
    /**
     * Highest level.
     * abs_max_level cannot be higher than 15 - this is the maximum for the 6-loop
     * bubble
     */
    static int abs_max_level;
    /**
     * Maximal sector number. Minimal sector number is always 2 in our enumeration
     */
    static sector_count_t abs_max_sector;
    /**@}*/
    /**
     * Indication that only a part of masters will be used during reduction and
     * substitutions.
     */
    static bool split_masters;
    /**
     * Indication whether the list of nonzero sectors should stay unchanged
     * despite running in the split_master mode
     */
    static bool split_masters_no_dep;
    /**
     * Stores output path supplied by a command line argument --output, to
     * override the config file setting
     */
    static string output_override;
    /**
     * The minimal number of the master-integral that is not set to zero in
     * split_masters mode.
     */
    static unsigned int master_number_min;
    /**
     * The maximal number of the master-integral that is not set to zero in
     * split_masters mode.
     */
    static unsigned int master_number_max;
    /** @name Database wrapper members.*/
    /**@{*/
    /**
     * Mutex that controls access to wrapper tar file
     */
    static mutex wrapper_mutex;
    /**
     * Database for storing other databases
     */
    static kyotocabinet::HashDB wrapper_database;
    /**
     * Flag that corresponds to \#wrap in config.
     * True if \#wrap is used, false otherwise.
     */
    static bool wrap_databases;
    /**@}*/

    /**
     * Flag that corresponds to selection of \#masters option in config.
     * True if we used \#masters, False if \#output.
     */
    static bool only_masters;

    /**
     * If set to false, FIRE will print much more verbose information about work
     * being done. False by default.
     */
    static bool silent;

    /**
     * If set to true, evel more printing is suppressed
     */
    static bool very_silent;
    /**
     * Database handlers.
     */
    static kyotocabinet::CacheDB *points[MAX_SECTORS + 1];

    /** @name Database bucket settings and sizes.*/
    /**@{*/
    /**
     * Property of database, see kyotocabinet documentation for details.
     */
    static int buckets[MAX_SECTORS + 1];
    /**@}*/

    /** @name Pipes for expression communication.*/
    /**@{*/
    /**
     * File stream that child is writing to.
     */
    static FILE *child_stream_from_child;
    /**
     * File stream that child is reading from.
     */
    static FILE *child_stream_to_child;
    /**
     * Flag that tells binary that it should receive answers from child. In other
     * words, that it's a parent.
     */
    static bool receive_from_child;
    /**
     * Flag that tells binary that it should send answers to parent. In other
     * words, that it's a child working in no-separate fermat mode.
     */
    static bool send_to_parent;
    /**@}*/

    /**
     * True if FIRE was run in parallel mode.
     * That is a call from the MPI binary or simply by providing the -parallel
     * option. The result is separation of database paths and semapthore names.
     */
    static bool parallel_mode;

    /** @name Stored paths to folders and files.*/
    /**@{*/
    /**
     * Path FIRE folder with input and output.
     */
    static string FIRE_folder;

    /**
     * Path to configuration file.
     */
    static string config_file;

    /**
     * Path to databases.
     */
    static string path;

    /**
     * Path to the so-called storage, copies of databases (if we use them).
     */
    static string cpath;

    /**
     * Vector of completed levels found in storage, to skip. Read from file in storage dir.
     */
    static vector<pair<int,int>> completed_in_storage;
    /**
     * Name of file in storage dir to read or store completed level information.
     */
    static string completed_in_storage_fname;

    /**
     * Path to folder with hints.
     */
    static string hint_path;
    /**@}*/

    /** @name Variables for statistics.*/
    /**@{*/
    /**
     * Time spend for expression simplification
     */
    static atomic<long long> simplify_time;
    /**
     * Total time spent in thread.
     */
    static atomic<long long> thread_time;
    /**@}*/

    /**
     * This flag corresponds to usage of \#storage option in config.
     */
    static bool cpath_on_substitutions;

    /**
     * True if we use all IBPs. See \#allIBP in configuration file.
     */
    static bool all_ibps;

    /**
     * Inverse orderings in sectors (matrices)
     */
    static vector<vector<vector<t_index>>> iorderings;

    /**
     * Maps numbers to sectors (as vectors).
     */
    static vector<vector<t_index>> ssectors;

    /**
     * Global symmetries.
     */
    static vector<vector<vector<t_index>>> symmetries;

    /**
     * Set of sectors lower than others in their level.
     */
    static set<SECTOR> lsectors;

    /**
     * Lee bases.
     * Internal vector of strings is for possible multiple variable substitutions.
     * Only in MPRIME mode it contains more that one element
     */
    static common_lbases_t lbases;

    /**
     * For fast checks whether a sector has lbases
     */
    inline static std::vector<bool> has_lbases;

    /**
     * The diagram number in use.
     */
    static unsigned int global_pn;

    /** @name Various thread counts.*/
    /** By default threads_number == fthreads_number == sthreads_number*/
    /**@{*/
    /**
     * Current number of threads.
     */
    static unsigned int threads_number;

    /**
     * Number of threads per level. Used to fine-tune performance
     */
    static map<unsigned short, unsigned int> threads_level_number;

    /**
     * Default number of threads in use
     */
    static unsigned int threads_default_number;

    /**
     * Number of level workers inside a sector. Equals to 1 by default.
     */
    static unsigned int lthreads_number;

    /**
     * Number of threads working during substitution stage.
     * should be decreased in case of
     * terminate called after throwing an instance of 'std::runtime_error'
     * what():  pthread_key_create
     */
    static unsigned int sthreads_number;

    /**
     * Number of fermat processes.
     */
    static unsigned int fthreads_number;

    /**
     * Number of fermat separate queues. Equals to 1 by default, which means all
     * sectors use same fermat queue.
     */
    static unsigned int f_queues;
    /**@}*/

    /**
     * Number of iterations between printing information during reduce and
     * substitution. If equal to 0 we don't print anything.
     */
    static int print_step;
    /**
     * Prime number we use for modular arithmetic.
     */
    static uint64_t prime;
    /**
     * Index of prime number in primes array in primes.cpp.
     */
    static unsigned short prime_number;

    /**
     * Map of variable substitutions. For MPRIME mode there will be multiple on
     * rhs
     */
    static map<string, std::vector<std::string>> variable_replacements;
    /**
     * Non-substituted variables separated with |.
     */
    static string active_variables;
    /**
     * True if \#small is in configuration file.
     */
    static bool small;
    /**
     * True if variables passed from arguments can be big and thus external
     * library should be used for modular.
     */
    static bool large_variables;
    /**
     * True if we use hints. See \#hint in configuration file.
     */
    static bool hint;

    /**
     * Thread which we use to listen for incoming connections.
     */
    static std::thread socket_listen;

    /**
     * Only used in eqgen_external_solver.cpp. Indication that all integrals up to
     * a given complexity, if fully reduced to masters, will be printed out. This
     * is useful for e.g. generating IBP Tables used for searching for an improved
     * master basis.
     */
    static int print_all_up_to_complexity;

    /**
     * Only used in eqgen_external_solver.cpp. If true, only generate IBP /
     * symmetry equations for the bottom sector, e.g. for finding an improved
     * master basis for the bottom sector
     */
    static bool bottom_sector_only;
};

// some more function declarations
/**
 * Check existence of database by its number.
 * @param number sector number
 * @return true if exists on disk
 */
bool database_exists(sector_count_t number);

/**
 * Remove the database by its number.
 * @param number sector number
 */
void clear_database(sector_count_t number);

/**
 * Open a database (either on disk, or in RAM).
 * @param number sector number
 * @param read_snapshot indicates whether to read snapshot from disk or just
 * open
 */
void open_database(sector_count_t number, bool read_snapshot = true);

/**
 * Reopen database by number.
 * @param number sector number
 * @param changed indicates whether the database was changed and needs a
 * snapshot save
 */
void reopen_database(sector_count_t number, bool changed = true);

/**
 * Save a part of database entries to disk
 * @param dest destanation ofstream
 * @param db open cache database
 * @param condition a function determining whether to save an entry
 * @return the number of entries ignores and not saved to disk
 */

size_t dump_partial_snapshot(std::ostream *dest, kyotocabinet::CacheDB *db,
                             std::function<bool(const char *, size_t, const char *, size_t)> condition);

/**
 * Close database by number.
 * @param number sector number
 * @param changed indicates whether the database has been changed, and we need
 * to write a snapshot to disk
 * @param condition a function determining whether to save an entry
 * @param append_snapshot if true, the database contents is appended to the
 * snapshot, not overwritten
 * @return the number of entries ignored and not saved to disk
 */
size_t close_database(sector_count_t number, bool changed = true,
                      std::function<bool(const char *, size_t, const char *, size_t)> condition = {},
                      bool append_snapshot = false);

/**
 * Copy database by number to storage location (inverse is done for all file at
 * job start). This is needed to restart broken jobs.
 * @param sector_number the number of the sector database to be copied
 */
void store_database(sector_count_t sector_number);

/**
 * @brief Call database wrapper on specific numbers and write from database to
 * file or backwards.
 *
 * number = 0 and back = false is used to start the wrapper thread
 * number = 0 and back = true is used to stop the wrapper thread
 *
 * Use number of sector directly to write sector,
 * @param number sector number
 * @param back direction; true for adding file to storage
 * @param remove_file whether to remove the file from the storage after getting,
 * important only in case of back=false
 * @return successfullness of the operation
 */
bool database_to_file_or_back(sector_count_t number, bool back, bool remove_file = true);

/**
 * Read completed_in_storage file.
 */
void completed_in_storage_read(void);

/**
 * Update completed_in_storage file with current values.
 */
void completed_in_storage_update(void);

/**
 * Check whether a sector is in the list of sectors without Lee external
 * symmetries (lower).
 * @param sector_number sector number
 * @return check result
 */
bool in_lsectors(sector_count_t sector_number);

/**
 * Read from stream when communicating via pipe
 * @param buf buffer to write to, can be reallocated if size is not enough
 * @param buf_size location of the size to be written to, can be allocated
 * @param stream_from_child stream to read from
 */
void read_from_stream(char **buf, size_t *buf_size, FILE *stream_from_child);

#ifdef PRIME
/**
 * @brief Bring number stored in s to the mod range by Common::prime.
 * @param s input string containing a fraction. Both numerator and denominator
 * can contain brackets and the negative sign. The absolute values must fit into
 * uint64
 * @return resulting number in proper range
 */
unsigned long long string_fraction_to_modular(string &s);
#endif

/**
 * Substitute all variables from Common::variable_replacements in str, using
 * replace_all().
 * @param str input string
 * @param index the number of replacement in used (needed for MPRIME)
 * @return copy of updated string
 */
string replace_all_variables(string str, size_t index = 0);

/**
 * @brief Wrapper for coefficient in monoms.
 *
 * Is a number, if used in prime version of FIRE, string in normal version.
 */
class COEFF {
  public:
#if defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
#if defined(MPRIME) || defined(DOXYGEN_DOCUMENTATION)
    unsigned long long N[MPRIME]; ///< Exact values of coefficient modulo selected prime for
                                  ///< different variable values, used in MULTIPRIME mode.
#else
    unsigned long long n; ///< Exact value of coefficient modulo selected prime,
                          ///< used in PRIME mode.
#endif
#endif
#if !defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
    std::string s; ///< String representation of coefficient, used in normal mode.
#endif
    /** @fn operator<<(ostream &out, const COEFF &)
     * @brief Prints coeff to stream
     * @param out the stream
     * @param c the coeff to be printed
     * @return the stream
     */
    friend ostream &operator<<(ostream &out, const COEFF c) {
#ifdef PRIME
#ifdef MPRIME
        for (size_t j = 0; j != MPRIME; ++j) {
            out << c.N[j];
            if (j != MPRIME - 1) {
                out << "|";
            }
        }
#else
        out << c.n;
#endif
#else
        out << c.s;
#endif
        return out;
    }
    /**
     * Default zero constructor for coefficient
     */
    COEFF() {
#ifdef PRIME
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            N[i] = 0;
        }
#else
        n = 0;
#endif
#else
        s = "";
#endif
    }
#if defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
    /**
     * Constructor from a number in prime mode simply copying that number
     * @param number a number
     */
    COEFF(unsigned long long number) {
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            N[i] = number;
        }
#else
        n = number;
#endif
    }
#endif
#if !defined(PRIME) || defined(DOXYGEN_DOCUMENTATION)
    /**
     * Constructor from a string in poly mode simply copying that string
     * @param str a string
     */
    COEFF(const string &str) { s = str; }
    /**
     * Move constructor from a string in poly mode for faster emplacement with
     * moving
     * @param str a string
     */
    COEFF(string &&str) { s.swap(str); }
#endif

    /**
     * Check whether the coefficient is zero or non-set, universal for both
     * versions of FIRE
     * @return result of the check
     */
    bool Empty() const {
#ifdef PRIME
        COEFF zero(0);
        return (*this == zero);
#else
        return ((s == "") || (s == "0"));
#endif
    }

    /** @fn operator==(const COEFF &, const COEFF &)
     * @brief Checks whether two coefficients are equal
     * @param c1 first coefficient
     * @param c2 second coefficient
     * @return Check result
     */
    friend bool operator==(const COEFF &c1, const COEFF &c2) {
        COEFF result;
#ifdef PRIME
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            if (c1.N[i] != c2.N[i]) {
                return false;
            }
        }
        return true;
#else
        return (c1.n == c2.n);
#endif
#else
        return (c1.s == c2.s);
#endif
    }

    /** @fn operator+(const COEFF &, const COEFF &)
     * @brief Add two coefficients
     * @param c1 first coefficient
     * @param c2 second coefficient
     * @return Their sum
     */
    friend COEFF operator+(const COEFF &c1, const COEFF &c2) {
        COEFF result;
#ifdef PRIME
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            result.N[i] = nmod_add(c1.N[i], c2.N[i], Common::flint_mod);
        }
#else
        result.n = nmod_add(c1.n, c2.n, Common::flint_mod);
#endif
#else
        if (c1.s == "")
            result.s = c2.s;
        else if (c2.s == "")
            result.s = c1.s;
        else
            result.s = "(" + c1.s + ") + (" + c2.s + ")";
#endif
        return result;
    }

    /** @fn operator-(const COEFF &, const COEFF &)
     * @brief Substract two coefficients
     * @param c1 first coefficient
     * @param c2 second coefficient
     * @return Their difference
     */
    friend COEFF operator-(const COEFF &c1, const COEFF &c2) {
        COEFF result;
#ifdef PRIME
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            result.N[i] = nmod_sub(c1.N[i], c2.N[i], Common::flint_mod);
        }
#else
        result.n = nmod_sub(c1.n, c2.n, Common::flint_mod);
#endif
#else
        if ((c1.s == "") && (c2.s == ""))
            result.s = "";
        else if (c1.s == "")
            result.s = "- (" + c2.s + ")";
        else if (c2.s == "")
            result.s = c1.s;
        else
            result.s = "(" + c1.s + ") - (" + c2.s + ")";
#endif
        return result;
    }

    /** @fn operator-(const COEFF &)
     * @brief Negation
     * @param c coefficient
     * @return the negation result
     */
    friend COEFF operator-(const COEFF &c) {
        COEFF result;
#ifdef PRIME
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            result.N[i] = nmod_neg(c.N[i], Common::flint_mod);
        }
#else
        result.n = nmod_neg(c.n, Common::flint_mod);
#endif
#else
        if (c.s == "")
            result.s = "";
        else
            result.s = "-(" + c.s + ")";
#endif
        return result;
    }

    /** @fn operator*(const COEFF &, const COEFF &)
     * @brief Multiply two coefficients
     * @param c1 first coefficient
     * @param c2 second coefficient
     * @return Their product
     */
    friend COEFF operator*(const COEFF &c1, const COEFF &c2) {
        COEFF result;
#ifdef PRIME
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            result.N[i] = nmod_mul(c1.N[i], c2.N[i], Common::flint_mod);
        }
#else
        result.n = nmod_mul(c1.n, c2.n, Common::flint_mod);
#endif
#else
        if (c1.s == "")
            result.s = "";
        else if (c2.s == "")
            result.s = "";
        else
            result.s = "(" + c1.s + ") * (" + c2.s + ")";
#endif
        return result;
    }

    /** @fn operator/(const COEFF &, const COEFF &)
     * @brief Divide two coefficients
     * @param c1 first coefficient
     * @param c2 second coefficient
     * @return c1/c2
     */
    friend COEFF operator/(const COEFF &c1, const COEFF &c2) {
        COEFF result;
#ifdef PRIME
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            result.N[i] = nmod_div(c1.N[i], c2.N[i], Common::flint_mod);
        }
#else
        result.n = nmod_div(c1.n, c2.n, Common::flint_mod);
#endif
#else
        if (c1.s == "")
            result.s = "";
        else if (c2.s == "")
            result.s = "";
        else
            result.s = "(" + c1.s + ") / (" + c2.s + ")";
#endif
        return result;
    }

    /** @fn operator/(const unsigned long long &, const COEFF &)
     * @brief Divide number by coefficients
     * @param n1 first number
     * @param c2 second coefficient
     * @return c1/c2
     */
    friend COEFF operator/(const unsigned long long &n1, const COEFF &c2) {
        COEFF result;
#ifdef PRIME
        if (n1 != 1) {
            return COEFF(n1) * (1 / c2);
        }
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            result.N[i] = nmod_inv(c2.N[i], Common::flint_mod);
        }
#else
        result.n = nmod_inv(c2.n, Common::flint_mod);
#endif
#else
        if (c2.s == "")
            result.s = "";
        else
            result.s = "(" + std::to_string(n1) + ") / (" + c2.s + ")";
#endif
        return result;
    }
};

#ifdef WITH_ZSTD

#include <zstd.h>
/**
 * @brief ZStandard Compressor extension for the kyotocabinet.
 */
class ZstdCompressor : public kyotocabinet::Compressor {
  private:
    char *compress(const void *buf, size_t size, size_t *sp) {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        *sp = ZSTD_compressBound(size);
        char *out = new char[*sp + 1];
        if ((Common::lthreads_number == 1) && !omp_in_parallel()) {
            *sp = ZSTD_compressCCtx(ccontext, out, *sp, buf, size, Common::compressor_level);
        } else {
            *sp = ZSTD_compress(out, *sp, buf, size, Common::compressor_level);
        }
        out[*sp] = '\0';
        return out;
    }

    ZstdCompressor(const ZstdCompressor &) = delete;
    void operator=(ZstdCompressor const &x) = delete;

    char *decompress(const void *buf, size_t size, size_t *sp) {
        _assert_(buf && size <= MEMMAXSIZ && sp);
        if (!sp) {
            cout << "Nullptr passed to decompress" << endl;
            abort();
        }
        *sp = ZSTD_getFrameContentSize(buf, size);
        if (!*sp) {
            return nullptr;
        }
        char *out = new char[*sp + 1];
        if ((Common::lthreads_number == 1) && !omp_in_parallel()) {
            if (!ZSTD_decompressDCtx(dcontext, out, *sp, buf, size)) {
                delete[] out;
                return nullptr;
            }
        } else {
            if (!ZSTD_decompress(out, *sp, buf, size)) {
                delete[] out;
                return nullptr;
            }
        }
        out[*sp] = '\0';
        return out;
    }

  public:
    ZstdCompressor() {
        ccontext = ZSTD_createCCtx();
        dcontext = ZSTD_createDCtx();
    }
    ~ZstdCompressor() {
        ZSTD_freeCCtx(ccontext);
        ZSTD_freeDCtx(dcontext);
    }

  private:
    ZSTD_CCtx *ccontext;
    ZSTD_DCtx *dcontext;
};

#endif

/**
 * Smallest bucket value for the number of entries in a database
 * @param entries number of entries
 * @return the bucket
 */
int smallest_bucket(size_t entries);

/**
 * Scan the snapshot and apply a function to all entries.
 * @param number the database number
 * @param condition a check whether to read the value and apply the other
 * function
 * @param action function to be applied
 * @return number of entries in the snapshot and number of entries satisfying
 * the condition
 */
pair<size_t, size_t> scan_snapshot(sector_count_t number, std::function<bool(const char *, size_t)> condition,
                                   std::function<void(const char *, size_t, const char *, size_t)> action);

#endif // COMMON_H_INCLUDED
