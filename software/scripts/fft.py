import numpy as np
import pylab as py
import math

num_samples = 2**14
h = 81
npts = math.floor(num_samples/float(h)) * h

data_i = np.loadtxt("adc_data_0_i.txt")[:npts]
data_q = np.loadtxt("adc_data_0_q.txt")[:npts]

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
Fs = 499.64*81/328
n = len(data_i)
k = np.arange(n)
T = n/Fs
frq = k/T
frq = frq[range(int(n/2))]

Y_i = np.fft.fft(data_i)/n
Y_i = Y_i[range(int(n/2))]
Y_q = np.fft.fft(data_q)/n
Y_q = Y_q[range(int(n/2))]

py.figure()
py.semilogy(frq, abs(Y_i))
py.semilogy(frq, abs(Y_q))
legend = ["I", "Q"]
py.legend(legend)
py.title("FFT Data")
py.xlabel("Freq (MHz):"+ str(n) + " points")
py.ylabel("log10 |Y(freq)|")
py.grid()
py.draw()

py.show()
