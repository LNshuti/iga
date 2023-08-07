import numpy as np
from timeit import default_timer as timer
from numba import vectorize

@vectorize(['float32(float32, float32)'])
def vectorAdd(a, b):    
    return a + b

# Simulate a large matrix multiplication operation
@vectorize(['float32(float32, float32)'])
def vectorMultiply(a, b):
    return a * b

def main():
    N = 32000000
    A = np.ones(N, dtype=np.float32)
    B = np.ones(N, dtype=np.float32)
    C = np.zeros(N, dtype=np.float32)

    start = timer()
    C = vectorAdd(A, B)
    vector_add_time = timer() - start

    print("C[:5] = " + str(C[:5]))
    print("C[-5:] = " + str(C[-5:]))

    print("VectorAdd took %f seconds" % vector_add_time)

    start = timer()
    # Define matrix E 
    E = np.ones(N, dtype=np.float32)
    F = np.ones(N, dtype=np.float32)
    G = np.zeros(N, dtype=np.float32)
    G = vectorMultiply(E, F)

    vector_multiply_time = timer() - start

    print("G[:5] = " + str(G[:5]))
    print("G[-5:] = " + str(G[-5:]))
    print("VectorMultiply took %f seconds" % vector_multiply_time)

if __name__ == '__main__':
    main()