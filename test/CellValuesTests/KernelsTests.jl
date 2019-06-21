module KernelsTests

using Gridap
using TensorValues
using Gridap.Kernels: CellSumKernel
using Gridap.Kernels: LinCombKernel
using Gridap.Kernels: VarinnerKernel
using Gridap.Kernels: PhysGradKernel

# NumberKernelFromFunction

k = NumberKernelFromFunction(-)

test_number_kernel(k,1,4,3)

test_number_kernel(k,-1.0,1.0)

k = NumberKernelFromFunction(sum)

test_number_kernel(k,7,[1,2,4])

# ArrayKernelFromBroadcastedFunction

k = ArrayKernelFromBroadcastedFunction(*)

test_array_kernel(k,[3,4,3],[1,2,3],[3,2,1])

test_array_kernel(k,[6,4,2],2,[3,2,1])

test_array_kernel(k,[6,4,2],[3,2,1],2)

test_array_kernel(k,[6,4,2],[3,2,1],2,1)

u = rand(Int,2,3,1)
v = rand(Int,1,3,4)
w = u .* v
test_array_kernel(k,w,u,v)
test_array_kernel(k,w,u,v,1)

k = ArrayKernelFromBroadcastedFunction(+)

v1 = VectorValue(2,3)
v2 = VectorValue(3,2)
v3 = VectorValue(1,2)
u = [v1,v2,v3]
v = v1
w = u .+ v
test_array_kernel(k,w,u,v)

w = broadcast(+,u,v,0)
test_array_kernel(k,w,u,v,0)

# CellSumKernel

D = 1
k = CellSumKernel{D}()
a = rand(2,3,4)
b = reshape(sum(a,dims=D),(3,4))
test_array_kernel(k,b,a)

D = 2
k = CellSumKernel{D}()
a = rand(2,3,4)
b = reshape(sum(a,dims=D),(2,4))
test_array_kernel(k,b,a)

D = 3
k = CellSumKernel{D}()
a = rand(2,3,4)
b = reshape(sum(a,dims=D),(2,3))
test_array_kernel(k,b,a)

# LinCombKernel

k = LinCombKernel()
a = rand(4,8)
b = rand(4)
r = reshape(sum(outer.(a,reshape(b,(4,1))),dims=1),(8,))
test_array_kernel(k,r,a,b)

k = LinCombKernel()
ai = VectorValue(2.0,3.1,4.3)
a = fill(ai,4,8)
b = rand(4)
r = reshape(sum(outer.(a,reshape(b,(4,1))),dims=1),(8,))
test_array_kernel(k,r,a,b)

k = LinCombKernel()
ai = VectorValue(2.0,3.1,4.3)
a = fill(ai,4,8)
b = fill(ai,4)
r = reshape(sum(outer.(a,reshape(b,(4,1))),dims=1),(8,))
test_array_kernel(k,r,a,b)

# VarinnerKernel

k = VarinnerKernel()
a = rand(4,8)
b = rand(8)
r = inner.(a,reshape(b,(1,8)))
test_array_kernel(k,r,a,b)

k = VarinnerKernel()
a = rand(4,8)
b = rand(5,8)
r = inner.(reshape(a,(4,1,8)),reshape(b,(1,5,8)))
test_array_kernel(k,r,a,b)

ai = VectorValue(2.0,3.1,4.3)
bi = VectorValue(2.1,1.1,4.1)

a = fill(ai,4,8)
b = fill(bi,8)
r = inner.(a,reshape(b,(1,8)))
test_array_kernel(k,r,a,b)

a = fill(ai,4,8)
b = fill(bi,5,8)
r = inner.(reshape(a,(4,1,8)),reshape(b,(1,5,8)))
test_array_kernel(k,r,a,b)

# PhysGradKernel

k = PhysGradKernel()

ai = TensorValue(1.0,2.0,0.0,2.0)
bi = 3.0
a = fill(ai,8)
b = fill(bi,5,8)
r = outer.(reshape(inv.(a),1,8),b)
test_array_kernel(k,r,a,b)

bi = VectorValue(3.4,2.5)
b = fill(bi,5,8)
r = reshape(inv.(a),1,8) .* b
test_array_kernel(k,r,a,b)

end # module
