/**
 * @file main.cpp
 * @author Alexander Smirnov
 *
 * This file is a part of the FIRE package.
 */

#include <arpa/inet.h>
#include <array>
#include <cstdio>
#include <cstring>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>

#include "common.h"
#include "functions.h"
#include "handler.h"
#include "parser.h"

// routines to save and load temporary tables
/**
 * Temporary tables.
 */
map<Point, vector<pair<Point, COEFF>>> temp;

/**
 * Set terms for specific Point in temporary tables.
 * @param p Point for which we are adding terms to temporary tables.
 * @param terms terms which we are writing in temporary tables.
 */
void p_set_temp(const Point &p, const vector<pair<Point, COEFF>> &terms) {
    temp.emplace(p, terms);
}

/**
 * Get terms for Point from temporary tables.
 * @param p Point for which we are searching terms.
 * @param terms result vector where we'll place found terms, if there're any.
 */
void p_get_temp(const Point &p, vector<pair<Point, COEFF>> &terms) {
    auto itr = temp.find(p);
    if (itr == temp.end()) {
        terms.clear();
    } else {
        terms = itr->second;
    }
}

string Common::FIRE_folder;
string Common::config_file;

/**
 * Run a system command and get output
 * @param cmd the command
 * @return joined resulting output
 */
std::string exec_command(const char *cmd) {
    std::array<char, 128> buffer;
    std::string result;
    struct PipeCloser {
        void operator()(FILE *f) const { pclose(f); }
    };
    std::unique_ptr<FILE, PipeCloser> pipe(popen(cmd, "r"));
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    return result;
}

/**
 * Closed worker threads for parallel libraries
 */
void close_worker_threads() {
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
}

#ifdef PRIME
void save_relations(
        fstream& out,
        const set<Point,
        std::greater<Point>> &points,
        const vector<list<pair<Point, COEFF>>> &substituted_combinations
    ) {
#else
/**
 * Save relations to stream
 * @param out the stream
 * @param points the points to be saved
 * @param substituted_combinations combinations of points that were substituted
 */
void save_relations(
        fstream& out,
        const set<Point,
        std::greater<Point>> &points,
        const vector<vector<pair<Point, COEFF>>> &substituted_combinations
    ) {
#endif

    size_t comb_count = 1;

    out << "    {" << endl;
    bool first_combination = true;
    for (auto &combination : substituted_combinations) {
        if (!first_combination) {
            out << "," << std::endl;
        }
        first_combination = false;
        out << "        {" << "combination[" << comb_count << "]" << "," << endl;
        ++comb_count;
        out << "            {" << endl;
        bool first = true;
        for (auto &term : combination) {
            if (!first) {
                out << "," << std::endl;
            }
            first = false;
            out << "                {" << term.first.Number() << "," << "\"" << term.second << "\"}";
        }
        out << endl;
        out << "            }" << endl;
        out << "        }";
    }
    if (!first_combination) {
        if (!points.empty())
            out << ",";
        out << std::endl;
    }

    for (auto itr = points.begin(); itr != points.end(); ++itr) {
        out << "        {" << itr->Number() << "," << endl;
        out << "            {" << endl;
        vector<pair<Point, COEFF>> terms;
        p_get_temp(*itr, terms);
        if (terms.empty()) {
            out << "{" << itr->Number() << ",\"1";
#ifdef MPRIME
            for (size_t i = 1; i != MPRIME; ++i) {
                out << "|1";
            }
#endif
            out << "\"}}}";
        } else {
            for (unsigned int i = 0; i != terms.size() - 1; ++i) {
                out << "                {" << terms[i].first.Number() << "," << "\"";
#ifdef PRIME
                mp_limb_t num, denum;
#ifdef MPRIME
                for (size_t j = 0; j != MPRIME; ++j) {
                    num = terms[i].second.N[j];
                    denum = terms.back().second.N[j];
                    num = nmod_neg(num, Common::flint_mod);
                    num = nmod_div(num, denum, Common::flint_mod);
                    out << num;
                    if (j != MPRIME - 1) {
                        out << "|";
                    }
                }
#else
                num = terms[i].second.n;
                denum = terms.back().second.n;
                num = nmod_neg(num, Common::flint_mod);
                num = nmod_div(num, denum, Common::flint_mod);
                out << num;
#endif
#else
                string expr = "-(" + terms[i].second.s + ")/(" + terms.back().second.s + ")";
                fuel::simplify(expr, 0);
                out << expr;
#endif
                out << "\"" << "}";
                if (i + 2 != terms.size()) {
                    out << ",";
                }
                out << endl;
            }
            out << "            }" << endl;
            out << "        }";
        }
        itr++;
        if (itr != points.end()) {
            out << "," << endl;
        }
        itr--;
    }
    out << endl << "    }" << endl;

}

/**
 * Save ids to stream
 * @param out the stream
 * @param points the points to be saved
 */
void save_ids(fstream& out, const set<Point, std::greater<Point>> &points) {
    out << "    {" << endl;
    size_t comb_count = 1;
    bool first_combination = true;
    for (auto &combination : Equation::combinations_unsubstituted) {
        if (!first_combination) {
            out << "," << std::endl;
        }
        first_combination = false;
        out << "        {" << "combination[" << comb_count << "]" << ",";
        ++comb_count;
        out << "+{";
        bool first_term = true;
        for (auto &term : combination) {
            if (!first_term) {
                out << ",";
            }
            first_term = false;
            out << "{" << term.first << "," << term.second << "}";
        }
        out << "}";
        out << "}";
    }
    if (!first_combination) {
        if (!points.empty())
            out << ",";
        out << std::endl;
    }
    for (auto itr = points.begin(); itr != points.end(); ++itr) {
        out << "        {" << itr->Number() << "," << *itr << "}";
        itr++;
        if (itr != points.end()) {
            out << ",";
        }
        itr--;
        out << endl;
    }
    out << "    }" << endl;
}

/**
 * Launches reduction. For the list of options see the paper.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return successfullness
 */
int main(int argc, char *argv[]) {
#ifdef WITH_DEBUG
    attach_handler();
#endif
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
    srun = srun.substr(0, srun.length() - 7);
#else
    srun = srun.substr(0, srun.length() - 6);
#endif
#else
    srun = srun.substr(0, srun.length() - 5);
#endif

    if (srun[0] == '/') { // running with full path
        Common::FIRE_folder = srun;
    } else { // relative path, using current dir
        Common::FIRE_folder = scurrent + "/" + srun;
    }

    static_assert(sizeof(Point) == POINT_SIZE, "Strange size of point class");
    static_assert(sizeof(int) == 4, "Strange size of int");
    static_assert(sizeof(long long int) == 8, "Strange size of long long int");

    parse_argc_argv(argc, argv, true);

    if (!Common::very_silent)
        cout << "FIRE 7.0" << endl;

    if (!Common::silent) {
        cout << "Path: " << Common::FIRE_folder << endl;
        char sys_command[128];
        snprintf(sys_command, sizeof(sys_command), "cd %s && git log --oneline -1 2>/dev/null",
                 Common::FIRE_folder.c_str());
        string version = exec_command(sys_command);
        if (version == "")
            cout << "Cannot get version, git not available." << endl;
        else
            cout << "Version: " << version;
    }

    set<Point, std::greater<Point>> points;

    string output;
    int res = parse_config(Common::config_file + ".config", points, output, 0);
    if (res > 0) {
        return -1;
    } else if (res == -1) {
        // closing it safely
        fuel::close();
        if (Common::receive_from_child) {
            close_worker_threads();
        }
        if (Common::wrap_databases) {
            database_to_file_or_back(0, true); // close the wrapper database
        }

        if (Common::parallel_mode) {
            char sys_command[100];
            snprintf(sys_command, sizeof(sys_command), "rm -r %s", Common::path.c_str());
            if (system(sys_command)) {
                printf("Could not clean up database after MPI");
            }
        }

        return 0;
    }

    map<sector_count_t, set<Point>> needed;
    for (const auto &pnt : points) {
        add_needed(needed, pnt);
    }

    if (Common::stages != t_stages::backward) {
        for (const auto &item : needed) {
            if (Common::wrap_databases) {
                database_to_file_or_back(item.first, false);
            }
            open_database(item.first);

            vector<pair<Point, COEFF>> t;
            for (const auto &pnt : item.second) {
                p_set(pnt, t, true);
            }

            close_database(item.first);
            if (Common::wrap_databases) {
                database_to_file_or_back(item.first, true);
            }
        }
    }

    // the main call to reduction in functions.cpp
    // the data to be evaluated is already in tables
    //
    //

    if ((!points.empty()) || (Common::target_level != 0)) {
        perform_reduction();
    }

    if ((Common::stages == t_stages::forward) || (Common::stages == t_stages::backward && Common::target_level != 0)) {

        if (Common::wrap_databases) {
            database_to_file_or_back(0, true); // close the wrapper database
        }

        if (Common::parallel_mode || Common::clean_databases) {
            char sys_command[100];
            snprintf(sys_command, sizeof(sys_command), "rm -r %s", Common::path.c_str());
            if (system(sys_command)) {
                printf("Could not clean up database after work");
            }
        }

        if (Common::receive_from_child) {
            close_worker_threads();
        }

        fuel::close();
        return 0;
    }

    set<Point, std::greater<Point>> masters;

    if (!Common::only_masters) {
        // reading expressions from all databases, filling temporary tables,
        // creating list of masters;
        vector<pair<Point, COEFF>> empty_terms;
        for (const auto &item : needed) {
            if (Common::wrap_databases) {
                database_to_file_or_back(item.first, false, false);
            }
            open_database(item.first);

            for (const auto &pnt : item.second) {
                vector<pair<Point, COEFF>> terms;
                p_get(pnt, terms);
                if (terms.empty()) {
                    masters.insert(pnt);
                } else {
                    p_set_temp(pnt, terms);
                    for (const auto &term : terms) {
                        if (!(term.first == pnt)) {
                            masters.insert(term.first);
                            p_set_temp(term.first, empty_terms);
                        }
                    }
                }
            }
            close_database(item.first, false);
            if (Common::wrap_databases) {
                remove((Common::path + int2string(item.first) + "." + "tmp").c_str());
            }
        }
    } else { // now the only masters way
        // we need to locate masters and add them to the final list
        cout << "Identifying master-integrals" << endl;
        for (sector_count_t sector_number = 2; sector_number <= Common::abs_max_sector; ++sector_number) {
            if (!database_exists(sector_number))
                continue;
            if (Common::wrap_databases) {
                database_to_file_or_back(sector_number, false, false);
            }
            open_database(sector_number);

            class VisitorImpl : public kyotocabinet::DB::Visitor {
                // call back function for an existing record
                const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, [[maybe_unused]] size_t vsiz,
                                       [[maybe_unused]] size_t *sp) override {
                    if (ksiz < sizeof(Point)) {
                        return NOP;
                    }
                    const Point test = *(reinterpret_cast<const Point *>(kbuf));
                    if (vbuf[2] == 127) { // marked as master
                        masters->insert(test);
                    }
                    return NOP;
                }

                // call back function for an empty record space
                const char *visit_empty([[maybe_unused]] const char *kbuf, [[maybe_unused]] size_t ksiz,
                                        [[maybe_unused]] size_t *sp) override {
                    return NOP;
                }

              public:
                set<Point, std::greater<Point>> *masters{};
            } visitor;

            visitor.masters = &masters;

            if (!Common::points[sector_number]->iterate(&visitor, false)) {
                cout << "Iterate error on master collection: " << sector_number << endl;
                abort();
            }

            close_database(sector_number, false);
            if (Common::wrap_databases) {
                remove((Common::path + int2string(sector_number) + "." + "tmp").c_str());
            }
        }
    }
    if (!Common::very_silent)
        cout << "Master integrals: " << masters.size() << endl;
    points.clear();
    points = masters;

    // replacing vectors in points with their original vectors in orbits
    if (!Common::only_masters) {
        for (auto &cpair : Equation::initial) {
            Point &p = cpair.second.first;
            bool needed_for_tables = cpair.second.second;
            auto &vec = cpair.first;
            if (!p.IsZero()) {              // the original vector was not mapped into zero
                if (vec != p.GetVector()) { // the vectors differ. we do not have such a point
                    Point new_p(vec);
                    vector<pair<Point, COEFF>> terms;
                    p_get_temp(p, terms);
                    if (!terms.empty()) { // there is some table entry for our point, we
                                          // are making a copy
                        COEFF c = terms.back().second;
                        terms.pop_back();
                        terms.emplace_back(new_p, c);
                    } else { // there is no entry for our point, it is a master, sending
                             // the new one to the old one
                        COEFF one;
                        COEFF minus_one;
#ifdef PRIME
#ifdef MPRIME
                        for (size_t i = 0; i != MPRIME; ++i) {
                            one.N[i] = 1;
                            minus_one.N[i] = Common::prime - 1;
                        }
#else
                        one.n = 1;
                        minus_one.n = Common::prime - 1;
#endif
#else
                        one.s = "1";
                        minus_one.s = "-1";
#endif
                        terms.emplace_back(p, minus_one);
                        terms.emplace_back(new_p, one);
                    }
                    p_set_temp(new_p, terms);
                    if (needed_for_tables)
                        points.insert(new_p);
                } else { // such a Point already exists
                    if (needed_for_tables)
                        points.insert(p);
                }
            } else { // it is a zero point, mapping it to zero
                vector<t_index> vv = vec;

                Point new_p(vv, 0, -2); // get it to sector 1 without changes
                COEFF c;
#ifdef PRIME
#ifdef MPRIME
                for (size_t i = 0; i != MPRIME; ++i) {
                    c.N[i] = 1;
                }
#else
                c.n = 1;
#endif
#else
                c.s = "1";
#endif
                vector<pair<Point, COEFF>> terms;
                terms.emplace_back(new_p, c);

                p_set_temp(new_p, terms);
                if (needed_for_tables)
                    points.insert(new_p);
            }
        }
    }

    if (Common::one_pass_database != "" && !Common::one_pass) {
        // we need to save database
        cout << "Saving information for one-pass" << endl;
        std::ifstream src(Common::path + "0001.tmp", std::ios::binary);
        std::ofstream dst(Common::one_pass_database, std::ios::binary);
        dst << src.rdbuf();
    }

    if (Common::plan_file != "") {
        fstream plan_out;
        plan_out.open(Common::plan_file, fstream::out);
        for (sector_count_t sector_number = 2; sector_number <= Common::abs_max_sector + 1; ++sector_number) {
            if (!database_exists(sector_number))
                continue;
            if (Common::wrap_databases) {
                database_to_file_or_back(sector_number, false, false);
            }
            plan_out << "Sector" << std::endl << sector_number << std::endl;
            bool has_ext_symm = Point::dbases.find(sector_number) != Point::dbases.end();
            bool has_lrules = Common::lbases.find(sector_number) != Common::lbases.end();
            if (has_ext_symm) {
                plan_out << "ExtSymm" << std::endl;
            } else if (has_lrules) {
                plan_out << "LRulesBegin" << std::endl;
            }
            if (has_lrules) {
                // in this case we just need the list of points
                scan_snapshot(
                    sector_number,
                    [&plan_out]([[maybe_unused]] const char *kbuf, size_t ksiz) -> bool {
                        return (ksiz == sizeof(Point));
                    },
                    [&plan_out](const char *kbuf, [[maybe_unused]] size_t ksiz, [[maybe_unused]] const char *vbuf,
                                [[maybe_unused]] size_t vsiz) -> void {
                        Point p = *(reinterpret_cast<const Point *>(kbuf));
                        if (!p.IsVirtual()) {
                            unsigned int it = 0;
                            vector<t_index> v = p.GetVector();
                            plan_out << "{" << int(v[it]);
                            for (it++; (it != v.size()); it++)
                                plan_out << "," << int(v[it]);
                            plan_out << "}" << std::endl;
                        }
                    });
            } else if (!has_ext_symm) {
                scan_snapshot(
                    sector_number,
                    [&plan_out](const char *kbuf, size_t ksiz) -> bool {
                        return (ksiz >= 6 && !strncmp(kbuf, "$USED_", 6));
                    },
                    [sector_number, &plan_out](const char *kbuf, [[maybe_unused]] size_t ksiz,
                                               [[maybe_unused]] const char *vbuf,
                                               [[maybe_unused]] size_t vsiz) -> void {
                        int pos, neg;
                        std::string temp(kbuf, ksiz);
                        sscanf(temp.c_str(), "$USED_%d_%d", &pos, &neg);
                        plan_out << "Level" << std::endl << "{" << pos << ", " << neg << "}" << std::endl;
                        if (Common::pos_pref && Point::ibases.find(sector_number) != Point::ibases.end()) {
                            if (Common::pos_pref > 0) {
                                if ((pos <= abs(Common::pos_pref)) && (neg == 1)) {
                                    plan_out << "Symmetries" << std::endl;
                                }
                            } else {
                                if ((pos == 1) && (neg <= abs(Common::pos_pref))) {
                                    plan_out << "Symmetries" << std::endl;
                                }
                            }
                        }
                        if (Common::hint) {
                            std::ifstream hint_read(Common::hint_path + "-" + std::to_string(sector_number) + "-{" +
                                                    std::to_string(pos) + "," + std::to_string(neg) + "}.m");
                            for (std::string line; std::getline(hint_read, line);) {
                                if (line.size() == 1) {
                                    plan_out << "HintBegin" << std::endl;
                                    // first line in hint. We make a hint start
                                    continue;
                                } else {
                                    plan_out << line.substr(0, line.size() - 1) << std::endl;
                                    if (line[line.size() - 1] == '}') {
                                        plan_out << "HintEnd" << std::endl;
                                        break;
                                    }
                                }
                            }
                        } else {
                            plan_out << "Seed" << std::endl;
                        }
                    });
            }
            if (has_lrules) {
                plan_out << "LRulesEnd" << std::endl;
            }

            if (Common::wrap_databases) {
                remove((Common::path + int2string(sector_number) + "." + "tmp").c_str());
            }
        }

        plan_out << "Done" << std::endl;
        plan_out.close();
    }

    // everything done, saving tables
#ifndef PRIME
    fuel::switchToConventional();
#endif

    if (!Equation::combinations.empty()) {
        if (!Common::very_silent)
            cout << "Joining combinations" << endl;
    }

#ifdef PRIME
    vector<list<pair<Point, COEFF>>> substituted_combinations;
#else
    vector<vector<pair<Point, COEFF>>> substituted_combinations;
#endif

    for (auto &combination : Equation::combinations) {
#ifdef PRIME
        list<pair<Point, COEFF>> total_terms;
#else
        vector<pair<Point, COEFF>> total_terms;
#endif
        for (auto &cpair : combination) {
            if (cpair.first == Point()) {
                continue;
            }
            vector<pair<Point, COEFF>> terms;
            p_get_temp(cpair.first, terms);
            /*
            std::cout << "Terms" << std::endl;
            for (auto & tpair : terms) {
                std::cout << tpair.first << " | " << tpair.second << std::endl;
            }
            std::cout << "Coeff: " << cpair.second << std::endl;
            */
            if (!terms.empty()) {
#ifdef PRIME
                add_to(total_terms, terms, cpair.second / -(terms.rbegin()->second), true);
#else
                vector<pair<Point, COEFF>> rterms;
                add(total_terms, terms, rterms, cpair.second, true);
                total_terms.swap(rterms);
#endif
            }
        }
#ifndef PRIME
        normalize(total_terms, 0);
#endif
        /*
        std::cout << "Combination" << std::endl;
        for (auto & tpair : total_terms) {
            std::cout << tpair.first << " | " << tpair.second << std::endl;
        }
        */
        substituted_combinations.push_back(total_terms);
    }

    if (!Common::very_silent)
        cout << "Saving tables" << endl;

    fstream out;
    out.open(output, fstream::out);

    out << "{" << endl;

    if (Common::ids_first) {
        save_ids(out, points);
    } else {
        save_relations(out, points, substituted_combinations);
    }

    out << endl << "," << endl;

    if (Common::ids_first) {
        save_relations(out, points, substituted_combinations);
    } else {
        save_ids(out, points);
    }

    out << "}" << endl;
    out.close();

    if (Common::wrap_databases) {
        database_to_file_or_back(0, true); // close the wrapper database
    }

    if (Common::parallel_mode || Common::clean_databases) {
        char sys_command[100];
        snprintf(sys_command, sizeof(sys_command), "rm -r %s", Common::path.c_str());
        if (system(sys_command)) {
            printf("Could not clean up database after work");
        }
    }

    if (Common::receive_from_child) {
        close_worker_threads();
    }

    fuel::close();

    return 0;
}
