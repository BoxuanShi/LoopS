/** @file ftool.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package.
 *  This main is used to compile FTool binaries.
 *
 *  The FTool binaries are used to print relations from an existing database.
 *  The arguments of binaries are same as for FIRE.
 */
#include "functions.h"
#include "handler.h"
#include "parser.h"

string Common::FIRE_folder;
string Common::config_file;

/**
 * Entry Point for FTool binaries. Used for printing all entries in a database.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return successfullness
 */
int main(int argc, char *argv[]) {
#ifdef WITH_DEBUG
    attach_handler();
#endif
    sector_count_t sector;
    string output;

    set<Point, std::greater<Point>> points;
    if ((argc == 2) && !strcmp(argv[1], "-test")) {
        printf("Ok\n");
        return 0;
    }

    char current[PATH_MAX];
    if (!getcwd(current, PATH_MAX)) {
        cout << "Can't get current dir name" << endl;
        return 1;
    }
    string scurrent = string(current);
    string srun = string(argv[0]);

#ifdef PRIME
#ifdef MPRIME
    srun = srun.substr(0, srun.length() - 8);
#else
    srun = srun.substr(0, srun.length() - 7);
#endif
#else
    srun = srun.substr(0, srun.length() - 6);
#endif

    if (srun[0] == '/') { // running with full path
        Common::FIRE_folder = srun;
    } else { // relative path, using current dir
        Common::FIRE_folder = scurrent + "/" + srun;
    }

    pair<int, sector_count_t> temp = parse_argc_argv(argc, argv, false);
    sector = temp.second;

    if (sector <= 0) {
        cout << "Wrong sector" << endl;
        return -1;
    }
    Common::ftool = true;
    if (parse_config(Common::config_file + ".config", points, output, sector, true)) {
        return -1;
    }

    if (Common::stages != t_stages::backward) {

        if (Common::inputSpecifiedArgument != "") {
            load_integrals(Common::inputSpecifiedArgument, points);
        }
        // writing database contents to stdout

        cout << "{" << endl;
        Point::print_g = true;
        scan_snapshot(
            sector,
            [&points](const char *kbuf, size_t ksiz) -> bool {
                if (ksiz != sizeof(Point))
                    return false;
                if (Common::inputSpecifiedArgument == "")
                    return true; // no special restriction on filter
                return (points.find(*reinterpret_cast<const Point *>(kbuf)) != points.end());
            },
            [](const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz) -> void {
                if (ksiz < sizeof(Point)) {
                    return;
                }
                const Point test = *reinterpret_cast<const Point *>(kbuf);
                cout << test << " -> ";

                list<Point> monoms;
#ifdef PRIME
#ifdef MPRIME
                unsigned int len = vsiz / (sizeof(Point) + MPRIME * sizeof(long long int));
#else
                unsigned int len = vsiz / (sizeof(Point) + sizeof(long long int));
#endif
#else
                unsigned int len = (*reinterpret_cast<const unsigned int *>(vbuf + vsiz - 4) & ~NEEDED_BIT);
#endif
                for (unsigned int i = 0; i != len; ++i) {
                    monoms.push_back((reinterpret_cast<const Point *>(vbuf))[i]);
                }
                const char *buf = vbuf + (len * sizeof(Point));
                list<string> coeffs;
                string s = buf;
                size_t pos = 0;
                for (unsigned int i = 0; i != len; ++i) {
                    string coeff;
#ifdef PRIME
                    char buff[16];
                    snprintf(buff, sizeof(buff), "%llu", *reinterpret_cast<const unsigned long long *>(buf + pos));
                    coeff = string(buff);
#ifdef MPRIME
                    // currently FTool is picking first values from multitables
                    pos += MPRIME * sizeof(unsigned long long);
#else
                    pos += sizeof(unsigned long long);
#endif
#else
                    size_t next = s.find('|', pos);
                    coeff = s.substr(pos, next - pos);
                    pos = next + 1;
#endif
                    if (coeff[0] == '[') {
                        coeff[0] = '(';
                        coeff[coeff.size() - 1] = ')';
                        size_t pos_comma = coeff.find(',');
                        if (pos_comma != string::npos) {
                            coeff = coeff.replace(pos_comma, 1, ")/(");
                        }
                    }
                    coeffs.push_back(coeff);
                }
                if (len > 0) {
                    if (test != monoms.back()) {
                        cout << "error in database rules " << endl;
                        abort();
                    }
                    monoms.pop_back();
                    string c = coeffs.back();
                    coeffs.pop_back();
                    for (unsigned int i = 0; i + 1 != len; ++i) {
                        if (!Common::only_masters) {
                            cout << "(" << coeffs.front() << ")/(-(" << c << ")) ";
                        }
                        cout << monoms.front();
                        monoms.pop_front();
                        coeffs.pop_front();
                        if (i + 2 != len) {
                            cout << " + ";
                        }
                    }
                } else {
                    cout << test;
                }
                cout << "," << endl;
                return;
            });
        cout << "{}}" << endl;

    } else {
        open_database(sector);
        // loading database contents from stdin
        constexpr size_t LOAD_STR_SIZE = {1024}; ///< size of the string loaded from files
        char load_string[LOAD_STR_SIZE] = "none";
        string str;
        while (fgets(load_string, sizeof(load_string), stdin)) {
            str += load_string;
        }
        for (auto &symb : str) {
            if ((symb == '\r') || (symb == '\n') || (symb == '\\')) {
                symb = ' ';
            }
        }
        const char *it = str.c_str();
        int move;
        unsigned int n;
        vector<int64_t> res;
        vector<t_index> res_small;
        while (*it == ' ')
            it++;
        if (*it != '{') {
            cout << "wrong start (should be a list)" << endl;
            abort();
        }
        it++;
        while (*it == ' ')
            it++;

        while (true) {
            // cout << "relation" << endl;
            if (*it == ',') {
                // comma from previous relation
                it++;
                while (*it == ' ')
                    it++;
            }
            if (*it == '}') {
                it++;
                break;
            }

            // started reading relation

            if (*it != 'G') {
                cout << "wrong relation start (should be G)" << endl;
                abort();
            }
            it++;
            if (*it != '[') {
                cout << "wrong integral start (should be [)" << endl;
                abort();
            }
            it++;
            move = s2u(it, n);
            it += move;
            if (n != Common::global_pn) {
                cout << "Problem number on integral lhs does not coincide with global" << endl;
                abort();
            }
            while (*it == ' ')
                it++;
            if (*it != ',') {
                cout << "wrong integral middle (should be ,)" << endl;
                abort();
            }
            it++;
            move = parse_vector(it, res);
            it += move;
            Point left;
            if (res.size() > 2) {
                res_small.clear();
                for (auto val : res)
                    res_small.push_back(val);
                // real point
                left = Point(res_small);
            } else {
                // virtual Point in a numbered sector
                vector<t_index> empty;
                // second read number is virtual number, int64_t; first is sector number
                SECTOR s;
                if (res[0] == 1) {
                    s = static_cast<SECTOR>(-2);
                    // this is the SECTOR notation for virtual 1 sector, but it should not
                    // be in the left-hand side
                    cout << "We should not have mappings for virtual 1 sector on lhs " << endl;
                    abort();
                } else {
                    vector<t_index> sector = Common::ssectors[res[0]];
                    s = sector_fast(sector);
                }
                left = Point(empty, res[1], s);
            }
            // cout << left << endl;
            while (*it == ' ')
                it++;
            if (*it != ']') {
                cout << "wrong lhs end (should be ])" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it != '-') {
                cout << "wrong relation (should be ->)" << endl;
                abort();
            }
            it++;
            if (*it != '>') {
                cout << "wrong relation (should be ->)" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            if (*it != '{') {
                cout << "wrong rhs (should start from {)" << endl;
                abort();
            }
            it++;
            while (*it == ' ')
                it++;
            vector<pair<Point, COEFF>> rhs;
            while (true) {
                // a cycle to read list of pairs in rhs
                if (*it == '}') {
                    // rhs end
                    it++;
                    break;
                }
                if (*it == ',') {
                    // that's a comma after a pair in rhs
                    it++;
                    while (*it == ' ')
                        it++;
                }
                if (*it != '{') {
                    cout << "wrong rhs part (should start from {)" << endl;
                    abort();
                }
                it++;
                size_t pos = str.find(',', it - str.c_str());
                if (pos == string::npos) {
                    cout << "wrong relation, does not have , after coefficient" << endl;
                    abort();
                }
                pos -= (it - str.c_str());
                string coeff = string(it, pos);
                // cout << coeff << endl;
                COEFF c;
#ifdef PRIME
#ifdef MPRIME
                const char *poss = coeff.c_str();
                for (size_t i = 0; i != MPRIME; ++i) {
                    sscanf(poss, "%llu", &c.N[i]);
                    if (i != MPRIME - 1) {
                        while (*poss != '|') {
                            ++poss;
                        }
                        ++poss;
                    }
                }
#else
                sscanf(coeff.c_str(), "%llu", &c.n);
#endif
#else
                c.s = coeff;
#endif
                it += pos;
                it++;
                while (*it == ' ')
                    it++;
                if (*it != 'G') {
                    cout << "wrong rhs integral start (should be G)" << endl;
                    abort();
                }
                it++;
                if (*it != '[') {
                    cout << "wrong rhs integral start (should be G[)" << endl;
                    abort();
                }
                it++;
                move = s2u(it, n);
                it += move;
                if (n != Common::global_pn) {
                    cout << "Problem number on integral rhs does not coincide with global" << endl;
                    abort();
                }
                while (*it == ' ')
                    it++;
                if (*it != ',') {
                    cout << "wrong integral rhs middle (should be ,)" << endl;
                    abort();
                }
                it++;
                move = parse_vector(it, res);
                it += move;
                Point right;
                if (res.size() > 2) {
                    res_small.clear();
                    for (auto val : res)
                        res_small.push_back(val);
                    // real point
                    right = Point(res_small);
                } else {
                    // virtual Point in a numbered sector
                    vector<t_index> empty;
                    // second read number is virtual number, int64_t; first is sector
                    // number
                    SECTOR s;
                    if (res[0] == 1) {
                        s = static_cast<SECTOR>(-2);
                        // this is the SECTOR notation for virtual 1 sector
                    } else {
                        vector<t_index> sector = Common::ssectors[res[0]];
                        s = sector_fast(sector);
                    }
                    right = Point(empty, res[1], s);
                }
                // cout << right << endl;
                while (*it == ' ')
                    it++;
                if (*it != ']') {
                    cout << "wrong rhs integral end (should be ])" << endl;
                    abort();
                }
                it++;
                while (*it == ' ')
                    it++;
                if (*it != '}') {
                    cout << "wrong rhs pair end (should be })" << endl;
                    abort();
                }
                it++;
                while (*it == ' ')
                    it++;
                rhs.emplace_back(right, c);
            }
            // we have a relation, time to put in into the database
            sort(rhs.begin(), rhs.end(), pair_point_coeff_smaller);
            COEFF minus_one;
#ifdef PRIME
#ifdef MPRIME
            for (size_t i = 0; i != MPRIME; ++i) {
                minus_one.N[i] = Common::prime - 1;
            }
#else
            minus_one.n = Common::prime - 1;
#endif
#else
            minus_one.s = "-1";
#endif
            if (rhs.size() == 1 && rhs[0].first == left) {
                rhs.clear();
            } else {
                rhs.emplace_back(left, minus_one);
            }
            p_set(left, rhs, !left.IsVirtual());

            while (*it == ' ')
                it++;
        }

        close_database(sector, true); // updating the database
    }

    fuel::close();
    for (unsigned int i = 0; i != Common::f_queues; ++i) {
        {
            std::lock_guard<std::mutex> lck(Equation::f_submit_mutex[i]);
            Equation::f_stop = true;
        }
        Equation::f_submit_cond[i].notify_all();
    }
    for (unsigned int i = 0; i != Common::fthreads_number; ++i) {
        Equation::f_threads[i].join();
    }

    return 0;
}
