/** @file tables.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  Implementation of reading Tables from file, comparing them and writing
 */

#include "tables.h"

#include <sstream>

#include "tools.h"

// for mmap:
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>

const char *Tables::LoadRelationLine(const char *buf, size_t size) {

    const char *pos = buf;
    const char *end = buf + size;
    char c = '\0';

    while ((pos != end && (c = *(pos++))) && c != '{') {
    }
    if (c != '{') {
        Tables::errorMessage = "No relation line starting {";
        return nullptr;
    }
    while ((pos != end && (c = *(pos++))) && c != '{') {
    };
    if (c != '{') {
        Tables::errorMessage = "No relation pair starting {";
        return nullptr;
    }
    std::string temp = "";
    while ((pos != end && (c = *(pos++))) && c != ',') {
        if (c > ' ' && c != '\\')
            temp += c;
    }
    size_t i = stoi(temp);
    if (c != ',') {
        Tables::errorMessage = "No relation pair comma";
        return nullptr;
    }
    temp = "";
    while ((pos != end && (c = *(pos++))) && c != '}') {
        if (c > ' ' && c != '\\')
            temp += c;
    }
    size_t j = stoi(temp);
    if (c != '}') {
        Tables::errorMessage = "No relation pair ending }";
        return nullptr;
    }
    while ((pos != end && (c = *(pos++))) && c != '-') {
    };
    if (c != '-') {
        Tables::errorMessage = "No relation line intermediate -";
        return nullptr;
    }
    while ((pos != end && (c = *(pos++))) && c != '>') {
    };
    if (c != '>') {
        Tables::errorMessage = "No relation line intermediate >";
        return nullptr;
    }
    while ((pos != end && (c = *(pos++))) && c != '{') {
    };
    if (c != '{') {
        Tables::errorMessage = "No relation line intermediate {";
        return nullptr;
    }
    temp = "";
    while ((pos != end && (c = *(pos++))) && c != ',') {
        if (c > ' ' && c != '\\')
            temp += c;
    }
    std::string left = temp;
    if (c != ',') {
        Tables::errorMessage = "No relation line right part comma";
        return nullptr;
    }
    temp = "";
    while ((pos != end && (c = *(pos++))) && c != ',') {
        if (c > ' ' && c != '\\')
            temp += c;
    }
    std::string right = temp;
    if (c != ',') {
        Tables::errorMessage = "No relation line right part comma";
        return nullptr;
    }

    const char *pos_start = pos;
    std::string coeff = "";

    while ((pos != end && (c = *(pos++))) && c != '}') {
        if (c <= ' ' || c == '\\' || c == '"') {
            if (pos_start + 1 < pos) {
                coeff += std::string(pos_start, pos - pos_start - 1);
            }
            pos_start = pos;
        }
    }
    if (pos_start + 1 < pos) {
        coeff += std::string(pos_start, pos - pos_start - 1);
    }
    if (c != '}') {
        Tables::errorMessage = "No relation line closing }";
        return nullptr;
    }

    while ((pos != end && (c = *(pos++))) && c != '\n') {
    };
    if (c != '\n') {
        Tables::errorMessage = "No new line after relation line";
        return nullptr;
    }
    // std::cout << i << " | " << j << " | " << left << " | " << right << " | " <<
    // coeff << std::endl;
    if (relations.size() < i + 1) {
        relations.resize(i + 1);
    }
    if (relations[i].first != "" && relations[i].first != left) {
        Tables::errorMessage = "Incorrect left part of relation for " + std::to_string(i);
        return nullptr;
    }
    relations[i].first = left;
    if (relations[i].second.size() < j + 1) {
        relations[i].second.resize(j + 1);
    }
    if (relations[i].second[j].first != "" && relations[i].second[j].first != right) {
        Tables::errorMessage = "Incorrect left part of relation for " + std::to_string(i);
        return nullptr;
    }
    relations[i].second[j].first = right;
    relations[i].second[j].second = coeff;
    return pos;
}

bool Tables::Load(const char *buf, size_t size) {
    relations = {};
    representations = {};
    Tables::errorMessage = "";

    const char *pos = buf;
    const char *end = buf + size;
    char c = '\0';

    if (c != '{') {
        while ((pos != end && (c = *(pos++))) && c != '{') {
        }
        if (c != '{') {
            Tables::errorMessage = "No main starting { with size " + std::to_string(size);
            return false;
        }
    }

    c = '\0';
    while ((pos != end && (c = *(pos++))) && c != '{') {
    }
    if (c != '{') {
        Tables::errorMessage = "No relations starting {";
        return false;
    }

    if (Tables::loadTrules) {
        c = '\0';
        while ((pos != end && (c = *(pos++))) && c != ',') {
        }
        if (c != ',') {
            Tables::errorMessage = "No relation count comma";
            return false;
        }
        while ((pos != end && (c = *(pos++))) && c != ',') {
        }
        if (c != ',') {
            Tables::errorMessage = "No relation count comma";
            return false;
        }
        while ((pos != end && (c = *(pos++))) && c != '{') {
        }
        if (c != '{') {
            Tables::errorMessage = "No relation sizes start";
            return false;
        }
        while ((pos != end && (c = *(pos++))) && c != '}') {
        }
        if (c != '}') {
            Tables::errorMessage = "No relation sizes end";
            return false;
        }
        while (true) {
            while ((pos != end && (c = *(pos++))) && c != '}' && c != '{') {
            }
            if (c == '}') {
                break; // relations end
            }
            if (c != '{') {
                Tables::errorMessage = "No relation line starting {";
                return false;
            }
            --pos; // to stay on the bracket open
            pos = LoadRelationLine(pos, end - pos);
            if (pos == nullptr) {
                return false;
            }
        }
    } else {
        c = '\0';
        while (true) {
            // relations cycle
            while ((pos != end && (c = *(pos++))) && c != '}' && c != '{') {
            }
            if (c == '}') {
                break; // relations end
            }
            if (c != '{') {
                Tables::errorMessage = "No relation starting {";
                return false;
            }
            std::string left = "";

            while ((pos != end && (c = *(pos++))) && c != ',') {
                if (c > ' ' && c != '\\')
                    left += c;
            }
            if (c != ',') {
                Tables::errorMessage = "No relations separating ,";
                return false;
            }

            while ((pos != end && (c = *(pos++))) && c != '{') {
            }
            if (c != '{') {
                Tables::errorMessage = "No relations terms starting {";
                return false;
            }

            std::vector<std::pair<std::string, std::string>> relation;
            while (true) {

                // relation terms cycle
                while ((pos != end && (c = *(pos++))) && c != '}' && c != '{') {
                }
                if (c == '}') {
                    break; // terms end
                }
                if (c != '{') {
                    Tables::errorMessage = "No term starting {";
                    return false;
                }
                std::string number = "";

                while ((pos != end && (c = *(pos++))) && c != ',') {
                    if (c > ' ' && c != '\\')
                        number += c;
                }
                if (c != ',') {
                    Tables::errorMessage = "No term separating ,";
                    return false;
                }

                const char *pos_start = pos;
                std::string coeff = "";

                while ((pos != end && (c = *(pos++))) && c != '}') {
                    if (c <= ' ' || c == '\\' || c == '"') {
                        if (pos_start + 1 < pos) {
                            coeff += std::string(pos_start, pos - pos_start - 1);
                        }
                        pos_start = pos;
                    }
                }
                if (pos_start + 1 < pos) {
                    coeff += std::string(pos_start, pos - pos_start - 1);
                }
                if (c != '}') {
                    Tables::errorMessage = "No term closing }";
                    return false;
                }
                relation.emplace_back(number, coeff);

                while ((pos != end && (c = *(pos++))) && c != '}' && c != ',') {
                }

                if (c == '}') {
                    break; // closes terms
                }

                if (c != ',') {
                    Tables::errorMessage = "No comma or closing } after term";
                    return false;
                }
            }

            while ((pos != end && (c = *(pos++))) && c != '}') {
            }
            if (c != '}') {
                Tables::errorMessage = "No relation closing }";
                return false;
            }

            relations.emplace_back(left, relation);

            while ((pos != end && (c = *(pos++))) && c != '}' && c != ',') {
            }

            if (c == '}') {
                break; // closes terms
            }

            if (c != ',') {
                Tables::errorMessage = "No comma or closing } after relation";
                return false;
            }
        }
    }

    while ((pos != end && (c = *(pos++))) && c != ',') {
    }
    if (c != ',') {
        Tables::errorMessage = "No comma after relations";
        return false;
    }

    while ((pos != end && (c = *(pos++))) && c != '{') {
    }
    if (c != '{') {
        Tables::errorMessage = "No number representations";
        return false;
    }

    while (true) {
        // representations cycle
        while ((pos != end && (c = *(pos++))) && c != '}' && c != '{') {
        }
        if (c == '}') {
            break; // representations end
        }
        if (c != '{') {
            Tables::errorMessage = "No representations starting {";
            return false;
        }
        std::string left = "";

        while ((pos != end && (c = *(pos++))) && c != ',') {
            if (c > ' ' && c != '\\')
                left += c;
        }
        if (c != ',') {
            Tables::errorMessage = "No representations separating ,";
            return false;
        }

        while (pos != end && *pos == ' ') {
            ++pos;
        }

        int count_closing_bracket = 1;
        const char *pos2 = pos;
        while ((pos2 != end && (c = *(pos2++)))) {
            if (c == '{') {
                ++count_closing_bracket;
            } else if (c == '}') {
                --count_closing_bracket;
                if (count_closing_bracket == 0)
                    break;
            }
        }
        if (pos2 == end) {
            Tables::errorMessage = "Incorrect representation end";
            return false;
        }
        std::string right = std::string(pos, pos2 - pos - 1);
        right = replace_all(right, " ", "");
        // std::cout << right << std::endl;
        representations.push_back(std::make_pair(left, right));

        pos = pos2;
        c = '\0';
        while ((pos != end && (c = *(pos++))) && c != ',' && c != '}') {
        }

        if (c == '}') {
            // representations end
            break;
        }

        if (c != ',') {
            Tables::errorMessage = "No comma separating representations";
            return false;
        }
    }
    return true;
}

bool Tables::LoadFile(const char *filename) {
    int fd = open(filename, O_RDONLY);
    if (fd == -1) {
        Tables::errorMessage = "Missing or empty file";
        return false;
    }

    // obtain file size
    struct stat sb;
    if (fstat(fd, &sb) == -1) {
        Tables::errorMessage = "Cannot obtain file size";
        close(fd);
        return false;
    }

    char *buf = static_cast<char *>(mmap(NULL, sb.st_size, PROT_READ, MAP_PRIVATE, fd, 0u));
    if (buf == MAP_FAILED) {
        Tables::errorMessage = "Cannot mmap file";
        close(fd);
        return false;
    }

    bool result = Load(buf, sb.st_size);

    munmap(buf, sb.st_size);
    close(fd);

    return result;
}

/**
 * Read table from stream
 * @param in input ostream
 * @param t table to be loaded
 * @return reference to updated input stream
 */
std::istream &operator>>(std::istream &in, Tables &t) {

    size_t size = in.seekg(0, ios::end).tellg();
    if (!in) {
        Tables::errorMessage = "Missing or empty file";
        return in;
    }
    in.seekg(0);
    char *buf = new char[size];
    in.read(buf, size);
    t.Load(buf, size);
    delete[] buf;
    return in;
}

/**
 * Update output string stream, basically printing the table
 * @param out output ostream
 * @param t table to be printed
 * @return reference to updated output stream
 */
std::ostream &operator<<(std::ostream &out, const Tables &t) {

    if (Tables::saveTrules) {
        size_t count = 0;
        std::vector<size_t> lengths;
        for (unsigned i = 0; i != t.relations.size(); ++i) {
            for (unsigned j = 0; j != t.relations[i].second.size(); ++j) {
                std::stringstream sout;
                sout << "{{" << std::to_string(i) << "," << std::to_string(j) << "}->{" << t.relations[i].first << ","
                     << t.relations[i].second[j].first << ",\"" << t.relations[i].second[j].second << "\"}}";
                if (i != t.relations.size() - 1 || j != t.relations[i].second.size() - 1) {
                    sout << ",";
                }
                std::string res = sout.str();
                lengths.push_back(res.size() + 1);
                ++count;
            }
        }
        std::stringstream sout;
        sout << "{";
        for (size_t i = 0; i != lengths.size(); ++i) {
            sout << lengths[i];
            if (i != lengths.size() - 1) {
                sout << ",";
            } else {
                sout << "}," << std::endl;
            }
        }
        std::string res = sout.str();

        std::stringstream sout2;
        sout2 << "{{" << count << "," << res.size() << ",";
        std::string res2 = sout2.str();
        out << res2;
        size_t curLength = res2.size();
        while (curLength < 63) {
            out << " ";
            ++curLength;
        }
        out << std::endl;
        out << res;
        for (unsigned i = 0; i != t.relations.size(); ++i) {
            for (unsigned j = 0; j != t.relations[i].second.size(); ++j) {
                out << "{{" << std::to_string(i) << "," << std::to_string(j) << "}->{" << t.relations[i].first << ","
                    << t.relations[i].second[j].first << ",\"" << t.relations[i].second[j].second << "\"}}";
                if (i != t.relations.size() - 1 || j != t.relations[i].second.size() - 1) {
                    out << ",";
                }
                out << std::endl;
            }
        }
    } else {
        out << "{" << std::endl;
        out << "    {";
        auto rcount = t.relations.size();
        for (const auto &relation : t.relations) {
            out << "\n        {" << relation.first << ",\n            {";
            auto tcount = relation.second.size();
            for (const auto &term : relation.second) {
                out << "\n                {" << term.first << ",\"" << term.second << "\"}";
                if (--tcount)
                    out << ",";
            }
            out << "\n            }\n        }";
            if (--rcount)
                out << ",";
        }
    }
    out << "\n    }\n,\n    {";
    auto rcount = t.representations.size();
    for (const auto &representation : t.representations) {
        out << "\n        {" << representation.first << ", " << representation.second << "}";
        if (--rcount)
            out << ",";
    }
    out << "\n    }\n}";

    return out;
}

/** @fn operator!=(const Tables &, const Tables &) const
 * @brief Compare two tables
 * @param t1 first table
 * @param t2 second table
 * @return True if they are not equal
 */
bool operator!=(const Tables &t1, const Tables &t2) {
    return !(t1 == t2);
}

/** @fn operator==(const Tables &, const Tables &) const
 * @brief Compare two tables
 * @param t1 first table
 * @param t2 second table
 * @return True if they are equal. A simplication library is called
 */
bool operator==(const Tables &t1, const Tables &t2) {
    if (t1.relations.size() != t2.relations.size()) {
        Tables::errorMessage = "Sizes of relations to not match";
        return false;
    }
    if (t1.representations.size() != t2.representations.size()) {
        Tables::errorMessage = "Sizes of representations to not match";
        return false;
    }
    for (size_t i = 0; i != t1.representations.size(); ++i) {
        if (t1.representations[i] != t2.representations[i]) {
            Tables::errorMessage = "Representations number " + std::to_string(i) + " do not match";
            return false;
        }
    }
    if (Tables::compareRelations) {
        for (size_t i = 0; i != t1.relations.size(); ++i) {
            if (t1.relations[i].first != t2.relations[i].first) {
                Tables::errorMessage = "Relations numbers in part " + std::to_string(i) + " do not match";
                return false;
            }
            if (t1.relations[i].second.size() != t2.relations[i].second.size()) {
                Tables::errorMessage = "Relations result sizes in part " + std::to_string(i) + " do not match";
                return false;
            }
            for (size_t j = 0; j != t1.relations[i].second.size(); ++j) {
                if (t1.relations[i].second[j].first != t2.relations[i].second[j].first) {
                    Tables::errorMessage = "Relations numbers in parts {" + std::to_string(i) + ", " +
                                           std::to_string(j) + "} do not match";
                    return false;
                }
                if (Tables::compareCoefficients) {
                    std::string_view s1 = t1.relations[i].second[j].second;
                    std::string_view s2 = t2.relations[i].second[j].second;
                    while (true) {
                        auto pos1 = s1.find("|");
                        auto pos2 = s2.find("|");
                        if (pos1 == std::string::npos && pos2 != std::string::npos) {
                            Tables::errorMessage = "Relations coefficients in part {" + std::to_string(i) + ", " +
                                                   std::to_string(j) + "} have different number of subcoeffs";
                            return false;
                        }
                        if (pos1 != std::string::npos && pos2 == std::string::npos) {
                            Tables::errorMessage = "Relations coefficients in part {" + std::to_string(i) + ", " +
                                                   std::to_string(j) + "} have different number of subcoeffs";
                            return false;
                        }
                        std::string diff;
                        if (pos1 == std::string::npos) {
                            diff = "(" + std::string(s1) + ")-(" + std::string(s2) + ")";
                        } else {
                            diff =
                                "(" + std::string(s1.substr(0, pos1)) + ")-(" + std::string(s2.substr(0, pos2)) + ")";
                        }
                        fuel::simplify(diff, 0, Tables::primeSet);
                        if (diff != "0") {
                            Tables::errorMessage = "Relations coefficients in part {" + std::to_string(i) + ", " +
                                                   std::to_string(j) + "} do not match";
                            return false;
                        }
                        if (pos1 == std::string::npos) {
                            break;
                        } else {
                            s1 = s1.substr(pos1 + 1);
                            s2 = s2.substr(pos2 + 1);
                        }
                    }
                }
            }
        }
    }

    Tables::errorMessage = "";
    return true;
}
