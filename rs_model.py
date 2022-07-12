#!/usr/bin/env python3

import warnings, argparse
import numpy as np

primitive_poly = "0b100011101"
K = 251
T = 2
N = 1
Nerr = T

parser = argparse.ArgumentParser(
    description="RS decoder design utility.\
    Generates GF inverse LUT in BSV file,\
    Produces test pattern files: string of encoded data with injected errors,\
    and golden reference output file",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter,
)
parser.add_argument(
    "-P",
    type=str,
    dest="primitive_poly",
    help="Primitive polynomial in binary string format",
    default=primitive_poly,
)
parser.add_argument(
    "-K", type=int, dest="K", help="Length of uncoded data", default=K,
)
parser.add_argument(
    "-T", type=int, dest="T", help="Length of parity data, K+2*T == 255", default=T,
)
parser.add_argument(
    "-N", type=int, dest="N", help="Number of packets, each in 255 bytes", default=N,
)
parser.add_argument(
    "-Nerr",
    type=int,
    dest="Nerr",
    help="Number of injected errors in each packet",
    default=Nerr,
)

parser.add_argument(
    "-bsv",
    nargs="?",
    type=str,
    default="RSParameters.bsv",
    help="name of BSV file to save generated parameters and GF inv function",
)


args = parser.parse_args()
primitive_poly = args.primitive_poly
K = args.K
T = args.T
N = args.N
Nerr = args.Nerr

nn = 255
mm = 8
kk = K
tt = T
pp = np.zeros(mm + 1, dtype=int)
alpha_to = np.zeros(nn + 1, dtype=int)
index_of = np.zeros(nn + 1, dtype=int)

gg = np.zeros(nn - kk + 1, dtype=int)

poly = int(primitive_poly, 2)
for i in range(0, mm + 1):
    pp[i] = poly & 1
    poly >>= 1

mask = 1
alpha_to[mm] = 0

for i in range(0, mm):
    alpha_to[i] = mask
    index_of[alpha_to[i]] = i
    if pp[i] != 0:
        alpha_to[mm] ^= mask
    mask <<= 1

index_of[alpha_to[mm]] = mm
mask >>= 1
for i in range(mm + 1, nn):
    if alpha_to[i - 1] >= mask:
        alpha_to[i] = alpha_to[mm] ^ ((alpha_to[i - 1] ^ mask) << 1)
    else:
        alpha_to[i] = alpha_to[i - 1] << 1
    index_of[alpha_to[i]] = i
index_of[0] = -1

gg[0] = 2  # primitive element alpha = 2  for GF(2**mm)
gg[1] = 1  # g(x) = (X+alpha) initially
for i in range(2, nn - kk + 1):
    gg[i] = 1
    for j in range(i - 1, 0, -1):
        if gg[j] != 0:
            gg[j] = gg[j - 1] ^ alpha_to[(index_of[gg[j]] + i) % nn]
        else:
            gg[j] = gg[j - 1]
    gg[0] = alpha_to[(index_of[gg[0]] + i) % nn]
# gg[0] can never be zero
# convert gg[] to index form for quicker encoding
gg = index_of[gg]

f = open(args.bsv, "w")
f.write(f"typedef {K} K;\ntypedef {T} T;\nBit#(8) primitive_poly = 8'b")
for i in range(mm - 1, -1, -1):
    f.write(f"{pp[i]}")

f.write(";\nfunction Bit#(8) gf_inv(Bit#(8) a);\n\tcase (a) matches\n")

gfinv_lut = np.zeros(nn + 1, dtype=int)
for i in range(0, nn + 1):
    gfinv_lut[i] = alpha_to[(nn - index_of[i]) % nn]
    f.write(f"\t{i} : return {gfinv_lut[i]};\n")

f.write("\tendcase\nendfunction\n")
f.close()


# /* take the string of symbols in data[i], i=0..(k-1) and encode systematically
#    to produce 2*tt parity symbols in bb[0]..bb[2*tt-1]
#    data[] is input and bb[] is output in polynomial form.
#    Encoding is done by using a feedback shift register with appropriate
#    connections specified by the elements of gg[], which was generated above.
#    Codeword is   c(X) = data(X)*X**(nn-kk)+ b(X)          */
def encode_rs(data):
    bb = np.zeros(nn - kk, dtype=int)
    for i in range(kk - 1, -1, -1):
        feedback = index_of[data[i] ^ bb[nn - kk - 1]]
        if feedback != -1:
            for j in range(nn - kk - 1, 0, -1):
                if gg[j] != -1:
                    bb[j] = bb[j - 1] ^ alpha_to[(gg[j] + feedback) % nn]
                else:
                    bb[j] = bb[j - 1]

            bb[0] = alpha_to[(gg[0] + feedback) % nn]
        else:
            for j in range(nn - kk - 1, 0, -1):
                bb[j] = bb[j - 1]
            bb[0] = 0

    return bb


if N > 0:
    f_input = open("input.dat", "w")
    f_refout = open("ref_output.dat", "w")
    for p in range(0, N):
        # data = np.linspace(start=0, stop=255, num=kk, dtype=int)
        # data = np.linspace(start=0, stop=kk - 1, num=kk, dtype=int)
        # data = np.linspace(start=kk, stop=1, num=kk, dtype=int)
        data = np.random.randint(0, 255, kk)
        pb = encode_rs(data[::-1])[::-1]
        broken_data = np.concatenate((data, pb))
        broken_data[np.random.randint(0, 255, Nerr)] = np.random.randint(0, 255, Nerr)

        f_input.write(f"{nn} {T}\n")
        f_refout.write(f"{nn} {T}\n")

        for d in range(0, 255):
            f_input.write(f"{broken_data[d]}\n")
            if d < kk:
                f_refout.write(f"{data[d]}\n")

    f_refout.close()
    f_input.close()
