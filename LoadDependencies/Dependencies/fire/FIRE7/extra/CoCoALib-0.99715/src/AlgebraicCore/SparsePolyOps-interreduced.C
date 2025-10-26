//   Copyright (c)  2020  John Abbott,  Anna Bigatti
//   Original authors: Julian Danner (transcoded from CoCoA-5)

//   This file is part of the source of CoCoALib, the CoCoA Library.

//   CoCoALib is free software: you can redistribute it and/or modify
//   it under the terms of the GNU General Public License as published by
//   the Free Software Foundation, either version 3 of the License, or
//   (at your option) any later version.

//   CoCoALib is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License for more details.

//   You should have received a copy of the GNU General Public License
//   along with CoCoALib.  If not, see <http://www.gnu.org/licenses/>.


#include "CoCoA/SparsePolyOps-interreduced.H"

#include "CoCoA/SparsePolyOps-RingElem.H"
#include "CoCoA/interrupt.H"
#include "CoCoA/VectorOps.H"
#include "CoCoA/verbose.H"

//#include <vector>
using std::vector;


namespace CoCoA
{

  // Deliberately not defined!
  // void interreduce(std::vector<RingElem>& v)
  // {
  //   std::swap(v, interreduced(v));
  // }


  // naive impl (orig transcoded from CoCoA-5 by Julian Danner)
  std::vector<RingElem> interreduced(std::vector<RingElem> v)
  {
    static const char* const FnName = "interreduced";
    if (v.empty()) { return v; } // ??? or error???
    if (!HasUniqueOwner(v)) CoCoA_THROW_ERROR(ERR::MixedRings, FnName);
    VerboseLog VERBOSE(FnName);
    //delete possible zeros in v
    const ring& P = owner(v[0]);
    v.erase(std::remove(v.begin(), v.end(), zero(P)), v.end());

    // this local fn is used in call to sort
    const auto CompareLPPs = [](const RingElem& f, const RingElem& g) { return LPP(f)<LPP(g); };
    long count = 0;
    while (true)
    {
      VERBOSE(90) << "round " << ++count << std::endl; // NB *always* incrs count!
      sort(v.begin(), v.end(), CompareLPPs);
      vector<RingElem> ans;
      RingElem rem;
      bool NewLPPfound = false;
      for (const auto& f: v)
      {
        CheckForInterrupt(FnName);
        rem = NR(f, ans);
        if (IsZero(rem)) continue;
        ans.push_back(rem);
        NewLPPfound = (NewLPPfound || LPP(rem) != LPP(f));
//        if (!NewLPPfound && LPP(rem) != LPP(f))
//          NewLPPfound = true;
      }
      if (!NewLPPfound) return ans;
      swap(v, ans); // quicker than: v = ans;
    }
  }


} // end of namespace CoCoA


// RCS header/log in the next few lines
// $Header: /Volumes/Home_1/cocoa/cvs-repository/CoCoALib-0.99/src/AlgebraicCore/SparsePolyOps-interreduced.C,v 1.3 2020/11/19 18:29:10 abbott Exp $
// $Log: SparsePolyOps-interreduced.C,v $
// Revision 1.3  2020/11/19 18:29:10  abbott
// Summary: Added static keyword
//
// Revision 1.2  2020/10/23 07:54:20  abbott
// Summary: Improved commented out code (?!?)
//
// Revision 1.1  2020/10/14 20:01:54  abbott
// Summary: Renamed SparsePolyOps-interreduce to SparsePolyOps-interreduced
//
// Revision 1.2  2020/10/05 19:24:54  abbott
// Summary: Added comment
//
// Revision 1.1  2020/10/02 19:04:55  abbott
// Summary: New fn interreduce
//
//
//
