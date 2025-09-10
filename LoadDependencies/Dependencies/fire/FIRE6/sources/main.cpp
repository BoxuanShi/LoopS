/**
 * @file main.cpp
 * @author Alexander Smirnov
 *
 * This file is a part of the FIRE package.
 */

#include "common.h"
#include "parser.h"
#include "handler.h"
#include "functions.h"
#include <array>
#include <cstdio>
#include <ifaddrs.h>
#include <cstring>
#include <arpa/inet.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/socket.h>



// routines to save and load temporary tables
/**
 * Temporary tables.
 */
map<point, vector<pair<point, COEFF> > > temp;

/**
 * Set terms for specific point in temporary tables.
 * @param p point for which we are adding terms to temporary tables.
 * @param terms terms which we are writing in temporary tables.
 */
void p_set_temp(const point &p, const vector<pair<point, COEFF> > &terms) {
    temp.emplace(p, terms);
}

/**
 * Get terms for point from temporary tables.
 * @param p point for which we are searching terms.
 * @param terms result vector where we'll place found terms, if there're any.
 */
void p_get_temp(const point &p, vector<pair<point, COEFF> > &terms) {
    auto itr = temp.find(p);
    if (itr == temp.end()) {
        terms.clear();
    } else {
        terms = itr->second;
    }
}

string common::FIRE_folder;
string common::config_file;

/**
 * Run a system command and get output
 * @param cmd the command
 * @return joined resulting output
 */
std::string exec_command(const char* cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd, "r"), pclose);
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    return result;
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
    cout << "FIRE 6.5.2" << endl;
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
    srun = srun.substr(0, srun.length() - 6);
#else
    srun = srun.substr(0, srun.length() - 5);
#endif

    if (srun[0] == '/') {  // running with full path
        common::FIRE_folder = srun;
    } else { //relative path, using current dir
        common::FIRE_folder = scurrent + "/" + srun;
    }

    static_assert(sizeof(point) == POINT_SIZE, "Strange size of point class");

    auto ret = parseArgcArgv(argc, argv, true);
    if (ret.first == -2) {
        return 1;
    }

    if (!common::silent) {
        cout << "Path: " << common::FIRE_folder << endl;
        char sys_command[128];
        sprintf(sys_command, "cd %s && git log --oneline -1 2>/dev/null", common::FIRE_folder.c_str());
        string version = exec_command(sys_command);
        if (version == "")
            cout << "Cannot get version, git not available." << endl;
        else
            cout << "Version: " << version;
    }

    set<point, indirect_more> points;

    string output;
    int res = parse_config(common::config_file + ".config", points, output, 0);
    if (res > 0) {
        return -1;
    } else if (res == -1) {
        // closing it safely
        if (common::receive_from_child) {
            equation::f_stop = true;

            for (unsigned int i = 0; i != common::f_queues; ++i) {
                equation::f_submit_cond[i].notify_all();
            }
            for (unsigned int i = 0; i != common::fthreads_number; ++i) {
                equation::f_threads[i].join();
            }
        }
        if (common::wrap_databases) {
            database_to_file_or_back(0, true); // close the wrapper database
        }

        if (common::parallel_mode) {
            char sys_command[100];
            sprintf(sys_command, "rm -r %s", common::path.c_str());
            if (system(sys_command)) {
               printf("Could not clean up database after MPI");
            }
        }

        return 0;
    }

    map<sector_count_t, set<point> > needed;
    for (const auto &pnt : points) {
        add_needed(needed, pnt);
    }

    for (const auto &item : needed) {
        if (common::wrap_databases) {
            database_to_file_or_back(item.first, false);
        }
        open_database(item.first);

        vector<pair<point, COEFF> > t;
        for (const auto &pnt : item.second) {
            p_set(pnt, t, 126);
        }

        close_database(item.first);
        if (common::wrap_databases) {
            database_to_file_or_back(item.first, true);
        }
    }

    // the main call to reduction in functions.cpp
    // the data to be evaluated is already in tables
    if (!points.empty()) {
        Evaluate();
    }

    if (common::receive_from_child) {
        equation::f_stop = true;

        for (unsigned int i = 0; i != common::f_queues; ++i) {
            equation::f_submit_cond[i].notify_all();
        }
        for (unsigned int i = 0; i != common::fthreads_number; ++i) {
            equation::f_threads[i].join();
        }
    }

    set<point, indirect_more> masters;

    if (!common::only_masters) {
        //reading expressions from all databases, filling temporary tables, creating list of masters;
        vector<pair<point, COEFF> > empty_terms;
        for (const auto &item : needed) {
            if (common::wrap_databases) {
                database_to_file_or_back(item.first, false, false);
            }
            open_database(item.first);

            for (const auto &pnt : item.second) {
                vector<pair<point, COEFF> > terms;
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
            close_database(item.first);
            if (common::wrap_databases) {
                remove((common::path + int2string(item.first) + "." + "tmp").c_str());
            }
        }
    } else { // now the only masters way
        // we need to locate masters and add them to the final list
        cout << "Identifying master-integrals" << endl;
        for (sector_count_t test_sector = 2; test_sector <= common::abs_max_sector; ++test_sector) {
            if (!database_exists(test_sector)) continue;
            if (common::wrap_databases) {
                database_to_file_or_back(test_sector, false, false);
            }
            open_database(test_sector);

            class VisitorImpl : public kyotocabinet::DB::Visitor {
                // call back function for an existing record
                const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz, size_t *sp) override {
                    if (ksiz < sizeof(point)) {
                        return NOP;
                    }
                    const point test = *(reinterpret_cast<const point *>(kbuf));
                    if (vbuf[2] == 127) { // marked as master
                        masters->insert(test);
                    }
                    return NOP;
                }

                // call back function for an empty record space
                const char *visit_empty(const char *kbuf, size_t ksiz, size_t *sp) override {
                    return NOP;
                }
            public:
                set<point, indirect_more> *masters{};
            } visitor;

            visitor.masters = &masters;

            if (!common::points[test_sector]->iterate(&visitor, false)) {
                cout << "Iterate error on master collection: " << test_sector << endl;
                abort();
            }

            close_database(test_sector);
            if (common::wrap_databases) {
                remove((common::path + int2string(test_sector) + "." + "tmp").c_str());
            }
        }
    }
    cout << "Master integrals: " << masters.size() << endl;
    points.clear();
    points = masters;

    //replacing vectors in points with their original vectors in orbits
    if (!common::only_masters) {
        for (auto &integral : equation::initial) {
            point p = integral.second;
            if (!p.is_zero()) {  // the original vector was not mapped into zero
                if (integral.first != p.get_vector()) { // the vectors differ. we do not have such a point
                    point new_p(integral.first);
                    vector<pair<point, COEFF> > terms;
                    p_get_temp(p, terms);
                    if (!terms.empty()) {   // there is some table entry for our point, we are making a copy
                        COEFF c = terms.back().second;
                        terms.pop_back();
                        terms.emplace_back(new_p, c);
                    } else {    // there is no entry for our point, it is a master, sending the new one to the old one
                        COEFF one;
                        COEFF minus_one;
#ifdef PRIME
                        one.n = 1;
                        minus_one.n = common::prime - 1;
#else
                        one.s = "1";
                        minus_one.s = "-1";
#endif
                        terms.emplace_back(p, minus_one);
                        terms.emplace_back(new_p, one);
                    }
                    p_set_temp(new_p, terms);
                    points.insert(new_p);
                } else { //such a point already exists
                    points.insert(p);
                }
            } else {  // it is a zero point, mapping it to zero
                vector<t_index> vv = integral.first;

                point new_p(vv,0,-2); // get it to sector 1 without changes
                COEFF c;
#ifdef PRIME
                c.n = 1;
#else
                c.s = "1";
#endif
                vector<pair<point, COEFF> > terms;
                terms.emplace_back(new_p, c);

                p_set_temp(new_p, terms);
                points.insert(new_p);
            }
        }
    }

    // everything done, saving tables
    cout << "Saving tables" << endl;

#ifndef PRIME
    fuel::switchToConventional();
#endif

    fstream out;
    out.open(output, fstream::out);

    out << "{" << endl << "    {" << endl;
    for (auto itr = points.begin(); itr != points.end(); ++itr) {
        out << "        {" << itr->number() << "," << endl;
        out << "            {" << endl;
        vector<pair<point, COEFF> > terms;
        p_get_temp(*itr, terms);
        if (terms.empty()) {
            out << "{" << itr->number() << ",\"1\"}}}";
        } else {
            for (unsigned int i = 0; i != terms.size() - 1; ++i) {
                out << "                {" << terms[i].first.number() << "," << "\"";
#ifdef PRIME
                uint128_t num, denum;
                num = terms[i].second.n;
                denum = terms.back().second.n;
                num = common::prime - num;
                denum = mul_inv(denum, common::prime);
                num *= denum;
                num %= common::prime;
                out << static_cast<uint64_t>(num);
#else
                string res = "-(" + terms[i].second.s + ")/(" + terms.back().second.s + ")";
                fuel::simplify(res, 0);
                out << res;
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
    out << endl << "    }," << endl;

    out << "    {" << endl;
    for (auto itr = points.begin(); itr != points.end(); ++itr) {
        out << "        {" << itr->number() << "," << *itr << "}";
        itr++;
        if (itr != points.end()) {
            out << ",";
        }
        itr--;
        out << endl;
    }
    out << "    }" << endl << "}" << endl;
    out.close();

    if (common::wrap_databases) {
        database_to_file_or_back(0, true); // close the wrapper database
    }

    if (!common::remote_worker && common::clean_databases) {
        DIR *dp;
        struct dirent *ep;
        struct stat st{};

        dp = opendir((common::path + "/").c_str());
        if (dp != nullptr) {
            while ((ep = readdir(dp)) != nullptr) {
                stat((common::path + "/" + ep->d_name).c_str(), &st);
                if (S_ISDIR(st.st_mode) == 0) {
                    if (!common::silent) { cout << "Deleting file \"" << ep->d_name << "\"" << endl; }
                    remove((common::path + "/" + ep->d_name).c_str());
                }
            }
            closedir(dp);
        } else {
            cerr << "Couldn't open the directory." << endl;
            abort();
        }
    }

    if (common::parallel_mode) {
        char sys_command[100];
        sprintf(sys_command, "rm -r %s", common::path.c_str());
        if (system(sys_command)) {
            printf("Could not clean up database after MPI");
        }
    }

    fuel::close();
    return 0;
}
