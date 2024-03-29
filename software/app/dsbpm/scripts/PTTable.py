import numpy as np
import pylab as py

def DFTGenCoeff(K=20,N=77, phase = 0):
# K = DFT Freq bin, N = size of DFT
    n = np.arange(0,N,1)
    DFTCoeff = py.exp(1j*2.0*py.pi*(K/N*n - phase))
    return DFTCoeff

def ptTable_to_csv(FileName = None, DFTCoeffL = None, DFTCoeffH = None):
    DFTCoeff = (DFTCoeffL+DFTCoeffH)/2
    RealImag = py.transpose (py.array([py.real(DFTCoeff), py.imag(DFTCoeff)]))
    py.savetxt (FileName, RealImag*32767, delimiter = ',', fmt = "%d")

LO = 0
PTHCoeff = DFTGenCoeff(K=+(((LO+1)*19+11)),N=81*19)
PTLCoeff = DFTGenCoeff(K=-(((LO+1)*19+7)),N=81*19)

ptTable_to_csv(FileName = "ptGen.csv", DFTCoeffL=PTLCoeff, DFTCoeffH=PTHCoeff)
