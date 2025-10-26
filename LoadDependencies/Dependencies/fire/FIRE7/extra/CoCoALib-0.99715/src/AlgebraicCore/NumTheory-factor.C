//   Copyright (c)  1999,2009-2011,2019,2020  John Abbott and Anna M. Bigatti

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


#include "CoCoA/NumTheory-gcd.H"
#include "CoCoA/NumTheory-factor.H"

#include "CoCoA/BigIntOps.H"
#include "CoCoA/assert.H"
#include "CoCoA/bool3.H"
#include "CoCoA/config.H"
#include "CoCoA/convert.H"
#include "CoCoA/error.H"
#include "CoCoA/interrupt.H"
#include "CoCoA/utils.H"

#include <algorithm>
using std::min;
// using std::max;
// using std::swap;
#include <cmath>
// myThreshold uses floor,pow,sqrt
// #include <cstdlib>
// using std::ldiv;
#include <limits>
using std::numeric_limits;
#include <vector>
using std::vector;

namespace CoCoA
{

  namespace // anonymous
  {

    long SmoothFactor_ArgCheckLimit(const MachineInt& TrialLimit/*, const char* const FnName*/)
    {
      static const long BiggestSmallPrime = PrevPrime(numeric_limits<long>::max());
      if (!IsSignedLong(TrialLimit) || AsSignedLong(TrialLimit) < 1)
        CoCoA_THROW_ERROR(ERR::BadArg, "SmoothFactor:  TrialLimit must be at least 1 and fit into a machine long");
      // Below Pmax is unsigned long so that the code will work even if input TrialLimit is numeric_limits<long>::max()
      return min(BiggestSmallPrime,  AsSignedLong(TrialLimit));
    }


    // Divide n by highest power of b possible (to get integer result).
    // b need not be prime.
    // Changes value of n; returns multiplicity of b in original value of n.
    // EXCEPTION SAFE
    long DivideOutMaxPower_NoArgCheck(long b, long& n)
    {
      CoCoA_ASSERT(n != 0);
      CoCoA_ASSERT(b > 1);

      long mult = 0;
      while (n%b == 0)
      {
        n /= b;
        ++mult;
      }
      return mult;
    }


    // Divide N by highest power of b possible (to get integer result).
    // b need not be prime.
    // Changes value of N; returns multiplicity of b in original value of N.
    // EXCEPTION SAFE UNLESS GMP RUNS OUT OF MEMORY
    long DivideOutMaxPower_NoArgCheck(long b, BigInt& N)
    {
      CoCoA_ASSERT(b > 1);

      long mult = 0;
      {
        // Check if we can compute just with machine ints
        long n;
        if (IsConvertible(n, N))
        {
          mult = DivideOutMaxPower_NoArgCheck(b, n);
          N = n;
          return mult;
        }
      }
      // Case: N does not fit into a long
      // Repeatedly divide by largest power of prime which fits in ulong:
      long pwr = b;
      int exp = 1;
      const long limit = numeric_limits<long>::max()/b;
      while (pwr <= limit)
      {
        pwr *= b;
        ++exp;
      }
      // now pwr is largest power of base which fits into a long
      BigInt q,r; // used for quotient and remainder in loop below
      while (true)
      {
        CheckForInterrupt("DivideOutMaxPower_NoArgCheck");
        quorem(q, r, N, pwr); // r could be unsigned long...
        if (!IsZero(r)) break;
        swap(N,q); // really just assignment N = q;
        mult += exp;
      }
      // N was not div by pwr, but might still be div by base...
      long g = gcd(pwr, ConvertTo<long>(r)); // 0 < r < pwr
      // Need to be a bit careful below since b need not be prime!
      if (g < b) return mult;
      const long extra = DivideOutMaxPower_NoArgCheck(b, g);
      N /= SmallPower(b, extra);
      return mult + extra;
    }


    // Divide N by highest power of B possible (to get integer result).
    // B need not be prime.
    // Changes value of N; returns multiplicity of B in original value of N.
    // EXCEPTION SAFE UNLESS GMP RUNS OUT OF MEMORY
    long DivideOutMaxPower_NoArgCheck(const BigInt& B, BigInt& N)
    {
      CoCoA_ASSERT(B > 1);
      CoCoA_ASSERT(!IsZero(N));
      long b;
      if (IsConvertible(b, B)) return DivideOutMaxPower_NoArgCheck(b,N);
      long mult = 0;
      BigInt r;
      while (true)
      {
        CheckForInterrupt("DivideOutMaxPower_NoArgCheck");
        quorem(N, r, N, B);
        if (!IsZero(r)) break;
        ++mult;
      }
      return mult;
    }


  } // end of namespace anonymous

  //------------------------------------------------------------------

  long radical(const MachineInt& n)
  {
    if (IsZero(n)) return 0;
    const factorization<long> FacInfo = factor(n);
    const vector<long>& facs = FacInfo.myFactors();
    long ans = 1;
    for (const long p: facs)
      ans *= p;
    return ans;
  }

  BigInt radical(const BigInt& N)
  {
    if (IsZero(N)) return N;
    if (IsProbPrime(abs(N))) return abs(N);
    const factorization<BigInt> FacInfo = factor(N);
    const vector<BigInt>& facs = FacInfo.myFactors();
    BigInt ans(1);
    for (const BigInt& p: facs)
      ans *= p;
    return ans;
  }
  

  // EXCLUDES most negative long!
  factorization<long> SmoothFactor(const MachineInt& n, const MachineInt& TrialLimit)
  {
    const long Pmax = SmoothFactor_ArgCheckLimit(TrialLimit);
    if (IsZero(n))
      CoCoA_THROW_ERROR(ERR::BadArg, "SmoothFactor:  n must be non-zero");
    if (!IsSignedLong(n) || AsSignedLong(n) == numeric_limits<long>::min())
      CoCoA_THROW_ERROR(ERR::ArgTooBig, "SmoothFactor:  number to be factorized must fit into a machine long");
    long RemainingFactor = uabs(n); // cannot overflow since we exclude most neg long


    // Main loop: we simply do trial divisions by primes up to 31, & by numbers not divisible by 2,3,5,...,31.
    vector<long> factors;
    vector<long> exponents;

    // Use "mostly primes"; faster than using primes
    FastMostlyPrimeSeq TrialFactorSeq;
    
    long stop = Pmax; // highest prime we shall consider is "stop" (def'd below)
    if (RemainingFactor/stop < stop) stop = ConvertTo<long>(FloorSqrt(RemainingFactor));
    for (long p = *TrialFactorSeq; p <= stop; p = *++TrialFactorSeq)
    {
      if (RemainingFactor%p != 0) continue;
      const int exp = DivideOutMaxPower_NoArgCheck(p, RemainingFactor);
      CoCoA_ASSERT(exp > 0);
      factors.push_back(p);
      exponents.push_back(exp);
      if (RemainingFactor/stop < stop) stop = ConvertTo<long>(FloorSqrt(RemainingFactor));
    }
    // if RemainingFactor is non-triv & below limit, add it to the list of factors found.
    if (RemainingFactor > 1 && RemainingFactor <= Pmax)
    {
      factors.push_back(RemainingFactor);
      exponents.push_back(1);
      RemainingFactor = 1;
    }
    if (IsNegative(n))
      return factorization<long>(factors, exponents, -static_cast<long>(RemainingFactor));
    return factorization<long>(factors, exponents, RemainingFactor);
  }


  // This is very similar to the function above -- but I don't see how to share code.
  factorization<BigInt> SmoothFactor(const BigInt& N, const MachineInt& TrialLimit)
  {
    const long Pmax = SmoothFactor_ArgCheckLimit(TrialLimit);
    if (IsZero(N))
      CoCoA_THROW_ERROR(ERR::BadArg, "SmoothFactor(N,TrialLimit):  N must be non-zero");
    BigInt RemainingFactor = abs(N);

    // Main loop: we simply do trial divisions by primes up to 31 & then by numbers not divisible by 2,3,5,...,31.
    vector<BigInt> factors;
    vector<long> exponents;

    // Use "mostly primes"; faster than using primes
    FastMostlyPrimeSeq TrialFactorSeq;

    long stop = Pmax; // highest prime we shall consider is "stop"
    if (RemainingFactor/stop < stop) stop = ConvertTo<long>(FloorSqrt(RemainingFactor));
    long LogRemainingFactor = FloorLog2(RemainingFactor);
    long CountDivTests = 0;
    for (long p = *TrialFactorSeq; p <= stop; p = *++TrialFactorSeq)
    {
      CheckForInterrupt("SmoothFactor (main loop)");
      ++CountDivTests;
      // If several div tests have found no factors, check whether RemainingFactor is prime...
      if (p > 256 && CountDivTests == LogRemainingFactor && LogRemainingFactor < 64)
      {
        if (IsPrime(RemainingFactor)) break;
      }

      if (mpz_fdiv_ui(mpzref(RemainingFactor),p) != 0) continue;
      
      const long exp = DivideOutMaxPower_NoArgCheck(p, RemainingFactor); // updates RemainingFactor!!
      CoCoA_ASSERT(exp > 0);
      factors.push_back(BigInt(p));
      exponents.push_back(exp);
      LogRemainingFactor = FloorLog2(RemainingFactor);
      if (LogRemainingFactor < 64 && RemainingFactor/stop < stop)
        stop = ConvertTo<long>(FloorSqrt(RemainingFactor));
      CountDivTests = 0;
    }
    
    // if RemainingFactor is non-triv & below limit, add it to the list of factors found.
    if (RemainingFactor > 1 && RemainingFactor <= Pmax)
    {
      factors.push_back(RemainingFactor);
      exponents.push_back(1);
      RemainingFactor = 1;
    }
    if (N < 0)
      return factorization<BigInt>(factors, exponents, -RemainingFactor);
    return factorization<BigInt>(factors, exponents, RemainingFactor);
  }

  factorization<BigInt> SmoothFactor(const BigInt& N, const BigInt& TrialLimit)
  {
    if (IsZero(N))
      CoCoA_THROW_ERROR(ERR::BadArg, "SmoothFactor(N,TrialLimit):  N must be non-zero");
    if (TrialLimit < 1)
      CoCoA_THROW_ERROR(ERR::BadArg, "SmoothFactor(N,TrialLimit):  TrialLimit must be at least 1");
    
    // Not implemented for large TrialLimit because it would be hideously slow...
    // A naive implementation could simply copy code from SmoothFactor(N,pmax) above.
    long pmax;
    if (!IsConvertible(pmax, TrialLimit))
      CoCoA_THROW_ERROR(ERR::NYI, "SmoothFactor(N,TrialLimit) with TrialLimit greater than largest signed long");
    return SmoothFactor(N, pmax);
  }


  factorization<long> factor(const MachineInt& n)
  {
    if (IsZero(n))
      CoCoA_THROW_ERROR(ERR::BadArg, "factor(n):  n must be non-zero");
    if (!IsSignedLong(n))
      CoCoA_THROW_ERROR(ERR::ArgTooBig, "factor(n):  n must fit into a signed long");
    // Simple rather than efficient.
    if (uabs(n) < 2) return SmoothFactor(n,1);
    return SmoothFactor(n,uabs(n));
  }

  factorization<BigInt> factor(const BigInt& N)
  {
    if (IsZero(N))
      CoCoA_THROW_ERROR(ERR::BadArg, "factor(N):  N must be non-zero");
    const long PrimeLimit = FactorBigIntTrialLimit; // defined in config.H
    factorization<BigInt> ans = SmoothFactor(N, PrimeLimit);
    const BigInt& R = ans.myRemainingFactor();
    if (abs(R) == 1) return ans;
    if (abs(R) < power(PrimeLimit,2) || IsPrime(abs(R))) // ??? IsPrime or IsProbPrime ???
    {
      ans.myAppend(R,1);
      ans.myNewRemainingFactor(BigInt(sign(R)));
      return ans;
    }

    // Could check for abs(R) being a perfect power...
    CoCoA_THROW_ERROR(ERR::NYI, "factor(N) unimplemented in this case -- too many large factors");
    return ans;
  }


  //------------------------------------------------------------------

  PollardRhoSeq::PollardRhoSeq(const BigInt& N, long StartVal, long incr):
      myNumIters(1),
      myAnchorIterNum(1),
      myAnchorVal(StartVal),
      myN(abs(N)),
      myCurrVal(StartVal),
      myGCD(1),
      myStartVal(StartVal),
      myIncr(incr),
      myBlockSize(50)  // heuristic: 50-100 works well on my machine
  {
    if (myN < 2) CoCoA_THROW_ERROR(ERR::BadArg, "PollardRhoSeq ctor N must be >= 2");
    if (incr == 0) CoCoA_THROW_ERROR(ERR::BadArg, "PollardRhoSeq ctor incr must be non-zero");
  }


  void PollardRhoSeq::myAdvance(long k)
  {
    CoCoA_ASSERT(k > 0);
    const long stop = k + myNumIters; // BUG  overflow???
    while (myNumIters < stop)
    {
      if (!IsOne(myGCD)) return;  // don't advance if myGCD != 1
      BigInt prod(1);
      for (int j=0; j < myBlockSize; ++j)
      {
        myCurrVal = (myCurrVal*myCurrVal+myIncr)%myN;
        prod = (prod*(myCurrVal-myAnchorVal))%myN;
        ++myNumIters;
        if (myNumIters == 2*myAnchorIterNum)
        {
          myAnchorIterNum = myNumIters;
          myAnchorVal = myCurrVal;
        }
      }
      myGCD = gcd(myN, prod);
    }
  }


  bool IsEnded(const PollardRhoSeq& PRS) noexcept
  {
    return !IsOne(PRS.myGCD);
  }


  const BigInt& GetFactor(const PollardRhoSeq& PRS) noexcept
  {
//    if (!IsEnded(PRS)) CoCoA_THROW_ERROR("","");
    return PRS.myGCD;
  }


  long GetNumIters(const PollardRhoSeq& PRS) noexcept
  {
    return PRS.myNumIters;
  }


  std::ostream& operator<<(std::ostream& out, const PollardRhoSeq& PRS)
  {
    if (!out) return out;  // short-cut for bad ostreams
    if (out)
    {
      out << "PollardRhoSeq(N=" << PRS.myN
          << ",  start=" << PRS.myStartVal
          << ",  incr=" << PRS.myIncr
          << ",  NumIters=" << PRS.myNumIters
          << ",  gcd=" << PRS.myGCD << ")";
    }
    return out;
  }


  //------------------------------------------------------------------
  BigInt SumOfFactors(const MachineInt& n, long k)
  {
    if (IsNegative(n) || IsZero(n)) CoCoA_THROW_ERROR(ERR::NotPositive, "SumOfFactors");
    if (IsNegative(k)) CoCoA_THROW_ERROR(ERR::NotNonNegative, "SumOfFactors");
    const factorization<long> FacInfo = factor(n);
    const vector<long>& mult = FacInfo.myMultiplicities();
    const int s = len(mult);
    if (k == 0)
    {
      long ans = 1;
      for (int i=0; i < s; ++i)
        ans *= 1+mult[i];
      return BigInt(ans);
    }
    // Here k > 0
    BigInt ans(1);
    const vector<long>& fac = FacInfo.myFactors();
    for (int i=0; i < s; ++i)
      ans *= (power(fac[i], k*(mult[i]+1)) - 1)/(power(fac[i],k) - 1);
    return ans;
  }


  long SmallestNonDivisor(const MachineInt& N)
  {
    if (IsZero(N)) CoCoA_THROW_ERROR(ERR::NotNonZero, "SmallestNonDivisor");
    unsigned long n = uabs(N);
    if (IsOdd(n)) return 2;
    FastFinitePrimeSeq TrialDivisorList;
    while (n%(*TrialDivisorList) == 0)
      ++TrialDivisorList;
    return *TrialDivisorList;
  }
  
  long SmallestNonDivisor(const BigInt& N)
  {
    if (IsZero(N)) CoCoA_THROW_ERROR(ERR::NotNonZero, "SmallestNonDivisor");
    if (IsOdd(N)) return 2;
    // SLUG! simple rather than quick
    FastMostlyPrimeSeq TrialDivisorList;
    while (N%(*TrialDivisorList) == 0)
    {
      CheckForInterrupt("SmallestNonDivisor");
      ++TrialDivisorList;
    }
    return *TrialDivisorList;
  }


  bool IsSqFree(const MachineInt& N)
  {
    if (IsZero(N))
      CoCoA_THROW_ERROR(ERR::BadArg, "IsSqFree(N):  N must be non-zero");
    if (!IsSignedLong(N))
      CoCoA_THROW_ERROR(ERR::BadArg, "IsSqFree(N):  N must be non-zero");
    long n = uabs(N); // implicit cast to long is safe
    if (n < 4) return true;

    // Main loop: we simply do trial divisions by the first few primes, then divisors from NoSmallFactorSeq
    const long Pmax = min(FactorBigIntTrialLimit, MaxSquarableInteger<long>());
    long counter = 0;
    const long LogN = FloorLog2(N);
    const long TestIsPrime = (LogN>1000)?1000000:LogN*LogN;

    // Use "mostly primes"; much faster than using primes.
    FastMostlyPrimeSeq TrialFactorSeq;
    long p = *TrialFactorSeq;

    while (p <= Pmax)
    {
      ldiv_t qr = ldiv(n, p);
      if (p > qr.quot) return true;  // test  equiv to p^2 > N
      if (qr.rem == 0)
      {
        n = qr.quot;  // equiv. to N /= p;
        if (n%p == 0) return false;
      }
      else
      {
        ++counter;
        if (counter == TestIsPrime && IsProbPrime(n))
          return true;
      }

      ++TrialFactorSeq;
      p = *TrialFactorSeq;
    }

    if (counter < TestIsPrime && IsProbPrime(n)) return true;
    if (IsPower(n)) return false;
    return true;
  }


  bool3 IsSqFree(BigInt N)
  {
    if (IsZero(N))
      CoCoA_THROW_ERROR(ERR::BadArg, "IsSqFree(N):  N must be non-zero");
    N = abs(N);
    if (N < 4) return true3;

    // Main loop: we simply do trial divisions by the first few primes, then divisors from NoSmallFactorSeq
    const long Pmax = FactorBigIntTrialLimit;
    long counter = 0;
    const long LogN = FloorLog2(N);
    const long TestIsPrime = (LogN>1000)?1000000:LogN*LogN;

    // Use "mostly primes"; much faster than using primes.
    FastMostlyPrimeSeq TrialFactorSeq;
    long p = *TrialFactorSeq;

    BigInt quot, rem;
    while (p <= Pmax)
    {
      quorem(quot, rem, N, p);
      if (p > quot) return true3; // test  equiv to p^2 > N
      if (IsZero(rem))
      {
        swap(N, quot);  // equiv. to N /= p;
        if (N%p == 0) return false3;
      }
      else
      {
        ++counter;
        if (counter == TestIsPrime && IsProbPrime(N))
          return true3;
      }

      ++TrialFactorSeq;
      p = *TrialFactorSeq;
    }

    if (IsPower(N)) return false3;
    if (counter < TestIsPrime && IsProbPrime(N)) return true3;
    return uncertain3;
  }


  long FactorMultiplicity(const MachineInt& b, const MachineInt& n)
  {
    const char* const FnName = "FactorMultiplicity";
    if (IsZero(n)) CoCoA_THROW_ERROR(ERR::NotNonZero, FnName);
    if (IsNegative(b)) CoCoA_THROW_ERROR(ERR::BadArg, FnName);
    const long base = AsSignedLong(b);
    if (base == 0 || base == 1) CoCoA_THROW_ERROR(ERR::BadArg, FnName);
    long m = uabs(n);
    return DivideOutMaxPower_NoArgCheck(base, m);
  }


  long FactorMultiplicity(const MachineInt& b, BigInt N)
  {
    if (IsZero(N)) CoCoA_THROW_ERROR(ERR::NotNonZero, "FactorMultiplicity");
    if (IsNegative(b)) CoCoA_THROW_ERROR(ERR::BadArg, "FactorMultiplicity");
    const unsigned long base = AsUnsignedLong(b);
    if (base == 0 || base == 1) CoCoA_THROW_ERROR(ERR::BadArg, "FactorMultiplicity");

    return DivideOutMaxPower_NoArgCheck(base, N); // can overwrite N
  }

  long FactorMultiplicity(const BigInt& B, BigInt N)
  {
    const char* const FnName = "FactorMultiplicity";
    if (IsZero(N)) CoCoA_THROW_ERROR(ERR::NotNonZero, FnName);
    if (B < 2) CoCoA_THROW_ERROR(ERR::BadArg, FnName);
    return DivideOutMaxPower_NoArgCheck(B,N); // can overwrite N
  }


} // end of namespace CoCoA


// RCS header/log in the next few lines
// $Header: /Volumes/Home_1/cocoa/cvs-repository/CoCoALib-0.99/src/AlgebraicCore/NumTheory-factor.C,v 1.12 2021/02/10 19:40:00 abbott Exp $
// $Log: NumTheory-factor.C,v $
// Revision 1.12  2021/02/10 19:40:00  abbott
// Summary: Added noexcept (sometimes instead of throw()) -- redmine 1572
//
// Revision 1.11  2021/01/07 15:16:51  abbott
// Summary: Corrected copyright
//
// Revision 1.10  2020/10/29 20:27:32  abbott
// Summary: Corrected embarrassing bug in DivideOutMaxPower
//
// Revision 1.9  2020/10/05 19:24:29  abbott
// Summary: Added CheckForInterrupt in DivideOutMaxPower
//
// Revision 1.8  2020/09/28 11:18:37  abbott
// Summary: Tidying, removed cruft, added comments; new range for loop
//
// Revision 1.7  2020/09/22 18:16:36  abbott
// Summary: Overhauled SmoothFactor and FactorMultiplicity
//
// Revision 1.6  2020/06/17 15:49:24  abbott
// Summary: Changed CoCoA_ERROR into CoCoA_THROW_ERROR
//
// Revision 1.5  2020/06/16 18:01:14  abbott
// Summary: SmoothFactor is now interruptible (redmine 1457)
//
// Revision 1.4  2020/02/11 16:12:18  abbott
// Summary: Added some checks for bad ostream (even to mem fns myOutput); see redmine 969
//
// Revision 1.3  2020/01/26 14:41:59  abbott
// Summary: Revised includes after splitting NumTheory (redmine 1161)
//
// Revision 1.2  2019/09/16 17:31:07  abbott
// Summary: SmoothFactor now allows TrialLimit==1; added PollardRhoSeq
//
// Revision 1.1  2019/03/18 11:24:20  abbott
// Summary: Split NumTheory into several smaller files
//
//
