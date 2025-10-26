/**
 * @file thread.cpp
 * @author Alexander Smirnov
 *
 * This file is a part of the FIRE package.
 * This file is used to compile FLAME binaries.
 *
 */

#include "functions.h"
#include "handler.h"
#include "parser.h"

string Common::FIRE_folder;
string Common::config_file;

/**
 * FLAME binaries can be started either the same way like FIRE for the port
 * connection (see first test) or called by FIRE. FLAME binaries can be started
 * manually to work in a particular sector with -sector sector_number, but only
 * with already existing database. Positive numbers mean forward pass, negative
 * - backward.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return successfullness
 */
int main(int argc, char *argv[]) {

    auto start_time = chrono::steady_clock::now();

#ifdef WITH_DEBUG
    attach_handler();
#endif
    int sector;
    int thread_number;
    string output;
    set<Point, std::greater<Point>> points;

    if ((argc == 2) && !strcmp(argv[1], "-test")) {
        printf("Ok\n");
        return 0;
    }

    char current[PATH_MAX];
    if (!getcwd(current, PATH_MAX)) {
        cerr << "Can't get current dir name" << endl;
        return 1;
    }
    string scurrent = string(current);
    string srun = string(argv[0]);

    // this is important, there's the length of program name here!
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

    pair<int, int> temp = parse_argc_argv(argc, argv, false); // it's a larger type to be negative
    thread_number = temp.first;
    sector = temp.second;

    bool with_fire = true;
    if (thread_number == -1) {
        cout << "Forcing no send to parent" << endl;
        with_fire = false;
        thread_number = 0;
    }

    if (parse_config(Common::config_file + ".config", points, output, sector, !with_fire)) {
        return -1;
    }

    if (sector > 0) { // forward or double in case os one pass
        forward_stage(thread_number, sector);
        if (Common::one_pass) {
            perform_substitution(thread_number, sector);
        }
    } else if (sector < 0) { // backward
        perform_substitution(thread_number, -sector);
    } else {
        cout << "Unspecified sector" << endl;
        abort();
    }

    if (Common::send_to_parent) {
        fclose(Common::child_stream_from_child);
        fclose(Common::child_stream_to_child);
    }

    fuel::close();
    if ((!Common::send_to_parent) || (Common::receive_from_child)) {
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

    auto stop_time = chrono::steady_clock::now();
    if (!Common::silent) {
        cout << "FLAME time (" << sector
             << "): " << chrono::duration_cast<chrono::duration<float>>(stop_time - start_time).count() << endl;
    }

    return 0;
}
