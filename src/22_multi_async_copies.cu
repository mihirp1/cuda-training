#include <cassert>
#include <iostream>
#include <vector>

using namespace std;

__global__
void Negate(signed char* buffer) {
    size_t i = blockDim.x * blockIdx.x + threadIdx.x;
    buffer[i] = -buffer[i];
}


int main(int, char**) {
    assert(sizeof(signed char) == 1);
    //allocate pinned host buffer
    const size_t HOST_BUFFER_SIZE = 1 << 32;
    const int NUM_DEVICES = 4;
    const size_t DEVICE_BUFFER_SIZE = HOST_BUFFER_SIZE / NUM_DEVICES;
    signed char* hostBuffer = 0;
    cudaError_t err = cudaMallocHost((void**) &hostBuffer, HOST_BUFFER_SIZE);
    assert(hostBuffer);
    assert(err == cudaSuccess);
    //initialize host buffer with -1-1-1-1-2-2-2-2-3-3-3-3-4-4-4-4
    InitHostBuffer(hostBuffer, HOST_BUFFER_SIZE, NUM_DEVICES);
    //allocate 4 device buffers, one per device
    vector< signed char* > deviceBuffers(NUM_DEVICES, 0);
    for(int d = 0; d != NUM_DEVICES; ++d) {
        err = cudaSetDevice(d);
        assert(err == cudaSuccess);
        err = cudaMalloc((void**) &deviceBuffers[d], DEVICE_BUFFER_SIZE);
        assert(deviceBuffers[d]);
        assert(err == cudaSuccess);
    }
    //async per-device copies
    for(int d = 0; d != NUM_DEVICES; ++d) {
        err = cudaSetDevice(d);
        assert(err == cudaSuccess);
        err = cudaMemcpyAsync(deviceBuffer[d], 
                              hostBuffer + d * DEVICE_BUFFER_SIZE, DEVICE,
                              DEVICE_BUFFER_SIZE, cudaMemcpyHostToDevice);
        assert(err == cudaSuccess);
    }
    //
    const int THREAD_BLOCK_SIZE = 1024;
    const int BLOCK_SIZE = DEVICE_BUFFER_SIZE / THREAD_BLOCK_SIZE;
    for(int d = 0; d != NUM_DEVICES; ++d) {
        err = cudaSetDevice(d);
        assert(err == cudaSuccess);
        Negate<<< BLOCK_SIZE, THREAD_BLOCK_SIZE >>>(deviceBuffers[d]);
        //err == cudaGetLastError();
        //assert(err == cudaSuccess);
    }
    //
    for(int d = 0; d != NUM_DEVICES; ++d) {
        err = cudaSetDevice(d);
        assert(err == cudaSuccess);
        err = cudaMemcpyAsync(hostBuffer + d * DEVICE_BUFFER_SIZE, DEVICE,
                              deviceBuffer[d], 
                              DEVICE_BUFFER_SIZE, cudaMemcpyDeviceToHost);
        assert(err == cudaSuccess);
    }

    for(int d = 0; d != NUM_DEVICES; ++d) {
        err = cudaSetDevice(d);
        assert(err == cudaSuccess);
        err = cudaDeviceSynchronize();
        assert(err == cudaSuccess);
    }
    
    for(int d = 0; d != NUM_DEVICES; ++d) {
        for(signed char* p = hostBuffer + d * DEVICE_BUFFER_SIZE;
            p != hostBuffer + d * DEVICE_BUFFER_SIZE + DEVICE_BUFFER_SIZE;
            ++p) assert(*p == -d);
    }

    err = cudaFreeHost(hostBuffer);
    assert(err);
    for(int d = 0; d != NUM_DEVICES; ++d) {
        err = setDevice(d);
        assert(err == cudaSuccess);
        err = cudaFree(deviceBuffers[d]);
        assert(err == cudaSuccess);
    }
    err = cudaDeviceReset();
    assert(err);
    return 0;
}