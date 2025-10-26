/**
 * @file mpi_wrapper.cpp
 * @author Alexander Smirnov
 *
 * This file is a part of the FIRE package.
 *
 * Used to launch and control result of work of many instances of FIRE7p and
 * have them run in parallel.
 */

#include <../../extra/fuel/usr/include/flint/fmpz_mpoly.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cstring>
#include <dirent.h>
#include <filesystem>
#include <fstream>
#include <getopt.h>
#include <iomanip>
#include <iostream>
#include <list>
#include <map>
#include <random>
#include <regex>
#include <sstream>
#include <string>
#include <sys/wait.h>
#include <thread>
#include <unistd.h>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "../handler.h"
#include "mpi.h"
#include "reconstruction.h"
#include "tables.h"
#include "tools.h"

namespace {
/**
 * MPI tag for command message.
 */
constexpr int COMMAND = 0;
/**
 * MPI tag for message with data.
 */
constexpr int DATA = 1;
/**
 * MPI tag for message with results of work.
 */
constexpr int RESULT = 2;
/**
 * Default string buffer size,
 */
constexpr int STR_SIZE = 256;
/**
 * Maximum index of a prime from primes.cpp
 */
constexpr int MAX_P_INDEX = 255;
} // namespace

std::string masters_split_string = {};  ///< the suffix due to partial masters in the table name
std::string path_to_tables = {};        ///< the starting part of table name
std::string database_path = "temp/db/"; ///< the place for temporary files
std::vector<std::string> vars_mpi;      ///< the variables

/**
 * The exponents switch limit for Tables saving
 */
int folders_limit_mpi = 0;

int thiele_limits_search_period = 1; ///< how often to try to reconstruct Thiele on limits detection stage

bool verbose_zippel = false; ///< whether to pass the verbose flag to zippel reconstruction

bool zippel_trules = false; ///< whether to use the trules format for Tables needed for zippel

bool no_integrity_check = false; ///< whether not to check the Tables for proper brackets

std::string external_option = ""; ///< the options that will be passed to external program

int zippel_parts = 0; ///< stores the number of parts used for zippel
                      ///< reconstruction to minimize memory usage
int thiele_parts = 0; ///< stores the number of parts used for thiele
                      ///< reconstruction to minimize memory usage

/**
 * Return Values for functions
 */
enum return_values { FAIL = -1, FAILED_TO_RESERVE = -1, SUCCESS = 0, ALREADY_RESERVED = 1 };

int starting_mpi_index = 1; ///< the index from which we have real MPI jobs
int NET_SIZE;               ///< MPI net size
int RANK;                   ///< MPI rank of the current process

int reconstruction_processes_per_node = 1; ///< the number of MPI processes per node participating in joint
                                           ///< reconstruction
int reconstruction_nodes = -1;             ///< the number of nodes participating in joint recosntruction

/**
 * Special struct, that describes what range covers given variable
 */
class InputVariable {
  public:
    int starting_value = 0;         ///< the value the indices start from
    int range = 0;                  ///< the index range
    std::string name = "";          ///< the name of the variable
    int newton_limit = 0;           ///< the limit for newton reconstruction needed in balanced
    bool geometric = false;         ///< whether this variable has geometric increase
    bool big_prime_initial = false; ///< whether the initial nummer is not the value but a prime number
    int zippel_limit = 0;           ///< the zippel limit for variables up to current

    /**
     * Return appropriate variable value with given shift
     * Depends on mode (geometric or not)
     * @param shift
     * @return value
     */
    std::string VariableValue(int shift) const {
        if (geometric) {
            return (big_prime_initial ? "p" : "") + std::to_string(starting_value) + "^" + std::to_string(shift + 1);
        } else {
            return std::to_string(starting_value + shift);
        }
    }
};

/**
 * Path to FIRE folder
 */
std::string FIRE_folder;

/**
 * Path to folder specified in config
 */
std::string folder;

/**
 * Path to prime reduction program
 */
std::string reduction_program = "FIRE7p";

/**
 * Path to multiprime reduction program folder
 */
std::string reduction_program_multu = "FIRE7mp";

/**
 * if additional arguments (in double quotation) need to be supplied to the
 * external program
 */
bool additional_args{false};

/**
 * string for additional arguments, like "arg1 arg2 arg3", to be split into
 * sub-strings and passed to the external program
 */
std::string additional_arg_string;

/**
 * Path to prime reduction program
 */
std::string plan = "";

/**
 * Default path to problem.
 */
std::string ARG_PATH{};

/**
 * How many indices should be reconstructed
 */
unsigned int reconstruction_limit = 0;

/**
 * The library that should be used for FIRE and reconstruction
 */
std::string library_name = "flint";

/**
 * Global to indicate that the master thread is also running a copy of FIRE
 */
bool master_running_FIRE = false;

/**
 * Global to indicate that we are using multitables runs (FIRE7mp)
 */
bool multitables_used = false;

/**
 * Global to indicate that Tables should be reserved before running FI-1*
 * usefull for multiple MPI jobs doing same
 */
bool reserve = false;

/**
 * Global to indicate that we are using the Zippel approach
 */
bool zippel = false;

/**
 * Global to indicate whether last variable is separated and can be
 * reconstructed with numeratorNewton
 */
bool last_separated = false;

/**
 * Self-made recursive directory removal function.
 * @param dirname full path
 * @return successfulness
 */
int remove_directory_recursively(const char *dirname) {
    DIR *dir;
    struct dirent *entry;
    char path[PATH_MAX];
    dir = opendir(dirname);
    if (dir == nullptr) {
        return 0;
    }

    while ((entry = readdir(dir)) != nullptr) {
        if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
            snprintf(path, (size_t)PATH_MAX, "%s/%s", dirname, entry->d_name);
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

    if (no_integrity_check) {
        if (std::filesystem::exists(filename)) {
            return ALREADY_RESERVED;
        } else {
            return SUCCESS;
        }
    }

    FILE *file;
    char buf[256];
    file = fopen(filename.c_str(), "r");
    if (file != nullptr) {
        int count_open = 0;
        int count_close = 0;
        int c;
        while ((c = getc(file)) != EOF) {
            count_open += (c == '{');
            count_close += (c == '}');
        }
        fclose(file);
        if (count_open != count_close) {
            printf("\nBROKEN TABLE, RERUNNING: %s\n\n", filename.c_str());
            return SUCCESS;
        } else if (count_open == 0 && !reserve) {
            printf("\bEMPTY TABLE, RERUNNING: %s\n\n", filename.c_str());
            return SUCCESS;
        }
        if (count_open == 0) {
            printf("Tables are reserved: %s\n", filename.c_str());
        } else {
            printf("Tables already exist: %s\n", filename.c_str());
        }
        return ALREADY_RESERVED;
    }

    if (reserve) {
        snprintf(buf, sizeof(buf), "touch '%s'", filename.c_str());
        if (system(buf)) {
            printf("Could not reserve Tables file");
            printf("%s\n", buf);
            return FAILED_TO_RESERVE;
        }
    }
    return SUCCESS;
}

/**
 * Recursively remove temporary files created during computation and table, if
 * it wasn't filled.
 * @param table_filename path to table to be checked
 * @param database_path path to temporary files
 * @param pid pid of FIRE executable, to identify temporary files belonged to
 * that process
 * @return result of cleanup
 */
int cleanup_temp_files(const std::string &table_filename, const std::string &database_path, pid_t pid) {
    FILE *file;
    file = fopen(table_filename.c_str(), "r");
    if (file != nullptr) {
        fgetc(file);
        if (feof(file)) {
            printf("Reserved Tables not created, deleting: %s\n", table_filename.c_str());
            if (remove(table_filename.c_str()) == -1) {
                printf("Could not delete temporary table data");
                return FAIL;
            }
        }
        fclose(file);
    }
    // now we need to remove temporary database_path after the child
    char hostname[64];
    char db_directory[256];
    gethostname(hostname, 64);
    snprintf(db_directory, sizeof(db_directory), "%s%s-%d", database_path.c_str(), hostname, pid);
    // printf("Removing %s\n", db_directory);
    remove_directory_recursively(db_directory);
    // printf("Removed %s\n", db_directory);
    return SUCCESS;
}

/**
 * Prints help on program usage
 * @param longOptions The struct containing options of the program
 */
void show_help_mpi(const option *longOptions) {
    std::cout << "Usage: FIRE7_MPI [options]\n";

    std::map<std::string, std::string> expl;
    expl.emplace("help", "Show this help.");
    expl.emplace("abort", "Abort when needed table is generated. Usefull to stop jobs "
                          "in case some of the mpi processes might be frozen");
    expl.emplace("calc", "Set calulation library, to be passed to FIRE and reconstruction");
    expl.emplace("tasks", "Set limit of jobs per worker. By default is unlimited");
    expl.emplace("config", "Path to file with config, one should omit extension '.config'");
    expl.emplace("delay", "Make a delay for a random number of seconds after start");
    expl.emplace("master", "Have master-thread also run a copy of FIRE");
    expl.emplace("reserve", "Reserve Tables with touch before running. Usefull "
                            "for multiple MPI jobs doing the same");
    expl.emplace("reconstruct", "Run recontruction after FIRE runs. The optional argument is "
                                "the number of reconstruction steps,");
    expl.emplace("newton_reconstruction_limits", "Set limits for Newton reconstruction ranges starting from "
                                                 "second variable (first does not need Newton). "
                                                 "Usefull since Thiele needs more. Underscore-separated values");
    expl.emplace("zippel", "Switch to Zippel reconstruction approach");
    expl.emplace("verbose_zippel", "To pass verbose flag to Zippel reconstruction");
    expl.emplace("last_separated", "Last variable is separated in the denominator, so can be "
                                   "reconstructed with numeratorNewton");
    expl.emplace("thiele_reconstruction_limits", "Set limits for Thiele reconstruction ranges. "
                                                 "Underscore-separated values");
    expl.emplace("rational_reconstruction_limit", "Set limit for the number of primes. Can be used like n:m to "
                                                  "use n..n+m-1");
    expl.emplace("initial_values_of_variables", "Set starting values of variables. Underscore-separated values");
    expl.emplace("geometric", "switch from consecutive (values are increased by "
                              "1) mode of seeding to geometric (powers taken)");
    expl.emplace("early_abortion", "Terminates if limits are unsufficient");
    expl.emplace("thiele_surplus", "Extra Tables for Thiele reconstruction compared with autodetection");
    expl.emplace("newton_surplus", "Extra Tables for Newton reconstruction compared with autodetection");
    expl.emplace("fixed_initial_values_of_variables", "Sets values for some variables like d_100,y_3");
    expl.emplace("skip_limit_detection", "Skip the stage detecting better limits");
    expl.emplace("delete_tables", "deletes Tables used for reconstruction after "
                                  "succsesfull reconstruction.");
    expl.emplace("multitables", "use multitables runs creating Tables with multiple results");
    expl.emplace("reconstruction_processes_per_node",
                 "the number of processes per node participating in joint reconstruction");
    expl.emplace("reconstruction_nodes", "the number nodes participating in joint reconstruction");
    expl.emplace("big_primes", "indication to use big primes for all basic initial values");
    expl.emplace("zippel_trules", "uses the trules format for Tables needed for Zippel that "
                                  "reduces filesystem load for Zippel recosntruction");
    expl.emplace("zippel_parts", "perform Zippel recosntruction with splitting the relations in "
                                 "parts to minimize memory usage");
    expl.emplace("thiele_parts", "perform Thiele recosntruction with splitting the relations in "
                                 "parts to minimize memory usage");
    expl.emplace("no_integrity_check", "do not check table files for brackets");
    expl.emplace("reduction_program", "provide path to alternative reduction program (not FIRE7p)");
    expl.emplace("reduction_program_args", "provide arguments to alternative reduction program");
    expl.emplace("folders", "Specify whether the Tables should be saved into a "
                            "subfolder depending on passed variables powers");
    expl.emplace("thiele_limits_search_period", "Specify how often to try Thiele recosntruction on limits "
                                                "detection stage. Default is meaning each run");
    expl.emplace("external", "use FIRE7np for reduction. The plan will be the requested "
                             "table name with .plan appended. Optional argument is the "
                             "option to be passed such as full_pivoting");

    for (auto current_option = longOptions; current_option->name != nullptr; ++current_option) {
        auto expl_itr = expl.find(current_option->name);
        std::string value;
        if (expl_itr != expl.end()) {
            value = expl_itr->second;
        } else {
            value = "NO EXPLANATION YET!";
        }
        printf("\t");
        size_t spaces = 0;
        if (current_option->val > 32) {
            printf("-%c", static_cast<char>(current_option->val));
            spaces += 2;
            if (current_option->has_arg == required_argument) {
                printf(" <value>");
                spaces += 8;
            } else if (current_option->has_arg == optional_argument) {
                printf(" <opt_value>");
                spaces += 12;
            }
            printf(", ");
            spaces += 2;
        }
        printf("--%s", current_option->name);
        spaces += 2;
        spaces += strlen(current_option->name);
        if (current_option->has_arg == required_argument) {
            printf(" <value>");
            spaces += 8;
        } else if (current_option->has_arg == optional_argument) {
            printf(" <opt_value>");
            spaces += 12;
        }
        while (spaces < 50) {
            printf(" ");
            ++spaces;
        }
        printf("\t");
        std::string info{value};
        info = std::regex_replace(info, std::regex("\n"), "\n\t");
        while (spaces) {
            info = std::regex_replace(info, std::regex("\n"), "\n ");
            --spaces;
        }
        info = std::regex_replace(info, std::regex("\n"), "\n\t");
        std::cout << info << std::endl;
    }
}

void run_worker_process(std::vector<InputVariable> var_ranges, bool quiet, int RANK, bool geometric,
                        bool additional_args = false);

std::string tables_path(const std::string &table_filename, const std::string &masters_split_string,
                        const std::vector<InputVariable> &variables, const std::vector<int> &indices, size_t var_count,
                        std::list<std::string> extra_indices);

/**
 * Indication that after reconstructing the needed table, it should call
 * mpi_abort
 */
bool abort_when_done = false;

/**
 *  A color for output printing
 */
class Color {
  public:
    /**
     * Black color
     * @return the chosen color
     */
    static const std::string &Black() {
        static const std::string value = "\033[30m";
        return value;
    }
    /**
     * White color
     * @return the chosen color
     */
    static const std::string &White() {
        static const std::string value = "\033[37m";
        return value;
    }
    /**
     * Red color
     * @return the chosen color
     */
    static const std::string &Red() {
        static const std::string value = "\033[31m";
        return value;
    }
    /**
     * Green color
     * @return the chosen color
     */
    static const std::string &Green() {
        static const std::string value = "\033[32m";
        return value;
    }
    /**
     * Blue color
     * @return the chosen color
     */
    static const std::string &Blue() {
        static const std::string value = "\033[34m";
        return value;
    }
    /**
     * Cyan color
     * @return the chosen color
     */
    static const std::string &Cyan() {
        static const std::string value = "\033[36m";
        return value;
    }
    /**
     * Magenta color
     * @return the chosen color
     */
    static const std::string &Magenta() {
        static const std::string value = "\033[35m";
        return value;
    }
    /**
     * Yellow color
     * @return the chosen color
     */
    static const std::string &Yellow() {
        static const std::string value = "\033[33m";
        return value;
    }
    /**
     * Code for resetting color change
     * @return the chosen color
     */
    static const std::string &Reset() {
        static const std::string value = "\033[0m";
        return value;
    }
};

/**
 *  Checks is a number follows in a string
 *  @param str the string being checked
 *  @return result of check
 */
bool is_number(const std::string &str) {
    if (str.empty()) {
        return false;
    }
    size_t startIndex = 0;
    if (str[0] == '-') {
        if (str.length() == 1) {
            return false;
        }
        startIndex = 1;
    }
    for (size_t i = startIndex; i < str.length(); ++i) {
        if (!std::isdigit(str[i])) {
            return false;
        }
    }
    return true;
}

/**
 * Class for working with variable settings such as ranges and Newton limits
 */
class Variables {
  private:
    std::vector<InputVariable> variables_;

  public:
    /**
     * Constructor
     * @param count the number of variables
     */
    Variables(int count) { variables_.resize(count); }

    /**
     * Use information on variable names
     * @param names the names
     * @return whether they were Fit succesfully
     */
    bool FitNames(const std::vector<std::string> &names) {
        if (names.empty()) {
            for (unsigned int i = 0; i < this->Size() - 1; ++i) {
                variables_[i].name = std::to_string(i + 1);
            }
            return true;
        }

        if (names.size() + 1 != variables_.size()) {
            return false;
        }
        for (unsigned int i = 0; i + 1 < this->Size(); ++i) {
            variables_[i].name = names[i];
        }
        variables_.back().name = "0";
        return true;
    }

    /**
     * Use information on Thiele reconstruction limits
     * @param thieleReconstructionLimits the Thiele reconstruction limits
     * @return whether they were Fit succesfully
     */
    bool FitThieleReconstructionLimits(const std::vector<int> &thieleReconstructionLimits) {
        if (thieleReconstructionLimits.size() + 1 != variables_.size()) {
            std::cout << "Thile limits size should be " << variables_.size() - 1 << std::endl;
            return false;
        }
        if (!std::all_of(thieleReconstructionLimits.begin(), thieleReconstructionLimits.end(),
                         [](int element) { return element > 0; })) {
            std::cout << "Thile limits should be positive " << std::endl;
            return false;
        }
        bool isFirst = true;
        for (unsigned int i = 0; i + 1 < this->Size(); ++i) {
            if (isFirst && thieleReconstructionLimits[i] > 1) {
                variables_[i].newton_limit = thieleReconstructionLimits[i];
                isFirst = false;
            }
            variables_[i].range = thieleReconstructionLimits[i];
        }
        return true;
    }

    /**
     * Use information on Newton reconstruction limits
     * @param newtonReconstructionLimits the Newton reconstruction limits
     * @return whether they were Fit succesfully
     */
    bool FitNewtonReconstructionLimits(const std::vector<int> &newtonReconstructionLimits) {
        if (newtonReconstructionLimits.size() + 1 != variables_.size()) {
            return false;
        }
        if (!std::all_of(newtonReconstructionLimits.begin(), newtonReconstructionLimits.end(),
                         [](int element) { return element >= 0; })) {
            return false;
        }
        for (unsigned int i = 0; i < this->Size() - 1; ++i) {
            if (newtonReconstructionLimits[i] == 0) {
                variables_[i].newton_limit = variables_[i].range;
            } else if (variables_[i].range > 1 && variables_[i].range < newtonReconstructionLimits[i]) {
                return false;
            } else {
                variables_[i].newton_limit = newtonReconstructionLimits[i];
            }
        }
        return true;
    }

    /**
     * Use information on Zippel reconstruction limits
     * @param zippelReconstructionLimits the Zippel reconstruction limits
     * @return whether they were Fit succesfully
     */
    bool FitZippelReconstructionLimits(const std::vector<int> &zippelReconstructionLimits) {
        if (zippelReconstructionLimits.size() + 1 != variables_.size()) {
            return false;
        }
        for (unsigned int i = 0; i < this->Size() - 1; ++i) {
            variables_[i].zippel_limit = zippelReconstructionLimits[i];
        }
        return true;
    }
    /**
     * Use information on rational reconstruction limit
     * @param rationalReconstructionStart the first prime index, 1 by default
     * @param rationalReconstructionLimit the rational reconstruction limit
     * @return whether they were Fit succesfully
     */
    bool FitRationalReconstructionLimit(int rationalReconstructionStart, int rationalReconstructionLimit) {
        if (rationalReconstructionLimit < 1) {
            return false;
        }
        if (rationalReconstructionStart < 1) {
            return false;
        }
        // last "variable" is the prime number
        variables_.back().starting_value = rationalReconstructionStart;
        variables_.back().geometric = false;

        variables_.back().range = rationalReconstructionLimit;
        variables_.back().newton_limit = rationalReconstructionLimit;

        return true;
    }

    /**
     * Use information on initial values of variables
     * @param initialValuesOfVariables the initial values of variables
     * @param geometric the mode
     * @param big_primes whether we are using initial large primes
     * @return whether they were Fit succesfully
     */
    bool FitValues(const std::vector<std::string> &initialValuesOfVariables, bool geometric, bool big_primes) {

        std::vector<int> some_primes = {41, 53, 67, 89, 101, 113, 149, 163};

        for (unsigned int i = 0; i + 1 < this->Size(); ++i) {
            if (initialValuesOfVariables[i] != "") {
                if (initialValuesOfVariables[i][0] == 'p') {
                    variables_[i].big_prime_initial = true;
                    variables_[i].starting_value = stoi(initialValuesOfVariables[i].substr(1));
                } else {
                    variables_[i].starting_value = stoi(initialValuesOfVariables[i]);
                }
            } else {
                if (big_primes) {
                    variables_[i].starting_value = i;
                    variables_[i].big_prime_initial = true;
                } else if (i < some_primes.size()) {
                    variables_[i].starting_value = some_primes[i];
                } else {
                    abort();
                }
            }
            if (geometric && variables_[i].range > 1) {
                variables_[i].geometric = true;
            }
        }

        return true;
    }

    /**
     * The number of variables
     * @return the number of variables
     */
    unsigned int Size() const { return variables_.size(); }

    /**
     * Getting the internal variables
     * @return the variables
     */
    std::vector<InputVariable> GetVariables() const { return variables_; }
};

/**
 * Update offsets in matrix for next FIRE7p invocation's arguments on the
 * initial stage
 * @param var_ranges the variable data
 * @param var_values return argument, used to put the result
 * @param done_mask the information on which variables are over with the Thiele
 * reconstruction
 * @returns true whether it finished and there are no more Tables left
 */
bool get_table_to_process_thiele(const std::vector<InputVariable> &var_ranges, std::vector<int> &var_values,
                                 std::vector<bool> &done_mask) {
    static bool is_finished_local = false;
    static int current_var_ind_ = 0;
    static std::vector<int> current_ind_;

    int var_count = var_ranges.size();

    if (current_ind_.empty()) {
        current_ind_.resize(var_count - 1, 0);
    }

    if (is_finished_local) {
        return true;
    }

    is_finished_local = true;
    for (int i = 0; i < static_cast<int>(current_ind_.size()); ++i) {
        if (current_ind_[i] < var_ranges[i].range) {
            is_finished_local = false;
            break;
        }
    }

    if (is_finished_local) {
        return true;
    }

    if (std::all_of(done_mask.begin(), done_mask.end(),
                [](bool x) { return x; })) {
        is_finished_local = true;
        return true;
    }

    std::fill(var_values.begin(), var_values.end(), 0);
    var_values[current_var_ind_] = current_ind_[current_var_ind_];

    for (int i = 0; i < var_count; ++i) {
        current_var_ind_ = (current_var_ind_ + 1) % (var_count - 1);
        if (!done_mask[current_var_ind_] && current_ind_[current_var_ind_] < var_ranges[current_var_ind_].range - 1) {
            if (multitables_used && current_ind_[current_var_ind_] != 0) {
                current_ind_[current_var_ind_] += MPRIME;
            } else {
                ++current_ind_[current_var_ind_];
            }
            return false;
        }
    }
    is_finished_local = true; // that was last step
    return false;
}

/**
 * Update offsets in matrix for next FIRE7p invocation's arguments.
 * @param var_ranges the variable data
 * @param var_values return argument, used to put the result
 * @param current_prime_index the prime we are reconstructing now
 * @param rec_index the index we are reconstructing now
 * @returns whether somthing is left
 */
bool get_table_to_process(const std::vector<InputVariable> &var_ranges, std::vector<int> &var_values,
                          int current_prime_index, int rec_index) {

    static int previous_prime_index = 0;
    static int previous_rec_index = 0;
    static int zippel_count = -1;
    static int thiele_count = -1;
    static bool seeded_random = false;
    static int var_count = var_ranges.size();
    static int extra_rec_index = 0;
    static std::vector<int> latest_var_steps_;
    static bool reconstruction_zippel_cycle = false;

    if (latest_var_steps_.empty()) {
        latest_var_steps_.resize(var_count, 0);
    }

    if (current_prime_index != previous_prime_index && current_prime_index != 0) {
        if (seeded_random) {
            seeded_random = false;
        } else {
            // random seed Point is alone, no multi
            seeded_random = true;
            // the prime number has just changed, we need to seed a random setting for
            // a check
            auto now = std::chrono::high_resolution_clock::now();
            std::random_device rd;                            // a seed source for the random number engine
            std::mt19937 gen(now.time_since_epoch().count()); // mersenne_twister_engine seeded with rd()
            std::uniform_int_distribution<> distrib(13, 666);
            for (int i = 0; i != var_count - 1; ++i) {
                if (var_ranges[i].range == 1) {
                    var_values[i] = 0;
                } else {
                    var_values[i] = distrib(gen);
                }
            }
            var_values[var_count - 1] = current_prime_index;
            var_values[var_count] = -2; // special indication that it's a random
            return true;
        }
    }

    if (zippel) {
        int first_nonsingle = 0;
        while (var_ranges[first_nonsingle].range == 1) {
            ++first_nonsingle;
        }
        if (rec_index < first_nonsingle) {
            rec_index = first_nonsingle;
        }
        if (current_prime_index != previous_prime_index || rec_index != previous_rec_index) {
            // zero is alone, no multi
            zippel_count = 1;
            // we well start next from zippel_count 1 since for zippel count 0 we
            // already had recosntruction by Thiele
            thiele_count = -1;
            // it will move to 0
            extra_rec_index = 0;
            previous_prime_index = current_prime_index;
            previous_rec_index = rec_index;
            std::fill(var_values.begin(), var_values.begin() + var_count - 1, 0);
            var_values[var_count - 1] = current_prime_index;
            var_values[var_count] = -1;
            reconstruction_zippel_cycle = false;
        } else {
            if (rec_index == first_nonsingle) {
                if (extra_rec_index < first_nonsingle) {
                    extra_rec_index = first_nonsingle;
                }
                if (extra_rec_index >= var_count - 1) {
                    return false;
                }
                // first variable but we seed all for Thiele
                if (multitables_used) {
                    if (thiele_count == -1) {
                        // it's -1 when we seeded 0, now we need to seed 1 on first variable
                        thiele_count = 1;
                    } else {
                        thiele_count += MPRIME;
                    }
                } else {
                    ++thiele_count;
                }
                if (thiele_count >= var_ranges[extra_rec_index].range) {
                    ++extra_rec_index;
                    while ((extra_rec_index < var_count - 1) && (var_ranges[extra_rec_index].range == 1)) {
                        ++extra_rec_index;
                    }
                    if (extra_rec_index == var_count - 1) {
                        return false;
                    }
                    thiele_count = 1; // on Thiele it will be 0 call alone and then we
                                      // start from shift 1 in multiprime too
                }
                std::fill(var_values.begin(), var_values.begin() + var_count - 1, 0);
                var_values[extra_rec_index] = thiele_count;
                var_values[var_count - 1] = current_prime_index;
                var_values[var_count] = -1;
            } else {
                // cycling through zippel_count and thiele_count
                ++thiele_count;
                auto tlimit = (last_separated && rec_index == var_count - 2 && zippel_count != 0)
                                  ? var_ranges[rec_index].newton_limit
                                  : var_ranges[rec_index].range;
                if (reconstruction_zippel_cycle) {
                    tlimit = 1;
                }
                if (thiele_count >= tlimit) {
                    if (zippel_count + (multitables_used ? MPRIME : 1) >= var_ranges[rec_index - 1].zippel_limit) {
                        // Zippel also reached it's limit
                        if (reconstruction_zippel_cycle) {
                            --thiele_count;
                            return false;
                        } else {
                            // now we will continue seeding one Point per zippel variant to
                            // recheck reconstructions
                            reconstruction_zippel_cycle = true;
                            zippel_count = 1;
                            thiele_count = 0;
                        }
                    } else {
                        thiele_count = 0;
                        if (multitables_used) {
                            zippel_count += MPRIME;
                        } else {
                            ++zippel_count;
                        }
                    }
                }
                for (int i = 0; i != rec_index; ++i) {
                    if (var_ranges[i].range != 1) {
                        var_values[i] = zippel_count;
                    } else {
                        var_values[i] = 0;
                    }
                }
                var_values[rec_index] = thiele_count;
                std::fill(var_values.begin() + rec_index + 1, var_values.begin() + var_count - 1, 0);
                var_values[var_count - 1] = current_prime_index;
                var_values[var_count] = rec_index; // sending stage to slaves
                                                   /*
                                                   std::stringstream s;
                                                   s << "Requesting {";
                                                   for (int i = 0; i != var_count - 1; ++i) {
                                                       s << var_values[i] << ", ";
                                                   }
                                                   s << var_values[var_count - 1] << "}" << std::endl;
                                                   std::cout << s.str() << std::endl;
                                                   */
            }
        }

    } else { // not zippel
        previous_prime_index = current_prime_index;
        previous_rec_index = rec_index;

        if (latest_var_steps_[var_count - 1] < current_prime_index) {
            for (int i = 0; i != var_count - 1; ++i) {
                latest_var_steps_[i] = 0;
            }
            latest_var_steps_[var_count - 1] = current_prime_index;
        } else {

            int allowed_index = rec_index;
            if (latest_var_steps_[var_count - 1] < current_prime_index) {
                // we increased the prime, should allow to change all indices
                allowed_index = var_count - 1;
            }
            int first_increased_index = 0;

            while ((first_increased_index < var_count - 1) && (latest_var_steps_[first_increased_index] == 0)) {
                ++first_increased_index;
            }
            // here it is equal to the first nonzero index
            if (latest_var_steps_[first_increased_index] < var_ranges[first_increased_index].newton_limit) {
                // now if it is not beyond newton limit, we reset it
                first_increased_index = 0;
            }

            int last_increased_index = first_increased_index;

            while (latest_var_steps_[last_increased_index] >= var_ranges[last_increased_index].range - 1) {
                ++last_increased_index;
                if (last_increased_index > allowed_index) {
                    if (last_increased_index >= var_count) {
                        std::cout << "NO MORE TABLES LEFT\n";
                    } else {
                        std::cout << "NOT ALLOWED TO SHIFT MORE\n";
                    }
                    return false;
                }
            }

            while (first_increased_index != last_increased_index) {
                latest_var_steps_[first_increased_index++] = 0;
            }
            ++latest_var_steps_[last_increased_index];
        }

        std::copy(latest_var_steps_.begin(), latest_var_steps_.end(), var_values.begin());
        var_values[var_count] = rec_index; // sending stage to slaves
    }
    return true;
}

/**
 * Update for which variables the initial stage is over
 * @param done_mask a vector of booleans storing information where the stage is
 * over
 * @param var_ranges the variables and theis settings
 * @param path_to_tables path to Tables files to be able to check them
 * @param masters_split_string suffix for masters
 * @return whether it finished for all variables
 */
bool update_done_mask(std::vector<bool> &done_mask, const std::vector<InputVariable> &var_ranges,
                      const std::string &path_to_tables, const std::string &masters_split_string) {
    unsigned int var_count = var_ranges.size();
    for (unsigned int i = 0; i < var_count - 1; ++i) {
        if (var_ranges[i].newton_limit <= 1 || var_ranges[i].range <= 1) {
            done_mask[i] = true;
        } else {
            std::list<std::string> set_vars;
            for (unsigned int j = 0; j != var_count; ++j) {
                if (i == j) {
                    set_vars.push_back(var_ranges[j].name);
                } else {
                    set_vars.push_back(var_ranges[j].VariableValue(0));
                }
            }
            std::string to_check =
                tables_path(path_to_tables, masters_split_string, var_ranges, std::vector<int>{}, 0, set_vars);
            to_check = subfolder_path(to_check, folders_limit_mpi);
            std::filesystem::path path_to_check(to_check);
            if (std::filesystem::exists(path_to_check)) {
                done_mask[i] = true;
            }
        }
    }
    return std::all_of(done_mask.begin(), done_mask.end(),
            [](bool x) { return x; });
}

/**
 * Update information on what thiele reconstruction limits should be based on
 * created tables
 * @param var_ranges the variables and theis settings
 * @param path_to_tables path to Tables files to be able to check them
 * @param early_abortion whether we are in early termination mode
 * @param masters_split_string suffix for masters
 * @return if false, the program should stop due to insufficient limits
 */
bool update_thiele_limits(std::vector<InputVariable> &var_ranges, const std::string &path_to_tables,
                          bool early_abortion, const std::string &masters_split_string) {
    unsigned int var_count = var_ranges.size();
    for (unsigned int i = 0; i < var_count - 1; ++i) {
        if (var_ranges[i].newton_limit <= 1 || var_ranges[i].range <= 1) {
            continue;
        } else {
            bool reconstructed = false;
            std::list<std::string> set_vars;
            for (unsigned int j = 0; j != var_count; ++j) {
                if (i == j) {
                    set_vars.push_back(var_ranges[j].name);
                } else {
                    set_vars.push_back(var_ranges[j].VariableValue(0));
                }
            }
            std::string to_check =
                tables_path(path_to_tables, masters_split_string, var_ranges, std::vector<int>{}, 0, set_vars);
            int minterms = 2;
            std::vector<std::string> params{
                FIRE_folder + "reconstruct", "--calc", library_name, "--method", "thiele", "--prime"};
            params.push_back(std::to_string(var_ranges[var_count - 1].starting_value));
            if (thiele_parts != 0) {
                params.push_back("--parts");
                params.push_back(std::to_string(thiele_parts));
            }
            if (multitables_used) {
                params.push_back("--multitables");
                params.push_back("--multitables_first");
                params.push_back("1");
            }
            if (folders_limit_mpi != 0) {
                params.push_back("--folders");
                params.push_back(std::to_string(folders_limit_mpi));
            }
            params.push_back("--parallel");
            params.push_back("--variables");
            params.push_back(var_ranges[i].name);
            params.push_back("--reconstruction_variable");
            params.push_back(var_ranges[i].name + "_" + std::to_string(var_ranges[i].starting_value));
            if (var_ranges[i].big_prime_initial) {
                params.push_back("--big_prime");
            }
            if (var_ranges[i].geometric) {
                params.push_back("--geometric");
            }
            params.push_back("--steps_as_error_code");
            params.push_back(to_check);
            params.push_back(std::to_string(var_ranges[i].range));
            pid_t pid;
            int result = run_process(params, 0, pid);
            if (result != 0 && result != 1) {
                if (result < 0) {
                    result += 256;
                }
                minterms = result + 1;
            } else {
                std::filesystem::path path_to_check(to_check);
                if (std::filesystem::exists(path_to_check)) {
                    Tables t;
                    std::ifstream f(to_check);
                    f >> t;
                    f.close();
                    for (const auto &relation : t.relations) {
                        for (const auto &term : relation.second) {
                            auto pair = numerator_denominator(term.second);
                            int curterms = exponent(pair.first, var_ranges[i].name) +
                                           exponent(pair.second, var_ranges[i].name) + 1;
                            if (curterms > minterms) {
                                minterms = curterms;
                            }
                        }
                    }
                }
            }
            for (int j = minterms; j <= var_ranges[i].range; ++j) {
                std::vector<std::string> params{
                    FIRE_folder + "reconstruct", "--calc", library_name, "--method", "thiele", "--prime"};
                params.push_back(std::to_string(var_ranges[var_count - 1].starting_value));
                if (thiele_parts != 0) {
                    params.push_back("--parts");
                    params.push_back(std::to_string(thiele_parts));
                }
                if (multitables_used) {
                    params.push_back("--multitables");
                    params.push_back("--multitables_first");
                    params.push_back("1");
                }
                if (folders_limit_mpi != 0) {
                    params.push_back("--folders");
                    params.push_back(std::to_string(folders_limit_mpi));
                }
                params.push_back("--parallel");
                params.push_back("--variables");
                params.push_back(var_ranges[i].name);
                params.push_back("--reconstruction_variable");
                params.push_back(var_ranges[i].name + "_" + std::to_string(var_ranges[i].starting_value));
                if (var_ranges[i].big_prime_initial) {
                    params.push_back("--big_prime");
                }
                if (var_ranges[i].geometric) {
                    params.push_back("--geometric");
                }
                params.push_back(to_check);
                params.push_back(std::to_string(j));
                pid_t pid;
                int result = run_process(params, 0, pid);
                if (!result) {
                    var_ranges[i].range = j;
                    if (i == 0) {
                        var_ranges[i].newton_limit = j;
                    }
                    reconstructed = true;
                    break;
                }
            }
            if (!reconstructed && early_abortion) {
                return false;
            }
        }
    }
    return true;
}

/**
 * Update information on what newton reconstruction limits should be based on
 * created tables
 * @param var_ranges the variables and theis settings
 * @param path_to_tables path to Tables files to be able to check them
 * @param early_abortion whether we are in early termination mode
 * @param masters_split_string suffix for masters
 * @return if false, the program should stop due to insufficient limits
 */
bool update_newton_limits(std::vector<InputVariable> &var_ranges, const std::string &path_to_tables,
                          bool early_abortion, const std::string &masters_split_string) {
    std::cout << "Updating Newton reconstruction limits...\n";
    auto start_time = std::chrono::steady_clock::now();
    bool is_good = true;
    unsigned int var_count = var_ranges.size();
    std::vector<bool> done_mask(var_count - 1, true);

    for (unsigned int i = 0; i < var_count - 1; ++i) {
        if (var_ranges[i].newton_limit <= 1 || var_ranges[i].range <= 1) {
            continue;
        } else {
            std::list<std::string> set_vars;
            for (unsigned int j = 0; j != var_count; ++j) {
                if (i == j) {
                    set_vars.push_back(var_ranges[j].name);
                } else {
                    set_vars.push_back(var_ranges[j].VariableValue(0));
                }
            }
            std::string to_check =
                tables_path(path_to_tables, masters_split_string, var_ranges, std::vector<int>{}, 0, set_vars);
            to_check = subfolder_path(to_check, folders_limit_mpi);
            std::filesystem::path path_to_check(to_check);
            if (std::filesystem::exists(path_to_check)) {
                std::ifstream inputFile(path_to_check);
                std::ostringstream buffer;
                buffer << inputFile.rdbuf();
                std::string table = buffer.str();
                inputFile.close();
                int new_limit = exponent(table, var_ranges[i].name) + 2;
                if (early_abortion && new_limit > var_ranges[i].newton_limit) {
                    is_good = false;
                    done_mask[i] = false;
                } else {
                    var_ranges[i].newton_limit = new_limit;
                }
                if (!zippel) {
                    remove(path_to_check); // for fair reconstruction on main stage
                }
            }
        }
    }
    if (!is_good) {
        std::cout << Color::Red() << "Early termination: Newton limits are insufficient." << Color::Reset()
                  << std::endl;
        std::cout << "To resolve this issue, consider increasing the limits for "
                     "the following variables:"
                  << std::endl;
        for (int i = 0; i < static_cast<int>(done_mask.size()) - 1; ++i) {
            if (!done_mask[i]) {
                std::cout << "- \"" << var_ranges[i].name << "\" "
                          << "variable at position " << i + 1 << std::endl;
            }
        }
        std::cout << std::endl;
    }
    auto stop_time = std::chrono::steady_clock::now();
    std::cout << "Time taken in updating Newton reconstruction limits: "
              << std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count() << std::endl;
    return is_good;
}

/**
 * Splits a given string into a vector of substrings based on the specified
 * delimiter
 * @param str the input string to be split
 * @param delimiter the character used to identify splitting points
 * @return a vector of substrings obtained by splitting the input string
 */
std::vector<std::string> split(const std::string &str, char delimiter) {
    std::vector<std::string> tokens;
    std::istringstream tokenStream(str);
    std::string token;
    while (std::getline(tokenStream, token, delimiter)) {
        tokens.push_back(token);
    }
    return tokens;
}

/**
 * Save information about limit into a file
 * The filename is the target Tables filename + .limits
 * @param path_to_tables starting part of table name
 * @param masters_split_string ending part of table name
 * @param var_ranges variables setup
 */
void save_limits(const std::string &path_to_tables, const std::string &masters_split_string,
                 const std::vector<InputVariable> &var_ranges) {
    size_t var_count = var_ranges.size();
    std::list<std::string> set_vars;
    for (unsigned int j = 0; j != var_count; ++j) {
        set_vars.push_back(var_ranges[j].name);
    }
    std::string filename =
        tables_path(path_to_tables, masters_split_string, var_ranges, std::vector<int>{}, 0, set_vars) + ".limits";

    std::ofstream fout(filename);
    fout << "Thiele ";
    for (unsigned int j = 0; j != var_count - 1; ++j) {
        fout << var_ranges[j].range << " ";
    }
    fout << std::endl;
    fout << "Newton ";
    for (unsigned int j = 0; j != var_count - 1; ++j) {
        fout << var_ranges[j].newton_limit << " ";
    }
    fout << std::endl;
    fout << "Zippel ";
    for (unsigned int j = 0; j != var_count - 1; ++j) {
        fout << var_ranges[j].zippel_limit << " ";
    }
    fout << std::endl;
    fout.close();
}

/**
 * Load information about limits from a file saved during a previous run
 * The filename is the target Tables filename + .limits
 * @param path_to_tables starting part of table name
 * @param masters_split_string ending part of table name
 * @param var_ranges variables setup
 */
void load_limits(const std::string &path_to_tables, const std::string &masters_split_string,
                 std::vector<InputVariable> &var_ranges) {
    size_t var_count = var_ranges.size();
    std::list<std::string> set_vars;
    for (unsigned int j = 0; j != var_count; ++j) {
        set_vars.push_back(var_ranges[j].name);
    }
    std::string filename =
        tables_path(path_to_tables, masters_split_string, var_ranges, std::vector<int>{}, 0, set_vars) + ".limits";
    std::ifstream fin;
    fin.open(filename);

    std::string word = "";
    fin >> word;
    if (!fin.good()) {
        return;
    }
    if (word != "Thiele") {
        std::cout << "ERROR!\n" << word << std::endl;
        return;
    }
    for (unsigned int j = 0; j != var_count - 1; ++j) {
        fin >> word;
        var_ranges[j].range = stoi(word);
    }
    fin >> word;
    if (word != "Newton") {
        std::cout << "ERROR!\n" << word << std::endl;
        return;
    }
    for (unsigned int j = 0; j != var_count - 1; ++j) {
        fin >> word;
        var_ranges[j].newton_limit = stoi(word);
    }
    fin >> word;
    if (word != "Zippel") {
        std::cout << "ERROR!\n" << word << std::endl;
        return;
    }
    for (unsigned int j = 0; j != var_count - 1; ++j) {
        fin >> word;
        var_ranges[j].zippel_limit = stoi(word);
    }
    fin.close();
}

/**
 * Checks if a requested stage is over, we reconstructed up to needed_stage
 * variables
 * @param path_to_tables starting part of table name
 * @param masters_split_string ending part of table name
 * @param var_ranges variables setup
 * @param early_abortion whether to abort is failed
 * @param needed_stage the requested stage
 * @param current_prime_index the prime index we are currently checking
 * reconstruction for
 * @return the real stage that is over
 */
size_t check_stage(const std::string &path_to_tables, const std::string &masters_split_string,
                   std::vector<InputVariable> &var_ranges, bool early_abortion, size_t needed_stage,
                   int current_prime_index) {
    size_t var_count = var_ranges.size();
    std::list<std::string> reconstructed_vars;
    std::vector<const char *> vars_vector;
    vars_vector.resize(var_count);
    size_t nvars = 0;
    for (unsigned int j = 0; j != var_count; ++j) {
        reconstructed_vars.push_back(var_ranges[j].name);
        if (var_ranges[j].range != 1) {
            vars_vector[nvars] = var_ranges[j].name.c_str();
            ++nvars;
        }
    }
    std::vector<int> zero_vars(var_count, 0);
    zero_vars[var_count - 1] = current_prime_index;
    std::string path_to_check;
    for (unsigned int j = 0; j != var_count - needed_stage + 1; ++j) {
        if (j == var_count) {
            break;
        }
        path_to_check = tables_path(path_to_tables, masters_split_string, var_ranges, zero_vars, j, reconstructed_vars);
        path_to_check = subfolder_path(path_to_check, folders_limit_mpi);
        std::cout << "Checking " << path_to_check << std::endl;
        if (std::filesystem::exists(path_to_check)) {
            std::cout << Color::Green() << std::endl
                      << "WE HAVE RECONSTRUCTED UP TO INDEX " << (var_count - j) << ":" << std::endl
                      << path_to_check << Color::Reset() << std::endl
                      << std::endl;
            std::list<std::string> set_vars;
            for (unsigned int j = 0; j != var_count; ++j) {
                set_vars.push_back(var_ranges[j].name);
            }
            std::string limits_filename =
                tables_path(path_to_tables, masters_split_string, var_ranges, std::vector<int>{}, 0, set_vars) +
                ".limits";
            bool limits_file_exists = std::filesystem::exists(limits_filename);
            if (zippel && j > 1 && (current_prime_index == 0 || var_ranges[var_count - j - 1].zippel_limit == 0)) {
                Tables t;
                std::ifstream f(path_to_check);
                f >> t;
                f.close();
                fmpz_mpoly_t res;
                fmpz_mpoly_ctx_t ctx;
                fmpz_mpoly_ctx_init(ctx, nvars, ORD_LEX);
                fmpz_mpoly_init(res, ctx);
                long max_terms = 1;
                for (const auto &relation : t.relations) {
                    for (const auto &term : relation.second) {
                        long terms;
                        auto pair = numerator_denominator(term.second);
                        fmpz_mpoly_set_str_pretty(res, pair.first.c_str(), &vars_vector[0], ctx);
                        terms = fmpz_mpoly_length(res, ctx);
                        if (terms > max_terms) {
                            max_terms = terms;
                        }
                        fmpz_mpoly_set_str_pretty(res, pair.second.c_str(), &vars_vector[0], ctx);
                        terms = fmpz_mpoly_length(res, ctx);
                        if (terms > max_terms) {
                            max_terms = terms;
                        }
                    }
                }
                fmpz_mpoly_clear(res, ctx);
                fmpz_mpoly_ctx_clear(ctx);
                std::cout << Color::Green() << std::endl
                          << "UPDATING ZIPPEL LIMIT UP TO INDEX " << var_count - j << ": "
                          << ((var_ranges[var_count - j - 1].zippel_limit == 0)
                                  ? ""
                                  : (std::to_string(var_ranges[var_count - j - 1].zippel_limit) + " -> "))
                          << max_terms << Color::Reset() << std::endl
                          << std::endl;
                var_ranges[var_count - j - 1].zippel_limit = max_terms;
                if (limits_file_exists) {
                    save_limits(path_to_tables, masters_split_string, var_ranges);
                }
            }
            return var_count - j;
        } else {
            reconstructed_vars.pop_back();
        }
    }
    if (needed_stage != 0) {
        // we needed to finish a stage but we did not
        std::cout << Color::Red() << std::endl
                  << "ERROR! WE COULD NOT RECONSTRUCT UP TO INDEX " << needed_stage << ":" << std::endl
                  << path_to_check << Color::Reset() << std::endl
                  << std::endl;
        if (early_abortion) {
            int command = 0;
            for (int i = starting_mpi_index; i < NET_SIZE; i++) {
                MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
            }
            MPI_Abort(MPI_COMM_WORLD, EXIT_SUCCESS);
        }
    }
    return needed_stage;
}

/**
 * Generate the data needed for reconstruction attempts with the current input
 * @param var_ranges the variable data
 * @param indices the current requested table indices
 * @param path_to_tables starting part of table name
 * @param masters_split_string suffix for masters
 * @param delete_tables whether we will be passing the --delete-tables option to
 * reconstruction
 * @param on_master whether the master node called it
 * @return a tuple containing call parameters, return code for master process
 * and resulting filename (or message starting with !)
 */
auto generate_reconstruction_runs(const std::vector<InputVariable> &var_ranges, const std::vector<int> &indices,
                                  const std::string &path_to_tables, const std::string &masters_split_string,
                                  bool delete_tables, bool on_master = false) {

    std::list<std::tuple<std::vector<std::string>, // the call parameters
                         int,                      // the code to return to master process in case of
                                                   // success
                         std::string               // the resulting filename
                         >>
        reconstruction_runs; // will be returned

    unsigned int var_count = var_ranges.size();

    std::list<std::string> set_vars_temp;
    for (unsigned int j = 0; j != var_count; ++j) {
        set_vars_temp.push_back(var_ranges[j].name);
    }
    std::string limits_filename =
        tables_path(path_to_tables, masters_split_string, var_ranges, std::vector<int>{}, 0, set_vars_temp) + ".limits";
    bool limits_file_exists = std::filesystem::exists(limits_filename);

    if (indices[var_count] == -2) {
        // that's a random seed coming
        std::vector<std::string> params{
            FIRE_folder + "substitute", "--calc", library_name, "--suffix", ".cand", "--config"};
        params.push_back(std::string{ARG_PATH});
        params.push_back("--variables");
        std::string arg_numbers =
            tables_path("", std::string{}, var_ranges, indices, var_count, std::list<std::string>{});
        params.push_back(arg_numbers);
        reconstruction_runs.emplace_back(params, 0, std::string{"!substituting values into a candidate"});

        params.clear();
        params.push_back(FIRE_folder + "diff");
        params.push_back("--calc");
        params.push_back(library_name);
        params.push_back("--variables");
        std::stringstream vars_mpi;
        for (unsigned int j = 0; j != var_count - 1; ++j) {
            if (var_ranges[j].range != 1) {
                vars_mpi << var_ranges[j].name << "_";
            }
        }
        std::string varss = vars_mpi.str();
        varss.pop_back(); // deleting last underscore
        params.push_back(varss);
        params.push_back("--prime");
        params.push_back(var_ranges[var_count - 1].VariableValue(indices[var_count - 1]));
        std::string requested_table =
            tables_path(path_to_tables, masters_split_string, var_ranges, indices, var_count, std::list<std::string>{});
        params.push_back(requested_table);
        params.push_back(requested_table + ".cand");
        reconstruction_runs.emplace_back(params, 0, std::string{"!comparing candidate and check table"});

        params.clear();
        if (std::filesystem::exists("/usr/bin/mv")) {
            params.push_back("/usr/bin/mv");
        } else {
            params.push_back("/bin/mv");
        }
        params.push_back(path_to_tables + ".tables.cand");
        std::list<std::string> set_indices;
        for (unsigned int j = 0; j != var_count; ++j) {
            set_indices.push_back(var_ranges[j].name);
        }
        std::string table_filename =
            tables_path(path_to_tables, masters_split_string, var_ranges, indices, 0, set_indices);
        params.push_back(table_filename);
        reconstruction_runs.emplace_back(params, var_count, table_filename);

        return reconstruction_runs;
    }

    unsigned int first_nonsingle = 0;
    while (var_ranges[first_nonsingle].range == 1) {
        ++first_nonsingle;
    }

    if (zippel) {
        std::list<std::string> set_indices;
        unsigned int current_stage = var_count;
        if (indices[var_count] == -1) {
            // auto detection
            for (unsigned int i = 0; i != var_count - 1; ++i) {
                if (indices[i] != 0) {
                    current_stage = i;
                }
            }
            if (current_stage == var_count) {
                return reconstruction_runs;
                // only for very first table, could not detect
            }
        } else {
            current_stage = indices[var_count];
        }
        if (current_stage < first_nonsingle) {
            current_stage = first_nonsingle;
        }
        unsigned int i = 0;
        // we try one reconstruction to get a thiele
        while (i != current_stage) {
            if (multitables_used && indices[var_count] != -1) {
                // that's a multi reconstruction by thiele or numerator_newton where
                // zippel indices are nonzero
                set_indices.push_back(var_ranges[i].VariableValue(indices[i]) + "+");
            } else {
                set_indices.push_back(var_ranges[i].VariableValue(indices[i]));
            }
            ++i;
        }
        set_indices.push_back(var_ranges[current_stage].name);
        auto table_filename = tables_path(path_to_tables, masters_split_string, var_ranges, indices,
                                          var_count - 1 - current_stage, set_indices);
        std::vector<std::string> params{FIRE_folder + "reconstruct", "--calc", library_name, "--method"};

        if (current_stage != first_nonsingle && last_separated && current_stage == var_count - 2 &&
            indices[first_nonsingle] != 0) {
            params.push_back("numeratorNewton");
            params.push_back("--all_tables_needed");
        } else {
            params.push_back("thiele");
            if (limits_file_exists) {
                params.push_back("--all_tables_needed");
            }
            if (!limits_file_exists && (indices[current_stage] % thiele_limits_search_period != 0)) {
                std::cout << "Skipping Thiele" << std::endl;
                return reconstruction_runs;
            }
            if (thiele_parts != 0) {
                params.push_back("--parts");
                params.push_back(std::to_string(thiele_parts));
            }
        }
        if (zippel_trules && current_stage != first_nonsingle && indices[first_nonsingle] != 0) {
            params.push_back("-T");
        }
        if (multitables_used && indices[var_count] == -1) {
            // in case of zippel runs the multicount is on Zippel and will be used
            // later with balancedZippelNewton but this is the first stage and we call
            // Thiele reconstruction with multitables
            params.push_back("--multitables");
            params.push_back("--multitables_first");
            params.push_back("1");
        }
        if (folders_limit_mpi != 0) {
            params.push_back("--folders");
            params.push_back(std::to_string(folders_limit_mpi));
        }
        params.push_back("--no_override"); // to prevent multiple zippel calls at same time
        params.push_back("--variables");
        params.push_back(var_ranges[current_stage].name);
        params.push_back("--reconstruction_variable");
        params.push_back(var_ranges[current_stage].name + "_" +
                         std::to_string(var_ranges[current_stage].starting_value));
        if (var_ranges[current_stage].big_prime_initial) {
            params.push_back("--big_prime");
        }
        params.push_back("--geometric");
        if (delete_tables) {
            params.push_back("--delete_tables");
            if (current_stage == first_nonsingle || indices[first_nonsingle] == 0) {
                params.push_back("1");
            }
        }
        params.push_back("--prime");
        params.push_back(var_ranges[var_count - 1].VariableValue(indices[var_count - 1]));
        params.push_back(table_filename);
        if (current_stage != first_nonsingle && last_separated && current_stage == var_count - 2 &&
            indices[first_nonsingle] != 0) {
            params.push_back(std::to_string(var_ranges[current_stage].newton_limit));
        } else {
            params.push_back(std::to_string(var_ranges[current_stage].range));
        }

        reconstruction_runs.emplace_back(params, (current_stage == first_nonsingle) ? first_nonsingle : 0,
                                         table_filename);

        if (current_stage == first_nonsingle) {
            // first index is only Thiele, no need for balancedZippelNewton
            ++current_stage;
        }

        set_indices.clear();
        for (unsigned int j = 0; j <= current_stage; ++j) {
            set_indices.push_back(var_ranges[j].name);
        }

        if (current_stage != var_count - 1) {
            if (var_ranges[current_stage - 1].zippel_limit != 0) {
                // now we need balancedZippelNewton for following tables
                table_filename = tables_path(path_to_tables, masters_split_string, var_ranges, indices,
                                             var_count - 1 - current_stage, set_indices);
                params = std::vector<std::string>{FIRE_folder + "reconstruct", "--calc",     library_name, "--method",
                                                  "balancedZippelNewton",      "--variables"};
                std::stringstream vars_mpi;
                for (unsigned int j = 0; j <= current_stage; ++j) {
                    if (var_ranges[j].range != 1) {
                        vars_mpi << var_ranges[j].name << "_";
                    }
                }
                std::string varss = vars_mpi.str();
                varss.pop_back(); // deleting last underscore
                params.push_back(varss);
                if (zippel_parts != 0) {
                    params.push_back("--parts");
                    params.push_back(std::to_string(zippel_parts));
                }
                if (zippel_trules) {
                    params.push_back("-t");
                }
                if (multitables_used) {
                    params.push_back("--multitables");
                    params.push_back("--multitables_first");
                    params.push_back("1");
                }
                if (folders_limit_mpi != 0) {
                    params.push_back("--folders");
                    params.push_back(std::to_string(folders_limit_mpi));
                }
                params.push_back("--all_tables_needed");
                params.push_back("--parallel_zippel");
                if (verbose_zippel) {
                    params.push_back("-V");
                }
                if (reconstruction_processes_per_node != 1) {
                    params.push_back("-R");
                    params.push_back(std::to_string(reconstruction_processes_per_node));
                }
                if (reconstruction_nodes != -1) {
                    params.push_back("-N");
                    params.push_back(std::to_string(reconstruction_nodes));
                }
                params.push_back("--balancing_variables");
                std::stringstream varsb;
                for (unsigned int j = 0; j != current_stage; ++j) {
                    if (var_ranges[j].range != 1) {
                        varsb << var_ranges[j].name << "_" << var_ranges[j].starting_value << ",";
                    }
                }
                varss = varsb.str();
                varss.pop_back();
                params.push_back(varss);
                params.push_back("--reconstruction_variable");
                params.push_back(var_ranges[current_stage].name + "_" +
                                 std::to_string(var_ranges[current_stage].starting_value) + "_" +
                                 std::to_string(var_ranges[current_stage].newton_limit));
                if (var_ranges[current_stage].big_prime_initial) {
                    params.push_back("--big_prime");
                }
                params.push_back("--geometric");
                params.push_back("--no_override");
                if (delete_tables) {
                    params.push_back("--delete_tables");
                }
                params.push_back("--prime");
                params.push_back(var_ranges[var_count - 1].VariableValue(indices[var_count - 1]));
                params.push_back(table_filename);
                params.push_back(std::to_string(var_ranges[current_stage - 1].zippel_limit));
                if (!on_master) {
                    params.clear();
                }
                reconstruction_runs.emplace_back(params, current_stage, table_filename);
            }
            ++current_stage;
            set_indices.push_back(var_ranges[current_stage].name);
        }

        if (current_stage == var_count - 1) {
            // and final rational
            table_filename = tables_path(path_to_tables, masters_split_string, var_ranges, indices, 0, set_indices);
            params = std::vector<std::string>{
                FIRE_folder + "reconstruct", "--calc", library_name, "--method", "rational", "--variables"};
            std::stringstream vars_mpi;
            for (unsigned int j = 0; j != var_count - 1; ++j) {
                if (var_ranges[j].range != 1) {
                    vars_mpi << var_ranges[j].name << "_";
                }
            }
            std::string varss = vars_mpi.str();
            varss.pop_back(); // deleting last underscore
            params.push_back(varss);
            if (delete_tables) {
                params.push_back("--delete_tables");
            }
            if (folders_limit_mpi != 0) {
                params.push_back("--folders");
                params.push_back(std::to_string(folders_limit_mpi));
            }
            params.push_back("--parallel");
            if (reconstruction_processes_per_node != 1) {
                params.push_back("-R");
                params.push_back(std::to_string(reconstruction_processes_per_node));
            }
            if (reconstruction_nodes != -1) {
                params.push_back("-N");
                params.push_back(std::to_string(reconstruction_nodes));
            }
            params.push_back("--unstable_filename");
            params.push_back(path_to_tables + ".tables.cand");
            params.push_back(table_filename);
            // shifted prime
            params.push_back(std::to_string(var_ranges[current_stage].starting_value) + ":" +
                             std::to_string(var_ranges[current_stage].newton_limit));
            if (!on_master) {
                params.clear();
            }
            reconstruction_runs.emplace_back(params, var_count, table_filename);
        }
        /*for (const auto &rec_run : reconstruction_runs) {
            std::cout << "Higher: " << std::get<2>(rec_run) << std::endl;
        }*/

    } else { // non-Zippel
        if (reconstruction_limit == 0) {
            return reconstruction_runs;
        }

        bool needed_for_balancing = false;
        unsigned int balancing_index = first_nonsingle; // if it remains first_nonsingle, then the table is not
                                                        // for balancing

        // even if we do not reconstruct, we check for reconstructed tables
        while ((balancing_index < var_count - 2) && (indices[balancing_index] == 0)) {
            // if the first variables are at starting indices, this will be used for
            // balancing
            ++balancing_index;
            needed_for_balancing = true;
            // maximal value reached is var_count - 2, in case of 2 indices
            // (varible and prime) it is 0, so no balancing. In case of 3
            // indices it is 1 if the first index is 0
        }
        if (needed_for_balancing && balancing_index == var_count - 2 && indices[balancing_index] == 0) {
            needed_for_balancing = false;
            balancing_index = first_nonsingle;
            // all zeros (except for prime possibly), we are not looking for higher
        }

        std::list<std::string> set_indices;
        unsigned int i = 0;
        while (i != first_nonsingle) {
            // that's a variable with one value, we ignore it for reconstructions
            set_indices.push_back(std::to_string(var_ranges[i].starting_value));
            ++i;
        }
        if (needed_for_balancing) {
            // we try one reconstruction to get a balancing table
            // we put values, then the name of the variable on place balancing_index
            while (i != balancing_index) {
                set_indices.push_back(var_ranges[i].VariableValue(indices[i]));
                ++i;
            }
            set_indices.push_back(var_ranges[balancing_index].name);
            auto table_filename = tables_path(path_to_tables, masters_split_string, var_ranges, indices,
                                              var_count - 1 - balancing_index, set_indices);
            std::vector<std::string> params{
                FIRE_folder + "reconstruct", "--calc", library_name, "--method", "thiele", "--variables"};
            if (!limits_file_exists && (indices[balancing_index] % thiele_limits_search_period != 0)) {
                std::cout << "Skipping Thiele" << std::endl;
                return reconstruction_runs;
            }
            params.push_back(var_ranges[balancing_index].name);
            if (thiele_parts != 0) {
                params.push_back("--parts");
                params.push_back(std::to_string(thiele_parts));
            }
            params.push_back("--reconstruction_variable");
            params.push_back(var_ranges[balancing_index].name + "_" +
                             std::to_string(var_ranges[balancing_index].starting_value));
            if (var_ranges[balancing_index].big_prime_initial) {
                params.push_back("--big_prime");
            }
            if (folders_limit_mpi != 0) {
                params.push_back("--folders");
                params.push_back(std::to_string(folders_limit_mpi));
            }
            if (var_ranges[balancing_index].geometric) {
                params.push_back("--geometric");
            }
            if (delete_tables) {
                params.push_back("--delete_tables");
                // that's a thiele reconstruction not for first variable. The Tables can
                // be needed again for reconstruction, deleting only higher ones
                params.push_back(std::to_string(var_ranges[balancing_index].newton_limit));
            }
            if (i != var_count - 1) {
                params.push_back("--prime");
                params.push_back(var_ranges[var_count - 1].VariableValue(indices[var_count - 1]));
            }
            params.push_back(table_filename);
            params.push_back(std::to_string(var_ranges[balancing_index].range));

            reconstruction_runs.emplace_back(params, 0, table_filename); // we do not ignore extra jobs after
                                                                         // reconstructing a balancing table
            // after balancing we can try balanced
            set_indices.clear();
            for (unsigned int j = 0; j != balancing_index; ++j) {
                set_indices.push_back(var_ranges[j].name);
            }
        }

        for (; i < reconstruction_limit; ++i) {
            set_indices.push_back(var_ranges[i].name);

            if (var_ranges[i].range != 1) {
                auto table_filename = tables_path(path_to_tables, masters_split_string, var_ranges, indices,
                                                  var_count - 1 - i, set_indices);

                std::vector<std::string> params{FIRE_folder + "reconstruct", "--calc", library_name, "--method"};
                if (i == var_count - 1) {
                    params.push_back("rational");
                    if (folders_limit_mpi != 0) {
                        params.push_back("--folders");
                        params.push_back(std::to_string(folders_limit_mpi));
                    }
                    params.push_back("--variables");
                    std::stringstream vars_mpi;
                    for (unsigned int j = 0; j != var_count - 1; ++j) {
                        if (var_ranges[j].range != 1) {
                            vars_mpi << var_ranges[j].name << "_";
                        }
                    }
                    std::string varss = vars_mpi.str();
                    varss.pop_back(); // deleting last underscore
                    params.push_back(varss);
                    params.push_back("--unstable_filename");
                    params.push_back(path_to_tables + ".tables.cand");
                } else {
                    if (i == first_nonsingle) {
                        // first variable is thiele
                        params.push_back("thiele");
                        if (!limits_file_exists && (indices[i] % thiele_limits_search_period != 0)) {
                            std::cout << "Skipping Thiele" << std::endl;
                            return reconstruction_runs;
                        }
                        if (thiele_parts != 0) {
                            params.push_back("--parts");
                            params.push_back(std::to_string(thiele_parts));
                        }
                    } else {
                        params.push_back("balancedNewton");
                        params.push_back("--balancing_variables");
                        std::stringstream vars_mpi;
                        for (unsigned int j = 0; j != i; ++j) {
                            if (var_ranges[j].range != 1) {
                                // special variable with 1 index, skipped
                                vars_mpi << var_ranges[j].name << "_" << var_ranges[j].starting_value << ",";
                            }
                        }
                        std::string varss = vars_mpi.str();
                        varss.pop_back();
                        params.push_back(varss);
                    }
                    if (i != var_count - 1) {
                        params.push_back("--prime");
                        params.push_back(var_ranges[var_count - 1].VariableValue(indices[var_count - 1]));
                    }
                    params.push_back("--variables");
                    std::stringstream vars_mpi;
                    for (unsigned int j = 0; ((j != i + 1) && j != (var_count - 1)); ++j) {
                        // up to the index being reconstructed, but last is modular, it is
                        // not a variable
                        if (var_ranges[j].range != 1) {
                            // special variable with 1 index, skipped
                            vars_mpi << var_ranges[j].name << "_";
                        }
                    }
                    std::string varss = vars_mpi.str();
                    varss.pop_back(); // deleting last underscore
                    params.push_back(varss);
                    params.push_back("--reconstruction_variable");
                    params.push_back(var_ranges[i].name + "_" + std::to_string(var_ranges[i].starting_value));
                    if (var_ranges[i].big_prime_initial) {
                        params.push_back("--big_prime");
                    }
                    if (var_ranges[i].geometric) {
                        params.push_back("--geometric");
                    }
                }
                if (delete_tables) {
                    params.push_back("--delete_tables");
                    if (i == var_count - 1) {
                        // that's rational, we delete all (default)
                    } else if (i == first_nonsingle) {
                        // that's thiele on first variable, we need to keep first table
                        params.push_back("1");
                    } else {
                        // that's balancedNewton, we can delete all, but keep first replaced
                        params.push_back("0_1");
                    }
                }
                params.push_back(table_filename);

                if (i == first_nonsingle) {
                    // thiele
                    params.push_back(std::to_string(var_ranges[balancing_index].range));
                } else if (i == var_count - 1) {
                    // shifted prime
                    params.push_back(std::to_string(var_ranges[i].starting_value) + ":" +
                                     std::to_string(var_ranges[i].newton_limit));
                } else {
                    // balanced newton
                    params.push_back(std::to_string(var_ranges[i].newton_limit));
                }
                reconstruction_runs.emplace_back(params, i + 1, table_filename);
            }
        }
    }

    return reconstruction_runs;
}

/**
 * Tries a reconstruction at master node
 * @param var_ranges the variable settings
 * @param indices the indices passed to produce reconstruction commands
 * @param path_to_tables table start (without suffix or indices). If empty, no
 * first undescore is added, used for preapring option for FIRE run
 * @param masters_split_string ending related to split masters mode
 * @param delete_tables whether to delete Tables after success
 * @param NET_SIZE the number of nodes participating in reconstruction
 * @return return code from reconstruction call
 */
int try_master_reconstruction(const std::vector<InputVariable> &var_ranges, std::vector<int> &indices,
                              const std::string &path_to_tables, const std::string &masters_split_string,
                              bool delete_tables, int NET_SIZE) {

    int command = 6;
    unsigned int var_count = var_ranges.size();
    for (int slave = 1; slave != NET_SIZE; ++slave) {
        // we are sending commands to participate in reconstruction to all slaves
        MPI_Send(&command, 1, MPI_INT, slave, COMMAND, MPI_COMM_WORLD);
        MPI_Send(indices.data(), var_count + 3, MPI_INT, slave, DATA, MPI_COMM_WORLD);
    }

    // a barrier is needed here so that the file is completely saved by other
    // process
    MPI_Barrier(MPI_COMM_WORLD);

    auto reconstruction_runs =
        generate_reconstruction_runs(var_ranges, indices, path_to_tables, masters_split_string, delete_tables, true);
    // we will need reconstruction run that is passed to master for zippel
    int reconstruction_result = 0;
    int reconstruction_number = 0;
    int needed_reconstruction_number = indices[var_ranges.size() + 2];
    bool had_barrier = false;
    std::cout << "Trying reconstruction number " << needed_reconstruction_number << " of "
              << reconstruction_runs.size() - 1 << std::endl;
    for (const auto &[params, return_code, reconstructed_table_filename] : reconstruction_runs) {
        if (reconstruction_number == needed_reconstruction_number) {
            if (std::filesystem::exists(subfolder_path(reconstructed_table_filename, folders_limit_mpi))) {
                printf("Reconstructed Tables already exist: %s\n", reconstructed_table_filename.c_str());
                // break; // this way we will check all but use highest
            } else {
                // we want to run reconstruction without forking and starting a process
                char *run_args[32];
                unsigned int i = 0;
                while (i != params.size()) {
                    // const_cast due to old style of execv syntax
                    run_args[i] = const_cast<char *>(params[i].c_str());
                    ++i;
                }
                run_args[i] = nullptr;
                printf("INTERNALLY CALLING (%d): ", RANK);
                for (i = 0; run_args[i] != nullptr; ++i)
                    printf("%s ", run_args[i]);
                printf("\n");
                optind = 0;
                auto start_time = std::chrono::steady_clock::now();
                reconstruction_result = reconstruct(params.size(), run_args, 0, NET_SIZE);
                if (!had_barrier) {
                    had_barrier = true;
                    MPI_Barrier(MPI_COMM_WORLD); // barrier for proper printing if main
                                                 // process is not participating
                }
                auto stop_time = std::chrono::steady_clock::now();
                printf("INTERNAL CALL (%d) ended with return value %d after %f seconds\n", RANK, reconstruction_result,
                       std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count());
            }
        }
        ++reconstruction_number;
    }
    if (!had_barrier) {
        had_barrier = true;
        MPI_Barrier(MPI_COMM_WORLD); // barrier for proper printing if main process
                                     // is not participating
    }
    return reconstruction_result;
}

/**
 * Run a system command and get output
 * @param cmd the command
 * @return joined resulting output
 */
std::string exec_command(const char *cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, std::function<int(FILE * __stream)>> pipe(popen(cmd, "r"), pclose);
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    return result;
}

/**
 * Entry Point for mpi_wrapper.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return successfullness
 */
int main(int argc, char *argv[]) {
    // int NET_SIZE, RANK, tmp;
    int provided = 0;
    int requested = MPI_THREAD_SINGLE;
    if (master_running_FIRE)
        requested = MPI_THREAD_MULTIPLE;
    MPI_Init_thread(&argc, &argv, requested, &provided);
    bool delete_tables_setting = false;

    if (provided < requested) {
        if (RANK == 0) {
            std::cout << "MPI requested thread safety " << requested << " was not obtained, only " << provided
                      << ", exiting." << std::endl;
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    MPI_Comm_rank(MPI_COMM_WORLD, &RANK);
    MPI_Comm_size(MPI_COMM_WORLD, &NET_SIZE);
    bool big_primes = false;
    zippel_trules = false;
    bool external = false;
    struct option longOptions[] = {{"help", no_argument, nullptr, 'h'},
                                   {"abort", no_argument, nullptr, 'a'},
                                   {"master", no_argument, nullptr, 'm'},
                                   {"calc", required_argument, nullptr, 'l'},
                                   {"reconstruct", optional_argument, nullptr, 'r'},
                                   {"config", required_argument, nullptr, 'c'},
                                   {"tasks", required_argument, nullptr, 't'},
                                   {"delay", required_argument, nullptr, 'd'},
                                   {"delete_tables", no_argument, nullptr, 'D'},
                                   {"big_primes", no_argument, nullptr, 'B'},
                                   {"zippel_trules", no_argument, nullptr, 'z'},
                                   {"reserve", no_argument, nullptr, 3},
                                   {"zippel", optional_argument, nullptr, 'Z'},
                                   {"verbose_zippel", optional_argument, nullptr, 'V'},
                                   {"last_separated", no_argument, nullptr, 'S'},
                                   {"skip_limit_detection", no_argument, nullptr, 's'},
                                   {"thiele_reconstruction_limits", required_argument, nullptr, 'T'},
                                   {"thiele_surplus", required_argument, nullptr, 1},
                                   {"newton_reconstruction_limits", required_argument, nullptr, 'N'},
                                   {"newton_surplus", required_argument, nullptr, 2},
                                   {"rational_reconstruction_limit", required_argument, nullptr, 'P'},
                                   {"initial_values_of_variables", required_argument, nullptr, 'I'},
                                   {"fixed_initial_values_of_variables", required_argument, nullptr, 'F'},
                                   {"reconstruction_processes_per_node", required_argument, nullptr, 4},
                                   {"reconstruction_nodes", required_argument, nullptr, 5},
                                   {"no_integrity_check", no_argument, nullptr, 6},
                                   {"geometric", no_argument, nullptr, 'G'},
                                   {"early_abortion", no_argument, nullptr, 'E'},
                                   {"multitables", no_argument, nullptr, 'M'},
                                   {"external", optional_argument, nullptr, 'e'},
                                   {"reduction_program", required_argument, nullptr, 'R'},
                                   {"reduction_program_args", required_argument, nullptr, 'A'},
                                   {"folders", required_argument, nullptr, 'f'},
                                   {"zippel_parts", required_argument, nullptr, 7},
                                   {"thiele_parts", required_argument, nullptr, 9},
                                   {"thiele_limits_search_period", required_argument, nullptr, 8},
                                   {nullptr, 0, nullptr, 0}};
    if (!master_running_FIRE && (NET_SIZE < 2)) {
        if (RANK == 0) {
            std::cout << "At least 2 processes are needed if the master process is not "
                      << "running FIRE!" << std::endl;
            for (int i = 0; i != argc; ++i) {
                if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
                    show_help_mpi(longOptions);
                    break;
                }
            }
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    if (RANK == 0) {
        std::cout << "Running with " << NET_SIZE - 1 + master_running_FIRE << " worker-processes" << std::endl;
        for (int count = 0; count != argc; ++count) {
            std::cout << argv[count] << " ";
        }
        std::cout << std::endl;
    }

    FIRE_folder = std::string(argv[0]);
    int extra_name_length = 0;
    if (FIRE_folder[FIRE_folder.size() - 1] == 'U') {
        // GPU
        extra_name_length = 4;
    }
    FIRE_folder = FIRE_folder.substr(0, FIRE_folder.size() - strlen("FIRE7_MPI") - extra_name_length);

    if (RANK == 0) {
        cout << "Path: " << FIRE_folder << endl;
        char sys_command[128];
        snprintf(sys_command, sizeof(sys_command), "cd %s && git log --oneline -1 2>/dev/null", FIRE_folder.c_str());
        string version = exec_command(sys_command);
        if (version == "")
            cout << "Cannot get version, git not available." << endl;
        else
            cout << "Version: " << version;
    }

    std::chrono::time_point<std::chrono::steady_clock> start_time = std::chrono::steady_clock::now();
    int lim = -1; // maximal number of runs, 0 will lead to infinity
    int option_index = 0;
    int c = 0;
    int delay = 0;
    bool help_flag = false;
    bool skip_limit_detection = false;

    std::vector<int> thiele_reconstruction_limits;
    std::vector<int> zippel_reconstruction_limits;
    std::vector<int> thiele_surplus;
    std::vector<int> newton_reconstruction_limits;
    std::vector<int> newton_surplus;

    constexpr int DEFAULT = 128;
    int rational_reconstruction_limit = DEFAULT;
    std::vector<std::string> initial_values_of_variables;
    std::unordered_map<std::string, int> fixed_initial_values_of_variables;
    bool early_abortion = false;
    bool geometric = false;
    int rational_reconstruction_start = 1;

    std::stringstream shortOptions;
    for (auto current_option = longOptions; current_option->name != nullptr; ++current_option) {
        if (current_option->val > 32) {
            shortOptions << static_cast<char>(current_option->val);
            if (current_option->has_arg == required_argument) {
                shortOptions << ':';
            } else if (current_option->has_arg == optional_argument) {
                shortOptions << "::";
            }
        }
    }

    while ((c = getopt_long(argc, argv, shortOptions.str().c_str(), longOptions, &option_index)) != -1) {
        switch (c) {
        case 0:
            break;
        case 'h':
            help_flag = true;
            break;
        case 3:
            reserve = true;
            break;
        case 8:
            thiele_limits_search_period = stoi(optarg);
            break;
        case 'M':
            multitables_used = true;
            break;
        case 'B':
            big_primes = true;
            break;
        case 'z':
            zippel_trules = true;
            break;
        case 'V':
            verbose_zippel = true;
            break;
        case 'f':
            folders_limit_mpi = stoi(optarg);
            break;
        case 'S':
            last_separated = true;
            break;
        case 6:
            no_integrity_check = true;
            break;
        case 7:
            zippel_parts = stoi(optarg);
            break;
        case 9:
            thiele_parts = stoi(optarg);
            break;
        case 'Z': {
            if (optarg == nullptr && optind < argc && argv[optind][0] != '-' &&
                std::string(argv[optind]).find(";") == std::string::npos) {
                optarg = argv[optind++];
            }
            zippel_reconstruction_limits.clear();
            if (optarg != nullptr) {
                std::istringstream iss(optarg);
                std::string value;
                while (getline(iss, value, '_')) {
                    zippel_reconstruction_limits.push_back(std::stoi(value));
                }
            }
            zippel = true;
            geometric = true;
        } break;
        case 'D':
            delete_tables_setting = true;
            break;
        case 'a':
            abort_when_done = true;
            break;
        case 'm':
            master_running_FIRE = true;
            break;
        case 's':
            skip_limit_detection = true;
            break;
        case 'r':
            if (optarg == nullptr && optind < argc && argv[optind][0] != '-' &&
                std::string(argv[optind]).find(";") == std::string::npos) {
                optarg = argv[optind++];
            }
            if (optarg == nullptr) {
                reconstruction_limit = 100; // not limited, to receive real value later
            } else {
                reconstruction_limit = std::stoi(optarg);
            }
            break;
        case 'c':
            ARG_PATH = optarg;
            break;
        case 'e':
            reduction_program = "FIRE7np";
            reduction_program_multu = "FIRE7mnp";
            external = true;
            if (optarg == nullptr && optind < argc && argv[optind][0] != '-' &&
                std::string(argv[optind]).find(";") == std::string::npos) {
                optarg = argv[optind++];
            }
            if (optarg != nullptr) {
                external_option = optarg;
            }
            break;
        case 'R':
            reduction_program = optarg;
            break;
        case 'A':
            additional_args = true;
            additional_arg_string = std::string(optarg);
            break;
        case 't':
            lim = std::stoi(optarg);
            break;
        case 4:
            reconstruction_processes_per_node = std::stoi(optarg);
            break;
        case 5:
            reconstruction_nodes = std::stoi(optarg);
            break;
        case 'l':
            library_name = std::string(optarg);
            break;
        case 'd':
            delay = std::stoi(optarg);
            break;
        case 'T': {
            thiele_reconstruction_limits.clear();
            std::istringstream iss(optarg);
            std::string value;
            while (getline(iss, value, '_')) {
                thiele_reconstruction_limits.push_back(std::stoi(value));
            }
        } break;
        case 1: {
            thiele_surplus.clear();
            std::istringstream iss(optarg);
            std::string value;
            while (getline(iss, value, '_')) {
                thiele_surplus.push_back(std::stoi(value));
            }
        } break;
        case 'N': {
            newton_reconstruction_limits.clear();
            std::istringstream iss(optarg);
            std::string value;
            while (getline(iss, value, '_')) {
                newton_reconstruction_limits.push_back(std::stoi(value));
            }
        } break;
        case 2: {
            newton_surplus.clear();
            std::istringstream iss(optarg);
            std::string value;
            while (getline(iss, value, '_')) {
                newton_surplus.push_back(std::stoi(value));
            }
        } break;
        case 'P': {
            auto range = std::string(optarg);
            auto posS = range.find(":");
            if (posS != std::string::npos) {
                rational_reconstruction_start = std::stoi(range);
                range = range.substr(posS + 1);
            }
            rational_reconstruction_limit = std::stoi(range);
        } break;
        case 'I': {
            initial_values_of_variables.clear();
            std::istringstream iss(optarg);
            std::string value;
            while (getline(iss, value, '_')) {
                initial_values_of_variables.push_back(value);
            }
        } break;
        case 'F': {
            fixed_initial_values_of_variables.clear();
            std::istringstream iss(optarg);
            std::string variable;
            while (getline(iss, variable, ',')) {
                size_t pos = variable.find('_');
                if (pos != std::string::npos) {
                    fixed_initial_values_of_variables[variable.substr(0, pos)] = std::stoi(variable.substr(pos + 1));
                }
            }
        } break;
        case 'G':
            geometric = true;
            break;
        case 'E':
            early_abortion = true;
            break;
        default:
            MPI_Finalize();
            return EXIT_FAILURE;
        }
        option_index = 0;
    }

    if (help_flag) {
        if (RANK == 0) {
            show_help_mpi(longOptions);
        }
        MPI_Finalize();
        return EXIT_SUCCESS;
    }

    if (ARG_PATH.empty()) {
        if (RANK == 0) {
            std::cout << "Missing --config/-c option! Exiting..." << std::endl;
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }

    if (multitables_used && !zippel) {
        multitables_used = false;
        if (RANK == 0) {
            std::cout << "Multitables option works only together with Zippel" << std::endl;
        }
    }

    if (!parse_config(ARG_PATH + ".config", folder, path_to_tables, masters_split_string, database_path, vars_mpi)) {
        MPI_Finalize();
        return EXIT_FAILURE;
    }

    if (!thiele_reconstruction_limits.empty() &&
        fixed_initial_values_of_variables.size() + thiele_reconstruction_limits.size() != vars_mpi.size()) {
        if (RANK == 0) {
            std::cout << "Error: Inconsistent variable vector sizes." << std::endl;
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    if (thiele_reconstruction_limits.empty()) {
        constexpr int DEFAULT = 1024;
        thiele_reconstruction_limits =
            std::vector<int>(vars_mpi.size() - fixed_initial_values_of_variables.size(), DEFAULT);
    }
    if (newton_reconstruction_limits.empty()) {
        newton_reconstruction_limits =
            std::vector<int>(vars_mpi.size() - fixed_initial_values_of_variables.size() - 1, 0);
    }
    if (zippel_reconstruction_limits.empty()) {
        zippel_reconstruction_limits =
            std::vector<int>(vars_mpi.size() - fixed_initial_values_of_variables.size() - 1, 0);
    }
    std::unordered_map<std::string, int> tempNameToInd;
    for (int i = 0; i < static_cast<int>(vars_mpi.size()); ++i) {
        tempNameToInd[vars_mpi[i]] = i;
    }
    std::vector<std::string> extended_initial_values_of_variables(vars_mpi.size(), "");
    for (const auto &[name, value] : fixed_initial_values_of_variables) {
        extended_initial_values_of_variables[tempNameToInd[name]] = value;
        vars_mpi[tempNameToInd[name]] = std::to_string(value);
        tempNameToInd.erase(name);
    }
    std::vector<int> unfixed;
    unfixed.reserve(tempNameToInd.size());
    for (const auto &[name, ind] : tempNameToInd) {
        unfixed.push_back(ind);
    }
    std::sort(unfixed.begin(), unfixed.end());
    std::vector<int> extended_thiele_reconstruction_limits(vars_mpi.size(), 1);
    std::vector<int> extended_zippel_reconstruction_limits(vars_mpi.size(), 0);
    std::vector<int> extended_thiele_surplus(vars_mpi.size(), 0);
    std::vector<int> extended_newton_reconstruction_limits(vars_mpi.size(), 1);
    std::vector<int> extended_newton_surplus(vars_mpi.size(), 0);
    for (int i = 0; i < static_cast<int>(unfixed.size()); ++i) {
        if (i < static_cast<int>(thiele_reconstruction_limits.size())) {
            extended_thiele_reconstruction_limits[unfixed[i]] = thiele_reconstruction_limits[i];
        }
        if (i < static_cast<int>(zippel_reconstruction_limits.size())) {
            extended_zippel_reconstruction_limits[unfixed[i]] = zippel_reconstruction_limits[i];
        }
        if (i < static_cast<int>(thiele_surplus.size())) {
            extended_thiele_surplus[unfixed[i]] = thiele_surplus[i];
        }
        if (i > 0) {
            if (i - 1 < static_cast<int>(newton_reconstruction_limits.size())) {
                extended_newton_reconstruction_limits[unfixed[i]] = newton_reconstruction_limits[i - 1];
            }
            if (i - 1 < static_cast<int>(newton_surplus.size())) {
                extended_newton_surplus[unfixed[i]] = newton_surplus[i - 1];
            }
        } else {
            extended_newton_reconstruction_limits[unfixed[i]] = extended_thiele_reconstruction_limits[unfixed[i]];
        }
        if (i < static_cast<int>(initial_values_of_variables.size())) {
            extended_initial_values_of_variables[unfixed[i]] = initial_values_of_variables[i];
        }
    }
    if (thiele_surplus.empty()) {
        extended_thiele_surplus.clear();
    }
    if (newton_surplus.empty()) {
        extended_newton_surplus.clear();
    }

    Variables variables(vars_mpi.size() + 1);
    if (!variables.FitNames(vars_mpi)) {
        if (RANK == 0) {
            std::cout << "Names were not Fit \n";
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    if (!variables.FitThieleReconstructionLimits(extended_thiele_reconstruction_limits)) {
        if (RANK == 0) {
            std::cout << "Thiele limits were not Fit \n";
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    if (!variables.FitNewtonReconstructionLimits(extended_newton_reconstruction_limits)) {
        if (RANK == 0) {
            std::cout << "Newton limits were not Fit \n";
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    if (!variables.FitZippelReconstructionLimits(extended_zippel_reconstruction_limits)) {
        if (RANK == 0) {
            std::cout << "Zippel limits were not Fit \n";
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    if (!variables.FitRationalReconstructionLimit(rational_reconstruction_start, rational_reconstruction_limit)) {
        if (RANK == 0) {
            std::cout << "Rational limits were not Fit \n";
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    if (!variables.FitValues(extended_initial_values_of_variables, geometric, big_primes)) {
        if (RANK == 0) {
            std::cout << "Values were not Fit \n";
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    std::vector<InputVariable> var_ranges = variables.GetVariables();

    if (reconstruction_limit == 100) {
        reconstruction_limit = var_ranges.size();
    }
    if (reconstruction_limit > 1) {
        if (vars_mpi.empty()) {
            if (RANK == 0) {
                std::cout << "Variables should be set for reconstruction (other "
                             "than rational) to work \n";
            }
            MPI_Finalize();
            return EXIT_FAILURE;
        }
    }

    if (external) {
        std::string path = path_to_tables;
        if (path.substr(0, folder.size()) == folder)
            path = path.substr(folder.size());
        plan = path + ".plan";
    }

    if (path_to_tables.substr(path_to_tables.size() - 7) == ".tables") {
        path_to_tables = path_to_tables.substr(0, path_to_tables.size() - 7);
    }

    load_limits(path_to_tables, masters_split_string, var_ranges);

#ifdef WITH_DEBUG
    attach_handler();
#endif
    if (RANK == 0) {
        if (delay) {
            std::random_device rd;
            std::mt19937 e{rd()};
            std::uniform_int_distribution<int> dist{1, delay};
            int chosen_delay = dist(e);
            printf("Making a delay for %d/%d\n", chosen_delay, delay);
            std::chrono::seconds duration(chosen_delay);
            std::this_thread::sleep_for(duration);
        }
        std::thread slave_in_master;
        if (master_running_FIRE) {
            slave_in_master =
                std::thread(run_worker_process, var_ranges, NET_SIZE > 1, RANK, geometric, additional_args);
        }

        std::cout << "Current values:" << std::endl
                  << "\tconfig path = " << ARG_PATH << std::endl
                  << "Current ranges:" << std::endl;
        for (size_t var_i = 0; var_i < var_ranges.size(); var_i++) {
            if (var_i == var_ranges.size() - 1) {
                std::cout << "\tPrime number index from " << var_ranges[var_i].starting_value << " to "
                          << (var_ranges[var_i].starting_value + var_ranges[var_i].range - 1);
            } else if (var_ranges[var_i].range == 1) {
                std::cout << "\tVariable " << var_i + 1 << " is set to " << var_ranges[var_i].starting_value;
            } else {
                std::cout << "\tVariable " << var_i + 1 << " (" << var_ranges[var_i].name << ") starts from "
                          << var_ranges[var_i].starting_value << " and has range " << var_ranges[var_i].range;
                if (var_ranges[var_i].newton_limit != var_ranges[var_i].range) {
                    std::cout << " with Newton limit " << var_ranges[var_i].newton_limit;
                }
                if (zippel) {
                    if (var_ranges[var_i].zippel_limit != 0) {
                        std::cout << " with Zippel limit " << var_ranges[var_i].zippel_limit;
                    }
                }
            }
            std::cout << std::endl;
        }

        std::cout << "Requested Tables output: " << path_to_tables << ".tables" << std::endl;

        int command = 1; // 0 is finish, 1 is eval, 2 is eval with delete_tables.
        auto requests = std::vector<MPI_Request>(NET_SIZE);
        auto task_limits = std::vector<int>(NET_SIZE, lim);
        if (master_running_FIRE)
            starting_mpi_index = 0; // using one more worker process
        auto answers = std::vector<std::vector<int>>(NET_SIZE);
        unsigned int var_count = var_ranges.size();
        std::vector<int> var_values(var_count + 1); // extra one is used for passing extra information to slaves
        int i;
        for (i = 0; i < NET_SIZE; i++) {
            answers[i].resize(var_count + 3); // [0-var_count-1] - values including prime, extra
                                              // information, status and reconstruct attempt
        }

        std::vector<bool> done_mask(var_count - 1, false);
        bool is_done = false;
        bool is_finished = false;
        unsigned int rec_index = check_stage(path_to_tables, masters_split_string, var_ranges, early_abortion, 0, 0);

        int current_prime_index = 0;

        std::list<std::string> set_vars;
        for (unsigned int j = 0; j != var_count; ++j) {
            set_vars.push_back(var_ranges[j].name);
        }
        std::string limits_filename =
            tables_path(path_to_tables, masters_split_string, var_ranges, std::vector<int>{}, 0, set_vars) + ".limits";
        bool limits_file_exists = std::filesystem::exists(limits_filename);

        if ((rec_index == 0 || !limits_file_exists) && !skip_limit_detection) {
            if (rec_index != 0) {
                is_done = true;
                // we are here because we have reconstructed it but  limits are
            }
            auto original_NET_SIZE = NET_SIZE;
            while (is_done == false) {
                bool have_to_repeat = false;
                if (plan != "" && !std::filesystem::exists(folder + (folder != "" ? "/" : "") + plan + ".warmup")) {
                    printf("No warmup file, starting with 1 slave\n");
                    NET_SIZE = starting_mpi_index + 1;
                    have_to_repeat = true;
                } else {
                    NET_SIZE = original_NET_SIZE;
                }
                is_done = update_done_mask(done_mask, var_ranges, path_to_tables, masters_split_string);
                for (i = starting_mpi_index; i < NET_SIZE; ++i) {
                    if (have_to_repeat) {
                        have_to_repeat = false;
                    } else {
                        is_finished = get_table_to_process_thiele(var_ranges, var_values, done_mask);
                    }
                    if (is_finished) {
                        break;
                    }
                    int sum = 0;
                    for (unsigned int j = 0; j != var_count; ++j) {
                        sum += j;
                    }
                    if (sum == 0) {
                        std::string requested_table = tables_path(path_to_tables, masters_split_string, var_ranges,
                                                                  var_values, var_count, std::list<std::string>{});
                        if (std::filesystem::exists(requested_table)) {
                            std::cout << "Table already exists, not running reduction: " << requested_table
                                      << std::endl;
                            --i;
                            continue;
                        }
                    }
                    var_values[var_count] = -1; // reconstruction information to detect stage as last non-zero
                    MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
                    MPI_Send(var_values.data(), var_count + 3, MPI_INT, i, DATA, MPI_COMM_WORLD);
                    MPI_Irecv(answers[i].data(), var_count + 3, MPI_INT, i, RESULT, MPI_COMM_WORLD, &requests[i]);
                }
                MPI_Waitall(i - starting_mpi_index, &requests[starting_mpi_index], MPI_STATUSES_IGNORE);
                if (plan != "" && !std::filesystem::exists(folder + (folder != "" ? "/" : "") + plan + ".warmup")) {
                    have_to_repeat = true;
                }
                if (is_finished) {
                    is_done = update_done_mask(done_mask, var_ranges, path_to_tables, masters_split_string);
                    break;
                }
            }
            if (!is_done) {
                std::cout << Color::Red() << "Thiele limits are insufficient." << Color::Reset() << std::endl;
                std::cout << "To resolve this issue, consider increasing the limits "
                             "for the following variables:"
                          << std::endl;
                for (int i = 0; i < static_cast<int>(done_mask.size()); ++i) {
                    if (!done_mask[i]) {
                        std::cout << "- \"" << var_ranges[i].name << "\" "
                                  << "variable at position " << i + 1 << std::endl;
                    }
                }
                std::cout << std::endl;

                if (early_abortion) {
                    command = 0;
                    for (int i = starting_mpi_index; i < NET_SIZE; i++) {
                        MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
                    }
                    MPI_Abort(MPI_COMM_WORLD, EXIT_SUCCESS);
                }
            } else {
                auto var_ranges_copy = var_ranges;

                if (!update_thiele_limits(var_ranges_copy, path_to_tables, early_abortion, masters_split_string) ||
                    !update_newton_limits(var_ranges_copy, path_to_tables, early_abortion, masters_split_string)) {
                    command = 0;
                    for (int i = starting_mpi_index; i < NET_SIZE; i++) {
                        MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
                    }
                    MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
                }

                for (int i = 0; i < static_cast<int>(var_ranges_copy.size()) - 1; ++i) {
                    if (i < static_cast<int>(extended_thiele_surplus.size())) {
                        var_ranges_copy[i].range += extended_thiele_surplus[i];
                    }
                    if (i < static_cast<int>(extended_newton_surplus.size()) && i > 0) {
                        var_ranges_copy[i].newton_limit += extended_newton_surplus[i - 1];
                    }
                }

                std::cout << std::endl
                          << Color::Green() << "Calculation of new limits has been successfully completed." << std::endl
                          << std::endl;

                if (early_abortion || thiele_reconstruction_limits.empty() || newton_reconstruction_limits.empty()) {
                    std::cout << "The new limits are the following:" << std::endl;
                } else {
                    std::cout << "We suggest using the following limits:" << std::endl;
                }

                bool is_first = true;
                for (int i = 0; i < static_cast<int>(var_ranges_copy.size()) - 1; ++i) {
                    const auto &name = var_ranges_copy[i].name;
                    const auto thieleLimit = var_ranges_copy[i].range;
                    const auto newtonLimit = var_ranges_copy[i].newton_limit;
                    if (thieleLimit != 1 && newtonLimit != 1) {
                        std::cout << "- Variable name: \"" << (var_ranges[i].big_prime_initial ? "p" : "") << name
                                  << "\"" << std::endl;
                        std::cout << "  Thiele limit: " << var_ranges[i].range << " -> " << thieleLimit << std::endl;
                        if (!is_first) {
                            std::cout << "  Newton limit: " << var_ranges[i].newton_limit << " -> " << newtonLimit
                                      << std::endl;
                        } else {
                            is_first = false;
                        }
                    }
                }
                std::cout << Color::Reset() << std::endl << std::endl;

                if (early_abortion || thiele_reconstruction_limits.empty() || newton_reconstruction_limits.empty()) {
                    var_ranges = var_ranges_copy;
                    // sending thiele and newton limits
                    command = 3;
                    for (unsigned int j = 0; j != var_count; ++j) {
                        var_values[j] = var_ranges[j].range;
                    }
                    for (i = starting_mpi_index; i < NET_SIZE; ++i) {
                        MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
                        MPI_Send(var_values.data(), var_count + 3, MPI_INT, i, DATA, MPI_COMM_WORLD);
                    }
                    command = 4;
                    for (unsigned int j = 0; j != var_count; ++j) {
                        var_values[j] = var_ranges[j].newton_limit;
                    }
                    for (i = starting_mpi_index; i < NET_SIZE; ++i) {
                        MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
                        MPI_Send(var_values.data(), var_count + 3, MPI_INT, i, DATA, MPI_COMM_WORLD);
                    }
                }
                save_limits(path_to_tables, masters_split_string, var_ranges);
            }

            // we skipped limit detection if we are on a later stage
        } else if (rec_index != var_count) {
            while (rec_index == var_count - 1) {
                std::cout << Color::Green() << std::endl
                          << "PROCEEDING TO PRIME " << (rational_reconstruction_start + current_prime_index + 1)
                          << std::endl
                          << Color::Reset() << std::endl
                          << std::endl;
                ++current_prime_index;
                rec_index = check_stage(path_to_tables, masters_split_string, var_ranges, early_abortion, 0,
                                        current_prime_index);
            }
            if (current_prime_index != 0) {
                // we are not on first prime, let us try modular reconstruction
                for (unsigned i = 0; i != var_count - 1; ++i) {
                    answers[1][i] = 0;
                }
                answers[1][var_count - 1] = current_prime_index;
                answers[1][var_count] = var_count - 2; // stage to have zippel and rational reconstruction
                answers[1][var_count + 1] = 0;         // not used
                answers[1][var_count + 2] = 2;         // the number of rational reconstruction
                if (reconstruction_limit >= var_count - 1) {
                    try_master_reconstruction(var_ranges, answers[1], path_to_tables, masters_split_string,
                                              delete_tables_setting, NET_SIZE);
                }
            }
            std::cout << std::endl
                      << Color::Green() << "Proceeding to stage " << (rec_index + 1) << Color::Reset() << std::endl
                      << std::endl;
        }

        if (!master_running_FIRE)
            requests[0] = MPI_REQUEST_NULL;
        int res_i;
        int successfull_jobs = 0;

        if (rec_index == var_count) {
            current_prime_index = var_ranges[var_count - 1].range;
        }
        unsigned int first_nonsingle = 0;
        while (var_ranges[first_nonsingle].range == 1) {
            ++first_nonsingle;
        }
        for (; current_prime_index != var_ranges[var_count - 1].range; current_prime_index++) {
            for (++rec_index; rec_index < var_count; ++rec_index) {
                if (zippel) {
                    command = 5;
                    for (unsigned int j = 0; j != var_count; ++j) {
                        var_values[j] = var_ranges[j].zippel_limit;
                    }
                    for (i = starting_mpi_index; i < NET_SIZE; ++i) {
                        MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
                        MPI_Send(var_values.data(), var_count + 3, MPI_INT, i, DATA, MPI_COMM_WORLD);
                    }
                }

                // there's a new portion of tasks for workers
                command = delete_tables_setting ? 2 : 1;
                for (i = starting_mpi_index; i < NET_SIZE; ++i) {
                    if (!get_table_to_process(var_ranges, var_values, current_prime_index, rec_index - 1)) {
                        break; // nothing more to submit
                    }
                    MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
                    MPI_Send(var_values.data(), var_count + 3, MPI_INT, i, DATA, MPI_COMM_WORLD);
                    MPI_Irecv(answers[i].data(), var_count + 3, MPI_INT, i, MPI_ANY_TAG, MPI_COMM_WORLD, &requests[i]);
                }

                while (i != NET_SIZE) {
                    requests[i] = MPI_REQUEST_NULL;
                    ++i;
                }

                MPI_Status status;
                MPI_Waitany(NET_SIZE, requests.data(), &res_i, &status);
                while (res_i != MPI_UNDEFINED) {
                    if (answers[res_i][var_count + 1] == FAIL) {
                        // rerun this job
                        for (unsigned j = 0; j != var_count + 1; ++j) {
                            var_values[j] = answers[res_i][j];
                        }
                        std::this_thread::sleep_for(std::chrono::seconds(2));
                        std::cout << "RERUNNING A JOB FOR "
                                  << tables_path("", std::string{}, var_ranges, var_values, var_count,
                                                 std::list<std::string>{})
                                  << std::endl;
                        command = delete_tables_setting ? 2 : 1;
                        MPI_Send(&command, 1, MPI_INT, res_i, COMMAND, MPI_COMM_WORLD);
                        MPI_Send(var_values.data(), var_count + 3, MPI_INT, res_i, DATA, MPI_COMM_WORLD);
                        MPI_Irecv(answers[res_i].data(), var_count + 3, MPI_INT, res_i, MPI_ANY_TAG, MPI_COMM_WORLD,
                                  &requests[res_i]);
                    } else {

                        if (!answers[res_i][var_count + 1]) {
                            ++successfull_jobs;
                        }

                        if (task_limits[res_i] > 0 && answers[res_i][var_count + 1] != ALREADY_RESERVED) {
                            --task_limits[res_i];
                        }

                        if (task_limits[res_i] == 0) {
                            // this worker did all it could;
                            // let's stop it and continue
                            printf("Stopping worker %d\n", res_i);
                            command = 0;
                            MPI_Send(&command, 1, MPI_INT, res_i, COMMAND, MPI_COMM_WORLD);
                            MPI_Waitany(NET_SIZE, requests.data(), &res_i, &status);
                            printf("Stopped worker %d\n", res_i);
                            continue;
                        }

                        unsigned int reconstructed = answers[res_i][var_count + 2];
                        bool should_stop_stage = false;
                        if (reconstructed >= rec_index) {
                            should_stop_stage = true;
                        }
                        if ((!zippel || (rec_index > first_nonsingle + 1)) && (answers[res_i][var_count] != -2)) {
                            for (unsigned int j = rec_index; j < var_count - 1; ++j) {
                                if (var_values[j] != 0) {
                                    should_stop_stage = true;
                                    break;
                                }
                            }
                        }
                        if (var_values[var_count - 1] > current_prime_index) {
                            should_stop_stage = true;
                        }
                        if (!should_stop_stage) {
                            // we request another table and send it to slaves
                            if (get_table_to_process(var_ranges, var_values, current_prime_index, rec_index - 1)) {
                                command = delete_tables_setting ? 2 : 1;
                                MPI_Send(&command, 1, MPI_INT, res_i, COMMAND, MPI_COMM_WORLD);
                                MPI_Send(var_values.data(), var_count + 3, MPI_INT, res_i, DATA, MPI_COMM_WORLD);
                                MPI_Irecv(answers[res_i].data(), var_count + 3, MPI_INT, res_i, MPI_ANY_TAG,
                                          MPI_COMM_WORLD, &requests[res_i]);
                            }
                        }
                    }

                    MPI_Waitany(NET_SIZE, requests.data(), &res_i, &status);
                }

                if (zippel && rec_index - 1 != first_nonsingle) {
                    // looks like we need to try a reconstruction attempt
                    // we pass forbidden_node to -1 not forbidding anything but to force
                    // initialization of slaves the number in answers is not important
                    for (unsigned i = 0; i != var_count - 1; ++i) {
                        answers[1][i] = 0;
                    }
                    answers[1][var_count - 1] = current_prime_index;
                    answers[1][var_count] = rec_index - 1;
                    answers[1][var_count + 1] = 0; // not used
                    answers[1][var_count + 2] = 1; // zippel reconstruction
                    if (reconstruction_limit >= var_count - 2) {
                        int res = try_master_reconstruction(var_ranges, answers[1], path_to_tables,
                                                            masters_split_string, delete_tables_setting, NET_SIZE);
                        if (!res && rec_index == var_count - 1 && (reconstruction_limit >= var_count - 1)) {
                            answers[1][var_count + 2] = 2;
                            try_master_reconstruction(var_ranges, answers[1], path_to_tables, masters_split_string,
                                                      delete_tables_setting, NET_SIZE);
                        }
                    }
                }

                rec_index = check_stage(path_to_tables, masters_split_string, var_ranges, early_abortion, rec_index,
                                        current_prime_index);

                if (rec_index == var_count - 1) {
                    std::cout << Color::Green() << std::endl
                              << "PROCEEDING TO PRIME " << (rational_reconstruction_start + current_prime_index + 1)
                              << std::endl
                              << Color::Reset() << std::endl
                              << std::endl;
                    rec_index = check_stage(path_to_tables, masters_split_string, var_ranges, early_abortion, 0,
                                            current_prime_index + 1);
                    break;
                }
            }
        }

        std::cout << "Finished, there were " << successfull_jobs << " successful jobs" << std::endl;

        command = 0;
        for (int i = starting_mpi_index; i < NET_SIZE; i++) {
            MPI_Send(&command, 1, MPI_INT, i, COMMAND, MPI_COMM_WORLD);
        }
        std::this_thread::sleep_for(std::chrono::seconds(5));

        std::chrono::time_point<std::chrono::steady_clock> stop_time = std::chrono::steady_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::duration<float>>(stop_time - start_time).count();
        std::cout << "Your calculations took " << std::fixed << std::setprecision(6) << duration << " seconds to run."
                  << std::endl;

        if (master_running_FIRE)
            slave_in_master.join();
    } else {
        run_worker_process(var_ranges, (master_running_FIRE || (NET_SIZE > 2)), RANK, geometric, additional_args);
    }
    MPI_Finalize();
    return EXIT_SUCCESS;
}

/**
 * Generats a path to a Tables file, individual or reconstructed
 * @param table_filename table start (without suffix or indices). If empty, no
 * first undescore is added, used for preapring option for FIRE run
 * @param masters_split_string ending related to split masters mode
 * @param variables the class contating variables in yse
 * @param indices array of indices to be put into path
 * @param var_count number of indices to be inserted into path
 * @param extra_indices variable names that will be appended at the beginning(we
 * changed order!)
 * @return full path
 */
std::string tables_path(const std::string &table_filename, const std::string &masters_split_string,
                        const std::vector<InputVariable> &variables, const std::vector<int> &indices, size_t var_count,
                        std::list<std::string> extra_indices) {
    std::stringstream res;
    res << table_filename;

    bool skip_underscore = (table_filename == "");

    for (const auto &index : extra_indices) {
        if (skip_underscore) {
            skip_underscore = false;
        } else {
            res << "_";
        }

        res << index;
    }

    for (unsigned int i = 0; i < var_count; ++i) {
        if (skip_underscore) {
            skip_underscore = false;
        } else {
            res << "_";
        }

        res << variables[i + extra_indices.size()].VariableValue(
            indices[i + extra_indices.size()]); // we skip the first indices, as
                                                // they come with extra
    }

    res << masters_split_string;

    if (table_filename != "") {
        res << ".tables";
    }

    std::string path = res.str();

    return path;
}

/**
 * Operations performed by the slave or master in a thread
 * @param var_ranges the scanned vector of variable ranges
 * @param quiet whether to run FIRE quietly
 * @param RANK the rank of the current MPI process (for printing)
 * @param geometric whether we use large variables in FIRE for exponents of
 * params
 * @param additional_args whether there are additional arguments to be passed to
 * the process
 */
void run_worker_process(std::vector<InputVariable> var_ranges, bool quiet, int RANK, bool geometric,
                        bool additional_args) {
    unsigned int var_count = var_ranges.size();

    std::list<std::string> variables;
    for (const auto &var : var_ranges)
        variables.push_back(var.name);
    std::string final_table =
        tables_path(path_to_tables, masters_split_string, var_ranges, std::vector<int>{}, 0, variables);
    final_table = subfolder_path(final_table, folders_limit_mpi);
    // final requested table

    int command;
    const int MASTER = 0;
    std::vector<int> result; // used for receiving requested points and passing
                             // back result to master
    result.resize(var_count + 3);
    pid_t pid;

    auto start_time = std::chrono::steady_clock::now();
    MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    while (command != 0) {
        MPI_Recv(result.data(), var_count + 3, MPI_INT, MASTER, DATA, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        if (command == 3) {
            for (unsigned j = 0; j != var_count; ++j) {
                var_ranges[j].range = result[j];
            }
            MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            continue;
        }
        if (command == 4) {
            for (unsigned j = 0; j != var_count; ++j) {
                var_ranges[j].newton_limit = result[j];
            }
            MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            continue;
        }
        if (command == 5) {
            for (unsigned j = 0; j != var_count; ++j) {
                var_ranges[j].zippel_limit = result[j];
            }
            MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            continue;
        }
        if (command == 6) {
            // participating in a distributed reconstruction
            // auto stop_time = std::chrono::steady_clock::now();
            // printf("PROCESS (%d) waited for a task for %f seconds\n", RANK,
            // std::chrono::duration_cast<std::chrono::duration<float>>(stop_time -
            // start_time).count());
            MPI_Barrier(MPI_COMM_WORLD);
            bool delete_tables = false;
            auto reconstruction_runs = generate_reconstruction_runs(var_ranges, result, path_to_tables,
                                                                    masters_split_string, delete_tables, true);
            // we will need reconstruction run that is passed to master for zippel
            int reconstruction_number = 0;
            int needed_reconstruction_number = result[var_ranges.size() + 2];
            // std::cout << "Participating in reconstruction number " <<
            // needed_reconstruction_number << " of " << reconstruction_runs.size() -
            // 1<< std::endl;
            for (const auto &[params, return_code, reconstructed_table_filename] : reconstruction_runs) {
                if (reconstruction_number == needed_reconstruction_number) {
                    if (std::filesystem::exists(subfolder_path(reconstructed_table_filename, folders_limit_mpi))) {
                        // printf("Reconstructed Tables already exist: %s\n",
                        // reconstructed_table_filename.c_str()); break; // this way we will
                        // check all but use highest
                    } else {
                        // we want to run reconstruction without forking and starting a
                        // process
                        char *run_args[32];
                        unsigned int i = 0;
                        while (i != params.size()) {
                            // const_cast due to old style of execv syntax
                            run_args[i] = const_cast<char *>(params[i].c_str());
                            ++i;
                        }
                        run_args[i] = nullptr;
                        optind = 0;
                        reconstruct(params.size(), run_args, RANK, NET_SIZE);
                    }
                }
                ++reconstruction_number;
            }
            start_time = std::chrono::steady_clock::now();
            MPI_Barrier(MPI_COMM_WORLD);
            // we do not send anwer here, it was in distributed call
            MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            continue;
        }

        // auto stop_time = std::chrono::steady_clock::now();
        // printf("PROCESS (%d) waited for a task for %f seconds\n", RANK,
        // std::chrono::duration_cast<std::chrono::duration<float>>(stop_time -
        // start_time).count());

        bool delete_tables = (command == 2) ? true : false;
        auto reconstruction_runs =
            generate_reconstruction_runs(var_ranges, result, path_to_tables, masters_split_string, delete_tables);

        result[var_count + 1] = FAIL; // by default, we think we rather failed to reconstruct
        result[var_count + 2] = 0;    // number of reconstructed tables

        int mpi_return_value = -1; // if changed, we are done and need to send response to master
        for (const auto &[params, return_code, reconstructed_table_filename] : reconstruction_runs) {
            if (reconstructed_table_filename[0] != '!') {
                if (std::filesystem::exists(subfolder_path(reconstructed_table_filename, folders_limit_mpi))) {
                    printf("Reconstructed Tables already exist: %s\n", reconstructed_table_filename.c_str());
                    mpi_return_value = return_code;
                    // break; // this way we will check all but use highest
                }
            }
        }

        // forming a string for variables call and table name
        std::string arg_numbers;
        std::string program_path;
        bool should_use_multi = zippel && multitables_used && (result[var_count] != -2);
        if (should_use_multi) {
            if (result[var_count] != -1) {
                int current_stage = result[var_count];
                // that's a zippel Tables generation, we should put + on all real
                // indices before the current stage
                std::list<std::string> inds;
                for (int i = 0; i != current_stage; ++i) {
                    if (var_ranges[i].range != 1) {
                        // real index
                        inds.push_back(var_ranges[i].VariableValue(result[i]) + "+");
                    } else {
                        inds.push_back(var_ranges[i].VariableValue(0));
                    }
                }
                arg_numbers = tables_path("", std::string{}, var_ranges, result, var_count - current_stage, inds);
            } else {
                int nonzero_index = -1;
                for (unsigned int i = 0; i != var_count - 1; ++i) {
                    if (result[i] != 0) {
                        nonzero_index = i;
                        break;
                    }
                }
                if (nonzero_index == -1) {
                    should_use_multi = false;
                } else {
                    // it's a line Thiele. We should put + on that line
                    std::list<std::string> inds;
                    int current_stage = nonzero_index;
                    for (int i = 0; i != current_stage; ++i) {
                        inds.push_back(var_ranges[i].VariableValue(0));
                    }
                    inds.push_back(var_ranges[current_stage].VariableValue(result[current_stage]) + "+");
                    arg_numbers =
                        tables_path("", std::string{}, var_ranges, result, var_count - current_stage - 1, inds);
                }
            }
        }
        if (!should_use_multi) {
            arg_numbers = tables_path("", std::string{}, var_ranges, result, var_count, std::list<std::string>{});
        }

        std::string requested_table =
            subfolder_path(path_to_tables + "_" + arg_numbers + masters_split_string + ".tables", folders_limit_mpi);

        if (mpi_return_value != -1) {
            printf("Not needed: %s\n", requested_table.c_str());
            result[var_count + 1] = ALREADY_RESERVED;
            result[var_count + 2] = mpi_return_value;
            start_time = std::chrono::steady_clock::now();
            MPI_Send(result.data(), var_count + 3, MPI_INT, MASTER, RESULT, MPI_COMM_WORLD);
            MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            continue;
        }

        int res;
        if (plan != "" && !std::filesystem::exists(folder + (folder != "" ? "/" : "") + plan + ".warmup")) {
            res = SUCCESS;
        } else {
            res = reserve_table(requested_table);
        }

        if (res == ALREADY_RESERVED) {
            result[var_count + 1] = ALREADY_RESERVED;
        } else if (res == FAILED_TO_RESERVE) {
            std::cout << "Failed to reserve a new table, something is wrong with the "
                         "filesystem\n";
            abort();
        }

        bool found_higher = false;
        if (result[var_count + 1] != ALREADY_RESERVED) {
            // calling FIRE
            // we do not use the multitable program for a random seed and for the case
            // when all indices are starting;
            std::string current_reduction_program = should_use_multi ? reduction_program_multu : reduction_program;
            if (plan != "" && !std::filesystem::exists(folder + (folder != "" ? "/" : "") + plan)) {
                printf("No plan file, running old reduction first\n");
                current_reduction_program = replace_all(current_reduction_program, "n", "");
            }
            if (current_reduction_program[0] == '/') // user input starts with "/"
                program_path = current_reduction_program;
            else {
                if ((current_reduction_program.size() >= 2) && (current_reduction_program[0] == '.') &&
                    (current_reduction_program[1] == '/')) // user input starts with "./"
                    program_path =
                        static_cast<std::string>(std::filesystem::current_path()) + "/" + current_reduction_program;
                else // relative to FIRE7/bin/
                    program_path = FIRE_folder + current_reduction_program;
            }
            std::vector<std::string> params = {program_path};
            if (quiet) {
                params.push_back("--QUIET");
            } else {
                params.push_back("--quiet");
            }
            if (folders_limit_mpi != 0 && result[var_count] != -2) {
                params.push_back("--folders");
                params.push_back(std::to_string(folders_limit_mpi));
            }
            if (plan != "") {
                params.push_back("-P");
                params.push_back(plan);
            }
            if (external_option != "") {
                params.push_back("--calc_option");
                params.push_back(external_option);
            }
            params.push_back("--variables");
            params.push_back(arg_numbers);
            params.push_back("--config");
            params.push_back(ARG_PATH);
            params.push_back("--parallel");
            params.push_back("--calc");
            params.push_back(library_name);
            if (geometric) {
                params.push_back("--large_variables");
            }
            if (additional_args) {
                std::istringstream str(additional_arg_string);
                std::string nth_param;
                while (!str.eof()) {
                    str >> nth_param;
                    params.push_back(nth_param);
                }
            }

            int fire_return_code = run_process(params, RANK, pid);

            if (cleanup_temp_files(requested_table, database_path, pid) == FAIL) {
                abort();
            }

            if (fire_return_code) {
                result[var_count + 1] = FAIL;
            } else {
                result[var_count + 1] = 0;
                printf("Generated: %s\n", requested_table.c_str());
                if (delete_tables) {
                    for (const auto &[params, return_code, reconstructed_table_filename] : reconstruction_runs) {
                        if (reconstructed_table_filename[0] != '!') {
                            if (std::filesystem::exists(
                                    subfolder_path(reconstructed_table_filename, folders_limit_mpi))) {
                                printf("We generated a table %s, but deleting it since "
                                       "reconstructed Tables already exist: %s\n",
                                       requested_table.c_str(), reconstructed_table_filename.c_str());
                                std::filesystem::remove(requested_table);
                                found_higher = true;
                                break;
                            }
                        }
                    }
                }
            }
        }
        // if the table already exists or we created a new table and did not find
        // higer tables
        if (result[var_count + 1] != FAIL && !found_higher) {

            int reconstruction_number = 0;
            for (const auto &[params, return_code, reconstructed_table_filename] : reconstruction_runs) {
                if (params.empty()) {
                    // that was only a check, we do not call
                    continue;
                }
                int res;
                res = run_process(params, RANK, pid);
                if (res == 0) {
                    if (reconstructed_table_filename[0] == '!') {
                        printf("Successfully called %s\n", reconstructed_table_filename.c_str() + 1);
                    } else {
                        std::string tname = subfolder_path(reconstructed_table_filename, folders_limit_mpi);
                        printf("Reconstructed: %s\n", tname.c_str());
                        if (final_table == tname) {
                            std::cout << Color::Green() << std::endl
                                      << "REQUESTED TABLED HAS BEEN RECONSTRUCTED " << std::endl
                                      << Color::Reset() << std::endl;
                            if (abort_when_done) {
                                printf("Requested table has been reconstructed, aborting\n");
                                MPI_Abort(MPI_COMM_WORLD, 0);
                            }
                        }
                        result[var_count + 2] = return_code;
                    }
                } else {
                    if (res != 1) {
                        // reserved code meaning unstable but no fail
                        printf("RECONSTRUCTION FAILED ON %d\n", RANK);
                    }
                    break;
                }
                ++reconstruction_number;
            }
        }

        start_time = std::chrono::steady_clock::now();
        MPI_Send(result.data(), var_count + 3, MPI_INT, MASTER, RESULT, MPI_COMM_WORLD);
        MPI_Recv(&command, 1, MPI_INT, MASTER, COMMAND, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    }
}
