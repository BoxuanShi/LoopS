//   Copyright (c)  1999,2009-2011  John Abbott  &  Anna M. Bigatti

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


#include "CoCoA/NumTheory-misc.H"
#include "CoCoA/NumTheory-factor.H"
#include "CoCoA/BigIntOps.H"
#include "CoCoA/error.H"


#include <vector>
using std::vector;

namespace CoCoA
{


  long EulerTotient(const MachineInt& n)
  {
    if (IsZero(n) || IsNegative(n))
      CoCoA_THROW_ERROR(ERR::BadArg, "EulerTotient(n):  n must be strictly positive");
    if (!IsSignedLong(n)) CoCoA_THROW_ERROR(ERR::ArgTooBig, "EulerTotient(n)");
    const factorization<long> facpows = factor(n);
    const vector<long>& primes = facpows.myFactors();
    long ans = AsSignedLong(n);
    const int NumPrimes = len(primes);
    for (int i=0; i < NumPrimes; ++i)
    {
      const long p = primes[i];
      ans = (ans/p)*(p-1);
    }
    return ans;
  }

  BigInt EulerTotient(const BigInt& N)
  {
    if (N <= 0)
      CoCoA_THROW_ERROR(ERR::BadArg, "EulerTotient(N):  N must be strictly positive");
    const factorization<BigInt> facpows = factor(N);
    const vector<BigInt>& primes = facpows.myFactors();

    BigInt ans = abs(N);
    const int NumPrimes = len(primes);
    for (int i=0; i < NumPrimes; ++i)
    {
      const BigInt p = primes[i];
      ans = (ans/p)*(p-1);
    }
    return ans;
  }






  //////////////////////////////////////////////////////////////////
  // Binomial repr of an integer.
  // A fair compromise between simplicity and speed.

  namespace  // file local fn
  {

    BigInt SearchUpwards(const BigInt& N, BigInt n, long r)
    {
      BigInt step(1);
      while (binomial(n+step,r) <= N)
      {
        n += step;
        step *= 2;
      }
      step /= 2; // step is power of 2 (may also be 1)
      while (step >= 1)
      {
        if (binomial(n+step, r) <= N)
          n += step;
        step /= 2;
      }
      return n;
    }

  } // end of anonymous namespace

  std::vector<BigInt> BinomialRepr(BigInt N, long r)
  {
    if (N < 0) CoCoA_THROW_ERROR(ERR::NotNonNegative, "BinomialRepr(N,r)");
    if (r < 1) CoCoA_THROW_ERROR(ERR::NotPositive, "BinomialRepr(N,r)");
    vector<BigInt> ans(r+1);
    while (r > 0 && N > 0)
    {
      BigInt lwb = (r-1 + FloorRoot(power(2,r)*factorial(r)*N, r))/2;
      if (N <= r || lwb < r) lwb = r;
      if (lwb == r && N > r) lwb = r+1;
      ans[r] = SearchUpwards(N, lwb, r);
      N -= binomial(ans[r], r);
      --r;
    }
    return ans;
  }

  BigInt BinomialReprShift(BigInt N, long r, long shift1, long shift2)
  {
    const vector<BigInt> n = BinomialRepr(N, r);
    BigInt ans;
    for (long i=1; i <= r; ++i)
    {
      if (n[i]==0) continue;
      if (i+shift2 < 0) continue;
      ans += binomial(n[i]+shift1, i+shift2);
    }
    return ans;
  }


} // end of namespace CoCoA


// RCS header/log in the next few lines
// $Header: /Volumes/Home_1/cocoa/cvs-repository/CoCoALib-0.99/src/AlgebraicCore/NumTheory-misc.C,v 1.2 2020/06/17 15:49:24 abbott Exp $
// $Log: NumTheory-misc.C,v $
// Revision 1.2  2020/06/17 15:49:24  abbott
// Summary: Changed CoCoA_ERROR into CoCoA_THROW_ERROR
//
// Revision 1.1  2020/01/26 14:14:31  abbott
// Summary: Finished splitting NumTheory into smaller pieces (redming 1161)
//
// Revision 1.89  2019/09/16 17:35:15  abbott
// Summary: Changed name EulerPhi into EulerTotient; changed iroot into FloorRoot
//
// Revision 1.88  2019/03/18 11:24:58  abbott
// Summary: Split NumTheory into several smaller files
//
// Revision 1.87  2019/03/04 16:18:27  abbott
// Summary: Added KroneckerSymbol; improved SmoothFactor
//
// Revision 1.86  2018/05/22 14:16:39  abbott
// Summary: Split BigRat into BigRat (class defn + ctors) and BigRatOps
//
// Revision 1.85  2018/05/18 12:15:04  bigatti
// -- renamed IntOperations --> BigIntOps
//
// Revision 1.84  2018/05/05 15:23:46  abbott
// Summary: Added primality test in SmoothFactor if there were several tests without finding a factor, and the RemainingFactor is not too big
//
// Revision 1.83  2018/04/20 18:51:25  abbott
// Summary: Changed ctors for BigInt/BigRat from string or from MPZ/MPQ
//
// Revision 1.82  2018/04/18 14:27:57  abbott
// Summary: Removed dirty trick from SmoothFactor
//
// Revision 1.81  2018/03/13 16:15:06  abbott
// Summary: Removed ProbPrimeIters (it is already in NumTheory-prime.C)
//
// Revision 1.80  2018/03/13 14:52:33  abbott
// Summary: Cleaned impl of RatReconstructByContFrac; added (commented-out) code for verbose
//
// Revision 1.79  2018/02/27 17:30:22  abbott
// Summary: Renamed NumTheory_prime to NumTheory-prime; changed includes
//
// Revision 1.78  2018/02/27 10:50:56  abbott
// Summary: Moved stuff about primes into NumTheory_prime
//
// Revision 1.77  2018/02/19 10:17:33  abbott
// Summary: Added comment
//
// Revision 1.76  2018/02/15 17:26:11  abbott
// Summary: Added EratosthenesRange, and PrimeSeq
//
// Revision 1.75  2018/01/17 10:29:52  abbott
// Summary: Changed InvModNoCheck into InvModNoArgCheck
//
// Revision 1.74  2018/01/16 11:42:51  abbott
// Summary: Changed NoThrow into RtnZeroOnError
//
// Revision 1.73  2017/11/08 14:03:56  abbott
// Summary: Added new fn SumOfFactors
//
// Revision 1.72  2017/10/17 15:51:00  abbott
// Summary: Replaced gcd(...)==1 by IsCoprime(...)
//
// Revision 1.71  2017/10/17 15:44:26  abbott
// Summary: Added new fn IsCoprime
//
// Revision 1.70  2017/04/18 09:59:30  bigatti
// -- separated errors in myAddInfo
//
// Revision 1.69  2016/11/23 15:37:25  abbott
// Summary: Now SmallestNonDivisor returns 0 if NextPrime reaches itslimit
//
// Revision 1.68  2016/11/22 14:31:01  abbott
// Summary: Added SmallestNonDivisor
//
// Revision 1.67  2016/11/11 14:15:32  abbott
// Summary: Added short-cut to operator<< when ostream is in bad state
//
// Revision 1.66  2016/10/25 20:54:09  abbott
// Summary: Added new fn IsSqFree (for BigInt and ringelem of PolyRing over field)
//
// Revision 1.65  2016/10/20 18:04:17  abbott
// Summary: Added radical; improved slightly factor and SmoothFactor
//
// Revision 1.64  2016/10/19 13:42:41  abbott
// Summary: Added radical for integers; fixed a bug in factor for MachineInt
//
// Revision 1.63  2016/07/04 11:05:39  abbott
// Summary: Removed two unnecessary assertions
//
// Revision 1.62  2016/06/29 13:11:37  abbott
// Summary: Added "NoThrow" option to InvMod; much cleaning inside NumTheory.C
//
// Revision 1.61  2016/04/19 08:53:26  bigatti
// -- fixed BinomialReprShift for 0 entries (case (45_2)^(+1) --> 55)
//
// Revision 1.60  2016/03/25 20:04:39  abbott
// Summary: Moved ExtendedEuclideanAlg into anon namespace
//
// Revision 1.59  2015/11/24 12:48:32  abbott
// Summary: Renamed "isqrt" --> "FloorSqrt"; also "ILogBase" --> "FloorLog"
//
// Revision 1.58  2015/11/21 19:17:53  abbott
// Summary: Added SimplestBinaryRatBetween; put InvModNoArgCheck_int into anon namespace
//
// Revision 1.57  2015/11/05 19:20:11  abbott
// Summary: Corrected two embarrassing bugs
//
// Revision 1.56  2015/11/05 14:18:19  abbott
// Summary: Changed InvMod to give error rather than return 0 if inv does not exist; added InvModNoArgCheck
//
// Revision 1.55  2015/10/09 18:26:36  abbott
// Summary: Corrected redmine reference
//
// Revision 1.54  2015/10/09 18:18:27  abbott
// Summary: Renamed "abs" to "uabs" for MachineInt; new fn "negate"; see redmine 783
//
// Revision 1.53  2015/07/30 15:57:43  abbott
// Summary: FactorMultiplicity now allows nonprime base
//
// Revision 1.52  2015/06/29 13:26:04  abbott
// Summary: Changed name "valuation" --> "FactorMultiplicity"; added new fns "BadMFactor"
// Author: JAA
//
// Revision 1.51  2014/10/28 15:12:08  abbott
// Summary: Renamed modulus --> CombinedModulus, residue --> CombinedResidue (for CRTMill)
// Author: JAA
//
// Revision 1.50  2014/09/16 10:41:41  abbott
// Summary: Added new fn eratosthenes (with doc, example, test)
// Author: JAA
//
// Revision 1.49  2014/09/01 16:25:52  abbott
// Summary: New condition for NextProbPrime/PrevProbPrime to use NextPrime/PrevPrime (previously allowed too large values); use new constant FactorBigIntTrialLimit; ExtGcd now gives error with args (0,0)
// Author: JAA
//
// Revision 1.48  2014/08/29 16:04:55  abbott
// Summary: Added optional 3rd arg to myAddInfo (so coprimality check is skipped)
// Author: JAA
//
// Revision 1.47  2014/05/06 13:13:36  abbott
// Summary: Removed useless fn PowerModLargeModulus
// Author: JAA
//
// Revision 1.46  2014/05/02 13:54:06  abbott
// Summary: Simplified ctor interface for RatReconstruct* (need explicit arg 0 for default behaviour)
// Author: JAA
//
// Revision 1.45  2014/04/24 09:54:50  abbott
// Summary: Corrected arg check in RatReconstructWithBounds
// Author: JAA
//
// Revision 1.44  2014/04/15 13:27:19  abbott
// Summary: Changed rtn type of PrimitiveRoot to long (for CoCoA-5/BuiltinOneLiners)
// Author: JAA
//
// Revision 1.43  2014/04/11 13:33:59  abbott
// Summary: Updated several assertions following revision of MaxSquarableInteger
// Author: JAA
//
// Revision 1.42  2014/04/04 10:15:17  abbott
// Summary: Updated to new interface for MaxSquarableInteger
// Author: JAA
//
// Revision 1.41  2014/03/24 12:09:21  abbott
// Summary: Major revision to public interface of factorization template class
// Author: JAA
//
// Revision 1.40  2014/01/16 16:09:54  abbott
// Added NumPartitions.
//
// Revision 1.39  2013/10/15 16:20:03  abbott
// Added valuation.
//
// Revision 1.38  2013/05/21 14:31:45  abbott
// Added BinomialRepr and BinomialReprShift to CoCoALib and CoCoA-5.
//
// Revision 1.37  2013/05/20 15:47:09  abbott
// Added new fn BinomialRepr (placed in NumTheory).
//
// Revision 1.36  2013/03/26 14:58:59  abbott
// Replaced calls to obsolete proc "convert" by calls to "ConvertTo<...>".
//
// Revision 1.35  2013/02/26 11:29:17  abbott
// Added impl of RatReconstructWithBounds
//
// Revision 1.34  2013/02/22 22:43:56  abbott
// Consequential change: new syntax for getting result from CRTMill.
//
// Revision 1.33  2013/02/22 18:56:50  abbott
// Added feature that RatReconstructByContFrac & RatReconstructByLattice
// ctors accept arg 0 to mean "use default value".
//
// Revision 1.32  2013/02/19 18:48:15  abbott
// Added printing for CRTMill and RatReconstructByContFrac and RatReconstructByLattice.
//
// Revision 1.31  2013/02/15 17:46:00  abbott
// Added RatReconstructByContFrac and RatReconstructByLattice.
//
// Revision 1.30  2012/12/12 18:25:06  abbott
// Added new fn IsFinal for ContFracIter.
// Corrected (subtle) bug in SimplestBigRatBetween.
//
// Revision 1.29  2012/12/12 10:39:06  abbott
// Corrected (embarrassing) typo in an assertion.
//
// Revision 1.28  2012/12/11 17:30:30  abbott
// Changed name from SimplestRationalInInterval to SimplestBigRatBetween.
// Also fixed a bug in the impl.
//
// Revision 1.27  2012/12/05 15:09:24  abbott
// Added new class ContFracApproximant.
// Added new fn SimplestBigRatBetween (NB name changed on 2012-12-11).
// Some minor cleaning.
//
// Revision 1.26  2012/12/04 20:14:11  abbott
// Added new class CRTMill.
// Improved impl of ContFracIter class.
// Fixed a bug in CFApproxIter class.
//
// Revision 1.25  2012/10/22 10:30:56  abbott
// SmoothFactor now allows limit to be 1 (previously it wanted limit >= 2).
//
// Revision 1.24  2012/10/05 09:30:35  abbott
// Changed myExponents into myMultiplicities.
//
// Revision 1.23  2012/09/26 12:51:26  abbott
// Clarified a comment about IsProbPrime.
//
// Revision 1.22  2012/06/29 15:17:27  abbott
// Fixed issue #199.
//
// Revision 1.21  2012/05/28 09:18:21  abbott
// Created IntOperations which gathers together all operations on
// integers (both big and small).  Many consequential changes.
//
// Revision 1.20  2012/03/16 15:40:12  abbott
// Merged contents of NumTheoryQQ (continued fraction functions) into NumTheory.
// Merged the doc too.
//
// Revision 1.19  2011/11/09 14:09:53  bigatti
// -- renamed MachineInteger --> MachineInt
//
// Revision 1.18  2011/09/06 13:39:08  abbott
// Minor cleaning: now uses "int" for increments and decrements in NextPrime & PrevPrime.
// Fixed (embarrassing) overflow bug.
//
// Revision 1.17  2011/08/14 15:52:17  abbott
// Changed ZZ into BigInt (phase 1: just the library sources).
//
// Revision 1.16  2011/03/23 21:00:46  abbott
// Removed FindPrimRoot from NumTheory.H because it was already
// available as PrimitiveRoot (a better name).
// Updated documentation for NumTheory.
//
// Revision 1.15  2011/03/22 20:17:18  abbott
// Added fn FindPrimRoot.
// Merged impls from obsolescent SmallPrime.C.
//
// Revision 1.14  2011/03/16 13:26:36  abbott
// Removed all "unsigned" from fn interfaces, and many unsigned from inside fn impls.
//
// Revision 1.13  2011/01/19 16:12:18  bigatti
// -- added ERR::ModulusLT2
//
// Revision 1.12  2010/03/05 21:37:58  abbott
// Completed implementation of MultiplicativeOrderMod.
//
// Revision 1.11  2010/03/03 15:02:09  abbott
// Corrected bug in PowerMod: forgot to give error for negative power of non-invertible base.
// Added tests of PowerMod to test-NumTheory1.C (and consequent change to expected output).
//
// Revision 1.10  2010/03/03 10:43:34  abbott
// Added PrimitiveRoot for big primes (might be very slow).
// Added MultiplicativeOrderMod (currently very SLUGGY implementation).
//
// Revision 1.9  2009/12/29 22:44:32  abbott
// Removed buggy proxy class ZZ::rtn.
// Consequent changes for function prototypes also in NumTheory.
// Corrected some minor buglets in NumTheory.
//
// Revision 1.8  2009/12/11 11:46:32  abbott
// Changed fn  convert  into  IsConvertible.
// Added template procedure  convert.
// New version because change is not backward compatible.
//
// Revision 1.7  2009/12/03 17:41:47  abbott
// Minor correction to a comment.
//
// Revision 1.6  2009/10/08 13:39:47  abbott
// Renamed "round" into "RoundDiv".
// Added some new versions of "RoundDiv".
// Added a test for "RoundDiv".
//
// Revision 1.5  2009/09/29 12:26:13  abbott
// Added patch/workaround for a problem in gmp-4.3.1, so that exgcd gives
// the right answers (gmp-4.3.1 no longer produces reduced cofactors).
//
// Revision 1.4  2009/07/06 12:30:48  abbott
// Fixed incorrect assertion in IsBigPrime.
// Corrected a bug in SmoothFactor (had > instead of >=), and tidied up a little.
//
// Revision 1.3  2009/07/02 16:28:10  abbott
// Fairly extensive change to NumTheory (at least internally and philosophically).
// Improved and cleaned NumTheory.  Added documentation.
// Clarified the exact behaviour of most functions.
//
// Revision 1.2  2009/06/11 14:10:58  abbott
// Added commented out procedural forms for gcd/lcm, in case we should
// later want to activate them.
//
// Revision 1.1  2009/06/05 12:14:55  abbott
// Major change:
//   created new files NumTheory.H/C  which contain basic number theory operations
//   removed several basic number theory operations from ZZ.H/C
//   removed gcd from MachineInt.H/C
//   changed names of some basic fns:
//      IsPPrime -> IsProbPrime
//      invmod -> InvMod    (changed signature too)
//      powermod -> PowerMod  (changed signature too)
//   added new fns
//      NextProbPrime & PrevProbPrime
//   consequent changes to other code and tests and examples
//
//
