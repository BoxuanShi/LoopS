/** @file mpi_wrapper.cpp
 * @author Fedor Chukharev
 *
 * This file is a part of the FIRE package.
 *
 * Used to launch and control result of work of many instances of FIRE6p and have them run in parallel.
*/
#include "mpi.h"
#include "handler.h"
#include <string>
#include <unistd.h>
#include <cstring>
#include <iostream>
#include <getopt.h>
#include <vector>
#include <list>
#include <dirent.h>
#include <chrono>
#include <sys/wait.h>

/**
 * MPI tag for command message.
 */
#define COMMAND 0
/**
 * MPI tag for message with data.
 */
#define DATA 1
/**
 * MPI tag for message with results of work.
 */
#define RESULT 2
/**
 * Default string buffer size,
 */
#define STR_SIZE 256
/**
 * Maximum index of a prime from primes.cpp
 */
#define MAX_P_INDEX 127

/**
 * Type of command send from master process.
 */
enum class command_type : int {
    FINISH, EVAL
};

/**
 * Return Values for functions
 */
enum return_values {
    FAIL = -1,
    FAILED_TO_RESERVE = -1,
    SUCCESS = 0,
    ALREADY_RESERVED = 1
};

/**
 * Special struct, that describes what range covers given variable
 */
struct input_variable_t {
    std::vector<int> indices; ///< the starting index 
    int range; ///< the index range
};

/**
 * Path to FIRE6p executable.
 */
char EXEC_PATH[128];

/**
 * Default path to problem.
 */
std::string ARG_PATH{};

/**
 * Global to indicate that --help option was passed. Used for getopt_long
 */
static int help_flag;

/**
 * Option that are used by getopt_long
 */
static struct option long_options[] =
        {
                {"help",   no_argument,       &help_flag, 1},
                {"config", required_argument, nullptr,    'c'},
                {"limit",  required_argument, nullptr,    'l'},
                {"variables",  required_argument, nullptr,    'v'},
                {nullptr, 0,                  nullptr,    0}
        };

/**
 * Update offsets in matrix for next FIRE6p invocation's arguments.
 * @param leftover_jobs list of tables' indices of failed jobs
 * @param tables_amount total count of jobs
 * @returns index of table to be processed, -1 if none left
 */
int get_table_to_process(std::list<int> &leftover_jobs, int tables_amount) {
    static int index_to_send = 0;
    int table_index_to_do = -1;
    if (!leftover_jobs.empty()) {
        table_index_to_do = leftover_jobs.back();
        leftover_jobs.pop_back();
    } else if (index_to_send != tables_amount) {
        table_index_to_do = index_to_send++;
    }
    return table_index_to_do;
}

/**
 * Self-made recursive directory removal function.
 * @param dirname full path
 * @return successfullness
 */
int remove_directory_recursively(const char *dirname) {
    DIR *dir;
    struct dirent *entry;
    char path[PATH_MAX];
    if (path == nullptr) {
        fprintf(stderr, "Out of memory error\n");
        return 0;
    }
    dir = opendir(dirname);
    if (dir == nullptr) {
        return 0;
    }

    while ((entry = readdir(dir)) != nullptr) {
        if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
            snprintf(path, (size_t) PATH_MAX, "%s/%s", dirname, entry->d_name);
            if (entry->d_type == DT_DIR) {
                remove_directory_recursively(path);
            }
            remove(path);
        }

    }
    closedir(dir);
    printf("Deleting: %s\n", dirname);
    remove(dirname);
    return 1;
}

/**
 * Try to reserve output table for FIRE executable
 * @param filename path to the table
 * @return result of attempt
 */
int reserve_table(const std::string &filename) {
    FILE *file;
    char buf[256];
    file = fopen(filename.c_str(), "r");
    if (file != nullptr) {
        fgetc(file);
        if (feof(file)) {
            printf("Tables are reserved! %s\n", filename.c_str());
        } else {
            printf("Tables are already created! %s\n", filename.c_str());
        }
        fclose(file);
        return ALREADY_RESERVED;
    } else {
        sprintf(buf, "touch '%s'", filename.c_str());
    }
    if (system(buf)) {
        printf("Could not reserve tables file");
        printf("%s\n", buf);
        return FAILED_TO_RESERVE;
    }
    return SUCCESS;
}

/**
 * Recursively remove temporary files created during computation and table, if it wasn't filled.
 * @param table_filename path to table to be checked
 * @param database_path path to temporary files
 * @param pid pid of FIRE executable, to identify temporary files belonged to that process
 * @return result of cleanup
 */
int cleanup_temp_files(const std::string &table_filename, const char *database_path, pid_t pid) {
    FILE *file;
    file = fopen(table_filename.c_str(), "r");
    if (file != nullptr) {
        fgetc(file);
        if (feof(file)) {
            printf("Reserved tables not created, deleting: %s\n", table_filename.c_str());
            if (remove(table_filename.c_str()) == -1) {
                printf("Could not delete temporary table data");
                return FAIL;
            }
        }
        fclose(file);
    }
    // now we need to remove temporary database after the child
    char hostname[64];
    char db_directory[256];
    gethostname(hostname, 64);
    sprintf(db_directory, "%s%s-%d", database_path, hostname, pid);
    printf("Removing %s\n", db_directory);
    remove_directory_recursively(db_directory);
    printf("Removed %s\n", db_directory);
    return SUCCESS;
}

/**
 * Prints usage to stdout
 */
void show_usage() {
    printf("Usage: ./bin/FIRE6_MPI [options]\n"
           "Options:\n"
           "\t-h, --help\t\t\tShow this help\n"
           "\t-l LIMIT, --limit LIMIT\t\tSet limit of jobs per worker. By default is unlimited.\n"
           "\t-c PATH, --config PATH\t\tSet config. One should omit extension '.config'\n"
           "\t-v \"variable_string\", --variables \"variables_string\" (be sure to enclose in in quotes)\n"
           "\tThe string must be of following template: 'd1-d2,d11-d12;x1-x2;f1-f2;p'\n"
           "\twhere 'd1-d2' or 'd11-d12' is range for variable or 'd21' is a fixed value and 'p' is prime numbers limit.\n"
           "\tFor example - '100-110;4-5;1-1;6' or '100-110,120-121;4-5;1-1;6' is a valid string.\n"
           "\tIt should be noted, that any number of variables can now be used, yet\n"
           "\ttheir positioning in this variable string should match that of config file.\n");
}

/**
 * @param input_ranges string of variable ranges, stripped of prime index at the end
 * @return vector of special structs, that are needed for calculation of indices
 */
std::vector<input_variable_t> parse_ranges(const std::string &input_ranges) {
    auto ranges = std::vector<input_variable_t>{};
    const char delim = ';';
    std::size_t current, previous = 0;
    current = input_ranges.find(delim);
    std::string temp{};
    int start, end;
    while (true) {
        start = end = 0;
        if (current == std::string::npos) 
            temp = input_ranges.substr(previous);
        else
            temp = input_ranges.substr(previous, current - previous);
        input_variable_t new_var = {{}, {}};
        // now working with temp string which can contain a number of comma separated ranges
        std::size_t current2, previous2 = 0;
        const char delim2 = ',';
        current2 = temp.find(delim2);
        while (true) {
            std::string temp2{};
            if (current2 == std::string::npos)
                temp2 = temp.substr(previous2);
            else
                temp2 = temp.substr(previous2, current2 - previous2);
            start = 0;
            end = 0;
            if (temp2.find('-') == std::string::npos) {
                if (sscanf(temp2.c_str(), "%d", &start) != 1) return std::vector<input_variable_t>{};
                end = start;
            } else {
                if (sscanf(temp2.c_str(), "%d-%d", &start, &end) !=2) return std::vector<input_variable_t>{};
                if (start > end) {
                    int swp_tmp = end;
                    end = start;
                    start = swp_tmp;
                }
            }
            new_var.range += end-start+1;
            new_var.indices.reserve(new_var.range);
            for (int i = start; i<=end; ++i) {
                new_var.indices.push_back(i);
            }
            if (current2 == std::string::npos) break;
            previous2 = current2 + 1;
            current2 = temp.find(delim2, previous2);
        }
        ranges.emplace_back(new_var);
        if (current == std::string::npos) break;
        previous = current + 1;
        current = input_ranges.find(delim, previous);
    }
    return ranges;
}

/**
 * Entry point for mpi_run_single.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return successfullness
 */
int main(int argc, char *argv[]) {
    int NET_SIZE, RANK, tmp;
    char proc_name[STR_SIZE];
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &RANK);
    MPI_Comm_size(MPI_COMM_WORLD, &NET_SIZE);
    MPI_Get_processor_name(proc_name, &tmp);
    strncpy(EXEC_PATH, argv[0], 127);
    EXEC_PATH[strlen(EXEC_PATH) - 4] = 'p';
    EXEC_PATH[strlen(EXEC_PATH) - 3] = '\0';
    std::chrono::time_point<std::chrono::steady_clock> start_time = std::chrono::steady_clock::now();
    int lim = -1; // maximal number of runs, 0 will lead to infinity
    int option_index = 0;
    int c = 0;
    std::string input_ranges{};
    while ((c = getopt_long(argc, argv, "hl:c:v:", long_options, &option_index)) != -1) {
        switch (c) {
            case 0:
                break;
            case 'h':
                help_flag = 1;
                break;
            case 'c':
                ARG_PATH = optarg;
                break;
            case 'l':
                lim = std::stoi(optarg);
                break;
            case 'v':
                input_ranges = optarg;
                break;
            default:
                MPI_Finalize();
                return 0;
        }
        option_index = 0;
    }
    if (help_flag) {
        if (RANK == 0) {
            show_usage();
        }
        MPI_Finalize();
        return 0;
    }
    if (NET_SIZE < 2) {
        printf("At least 2 processes are needed!\n");
        MPI_Finalize();
        return 0;
    }
    if (RANK == 0) {
        printf("Total %d worker-processes!\n\n", NET_SIZE - 1);
    }
    if (input_ranges == "") {
        if (RANK == 0) {
            std::cerr << "No ranges input!" << std::endl;
        }
        MPI_Finalize();
        return 1;
    }
    if (ARG_PATH.empty()) {
        if (RANK == 0) {
            std::cerr << "Missing --config/-c option! Exiting..." << std::endl;
        }
        MPI_Finalize();
        return 0;
    }
    auto sep_position = input_ranges.find_last_of(';');
    int p_index;
    if (sep_position == std::string::npos) {
        if (RANK == 0) {
            std::cout << "No prime number index found! - resetting it to 1..." << std::endl;
        }
        p_index = 1;
        sep_position = input_ranges.length();
    } else {
        p_index = std::stoi(input_ranges.substr(sep_position + 1));
    }
    if (p_index < 1 || p_index > MAX_P_INDEX) {
        if (RANK == 0) {
            std::cout << "Prime index not in range [1, " << MAX_P_INDEX << "]! - resetting it to 1..." << std::endl;
        }
        p_index = 1;
    }
    input_ranges.resize(sep_position); // we cut off the prime part
    std::vector<input_variable_t> var_ranges = parse_ranges(input_ranges);
    if (var_ranges.empty()) {
        if (RANK == 0) {
            std::cerr << "Please, check your input values, something is wrong!" << std::endl;
            std::cerr << "Received: " << input_ranges << std::endl;
            std::cout
                    << "The syntax for calling MPI executable has changed, please refer to CHANGELOG.md or type --help"
                    << std::endl;
        }
        MPI_Finalize();
        return 0;
    }
    const int P_INDEX = p_index;
    //
    // option parsing is common for every process!
    //
    if (RANK == 0) {
        std::cout << "Current values:" << std::endl <<
                  "\tconfig path = " << ARG_PATH << std::endl <<
                  "\tp_index = " << P_INDEX << std::endl <<
                  "Current ranges:" << std::endl;
        int i, tables_off = 0;
        for (size_t var_i = 0; var_i < var_ranges.size(); var_i++) {
            std::cout << "\tVariable " << var_i + 1 << " in {";
            for (int i = 0; i < var_ranges[var_i].range - 1; ++i) {
                std::cout << var_ranges[var_i].indices[i] << ", ";
            }
            std::cout << var_ranges[var_i].indices[var_ranges[var_i].range - 1] << "}" << std::endl;
        }
        auto answers = std::vector<int *>(NET_SIZE);
        for (i = 0; i < NET_SIZE; i++) {
            answers[i] = (int *) malloc(2 * sizeof(int)); // [0] - table index, [1] - status
        }

        int tables_amount = P_INDEX;
        for (auto &&var: var_ranges) {
            tables_amount *= var.range;
        }
        FILE *file;
        char filename[512];
        sprintf(filename, "%s.config", ARG_PATH.c_str());
        file = fopen(filename, "r");
        if (file == nullptr) {
            printf("No %s, exiting!\n", filename);
            return 1;
        }
        char load_string[1000] = "none";
        char output_buf[128];
        output_buf[0] = '\0';
        while (fgets(load_string, 1000, file)) {
            if (!strncmp(load_string, "#folder", 7)) {
                int pos = 7;
                while (load_string[pos] == ' ') pos++;
                strcpy(output_buf, load_string + pos);
                char *temp = output_buf;
                while (*temp) {
                    if (*temp == '\n') {
                        *temp = '\0';
                        break;
                    }
                    ++temp;
                }
            }
            if (!strncmp(load_string, "#output", 7)) {
                int pos = 7;
                while (load_string[pos] == ' ') pos++;
                if (load_string[pos] == '/') {
                    output_buf[0] = '\0'; // ignoring folder settings for absolute paths
                }
                strcpy(output_buf + strlen(output_buf), load_string + pos);

                char *temp = output_buf;
                while (*temp) {
                    if (*temp == '\n') {
                        *temp = '\0';
                        break;
                    }
                    ++temp;
                }
            }
        }
        fclose(file);

        printf("Requested tables output: %s\n", output_buf);

        if (!strncmp(output_buf + strlen(output_buf) - 7, ".tables", 7)) {
            output_buf[strlen(output_buf) - 7] = '\0';
        }

        command_type command = command_type::EVAL;
        auto requests = std::vector<MPI_Request>(NET_SIZE);
        auto task_limits = std::vector<int>(NET_SIZE, lim);
        auto leftover_jobs = std::list<int>{};
        for (i = 1; i < NET_SIZE; ++i) {
            tables_off = get_table_to_process(leftover_jobs, tables_amount);
            if (tables_off == -1) break; // nothing more to submit
            MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
            MPI_Send(&tables_off, 1, MPI_INT, i, DATA, MPI_COMM_WORLD);
            MPI_Irecv(answers[i], 2, MPI_INT, i, RESULT, MPI_COMM_WORLD, &requests[i]);
        }

        int new_NET_SIZE = i;
        if (i < NET_SIZE) {
            printf("Too many workers - shutting them down...\n");
            command = command_type::FINISH;
            for (; i < NET_SIZE; i++) {
                MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
            }
        }
        NET_SIZE = new_NET_SIZE;
        requests[0] = MPI_REQUEST_NULL;
        int res_i;

        MPI_Waitany(NET_SIZE, requests.data(), &res_i, MPI_STATUS_IGNORE);
        while (res_i != MPI_UNDEFINED) {
            int received_table_index = answers[res_i][0];
            if (answers[res_i][1] == FAIL) {
                leftover_jobs.push_back(received_table_index);
            }

            if (task_limits[res_i] > 0 && answers[res_i][1] != ALREADY_RESERVED) {
                --task_limits[res_i];
            }
            if (task_limits[res_i] == 0) {
                // this worker did all it could;
                // let's stop it and continue
                printf("Stopping worker %d\n", res_i);
                command = command_type::FINISH;
                MPI_Send(&command, 1, MPI_INT, res_i, COMMAND, MPI_COMM_WORLD);
                MPI_Waitany(NET_SIZE, requests.data(), &res_i, MPI_STATUS_IGNORE);
                continue;
            }

            tables_off = get_table_to_process(leftover_jobs, tables_amount);

            if (tables_off != -1) { // our limit of tasks
                command = command_type::EVAL;
                MPI_Send(&command, 1, MPI_INT, res_i, COMMAND, MPI_COMM_WORLD);
                MPI_Send(&tables_off, 1, MPI_INT, res_i, DATA, MPI_COMM_WORLD);
                MPI_Irecv(answers[res_i], 2, MPI_INT, res_i, RESULT, MPI_COMM_WORLD, &requests[res_i]);
            } else {
                command = command_type::FINISH;
                printf("Stopping worker %d (no tasks left)\n", res_i);
                MPI_Send(&command, 1, MPI_INT, res_i, COMMAND, MPI_COMM_WORLD);
            }
            MPI_Waitany(NET_SIZE, requests.data(), &res_i, MPI_STATUS_IGNORE);
        }
        printf("Finished all jobs\n");

        std::chrono::time_point<std::chrono::steady_clock> stop_time = std::chrono::steady_clock::now();

        printf("Your calculations took %.6lf seconds to run.\n",
               std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count());

        tables_off = get_table_to_process(leftover_jobs, tables_amount);
        if (tables_off != -1) {
            printf("Some tables where not created\n");
        }
    } else {
        /* Worker part below */
#ifdef WITH_DEBUG
        attach_handler();
#endif
        FILE *file;
        char config_filename[512];
        sprintf(config_filename, "%s.config", ARG_PATH.c_str());
        file = fopen(config_filename, "r");
        if (file == nullptr) {
            printf("No %s, exiting!\n", config_filename);
            return 1;
        }
        char load_string[1000] = "none";
        char masters_split_string[64] = "";
        char output_buf[128];
        output_buf[0] = '\0';
        char database[128] = "temp/db/";
        while (fgets(load_string, 1000, file)) {
            if (!strncmp(load_string, "#folder", 7)) {
                int pos = 7;
                while (load_string[pos] == ' ') pos++;
                strcpy(output_buf, load_string + pos);
                char *temp = output_buf;
                while (*temp) {
                    if (*temp == '\n') {
                        *temp = '\0';
                        break;
                    }
                    ++temp;
                }
            }
            if (!strncmp(load_string, "#database", 9)) {
                int pos = 9;
                while (load_string[pos] == ' ') pos++;
                strcpy(database, load_string + pos);
                char *temp = database;
                while (*temp) {
                    if (*temp == '\n') {
                        *temp = '\0';
                        break;
                    }
                    ++temp;
                }
                if (database[strlen(database) - 1] != '/') {
                    database[strlen(database) + 1] = '\0';
                    database[strlen(database)] = '/';
                }
            }
            if (!strncmp(load_string, "#output", 7)) {
                int pos = 7;
                while (load_string[pos] == ' ') pos++;
                if (load_string[pos] == '/') output_buf[0] = '\0'; // ignoring folder settings for absolute paths
                strcpy(output_buf + strlen(output_buf), load_string + pos);

                char *temp = output_buf;
                while (*temp) {
                    if (*temp == '\n') {
                        *temp = '\0';
                        break;
                    }
                    ++temp;
                }
            }
            if (!strncmp(load_string, "#masters", 8)) {
                unsigned int master_number_min = 0;
                unsigned int master_number_max = 0;

                size_t pos = 8;
                while (load_string[pos] == ' ') pos++;

                if (load_string[pos] == '|') {
                    // that's the split masters mode
                    const char *poss = load_string + pos;
                    ++poss;
                    while ((*poss) && (*poss != '|') && (*poss != '-')) ++poss;
                    if (!(*poss)) {
                        printf("Incorrect syntax for master file (no second |)\n");
                        abort();
                    }
                    if (*poss == '-') {
                        sscanf(load_string + pos, "|%u-%u|", &master_number_min, &master_number_max);
                    } else {
                        sscanf(load_string + pos, "|%u|", &master_number_min);
                        master_number_max = master_number_min;
                    }
                    if (!master_number_min) {
                        printf("Incorrect syntax for master file\n");
                        abort();
                    }
                    if (master_number_max < master_number_min) {
                        printf("Incorrect range of master integrals\n");
                        abort();
                    }
                    sprintf(masters_split_string, "-(%u-%u)", master_number_min, master_number_max);
                }
            }
        }
        fclose(file);

        if (!strncmp(output_buf + strlen(output_buf) - 7, ".tables", 7)) {
            output_buf[strlen(output_buf) - 7] = '\0';
        }
        command_type command;
        const int MASTER = 0;
        int result[2];
        int received_table;

        MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        while (command != command_type::FINISH) {
            MPI_Recv(&received_table, 1, MPI_INT, MASTER, DATA, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            result[0] = received_table; // table number
            std::string table_filename = output_buf;
            std::string arg_numbers =
                    "-" + std::to_string((received_table % P_INDEX) + 1); // because this is a special variable
            received_table /= P_INDEX;
            for (auto it = var_ranges.rbegin(); it != var_ranges.rend(); it++) { // TODO: Maybe there is more C++11 way
                arg_numbers.insert(0, "-" + std::to_string(it->indices[received_table % it->range]));
                received_table /= it->range;
            }
            table_filename += arg_numbers + masters_split_string + ".tables";
            arg_numbers.erase(0, 1); // remove leading dash
            int res = reserve_table(table_filename);
            if (res == ALREADY_RESERVED) {
                result[1] = ALREADY_RESERVED;
                MPI_Send(result, 2, MPI_INT, MASTER, RESULT, MPI_COMM_WORLD);
                MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                continue;
            } else if (res == FAILED_TO_RESERVE) {
                // FIXME: Here we should write more graceful shutdown for worker
                abort();
            }

// Prepare to execute child process
            char *run_args[16];
            char par1[16] = "--variables";
            char par3[8] = "--c";
            char par4[16] = "--parallel";
            char par5[16] = "--silent";
            if (NET_SIZE == 2) par5[0] = '\0';
            run_args[0] = EXEC_PATH;
            run_args[1] = par1;
            run_args[2] = const_cast<char *>(arg_numbers.c_str());
            run_args[3] = par3;
            run_args[4] = const_cast<char *>(ARG_PATH.c_str()); // this is because of execv legacy arguments type
            run_args[5] = par4;
            run_args[6] = par5;
            run_args[7] = nullptr;

            for (int i = 0; run_args[i] != nullptr; ++i) printf("%s ", run_args[i]);
            printf("\nSTARTING A TASK - %d-TH PROCESS\n", RANK);

            pid_t pid = fork();
            if (pid == -1) {
                printf("Error on fork\n");
                abort();
            }

            if (pid > 0) {
                // that's the parent process
                int status;
                waitpid(pid, &status, 0);
                if (WIFSIGNALED(status)) {
                    printf("TASK %d EXITED AFTER SIGNAL %d: %s\n", RANK, WTERMSIG(status), strsignal(WTERMSIG(status)));
                    result[1] = FAIL;
                } else if (!WIFEXITED(status)) {
                    printf("TASK %d EXITED WITH ERROR STATUS %d\n", RANK, status);
                    result[1] = FAIL;
                } else {
                    result[1] = WEXITSTATUS(status);
                    if (result[1]) {
                        printf("TASK %d ENDED WITH RETURN VALUE %d\n", RANK, WEXITSTATUS(status));
                    } else
                        printf("TASK %d ENDED SUCCESSFULLY\n", RANK);
                }
                if (cleanup_temp_files(table_filename, database, pid) == FAIL) {
                    abort();
                }
            } else {
                // that's the child process
                execv(EXEC_PATH, run_args);
                perror("execve");
                abort();
            }
            MPI_Send(result, 2, MPI_INT, MASTER, RESULT, MPI_COMM_WORLD);
            MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        }
    }
    MPI_Finalize();
    return 0;
}
