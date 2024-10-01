#
# Produce local oscillator lookup tables
#
import math
import argparse
import numpy as np
import pylab as py

parser = argparse.ArgumentParser(description='Create local oscillator lookup tables.', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-i', '--integerOutput', action='store_true', help='Show values as integers, not scaled back to [-1,1].')
parser.add_argument('-s', '--demodScaleFactor', default=0x1FFFF, type=int, help='Double to Integer scale factor for Demodulation tables (full scale value).')
parser.add_argument('-t', '--ptScaleFactor', default=0x7FFF, type=int, help='Double to Integer scale factor for Pilot Tone tables (full scale value).')
args = parser.parse_args()

def quantize(x, scaleFactor, integerOutput = False):
    if (x < 0): return -quantize(-x, scaleFactor)
    xi = math.floor((x * scaleFactor) + 0.5)
    if (not integerOutput): xi /= scaleFactor
    return xi

def rfTable(Frf, refDivider, refMultiplier, sampleCount, scaleFactor,
            Feff = None, conjugate = False):
    Frf = float(Frf)
    Fadc = Frf / refDivider * refMultiplier
    if (Feff is None): Feff = Frf - math.floor(Frf / Fadc) * Fadc
    if (Feff > Fadc / 2): Feff = Fadc - Feff
    fftIndex = Feff / (Fadc / sampleCount)
    print("Frf:%.3f  Fadc:%.3f  Feff:%.3f  FFT index:%d" % (Frf, Fadc, Feff, fftIndex))

    w = 2 * math.pi * Feff
    Tsamp = 1.0 / Fadc
    sl = []
    cl = []
    for i in range(sampleCount):
        s = quantize(math.sin(w*Tsamp*i), scaleFactor)
        if conjugate: s = -s
        c = quantize(math.cos(w*Tsamp*i), scaleFactor)
        cl.append(c)
        sl.append(s)

    return py.transpose(np.array([cl, sl]))

def ptDemodTableGen(FoffsetL, FoffsetH, Frf, refDivider, refMultiplier, sampleCount,
               scaleFactor, Feff = None, conjugate = False):
    Frf = float(Frf)
    Fadc = Frf / refDivider * refMultiplier
    if (Feff is None): Feff = Frf - math.floor(Frf / Fadc) * Fadc
    if (Feff > Fadc / 2): Feff = Fadc - Feff
    Flo = Feff - FoffsetL
    Fhi = Feff + FoffsetH
    print("Frf:%.3f  Fadc:%.3f  Flo:%.3f  Fhi:%.3f" % (Frf, Fadc, Flo, Fhi))

    wl = 2 * math.pi * Flo
    wh = 2 * math.pi * Fhi
    Tsamp = 1.0 / Fadc
    sll = []
    slh = []
    cll = []
    clh = []
    for i in range(sampleCount):
        sl = quantize(math.sin(wl*Tsamp*i), scaleFactor)
        if conjugate: sl = -sl
        cl = quantize(math.cos(wl*Tsamp*i), scaleFactor)
        sh = quantize(math.sin(wh*Tsamp*i), scaleFactor)
        if conjugate: sh = -sh
        ch = quantize(math.cos(wh*Tsamp*i), scaleFactor)
        sll.append(sl)
        slh.append(sh)
        cll.append(cl)
        clh.append(ch)

    return py.transpose(np.array([cll, sll, clh, slh]))

def ptDemodTable(Foffset, Frf, refDivider, refMultiplier,
                 sampleCount, scaleFactor, Feff = None,
                 conjugate = False):
    return ptDemodTableGen(Foffset, Foffset, Frf, refDivider,
                           refMultiplier, sampleCount, scaleFactor, Feff,
                           conjugate)

def ptGenTable(FoffsetL, FoffsetH, Frf, refDivider,
               refMultiplier, sampleCount, scaleFactor, Feff = None,
               conjugate = False):
    table = ptDemodTableGen(FoffsetL, FoffsetH, Frf, refDivider,
                            refMultiplier, sampleCount, scaleFactor, Feff,
                            conjugate)
    cll = table[:,0]
    sll = table[:,1]
    clh = table[:,2]
    slh = table[:,3]
    cl = (cll + clh)/2*32767
    sl = (sll + slh)/2*32767
    return py.transpose(np.array([cl, sl]))

def writeTable(name, array, fmt = "%9.6f"):
    py.savetxt(name, array, delimiter = ',', fmt = fmt)

###############################################################################
# RF tables
###############################################################################
writeTable('rfTableSR_81_328_bin_20_conjugate.csv',
          rfTable(499.64, 328, 81, 81,
                  scaleFactor = args.demodScaleFactor,
                  Feff = 499.64/328*20, conjugate = True))
writeTable('rfTableSR_77_328_bin_20_conjugate.csv',
          rfTable(499.64, 328, 77, 77,
                  scaleFactor = args.demodScaleFactor,
                  Feff = 499.64/328*20, conjugate = True))

###############################################################################
# Pilot Tone demodulation tables
###############################################################################
writeTable('ptTableSR_81_328_11_19_bin_20_conjugate.csv',
           ptDemodTable((499.64/328.0)*(11.0/19.0), 499.64, 328, 81, 81*19,
                        scaleFactor = args.demodScaleFactor,
                        Feff = 499.64/328*20, conjugate = True))
writeTable('ptTableSR_81_328_30_19_bin_20_conjugate.csv',
           ptDemodTable((499.64/328.0)*(30.0/19.0), 499.64, 328, 81, 81*19,
                        scaleFactor = args.demodScaleFactor, Feff = 499.64/328*20, conjugate = True))
writeTable('ptTableSR_81_328_L7_19_H11_19_bin_20_conjugate.csv',
           ptDemodTableGen((499.64/328.0)*(7.0/19.0), (499.64/328.0)*(11.0/19.0),
                           499.64, 328, 81, 81*19, scaleFactor = args.demodScaleFactor,
                           Feff = 499.64/328*20, conjugate = True))

###############################################################################
# Pilot Tone generation tables
###############################################################################
writeTable('ptGen_81_7_low_11_high_19.csv',
           ptGenTable((499.64/328.0)*(1+7.0/19.0), (499.64/328.0)*(1+11.0/19.0),
                           499.64, 328, 81, 81*19, scaleFactor = args.ptScaleFactor,
                           Feff = 0, conjugate = False),
          fmt = '%d')
writeTable('ptGen_77_7_low_11_high_19.csv',
           ptGenTable((499.64/328.0)*(1+7.0/19.0), (499.64/328.0)*(1+11.0/19.0),
                           499.64, 328, 77, 77*19, scaleFactor = args.ptScaleFactor,
                           Feff = 0, conjugate = False),
          fmt = '%d')
