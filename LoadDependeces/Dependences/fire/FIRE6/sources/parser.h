/** @file parser.h
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package.
 */

#ifndef PARSER_H_INCLUDED
#define PARSER_H_INCLUDED

#include "common.h"
#include "point.h"
#include "equation.h"
#include <sys/stat.h>
#include <dirent.h>

/**
 * Parse configuration file and read input data. This function is called we start new
 * FIRE or FLAME executables. The sector is 0 only in the master executable, FIRE.
 * @param filename path to configuration file.
 * @param points set of points which we will work with, given the directive. We fill it in this function.
 * @param output path to where tables will be saved.
 * @param sector number of sector, where we are working. 0 means we are calling this function from main.
 * @param force_no_send_to_parent
 * @return 0 if no errors, -1 if tables should not be created, error code otherwise.
 */
int parse_config(const string& filename, set<point, indirect_more> &points, string &output, const sector_count_t sector,
                 bool force_no_send_to_parent = false);

/**
 * Split a coefficient string into a vector.
 * @param s string with coefficients.
 * @return vector of coefficients, starting from free part and followed with coefficients at a[i].
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
 * @param digit pointer to char array from which we need to read an unsigned integer.
 * @param result reference to result unsigned integer. Answer is written here.
 * @return number of characters read in string.
 */
int s2u(const char *digit, unsigned int &result);

/**
 * Read a vector of coefficients from a string.
 * @param digit pointer to char array from which we need to read a vector of coefficients.
 * @param result reference to result vector of coefficients. Answer is written here.
 * @return number of characters read in string.
 */
int s2v(const char *digit, vector<t_index> &result);

/**
 * Read sector number from a string.
 * @param digit pointer to char array from which we need to read sector number.
 * @param result reference to result sector number. Answer is written here.
 * @return number of characters read in string.
 */
int s2sf(const char *digit, SECTOR &result);  // to sector fast directly

/**
 * Read a double vector of coefficients from a string.
 * @param digit pointer to char array from which we need to read a double vector of coefficients.
 * @param result reference to result double vector of coefficients. Answer is written here.
 * @return number of characters read in string.
 */
int s2vv(const char *digit, vector<vector<t_index> > &result);

/**
 * Read a triple vector of coefficients from a string.
 * @param digit pointer to char array from which we need to read a triple vector of coefficients.
 * @param result reference to result triple vector of coefficients. Answer is written here.
 * @return number of characters read in string.
 */
int s2vvv(const char *digit, vector<vector<vector<t_index> > > &result);

/**
 * Parse program arguments.
 * @param argc argument count.
 * @param argv array of pointers to char arguments.
 * @param main true if this function is called from FIRE, false otherwise.
 * @return pair of the process's thread number and assigned sector. If sector is 0 it is main FIRE executable.
 */
pair<int,int> parseArgcArgv(int argc, char *argv[], bool main);

#endif // PARSER_H_INCLUDED
