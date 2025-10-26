/** @file common.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package.
 *  It contains the initializations of static variables in the common class
 *  and a number of general functions used in other parts of the program.
 */

#include "common.h"

#include <sys/mman.h>
#include <sys/stat.h>
/* initializations of static variables
 * refer to common.h for details
 */

#ifdef PRIME
nmod_t Common::flint_mod;
#endif

vector<string> Common::variables;
vector<string> Common::fuelOptions;
string Common::fuelOptionsString;

kyotocabinet::HashDB Common::wrapper_database;

bool Common::large_variables = false;

thread Common::socket_listen;

unsigned short Common::dimension;
bool Common::parity_used[MAX_IND];
unique_ptr<sector_count_t[]> Common::sector_numbers_fast;
unique_ptr<unique_ptr<uint32_t[]>[]> Common::orderings_fast;

string Common::dep_file{};

int Common::pos_pref = 1;

string Common::ordering_string = "ANl";
vector<t_index> Common::index_ordering = {};

unsigned int Common::presolve_ibps = 0;

t_stages Common::stages = t_stages::all;
int Common::target_level = 0;
t_points Common::points_used = t_points::all;

bool Common::silent = false;
bool Common::very_silent = false;
bool Common::clean_databases = false;
bool Common::ftool = false;
sector_count_t Common::single_sector = 0;

bool Common::one_pass = false;
string Common::one_pass_database{};

bool Common::disable_presolve = false;
bool Common::old_presolve = false;

int Common::bucket_override = {};

bool Common::hint;
string Common::hint_path;

t_compressor Common::compressor = t_compressor::C_LZ4;
int Common::compressor_level{};
unique_ptr<kyotocabinet::Compressor> Common::compressor_class;

uint64_t Common::prime = 0;              // the prime number for fast evaluations
unsigned short Common::prime_number(-1); // by default no prime is selected

map<string, std::vector<std::string>> Common::variable_replacements; // while parsing
string Common::active_variables;

bool Common::all_ibps = false;

int Common::print_step = 0;

bool Common::split_masters = false;
bool Common::split_masters_no_dep = false;
unsigned int Common::master_number_min = 0;
unsigned int Common::master_number_max = 0;

string Common::output_override{};

bool Common::variables_set_from_command_line = false;

sector_count_t Common::virtual_sector = 0;

bool Common::parallel_mode = false;

string Common::path = "";
string Common::cpath;

vector<pair<int,int>> Common::completed_in_storage;
string Common::completed_in_storage_fname = "completed_in_storage";

bool Common::cpath_on_substitutions = false;
int Common::buckets[MAX_SECTORS + 1];

string Common::tables_prefix = "";

bool Common::only_masters = false;

// pipes for expression communication
FILE *Common::child_stream_from_child = nullptr;
FILE *Common::child_stream_to_child = nullptr;
bool Common::receive_from_child = false;
bool Common::send_to_parent = false;

sector_count_t Common::abs_max_sector = 3;

int Common::abs_max_level = 0;

int Common::abs_min_level = 100;
kyotocabinet::CacheDB *Common::points[MAX_SECTORS + 1];

atomic<long long> Common::simplify_time{};
atomic<long long> Common::thread_time{};

unsigned int Common::global_pn = 0;
unsigned int Common::threads_number = 0;
unsigned int Common::lthreads_number = 1;
unsigned int Common::sthreads_number = 0;
unsigned int Common::fthreads_number = 0;
unsigned int Common::f_queues = 1;

int Common::print_all_up_to_complexity = -1;
bool Common::bottom_sector_only = false;

map<unsigned short, unsigned int> Common::threads_level_number;
unsigned int Common::threads_default_number;

vector<vector<vector<t_index>>> Common::iorderings;
vector<vector<vector<t_index>>> Common::symmetries;

vector<vector<t_index>> Common::ssectors;
set<SECTOR> Common::lsectors;

common_lbases_t  Common::lbases;
//      sector    condition+result        coefficients  free term   eq coeff
//      indices:   coefficients and free term

// database wrapper things
mutex Common::wrapper_mutex;
bool Common::wrap_databases;

vector<t_index> sector(const vector<t_index> &v) {
    vector<t_index> result;
    for (const t_index i : v)
        if (i > 0) {
            result.push_back(1);
        } else {
            result.push_back(-1);
        }
    return result;
}

SECTOR sector_fast(const vector<t_index> &v) {
    SECTOR result = 0;
    for (const t_index i : v)
        if (i > 0) {
            result = ((result << 1) ^ 1);
        } else {
            result = result << 1;
        }
    return result;
}

vector<t_index> corner(const vector<t_index> &v) {
    vector<t_index> result;
    for (const t_index i : v)
        if (i > 0) {
            result.push_back(1);
        } else {
            result.push_back(0);
        }
    return result;
}

vector<t_index> degree(const vector<t_index> &v) {
    vector<t_index> result;
    for (const t_index i : v)
        if (i > 0) {
            result.push_back(i - 1);
        } else {
            result.push_back(-i);
        }
    return result;
}

pair<unsigned int, unsigned int> level(const vector<t_index> &v) {
    unsigned int p = 0;
    unsigned int m = 0;
    for (const t_index i : v)
        if (i > 0) {
            p += (i - 1);
        } else {
            m += (-i);
        }
    return make_pair(p, m);
}

// output routines for vectors and double vectors
void print_vector(const vector<t_index> &v) {
    if (Common::silent)
        return;
    auto it = v.begin();
    cout << "{" << int(*it);
    for (it++; it != v.end(); it++) {
        cout << "," << int(*it);
    }
    cout << "}";
}

// output routines for vectors and double vectors
void print_sector_fast(const SECTOR &sf) {
    if (Common::silent)
        return;
    SECTOR i = 1;
    i <<= (Common::dimension - 1);
    cout << "{" << (i & sf ? 1 : -1);
    for (i >>= 1; i; i >>= 1) {
        cout << "," << (i & sf ? 1 : -1);
    }
    cout << "}";
}

void symmetry_orbit(const vector<t_index> &v, vector<vector<t_index>> &orbit, vector<vector<vector<t_index>>> &sym) {
    for (const auto &values : sym) {
        if (values.size() == 4) {
            const vector<t_index> &restrictions = values[2];
            for (unsigned int i = 0; i != v.size(); ++i) {
                if ((restrictions[i] == 1) && (v[i] <= 0))
                    continue;
                if ((restrictions[i] == -1) && (v[i] > 0))
                    continue;
            }
        }
        const vector<t_index> &permutation = values[0];
        vector<t_index> result;
        for (unsigned int i = 0; i != v.size(); ++i) {
            result.push_back(v[permutation[i] - 1]);
        }
        bool to_add = true;
        for (unsigned int i = (*(values.rbegin()))[0]; i != result.size(); ++i) {
            if (result[i] > 0) {
                to_add = false;
            }
        }
        if (to_add)
            orbit.push_back(result);
    }
}

void make_ordering(uint32_t *mat, const vector<t_index> &sector, const string local_ordering_string) {
    vector<vector<t_index>> result;
    result.reserve(sector.size());
    vector<t_index> neg;
    vector<t_index> pos;
    vector<t_index> one_vector;
    vector<t_index> zero_vector;
    zero_vector.reserve(sector.size());

    bool all_plus = true;
    bool all_minus = true;
    for (const t_index i : sector) {
        if (i != 1)
            all_plus = false;
        if (i != -1)
            all_minus = false;
    }

    unsigned int pos_count = 0;
    unsigned int neg_count = 0;

    for (unsigned int i = 0; i < sector.size(); ++i) {
        one_vector.push_back(1);
        zero_vector.push_back(0);
        if (sector[i] == 1) {
            neg.push_back(0);
            pos.push_back(1);
            ++pos_count;
        } else {
            neg.push_back(1);
            pos.push_back(0);
            ++neg_count;
        }
    }

    const char *ordering_pos = local_ordering_string.c_str();

    if ((all_plus) || all_minus) {
        result.push_back(one_vector);
        for (unsigned int i = 0; i + 1 < sector.size(); ++i) {
            vector<t_index> v;
            for (unsigned int j = 0; j < sector.size(); ++j) {
                if (i == j) {
                    v.push_back(1);
                } else {
                    v.push_back(0);
                }
            }
            result.push_back(v);
        }
    } else {
        if (!pos_count || !neg_count) {
            cout << "Something wrong with make_ordering!" << endl;
            abort();
        }
        bool used_sum = false;
        bool used_pos = false;
        bool used_neg = false;
        bool next_reverse = false;
        bool next_inverse = false;
        while (*ordering_pos != '\0') {
            if (*ordering_pos == 'A') {
                result.push_back(one_vector);
                used_sum = true;
            } else if (*ordering_pos == 'N') {
                result.push_back(neg);
                used_neg = true;
                if (used_sum)
                    used_pos = true;
            } else if (*ordering_pos == 'P') {
                result.push_back(pos);
                used_pos = true;
                if (used_sum)
                    used_neg = true;
            } else if (*ordering_pos == 'r') {
                next_reverse = true;
            } else if (*ordering_pos == 'i') {
                next_inverse = true;
            } else if (*ordering_pos == 'a') {
                bool first_positive = true;
                bool first_negative = true;
                for (unsigned int i = (next_reverse ? sector.size() - 1 : 0);
                     i != (next_reverse ? static_cast<unsigned int>(-1) : sector.size()); (next_reverse ? --i : ++i)) {
                    unsigned int j = Common::index_ordering[i] - 1;
                    bool adding = true;
                    if (sector[j] == 1) {
                        if (next_inverse) {
                            if (first_positive && (used_pos || (first_negative && used_sum))) {
                                adding = false;
                            }
                            first_positive = false;
                        } else {
                            --pos_count;
                            if (!pos_count) {
                                if (used_pos || (used_sum && !neg_count)) {
                                    adding = false;
                                }
                                used_pos = true;
                                if (used_sum)
                                    used_neg = true;
                            }
                        }
                    } else {
                        if (next_inverse) {
                            if (first_negative && (used_neg || (first_positive && used_sum))) {
                                adding = false;
                            }
                            first_negative = false;
                        } else {
                            --neg_count;
                            if (!neg_count) {
                                if (used_neg || (used_sum && !pos_count)) {
                                    adding = false;
                                }
                                used_neg = true;
                                if (used_sum)
                                    used_pos = true;
                            }
                        }
                    }
                    if (adding) {
                        if (next_inverse) {
                            result.push_back(one_vector);
                        } else {
                            vector<t_index> v = zero_vector;
                            v[j] = 1;
                            result.push_back(v);
                        }
                    }
                    if (next_inverse) {
                        one_vector[j] = 0;
                    }
                }
                next_reverse = false;
                next_inverse = false;
            } else if (*ordering_pos == 'l') {
                for (unsigned int i = (next_reverse ? sector.size() - 1 : 0);
                     i != (next_reverse ? static_cast<unsigned int>(-1) : sector.size()); (next_reverse ? --i : ++i)) {
                    unsigned int j = Common::index_ordering[i] - 1;
                    if (sector[j] == 1) {
                        --pos_count;
                        if ((!used_pos) || pos_count) {
                            vector<t_index> v = zero_vector;
                            v[j] = 1;
                            result.push_back(v);
                        }
                    } else {
                        --neg_count;
                        if ((!used_neg) || neg_count) {
                            neg[j] = 0;
                            result.push_back(neg);
                        }
                    }
                }
                next_reverse = false;
                next_inverse = false;
            } else if (*ordering_pos == 'p') {
                bool first_positive = true;
                for (unsigned int i = (next_reverse ? sector.size() - 1 : 0);
                     i != (next_reverse ? static_cast<unsigned int>(-1) : sector.size()); (next_reverse ? --i : ++i)) {
                    unsigned int j = Common::index_ordering[i] - 1;
                    if (sector[j] == 1) {
                        if (next_inverse) {
                            if (!first_positive || !used_pos) {
                                result.push_back(pos);
                            }
                            first_positive = false;
                            pos[j] = 0;
                        } else {
                            --pos_count;
                            if ((!used_pos) || pos_count) {
                                vector<t_index> v = zero_vector;
                                v[j] = 1;
                                result.push_back(v);
                            }
                        }
                    }
                }
                next_reverse = false;
                next_inverse = false;
                used_pos = true;
                if (used_sum)
                    used_neg = true;
            } else if (*ordering_pos == 'n') {
                bool first_negative = true;
                for (unsigned int i = (next_reverse ? sector.size() - 1 : 0);
                     i != (next_reverse ? static_cast<unsigned int>(-1) : sector.size()); (next_reverse ? --i : ++i)) {
                    unsigned int j = Common::index_ordering[i] - 1;
                    if (sector[j] != 1) {
                        if (next_inverse) {
                            if (!first_negative || !used_neg) {
                                result.push_back(neg);
                            }
                            first_negative = false;
                            neg[j] = 0;
                        } else {
                            --neg_count;
                            if ((!used_neg) || neg_count) {
                                vector<t_index> v = zero_vector;
                                v[j] = 1;
                                result.push_back(v);
                            }
                        }
                    }
                }
                next_reverse = false;
                next_inverse = false;
                used_neg = true;
                if (used_sum)
                    used_pos = true;
            }
            ++ordering_pos;
        }
    }

    int row = 0;
    for (auto itr_row = result.begin(); itr_row != result.end(); ++itr_row, ++row) {
        // now we stopped using vectors, moving to arrays, it's much faster
        // and array of vectors leads to crashes
        int column = 0;
        uint32_t res = 0;
        uint32_t bit = 1;
        for (auto itr_column = itr_row->begin(); itr_column != itr_row->end(); ++itr_column, ++column) {
            if (*itr_column)
                res += bit;
            bit <<= 1;
        }
        mat[row] = res;
    }
}

vector<vector<t_index>> all_sectors(unsigned int d, int positive, int positive_start) {
    vector<t_index> vv3;
    for (unsigned int i = 0; i != d; ++i)
        vv3.push_back(-1);
    vector<vector<t_index>> vv;
    vv.push_back(vv3);
    for (int i = positive_start - 1; i < positive; ++i) {
        vector<vector<t_index>> ww = vv;
        vv.reserve(2 * vv.size());
        for (auto &current : ww) {
            current[i] = 1;
            vv.push_back(current);
        };
    };
    return (vv);
}

size_t dump_partial_snapshot(std::ostream *dest, kyotocabinet::CacheDB *db,
                             std::function<bool(const char *, size_t, const char *, size_t)> condition) {
    class VisitorImpl : public kyotocabinet::DB::Visitor {
      public:
        explicit VisitorImpl(std::ostream *dest,
                             std::function<bool(const char *, size_t, const char *, size_t)> condition)
            : dest_(dest), stack_(), condition_(condition) {};
        size_t ignored{};

      private:
        const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz,
                               [[maybe_unused]] size_t *sp) {
            if (condition_(kbuf, ksiz, vbuf, vsiz)) {
                char *wp = stack_;
                *(wp++) = 0x00;
                wp += kyotocabinet::writevarnum(wp, ksiz);
                wp += kyotocabinet::writevarnum(wp, vsiz);
                dest_->write(stack_, wp - stack_);
                dest_->write(kbuf, ksiz);
                dest_->write(vbuf, vsiz);
            } else
                ++ignored;
            return NOP;
        }
        std::ostream *dest_;
        char stack_[64];
        std::function<bool(const char *, size_t, const char *, size_t)> condition_;
    };
    VisitorImpl visitor(dest, condition);
    visitor.ignored = 0;
    if (db->iterate(&visitor, false)) {
        /*unsigned char c = 0xff;
        dest->write((char*)&c, 1);
        if (dest->fail()) {
            cout << "Cannot write in dump_partial_snapshot " << endl;
            abort();
        }*/
    } else {
        cout << "Cannot iterate in dump_partial_snapshot " << endl;
        abort();
    }
    return visitor.ignored;
}

bool database_exists(sector_count_t number) {
    if (Common::wrap_databases) {
        lock_guard<mutex> guard(Common::wrapper_mutex);
        string key = int2string(number);
        return (Common::wrapper_database.check(key) != -1);
    }
    string name = Common::path + int2string(number);
    name += ".tmp";
    bool result = (access(name.c_str(), F_OK) != -1);
    return result;
}

void open_database(sector_count_t number, bool read_snapshot) {
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

    if (read_snapshot) {
        pdb->load_snapshot(Common::path + int2string(number) + ".tmp");
        uint64_t entries = pdb->count();
        if (entries > (1llu << Common::buckets[number])) {
            while (entries > (1llu << Common::buckets[number])) {
                Common::buckets[number]++;
            }
            reopen_database(number, false);
        }
    }
}

void reopen_database(sector_count_t number, bool changed) {
    if (!Common::silent) {
        cout << "Reopening database " << number << " with bucket=" << Common::buckets[number] << endl;
    }
    string path = Common::path + int2string(number) + ".tmp";

    close_database(number, changed);
    open_database(number);
}

size_t close_database(sector_count_t number, bool changed,
                      std::function<bool(const char *, size_t, const char *, size_t)> condition, bool append_snaphot) {
    size_t ignored{};
    if (changed) {
        if (condition) {
            std::ofstream ofs;
            if (append_snaphot)
                ofs.open((Common::path + int2string(number) + ".tmp").c_str(),
                         std::ios_base::out | std::ios_base::binary | std::ios_base::app);
            else
                ofs.open((Common::path + int2string(number) + ".tmp").c_str(),
                         std::ios_base::out | std::ios_base::binary | std::ios_base::trunc);
            if (!ofs) {
                cout << "Cannot open database snapshot for writing " << number << endl;
                abort();
            }
            if (append_snaphot) {
                // long pos = ofs.tellp();
                // cout<<pos<<endl;
                // ofs.seekp(pos-1);
            } else {
                ofs.write(KCDBSSMAGICDATA, sizeof(KCDBSSMAGICDATA));
            }
            ignored = dump_partial_snapshot(&ofs, Common::points[number], condition);
            ofs.close();
            if (!ofs) {
                cout << "Cannot close database snapshot " << number << endl;
                abort();
            }
        } else {
            Common::points[number]->dump_snapshot(Common::path + int2string(number) + ".tmp");
        }
    }
    Common::points[number]->close();
    delete Common::points[number];
    return ignored;
}

bool in_lsectors(sector_count_t sector_number) {
    if (Common::lsectors.empty())
        return true;
    return (Common::lsectors.find(sector_fast(Common::ssectors[sector_number])) != Common::lsectors.end());
}

int positive_index(vector<t_index> v) {
    int res = 0;
    for (unsigned int i = 0; i != v.size(); ++i) {
        if (v[i] == 1)
            res++;
    }
    return res;
}

string int2string(int i) {
    stringstream ss(stringstream::out);
    int curr_ten = pow(10, SECTOR_NAME_LEN - 1);
    while (curr_ten > 1) {
        if (i < curr_ten) {
            ss << 0;
        }
        curr_ten /= 10;
    }
    ss << i;
    return ss.str();
}

void read_from_stream(char **buf, size_t *buf_size, FILE *stream_from_child) {
    char *pos = *buf;
    size_t read = 0;
    size_t rem_size = *buf_size;
    size_t lim = 1;
    lim <<= 30;
    while (true) {
        size_t load_size = rem_size;
        if (load_size > lim) {
            load_size = lim; // fgets accepts int
        }
        pos[load_size - 2] = '\r'; // just to check whether it will be overwritten
        char *temp = fgets(pos, load_size, stream_from_child);
        if (feof(stream_from_child))
            return;
        if (!temp || ferror(stream_from_child)) {
            cout << "Error reading from stream" << endl;
            abort();
        }
        if (pos[load_size - 2] == '\r')
            return; // we did not overwrite the prelast symbol, so we are done with
                    // reading the new line

        // if we are here, this means that the prelast symbol was overwritten
        if (pos[load_size - 2] == '\n')
            return; // '\n' is the last symbol of what we've been sending
        if (pos[load_size - 2] == '\0')
            return; // prelast overwritten with end
        if (read + load_size + lim >= *buf_size) {
            *buf_size = (*buf_size) * 2;
            auto nbuf = static_cast<char *>(realloc(*buf, *buf_size));
            if (nbuf == nullptr) {
                cout << "Cannot realloc in read_from_stream" << endl;
                abort();
            } else
                *buf = nbuf;
        }
        read += (load_size - 1);
        rem_size = (*buf_size) - read;
        pos = (*buf) + read;
    }
}

void store_database(sector_count_t sector_number) {
    string name = int2string(sector_number);
    string suffix = ".copying";
    name += ".tmp";
    if (!Common::silent)
        cout << "Copying file " << name << " " << "to storage" << endl;
    ifstream src(Common::path + name, ios::binary);
    ofstream dst(Common::cpath + name + suffix, ios::binary);
    dst << src.rdbuf();
    src.close();
    dst.close();
    string old_name = Common::cpath + name + suffix;
    string new_name = Common::cpath + name;
    rename(old_name.c_str(), new_name.c_str());
}

bool database_to_file_or_back(sector_count_t number, bool back, bool remove_file) {
    lock_guard<mutex> guard(Common::wrapper_mutex);
    if (!number) {
        if (!back) {
            Common::wrapper_database.tune_alignment(8);
            Common::wrapper_database.tune_buckets(4096);
            if (!Common::wrapper_database.open(Common::path + "wrapper" + ".kch",
                                               kyotocabinet::HashDB::OWRITER | kyotocabinet::HashDB::OCREATE |
                                                   kyotocabinet::HashDB::OTRUNCATE)) {
                cout << "Wrapper open error: " << Common::wrapper_database.error().name() << endl;
                abort();
            }
        } else {
            Common::wrapper_database.close();
        }
        return true;
    }
    if (!back) {
        class VisitorImpl : public kyotocabinet::DB::Visitor {
            // call back function for an existing record
            const char *visit_full([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz, const char *vbuf,
                                   size_t vsiz, [[maybe_unused]] size_t *sp) {
                FILE *fp;
                if ((fp = fopen(write_to.c_str(), "w")) == nullptr) {
                    printf("Cannot open file.\n");
                    abort();
                }
                fwrite(vbuf, 1, vsiz, fp);
                fclose(fp);
                if (remove_file)
                    return REMOVE;
                else
                    return NOP;
            }
            // call back function for an empty record space
            const char *visit_empty([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz,
                                    [[maybe_unused]] size_t *sp) {
                return NOP;
            }

          public:
            bool remove_file;
            string write_to;
        } get_visitor;
        char buf[16];
        //Rely on int2string to put the proper padding on everything
        sprintf(buf,"%s", int2string(number).c_str());
        get_visitor.remove_file = remove_file;
        get_visitor.write_to = Common::path + int2string(number) + "." + "tmp";
        return Common::wrapper_database.accept(buf, SECTOR_NAME_LEN, &get_visitor, remove_file);
    } else {
        string read_from = Common::path + int2string(number) + "." + "tmp";
        struct stat stat_buf;
        int rc = stat(read_from.c_str(), &stat_buf);
        if (rc) {
            cout << "Empty file " << read_from << endl;
            abort();
        }
        int fd = open(read_from.c_str(), O_RDONLY);
        if (fd == -1) {
            printf("Cannot open file\n");
            abort();
        }
        void *addr = mmap(NULL, stat_buf.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
        if (addr == MAP_FAILED) {
            cout << "Cannot mmap " << endl;
            abort();
        }
        string key = int2string(number);
        Common::wrapper_database.set(key.c_str(), SECTOR_NAME_LEN, static_cast<const char *>(addr), stat_buf.st_size);
        munmap(addr, stat_buf.st_size);
        close(fd);
        remove(read_from.c_str());
        return true;
    }
}

void completed_in_storage_read(void) {
    fstream file;
    // Make sure the file is created if it doesn't exist
    file.open(Common::cpath + Common::completed_in_storage_fname, fstream::app);
    file.close();
    file.open(Common::cpath + Common::completed_in_storage_fname, fstream::in);
    if ( ! file.is_open() ) {
        cout << "Could not open file: " << Common::cpath + Common::completed_in_storage_fname << endl;
        abort();
    }

    pair<int, int> in;
    while (file >> in.first >> in.second) {
        Common::completed_in_storage.push_back(in);
    }

    file.close();
}

void completed_in_storage_update(void) {
    fstream file;
    file.open(Common::cpath + '/' + Common::completed_in_storage_fname, fstream::out);
    if ( ! file.is_open() ) {
        cout << "Could not open file: " << Common::cpath + '/' + Common::completed_in_storage_fname << endl;
        abort();
    }

    for (auto i : Common::completed_in_storage) {
        file << i.first << " " << i.second << endl;
    }

    file.close();
}

#ifdef PRIME
unsigned long long string_fraction_to_modular(string &s) {
    mp_limb_t num, denom;
    const char *posc = s.c_str();
    if (*posc == '(')
        ++posc;
    bool negative = false;
    if (*posc == '-') {
        negative = true;
        ++posc;
    }
    sscanf(posc, "%lu", &num);
    num = num % Common::prime;
    // to be safe, but it should not be greater;
    if (negative) {
        num = nmod_neg(num, Common::flint_mod);
    }
    unsigned long pos = s.find('/');
    if (pos != string::npos) {
        ++pos;
        if (s[pos] == '(')
            ++pos;
        negative = false;
        if (s[pos] == '-') {
            negative = true;
            ++pos;
        }
        sscanf(s.c_str() + pos, "%lu", &denom);
        denom = denom % Common::prime;
        // to be safe, but it should not be greater;
        if (negative) {
            denom = nmod_neg(denom, Common::flint_mod);
        }
        num = nmod_div(num, denom, Common::flint_mod);
    }
    return num;
}
#endif

string replace_all_variables(string str, size_t index) {
    for (auto itr = Common::variable_replacements.rbegin(); itr != Common::variable_replacements.rend(); ++itr) {
        str = replace_all(str, itr->first, "(" + itr->second[index] + ")");
    }
    return str;
}

int smallest_bucket(size_t entries) {
    int result = 2;
    while (entries) {
        ++result;
        entries >>= 1;
    }
    if (result < 5)
        result = 5;
    return result;
}

pair<size_t, size_t> scan_snapshot(sector_count_t number, std::function<bool(const char *, size_t)> condition,
                                   std::function<void(const char *, size_t, const char *, size_t)> action) {
    char kbuf[8192];
    char vbuf[8192];

    std::ifstream ifs;
    ifs.open((Common::path + int2string(number) + ".tmp").c_str(), std::ios_base::in | std::ios_base::binary);
    if (!ifs) {
        cout << "Cannot open snapshot file for reading" << endl;
        abort();
    }
    auto src = &ifs;
    src->read(kbuf, sizeof(KCDBSSMAGICDATA));
    if (src->fail()) {
        cout << "Stream input error at read start" << endl;
        abort();
    }
    if (std::memcmp(kbuf, KCDBSSMAGICDATA, sizeof(KCDBSSMAGICDATA))) {
        cout << "Invalid magic data of input stream" << endl;
        abort();
    }
    size_t curcnt = 0;
    size_t satisf = 0;
    while (true) {
        int32_t c = src->get();
        if (src->eof())
            break;
        if (src->fail()) {
            cout << "Stream input error" << endl;
            abort();
        }
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
            src->read(kbuf, ksiz);
            if (src->fail()) {
                cout << "Stream input error" << endl;
                abort();
            }
            if (condition(kbuf, ksiz)) {
                ++satisf;
                char *rbuf = vsiz > sizeof(vbuf) ? new char[(vsiz / 16 + (vsiz % 16 ? 1 : 0)) * 16] : vbuf;
                src->read(rbuf, vsiz);
                if (src->fail()) {
                    cout << "Stream input error" << endl;
                    if (rbuf != vbuf)
                        delete[] rbuf;
                    abort();
                }
                action(kbuf, ksiz, rbuf, vsiz); // we apply the function to all entries
                if (rbuf != vbuf)
                    delete[] rbuf;
            } else {
                src->ignore(vsiz);
            }
        } else {
            cout << "Invalid magic data of input stream" << endl;
            abort();
        }
        curcnt++;
    }
    ifs.close();
    if (ifs.bad()) {
        cout << "Cannot close snapshot file after reading" << endl;
        abort();
    }
    return make_pair(curcnt, satisf);
}
