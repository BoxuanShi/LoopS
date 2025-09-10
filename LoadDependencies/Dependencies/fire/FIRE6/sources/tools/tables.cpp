#include "tables.h"

std::istream &operator>>(std::istream &in, tables &t) {

    t.relations = {};
    t.representations = {};
    tables::errorMessage = "";

    char c = '\0';
    
    if (!in.get(c)) {
        tables::errorMessage =  "Missing or empty file";
        return in;
    }

    if (c!='{') {
        while (in.get(c) && c!='{') {}
        if (c != '{') {
            tables::errorMessage =  "No main starting {";
            return in;
        }
    }

    c = '\0';
    while (in.get(c) && c!='{') {}
    if (c != '{') {
        tables::errorMessage =  "No relations starting {";
        return in;
    }

    c = '\0';
    while (true) {
        // relations cycle
        while (in.get(c) && c!='}' && c!='{') {}
        if (c == '}') {
            break; // relations end
        }
        if (c != '{') {
            tables::errorMessage =  "No relation starting {";
            return in;
        }
        std::string left = "";

        while (in.get(c) && c!=',') {if (c > ' ' && c!='\\') left+=c;}
        if (c != ',') {
            tables::errorMessage =  "No relations separating ,";
            return in;
        }

        while (in.get(c) && c!='{') {}
        if (c != '{') {
            tables::errorMessage =  "No relations terms starting {";
            return in;
        }
        
        std::vector<std::pair<std::string,std::string>> relation;
        while (true) {

            // relation terms cycle
            while (in.get(c) && c!='}' && c!='{') {}
            if (c == '}') {
                break; // terms end
            }
            if (c != '{') {
                tables::errorMessage =  "No term starting {";
                return in;
            }
            std::string number = "";

            while (in.get(c) && c!=',') {if (c > ' ' && c!='\\') number+=c;}
            if (c != ',') {
                tables::errorMessage =  "No term separating ,";
                return in;
            }

            std::string coeff = "";

            while (in.get(c) && c!='}') {if (c > ' ' && c!='\\' && c!='"') coeff+=c;}
            if (c != '}') {
                tables::errorMessage =  "No term closing }";
                return in;
            }
            
            relation.emplace_back(number, coeff);

            while (in.get(c) && c!='}' && c!=',') {}

            if (c == '}') {                
                break; // closes terms
            }

            if (c != ',') {
                tables::errorMessage =  "No comma or closing } after term";
                return in;
            }
        }

        while (in.get(c) && c!='}') {}
        if (c != '}') {
            tables::errorMessage =  "No relation closing }";
            return in;
        }
        
        t.relations.emplace_back(left, relation);

        while (in.get(c) && c!='}' && c!=',') {}

        if (c == '}') {
            break; // closes terms
        }

        if (c != ',') {
            tables::errorMessage =  "No comma or closing } after relation";
            return in;
        }
    }

    while (in.get(c) && c!=',') {}
    if (c != ',') {
        tables::errorMessage =  "No comma after relations";
        return in;
    }

    while (in.get(c) && c!='{') {}
    if (c != '{') {
        tables::errorMessage =  "No number representations";
        return in;
    }

    while (true) {
        // representations cycle
        while (in.get(c) && c!='}' && c!='{') {}
        if (c == '}') {
            break; // representations end
        }
        if (c != '{') {
            tables::errorMessage =  "No representations starting {";
            return in;
        }
        std::string left = "";

        while (in.get(c) && c!=',') {if (c > ' ' && c!='\\') left+=c;}
        if (c != ',') {
            tables::errorMessage =  "No representations separating ,";
            return in;
        }

        while (in.get(c) && c!='{') {}
        if (c != '{') {
            tables::errorMessage =  "No starting { in integral";
            return in;
        }

        std::string temp = "";

        while (in.get(c) && c!=',') {if (c > ' ' && c!='\\') temp+=c;}
        if (c != ',') {
            tables::errorMessage =  "No comma in integral after number";
            return in;
        }
        unsigned int pn = stol(temp);

        while (in.get(c) && c!='{') {}
        if (c != '{') {
            tables::errorMessage =  "No starting { in integral for indices";
            return in;
        }

        std::vector<signed char> vec;
        while (true) {
            // reading vector of indices
            temp = "";
            while (in.get(c) && c!=',' && c!='}') {if (c > ' ' && c!='\\') temp+=c;}
            int ind = stoi(temp);
            vec.push_back(ind);

            if (c == '}') {
                break;
            }

            if (c != ',') {
                tables::errorMessage =  "No comma in integral after number";
                return in;
            }
        }

        t.representations.emplace_back(left, std::make_pair(pn, vec));

        c = '\0';
        while (in.get(c) && c!='}') {}
        if (c != '}') {
            tables::errorMessage =  "No closing } for integral pair";
            return in;
        }

        c = '\0';
        while (in.get(c) && c!='}') {}
        if (c != '}') {
            tables::errorMessage =  "No closing } for representation";
            return in;
        }

        c = '\0';
        while (in.get(c) && c!=',' && c!='}') {}

        if (c == '}') {
            // representations end
            break;
        }

        if (c != ',') {
            tables::errorMessage =  "No comma separating representations";
            return in;
        }

    }

    return in;
}

std::ostream &operator<<(std::ostream &out, const tables &t) {

    out << "{" << std::endl;
    out << "\t{";
    auto rcount = t.relations.size();
    for (const auto& relation : t.relations) {
        out << "\n\t\t{" << relation.first << ",\n\t\t\t{";
        auto tcount = relation.second.size();
        for(const auto& term : relation.second) {
            out << "\n\t\t\t\t{" << term.first << ", " << term.second << "}";
            if (--tcount) out << ",";
        }
        out << "\n\t\t\t}\n\t\t}";
        if (--rcount) out << ",";
    }
    out << "\n\t}\n,\n\t{";
    rcount = t.representations.size();
    for (const auto& representation : t.representations) {
        out << "\n\t\t{" <<representation.first << ", {" << representation.second.first << ", {";
        auto vcount = representation.second.second.size();
        for(const auto& index : representation.second.second) {
            out << int{index};
            if (--vcount) out << ", ";
        }
        out << "}}}";
        if (--rcount) out << ",";
    }
    out << "\n\t}\n}";

    return out;
}
    
bool operator!=(const tables &t1, const tables &t2) {
    return !(t1 == t2);
}

bool operator==(const tables &t1, const tables &t2) {
    if (t1.relations.size() != t2.relations.size()) {
        tables::errorMessage = "Sizes of relations to not match";
        return false;
    }
    if (t1.representations.size() != t2.representations.size()) {
        tables::errorMessage = "Sizes of representations to not match";
        return false;
    }
    for (size_t i = 0; i!=t1.representations.size(); ++i) {
        if (t1.representations[i] != t2.representations[i]) {
            tables::errorMessage = "Representations number " + std::to_string(i) + " do not match";
            return false;
        }
    }
    for (size_t i = 0; i!=t1.relations.size(); ++i) {
        if (t1.relations[i].first != t2.relations[i].first) {
            tables::errorMessage = "Relations numbers in part " + std::to_string(i) + " do not match";
            return false;
        }
        if (t1.relations[i].second.size() != t2.relations[i].second.size()) {
            tables::errorMessage = "Relations result sizes in part " + std::to_string(i) + " do not match";
            return false;
        }
        for (size_t j = 0; j!=t1.relations[i].second.size(); ++j) {
            if (t1.relations[i].second[j].first != t2.relations[i].second[j].first) {
                tables::errorMessage = "Relations numbers in parts {" + std::to_string(i) + ", " + std::to_string(j) + "} do not match";
                return false;
            }
            if (tables::compareCoefficients) {
                std::string diff = "(" + t1.relations[i].second[j].second + ")-(" + t2.relations[i].second[j].second + ")";
                fuel::simplify(diff, 0);    
                if (diff != "0") {
                    tables::errorMessage = "Relations coefficients in part {" + std::to_string(i) + ", " + std::to_string(j) + "} do not match";
                    //std::cout << diff << std::endl;
                    return false;
                }
            }
        }
    }

    tables::errorMessage = "";
    return true;
}
