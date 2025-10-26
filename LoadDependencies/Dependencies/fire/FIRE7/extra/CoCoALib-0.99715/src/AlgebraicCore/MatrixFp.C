//   Copyright (c)  1997-2007,2016,2018  John Abbott and Anna M. Bigatti

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

#include "CoCoA/MatrixFp.H"
#include "CoCoA/matrix.H"
#include "CoCoA/DenseMatrix.H"
#include "CoCoA/convert.H"
#include "CoCoA/RingFp.H"
#include "CoCoA/utils.H"
#include "CoCoA/VectorOps.H"
#include "CoCoA/verbose.H"

#include <iostream>
using std::endl;
#include <vector>
using std::vector;

// /* Two bits used in the return value */
// const int FFsolve_new_pivot = 2;
// const int FFsolve_invalid = 1;



/* Find a solution to a system of linear equations (in place).          */
/* Several right hand side vectors may be specified.                    */
/* Method is just direct Gaussian elimination -- fine for finite fields */
/* The value returned is the rank of M.                                 */
/* The result is placed in soln; if there is no solution for some rhs   */
/* vector then its solution has first coordinate equal to p, the modulus.*/

namespace CoCoA
{


  MatrixFp::MatrixFp(const SmallFpImpl& ModP, int nrows, int ncols):
      myRows(nrows),
      myCols(ncols),
      myArith(ModP),
      myM(nrows, std::vector<SmallFpImpl::value>(ncols))
  {}


  MatrixFp::MatrixFp(const ConstMatrixView& M):
      myRows(NumRows(M)),
      myCols(NumCols(M)),
      myArith(ModularArith(RingOf(M))), // ASSUME small prime!!!
      myM(myRows, std::vector<SmallFpImpl::value>(myCols))
  {
    for (int i=0; i < myRows; ++i)
      for (int j=0; j < myCols; ++j)
        myM[i][j] = myArith.myReduce(ConvertTo<long>(M(i,j)));
  }





class MatrixFpNonRed
{
public:
  MatrixFpNonRed(long nrows, long ncols);
//  MatrixFpNonRed();
  void mySwapRows(long r1, long r2) {CoCoA_ASSERT(0 <= r1 && r1 < myRows && 0 <= r2 && r2 < myRows); if (r1 != r2) std::swap(myM[r1],myM[r2]);} ;
  SmallFpImpl::NonRedValue& operator()(long r, long c);
  const SmallFpImpl::NonRedValue& operator()(long r, long c) const;
//  friend void SetEntry(MatrixFp& M, long r, long c, SmallFpImpl::value x);
  
private:
  long myRows;
  long myCols;
  std::vector< std::vector< SmallFpImpl::NonRedValue > > myM;
};

MatrixFpNonRed::MatrixFpNonRed(long nrows, long ncols):
    myRows(nrows),  // clang says unused???
    myCols(ncols),  // clang says unused???
    myM(nrows, std::vector<SmallFpImpl::NonRedValue>(ncols))
{}

  inline SmallFpImpl::NonRedValue& MatrixFpNonRed::operator()(long r, long c) { return myM[r][c]; }
  inline const SmallFpImpl::NonRedValue& MatrixFpNonRed::operator()(long r, long c) const { return myM[r][c]; }


  MatrixFp MulByTr(const MatrixFp& M1, const MatrixFp& trM2)
  {
    CoCoA_ASSERT(ModPArith(M1) == ModPArith(trM2));
    CoCoA_ASSERT(NumCols(M1) == NumCols(trM2)); // YES!!! I do mean NumCols(trM2)
    const SmallFpImpl& ModP = ModPArith(M1);
    MatrixFp ans(ModP, NumRows(M1), NumRows(trM2));
    for (int i=0; i < NumRows(M1); ++i)
      for (int j=0; j < NumRows(trM2); ++j)
      {
        SmallFpImpl::NonRedValue sum = zero(SmallFp);
        for (int k=0; k < NumCols(M1); ++k)
          sum += M1(i,k)*trM2(j,k); // BUG add overflow check!
        ans(i,j) = ModP.myNormalize(sum);
      }
    return ans;
  }


class LinSolver
{
public:
  LinSolver(/*const SmallFpImpl& Modp,*/ const MatrixFp& M, const MatrixFp& rhs);
//??  LinSolver(const matrix& M, const matrix& rhs);
  friend long rk(LinSolver& LS);
  friend const MatrixFp& soln(/*const*/ LinSolver& LS);
private:
  void SolveByGauss();
private: // data members
  long myNrows;
  long myNcols;
  long myRHScols;
  long myRank; // -1 means not yet solved, non-neg is true value
  const SmallFpImpl& myModP;
  MatrixFpNonRed myM; // matrix and rhs concatenated
  MatrixFp mySoln;
  std::vector<bool> mySolnIsValid;
  std::vector<long> myPivotRow;
};

 long rk(LinSolver& LS) { if (LS.myRank < 0) LS.SolveByGauss(); return LS.myRank; }
const MatrixFp& soln(/*const*/ LinSolver& LS) { if (LS.myRank < 0) LS.SolveByGauss(); return LS.mySoln;} 

  LinSolver::LinSolver(/*const SmallFpImpl& Modp,*/ const MatrixFp& M, const MatrixFp& rhs):
    myNrows(NumRows(M)),
    myNcols(NumCols(M)),
    myRHScols(NumCols(rhs)),
    myRank(-1),
    myModP(ModPArith(M)),
    myM(myNrows, myNcols+myRHScols),
    mySoln(myModP, myNrows, myRHScols),
    mySolnIsValid(myRHScols), /// ??? init val
    myPivotRow(myNcols)  ///??? init val?
{
  CoCoA_ASSERT(NumRows(rhs) == myNrows);
//  CoCoA_ASSERT(NumRows(rhs) == myNrows);
  // Fill myM
  for (int i=0; i < myNrows; ++i)
  {
    for (int j=0; j < myNcols; ++j)
    {
      myM(i,j) = M(i,j);
    }
    for (int j=0; j < myRHScols; ++j)
    {
      myM(i, j+myNcols) = rhs(i,j);
    }
  }
}

//int FFsolve(FFmat soln, int *shape, FFmat matrix, FFmat RHS)
//int LinSolveInPlace(vector<vector< SmallFpImpl::NonRedValue> >& M, int ncols)
void LinSolver::SolveByGauss()//const SmallFpImpl& Modp, MatrixFp& soln, const MatrixFp& M, const MatrixFp& rhs)
{
  int ReducedRows = 0;
  const int AllCols = myNcols+myRHScols;
  const SmallFpImpl& Modp = myModP;
  const long TimeToReduce = Modp.myMaxIters();
  long count = 0;
//  vector<int> PivotRow(ncols);
//  pivot_row = (int*)MALLOC(ncols*sizeof(int));
  // Do Gauss redn col-by-col from lhs
  for (int i=0; i < myNcols; ++i)
  {
    bool ZeroCol = true;
    SmallFpImpl::value pivot;
    for (int j=ReducedRows; j < myNrows; ++j)
    {
      pivot = Modp.myNormalize(myM(j,i));
      if (!IsZero(pivot)) { ZeroCol = false; break;}
    }
    if (ZeroCol)
    {
///      if (shape[i]) { FREE(pivot_row); return FFsolve_invalid; }
      continue;
    }
// What does next block do????
    // if (!shape[i])
    // {
    //   shape[i] = 1;
    //   result |= FFsolve_new_pivot;
    //   for (k=i+1; k < ncols; ++k) shape[k] = 0;
    // }
    myPivotRow[ReducedRows] = i;
    myM.mySwapRows(ReducedRows, i);
    // swap = M[j]; M[j] = M[trows]; M[trows] = swap;
    // swap = rhs[j]; rhs[j] = rhs[trows]; rhs[trows] = swap;
//    const SmallFpImpl::value invMii = Modp.myRecip(myM(ReducedRows,i));
    const SmallFpImpl::value inv_pivot = Modp.myRecip(pivot);
    for (int j=i; j < AllCols; ++j)
      myM(ReducedRows,j) = Modp.myMul(inv_pivot, Modp.myNormalize(myM(ReducedRows,j)));
//    for (j=i; j < ncols; j++) M[trows][j] = FFmul(M[trows][j]%p, invMii);
//    for (j=0; j < r; j++) rhs[trows][j] = FFmul(rhs[trows][j]%p, invMii);

    // Now zero the whole column (except the pivot, of course!)
    for (int j=0; j < myNrows; j++)
    {
      if (j == ReducedRows) continue;
      SmallFpImpl::value Mji = Modp.myNormalize(myM(j,i));
      if (IsZero(Mji)) continue;
      Mji = Modp.myNegate(Mji);
      for (int k=i+1; k < AllCols; ++k)
        myM(j,k) += Mji*myM(ReducedRows,k);
      // for (int k=0; k < r; k++) rhs[j][k] += Mji*rhs[trows][k];
      // for (k=i+1; k < ncols; k++) M[j][k] += Mji*M[trows][k];
      myM(j,i) = zero(SmallFp);
    }
    ++ReducedRows;
    if (++count < TimeToReduce) continue;
    count = 0;
    for (int j=0; j < myNrows; ++j)
    {
      for (int k=i+1; k < AllCols; ++k)
        myM(j,k) = Modp.myHalfNormalize(myM(j,k));
      // for (k=0; k < r; k++)
      //   if (rhs[j][k] >= shift) rhs[j][k] -= shift;
      // for (k=i+1; k < ncols; k++)
      //   if (M[j][k] >= shift) M[j][k] -= shift;
    }
  }

  for (int j=0; j < myRHScols; ++j)
  {
    /* If any coord beyond ReducedRows is non-zero, no solution exists. */
    for (int i=ReducedRows; i < myNrows; ++i)
    {
      myM(i, j+myNcols) = Modp.myNormalize(myM(i,j));
      if (!IsZero(Modp.myNormalize(myM(i,j)))) { mySolnIsValid[j] = false; break; }
    }
    // There is a soln, so put it into mySoln:
    int k = ReducedRows-1;
    for (int i=myNcols-1; i >= 0; --i)
    {
      if (k >= 0 && i == myPivotRow[k])
      { mySoln(i,j) = Modp.myNormalize(myM(k, j + myNcols)); --k; }
//default value!!      else mySoln(i,j) = 0;
    }
  }

}


  matrix LinSolveFp(ConstMatrixView M, ConstMatrixView rhs)
  {
    ring Fp = RingOf(M);
    // assume RingOf(rhs) == Fp
//    const int p = ConvertTo<long>(characteristic(Fp));
//    SmallFpImpl Modp(p);
    const SmallFpImpl& ModP = ModularArith(Fp);

    const long rows = NumRows(M);
    const long cols = NumCols(M);
    const long rhs_cols  = NumCols(rhs);
    MatrixFp Mcopy(ModP, rows, cols);
    MatrixFp RHScopy(ModP, rows, rhs_cols);
    for (int i=0; i < rows; ++i)
      for (int j=0; j < cols; ++j)
        Mcopy(i,j) = ModP.myReduce(ConvertTo<long>(M(i,j)));
    for (int i=0; i < rows; ++i)
      for (int j=0; j < rhs_cols; ++j)
        RHScopy(i,j) = ModP.myReduce(ConvertTo<long>(rhs(i,j)));
    LinSolver LS(/*Modp,*/ Mcopy, RHScopy);
    const MatrixFp& Msoln = soln(LS);
    matrix ans = NewDenseMat(Fp, rows, rhs_cols);
    for (int i=0; i < rows; ++i)
      for (int j=0; j < rhs_cols; ++j)
        SetEntry(ans,i,j,  ModP.myExportNonNeg(Msoln(i,j)));
    return ans;
  }
  

  matrix LinKerFp(ConstMatrixView M_orig)
  {
    ring Fp = RingOf(M_orig);
    // assume RingOf(rhs) == Fp
//    const int p = ConvertTo<long>(characteristic(Fp));
    const SmallFpImpl& ModP = ModularArith(Fp);
//    SmallFpImpl Modp(p);

    const long nrows = NumRows(M_orig);
    const long ncols = NumCols(M_orig);
    MatrixFpNonRed M(nrows, ncols);
    for (int i=0; i < nrows; ++i)
      for (int j=0; j < ncols; ++j)
        M(i,j) = ModP.myReduce(ConvertTo<long>(M_orig(i,j)));

    vector<bool> c(nrows); // initially all false
    vector<int> d(ncols);  // initially all zero
    vector<SmallFpImpl::value> ThisRow(ncols);

    int KerDim = 0;
    int IterCount = 0;

    for (int k=0; k < ncols; ++k)
    {
      for (int j=0; j < nrows; ++j)
      {
        ThisRow[j] = ModP.myNormalize(M(j,k));
        M(j,k) = ThisRow[j];
      }

      int j;
      for (j=0; j < nrows; ++j)
        if (!c[j] && !IsZero(ThisRow[j])) break;

      if (j == nrows) { ++KerDim; d[k] = -1; continue; }
      // Mj = M+(ncols*j);
      const SmallFpImpl::value q = ModP.myNegate(ModP.myRecip(ThisRow[j])); // surely non-zero
      for (int i=k+1; i < ncols; i++)
        M(j,i) = ModP.myMul(q, ModP.myNormalize(M(j,i)));

      for (int i=0; i < nrows; i++)
      {
        if (i == j) continue;
        //Mi = M+(i*ncols);
        const SmallFpImpl::value Mik = ModP.myNormalize(M(i,k));
        if (IsZero(Mik)) continue;
        M(i,k) = zero(SmallFp);
        for (int s=k+1; s < ncols; s++)
          M(i,s) += Mik*M(j,s);
      /* for (s=k+1; s < ncols; s++) Mi[s] += Mik*Mj[s]; */
      // {
      //   FFelem *Mis = &Mi[k+1],
      //          *Mjs = &Mj[k+1],
      //          *last = &Mi[ncols-1];
      //   while (Mis <= last) *(Mis++) += Mik * *(Mjs++);
      // }
      }
      c[j] = true;
      d[k] = j;
      if (++IterCount < ModP.myMaxIters()) continue;
      IterCount = 0;
      for (int i=0; i < nrows; i++)
      {
//        Mi = M+(i*ncols);
        for (int j=k+1; j < ncols; j++)
          M(i,j) = ModP.myHalfNormalize(M(i,j));
//        if (Mi[j] >= shift) Mi[j] -= shift;
      }
  }


//    MatrixFp ans(KerDim, ncols);
    matrix ans = NewDenseMat(Fp, KerDim, ncols);
//  ans = (FFelem*)MALLOC(KerDim*ncols*sizeof(FFelem));
  int s = 0;
//  x = ans;
  for (int k=0; k < ncols; ++k)
  {
    if (d[k] != -1) continue;
    for (int i=0; i < ncols; ++i)
    {
      if (d[i] == -1) SetEntry(ans,s,i, (i == k));//ans(k,i) = ModP.myReduce(i == k);
      else SetEntry(ans,s,i, ModP.myExport(ModP.myNormalize(M(d[i],k))));// ans(k,i) = ModP.myNormalize(M(d[i],k));
    }
//    x += ncols;
    ++s;
  }
//  FREE(c);
//  FREE(d);

//  *B = ans;
  return ans;
    
  }

//   class LinDepFp
//   {
//   public:
//     LinDepFp(const SmallFpImpl& ModP, long dim);
//     bool myAppendVec(std::vector<SmallFpImpl::value>& v);
// //    bool IsLinDep() const { return };
//     const std::vector<SmallFpImpl::value>& myLinReln() { CoCoA_ASSERT(); return myLinRelnVec;}

//   private:
//     const SmallFpImpl& myArith;
//     long myDim;
//     int myNumVecs;
//     std::vector< std::vector<SmallFpImpl::value> > myM;
//     std::vector<SmallFpImpl::NonRedValue> myRow;
// //    std::vector<std::vector<RingElem> > myRowRepr;
//     std::vector<int> myColIndices;
//     std::vector<SmallFpImpl::value> myLinRelnVec;

//   };

  LinDepFp::LinDepFp(const SmallFpImpl& ModP, long dim):
      myArith(ModP),
      myDim(dim),
      myNumVecs(0),
      myColIndices(dim,-1)
    {
//      if (!IsField(K)) CoCoA_THROW_ERROR(ERR::NotField, "LinDepMill ctor");
      if (dim <= 0) CoCoA_THROW_ERROR(ERR::NotPositive, "LinDepFp ctor");
      myM.reserve(dim);
      myRow.reserve(2*dim);
      myLinRelnVec.reserve(dim);
    }

  bool LinDepFp::myAppendVec(std::vector<SmallFpImpl::value>& v)
  {
    myLinRelnVec.clear(); // empty unless we find a lin reln
//    VerboseLog VERBOSE("LinDepFp::myAppendVec");
//    VERBOSE(10) << "Recvd vec " << v << endl;
    CoCoA_ASSERT(len(v) == myDim);
    for (int i=0; i < myDim; ++i)
    {
      myRow[i] = v[i];
      myRow[i+myDim] = (i == myNumVecs)?one(SmallFp):zero(SmallFp);
    }

    int rightmost = 0;
    const long p = myArith.myModulus();
    const long SizeLimit = std::numeric_limits<SmallFpImpl::repr_t>::max()/p; // integer division
    const long HalfWay_up = (1+SizeLimit)/2; // integer division!
    long SizeEst = 1;  // values in myRow are less than p*SizeEst
    for (int c=0; c < myDim; ++c)
    {
      const SmallFpImpl::value entry = myArith.myNormalize(myRow[c]);
      if (IsZero(entry)) { myRow[c] = entry; continue; }
      if (myColIndices[c] < 0)
      {
        // We have a new reducer (and surely no lin dep)
        vector<SmallFpImpl::value> NewRow(2*myDim);
        const SmallFpImpl::value inv = myArith.myRecip(entry);
        NewRow[c] = one(SmallFp);
        const int END = myNumVecs+myDim;
        for (int j=c+1; j <= END; ++j)
          NewRow[j] = myArith.myMul(inv, myArith.myNormalize(myRow[j]));
//        VERBOSE(10) << "New reducer for col " << c << "  is " << NewRow << endl;
        myM.push_back(NewRow);
        myColIndices[c] = myNumVecs;
        ++myNumVecs;
        return false; // no lin dep
      }

      myRow[c] = zero(SmallFp);
      const int reducer = myColIndices[c];
      if (reducer > rightmost) rightmost = reducer;
//      VERBOSE(10) << "Row redn for col " << c << "  by vec " << reducer << " " << myM[reducer] << endl;
      const SmallFpImpl::value scale = myArith.myNegate(entry);

      SizeEst += myArith.myExportNonNeg(scale);
      if (SizeEst > SizeLimit)
      {
        // Overflow is possible, so to avoid it we half-reduce entries in myRow
        const int END2 = rightmost + myDim;
        for (int j=c+1; j < END2; ++j)
          myRow[j] = myArith.myHalfNormalize(myRow[j]);

        SizeEst = HalfWay_up + myArith.myExportNonNeg(scale);
      }

      const vector<SmallFpImpl::value>& RedRow = myM[reducer];
      const int END = reducer+myDim; // all later coords are zero
      for (int j=c+1; j <= END; ++j)
        myRow[j] += scale*RedRow[j];

    }
    // We have a lin dep; copy it into myLinRelnVec
    myLinRelnVec.resize(1+myNumVecs);
    myLinRelnVec[myNumVecs] = one(SmallFp);
    for (int j=0; j < myNumVecs; ++j)
      myLinRelnVec[j] = myArith.myNormalize(myRow[j+myDim]);
    
    return true;
  }


int SignatureOfPerm(const vector<int>& perm)
{
  const int n = len(perm);
  vector<bool> visited(n); // initially false
  int sign = 1;
  for (int i=0; i < n; ++i)
  {
    if (visited[i]) continue;
    int CycleLen = 0;
    int curr = i;
    while (!visited[curr])
    {
      visited[curr] = true;
      curr = perm[curr];
      ++CycleLen;
    }
    if ((CycleLen&1) == 0) sign = -sign;
  }
  return sign;
}


  long/*SmallFpImpl::value*/ det(MatrixFp& M)
{
  const SmallFpImpl& ModP = ModPArith(M);
    const long p = ModP.myModulus();
    const long SizeLimit = std::numeric_limits<SmallFpImpl::repr_t>::max()/p; // integer division
    const long HalfWay_up = (1+SizeLimit)/2; // integer division!
    long SizeEst = 1;  // values in myRow are less than p*SizeEst
    const int n = NumRows(M);
    vector<int> ReducerIndex(n,-1); // -1 means no reducer
    vector<SmallFpImpl::NonRedValue> CurrRow(n);
    SmallFpImpl::value DiagProd = one(SmallFp);
    for (int row=0; row < n; ++row)
    {
      //CurrRow = M[row];
      for (int col=0; col < n; ++col)
        CurrRow[col] = M(row,col);
      bool HaveNewReducerRow = false;
      for (int col=0; col < n; ++col)
      {
        const SmallFpImpl::value entry = ModP.myNormalize(CurrRow[col]);
        if (IsZero(entry)) { CurrRow[col] = entry; continue; }
        const int reducer = ReducerIndex[col];
        if (reducer >= 0)
        {
        CurrRow[col] = zero(SmallFp);
//      VERBOSE(10) << "Row redn for col " << c << "  by vec " << reducer << " " << myM[reducer] << endl;
        const SmallFpImpl::value scale = ModP.myNegate(entry);

        SizeEst += ModP.myExportNonNeg(scale);
        // if (SizeEst <= SizeLimit)
        // {
        // const vector<SmallFpImpl::value>& RedRow = M[reducer];
        // for (int j=col+1; j < n; ++j)
        //   CurrRow[j] += scale*RedRow[j];
        // // SmallFpImpl::NonRedValue* Rj = &CurrRow[col+1];
        // // SmallFpImpl::NonRedValue* END = &CurrRow[n];
        // // SmallFpImpl::value* mij = &M[reducer][col+1];
        // // while (Rj != END)
        // //   *Rj++ = scale * *mij++;
        // continue;
        // }
        if (SizeEst > SizeLimit)
        {
          // Overflow is possible, so to avoid it we half-reduce entries in myRow
          for (int j=col+1; j < n; ++j)
            CurrRow[j] = ModP.myHalfNormalize(CurrRow[j]);

          SizeEst = HalfWay_up + ModP.myExportNonNeg(scale);
        }

        const vector<SmallFpImpl::value>& RedRow = M[reducer];
        for (int j=col+1; j < n; ++j)
          CurrRow[j] += scale*RedRow[j];
        continue;
        }
        if (ReducerIndex[col] < 0)
        {
          // We have a new reducer
          HaveNewReducerRow = true;
          const SmallFpImpl::value inv = ModP.myRecip(entry);
          DiagProd = ModP.myMul(DiagProd, entry);
//          vector<SmallFpImpl::value>& Mrow = M[row];
          for (int j=0; j < col; ++j)
            M(row,j)/*Mrow[j]*/ = zero(SmallFp);
          M(row,col)/*Mrow[col]*/ = one(SmallFp);
          for (int j=col+1; j < n; ++j)
            M(row,j)/*Mrow[j]*/ = ModP.myMul(inv, ModP.myNormalize(CurrRow[j]));
//        VERBOSE(10) << "New reducer for col " << c << "  is " << NewRow << endl;
          ReducerIndex[col] = row;
          break;
        }


      }
      if (!HaveNewReducerRow) return 0; //zero(SmallFp);
    }
    if (SignatureOfPerm(ReducerIndex) == 1)
      return ModP.myExportNonNeg(DiagProd);
    return ModP.myModulus() - ModP.myExportNonNeg(DiagProd);
}


  RowRednFp::RowRednFp(const SmallFpImpl& ModP, long dim):
      myArith(ModP),
      myDim(dim),
      myNumVecs(0),
      myDiagProd(one(SmallFp)),
      myColIndices(dim,-1)
    {
//      if (!IsField(K)) CoCoA_THROW_ERROR(ERR::NotField, "LinDepMill ctor");
      if (dim <= 0) CoCoA_THROW_ERROR(ERR::NotPositive, "RowRednFp ctor");
      myM.reserve(dim);
      myRow.reserve(2*dim);
//      myLinRelnVec.reserve(dim);
    }

  void RowRednFp::myAppendVec(std::vector<SmallFpImpl::value>& v)
  {
//    myLinRelnVec.clear(); // empty unless we find a lin reln
//    VerboseLog VERBOSE("RowRednFp::myAppendVec");
//    VERBOSE(10) << "Recvd vec " << v << endl;
    CoCoA_ASSERT(len(v) == myDim);
    for (int i=0; i < myDim; ++i)
    {
      myRow[i] = v[i];
//      myRow[i+myDim] = (i == myNumVecs)?one(SmallFp):zero(SmallFp);
    }

//    int rightmost = 0;
    const long p = myArith.myModulus();
    const long SizeLimit = std::numeric_limits<SmallFpImpl::repr_t>::max()/p; // integer division
    const long HalfWay_up = (1+SizeLimit)/2; // integer division!
    long SizeEst = 1;  // values in myRow are less than p*SizeEst
    for (int c=0; c < myDim; ++c)
    {
      const SmallFpImpl::value entry = myArith.myNormalize(myRow[c]);
      if (IsZero(entry)) { myRow[c] = entry; continue; }
      if (myColIndices[c] < 0)
      {
        // We have a new reducer
        vector<SmallFpImpl::value> NewRow(myDim);
        const SmallFpImpl::value inv = myArith.myRecip(entry);
        myDiagProd = myArith.myMul(myDiagProd, entry);
        NewRow[c] = one(SmallFp);
//        const int END = myNumVecs+myDim;
        for (int j=c+1; j < myDim; ++j)
          NewRow[j] = myArith.myMul(inv, myArith.myNormalize(myRow[j]));
//        VERBOSE(10) << "New reducer for col " << c << "  is " << NewRow << endl;
        myM.push_back(NewRow);
        myColIndices[c] = myNumVecs;
        ++myNumVecs;
        return;
      }

      myRow[c] = zero(SmallFp);
      const int reducer = myColIndices[c];
//      if (reducer > rightmost) rightmost = reducer;
//      VERBOSE(10) << "Row redn for col " << c << "  by vec " << reducer << " " << myM[reducer] << endl;
      const SmallFpImpl::value scale = myArith.myNegate(entry);

      SizeEst += myArith.myExportNonNeg(scale);
      if (SizeEst > SizeLimit)
      {
        // Overflow is possible, so to avoid it we half-reduce entries in myRow
//        const int END2 = rightmost + myDim;
        for (int j=c+1; j < myDim; ++j)
          myRow[j] = myArith.myHalfNormalize(myRow[j]);

        SizeEst = HalfWay_up + myArith.myExportNonNeg(scale);
      }

      const vector<SmallFpImpl::value>& RedRow = myM[reducer];
//      const int END = reducer+myDim; // all later coords are zero

      for (int j=c+1; j < myDim; ++j)
        myRow[j] += scale*RedRow[j];

      // SmallFpImpl::NonRedValue* dest = &myRow[c+1];
      // const SmallFpImpl::value* reduce = &RedRow[c+1];
      // SmallFpImpl::NonRedValue* const END = &myRow[myDim+1];
      // while (dest != END)
      //   *dest++ += scale * *reduce++;

    }
    // // We have a lin dep; copy it into myLinRelnVec
    // myLinRelnVec.resize(1+myNumVecs);
    // myLinRelnVec[myNumVecs] = one(SmallFp);
    // for (int j=0; j < myNumVecs; ++j)
    //   myLinRelnVec[j] = myArith.myNormalize(myRow[j+myDim]);
    
    return;
  }

long RowRednFp::myRank() const
{
  return myNumVecs;
}

SmallFpImpl::value RowRednFp::myDet() const
{
  CoCoA_ASSERT(myNumVecs == myDim); // BUG, should count number of calls!!!
  if (myNumVecs < myDim) return zero(SmallFp);
  if (SignatureOfPerm(myColIndices) == 1)
  return myDiagProd; // sign???
  else
    return myArith.myNegate(myDiagProd);
}

} // end of namespace CoCoA
