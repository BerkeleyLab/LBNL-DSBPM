#
# Produce local oscillator lookup tables
#
import math
import argparse

parser = argparse.ArgumentParser(description='Create local oscillator lookup tables.', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-i', '--integerOutput', action='store_true', help='Show values as integers, not scaled back to [-1,1].')
parser.add_argument('-s', '--demodScaleFactor', default=0x1FFFF, type=int, help='Double to Integer scale factor for Demodulation tables (full scale value).')
args = parser.parse_args()

def quantize(x, scaleFactor, integerOutput = False):
    if (x < 0): return -quantize(-x, scaleFactor)
    xi = math.floor((x * scaleFactor) + 0.5)
    if (not integerOutput): xi /= scaleFactor
    return xi

def rfTable(name, Frf, refDivider, refMultiplier, sampleCount, scaleFactor,
            Feff = None, conjugate = False):
    Frf = float(Frf)
    Fadc = Frf / refDivider * refMultiplier
    if (not Feff): Feff = Frf - math.floor(Frf / Fadc) * Fadc
    if (Feff > Fadc / 2): Feff = Fadc - Feff
    fftIndex = Feff / (Fadc / sampleCount)
    print("RF table: %s" % (name))
    print("    Frf:%.3f  Fadc:%.3f  Feff:%.3f  FFT index:%d" % (Frf, Fadc, Feff, fftIndex))
    with open(name, 'w') as f:
        w = 2 * math.pi * Feff
        Tsamp = 1.0 / Fadc
        for i in range(sampleCount):
            s = quantize(math.sin(w*Tsamp*i), scaleFactor)
            if conjugate: s = -s
            c = quantize(math.cos(w*Tsamp*i), scaleFactor)
            f.write("%9.6f,%9.6f\n" % (c, s))

def ptTableGen(name, FoffsetL, FoffsetH, Frf, refDivider, refMultiplier, sampleCount,
               scaleFactor, Feff = None, conjugate = False):
    Frf = float(Frf)
    Fadc = Frf / refDivider * refMultiplier
    if (not Feff): Feff = Frf - math.floor(Frf / Fadc) * Fadc
    if (Feff > Fadc / 2): Feff = Fadc - Feff
    Flo = Feff - FoffsetL
    Fhi = Feff + FoffsetH
    print("PT table: %s" % (name))
    print("    Frf:%.3f  Fadc:%.3f  Flo:%.3f  Fhi:%.3f" % (Frf, Fadc, Flo, Fhi))
    with open(name, 'w') as f:
        wl = 2 * math.pi * Flo
        wh = 2 * math.pi * Fhi
        Tsamp = 1.0 / Fadc
        for i in range(sampleCount):
            sl = quantize(math.sin(wl*Tsamp*i), scaleFactor)
            if conjugate: sl = -sl
            cl = quantize(math.cos(wl*Tsamp*i), scaleFactor)
            sh = quantize(math.sin(wh*Tsamp*i), scaleFactor)
            if conjugate: sh = -sh
            ch = quantize(math.cos(wh*Tsamp*i), scaleFactor)
            f.write("%9.6f,%9.6f,%9.6f,%9.6f\n" % (cl, sl, ch, sh))

def ptTable(name, Foffset, Frf, refDivider, refMultiplier, sampleCount, scaleFactor, Feff = None, conjugate = False):
    ptTableGen(name, Foffset, Foffset, Frf, refDivider, refMultiplier, sampleCount, scaleFactor, Feff = None, conjugate = False)

rfTable('rfTableSR.csv', 500, 328,  77, 77,
        scaleFactor = args.demodScaleFactor)
rfTable('rfTableSR_81_328.csv', 499.64, 328,  81, 81,
        scaleFactor = args.demodScaleFactor)
rfTable('rfTableSR_81_328_bin_20.csv', 499.64, 328,  81, 81,
        scaleFactor = args.demodScaleFactor, Feff = 499.64/328*20)
rfTable('rfTableSR_81_328_bin_20_conjugate.csv', 499.64, 328,  81, 81,
        scaleFactor = args.demodScaleFactor, Feff = 499.64/328*20, conjugate = True)
rfTable('rfTableSR_80_333.csv', 499.50, 333,  80, 80,
        scaleFactor = args.demodScaleFactor)
rfTable('rfTableTL.csv', 500, 328,  77, 77,
        scaleFactor = args.demodScaleFactor)
rfTable('rfTableBR.csv', 500, 500, 116, 29,
        scaleFactor = args.demodScaleFactor)

ptTable('ptTableSR_1_2.csv', (500.0/328.0)*(1.0/2.0), 500, 328, 77, 77*2,
        scaleFactor = args.demodScaleFactor)
ptTable('ptTableSR_81_328_1_2.csv', (499.64/328.0)*(1.0/2.0), 499.64, 328, 81, 81*2,
        scaleFactor = args.demodScaleFactor)
ptTable('ptTableSR_80_333_1_2.csv', (499.50/333.0)*(1.0/2.0), 499.50, 333, 80, 80*2,
        scaleFactor = args.demodScaleFactor)
ptTable('ptTableSR_81_328_11_19.csv', (499.64/328.0)*(11.0/19.0), 499.64, 328, 81, 81*19,
        scaleFactor = args.demodScaleFactor)
ptTable('ptTableSR_81_328_11_19_bin_20.csv', (499.64/328.0)*(11.0/19.0), 499.64, 328, 81, 81*19,
        scaleFactor = args.demodScaleFactor, Feff = 499.64/328*20)
ptTable('ptTableSR_81_328_11_19_bin_20_conjugate.csv', (499.64/328.0)*(11.0/19.0), 499.64, 328, 81, 81*19,
        scaleFactor = args.demodScaleFactor, Feff = 499.64/328*20, conjugate = True)
ptTable('ptTableSR_81_328_30_19_bin_20_conjugate.csv', (499.64/328.0)*(30.0/19.0), 499.64, 328, 81, 81*19,
        scaleFactor = args.demodScaleFactor, Feff = 499.64/328*20, conjugate = True)

ptTableGen('ptTableSR_81_328_L26_19_H30_19_bin_20_conjugate.csv', (499.64/328.0)*(26.0/19.0),
           (499.64/328.0)*(30.0/19.0), 499.64, 328, 81, 81*19, scaleFactor = args.demodScaleFactor,
           Feff = 499.64/328*20, conjugate = True)

ptTable('ptTableSR_11_19.csv', (500.0/328.0)*(11.0/19.0), 500, 328, 77, 77*19,
        scaleFactor = args.demodScaleFactor)
ptTable('ptTableTL.csv', 0, 500, 328,  77,  77,
        scaleFactor = args.demodScaleFactor)
ptTable('ptTableBR_1_2.csv', (500.0/125.0)*(1.0/2.0), 500, 500, 116,  29*2,
        scaleFactor = args.demodScaleFactor)
