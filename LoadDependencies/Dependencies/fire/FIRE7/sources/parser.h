/** @file parser.h
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package.
 */

#ifndef PARSER_H_INCLUDED
#define PARSER_H_INCLUDED

#include <dirent.h>
#include <sys/stat.h>

#include "common.h"
#include "equation.h"
#include "point.h"
#include "tools/primes.h"

/**
 * Load input integrals list or a list for the ftool
 * @param filename the file with integrals
 * @param points where points are loaded
 * @return error code
 */
int load_integrals(const string &filename, set<Point, std::greater<Point>> &points);

/**
 * Parses a vactor of long numbers from a string
 * @param digit the pointer
 * @param result where to put vector
 * @return number of bytes to shift after that
 */
int parse_vector(const char *digit, vector<int64_t> &result);

/**
 * Perses a long number from a string
 * @param digit the pointer
 * @param result where to put number
 * @return number of bytes to shift after that
 */
int parse_long(const char *digit, int64_t &result);

/**
 * Leave only points of set parity
 * @param s_fast Set of points to be filtered. Is changed accordingly
 */
void leave_used_points(set<FastPoint> &s_fast);

/**
 * Parse configuration file and read input data. This function is called we
 * start new FIRE or FLAME executables. The sector is 0 only in the master
 * executable, FIRE.
 * @param filename path to configuration file.
 * @param points set of points which we will work with, given the directive. We
 * fill it in this function.
 * @param output path to where Tables will be saved.
 * @param sector number of sector, where we are working. 0 means we are calling
 * this function from main. We use negative for substitution
 * @param force_no_send_to_parent
 * @return 0 if no errors, -1 if Tables should not be created, error code
 * otherwise.
 */
int parse_config(const string &filename, set<Point, std::greater<Point>> &points, string &output, const int sector,
                 bool force_no_send_to_parent = false);

/**
 * Split a coefficient string into a vector.
 * @param s string with coefficients.
 * @return vector of coefficients, starting from free part and followed with
 * coefficients at a[i].
 */
vector<COEFF> split_coeff(const string &s);

/**
 * Read an integer from a string.
 * @param digit pointer to char array from which we need to read an integer.
 * @param result reference to result integer. Answer is written here.
 * @return number of characters read in string.
 */
int s2i(const char *digit, int &result);

/**
 * Read an unsigned integer from a string.
 * @param digit pointer to char array from which we need to read an unsigned
 * integer.
 * @param result reference to result unsigned integer. Answer is written here.
 * @return number of characters read in string.
 */
int s2u(const char *digit, unsigned int &result);

/**
 * Read a long unsigned integer from a string.
 * @param digit pointer to char array from which we need to read an unsigned
 * integer.
 * @param result reference to result unsigned integer. Answer is written here.
 * @return number of characters read in string.
 */
int s2lu(const char *digit, unsigned long &result);

/**
 * Read a vector of coefficients from a string.
 * @param digit pointer to char array from which we need to read a vector of
 * coefficients.
 * @param result reference to result vector of coefficients. Answer is written
 * here.
 * @return number of characters read in string.
 */
int s2v(const char *digit, vector<t_index> &result);

/**
 * Read sector number from a string.
 * @param digit pointer to char array from which we need to read sector number.
 * @param result reference to result sector number. Answer is written here.
 * @return number of characters read in string.
 */
int s2sf(const char *digit, SECTOR &result); // to sector fast directly

/**
 * Read a double vector of coefficients from a string.
 * @param digit pointer to char array from which we need to read a double vector
 * of coefficients.
 * @param result reference to result double vector of coefficients. Answer is
 * written here.
 * @return number of characters read in string.
 */
int s2vv(const char *digit, vector<vector<t_index>> &result);

/**
 * Read a triple vector of coefficients from a string.
 * @param digit pointer to char array from which we need to read a triple vector
 * of coefficients.
 * @param result reference to result triple vector of coefficients. Answer is
 * written here.
 * @return number of characters read in string.
 */
int s2vvv(const char *digit, vector<vector<vector<t_index>>> &result);

/**
 * Parse program arguments.
 * @param argc argument count.
 * @param argv array of pointers to char arguments.
 * @param main true if this function is called from FIRE, false otherwise.
 * @return pair of the process's thread number and assigned sector. If sector is
 * 0 it is main FIRE executable. Negative is for substitutions
 */
pair<int, int> parse_argc_argv(int argc, char *argv[], [[maybe_unused]] bool main);

#endif // PARSER_H_INCLUDED
