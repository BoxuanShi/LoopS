/** @file point.cpp
 *  @author Alexander Smirnov, Alex Edison
 *
 *  This file is a part of the FIRE package
 *  It contains the basic point class corresponding to a Feynman integral
 */

#include "point.h"
#include <algorithm>

vector<set<vector<t_index> > > point::preferred;
vector<set<point_fast> > point::preferred_fast;
// numbered with sector numbers

bool point::print_g = false;

// we had to move them here to avoid circular dependencies
ibases_t point::ibases;
//        sector       variants    permutation    product     sum         coefficient   indices       powers

dbases_t point::dbases;
//        sector           permutation    product     sum         coefficient   indices       powers

vector<vector<pair<vector<COEFF>, point_fast > > > point::ibps;

point_fast::point_fast() {
    memset(buf, 0, MAX_IND);
}

point_fast::~point_fast() = default;

point_fast &point_fast::operator=(const point_fast &p) {
    memcpy(buf, p.buf, MAX_IND);
    return *this;
}

point_fast::point_fast(const point &p) {
    memset(buf, 0, MAX_IND);
    vector<t_index> v = p.get_vector();
    t_index *pos = buf;
    for (auto itr = v.begin(); itr != v.end(); ++itr, ++pos) *pos = *itr;
}

point_fast::point_fast(const vector<t_index> &v) {
    memset(buf, 0, MAX_IND);
    t_index *pos = buf;
    for (auto itr = v.begin(); itr != v.end(); ++itr, ++pos) *pos = *itr;
}

point_fast::point_fast(const point_fast &p) {
    memcpy(buf, p.buf, MAX_IND);
}

SECTOR point_fast::sector_fast() const {
    SECTOR result = 0;
    const t_index *pos_begin = this->buf;
    const t_index *pos_end = this->buf + common::dimension;
    while (pos_begin != pos_end) {
        if ((*pos_begin) > 0) {
            result = ((result << 1) ^ 1);
        } else {
            result = result << 1;
        }
        ++pos_begin;
    }
    return result;
}

point_fast point_fast::degree() const {
    point_fast result;
    const t_index *pos_old = this->buf;
    t_index *pos_new = result.buf;
    for (size_t i = 0; i != common::dimension; ++i, ++pos_new, ++pos_old)
        if ((*pos_old) > 0) {
            *pos_new = (*pos_old) - 1;
        } else {
            *pos_new = -(*pos_old);
        }
    return result;
}

bool over_fast(const point_fast &l, const point_fast &r) {
    for (unsigned int i = 0; i != common::dimension; ++i) {
        if (l.buf[i] < r.buf[i]) return false;
    }
    return true;
}

point::point(const point &p) {
  memcpy(this->ww,p.ww,std::size(this->ww));
}

point &point::operator=(const point &p) {
  memcpy(this->ww,p.ww,std::size(this->ww));
    return *this;
}

point::point() {
  memset(this->ww,0,std::size(this->ww));
}


int point::level() const {
    return positive_index(common::ssectors[s_number()]);
}

#ifdef SMALL_POINT
    void shift_bits(unsigned short &bit_start, unsigned short &bit_end, unsigned short &current_byte, bool& split_byte) {
        bit_start += BITS_PER_INDEX;
        bit_end += BITS_PER_INDEX;
        if (bit_start >= 8) {
            bit_start -=8;
            ++current_byte;
        }
        if (bit_end >=8) {
            bit_end -= 8;
        }
        split_byte = (bit_start > bit_end);
    }

    inline void set_ww_and_shift(char* ww,char source, unsigned short &bit_start, unsigned short &bit_end, unsigned short &current_byte, bool& split_byte) {
        ww[sizeof(point) - 3 - current_byte] |= ((static_cast<unsigned char>(source) << (8 - BITS_PER_INDEX)) >> bit_start);
        if (split_byte) {
            ww[sizeof(point) - 3 - current_byte - 1] += (source << (7 - bit_end));
        }
        shift_bits(bit_start, bit_end, current_byte, split_byte);
    }

    inline char get_ww_and_shift(const char* ww, unsigned short &bit_start, unsigned short &bit_end, unsigned short &current_byte, bool& split_byte) {
        char result = static_cast<unsigned char>(static_cast<unsigned char>(ww[sizeof(point) - 3 - current_byte]) << bit_start) >> (8 - BITS_PER_INDEX);
        if (split_byte) {
            result |= (static_cast<unsigned char>(ww[sizeof(point) - 3 - current_byte - 1])) >> (7 - bit_end);
        }
        shift_bits(bit_start, bit_end, current_byte, split_byte);
        return result;
    }
#endif

point::point(const vector<t_index> &v, virt_t virt, SECTOR ssector) {

  memset(ww,0,std::size(ww));


    SECTOR s = ssector;
    if (s == static_cast<SECTOR>(-1)) s = sector_fast(v);
    sector_count_t sn;
    if (s == static_cast<SECTOR>(-2)) {
        sn = 1;
    } else {
        sn = common::sector_numbers_fast[s];
    }

    *h1p() = sn << 1;
    if (sn == 0) {
        cout << s << endl;
        cout << endl << "Sector 0" << endl << "Possible error in symmetries" << endl;
        abort();
    }

    if (virt != 0) {
      *reinterpret_cast<virt_t *>(ww + VIRT_OFFSET) = virt;
        ww[VIRT_ZERO_OFFSET] = 0;
        return;
    }

    if ((sn == 1) || (sn == common::virtual_sector)) {
        #ifdef SMALL_POINT
            unsigned short bit_start = {0};
            unsigned short bit_end = {BITS_PER_INDEX - 1};
            unsigned short current_byte = {0};
            bool split_byte = false;
        #endif
        for (unsigned int i = 0; i != common::dimension; ++i) {
            #ifndef SMALL_POINT
                ww[VIRT_ZERO_OFFSET - i] = 128 + v[i];
            #else
                set_ww_and_shift(ww, (1u<<(BITS_PER_INDEX-1)) + v[i], bit_start, bit_end, current_byte, split_byte);
            #endif
        }
    } else {
        auto ordering_now = common::orderings_fast[s].get();
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
        for (unsigned int i = 0; i != common::dimension; ++i) {
            char pr = 1;  // it should be at least 1 to be higher than virtual
            for (unsigned int j = 0; j != common::dimension; ++j) {
                pr += ordering_now[i * common::dimension + j] * (degrees[j]);
            }
            #ifndef SMALL_POINT
                ww[VIRT_ZERO_OFFSET - i] = pr;
            #else
                set_ww_and_shift(ww, pr, bit_start, bit_end, current_byte, split_byte);
            #endif
        }
        if (preferred[sn].find(v) == preferred[sn].end()) {
            *h1p() |= 1;
        }
    }
}

point::point(const point_fast &pf, SECTOR ssector) {
  memset(ww,0,std::size(ww));

    SECTOR s = ssector;
    if (s == static_cast<SECTOR>(-1)) { s = pf.sector_fast(); }
    sector_count_t sn = common::sector_numbers_fast[s];
    *h1p() = sn << 1;
    if (sn == 0) {
        cout << s << endl;
        cout << endl << "Sector 0" << endl << "Possible error in symmetries" << endl;
        abort();
    }

    if (sn == common::virtual_sector) { // we never have sector 1 here
        #ifdef SMALL_POINT
            unsigned short bit_start = {0};
            unsigned short bit_end = {BITS_PER_INDEX - 1};
            unsigned short current_byte = {0};
            bool split_byte = false;
        #endif
        for (unsigned int i = 0; i != common::dimension; ++i) {
            #ifndef SMALL_POINT
                ww[VIRT_ZERO_OFFSET - i] = 128 + pf.buf[i];
            #else
                set_ww_and_shift(ww, (1u<<(BITS_PER_INDEX-1)) + pf.buf[i], bit_start, bit_end, current_byte, split_byte);
            #endif
        }
    } else {
        auto ordering_now = common::orderings_fast[s].get();
        point_fast degrees = pf.degree();

        // size should be equal to common::dimension in this case
        t_index *pos = ordering_now;

        #ifdef SMALL_POINT
            unsigned short bit_start = {0};
            unsigned short bit_end = {BITS_PER_INDEX - 1};
            unsigned short current_byte = {0};
            bool split_byte = false;
        #endif
        for (unsigned int i = 0; i != common::dimension; ++i) {
            #ifndef SMALL_POINT
                ww[VIRT_ZERO_OFFSET - i] = 1; // to be higher than virtual anyway even for preferred
                for (unsigned int j = 0; j != common::dimension; ++j) {
                    if (*pos++) ww[VIRT_ZERO_OFFSET - i] += (degrees.buf[j]);
                }
            #else
                char res = 1;
                for (unsigned int j = 0; j != common::dimension; ++j) {
                    if (*pos++) res += (degrees.buf[j]);
                }
                set_ww_and_shift(ww, res, bit_start, bit_end, current_byte, split_byte);
            #endif
        }
        if (preferred_fast[sn].find(pf) == preferred_fast[sn].end()) {
            *h1p() |= 1;
        }
    }
}

point::point(const point &p, const point_fast& v, SECTOR ssector, bool not_preferred) {
  memcpy(this->ww,p.ww,std::size(this->ww));

    auto ordering_now = common::orderings_fast[ssector].get();
    SECTOR bit = 1<<(common::dimension-1);
    t_index *pos = ordering_now;
    #ifndef SMALL_POINT
        for (unsigned int j = 0; j != common::dimension; ++j) {
            if (v.buf[j]) {
                t_index shift = (bit & ssector) ? v.buf[j] : -v.buf[j];
                for (unsigned int i = 0; i != common::dimension; ++i) {
                    if (*pos) ww[VIRT_ZERO_OFFSET - i] += shift;
                    pos += common::dimension;
                }
                pos -= common::dimension*common::dimension;
            }
            bit >>= 1;
            ++pos;
        }
    #else
        char temp_ww[MAX_IND];
        {
            unsigned short bit_start = {0};
            unsigned short bit_end = {BITS_PER_INDEX - 1};
            unsigned short current_byte = {0};
            bool split_byte = false;
            for (int i = 0; i!=common::dimension; ++i) {
                temp_ww[i] = get_ww_and_shift(p.ww, bit_start, bit_end, current_byte, split_byte);
            }
        }
        for (unsigned int j = 0; j != common::dimension; ++j) {
            if (v.buf[j]) {
                t_index shift = (bit & ssector) ? v.buf[j] : -v.buf[j];
                for (unsigned int i = 0; i != common::dimension; ++i) {
                    if (*pos) temp_ww[i] +=shift;
                    pos += common::dimension;
                }
                pos -= common::dimension*common::dimension;
            }
            bit >>= 1;
            ++pos;
        }
        {
            unsigned short bit_start = {0};
            unsigned short bit_end = {BITS_PER_INDEX - 1};
            unsigned short current_byte = {0};
            bool split_byte = false;
            for (int i = 0; i!=common::dimension; ++i) {
                set_ww_and_shift(ww, temp_ww[i], bit_start, bit_end, current_byte, split_byte);
            }
        }
    #endif

    *h1p() &= ~1u;
    if (not_preferred) {
        *h1p() |= 1;
    }

}

point::point(char *buf) {
  for (unsigned int i = 0; i != std::size(ww); ++i) {
        ww[i] = (buf[i] << 4) ^ (buf[i + std::size(ww)] & 15);
    }
}

void point::safe_string(char *buf) const {
    for (unsigned int i = 0; i != std::size(ww); ++i) {
        buf[i] = (ww[i] >> 4) | 64;
        buf[i + std::size(ww)] = (ww[i] & 15) | 64;
    }
}


string point::number() const {
    stringstream ss(stringstream::out);
    ss << h1();
    #ifdef SMALL_POINT
        unsigned short bit_start = {0};
        unsigned short bit_end = {BITS_PER_INDEX - 1};
        unsigned short current_byte = {0};
        bool split_byte = false;
    #endif
    for (unsigned short i = 0; i != common::dimension; ++i) {
        #ifndef SMALL_POINT
            ss << std::setfill('0') << std::setw(3) << (int(static_cast<unsigned char>(ww[VIRT_ZERO_OFFSET - i])) - 1);
        #else
            sector_count_t sn = s_number();
            vector<t_index> result;
            if ((sn == 1) || (sn == common::virtual_sector)) {
                ss << std::setfill('0') << std::setw(3) << (int(static_cast<unsigned char>(
                    get_ww_and_shift(ww, bit_start, bit_end, current_byte, split_byte) - 1 - (1u<<(BITS_PER_INDEX-1)) +128)
                ));
            } else
                ss << std::setfill('0') << std::setw(3) << (int(static_cast<unsigned char>(get_ww_and_shift(ww, bit_start, bit_end, current_byte, split_byte) - 1)));
        #endif
    }
    return ss.str();
}

//Should rewrite using memcmp
bool point::is_zero() const {
    #ifndef SMALL_POINT
  return std::all_of(reinterpret_cast<const uint64_t *>(ww),
		     reinterpret_cast<const uint64_t *>(ww+std::size(ww)),
		     [](uint64_t i){return i==0;});
    #else
        return reinterpret_cast<const uint128_t *>(this)[0] == 0;
    #endif
}

/**
 * Update output string stream, basically printing the point
 * @param out output ostream
 * @param p point to be printed
 * @return reference to updated output stream
 */
ostream &operator<<(ostream &out, const point &p) {
    out << (point::print_g ? "G[" : "{") << common::global_pn << ",{";
    if (p.virt()) {
        out << p.s_number() << ",";
        out << reinterpret_cast<const virt_t *>(p.ww + VIRT_OFFSET)[0];
    } else {
        unsigned int it = 0;
        vector<t_index> v = p.get_vector();
        out << int(v[it]);
        for (it++; (it != v.size()); it++) out << "," << int(v[it]);
    }
    out << "}" << (point::print_g ? "]" : "}");
    return out;
}


vector<t_index> point::get_vector() const {
    sector_count_t sn = s_number();
    vector<t_index> result;
    if ((sn == 1) || (sn == common::virtual_sector)) {
        #ifdef SMALL_POINT
            unsigned short bit_start = {0};
            unsigned short bit_end = {BITS_PER_INDEX - 1};
            unsigned short current_byte = {0};
            bool split_byte = false;
        #endif
        for (unsigned short i = 0; i != common::dimension; i++) {
            #ifndef SMALL_POINT
                result.push_back(ww[VIRT_ZERO_OFFSET - i] - 128);
            #else
                char res = get_ww_and_shift(ww, bit_start, bit_end, current_byte, split_byte);
                result.push_back(res - (1u<<(BITS_PER_INDEX-1)));
            #endif
        }
    } else {
        vector<vector<t_index> > &iordering = common::iorderings[sn];
        vector<t_index> ssector = common::ssectors[sn];
        for (int i = 0; i != common::dimension; ++i) {
            #ifdef SMALL_POINT
                unsigned short bit_start = {0};
                unsigned short bit_end = {BITS_PER_INDEX - 1};
                unsigned short current_byte = {0};
                bool split_byte = false;
            #endif
            t_index z = 0;
            if (!virt()) {
                for (unsigned short j = 0; j != common::dimension; ++j) {
                    #ifndef SMALL_POINT
                        if (iordering[i][j] == 1) z += (ww[VIRT_ZERO_OFFSET - j] - 1);
                        else if (iordering[i][j] == -1) z -= (ww[VIRT_ZERO_OFFSET - j] - 1);
                    #else
                        char val = get_ww_and_shift(ww, bit_start, bit_end, current_byte, split_byte);
                        if (iordering[i][j] == 1) z += (val - 1);
                        else if (iordering[i][j] == -1) z -= (val - 1);
                    #endif
                }
            }
            if (ssector[i] == 1) z++; else z = -z;
            result.push_back(z);
        }
    }
    return result;
}


set<point_fast> level_points_fast(point_fast s, const unsigned int pos, const unsigned int neg) {
    if ((pos == 0) && (neg == 0)) {
        set<point_fast> r;
        r.insert(s);
        return (r);
    }
    if (neg > 0) {
        set<point_fast> old = level_points_fast(s, pos, neg - 1);
        set<point_fast> r;
        for (const auto & p : old) {
            for (unsigned short i = 0; i < common::dimension; ++i) {
                if (p.buf[i] <= 0) {
                    point_fast p2 = p;
                    p2.buf[i]--;
                    r.insert(p2);
                }
            }
        }
        return r;
    }
    set<point_fast> old = level_points_fast(s, pos - 1, neg);
    set<point_fast> r;
    for (const auto & p : old) {
        for (unsigned short i = 0; i < common::dimension; ++i) {
            if (p.buf[i] > 0) {
                point_fast p2 = p;
                p2.buf[i]++;
                r.insert(p2);
            }
        }
    }
    return r;
}
