#ifndef HIP_T_H
#define HIP_T_H

#define cudaError_t hipError_t
#define cudaDeviceProp hipDeviceProp_t

#define cudaMalloc(ppt, size) hipMalloc(ppt, size)
#define cudaMemcpy(dst, src, size, type) hipMemcpy(dst, src, size, type)
#define cudaFree(pt) hipFree(pt)
#define cudaGetDevice(pt) hipGetDevice(pt)
#define cudaGetDeviceProperties(id, prop) hipGetDeviceProperties(id, prop)
#define cudaGetErrorString(e) hipGetErrorString(e)
#define cudaMemcpyDeviceToHost hipMemcpyDeviceToHost
#define cudaMemcpyHostToDevice hipMemcpyHostToDevice
#define cudaDeviceSynchronize() hipDeviceSynchronize()
#define cudaDeviceReset() hipDeviceReset()
#define cudaSetDevice(id) hipSetDevice(id)
#define cudaMallocPitch(a, b, c, d) hipMallocPitch(a, b, c, d)
#define cudaMemcpy2D(a, b, c, d, e, f, g) hipMemcpy2D(a, b, c, d, e, f, g)
#endif // HIP_T_H
