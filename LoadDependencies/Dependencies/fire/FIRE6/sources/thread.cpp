/**
 * @file thread.cpp
 * @author Alexander Smirnov
 *
 * This file is a part of the FIRE package.
 * This file is used to compile FLAME binaries.
 *
*/

#include "handler.h"
#include "functions.h"
#include "parser.h"

string common::FIRE_folder;
string common::config_file;

/**
* FLAME binaries can be started either the same way like FIRE for the port connection (see first test)
* or called by FIRE.
* FLAME binaries can be started manually to work in a particular sector with -sector sector_number,
* but only with already existing database.
* Positive numbers mean forward pass, negative - backward.
* @param argc number of arguments
* @param argv array of arguments
* @return successfullness
*/
int main(int argc, char *argv[]) {

    auto start_time = chrono::steady_clock::now();

#ifdef WITH_DEBUG
    attach_handler();
#endif
    common::remote_worker = true;
    int sector;
    int thread_number;
    string output;
    set<point, indirect_more> points;

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
    thread_number = temp.first;
    sector = temp.second;

    bool with_fire = true;
    if (thread_number == -1) {
        cout << "Forcing no send to parent" << endl;
        with_fire = false;
        thread_number = 0;
    }

    if (parse_config(common::config_file + ".config", points, output, sector, !with_fire)) {
        return -1;
    }

    if (sector > 0) { // forward or just the one pass in case of reverse mode!
        forward_stage(thread_number, sector);
    } else if (sector < 0) {// backward
        perform_substitution(thread_number, -sector);
    } else {
        cout << "Sector not specified" << endl;
        abort();
    }

    if (common::send_to_parent) {
        fclose(common::child_stream_from_child);
        fclose(common::child_stream_to_child);
    }

    if ((!common::send_to_parent) || (common::receive_from_child)) {
        equation::f_stop = true;

        for (unsigned int i = 0; i != common::f_queues; ++i) {
            equation::f_submit_cond[i].notify_all();
        }
        for (unsigned int i = 0; i != common::fthreads_number; ++i) {
            equation::f_threads[i].join();
        }
    }
    if (!sector) cout<<"Done"<<endl;


    auto stop_time = chrono::steady_clock::now();
    if (!common::silent) {
        cout << "FLAME time ("<<sector<<"): " << chrono::duration_cast<chrono::duration<float>>(stop_time - start_time).count() << endl;
    }

    fuel::close();

    return 0;
}
