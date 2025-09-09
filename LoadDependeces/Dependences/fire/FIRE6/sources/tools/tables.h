/** @file tables.h
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 */

#ifndef TABLES_H_INCLUDED
#define TABLES_H_INCLUDED

#include <vector>
#include <string>
#include <fstream>
#include <iostream>

#include "../../extra/fuel/library/fuel.h"

/**
 * @brief Tables class is for manipulating with stored tables.
 *
 */
class tables {
public:

    /**
     * Stores error message of last function or operator call
     * Is reset to empty line upon success
     */
    inline static std::string errorMessage = {};

    /**
     * Indicated whether coefficients should be compared in == or !-
     * If false, they are ignored. Is used for controlling structure only
     */
    inline static bool compareCoefficients = true;

    /**
     * Maps point numbers to their representations, that are vectors of point numbers and coefficients
     */
    std::vector<std::pair<std::string, std::vector<std::pair<std::string,std::string>>>> relations;

    /**
     * Maps point numbers to their real representations with indices
     */
    std::vector<std::pair<std::string, std::pair<unsigned int, std::vector<signed char>>>> representations;

    /** @fn operator==(const tables &, const tables &) const
     * @brief Compare two points
     * @param t1 first table
     * @param t2 second table
     * @return True if they are equal
     */
    friend bool operator==(const tables &t1, const tables &t2);

    /** @fn operator!=(const tables &, const tables &) const
     * @brief Compare two points
     * @param t1 first table
     * @param t2 second table
     * @return True if they are not equal
     */
    friend bool operator!=(const tables &t1, const tables &t2);
    
    /** @fn operator<<(std::ostream &, const tables &t)
     * @brief Output table to stream
     * @param out stream
     * @param t table
     * @return stream
     */
    friend std::ostream &operator<<(std::ostream &out, const tables &t);

    /** @fn operator>>(std::ostream &, const tables &t)
     * @brief Input table from stream
     * @param in stream
     * @param t table
     * @return stream
     */
    friend std::istream &operator>>(std::istream &in, tables &t);

};

#endif // TABLES_H_INCLUDED
