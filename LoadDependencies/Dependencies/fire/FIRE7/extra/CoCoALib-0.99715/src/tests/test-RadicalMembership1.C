//   Copyright (c)  2017  John Abbott

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


#include "CoCoA/BuildInfo.H"
#include "CoCoA/GlobalManager.H"
#include "CoCoA/QuotientRing.H"
#include "CoCoA/SparsePolyOps-RadicalMembership.H"
#include "CoCoA/SparsePolyRing.H"
#include "CoCoA/error.H"
#include "CoCoA/ideal.H"
#include "CoCoA/ring.H"


#include <iostream>
using std::cerr;
using std::endl;

#include <vector>
using std::vector;

//----------------------------------------------------------------------
// This test checks that IsInRadical and MinPowerInIdeal work in some
// simple test cases.
//----------------------------------------------------------------------

namespace CoCoA
{
  // Put your code inside namespace CoCoA to avoid possibile
  // ambiguities with STL fns sharing names with CoCoALib fns.

  void program()
  {
    GlobalManager CoCoAFoundations;
    
    // Use ZZ/(32003) for coeffs as QQ is noticeably slower
    PolyRing P = NewPolyRing(NewZZmod(32003), symbols("x, y, z"));

    {
      // Monomial ideal ==> homogeneous
      ideal I = ideal(RingElem(P,"x^5"),
                      RingElem(P,"y^8"),
                      RingElem(P,"z^13"));

      CoCoA_ASSERT_ALWAYS(IsInRadical(RingElem(P,"x"), I));
      CoCoA_ASSERT_ALWAYS(IsInRadical(RingElem(P,"x^2"), I));
      CoCoA_ASSERT_ALWAYS(IsInRadical(RingElem(P,"x^99"), I));
      CoCoA_ASSERT_ALWAYS(IsInRadical(RingElem(P,"y"), I));
      CoCoA_ASSERT_ALWAYS(IsInRadical(RingElem(P,"y^2"), I));
      CoCoA_ASSERT_ALWAYS(IsInRadical(RingElem(P,"y^99"), I));
      CoCoA_ASSERT_ALWAYS(IsInRadical(RingElem(P,"z"), I));
      CoCoA_ASSERT_ALWAYS(IsInRadical(RingElem(P,"z^2"), I));
      CoCoA_ASSERT_ALWAYS(IsInRadical(RingElem(P,"z^99"), I));

      RingElem f1 = RingElem(P,"x+y");
      RingElem f2 = RingElem(P,"(x+y+z)^2");

      CoCoA_ASSERT_ALWAYS(!IsInRadical(f1+1,I));
      CoCoA_ASSERT_ALWAYS(!IsInRadical(f2+2,I));

      CoCoA_ASSERT_ALWAYS(IsInRadical(f1,I));
      CoCoA_ASSERT_ALWAYS(MinPowerInIdeal(f1,I) == 12);

      CoCoA_ASSERT_ALWAYS(IsInRadical(f2,I));
      CoCoA_ASSERT_ALWAYS(MinPowerInIdeal(f2,I) == 12);

      CoCoA_ASSERT_ALWAYS(IsInRadical(f1-f2,I));
      CoCoA_ASSERT_ALWAYS(MinPowerInIdeal(f1-f2,I) == 18);

      CoCoA_ASSERT_ALWAYS(!IsInRadical(f1+1,I));
      CoCoA_ASSERT_ALWAYS(MinPowerInIdeal(f1+1,I) == -1);

      CoCoA_ASSERT_ALWAYS(!IsInRadical(f2-1,I));
      CoCoA_ASSERT_ALWAYS(MinPowerInIdeal(f2-1,I) == -1);
    }

    {
      // Non homogeneous ideal
      RingElem g1 = RingElem(P,"2*x^2+3*y*z-x-4");
      RingElem g2 = RingElem(P,"3*x*y*z-5*x*z+2*y");
      ideal I = ideal(power(g1,4) + power(g2,3),
                      power(g1,4) - power(g2,3));

      RingElem f1 = g1*g1 + g2;
      CoCoA_ASSERT_ALWAYS(IsInRadical(f1,I));
      CoCoA_ASSERT_ALWAYS(!IsInRadical(f1 + RingElem(P,"x"),I));
      CoCoA_ASSERT_ALWAYS(MinPowerInIdeal(f1,I) == 4);
      
      RingElem f2 = g2*g2 + g1 - g2;
      CoCoA_ASSERT_ALWAYS(IsInRadical(f2,I));
      CoCoA_ASSERT_ALWAYS(!IsInRadical(f2 + RingElem(P,"y^2"),I));
      CoCoA_ASSERT_ALWAYS(MinPowerInIdeal(f2,I) == 6);
    }

  }

} // end of namespace CoCoA

//----------------------------------------------------------------------
// Use main() to handle any uncaught exceptions and warn the user about them.
int main()
{
  try
  {
    CoCoA::program();
    return 0;
  }
  catch (const CoCoA::ErrorInfo& err)
  {
    cerr << "***ERROR***  UNCAUGHT CoCoA Error";
    ANNOUNCE(cerr, err);
  }
  catch (const std::exception& exc)
  {
    cerr << "***ERROR***  UNCAUGHT std::exception: " << exc.what() << endl;
  }
  catch(...)
  {
    cerr << "***ERROR***  UNCAUGHT UNKNOWN EXCEPTION" << endl;
  }

  CoCoA::BuildInfo::PrintAll(cerr);
  return 1;
}
