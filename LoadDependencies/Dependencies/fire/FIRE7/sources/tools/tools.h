/** @file tools.h
 *
 *  This file is a part of the FIRE package and contains some universal
 * functions
 */

#ifndef TOOLS_H_INCLUDED
#define TOOLS_H_INCLUDED

#include <string.h>
#include <string>
#include <vector>

#include "../../extra/fuel/library/fuel.h"

/**
 * Calculated a maximal power of var in function
 * @param function the function
 * @param var the variable
 * @return maximal exponent
 */
int exponent(const std::string &function, const std::string &var);

/**
 * Splits a rational function
 * @param function the function
 * @param allow_fuel_call if set to true, calls fuel for simplification if
 * simple parsing fails, if not, crashes in this case
 * @return numerator and denumenator
 */
std::pair<std::string, std::string> numerator_denominator(const std::string &function, bool allow_fuel_call = false);

/**
 * Detects a proper input or output table path
 * @param filename the original filename
 * @param folders_limit the setting splitting files by subfolders
 * @param create whether folders should be created
 * @return the adjusted filename according to the exponents in it and folder
 * limit setting
 */
std::string subfolder_path(std::string filename, int folders_limit, bool create = false);

/**
 * Replace all occurrences of from string in str to to string.
 * @param str string that will be updated
 * @param from etalon of substring to be replaced
 * @param to replacement string
 * @return copy of updated string
 */
std::string replace_all(std::string str, const std::string &from, const std::string &to);

/**
 * Parses FIRE config file getting needed information
 * @param filename the config to read from
 * @param folder the fire setting for folder with other files from config
 * @param path_to_tables table name with .tables
 * @param masters_split_string suffix for masters
 * @param database_path path to database FIRE creates
 * @param vars the non-replaced variables in the config file
 * @return whether the file exists
 */
bool parse_config(const std::string &filename, std::string &folder, std::string &path_to_tables,
                  std::string &masters_split_string, std::string &database_path, std::vector<std::string> &vars);

/**
 * Launches a process via for-exec
 * @param params the call parameters starting from program name
 * @param RANK rank of the process to be printed in case of errors
 * @param pid the pid of the child process launched, used as return argument
 * @param verbose whether to print time on success
 * @return return code of the child process
 */
int run_process(std::vector<std::string> params, int RANK, pid_t &pid, bool verbose = true);
#endif // TOOLS_H_INCLUDED
