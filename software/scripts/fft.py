import numpy as np
import pylab as py
import math
import argparse
import os

script_dir = os.path.dirname(__file__)

parser = argparse.ArgumentParser(description='Calculate FFT from a complex signal',
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-f', '--file', help='.csv file with complex signal', required=True)
parser.add_argument('-a', '--harm-number', help='Harmonic number', type=int,
                    default=328)
parser.add_argument('-N', '--samples-per-turn', help='Samples per turn', type=int,
                    default=81)
parser.add_argument('-n', '--num-turns', help='Number of turns', type=int,
                    default=19)
parser.add_argument('-r', '--rf', help='RF frequency [MHz]', type=float,
                    default=499.64)
args = parser.parse_args()

h = args.harm_number
n = args.num_turns
N = args.samples_per_turn
rf = args.rf

num_samples = N * n
npts = math.floor(num_samples/N) * N

data_i = np.genfromtxt(args.file, delimiter = ',')[:,0][:npts]
data_q = np.genfromtxt(args.file, delimiter = ',')[:,1][:npts]
data = data_i + 1j*data_q

py.figure()
py.plot(data_i)
py.plot(data_q)
legend = ["I", "Q"]
py.legend (legend)
py.title("I/Q data")
py.xlabel("Samples")
py.ylabel("ADC counts")
py.grid()
py.draw()

# FFT
Fs = rf*N/h
nsamples = len(data)
k = np.arange(nsamples)
T = nsamples/Fs
frq = k/T
frq = frq[range(int(nsamples))]

Y = np.fft.fft(data)/nsamples
Y = Y[range(int(nsamples))]

py.figure()
py.semilogy(frq, abs(Y))
legend = ["FFT data"]
py.legend(legend)
py.title("FFT Data")
py.xlabel("Freq (MHz):"+ str(nsamples) + " points")
py.ylabel("log10 |Y(freq)|")
py.grid()
py.draw()

py.show()
