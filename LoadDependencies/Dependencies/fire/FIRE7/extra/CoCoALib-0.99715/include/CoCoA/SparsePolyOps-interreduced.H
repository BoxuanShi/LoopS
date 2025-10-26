#ifndef CoCoA_SparsePolyOps_interreduced_H
#define CoCoA_SparsePolyOps_interreduced_H

//   Copyright (c)  2020  John Abbott,  Anna M. Bigatti

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
//   -------------------------------------------------------------------------

#include "CoCoA/ring.H"

#include <vector>
// using std::vector;

namespace CoCoA
{

  std::vector<RingElem> interreduced(std::vector<RingElem> v);
// NOT DEFINED!!  void interreduce(std::vector<RingElem>& v);

} // end of namespace CoCoA



// RCS header/log in the next few lines
// $Header: /Volumes/Home_1/cocoa/cvs-repository/CoCoALib-0.99/include/CoCoA/SparsePolyOps-interreduced.H,v 1.1 2020/10/14 20:01:54 abbott Exp $
// $Log: SparsePolyOps-interreduced.H,v $
// Revision 1.1  2020/10/14 20:01:54  abbott
// Summary: Renamed SparsePolyOps-interreduce to SparsePolyOps-interreduced
//
// Revision 1.1  2020/10/09 11:49:10  abbott
// Summary: New file for interreduced
//
//
//

#endif
