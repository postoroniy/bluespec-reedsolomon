//----------------------------------------------------------------------//
// The MIT License
//
// Copyright (c) 2008 Abhinav Agarwal, Alfred Man Cheuk Ng
// Contact: abhiag@gmail.com
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

//**********************************************************************
// Galois field arithmetic
//----------------------------------------------------------------------
// $Id: GFArith.bsv
//

import Vector::*;
import GFTypes::*;
import RSParameters::*;

// -----------------------------------------------------------
//(* noinline *)
function Byte gf_mult(Byte left, Byte right);

   Bit#(15) first  = 15'b0;
   Bit#(15) result = 15'b0;

   // this function bring back higher degree values back to the field
   function Bit#(15) getNewResult(Integer shift, Bit#(15) res);
      Bit#(15) shiftPoly = zeroExtend(primitive_poly) << shift;
      Bit#(15) newRes    = res ^ ((res[8+shift] == 1'b1) ? shiftPoly : 0);
      return newRes;
   endfunction

  for (Integer i = 0; i < 8; i = i + 1)
     for (Integer j = 0; j < 8 ; j = j + 1)
        begin
           if (first[i+j] == 0) // initialize result[i+j]
              result[i+j] = (left[i] & right[j]);
           else                 // accumulate
              result[i+j] = result[i+j] ^ (left[i] & right[j]);
           first[i+j] = 1; // only initialize each signal once
        end

  Vector#(7,Integer) shftAmntV = genVector;
  Bit#(15) finalResult = foldr(getNewResult,result,shftAmntV);

  return finalResult[7:0];

endfunction

(* noinline *)
function Byte gf_mult_inst(Byte x, Byte y);
   return gf_mult(x,y);
endfunction

// -----------------------------------------------------------
function Byte gf_add(Byte left, Byte right);
   return (left ^ right);
endfunction

(* noinline *)
function Byte gf_add_inst(Byte x, Byte y);
   return gf_add(x,y);
endfunction


// -----------------------------------------------------------
//(* noinline *)
function Byte alpha_n(Byte n);
	return times_alpha_n(1,n);
endfunction

// -----------------------------------------------------------
//(* noinline *)
function Byte times_alpha_n(Byte a, Byte n);
//    Byte multVal = 1 << n;
//    return gf_mult(primitive_poly,a,multVal);

   Byte b=a;
   for (Byte i = 0; i < n; i = i + 1)
      b=times_alpha(b);
   return b;
endfunction

// -----------------------------------------------------------
//(* noinline *)
function Byte times_alpha(Byte a);
//   return gf_mult(primitive_poly, a, 2);
   return (a<<1)^({a[7],a[7],a[7],a[7],a[7],a[7],a[7],a[7]} & primitive_poly);
endfunction
