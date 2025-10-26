/** @file equation.inl
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package.
 */

template <class I>
void p_set(const Point &p, unsigned int n, I termsB, I termsE, bool needed_higher, sector_count_t sector_number) {
    if (!sector_number)
        sector_number = p.SectorNumber();
    unsigned int string_size = 0;
#ifdef PRIME
#ifdef MPRIME
    string_size = MPRIME * n * sizeof(unsigned long long); // we will just put our multiple
                                                           // numbers into the buffer
#else
    string_size = n * sizeof(unsigned long long); // we will just put our number into the buffer
#endif
#else
    for (auto itr = termsB; itr != termsE; ++itr) {
        string_size += (itr->second.s.size() + 1);
    }
#endif
    unsigned int points_size = n * sizeof(Point);
    unsigned int buf_size = points_size + string_size;
#ifdef PRIME
    ++buf_size;
#else
    buf_size += 4;
#endif

    char *buf = static_cast<char *>(malloc(buf_size));
    // the structure of the buffer
    // 1) points, 16*n in case of small, 24*n otherwise
    // 2) coeffs, 8*n in case of prime, string_size otherwise
    // 3) in case of poly, n, 4 bytes, needed higher stored as top bit, in case of
    // prime 0 or one byte for needed_higher

    if (!buf) {
        cout << "Cannot malloc in p_set" << endl;
        abort();
    }

#ifdef PRIME
    if (needed_higher)
        buf[points_size + string_size] = 1;
    else
        buf[points_size + string_size] = 0; // this is only information for the visitor, length will be decreased
                                            // in this case
#else
    *reinterpret_cast<unsigned int *>(buf + points_size + string_size) = needed_higher ? (n | NEEDED_BIT) : n;
#endif

    unsigned int j = 0;
    for (auto itr = termsB; itr != termsE; ++itr) {
        reinterpret_cast<Point *>(buf)[j] = itr->first;
        ++j;
    }

    if (n) { // just some checks
        auto terms_itr = termsE;
        --terms_itr;
        if (p != terms_itr->first) {
            cout << "p_set error" << endl;
            cout << p << endl;
            cout << n << endl;
            for (auto itr = termsB; itr != termsE; ++itr) {
                cout << itr->first << endl;
            }
            abort();
        }
    }
    char *pos = buf + points_size; // preparing a string of coeffs
    for (auto itr = termsB; itr != termsE; ++itr) {
#ifdef PRIME
#ifdef MPRIME
        for (size_t i = 0; i != MPRIME; ++i) {
            *reinterpret_cast<unsigned long long *>(pos) = itr->second.N[i];
            pos += sizeof(unsigned long long);
        }
#else
        *reinterpret_cast<unsigned long long *>(pos) = itr->second.n;
        pos += sizeof(unsigned long long);
#endif
#else
        strncpy(pos, itr->second.s.c_str(), itr->second.s.size());
        pos += itr->second.s.size();
        *pos = '|';
        ++pos;
#endif
    }

    class VisitorImpl : public kyotocabinet::DB::Visitor {
        const char *visit_full([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz, const char *vbuf,
                               size_t vsiz, size_t *sp) {

            *sp = buf_size;

#ifdef PRIME
#ifdef MPRIME
            unsigned int n = buf_size / (sizeof(Point) + MPRIME * sizeof(unsigned long long));
            unsigned int old_n = vsiz / (sizeof(Point) + MPRIME * sizeof(unsigned long long));
#else
            unsigned int n = buf_size / (sizeof(Point) + sizeof(unsigned long long));
            unsigned int old_n = vsiz / (sizeof(Point) + sizeof(unsigned long long));
#endif

            if ((old_n != 0) && (n == 0)) {
                // this means that we already have a table, and now it is being marked
                // as needed we should not change the table in this case
                return kyotocabinet::DB::Visitor::NOP;
            }
#ifdef MPRIME
            bool needed = buf_size % (sizeof(Point) + MPRIME * sizeof(unsigned long long));
            bool old_needed = vsiz % (sizeof(Point) + MPRIME * sizeof(unsigned long long));
#else
            bool needed = buf_size % (sizeof(Point) + sizeof(unsigned long long));
            bool old_needed = vsiz % (sizeof(Point) + sizeof(unsigned long long));
#endif
            if (!(needed || old_needed)) {
                --*sp;
                // the extra byte is used to mark as needed
            }
#else
            // poly variant
            unsigned int n = *reinterpret_cast<unsigned int *>(buf + buf_size - 4) & ~NEEDED_BIT;
            unsigned int old_n = *reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & ~NEEDED_BIT;

            if ((old_n != 0) && (n == 0)) {
                // this means that we already have a table, and now it is being marked
                // as needed we should not change the table in this case
                return kyotocabinet::DB::Visitor::NOP;
            }
            // now we need to keep the old needed mark, but take the new length
            *reinterpret_cast<unsigned int *>(buf + buf_size - 4) |=
                (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & NEEDED_BIT);
#endif
            return buf;
        }

        const char *visit_empty([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz, size_t *sp) {
            *sp = buf_size;
            return buf;
        }

      public:
        char *buf;
        uint32_t buf_size;
    } visitor;

    visitor.buf = buf;
    visitor.buf_size = buf_size;
    Common::points[sector_number]->accept(p.ww, sizeof(Point), &visitor, true);
    free(buf);
}
