import numpy as np
max_t = []
for i in range(1,1001):
    s = str(i*10000)
    tvals = np.load(f'1st-order-tvla-{s}.npy')
    max_t.append(np.max(np.absolute(tvals)))
    
import matplotlib.pyplot as plt
plt.rcParams["figure.figsize"] = (20,3)
plt.axhline(y=4.5, color='r', linestyle='-')
plt.plot(max_t)
