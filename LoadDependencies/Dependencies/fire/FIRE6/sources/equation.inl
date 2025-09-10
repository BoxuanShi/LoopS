/** @file equation.inl
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package.
 */


template<class I>
void p_set(const point &p, unsigned int n, I termsB, I termsE, unsigned char level, sector_count_t fixed_database_sector) {
    sector_count_t dsector = (fixed_database_sector == 0) ? p.s_number() : fixed_database_sector;
    unsigned int string_size = 0;
#ifdef PRIME
    string_size = n * sizeof(unsigned long long); // we will just put our number into the buffer
#else
    for (auto itr = termsB; itr != termsE; ++itr) {
        string_size += (itr->second.s.size() + 1);
    }
#endif

    char *buf = static_cast<char*>(malloc(3 + n * sizeof(point) + string_size + 1));
    // the structure of the buffer
    // 1) n, 2 bytes
    // 2) level, 1 byte
    // 3) types of lower points, n/4 bytes in case of small, nothing otherwise
    // 4) points, differs in case of small, 24*n otherwise
    // 5) coeffs, 8*n in case of prime, string_size otherwise
    // 6) the 0 symbol, just in case

    if (!buf) {
        cout<<"Cannot malloc in p_set"<<endl;
        abort();
    }

    reinterpret_cast<unsigned short*>(buf)[0] = n; // bytes 1 and 2... can n be longer?
    buf[2] = level; // byte 3

    unsigned int points_size;
    unsigned short j = 0;
    for (auto itr = termsB; itr != termsE; ++itr) {
        reinterpret_cast<point *>(buf + 3)[j] = itr->first;
        ++j;
    }
    points_size = n * sizeof(point);

    uint32_t buf_size = 3 + points_size + string_size + 1;
    if (n) { // just some checks
        auto terms_itr = termsE;
        --terms_itr;
        if (p != terms_itr->first) {
            cout << "p_set error" << endl;
            cout << p << endl;
            cout << n << endl;
            for (auto itr = termsB; itr != termsE; ++itr) { cout << itr->first << endl; }
            abort();
        }
    }
    char *pos = buf + 3 + points_size; // preparing a string of coeffs
    for (auto itr = termsB; itr != termsE; ++itr) {
#ifdef PRIME
        *reinterpret_cast<unsigned long long *>(pos) = itr->second.n;
        pos += sizeof(unsigned long long);
#else
        strncpy(pos, itr->second.s.c_str(), itr->second.s.size());
        pos += itr->second.s.size();
        *pos = '|';
        ++pos;
#endif
    }
    *pos = '\0'; // do we really need it? we won't be interpreting the contents as a string any longer


    class VisitorImpl : public kyotocabinet::DB::Visitor {
        const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz, size_t *sp) {
            const point p = *reinterpret_cast<const point *>(kbuf);

            *sp = buf_size;

            unsigned short n = reinterpret_cast<unsigned short *>(buf)[0];
            char level = buf[2];

            unsigned short old_n = reinterpret_cast<const unsigned short *>(vbuf)[0];
            char old_level = vbuf[2];

            if ((old_n != 0) && (n == 0)) {
                //this means that we have a rule in a lower sector and now it is being marked as needed
                //we should not change the table in this case... but only check the level it is needed up to
                return kyotocabinet::DB::Visitor::NOP;
            }

            if ((old_level == 127) && (n) && (level != 127)) {
                // the point was marked as a master, but now we have a table
                cout << "SOMEHOW " << p << " IS NO LONGER A MASTER!!!" << endl;
                old_level = 126;
            }
            char new_level = old_level;
            if (level > new_level) new_level = level;
            buf[2] = new_level;
            return buf;
        }

        const char *visit_empty(const char *kbuf, size_t ksiz, size_t *sp) {
            *sp = buf_size;
            return buf;
        }
    public:
        char * buf;
        uint32_t buf_size;
    } visitor;

    visitor.buf = buf;
    visitor.buf_size = buf_size;
    common::points[dsector]->accept(p.ww, sizeof(point), &visitor, true);
    free(buf);
}
