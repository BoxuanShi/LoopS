//   Copyright (c)  2016  John Abbott and Anna M. Bigatti

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


#include "CoCoA/verbose.H"
#include "CoCoA/error.H"
#include "CoCoA/LogStream.H"

#include <fstream>
using std::ofstream;
#include <iostream>
//#include <string>
using std::string;

namespace // anonymous
{
  
  // Global "bit-bucket" ostream
  std::ofstream DevNull;

} // end of namespace anonymous

namespace CoCoA
{

  // static data members (effectively global variables)
  long VerboseLog::ourNestingDepth = 0;
  long VerboseLog::ourVerbosityLevel = 0; // default 0 ==> print nothing
  

  VerboseLog::VerboseLog(const char* const FnName):
      myFnName(FnName)
  {
    ++ourNestingDepth;
  }

  VerboseLog::~VerboseLog()
  {
    --ourNestingDepth;
  }

  std::ostream& VerboseLog::operator()(long level)
  {
    if (level < 1) CoCoA_THROW_ERROR(ERR::NotPositive, "Verbosity level");
    if (level > ourVerbosityLevel) return DevNull;
    LogStream() << myFnName << '[' << ourNestingDepth << "]: ";
    return LogStream();
  }


  //  long SetVerbosityLevel(long NewLevel)
  void SetVerbosityLevel(long NewLevel)
  {
    if (NewLevel < 0) CoCoA_THROW_ERROR(ERR::NotNonNegative, "SetVerbosityLevel");
    //    const long OldValue = VerboseLog::ourVerbosityLevel;
    VerboseLog::ourVerbosityLevel = NewLevel;
    //    return OldValue;
  }

  long VerbosityLevel() noexcept
  {
    return VerboseLog::ourVerbosityLevel;
  }

} // end of namespace CoCoA


// RCS header/log in the next few lines
// $Header: /Volumes/Home_1/cocoa/cvs-repository/CoCoALib-0.99/src/AlgebraicCore/verbose.C,v 1.8 2021/02/10 19:40:01 abbott Exp $
// $Log: verbose.C,v $
// Revision 1.8  2021/02/10 19:40:01  abbott
// Summary: Added noexcept (sometimes instead of throw()) -- redmine 1572
//
// Revision 1.7  2021/01/07 15:23:39  abbott
// Summary: Corrected copyright
//
// Revision 1.6  2020/06/17 15:49:30  abbott
// Summary: Changed CoCoA_ERROR into CoCoA_THROW_ERROR
//
// Revision 1.5  2019/11/14 17:53:59  abbott
// Summary: Removed cruft
//
// Revision 1.4  2017/03/02 10:04:22  bigatti
// -- modified interface for VerbosityLevel
//
// Revision 1.3  2017/01/25 13:02:42  abbott
// Summary: Verbose logging mesgs now output to CoCoA::LogStream (instead of clog)
//
// Revision 1.2  2016/11/23 12:54:22  bigatti
// fixed IsVerbosityLevel
//
// Revision 1.1  2016/11/11 13:24:08  abbott
// Summary: new file for "verbose" capabilities
//
//
