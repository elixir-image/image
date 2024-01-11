#!/opt/homebrew/bin/python3

import sys
import time
import pyvips

if len(sys.argv) != 3:
    print("usage: {sys.argv[0]) WIDTH HEIGHT")
    sys.exit(1)

width = int(sys.argv[1])
height = int(sys.argv[2])
shift = 1
subsample = 1 << shift
ycc2rgb = [
    [1.0,  0.0,       1.402   ],
    [1.0, -0.344136, -0.714136],
    [1.0,  1.772,     0.0     ],
]

Y = pyvips.Image.black(width, height).copy_memory()
Cb = pyvips.Image.black(width >> shift, height >> shift).copy_memory()
Cr = pyvips.Image.black(width >> shift, height >> shift).copy_memory()


# use linear inerp, plus multi-valued linear
def try2(Y, Cb, Cr):
    Cb = Cb.resize(subsample, kernel="linear")
    Cr = Cr.resize(subsample, kernel="linear")
    YCbCr = Y.bandjoin([Cb, Cr]) - [16, 128, 128]
    return YCbCr.recomb(ycc2rgb).copy(interpretation="srgb")

def try3(Y, Cb, Cr):
    Cb = Cb.resize(subsample, kernel="linear")
    Cr = Cr.resize(subsample, kernel="linear")
    YCbCr = Y.bandjoin([Cb, Cr]) - [16, 128, 128]
    Rgb = YCbCr.recomb(ycc2rgb).copy(interpretation="srgb")
    return Rgb.write_to_binary()

def bench(msg, fn, Y, Cb, Cr):
    start = time.time()
    result = fn(Y, Cb, Cr).copy_memory()
    end = time.time()
    print(f"{msg}: {1000 * (end - start):.1f}ms")

bench("linear", try2, Y, Cb, Cr)
bench("plus write_to_binary", try2, Y, Cb, Cr)

