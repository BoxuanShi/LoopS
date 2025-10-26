/** @file point.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  It contains the basic Point class corresponding to a Feynman integral
 */

#include "point.h"

bool Point::print_g = false;

// we had to move them here to avoid circular dependencies
ibases_t Point::ibases;
//        sector       variants    permutation    product     sum coefficient
//        indices       powers

dbases_t Point::dbases;
//        sector           permutation    product     sum         coefficient
//        indices       powers

vector<ibp_type> Point::ibps;

FastPoint::FastPoint() {
    memset(buf, 0, MAX_IND);
}

FastPoint::~FastPoint() = default;

FastPoint &FastPoint::operator=(const FastPoint &p) {
    memcpy(buf, p.buf, MAX_IND);
    return *this;
}

FastPoint::FastPoint(const Point &p) {
    memset(buf, 0, MAX_IND);
    vector<t_index> v = p.GetVector();
    t_index *pos = buf;
    for (auto itr = v.begin(); itr != v.end(); ++itr, ++pos)
        *pos = *itr;
}

FastPoint::FastPoint(const vector<t_index> &v) {
    memset(buf, 0, MAX_IND);
    t_index *pos = buf;
    for (auto itr = v.begin(); itr != v.end(); ++itr, ++pos)
        *pos = *itr;
}

FastPoint::FastPoint(const FastPoint &p) {
    memcpy(buf, p.buf, MAX_IND);
}

SECTOR FastPoint::SectorFast() const {
    SECTOR result = 0;
    const t_index *pos_begin = this->buf;
    SECTOR one = 1;
    one <<= (Common::dimension - 1);
    while (one != 0) {
        if ((*pos_begin++) > 0) {
            result ^= one;
        }
        one >>= 1;
    }
    return result;
}

FastPoint FastPoint::Degree() const {
    FastPoint result;
    const t_index *pos_old = this->buf;
    t_index *pos_new = result.buf;
    for (size_t i = 0; i != Common::dimension; ++i, ++pos_new, ++pos_old)
        if ((*pos_old) > 0) {
            *pos_new = (*pos_old) - 1;
        } else {
            *pos_new = -(*pos_old);
        }
    return result;
}

bool over_fast(const FastPoint &l, const FastPoint &r) {
    for (unsigned int i = 0; i != Common::dimension; ++i) {
        if (l.buf[i] < r.buf[i])
            return false;
    }
    return true;
}

Point::Point(const Point &p) {
#ifndef SMALL_POINT
#ifdef LARGE_POINT
    reinterpret_cast<uint128_t *>(this->ww)[1] = reinterpret_cast<const uint128_t *>(p.ww)[1];
    reinterpret_cast<uint128_t *>(this->ww)[0] = reinterpret_cast<const uint128_t *>(p.ww)[0];
#else
    reinterpret_cast<uint64_t *>(this->ww)[2] = reinterpret_cast<const uint64_t *>(p.ww)[2];
    reinterpret_cast<uint64_t *>(this->ww)[1] = reinterpret_cast<const uint64_t *>(p.ww)[1];
    reinterpret_cast<uint64_t *>(this->ww)[0] = reinterpret_cast<const uint64_t *>(p.ww)[0];
#endif
#else
    reinterpret_cast<uint128_t *>(this->ww)[0] = reinterpret_cast<const uint128_t *>(p.ww)[0];
#endif
}

Point &Point::operator=(const Point &p) {
#ifndef SMALL_POINT
#ifdef LARGE_POINT
    reinterpret_cast<uint128_t *>(this->ww)[1] = reinterpret_cast<const uint128_t *>(p.ww)[1];
    reinterpret_cast<uint128_t *>(this->ww)[0] = reinterpret_cast<const uint128_t *>(p.ww)[0];
#else
    reinterpret_cast<uint64_t *>(this->ww)[2] = reinterpret_cast<const uint64_t *>(p.ww)[2];
    reinterpret_cast<uint64_t *>(this->ww)[1] = reinterpret_cast<const uint64_t *>(p.ww)[1];
    reinterpret_cast<uint64_t *>(this->ww)[0] = reinterpret_cast<const uint64_t *>(p.ww)[0];
#endif
#else
    reinterpret_cast<uint128_t *>(this->ww)[0] = reinterpret_cast<const uint128_t *>(p.ww)[0];
#endif
    return *this;
}

Point::Point() {
#ifndef SMALL_POINT
#ifdef LARGE_POINT
    reinterpret_cast<uint128_t *>(this->ww)[1] = 0;
    reinterpret_cast<uint128_t *>(this->ww)[0] = 0;
#else
    reinterpret_cast<uint64_t *>(this->ww)[2] = 0;
    reinterpret_cast<uint64_t *>(this->ww)[1] = 0;
    reinterpret_cast<uint64_t *>(this->ww)[0] = 0;
#endif
#else
    reinterpret_cast<uint128_t *>(this->ww)[0] = 0;
#endif
}

int Point::Level() const {
    return positive_index(Common::ssectors[SectorNumber()]);
}

#ifdef SMALL_POINT
void shift_bits(unsigned short &bit_start, unsigned short &bit_end, unsigned short &current_byte, bool &split_byte) {
    bit_start += BITS_PER_INDEX;
    bit_end += BITS_PER_INDEX;
    if (bit_start >= 8) {
        bit_start -= 8;
        ++current_byte;
    }
    if (bit_end >= 8) {
        bit_end -= 8;
    }
    split_byte = (bit_start > bit_end);
}

inline void set_ww_and_shift(char *ww, char source, unsigned short &bit_start, unsigned short &bit_end,
                             unsigned short &current_byte, bool &split_byte) {
    ww[sizeof(Point) - 3 - current_byte] |= ((static_cast<unsigned char>(source) << (8 - BITS_PER_INDEX)) >> bit_start);
    if (split_byte) {
        ww[sizeof(Point) - 3 - current_byte - 1] += (source << (7 - bit_end));
    }
    shift_bits(bit_start, bit_end, current_byte, split_byte);
}

inline char get_ww_and_shift(const char *ww, unsigned short &bit_start, unsigned short &bit_end,
                             unsigned short &current_byte, bool &split_byte) {
    char result =
        static_cast<unsigned char>(static_cast<unsigned char>(ww[sizeof(Point) - 3 - current_byte]) << bit_start) >>
        (8 - BITS_PER_INDEX);
    if (split_byte) {
        result |= (static_cast<unsigned char>(ww[sizeof(Point) - 3 - current_byte - 1])) >> (7 - bit_end);
    }
    shift_bits(bit_start, bit_end, current_byte, split_byte);
    return result;
}
#endif

Point::Point(const vector<t_index> &v, virt_t virt, SECTOR ssector) {
#ifndef SMALL_POINT
#ifdef LARGE_POINT
    reinterpret_cast<uint128_t *>(ww)[1] = 0;
    reinterpret_cast<uint128_t *>(ww)[0] = 0;
#else
    reinterpret_cast<uint64_t *>(ww)[2] = 0;
    reinterpret_cast<uint64_t *>(ww)[1] = 0;
    reinterpret_cast<uint64_t *>(ww)[0] = 0;
#endif
#else
    reinterpret_cast<uint128_t *>(ww)[0] = 0;
#endif

    SECTOR s = ssector;
    if (s == static_cast<SECTOR>(-1))
        s = sector_fast(v);
    sector_count_t sn;
    if (s == static_cast<SECTOR>(-2)) {
        sn = 1;
    } else {
        sn = Common::sector_numbers_fast[s];
    }

    *H1Pointer() = sn << 1;
    if (sn == 0) {
        cout << s << endl;
        cout << endl << "Sector 0" << endl << "Possible error in symmetries" << endl;
        abort();
    }

    if (virt != 0) {
        *reinterpret_cast<virt_t *>(ww + VIRT_OFFSET) = virt;
        ww[LAST_INDEX_OFFSET] = 0;
        return;
    }

    if ((sn == 1) || (sn == Common::virtual_sector)) {
#ifdef SMALL_POINT
        unsigned short bit_start = {0};
        unsigned short bit_end = {BITS_PER_INDEX - 1};
        unsigned short current_byte = {0};
        bool split_byte = false;
#endif
        for (unsigned short i = 0; i != Common::dimension; ++i) {
#ifndef SMALL_POINT
            ww[LAST_INDEX_OFFSET - i] = 128 + v[i];
#else
            set_ww_and_shift(ww, (1u << (BITS_PER_INDEX - 1)) + v[i], bit_start, bit_end, current_byte, split_byte);
#endif
        }
    } else {
        uint32_t *ordering_now = Common::orderings_fast[s].get();
        t_index degrees[MAX_IND];
        t_index *pos = static_cast<t_index *>(degrees);
        for (auto i = v.begin(); i != v.end(); ++pos, ++i) {
            if ((*i) > 0) {
                *pos = (*i) - 1;
            } else {
                *pos = -(*i);
            }
        }
#ifdef SMALL_POINT
        unsigned short bit_start = {0};
        unsigned short bit_end = {BITS_PER_INDEX - 1};
        unsigned short current_byte = {0};
        bool split_byte = false;
#endif
        for (unsigned int i = 0; i != Common::dimension; ++i) {
            char pr = 1; // it should be at least 1 to be higher than virtual
            uint32_t bit = 1;
            for (unsigned int j = 0; j != Common::dimension; ++j) {
                if (ordering_now[i] & bit) {
                    pr += degrees[j];
                }
                bit <<= 1;
            }
#ifndef SMALL_POINT
            ww[LAST_INDEX_OFFSET - i] = pr;
#else
            set_ww_and_shift(ww, pr, bit_start, bit_end, current_byte, split_byte);
#endif
        }
        if (!IsPreferred(v, sn)) {
            *H1Pointer() |= 1;
        }
    }
}

bool Point::IsPreferred(const vector<t_index> &v, sector_count_t sn) {
    if (preferred[sn].find(v) != preferred[sn].end()) {
        return true;
    }
    if (preferred_initial[sn].empty()) {
        if (Common::has_lbases[sn]) {
            return false;
        }
        // no manually selected preferred points in this sector so we should check
        // it with pos_pref setting
        int pos = 0;
        int pos_max = 0;
        int neg = 0;
        for (auto index : v) {
            if (index > 0) {
                pos += (index - 1);
                if (index > pos_max) {
                    pos_max = index;
                }
            } else {
                neg += (-index);
            }
        }
        if (Common::pos_pref >= 0) {
            if (pos > Common::pos_pref || pos_max > Common::pos_pref) {
                // not preferred
                // for example, having pos_pref 2 we can have 2 dots, but we should not
                // have index 3 this logic is old, comes from the parser where a big set
                // of preferred points was created pos_pref 1 does not allow dots, so
                // only the corner is preferred
                return false;
            }
            if (neg > 0) {
                return false;
            }
        } else {
            if (neg > -Common::pos_pref) {
                return false;
            }
            if (pos > 0) {
                return false;
            }
        }
        return true;
    }
    return false;
}

Point::Point(const FastPoint &pf, SECTOR ssector) {
#ifndef SMALL_POINT
#ifdef LARGE_POINT
    reinterpret_cast<uint128_t *>(ww)[1] = 0;
    reinterpret_cast<uint128_t *>(ww)[0] = 0;
#else
    reinterpret_cast<uint64_t *>(ww)[2] = 0;
    reinterpret_cast<uint64_t *>(ww)[1] = 0;
    reinterpret_cast<uint64_t *>(ww)[0] = 0;
#endif
#else
    reinterpret_cast<uint128_t *>(ww)[0] = 0;
#endif

    SECTOR s = ssector;
    if (s == static_cast<SECTOR>(-1)) {
        s = pf.SectorFast();
    }
    sector_count_t sn = Common::sector_numbers_fast[s];
    *H1Pointer() = sn << 1;
    if (sn == 0) {
        cout << s << endl;
        cout << endl << "Sector 0" << endl << "Possible error in symmetries" << endl;
        abort();
    }

    if (sn == Common::virtual_sector) { // we never have sector 1 here
#ifdef SMALL_POINT
        unsigned short bit_start = {0};
        unsigned short bit_end = {BITS_PER_INDEX - 1};
        unsigned short current_byte = {0};
        bool split_byte = false;
#endif
        for (unsigned int i = 0; i != Common::dimension; ++i) {
#ifndef SMALL_POINT
            ww[LAST_INDEX_OFFSET - i] = 128 + pf.buf[i];
#else
            set_ww_and_shift(ww, (1u << (BITS_PER_INDEX - 1)) + pf.buf[i], bit_start, bit_end, current_byte,
                             split_byte);
#endif
        }
    } else {
        uint32_t *ordering_now = Common::orderings_fast[s].get();
        FastPoint degrees = pf.Degree();

#ifdef SMALL_POINT
        unsigned short bit_start = {0};
        unsigned short bit_end = {BITS_PER_INDEX - 1};
        unsigned short current_byte = {0};
        bool split_byte = false;
#endif
        for (unsigned int i = 0; i != Common::dimension; ++i) {
            uint32_t bit = 1;
#ifndef SMALL_POINT
            ww[LAST_INDEX_OFFSET - i] = 1; // to be higher than virtual anyway even for preferred
            for (unsigned int j = 0; j != Common::dimension; ++j) {
                if (ordering_now[i] & bit)
                    ww[LAST_INDEX_OFFSET - i] += (degrees.buf[j]);
                bit <<= 1;
            }
#else
            char res = 1;
            for (unsigned int j = 0; j != Common::dimension; ++j) {
                if (ordering_now[i] & bit)
                    res += (degrees.buf[j]);
                bit <<= 1;
            }
            set_ww_and_shift(ww, res, bit_start, bit_end, current_byte, split_byte);
#endif
        }
        if (!IsPreferred(pf.GetVector(), sn)) {
            *H1Pointer() |= 1;
        }
    }
}

Point::Point(const Point &p, const FastPoint &v, SECTOR ssector, bool not_preferred) {
#ifndef SMALL_POINT
    // we will be adding in normal mode
#ifdef LARGE_POINT
    reinterpret_cast<uint128_t *>(this)[1] = reinterpret_cast<const uint128_t *>(p.ww)[1];
    reinterpret_cast<uint128_t *>(this)[0] = reinterpret_cast<const uint128_t *>(p.ww)[0];
#else
    reinterpret_cast<uint64_t *>(this)[2] = reinterpret_cast<const uint64_t *>(p.ww)[2];
    reinterpret_cast<uint64_t *>(this)[1] = reinterpret_cast<const uint64_t *>(p.ww)[1];
    reinterpret_cast<uint64_t *>(this)[0] = reinterpret_cast<const uint64_t *>(p.ww)[0];
#endif
#else
    reinterpret_cast<uint128_t *>(this)[0] = 0;
    *H1Pointer() = p.H1Value();
#endif

    uint32_t *ordering_now = Common::orderings_fast[ssector].get();
    uint32_t obit = 1;
    SECTOR bit = 1 << (Common::dimension - 1);
#ifndef SMALL_POINT
    for (unsigned int j = 0; j != Common::dimension; ++j) {
        if (v.buf[j]) {
            t_index shift = (bit & ssector) ? v.buf[j] : -v.buf[j];
            for (unsigned int i = 0; i != Common::dimension; ++i) {
                if (ordering_now[i] & obit)
                    ww[LAST_INDEX_OFFSET - i] += shift;
            }
        }
        bit >>= 1;
        obit <<= 1;
    }
#else
    char temp_ww[MAX_IND];
    {
        unsigned short bit_start = {0};
        unsigned short bit_end = {BITS_PER_INDEX - 1};
        unsigned short current_byte = {0};
        bool split_byte = false;
        for (int i = 0; i != Common::dimension; ++i) {
            temp_ww[i] = get_ww_and_shift(p.ww, bit_start, bit_end, current_byte, split_byte);
        }
    }
    for (unsigned int j = 0; j != Common::dimension; ++j) {
        if (v.buf[j]) {
            t_index shift = (bit & ssector) ? v.buf[j] : -v.buf[j];
            for (unsigned int i = 0; i != Common::dimension; ++i) {
                if (ordering_now[i] & obit)
                    temp_ww[i] += shift;
            }
        }
        bit >>= 1;
        obit <<= 1;
    }
    {
        unsigned short bit_start = {0};
        unsigned short bit_end = {BITS_PER_INDEX - 1};
        unsigned short current_byte = {0};
        bool split_byte = false;
        for (int i = 0; i != Common::dimension; ++i) {
            set_ww_and_shift(ww, temp_ww[i], bit_start, bit_end, current_byte, split_byte);
        }
    }
#endif

    *H1Pointer() &= ~1u;
    if (not_preferred) {
        *H1Pointer() |= 1;
    }
}

Point::Point(const char *buf) {
    for (unsigned int i = 0; i != POINT_SIZE; ++i) {
        ww[i] = (static_cast<unsigned char>(buf[i]) << 4) ^ (static_cast<unsigned char>(buf[i + POINT_SIZE]) & 15);
    }
}

void Point::SafeString(char *buf) const {
    for (unsigned int i = 0; i != POINT_SIZE; ++i) {
        buf[i] = (static_cast<unsigned char>(ww[i]) >> 4) | 64;
        buf[i + POINT_SIZE] = (static_cast<unsigned char>(ww[i]) & 15) | 64;
    }
}

string Point::Number() const {
    stringstream ss(stringstream::out);
    ss << H1Value();
#ifdef SMALL_POINT
    unsigned short bit_start = {0};
    unsigned short bit_end = {BITS_PER_INDEX - 1};
    unsigned short current_byte = {0};
    bool split_byte = false;
#endif
    for (unsigned short i = 0; i != Common::dimension; ++i) {
#ifndef SMALL_POINT
        ss << std::setfill('0') << std::setw(3) << (int(static_cast<unsigned char>(ww[LAST_INDEX_OFFSET - i])) - 1);
#else
        sector_count_t sn = SectorNumber();
        vector<t_index> result;
        if ((sn == 1) || (sn == Common::virtual_sector)) {
            ss << std::setfill('0') << std::setw(3)
               << (int(static_cast<unsigned char>(get_ww_and_shift(ww, bit_start, bit_end, current_byte, split_byte) -
                                                  1 - (1u << (BITS_PER_INDEX - 1)) + 128)));
        } else
            ss << std::setfill('0') << std::setw(3)
               << (int(static_cast<unsigned char>(get_ww_and_shift(ww, bit_start, bit_end, current_byte, split_byte) -
                                                  1)));
#endif
    }
    return ss.str();
}

bool Point::IsZero() const {
#ifndef SMALL_POINT
#ifdef LARGE_POINT
    return (reinterpret_cast<const uint128_t *>(this)[1] == 0) && (reinterpret_cast<const uint128_t *>(this)[0] == 0);
#else
    return (reinterpret_cast<const uint64_t *>(this)[2] == 0) && (reinterpret_cast<const uint64_t *>(this)[1] == 0) &&
           (reinterpret_cast<const uint64_t *>(this)[0] == 0);
#endif
#else
    return reinterpret_cast<const uint128_t *>(this)[0] == 0;
#endif
}

/**
 * Update output string stream, basically printing the point
 * @param out output ostream
 * @param p Point to be printed
 * @return reference to updated output stream
 */
ostream &operator<<(ostream &out, const Point &p) {
    out << (Point::print_g ? "G[" : "{") << Common::global_pn << ",{";
    if (p.IsVirtual()) {
        out << p.SectorNumber() << ",";
        out << reinterpret_cast<const virt_t *>(p.ww + VIRT_OFFSET)[0];
    } else {
        unsigned int it = 0;
        vector<t_index> v = p.GetVector();
        out << int(v[it]);
        for (it++; (it != v.size()); it++)
            out << "," << int(v[it]);
    }
    out << "}" << (Point::print_g ? "]" : "}");
    return out;
}

vector<t_index> Point::GetVector() const {
    sector_count_t sn = SectorNumber();
    vector<t_index> result;
    if ((sn == 1) || (sn == Common::virtual_sector)) {
#ifdef SMALL_POINT
        unsigned short bit_start = {0};
        unsigned short bit_end = {BITS_PER_INDEX - 1};
        unsigned short current_byte = {0};
        bool split_byte = false;
#endif
        for (unsigned short i = 0; i != Common::dimension; i++) {
            if (!IsVirtual()) {
#ifndef SMALL_POINT
                result.push_back(ww[LAST_INDEX_OFFSET - i] - 128);
#else
                char res = get_ww_and_shift(ww, bit_start, bit_end, current_byte, split_byte);
                result.push_back(res - (1u << (BITS_PER_INDEX - 1)));
#endif
            } else {
                result.push_back(0);
            }
        }
    } else {
        vector<vector<t_index>> &iordering = Common::iorderings[sn];
        vector<t_index> ssector = Common::ssectors[sn];
        for (unsigned short i = 0; i != Common::dimension; ++i) {
#ifdef SMALL_POINT
            unsigned short bit_start = {0};
            unsigned short bit_end = {BITS_PER_INDEX - 1};
            unsigned short current_byte = {0};
            bool split_byte = false;
#endif
            t_index z = 0;
            if (!IsVirtual()) {
                for (int j = 0; j != Common::dimension; ++j) {
#ifndef SMALL_POINT
                    if (iordering[i][j] == 1)
                        z += (ww[LAST_INDEX_OFFSET - j] - 1);
                    else if (iordering[i][j] == t_index(-1))
                        z -= (ww[LAST_INDEX_OFFSET - j] - 1);
#else
                    char val = get_ww_and_shift(ww, bit_start, bit_end, current_byte, split_byte);
                    if (iordering[i][j] == 1)
                        z += (val - 1);
                    else if (iordering[i][j] == t_index(-1))
                        z -= (val - 1);
#endif
                }
            }
            if (ssector[i] == 1)
                z++;
            else
                z = -z;
            result.push_back(z);
        }
    }
    return result;
}

set<FastPoint> level_points_fast(FastPoint s, const unsigned int pos, const unsigned int neg,
                                  std::optional<std::function<bool(const FastPoint &)>> filter_function) {
    if ((pos == 0) && (neg == 0)) {
        set<FastPoint> r;
        if ((!filter_function.has_value()) || (filter_function.value()(s)))
            r.insert(s);
        return (r);
    }
    if (neg > 0) {
        set<FastPoint> old = level_points_fast(s, pos, neg - 1, filter_function);
        set<FastPoint> r;
        for (const auto &p : old) {
            for (unsigned short i = 0; i < Common::dimension; ++i) {
                if (p.buf[i] <= 0) {
                    FastPoint p2 = p;
                    p2.buf[i]--;
                    if ((!filter_function.has_value()) || (filter_function.value()(p2)))
                        r.insert(p2);
                }
            }
        }
        return r;
    }
    set<FastPoint> old = level_points_fast(s, pos - 1, neg, filter_function);
    set<FastPoint> r;
    for (const auto &p : old) {
        for (unsigned short i = 0; i < Common::dimension; ++i) {
            if (p.buf[i] > 0) {
                FastPoint p2 = p;
                p2.buf[i]++;
                if ((!filter_function.has_value()) || (filter_function.value()(p2)))
                    r.insert(p2);
            }
        }
    }
    return r;
}

size_t load_snapshot_and_scan(std::istream *src, kyotocabinet::CacheDB *db,
                              std::function<bool(const char *, size_t, const char *, size_t)> condition,
                              set<Point, std::greater<Point>> &points) {

    char buf[8192];
    src->read(buf, sizeof(KCDBSSMAGICDATA));
    if (src->fail()) {
        cout << "Stream input error at read start" << endl;
        abort();
    }
    if (std::memcmp(buf, KCDBSSMAGICDATA, sizeof(KCDBSSMAGICDATA))) {
        cout << "Invalid magic data of input stream" << endl;
        abort();
    }
    int64_t curcnt = 0;
    while (true) {
        int32_t c = src->get();
        if (src->eof())
            break;
        if (src->fail()) {
            cout << "Stream input error" << endl;
            abort();
        }
        // if (c == 0xff) break;
        if (c == 0x00) {
            size_t ksiz = 0;
            do {
                c = src->get();
                ksiz = (ksiz << 7) + (c & 0x7f);
            } while (c >= 0x80);
            size_t vsiz = 0;
            do {
                c = src->get();
                vsiz = (vsiz << 7) + (c & 0x7f);
            } while (c >= 0x80);
            size_t rsiz = ksiz + vsiz;
            char *rbuf = rsiz > sizeof(buf) ? new char[rsiz] : buf;
            src->read(rbuf, ksiz + vsiz);
            if (src->fail()) {
                cout << "Stream input error" << endl;
                if (rbuf != buf)
                    delete[] rbuf;
                abort();
            }
            if (condition(rbuf, ksiz, rbuf + ksiz, vsiz))
                points.insert(*reinterpret_cast<Point *>(rbuf));
            if (!db->set(rbuf, ksiz, rbuf + ksiz, vsiz)) {
                if (rbuf != buf)
                    delete[] rbuf;
                cout << "Cannot set entry" << endl;
                abort();
            }
            if (rbuf != buf)
                delete[] rbuf;
        } else {
            cout << "Invalid magic data of input stream" << endl;
            abort();
        }
        curcnt++;
    }
    return curcnt;
}

void open_database_and_scan(int number, std::function<bool(const char *, size_t, const char *, size_t)> condition,
                            set<Point, std::greater<Point>> &points) {

    Common::points[number] = new kyotocabinet::CacheDB;

    auto pdb = Common::points[number];
    pdb->tune_buckets(1llu << Common::buckets[number]);

    if (Common::compressor != t_compressor::C_NONE) {
        pdb->tune_options(kyotocabinet::CacheDB::TLINEAR | kyotocabinet::CacheDB::TCOMPRESS);
        pdb->tune_compressor(Common::compressor_class.get());
    }

    if (!pdb->open("*")) {
        cout << "Error opening database, exiting" << endl;
        abort();
    }
    std::ifstream ifs;
    ifs.open((Common::path + int2string(number) + ".tmp").c_str(), std::ios_base::in | std::ios_base::binary);
    if (!ifs) {
        cout << "Cannot open snapshot file for reading" << endl;
        abort();
    }

    load_snapshot_and_scan(&ifs, pdb, condition, points);

    ifs.close();
    if (ifs.bad()) {
        cout << "Cannot close snapshot file after reading" << endl;
        abort();
    }
    uint64_t entries = pdb->count();
    if (entries > (1llu << Common::buckets[number])) {
        while (entries > (1llu << Common::buckets[number])) {
            Common::buckets[number]++;
        }
        reopen_database(number, false);
    }
}
