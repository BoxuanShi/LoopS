#ifndef CoCoA_combinatorics_H
#define CoCoA_combinatorics_H

//   Copyright (c)  2015,2020  John Abbott,  Anna M. Bigatti

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


#include "CoCoA/MachineInt.H"

#include <vector>
// using std::vector;

namespace CoCoA
{

  BigInt NumPartitions(const MachineInt& n);

  std::vector<long> RandomSubsetIndices(const MachineInt& n);
  std::vector<long> RandomSubsetIndices(const MachineInt& n, const MachineInt& r);

  std::vector<long> RandomTupleIndices(const MachineInt& n, const MachineInt& r);

  std::vector<long> RandomPermutation(const MachineInt& n);

  int signature(const std::vector<int>& perm) noexcept;
  int signature(const std::vector<long>& perm) noexcept;

} // end of namespace CoCoA



// RCS header/log in the next few lines
// $Header: /Volumes/Home_1/cocoa/cvs-repository/CoCoALib-0.99/include/CoCoA/combinatorics.H,v 1.6 2021/02/10 19:32:01 abbott Exp $
// $Log: combinatorics.H,v $
// Revision 1.6  2021/02/10 19:32:01  abbott
// Summary: Added noexcept (redmine 1572)
//
// Revision 1.5  2021/01/07 14:48:33  abbott
// Summary: Corrected copyright
//
// Revision 1.4  2020/09/22 18:11:22  abbott
// Summary: Added signature (of a perrm); made NumPartitions interruptible
//
// Revision 1.3  2020/01/26 14:16:52  abbott
// Summary: Moved NumPartitions from NumTheory to here
//
// Revision 1.2  2018/08/28 12:35:41  abbott
// Summary: Added new fn RandomPermutation
//
// Revision 1.1  2015/05/20 13:38:32  abbott
// Summary: New files for combinatorial fns: RandomSubset, RandomTuple
// Author: JAA
//
//

#endif
