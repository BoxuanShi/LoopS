/** @file tables.h
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 */

#ifndef TABLES_H_INCLUDED
#define TABLES_H_INCLUDED

#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "../../extra/fuel/library/fuel.h"

/**
 * @brief Tables class is for manipulating with stored tables.
 *
 */
class Tables {
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
     * Indicated whether relations should be compared in == or !-
     * If false, they only the masters structure is checked
     */
    inline static bool compareRelations = true;

    /**
     * Indicates whether prime was set when initializing fuel
     */
    inline static bool primeSet = false;

    /**
     * Indicated whether Tables should be saved in a trules format
     */
    inline static bool saveTrules = false;

    /**
     * Indicated whether Tables should be loaded in a trules format
     */
    inline static bool loadTrules = false;

    /**
     * Maps Point numbers to their representations, that are vectors of point
     * numbers and coefficients
     */
    std::vector<std::pair<std::string, std::vector<std::pair<std::string, std::string>>>> relations;

    /**
     * Maps Point numbers to their real representations with indices
     */
    std::vector<std::pair<std::string, std::string>> representations;

    /**
     * Loads a relation line from a buffer in a trules format
     * @param buf the buffer to be read from
     * @param size the size of the buffer
     * @return nullptr in case of failure or end of line position otherwise
     */
    const char *LoadRelationLine(const char *buf, size_t size);

    /**
     * Loads a table from a buffer
     * @param buf the buffer to be read from
     * @param size the size of the buffer
     * @return succesfulness
     */
    bool Load(const char *buf, size_t size);

    /**
     * Loads a table from a file
     * @param filename the filename
     * @return succesfulness
     */
    bool LoadFile(const char *filename);

    /** @fn operator==(const Tables &, const Tables &) const
     * @brief Compare two points
     * @param t1 first table
     * @param t2 second table
     * @return True if they are equal
     */
    friend bool operator==(const Tables &t1, const Tables &t2);

    /** @fn operator!=(const Tables &, const Tables &) const
     * @brief Compare two points
     * @param t1 first table
     * @param t2 second table
     * @return True if they are not equal
     */
    friend bool operator!=(const Tables &t1, const Tables &t2);

    /** @fn operator<<(std::ostream &, const Tables &t)
     * @brief Output table to stream
     * @return stream
     */
    friend std::ostream &operator<<(std::ostream &out, const Tables &t);

    /** @fn operator>>(std::ostream &, const Tables &t)
     * @brief Input table from stream
     * @return stream
     */
    friend std::istream &operator>>(std::istream &in, Tables &t);
};

#endif // TABLES_H_INCLUDED
