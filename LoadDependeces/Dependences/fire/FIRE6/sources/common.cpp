/** @file common.cpp
 *  @author Alexander Smirnov
*
*  This file is a part of the FIRE package.
*  It contains the initializations of static variables in the common class
*  and a number of general functions used in other parts of the program.
*/


#include "common.h"
#include <sys/stat.h>
#include <sys/mman.h>
/* initializations of static variables
* refer to common.h for details
*/

kyotocabinet::HashDB common::wrapper_database;

thread common::socket_listen;

vector<string> common::fuelOptions;
string common::fuelOptionsString;
unsigned short common::dimension;
unique_ptr<sector_count_t[]> common::sector_numbers_fast;
unique_ptr<unique_ptr<t_index[]>[]> common::orderings_fast;

string common::dep_file{};

int common::pos_pref = 1;

bool common::silent = false;

bool common::ftool = false;

bool common::disable_presolve = false;

bool common::hint;
string common::hint_path;

t_compressor common::compressor = t_compressor::C_LZ4;
int common::compressor_level{};
unique_ptr<kyotocabinet::Compressor> common::compressor_class;

uint64_t common::prime = 0; // the prime number for fast evaluations
unsigned short common::prime_number(-1); //by default no prime is selected


map<string, string> common::variable_replacements; // while parsing

bool common::nolock = false;
bool common::all_ibps = false;

int common::print_step = 0;

bool common::split_masters = false;
unsigned int common::master_number_min = 0;
unsigned int common::master_number_max = 0;

bool common::variables_set_from_command_line = false;

SECTOR common::virtual_sector = 0;

bool common::parallel_mode = false;

string common::path = "";
string common::cpath;

bool common::cpath_on_substitutions = false;
int common::buckets[MAX_SECTORS + 1];
int64_t common::buckets_full[MAX_SECTORS + 1];

string common::tables_prefix = "";
vector<unsigned short> common::var_values_from_arv = {};


bool common::only_masters = false;
bool common::keep_all = false;

// pipes for expression communication
FILE *common::child_stream_from_child = nullptr;
FILE *common::child_stream_to_child = nullptr;
bool common::receive_from_child = false;
bool common::send_to_parent = false;

bool common::clean_databases = false;

bool common::remote_worker = false;

sector_count_t common::abs_max_sector = 3;

int common::abs_max_level = 0;

int common::abs_min_level = 100;
#ifdef DISK_DB
    kyotocabinet::HashDB *common::points[MAX_SECTORS + 1];
#else
    kyotocabinet::CacheDB *common::points[MAX_SECTORS + 1];
#endif

atomic<long long> common::fuel_time{};
atomic<long long> common::thread_time{};

int common::msiz = 26;

unsigned int common::global_pn = 0;
unsigned int common::threads_number = 0;
unsigned int common::lthreads_number = 1;
unsigned int common::sthreads_number = 0;
unsigned int common::fthreads_number = 0;
unsigned int common::f_queues = 1;


vector<vector<vector<t_index> > > common::iorderings;
vector<vector<vector<t_index> > > common::symmetries;

vector<vector<t_index> > common::ssectors;
set<SECTOR> common::lsectors;

common_lbases_t common::lbases;
//      sector    condition+result        coefficients  free term   eq                 coeff     indices:   coefficients and free term

// database wrapper things
mutex common::wrapper_mutex;
bool common::wrap_databases;

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
    return make_pair(p,m);
}


// output routines for vectors and double vectors
void print_vector(const vector<t_index> &v) {
    if (common::silent) return;
    auto it = v.begin();
    cout << "{" << int(*it);
    for (it++; it != v.end(); it++) {
        cout << "," << int(*it);
    }
    cout << "}";
}

// output routines for vectors and double vectors
void print_sector_fast(const SECTOR &sf) {
    if (common::silent) return;
    SECTOR i = 1;
    i <<= (common::dimension -1);
    cout << "{" << (i&sf ? 1 : -1);
    for (i>>=1; i; i>>=1) {
        cout << "," << (i&sf ? 1 : -1);
    }
    cout << "}";
}


void Orbit(const vector<t_index> &v, vector<vector<t_index> > &orbit, vector<vector<vector<t_index> > > &sym) {
    for (const auto &values : sym) {
        if (values.size() == 4) {
            const vector<t_index> &restrictions = values[2];
            for (unsigned int i = 0; i != v.size(); ++i) {
                if ((restrictions[i] == 1) && (v[i] <= 0)) continue;
                if ((restrictions[i] == -1) && (v[i] > 0)) continue;
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
        if (to_add) orbit.push_back(result);
    }
}

void make_ordering(t_index *mat, const vector<t_index> &sector) {
    vector<vector<t_index> > result;
    result.reserve(sector.size());
    vector<t_index> neg;
    vector<t_index> one_vector;
    vector<t_index> zero_vector;
    zero_vector.reserve(sector.size());

    bool all_plus = true;
    bool all_minus = true;
    for (const t_index i : sector) {
        if (i != 1) all_plus = false;
        if (i != -1) all_minus = false;
    }

    auto l_pos = static_cast<unsigned int>(-1);
    auto l_neg = static_cast<unsigned int>(-1);

    for (unsigned int i = 0; i < sector.size(); ++i) {
        one_vector.push_back(1);
        zero_vector.push_back(0);
        if (sector[i] == 1) {
            l_pos = i;
            neg.push_back(0);
        } else {
            l_neg = i;
            neg.push_back(1);
        }
    }

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
        if (l_pos == static_cast<unsigned int>(-1) || l_neg == static_cast<unsigned int>(-1)) {
            cout << "Something wrong with make_ordering!" << endl;
            abort();
        }
        result.push_back(one_vector);
        result.push_back(neg);
        for (unsigned int i = 0; i < sector.size() - 1; ++i) {
            if (sector[i] == 1) {
                if (i != l_pos) {
                    vector<t_index> v = zero_vector;
                    v[i] = 1;
                    result.push_back(v);
                }
            } else {
                if (i != l_neg) {
                    neg[i] = 0;
                    result.push_back(neg);
                }
            }
        }
    }

    int row = 0;
    for (auto itr_row = result.begin(); itr_row != result.end(); ++itr_row, ++row) {
        // now we stopped using vectors, moving to arrays, it's much faster
        // and array of vectors leads to crashes
        int column = 0;
        for (auto itr_column = itr_row->begin(); itr_column != itr_row->end(); ++itr_column, ++column) {
            mat[row * common::dimension + column] = *itr_column;
        }
    }
}


vector<vector<t_index> > all_sectors(unsigned int d, int positive, int positive_start) {
    vector<t_index> vv3;
    for (unsigned int i = 0; i != d; ++i) vv3.push_back(-1);
    vector<vector<t_index> > vv;
    vv.push_back(vv3);
    for (int i = positive_start - 1; i < positive; ++i) {
        vector<vector<t_index> > ww = vv;
        vv.reserve(2 * vv.size());
        for (auto &current : ww) {
            current[i] = 1;
            vv.push_back(current);
        };
    };
    return (vv);
};


void clear_database(sector_count_t number) {
    if (number != 0) {
        remove((common::path + int2string(number) + ".kch").c_str());
    } else {
        remove((common::path + int2string(number) + ".kct").c_str());
    }
}

bool database_exists(sector_count_t number) {
    if (common::wrap_databases) {
        lock_guard<mutex> guard(common::wrapper_mutex);
        string key = int2string(number);
	cout<<"Checking existence of database:"<<number<<"|"<<key<<"->"<<common::wrapper_database.check(key)<<endl;
        return (common::wrapper_database.check(key) != -1);
    }
    string name = common::path + int2string(number);
    #ifdef DISK_DB
        name += ".kch";
    #else
        name += ".tmp";
    #endif
    bool result = (access(name.c_str(), F_OK) != -1);
    return result;
}

void open_database(sector_count_t number) {
    common::buckets_full[number] = (1ll << common::buckets[number]);

    #ifdef DISK_DB
        common::points[number] = new kyotocabinet::HashDB;
    #else
        common::points[number] = new kyotocabinet::CacheDB;
    #endif

    auto pdb = common::points[number];
    pdb->tune_buckets(common::buckets_full[number]);

    #ifdef DISK_DB
        pdb->tune_buckets(common::buckets_full[number]);
        pdb->tune_defrag(1);
        pdb->tune_fbp(10);
        pdb->tune_alignment(8);
        pdb->tune_map(1ll << common::msiz);
    #else
        common::buckets_full[number] <<= 1; //we need less buckets for memory_db
    #endif

    if (common::compressor != t_compressor::C_NONE) {
        pdb->tune_options(kyotocabinet::CacheDB::TLINEAR | kyotocabinet::CacheDB::TCOMPRESS);
        pdb->tune_compressor(common::compressor_class.get());
    }

    #ifndef DISK_DB
        if (!pdb->open("*")) {
            cout << "Error opening database, exiting" << endl;
            abort();
        }
        pdb->load_snapshot(common::path + int2string(number) + ".tmp");
    #else
        uint32_t flags = kyotocabinet::HashDB::OWRITER | kyotocabinet::HashDB::OCREATE;
        if (common::nolock) flags |= kyotocabinet::HashDB::ONOLOCK;

        if (!pdb->open(common::path + int2string(number) + ".kch", flags)) {
            cout << "Error opening database (" << pdb->error().message() << "), exiting" << endl;
            abort();
        }
    #endif

    int64_t entries = pdb->count();
    if (2 * entries > common::buckets_full[number]) {
        while (2 * entries > common::buckets_full[number]) {
            common::buckets[number]++;
            common::buckets_full[number] *= 2;
        }
        reopen_database(number);
    }
}


void file_not_needed(string path) {
    int fd;
    fd = open(path.c_str(), O_RDONLY);
    if (fd == -1) {
        cout << "File open error: "<< path;
        abort();
    }
#ifdef F_FULLFSYNC
    // OS X
    fcntl(fd, F_FULLFSYNC);
#else
    fdatasync(fd);
#endif

#ifndef POSIX_FADV_DONTNEED
    fcntl(fd, F_NOCACHE, 1);
#else
    // the preferred old way
    posix_fadvise64(fd, 0, 0, POSIX_FADV_DONTNEED);
#endif
    close(fd);
}


void reopen_database(sector_count_t number) {
    if (!common::silent) {
        cout << "Reopening database " << number << " with bucket=" << common::buckets[number] << endl;
    }
    string path = common::path + int2string(number) + ".tmp";

    #ifdef DISK_DB
        common::points[number]->dump_snapshot(path);
        close_database(number);
        clear_database(number);
        open_database(number);
        common::points[number]->load_snapshot(path);
    #else
        close_database(number);
        open_database(number);
    #endif
    file_not_needed(path);
}

void close_database(sector_count_t number) {
    #ifndef DISK_DB
        common::points[number]->dump_snapshot(common::path + int2string(number) + ".tmp");
        file_not_needed(common::path + int2string(number) + ".tmp");
    #endif
    common::points[number]->close();
    delete common::points[number];
    #ifdef DISK_DB
        file_not_needed(common::path + int2string(number) + ".kch");
    #endif
}


bool in_lsectors(sector_count_t test_sector) {
    if (common::lsectors.empty()) return true;
    return (common::lsectors.find(sector_fast(common::ssectors[test_sector]))!= common::lsectors.end());
}



int positive_index(vector<t_index> v) {
    int res = 0;
    for (unsigned int i = 0; i != v.size(); ++i) {
        if (v[i] == 1) res++;
    }
    return res;
}

//static constexpr sector_count_t MAX_TEN = pow(10,SECTOR_NAME_LEN-1);
string int2string(int i) {
  stringstream ss(stringstream::out);
  int curr_ten = pow(10,SECTOR_NAME_LEN-1);
  while (curr_ten>1){
    if (i < curr_ten) ss << 0;
    curr_ten /= 10;
  }
  ss << i;
  return ss.str();
}


void read_from_stream(char **buf, int *buf_size, FILE *stream_from_child) {
    char *pos = *buf;
    int read = 0;
    int rem_size = *buf_size;
    while (true) {
        pos[rem_size - 2] = '\r'; // just to check whether it will be overwritten
        char * temp = fgets(pos, rem_size, stream_from_child);
        if (feof(stream_from_child)) return;
        if (!temp || ferror(stream_from_child)) {
            cout << "Error reading from stream" << endl;
            abort();
        }
        if (pos[rem_size - 2] == '\r')
            return; // we did not overwrite the prelast symbol, so we are done with reading the new line

        // if we are here, this means that the prelast symbol was overwritten
        if (pos[rem_size - 2] == '\n') return; // '\n' is the last symbol of what we've been sending
        if (pos[rem_size - 2] == '\0') return; // prelast overwritten with end
        *buf_size = (*buf_size) * 2;
        auto nbuf = static_cast<char *>(realloc(*buf, static_cast<size_t>(*buf_size)));
        if (nbuf == nullptr) {
            cout << "Cannot realloc in read_from_stream"<<endl;
            abort();
        } else *buf = nbuf;
        read += (rem_size - 1);
        rem_size = (*buf_size) - read;
        pos = (*buf) + read;
    }
}


void copy_database(sector_count_t number, bool from_storage) {
    string name = int2string(number);
    string suffix = ".copying";
    #ifdef DISK_DB
        name += ".kch";
    #else
        name += ".tmp";
    #endif
    if (!common::silent) cout << "Copying file " << name << " " << (from_storage ? "from" : "to") << " storage" << endl;
    ifstream src((from_storage ? common::cpath : common::path) + name, ios::binary);
    ofstream dst((from_storage ? common::path : common::cpath) + name + suffix, ios::binary);
    dst << src.rdbuf();
    src.close();
    dst.close();
    string old_name = (from_storage ? common::path : common::cpath) + name + suffix;
    string new_name = (from_storage ? common::path : common::cpath) + name;
    remove(new_name.c_str());
    rename(old_name.c_str(), new_name.c_str());
    file_not_needed(common::path + name);
    file_not_needed(common::cpath + name);
}

bool database_to_file_or_back(sector_count_t number, bool back, bool remove_file) {
    lock_guard<mutex> guard(common::wrapper_mutex);
    if (!number) {
        if (!back) {
            common::wrapper_database.tune_alignment(8);
            common::wrapper_database.tune_buckets(4096);
            uint32_t flags = kyotocabinet::HashDB::OWRITER | kyotocabinet::HashDB::OCREATE | kyotocabinet::HashDB::OTRUNCATE;
            if (common::nolock) flags |= kyotocabinet::HashDB::ONOLOCK;
            if (!common::wrapper_database.open(common::path + "wrapper" + ".kch", flags)) {
                cerr << "Wrapper open error: " << common::wrapper_database.error().name() << endl;
                abort();
            }
        } else {
            common::wrapper_database.close();
        }
        return true;
    }
    if (!back) {
        class VisitorImpl : public kyotocabinet::DB::Visitor {
            // call back function for an existing record
            const char* visit_full(const char* kbuf, size_t ksiz, const char* vbuf, size_t vsiz, size_t *sp) {
                FILE* fp;
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
            const char* visit_empty(const char* kbuf, size_t ksiz, size_t *sp) {
                return NOP;
            }
            public:
                bool remove_file;
                string write_to;
        } get_visitor;
        char buf[16];
        //sprintf(buf, "%04d", number);
	//Rely on int2string to put the proper padding on everything
	sprintf(buf,"%s", int2string(number).c_str());
        get_visitor.remove_file = remove_file;
#ifdef DISK_DB
        get_visitor.write_to = common::path + int2string(number) + ".kch";
#else
        get_visitor.write_to = common::path + int2string(number) + ".tmp";
#endif
        return common::wrapper_database.accept(buf, SECTOR_NAME_LEN, &get_visitor, remove_file);
    } else {
#ifdef DISK_DB
        string read_from = common::path + int2string(number) + ".kch";
#else
        string read_from = common::path + int2string(number) + ".tmp";
#endif
        struct stat stat_buf;
        int rc = stat(read_from.c_str(), &stat_buf);
        if (rc) {
            cout << "Empty file "<< read_from <<endl;
            abort();
        }
        int fd = open(read_from.c_str(), O_RDONLY);
        if (fd == -1) {
            printf("Cannot open file\n");
            abort();
        }
        void *addr = mmap(NULL, stat_buf.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
        if (addr == MAP_FAILED) {
            cout << "Cannot mmap " <<endl;
            abort();
        }
        string key = int2string(number);
        common::wrapper_database.set(key.c_str(), SECTOR_NAME_LEN, static_cast<const char*>(addr), stat_buf.st_size);
        munmap(addr, stat_buf.st_size);
        close(fd);
        remove(read_from.c_str());
        return true;
    }
}


int128_t mul_inv(int128_t a, int128_t b) {
    int128_t b0 = b, t, q;
    int128_t x0 = 0, x1 = 1;
    if (b == 1) {
        return 1;
    }
    while (a > 1) {
        q = a / b;
        t = b, b = a % b, a = t;
        t = x0, x0 = x1 - q * x0, x1 = t;
    }
    if (x1 < 0) x1 += b0;
    return x1;
}

unsigned long long mod(string &s, bool positive_number_in_range) {
    uint128_t num, denum;
    int128_t temp128;
    long long int temp;
    unsigned long long int utemp;
    if (positive_number_in_range) {
        sscanf(s.c_str(), "%llu", &utemp);
        num = utemp;
    } else {
        sscanf(s.c_str(), "%lld", &temp); // there should be no overflow here, just reading
        temp128 = temp;
        temp128 = temp128 % (int128_t(common::prime));
        if (temp128 < 0) {
            temp128 += (int128_t(common::prime));
        }
        num = temp128;
    }

    unsigned long pos = s.find('/');
    if (pos != string::npos) {
        if (positive_number_in_range) {
            sscanf(s.c_str() + pos + 1, "%llu", &utemp);
            denum = utemp;
        } else {
            sscanf(s.c_str() + pos + 1, "%lld", &temp);
            if (temp < 0) {
                cout << "Bad denominator: " << s << endl;
                abort();
                // this cannot happen. we are reading a small number and the denominator cannot be big or negative
            }
            temp128 = temp;
            temp128 = temp128 % int128_t(common::prime);
            denum = temp128;
        }

        denum = mul_inv(denum, common::prime);
        num *= denum;
        num %= common::prime;
    }
    return num;
}

string ReplaceAll(string str, const string &from, const string &to) {
    size_t start_pos = 0;
    while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length(); // Handles case where 'to' is a substring of 'from'
    }
    return str;
}

string ReplaceAllVariables(string str) {
    for (const auto &variable_replacement : common::variable_replacements) {
        str = ReplaceAll(str, variable_replacement.first, "(" + variable_replacement.second + ")");
    }
    return str;
}
