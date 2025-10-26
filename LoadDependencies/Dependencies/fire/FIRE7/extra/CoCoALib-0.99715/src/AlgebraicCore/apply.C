//   Copyright (c)  2008  John Abbott and Anna M. Bigatti

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


#include "CoCoA/apply.H"
#include "CoCoA/MachineInt.H"
#include "CoCoA/DenseMatrix.H"
#include "CoCoA/utils.H"

#include <vector>
using std::vector;

namespace CoCoA
{

  // For vectors... now [2021-07-19] obsolescent???
  std::vector<RingElem> apply(const RingHom& phi, const std::vector<RingElem>& v)
  {
    const long n = len(v);
    vector<RingElem> ans; ans.reserve(n);
    for (const RingElem& x: v)
      ans.push_back(phi(x));
    return ans;
  }


  //PROTOTYPE IMPL!!!!!!!!
  //BUG BUG Result ought to be dense/sparse/diag according as M is....
  matrix apply(RingHom phi, ConstMatrixView M)
  {
    CoCoA_ASSERT(domain(phi) == RingOf(M));
    matrix NewM(NewDenseMat(codomain(phi), NumRows(M), NumCols(M)));
    for (long i=0; i < NumRows(M); ++i)
      for (long j=0; j < NumCols(M); ++j)
        SetEntry(NewM, i, j, phi(M(i,j)));
    return NewM;
  }


} // end of namespace CoCoA


// RCS header/log in the next few lines
// $Header: /Volumes/Home_1/cocoa/cvs-repository/CoCoALib-0.99/src/AlgebraicCore/apply.C,v 1.6 2021/07/19 13:09:26 abbott Exp $
// $Log: apply.C,v $
// Revision 1.6  2021/07/19 13:09:26  abbott
// Summary: Removed template fn apply (clash with std::apply) -- see redmine 1601
//
// Revision 1.5  2021/01/07 15:23:38  abbott
// Summary: Corrected copyright
//
// Revision 1.4  2020/01/26 14:41:16  abbott
// Summary: Added cinlude MachineInt
//
// Revision 1.3  2014/07/30 14:12:12  abbott
// Summary: Changed BaseRing into RingOf
// Author: JAA
//
// Revision 1.2  2011/03/03 13:50:22  abbott
// Replaced several occurrences of std::size_t by long; there's still more
// work to do though!
//
// Revision 1.1  2008/11/23 18:33:15  abbott
// First attempt at implementing an apply function for applying maps (RingHoms)
// to pure structures.
//
//
