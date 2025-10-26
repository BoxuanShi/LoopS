/** @file point.h
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  It contains the basic Point class corresponding to a Feynman integral
 */

#ifndef _points_h_
#define _points_h_

#include <functional>
#include <optional>

#include "common.h"

/** Used for enumerating virtual points (masked expressions) */
using virt_t = uint64_t;

#ifndef SMALL_POINT
// As per the comments in point, the byte at MAX_IND - 1 is 0 for virtual,
// and the previous bytes (virt_t is a uint64) are where the virtual number is stored
static const size_t LAST_INDEX_OFFSET = MAX_IND - 1; ///<< offset of the last index
#ifndef LARGE_POINT
static const size_t POINT_ALIGN = 8;  ///< Default size is 24, so align by 8
static const size_t POINT_SIZE = 24; ///< Basic size with 3*8
#else
static const size_t POINT_ALIGN = 32;  ///< Size is 32, we can align by 32 too
static const size_t POINT_SIZE = 32; ///< Large size with 4*8
#endif
#else
static const size_t POINT_SIZE = 16; ///< Small size with 2*8
static const size_t POINT_ALIGN = 16; ///< Small-point size is 16, let's align by 16 too
static const size_t LAST_INDEX_OFFSET = 13; ///< here we store 18 indices in 14 bytes
#endif

static const size_t VIRT_OFFSET = LAST_INDEX_OFFSET - sizeof(virt_t); ///< offset till the virual point number

#include <iomanip>

#ifndef DOXYGEN_DOCUMENTATION
class FastPoint;
#endif

/**
 * For internal Litered symmetried
 */
using ibases_t = map<unsigned short,
               vector< // because there can be multiple
                   pair<vector<t_index>, vector<pair<vector<pair<COEFF, FastPoint>>, t_index>>>>>;

/**
 * For external Litered symmetried
 */
using dbases_t = map<unsigned short, pair<vector<t_index>, vector<pair<vector<pair<COEFF, FastPoint>>, t_index>>>>;

/** Used for storing ibps without substituted indices */
using ibp_type = vector<pair<vector<COEFF>, FastPoint>>;

/**
 * @brief Ordered Point class.
 *
 * Contains point's degrees already multiplied by ordering matrix and calculated
 * sector number. There also are virtual points - there are not real integrals,
 * but some masking expressions of tails in lower sectors. Point is designed to
 * fit into the 24 = 3*8 byte size
 */
class Point {
  public:
    /** Globally known preferred points. */
    inline static vector<set<vector<t_index>>> preferred;
    /** Globally known preferred points set from input. */
    inline static vector<set<vector<t_index>>> preferred_initial;
    /** Globally known preferred fast-points. */
    inline static vector<set<FastPoint>> preferred_fast;
    /** Flag for Mathematical Point printing in FTool module. */
    static bool print_g;

    /**
     * Default constructor, fills with zeros.
     */
    Point();

    /**
     * Constructor from another point.
     * @param p another point

     */
    Point(const Point &p);

    /**
     * @brief Constructor from FastPoint.
     * Constructs only real points, no sector 1 or masking
     * @param pf the fast version of the point
     * @param ssector sector (not number) if we know it, -1 otherwise.
     */
    Point(const FastPoint &pf, SECTOR ssector = -1);

    /**
     * Constructor from Point and added shift FastPoint in case sector is not
     * changed. We must know and specify ssector.
     * @param p initial point
     * @param v shift to be added
     * @param ssector sector number
     * @param not_preferred whether the new Point is not preferred
     */
    Point(const Point &p, const FastPoint &v, SECTOR ssector, bool not_preferred);

    /** @fn operator=(const Point &) const
     * @brief Set one Point equal to another
     * @param p the copied point
     * @return The new point
     */
    Point &operator=(const Point &p);

    /**
     * Constructor from vector of indices in case sector is not changed.
     * @param v the vector of indices
     * @param virt the masking number, normal integral if zero
     * @param ssector sector number if we know it, -1 otherwise.
     */
    Point(const vector<t_index> &v, virt_t virt = 0, SECTOR ssector = -1);

    /** Constructor from safe buffer.
     *  @param buf the buffer filled by SafeString().
     * */
    Point(const char *buf);

    /** For normal points it stores the Point degrees already multiplied by the
     * ordering matrix. Bytes are stored in inverted manner, to speedup comparison.
     *
     *  If Point is virtual, then the ww[MAX_IND - 1] is equal to zero and virt_t suze bytes
     * before that are used to store virtual number point. Last sizeof(sector_count_t) bytes are the so
     * called H1Value.
     */
    char ww[POINT_SIZE];

    /**
     * top bits are for the sector number.
     * 1 bit for the "shift" value at the moment of Point initializations, hence
     * some points are lower (virtual among them). Virtual points are not real
     * integrals, but some masking expressions of tails in lower sectors.
     * @return last bytes as sector_count_t
     */

    sector_count_t H1Value() const { return *reinterpret_cast<const sector_count_t *>(ww + LAST_INDEX_OFFSET + 1); };

    /**
     * @return pointer to the last bytes, referred to as H1Value (see H1Value() description)
     */
    sector_count_t *H1Pointer() { return reinterpret_cast<sector_count_t *>(ww + LAST_INDEX_OFFSET + 1); };

    /**
     * Create a string that is written in tables
     * @return a string to be written in tables
     */
    string Number() const;

    /**
     * Checks if the vector corresponds to a preferred point
     * if there are preferred points in a sector, they are checked, otherwise the
     * pos_pref setting
     * @param v vector of indices
     * @param sn the sector number
     * @return whether the Point should be preferred
     */
    static bool IsPreferred(const vector<t_index> &v, sector_count_t sn);

    /**
     * Retrieve the sector number from H1Value.
     * @return sector number of the point.
     */
    sector_count_t SectorNumber() const { return (H1Value() >> 1); }

    /**
     * Check if the Point is virtual.
     * @return true if Point is virtual, false otherwise.
     */
    bool IsVirtual() const { return (ww[LAST_INDEX_OFFSET] == 0); }

    /**
     * Get the level of Point - number of non-negative indices
     * @return level of point.
     */
    int Level() const;

    /**
     * Fill buffer with information about without any special symbols that can't
     * be piped.
     * @param buf pointer allocated with sizeof(Point)*2 bytes.
     */
    void SafeString(char *buf) const;

    /**
     * Get the real Point indices, using inverse ordering.
     * @return vector of real Point indices.
     */
    vector<t_index> GetVector() const;

    /**
     * Check if Point data is filled with zeroes.
     * Point data can be filled with zeroes only as an exception, for example
     * if we where searching for a Point and found none.
     * @return true if Point data is filled with zeroes, false otherwise.
     */
    bool IsZero() const;

    /** @fn operator==(const Point &, const Point &) const
     * @brief Compare two points
     * @param p1 first point
     * @param p2 second point
     * @return True if they are equal
     */
    friend bool operator==(const Point &p1, const Point &p2) {
#ifndef SMALL_POINT
#ifdef LARGE_POINT
        if (reinterpret_cast<const uint128_t *>(p1.ww)[1] ^ reinterpret_cast<const uint128_t *>(p2.ww)[1])
            return false;
        if (reinterpret_cast<const uint128_t *>(p1.ww)[0] ^ reinterpret_cast<const uint128_t *>(p2.ww)[0])
            return false;
        return true;
#else
        if (reinterpret_cast<const uint64_t *>(p1.ww)[2] ^ reinterpret_cast<const uint64_t *>(p2.ww)[2])
            return false;
        if (reinterpret_cast<const uint64_t *>(p1.ww)[1] ^ reinterpret_cast<const uint64_t *>(p2.ww)[1])
            return false;
        if (reinterpret_cast<const uint64_t *>(p1.ww)[0] ^ reinterpret_cast<const uint64_t *>(p2.ww)[0])
            return false;
        return true;
#endif
#else
        return !(reinterpret_cast<const uint128_t *>(p1.ww)[0] ^ reinterpret_cast<const uint128_t *>(p2.ww)[0]);
#endif
    }

    /** @fn operator!=(const Point &, const Point &) const
     * @brief Compare two points
     * @param p1 first point
     * @param p2 second point
     * @return True if they are not equal
     */
    friend bool operator!=(const Point &p1, const Point &p2) {
#ifndef SMALL_POINT
        return (!(p1 == p2));
#else
        return reinterpret_cast<const uint128_t *>(p1.ww)[0] ^ reinterpret_cast<const uint128_t *>(p2.ww)[0];
#endif
    }

    /** @fn operator<=(const Point &, const Point &) const
     * @brief Compare two points
     * @param p1 first point
     * @param p2 second point
     * @return True if they are equal or first is less
     */
    friend bool operator<=(const Point &p1, const Point &p2) {
#ifndef SMALL_POINT
        return (p1 == p2 || p1 < p2);
#else
        return reinterpret_cast<const uint128_t *>(p1.ww)[0] <= reinterpret_cast<const uint128_t *>(p2.ww)[0];
#endif
    }

    /**
     * @fn operator<(const Point &, const Point &) const
     * Compare points first by H1Value field (including virtuality), then by the ww
     * vector.
     * @param p1 first point.
     * @param p2 second point.
     * It's a tricky compare:
     * vectors are interpreted by ints, so direction is backwards to agree with
     * memory orderings. H1Value that used to be in compare stands in memory after
     * buf[22], so plays the role of top 2 bytes. MAX_IND = 22 is principally
     * important.
     * @return true if p1 < p2, false otherwise
     */
    friend bool operator<(const Point &p1, const Point &p2) {
#ifndef SMALL_POINT
#ifdef LARGE_POINT
        if (reinterpret_cast<const uint128_t *>(p1.ww)[1] ^ reinterpret_cast<const uint128_t *>(p2.ww)[1]) {
            return reinterpret_cast<const uint128_t *>(p1.ww)[1] < reinterpret_cast<const uint128_t *>(p2.ww)[1];
        }
        return reinterpret_cast<const uint128_t *>(p1.ww)[0] < reinterpret_cast<const uint128_t *>(p2.ww)[0];
#else
        if (reinterpret_cast<const uint64_t *>(p1.ww)[2] ^ reinterpret_cast<const uint64_t *>(p2.ww)[2]) {
            return reinterpret_cast<const uint64_t *>(p1.ww)[2] < reinterpret_cast<const uint64_t *>(p2.ww)[2];
        }
        if (reinterpret_cast<const uint64_t *>(p1.ww)[1] ^ reinterpret_cast<const uint64_t *>(p2.ww)[1]) {
            return reinterpret_cast<const uint64_t *>(p1.ww)[1] < reinterpret_cast<const uint64_t *>(p2.ww)[1];
        }
        return reinterpret_cast<const uint64_t *>(p1.ww)[0] < reinterpret_cast<const uint64_t *>(p2.ww)[0];
#endif
#else
        return reinterpret_cast<const uint128_t *>(p1.ww)[0] < reinterpret_cast<const uint128_t *>(p2.ww)[0];
#endif
    }

    /**
     * @fn operator>(const Point &, const Point &) const
     * Compare points first by H1Value field (including virtuality), then by the ww
     * vector.
     * @param p1 first point.
     * @param p2 second point.
     * @return true if p1 > p2, false otherwise, read details for the < operator
     */
    friend bool operator>(const Point &p1, const Point &p2) {
#ifndef SMALL_POINT
#ifdef LARGE_POINT
        if (reinterpret_cast<const uint128_t *>(p1.ww)[1] ^ reinterpret_cast<const uint128_t *>(p2.ww)[1]) {
            return reinterpret_cast<const uint128_t *>(p1.ww)[1] > reinterpret_cast<const uint128_t *>(p2.ww)[1];
        }
        return reinterpret_cast<const uint128_t *>(p1.ww)[0] > reinterpret_cast<const uint128_t *>(p2.ww)[0];
#else
        if (reinterpret_cast<const uint64_t *>(p1.ww)[2] ^ reinterpret_cast<const uint64_t *>(p2.ww)[2]) {
            return reinterpret_cast<const uint64_t *>(p1.ww)[2] > reinterpret_cast<const uint64_t *>(p2.ww)[2];
        }
        if (reinterpret_cast<const uint64_t *>(p1.ww)[1] ^ reinterpret_cast<const uint64_t *>(p2.ww)[1]) {
            return reinterpret_cast<const uint64_t *>(p1.ww)[1] > reinterpret_cast<const uint64_t *>(p2.ww)[1];
        }
        return reinterpret_cast<const uint64_t *>(p1.ww)[0] > reinterpret_cast<const uint64_t *>(p2.ww)[0];
#endif
#else
        return reinterpret_cast<const uint128_t *>(p1.ww)[0] > reinterpret_cast<const uint128_t *>(p2.ww)[0];
#endif
    }

    /**
     * Update output string stream, basically printing the point
     * @param out output ostream
     * @param p Point to be printed
     * @return reference to updated output stream
     */
    friend ostream &operator<<(ostream &out, const Point &p);

    /** Globally known Lee internal symmetries for points. */
    static ibases_t ibases;

    /** Globally known Lee external symmetries for points. */
    static dbases_t dbases;

    /**
     * Integration by part relations (without substituting indices). Each ibp is a
     * vector of pairs (split coefficient and Point shift).
     */
    static vector<ibp_type> ibps;
}
__attribute__((aligned (POINT_ALIGN)));

/** @brief Primitive Point class.
 *
 *  Contains point's indices as is.
 */
class FastPoint {
  public:
    ~FastPoint(); ///< basic destructor

    FastPoint(); ///< basic constructor

    /**
     * Copy constructor
     * @param v initial point
     */
    FastPoint(const FastPoint &v);

    /**
     * @fn FastPoint(const Point &)
     * Constructor from a full Point class
     * @param p point
     * @brief Uses the inverse ordering matrix to get a set if indices from the
     * Point class
     */
    FastPoint(const Point &p);

    /**
     * Constructor from vector of indices
     * @param v vector of indices
     */
    FastPoint(const vector<t_index> &v);

    /** @fn operator=(const FastPoint &) const
     * @brief Make two points equal
     * @param p the original point
     * @return The new point
     */
    FastPoint &operator=(const FastPoint &p);

    /**
     * Make a verctor of indices
     * @return vector of indices based on buffer
     */
    std::vector<t_index> GetVector() const {
        std::vector<t_index> res;
        for (unsigned i = 0; i != Common::dimension; ++i) {
            res.push_back(buf[i]);
        }
        return res;
    }

    /** @fn operator==(const FastPoint &, const FastPoint &) const
     * @brief Compare two points
     * @param p1 first point
     * @param p2 second point
     * @return True if they are equal
     */
    friend bool operator==(const FastPoint &p1, const FastPoint &p2) { return !memcmp(p1.buf, p2.buf, MAX_IND); }

    /** @fn operator!=(const FastPoint &, const FastPoint &) const
     * @brief Compare two points
     * @param p1 first point
     * @param p2 second point
     * @return True if they are not equal
     */
    friend bool operator!=(const FastPoint &p1, const FastPoint &p2) { return memcmp(p1.buf, p2.buf, MAX_IND); }

    /** @fn operator<=(const FastPoint &, const FastPoint &) const
     * @brief Compare two points
     * @param p1 first point
     * @param p2 second point
     * @return True if they are equal or first is less
     */
    friend bool operator<=(const FastPoint &p1, const FastPoint &p2) {
        return (memcmp(p1.buf, p2.buf, MAX_IND) <= 0);
    }

    /** @fn operator<(const FastPoint &, const FastPoint &) const
     * @brief Compare two points
     * @param p1 first point
     * @param p2 second point
     * @return True if first is less. This is just an alphabetic comparisson
     * having no relation with the ordering
     */
    friend bool operator<(const FastPoint &p1, const FastPoint &p2) { return (memcmp(p1.buf, p2.buf, MAX_IND) < 0); }

    /** @fn operator+(const FastPoint &, const FastPoint &) const
     * @brief Add points as vectors. Used in IBP generation.
     * @param p1 first point
     * @param p2 second point
     * @return Resulting point
     */
    friend FastPoint operator+(const FastPoint &p1, const FastPoint &p2) {
        FastPoint result;
        const t_index *pos1 = p1.buf;
        const t_index *pos2 = p2.buf;
        for (unsigned short i = 0; i != MAX_IND; ++i, ++pos1, ++pos2)
            result.buf[i] = *pos1 + *pos2;
        return result;
    }

    /**
     * The degree of the point
     * @return - the absolute values of the shift from the corresponding sector
     * corner
     */
    FastPoint Degree() const;

    /**
     * Sector corresponding to a point
     * @return the corresponding sector (1 and -1 indices)
     */
    SECTOR SectorFast() const;

    /** Buffer for point's indices. */
    t_index buf[MAX_IND];
};

/**
 * Compare fast points l and r degree wise
 * This is a partial sorting function, for example, points in different sectors
 * of same level cannot be compared
 * @param l first point
 * @param r second point
 * @return true if l is above r or equal, meaning all indices are greater or
 * equal pairwise
 */
bool over_fast(const FastPoint &l, const FastPoint &r);

/**
 * Get set of points on a level
 * @param s starting point
 * @param pos number of dots
 * @param neg number of numerators
 * @param filter_function optional parameter, a filter function that returns
 * `true` only for seed points that need to be used
 * @return set of primitive points on a level
 */
set<FastPoint>
level_points_fast(FastPoint s, const unsigned int pos, const unsigned int neg,
                  std::optional<std::function<bool(const FastPoint &)>> filter_function = std::nullopt);

/**
 * Load records from a data stream.
 * @param src the source stream.
 * @param db cache database to put entries to
 * @param condition selecting function
 * @param points set of selected points
 * @return number of entries read
 */
size_t load_snapshot_and_scan(std::istream *src, kyotocabinet::CacheDB *db,
                              std::function<bool(const char *, size_t, const char *, size_t)> condition,
                              set<Point, std::greater<Point>> &points);

/**
 * Open database, load the snapshot and at the same time create a set of point
 * satisfying a condition.
 * @param number the database number
 * @param condition selecting function
 * @param points set of selected points
 */
void open_database_and_scan(int number, std::function<bool(const char *, size_t, const char *, size_t)> condition,
                            set<Point, std::greater<Point>> &points);

#endif
