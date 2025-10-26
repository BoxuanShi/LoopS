//   Copyright (c)  2017  John Abbott and Anna M. Bigatti

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


#include "CoCoA/SparsePolyOps-resultant.H"

#include "CoCoA/ring.H"
#include "CoCoA/SparsePolyOps-RingElem.H"
//#include "CoCoA/SparsePolyRing.H" // from SparsePolyOps-RingElem.H
#include "CoCoA/verbose.H"

//#include <vector>
using std::vector;
#include <iostream>
using std::endl;

namespace CoCoA
{

  namespace // anonymous
  {
  RingElem lcx(ConstRefRingElem f, long x)
  {
    CoCoA_ASSERT(!IsZero(f));
    const vector<RingElem> c = CoeffVecWRT(f,indet(owner(f),x));
    return c.back();
  }

  RingElem prem(RingElem f, RingElem g, long x)
  {
    CoCoA_ASSERT(owner(f) == owner(g));
    CoCoA_ASSERT(!IsZero(g));
    if (IsZero(f)) return f;
    const ring& P = owner(f);
    const long degg = deg(g,x);
    if (degg == 0) return zero(P);
    long degf = deg(f,x);
    if (degf < degg) return f;
    const RingElem lcg = lcx(g,x);
    f *= power(lcg, degf-degg+1);
    while (degf >= degg)
    {
      const RingElem lcf = lcx(f,x);
      f -= (lcf/lcg)*g*power(indet(P,x), degf-degg); // exact division!
      if (IsZero(f)) return f;
      degf = deg(f,x);
    }
    return f;
  }

  } // end of namespace anonymous

  vector<RingElem> SubresultantSeq(ConstRefRingElem f, ConstRefRingElem g, long x)
  {
    VerboseLog VERBOSE("SubresultantSeq");
    VERBOSE(30) << "Inputs:" << endl;
    VERBOSE(30) << "f = " << f << endl;
    VERBOSE(30) << "g = " << g << endl;
    vector<RingElem> S;
    RingElem s = power(lcx(g,x), deg(f,x)-deg(g,x));
    RingElem A = g;
    RingElem B = prem(f,-g,x);
    VERBOSE(30) << "Before loop prem = " << B << endl;
    while (true)
    {
      if (IsZero(B)) return S;
      long dA = deg(A,x);
      long dB = deg(B,x);
      S.push_back(B);
      long delta = dA-dB;
      RingElem C;
      if (delta > 1)
      {
        VERBOSE(30) << "case delta > 1; in fact delta = " << delta << endl;
        VERBOSE(30) << "lcx(B,x) = " << lcx(B,x) << endl;
        VERBOSE(30) << "s = " << s << endl;
        VERBOSE(30) << "gcd = " << gcd(s, lcx(B,x)) << endl;
        C = power(lcx(B,x), delta-1)*B/power(s, delta-1);
        VERBOSE(30) << "C = " << C << endl;
        S.push_back(C);
      }
      else
      {
        VERBOSE(30) << "case delta=1" << endl;
        C = B;
      }
      if (dB == 0) return S;
      B = prem(A, -B, x)/(power(s,delta)*lcx(A,x));
      VERBOSE(30) << "prem = " << prem(A, -B, x) << endl;
      VERBOSE(30) << "denom = " << power(s,delta)*lcx(A,x) << endl;
      A = C;
      s = lcx(A,x);
    }
    // never get here
  }

  RingElem resultant(ConstRefRingElem f, ConstRefRingElem g, long x)
  {
    return SubresultantSeq(f,g,x).back();
  }

  
} // end of namespace CoCoA
  
