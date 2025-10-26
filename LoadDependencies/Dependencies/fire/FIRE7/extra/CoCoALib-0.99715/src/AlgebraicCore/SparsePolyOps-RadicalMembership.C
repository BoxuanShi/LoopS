//   Copyright (c)  2017-2018, 2021  John Abbott,  Anna M. Bigatti
//   Original authors: Marvin Brandenstein, Alice Moallemy and Carsten Dettmar

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


#include "CoCoA/SparsePolyOps-RadicalMembership.H"

#include "CoCoA/RingHom.H"
#include "CoCoA/SparsePolyOps-RingElem.H"
//#include "CoCoA/SparsePolyRing.H"
#include "CoCoA/SparsePolyOps-ideal.H"
#include "CoCoA/VectorOps.H"
#include "CoCoA/apply.H"
#include "CoCoA/factor.H"
#include "CoCoA/ideal.H"
#include "CoCoA/interrupt.H"

#include <vector>
using std::vector;


namespace CoCoA
{

  namespace // anonymous
  {

    vector<RingElem> GensForRadical(const ideal& I)
    {
      vector<RingElem> ans = gens(I);
      // Next line gets rid of any zero gens:
      ans.erase(std::remove_if(ans.begin(), ans.end(),
                               /*IsZero*/[](const RingElem& f){return IsZero(f);}),
                ans.end());
      concat_copy(ans, ReducedGBasis(I));
      for (RingElem& g: ans)
      {
        RingElem radg = radical(g);
        if (LPP(g) != LPP(radg))
          swap(g, radg); // really assignment g = radg;
      }
      return ans;
    }


    // G is gens(I) but possibly with some sqfr polys included.
    bool RabinovichTrick(ConstRefRingElem f, const ideal& I, const vector<RingElem>& G)
    {
      if (IsElem(f,I)) return true; // simple special case

      const PolyRing& P = owner(G[0]);
      const ring& R = CoeffRing(P);
      PolyRing RabinovichPolyRing = NewPolyRing(R, NewSymbols(NumIndets(P)+1));
      const RingElem& t = indet(RabinovichPolyRing,NumIndets(P)); 
      vector<RingElem> image = indets(RabinovichPolyRing);
      image.pop_back();
      const RingHom Phi = PolyAlgebraHom(P, RabinovichPolyRing, image);
      vector<RingElem> newGens = Phi(G);////apply(Phi, G);
      newGens.push_back(1-t*Phi(f));
      return IsOne(ideal(newGens)); 
    }


  } // end of namespace anonymous
  

  bool IsInRadical(ConstRefRingElem f, const ideal& I)
  {
    const char* const FnName = "IsInRadical";
    if (owner(f) != RingOf(I))
      CoCoA_THROW_ERROR(ERR::MixedRings, FnName);
    if (!IsPolyRing(RingOf(I)) || !IsField(CoeffRing(RingOf(I))))
      CoCoA_THROW_ERROR(ERR::NotPolyRing, FnName); // BUG BUG err should say "polyring over field"

    const vector<RingElem> GensForRabinovich = GensForRadical(I);
    if (!IsHomog(I))
      return RabinovichTrick(f, I, GensForRabinovich);

    for (RingElem g=f; !IsZero(g); /*CutLF(g) inside loop body*/)
    {
      if (!RabinovichTrick(CutLF(g), I, GensForRabinovich))  // SLUG SLUG: wasteful recomputation of Rabinowitz ring!!!
        return false;
    }
    return true;
  }

  bool IsInRadical(const ideal& I, const ideal& J)
  {
    const vector<RingElem> GensForRabinovich = GensForRadical(J);
    for (const RingElem& g: gens(I))
    {
      if (!RabinovichTrick(g, I, GensForRabinovich)) // SLUG:  wasteful recomputation of RadcalHelpers
        return false;
    }
    return true;
  }



// // MinPowerInIdeal: Determines the minimal power m such that f^m is in the Ideal J
//   long MinPowerInIdeal_naive(ConstRefRingElem f, const ideal& I)
//   {
//     const char* const FnName = "MinPowerInIdeal";
//     if (owner(f) != RingOf(I))
//       CoCoA_THROW_ERROR(ERR::MixedRings, FnName);
//     if (!IsPolyRing(RingOf(I)) || !IsField(CoeffRing(RingOf(I))))
//       CoCoA_THROW_ERROR(ERR::NotPolyRing, FnName); // BUG BUG err should say "polyring over field"

//     if (!IsInRadical(f, I)) return -1;
//     long D = 1;
//     RingElem FpowD = f;
//     while (!IsElem(FpowD, I))
//     {
//       CheckForInterrupt(FnName);
//       FpowD *= f;
//       ++D;
//     }
//     return D;
//   }
  

// not sure if this is really any better than the sequential version below
  long MinPowerInIdeal_binary(RingElem f, const ideal& I)
  {
    const char* const FnName = "MinPowerInIdeal_binary";
    if (owner(f) != RingOf(I))
      CoCoA_THROW_ERROR(ERR::MixedRings, FnName);
    if (!IsPolyRing(RingOf(I)) || !IsField(CoeffRing(RingOf(I))))
      CoCoA_THROW_ERROR(ERR::NotPolyRing, FnName); // BUG BUG err should say "polyring over field"
//JAA: suggest clearing denoms (before & after NF?)
    f = NF(f,I);
    if (IsZero(f)) return 1;
    if (!IsInRadical(f, I)) return -1;  // WARNING: test can be slow/costly

    long D = 1;
    vector<RingElem> powers;
    RingElem FpowD = f;
    while (!IsZero(FpowD))
    {
      CheckForInterrupt(FnName);
      powers.push_back(FpowD);
      FpowD = NF(FpowD*FpowD, I);
      D *= 2;
    }
    D /= 2;
    long CurrPower = D;
    FpowD = powers.back();
    int n = len(powers)-1;
    while (D > 1)
    {
      CoCoA_ASSERT(n >= 1);
      --n; D /= 2;
      RingElem tmp = NF(FpowD*powers[n], I);
      if (IsZero(tmp)) continue;
      swap(FpowD, tmp);
      CurrPower += D;
    }
    return 1+CurrPower;
  }



// Exercise 5b): Alternative for MinPowerInIdeal using normal form
  // Just compute powers sequentially until we get NF=0.
  long MinPowerInIdeal(RingElem f, const ideal& I)
  {
    const char* const FnName = "MinPowerInIdeal";
    if (owner(f) != RingOf(I))
      CoCoA_THROW_ERROR(ERR::MixedRings, FnName);
    if (!IsPolyRing(RingOf(I)) || !IsField(CoeffRing(RingOf(I))))
      CoCoA_THROW_ERROR(ERR::NotPolyRing, FnName); // BUG BUG err should say "polyring over field"
//JAA: suggest clearing denoms (before & after NF?)
    f = NF(f,I);
    if (!IsInRadical(f, I)) return -1;  // WARNING: test can be slow/costly
    // simple sequential loop
    long D = 1;
    RingElem FpowD = f;
    while (!IsZero(FpowD))
    {
      CheckForInterrupt(FnName);
      FpowD = NF(FpowD*f, I);
      ++D;
    }
    return D;
  }



  
  // // MinPowerInIdealH (for homogeneous ideals): For every homogeneous
  // // component f_i, it determines the minimal exponent m_i, such that
  // // (f_i)^(m_i) is in the ideal J.
  // // Question: Knowing that, can we derive the minimal exponent m, s.t. f^m is in J?
  // vector<long> MinPowerInIdealH(ConstRefRingElem f, const ideal& J)
  // {
  //   vector<long> presumedExponent;
  //   vector<long> homogExponents; // alternative
  //   if (!IsInRadical(f, J))
  //   {
  //     presumedExponent.push_back(-1);
  //   }
  //   else if (!IsHomog(J))
  //   {
  //     presumedExponent.push_back(MinPowerInIdeal(f, J));
  //   }
  //   // f is in the radical of J, J is a radical ideal
  //   else {
  //     vector<RingElem> homogComp = HomogComp(f);	 

  //     for (int i = 0; i < len(homogComp); i++)
  //     {     
  //       homogExponents.push_back(MinPowerInIdeal(homogComp[i], J)); // alternative
  //     }

  //     // first conjecture: the minimal power m such that the polynomial f^m is in the Ideal J
  //     // equals the minimal power such that every homogenous component of f is in the Ideal J
  //     // second conjecture: the minimal power m such that the polynomial f^m is in the Ideal J
  //     // equals the product of the minimal powers for the homogenous components of f
  //     // such that every homogenous component of f is in the Ideal J
  //     // third conjecture: the minimal power m such that the polynomial f^m is in the Ideal J
  //     // equals the lcm of the minimal powers of the homogenous components 
  //     // such that every homogenous component of f is in the Ideal J
  //     // turns out: conjectures are wrong!
  //     // we could not find a simple connection between those powers
  //     presumedExponent.push_back(MaxElem(homogExponents));
  //     presumedExponent.push_back(Prod(homogExponents));
  //     presumedExponent.push_back(Lcm(homogExponents));
  //     cout << "Here the vector of powers for the homogenous components of the polynomial: " << homogExponents << endl; // alternative     
  //   }
  //   return presumedExponent;
  // }


} // end of namespace CoCoA


// RCS header/log in the next few lines
// $Header: /Volumes/Home_1/cocoa/cvs-repository/CoCoALib-0.99/src/AlgebraicCore/SparsePolyOps-RadicalMembership.C,v 1.7 2021/09/16 11:58:15 abbott Exp $
// $Log: SparsePolyOps-RadicalMembership.C,v $
// Revision 1.7  2021/09/16 11:58:15  abbott
// Summary: Removed cruft; minor cleaning (redmine 1565)
//
// Revision 1.6  2021/01/22 16:47:10  abbott
// Summary: Major update/cleaning (redmine 1565)
//
// Revision 1.5  2020/06/17 15:49:27  abbott
// Summary: Changed CoCoA_ERROR into CoCoA_THROW_ERROR
//
// Revision 1.4  2018/09/28 15:54:04  abbott
// Summary: Removed pseudo-ctors NewPolyRing which took just num of indets; now must specify their names
//
// Revision 1.3  2018/07/24 13:46:11  abbott
// Summary: Added CheckForInterrupt to potentially long loops
//
// Revision 1.2  2018/05/18 16:38:52  bigatti
// -- added include SparsePolyOps-RingElem.H
//
// Revision 1.1  2018/04/06 15:14:10  bigatti
// -- renamed RadicalMembership.C
//
// Revision 1.2  2018/03/15 14:18:06  bigatti
// -- added files SparsePolyOps-ideal.H and SparsePolyOps-involutive.H
//
// Revision 1.1  2017/07/19 16:39:02  abbott
// Summary: Added RadicalMembership
//
//
