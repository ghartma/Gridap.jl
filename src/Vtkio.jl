module Vtkio

export writevtk, visgrid

using Numa
using Numa: flatten
using Numa.Helpers
using Numa.CellValues
using Numa.CellValues: IndexCellValue
using Numa.CellFunctions
using Numa.FieldValues
using Numa.Polytopes
using Numa.Geometry
using Numa.Polytopes
using Numa.CellIntegration

import Numa.Geometry: cells, points, celltypes

using WriteVTK
using WriteVTK.VTKCellTypes: VTK_VERTEX
using WriteVTK.VTKCellTypes: VTK_LINE
using WriteVTK.VTKCellTypes: VTK_TRIANGLE
using WriteVTK.VTKCellTypes: VTK_QUAD
using WriteVTK.VTKCellTypes: VTK_TETRA
using WriteVTK.VTKCellTypes: VTK_HEXAHEDRON

function writevtk(grid::Grid,filebase;celldata=Dict(),pointdata=Dict())
  points = vtkpoints(grid)
  cells = vtkcells(grid)
  vtkfile = vtk_grid(filebase, points, cells)
  for (k,v) in celldata
    vtk_cell_data(vtkfile, prepare_data(v), k)
  end
  for (k,v) in pointdata
    vtk_point_data(vtkfile, prepare_data(v), k)
  end
  outfiles = vtk_save(vtkfile)
end

function vtkpoints(grid::Grid{D}) where D
  x = points(grid)
  xflat = collect(x)
  reshape(reinterpret(Float64,xflat),(D,length(x)))
end

# @fverdugo this allocates a lot of small objects
# Not very crucial since it is for visualization
# but it would be nice to have a better way
function vtkcells(grid::Grid)
  types = vtkcelltypedict()
  nodes = vtkcellnodesdict()
  c = celltypes(grid)
  n = cells(grid)
  [ MeshCell(types[encode_extrusion(ci)], ni[nodes[encode_extrusion(ci)]])
     for (ci,ni) in zip(c,n) ] 
end

# @fverdugo move this to another place, Polytope.jl?

"""
Encodes the tuple defining a Polytope into an integer
"""
function encode_extrusion(extrusion::NTuple{Z,Int}) where Z
  k = 0
  for (i,v) in enumerate(extrusion)
    k += v*3^i
  end
  k
end

"""
Decodes an integer into a tuple defining a Polytope
"""
function decode_extrusion(i::Int,::Val{Z}) where Z
  @notimplemented
end


# @fverdugo This can also be done by dispatching on value
"""
Generates the lookup table (as a Dict) in order to convert between
Numa Polytope identifiers into VTK cell type identifiers
"""
function vtkcelltypedict()
  d = Dict{Int,WriteVTK.VTKCellTypes.VTKCellType}()
  h = HEX_AXIS
  t = TET_AXIS
  d[encode_extrusion(())] = VTK_VERTEX
  d[encode_extrusion((t,))] = VTK_LINE
  d[encode_extrusion((h,))] = VTK_LINE
  d[encode_extrusion((t,t))] = VTK_TRIANGLE
  d[encode_extrusion((h,h))] = VTK_QUAD
  d[encode_extrusion((t,t,t))] = VTK_TETRA
  d[encode_extrusion((h,h,h))] = VTK_HEXAHEDRON
  d
end

# @fverdugo This can also be done by dispatching on value
"""
Generates the lookup table (as a Dict) in order to convert between
Numa Polytope corner numbering into VTK corner numbering
"""
function vtkcellnodesdict()
  d = Dict{Int,Vector{Int}}()
  h = HEX_AXIS
  t = TET_AXIS
  d[encode_extrusion(())] = [1,]
  d[encode_extrusion((t,))] = [1,2]
  d[encode_extrusion((h,))] = [1,2]
  d[encode_extrusion((t,t))] = [1,2,3]
  d[encode_extrusion((h,h))] = [1,2,4,3]
  d[encode_extrusion((t,t,t))] = [1,2,3,4]
  d[encode_extrusion((h,h,h))] = [1,2,4,3,5,6,8,7]
  d
end

function writevtk(points::CellPoints,filebase;celldata=Dict(),pointdata=Dict())
  grid, p_to_cell = cellpoints_to_grid(points)
  pdat = prepare_pointdata(pointdata)
  k = "cellid"
  @assert ! haskey(pdat,k)
  pdat[k] = p_to_cell
  writevtk(grid,filebase,pointdata=pdat)
end

function writevtk(points::CellValue{Point{D}} where D,filebase;celldata=Dict(),pointdata=Dict())
  grid = cellpoint_to_grid(points)
  pdat = prepare_pointdata(pointdata)
  writevtk(grid,filebase,pointdata=pdat)
end

function cellpoints_to_grid(points::CellPoints{D}) where D
  ps = Array{Point{D},1}(undef,(0,))
  p_to_cell = Array{Int,1}(undef,(0,))
  for (cell,p) in enumerate(points)
    for pj in p
      push!(ps,pj)
      push!(p_to_cell,cell)
    end
  end
  data, ptrs, ts = prepare_cells(ps)
  grid = UnstructuredGrid(ps,data,ptrs,ts)
  (grid, p_to_cell)
end

function cellpoint_to_grid(points::CellValue{Point{D}}) where D
  ps = collect(points)
  data, ptrs, ts = prepare_cells(ps)
  UnstructuredGrid(ps,data,ptrs,ts)
end

function prepare_cells(ps)
  data = [ i for i in 1:length(ps) ]
  ptrs = [ i for i in 1:(length(ps)+1) ]
  ts = [ () for i in 1:length(ps) ]
  (data,ptrs,ts)
end

function prepare_pointdata(pointdata)
  pdat = Dict()
  for (k,v) in pointdata
    pdat[k] = prepare_data(v)
  end
  pdat
end

prepare_data(v) = v

function prepare_data(v::IterData{<:VectorValue{D}}) where D
  a = collect(v)
  reshape(reinterpret(Float64,a),(D,length(a)))
end

function prepare_data(v::IterData{<:VectorValue{2}})
  a = collect(v)
  b = reshape(reinterpret(Float64,a),(2,length(a)))
  z = zeros((1,size(b,2)))
  vcat(b,z)
end

function prepare_data(v::IterData{<:TensorValue{D}}) where D
  a = collect(v)
  reshape(reinterpret(Float64,a),(D*D,length(a)))
end

prepare_data(v::CellArray{<:Number}) = collect(flatten(v))

function prepare_data(v::CellArray{<:VectorValue{D}}) where D
  a = collect(flatten(v))
  reshape(reinterpret(Float64,a),(D,length(a)))
end

function prepare_data(v::CellArray{<:VectorValue{2}})
  a = collect(flatten(v))
  b = reshape(reinterpret(Float64,a),(2,length(a)))
  z = zeros((1,size(b,2)))
  vcat(b,z)
end

function prepare_data(v::CellArray{<:TensorValue{D}}) where D
  a = collect(flatten(v))
  reshape(reinterpret(Float64,a),(D*D,length(a)))
end

struct VisualizationGrid{D,Z,G<:Grid{D,Z},C<:IndexCellValue{Int},P<:CellPoints{Z}} <: Grid{D,Z}
  grid::G
  coarsecells::C
  samplingpoints::P
end

points(vg::VisualizationGrid) = points(vg.grid)

cells(vg::VisualizationGrid) = cells(vg.grid)

celltypes(vg::VisualizationGrid) = celltypes(vg.grid)

function writevtk(vg::VisualizationGrid,filebase;celldata=Dict(),cellfields=Dict())
  cdata = prepare_cdata(celldata,vg.coarsecells)
  pdata = prepare_pdata(cellfields,vg.samplingpoints)
  writevtk(vg.grid,filebase,celldata=cdata,pointdata=pdata)
end

function prepare_cdata(celldata,fine_to_coarse)
  cdata = Dict()
  for (k,v) in celldata
    acoarse = collect(v)
    afine = allocate_afine(acoarse,length(fine_to_coarse))
    fill_afine!(afine,acoarse,fine_to_coarse)
    cdata[k] = afine
  end
  k2 = "cellid"
  @assert ! haskey(cdata,k2)
  cdata[k2] = fine_to_coarse
  cdata
end

allocate_afine(acoarse::Array{T},l) where T = Array{T,1}(undef,(l,))

function fill_afine!(afine,acoarse,fine_to_coarse)
  for (i,coarse) in enumerate(fine_to_coarse)
    afine[i] = acoarse[coarse]
  end
end

function prepare_pdata(cellfields,samplingpoints)
  pdata = Dict()
  for (k,v) in cellfields
    pdata[k] = collect(flatten(evaluate(v,samplingpoints)))
  end
  pdata
end

function visgrid(self::IntegrationMesh;nref=0)
  grid, coarsecells, samplingpoints = _prepare_grid(celltypes(self),geomap(self),nref)
  VisualizationGrid(grid,coarsecells,samplingpoints)
end

# @fverdugo Avoid code repetition with a generated function

function refgrid end

function refgrid(::Val{(HEX_AXIS,)},nref::Int)
  n = 2^nref
  CartesianGrid(domain=(-1.0,1.0),partition=(n,))
end

function refgrid(::Val{(HEX_AXIS,HEX_AXIS)},nref::Int)
  n = 2^nref
  CartesianGrid(domain=(-1.0,1.0,-1.0,1.0),partition=(n,n))
end

function refgrid(::Val{(HEX_AXIS,HEX_AXIS,HEX_AXIS)},nref::Int)
  n = 2^nref
  CartesianGrid(domain=(-1.0,1.0,-1.0,1.0,-1.0,1.0),partition=(n,n,n))
end

function _prepare_grid(celltypes::CellValue{NTuple{Z,Int}},phi::CellGeomap{Z,D},nref) where {Z,D}
  @notimplemented
end

function _prepare_grid(ctypes::ConstantCellValue{NTuple{Z,Int}},phi::CellGeomap{Z,D},nref) where {Z,D}
  refgrid = _prepare_refgrid(ctypes,nref)
  samplingpoints = _prepare_samplingpoints(refgrid,ctypes)
  ps, offsets = _prepare_points(samplingpoints,points(refgrid),phi)
  data, ptrs, coarsecells = _prepare_cells(refgrid,offsets)
  ts = _prepare_celltypes(length(ctypes),celltypes(refgrid))
  grid = UnstructuredGrid(ps,data,ptrs,ts)
  (grid, coarsecells, samplingpoints)
end

function _prepare_refgrid(ctypes,nref)
  extrusion = celldata(ctypes)
  refgrid(Val(extrusion),nref)
end

function _prepare_samplingpoints(refgrid,ctypes)
  refpoints = flatten(collect(points(refgrid)))
  ConstantCellArray(refpoints,length(ctypes))
end

function _prepare_points(samplingpoints,refpoints,phi::CellGeomap{Z,D}) where {Z,D}
  xe = evaluate(phi,samplingpoints)
  offsets = Array{Int,1}(undef,(length(xe),))
  ps = Array{Point{D},1}(undef,(length(xe)*length(refpoints)))
  _fill_ps_and_offsets!(ps,offsets,xe)
  (ps, offsets)
end

function _fill_ps_and_offsets!(ps,offsets,xe)
  k = 1
  for (n,x) in enumerate(xe)
    offsets[n] = k - 1
    for xi in x
      @inbounds ps[k] = xi
      k += 1
    end
  end
end

function _prepare_cells(refgrid,offsets)
  refcells = cells(refgrid)
  ptrs = Array{Int,1}(undef,(1+length(offsets)*length(refcells),))
  coarsecells = Array{Int,1}(undef,(length(offsets)*length(refcells),))
  _fill_ptrs_and_coarsecells!(ptrs,coarsecells,refcells,length(offsets))
  length_to_ptrs!(ptrs)
  data = Array{Int,1}(undef,(ptrs[end]-1,))
  _fill_data!(data,offsets,refcells)
  (data, ptrs, CellValueFromArray(coarsecells))
end

function _fill_ptrs_and_coarsecells!(ptrs,coarsecells,refcells,ncells)
  k = 1
  for cell in 1:ncells
    for refnodes in refcells
      @inbounds coarsecells[k] = cell
      k += 1
      @inbounds ptrs[k] = length(refnodes)
    end
  end
end

function _fill_data!(data,offsets,refcells)
  k = 1
  for offset in offsets
    for refnodes in refcells
      for node in refnodes
        @inbounds data[k] = node + offset
        k += 1
      end
    end
  end
end

function _prepare_celltypes(ncells,refcelltypes::ConstantCellValue)
  refextrusion = celldata(refcelltypes)
  fill(refextrusion,ncells*length(refcelltypes) )
end

end # module Vtkio
