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
#include "parser.h"

string common::FIRE_folder;
string common::config_file;

/**
 * Entry point for FTool binaries. Used for printing all entries in a database.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return successfullness
 */
int main(int argc, char *argv[]) {
    common::remote_worker = true;
    int sector;
    string output;

    set<point, indirect_more> points;
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
    srun = srun.substr(0, srun.length() - 7);
#else
    srun = srun.substr(0, srun.length() - 6);
#endif

    if (srun[0] == '/') {  // running with full path
        common::FIRE_folder = srun;
    } else { //relative path, using current dir
        common::FIRE_folder = scurrent + "/" + srun;
    }

    pair<int,int> temp = parseArgcArgv(argc, argv, false);
    sector = temp.second;

    if (sector <= 0) {
        cout << "Wrong sector" << endl;
        return -1;
    }
    common::ftool = true;
    if (parse_config(common::config_file + ".config", points, output, sector, true)) {
        return -1;
    }
    if (common::cpath != "") {   // we need the file here locally
        copy_database(abs(sector), true);
    }
    open_database(sector);
    point::print_g = true;

    cout << "{" << endl;

    auto *pdb = common::points[sector];
    class VisitorImpl : public kyotocabinet::DB::Visitor {
        // call back function for an existing record
        const char *visit_full(const char *kbuf, size_t ksiz, const char *vbuf, size_t vsiz, size_t *sp) override {
            if (ksiz < sizeof(point)) {
                return NOP;
            }
            const point test = *reinterpret_cast<const point *>(kbuf);
            cout << test << " -> ";

            list<point> monoms;
            unsigned short len = reinterpret_cast<const unsigned short *>(vbuf)[0];
            for (unsigned int i = 0; i != len; ++i) {
                monoms.push_back((reinterpret_cast<const point *>(vbuf + 3))[i]);
            }
            const char *buf = vbuf + 3 + (len * sizeof(point));
            list<string> coeffs;
            string s = buf;
            size_t pos = 0;
            for (unsigned int i = 0; i != len; ++i) {
#ifdef PRIME
                char buff[16];
                sprintf(buff, "%llu", *reinterpret_cast<const unsigned long long *>(buf + pos));
                coeffs.push_back(string(buff));
                pos += 8;
#else
                size_t next = s.find('|', pos);
                coeffs.push_back(s.substr(pos, next - pos));
                pos = next + 1;
#endif
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
                    cout << "(" << coeffs.front() << ")/(-(" << c << ")) " << monoms.front();
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
            return NOP;
        }

        // call back function for an empty record space
        const char *visit_empty(const char *kbuf, size_t ksiz, size_t *sp) override {
            return NOP;
        }
    public:
        set<point> needed;
        set<point> masters;
        sector_count_t sector{};
        unsigned short sector_level{};
    } visitor;

    visitor.sector_level = 0;
    visitor.sector = sector;

    if (!pdb->iterate(&visitor, false)) {
        cout << "Iterate error" << sector << endl;
        abort();
    }

    cout << "{}}" << endl;

    close_database(sector);
    if (common::cpath != "") {
        clear_database(sector);
    }
    return 0;
}
