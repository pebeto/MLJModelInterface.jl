@testset "cat-light" begin
    setlight()
    x = 1:5
    @test_throws M.InterfaceError M.categorical(x)
end

@testset "cat-full" begin
    setfull()
    M.categorical(::FI, a...; kw...) = categorical(a...; kw...)
    x = 1:5
    @test M.categorical(x) == categorical(x)
end

# ------------------------------------------------------------------------
@testset "matrix-light" begin
    setlight()
    X = ones(2, 3)
    @test matrix(X) === X
    @test matrix(X, transpose=true) == ones(3, 2)

    # The following tests should throw a M.InterfaceError
    # as we can't know apriori what the trait of `X` is without
    # needing the `FullInterface`.
    X = (1, 2, 3)
    @test_throws M.InterfaceError matrix(X)
    
    X = (a=[1, 2, 3], b=[1, 2, 3])
    @test_throws M.InterfaceError matrix(X)
end

@testset "matrix-full" begin
    setfull()
    M.matrix(::FI, ::Val{:table}, X; kw...) = Tables.matrix(X; kw...)
    X = (a=[1, 2, 3], b=[1, 2, 3])
    @test matrix(X) == hcat([1, 2, 3], [1, 2, 3])
end

# ------------------------------------------------------------------------
@testset "int-light" begin
    setlight()
    x = categorical([1, 2, 3])
    @test_throws M.InterfaceError int(x)
end

@testset "int-full" begin
    setfull()
    M.int(::FI, x::CategoricalValue) = CategoricalArrays.refcode(x)
    x = categorical(['a','b','a'])
    @test int(x[1]) == 0x01
    @test int(x[2]) == 0x02
    @test int(x[2]) isa UInt32
    @test int(x[1], type=Int64) == 1
    @test int(x[1], type=Int64) isa Int64
end
# ------------------------------------------------------------------------
@testset "classes-light" begin
    setlight()
    x = categorical(['a','b','a'])
    @test_throws M.InterfaceError classes(x)
end
@testset "classes-full" begin
    setfull()
    M.classes(::FI, p::CategoricalPool) =
        [p[i] for i in invperm(1:length(levels(p)))]
    M.classes(::FI, x::CategoricalValue) = classes(x.pool)
    x = categorical(['a','b','a'])
    @test classes(x[1]) == ['a', 'b']
end

# ------------------------------------------------------------------------
@testset "scitype-light" begin
    # throw error for any input anyway
    setlight()

    ary = rand(10, 3)
    @test_throws M.InterfaceError M.scitype(ary)

    df = DataFrame(rand(10, 3), :auto)
    @test_throws M.InterfaceError M.scitype(df)
end

@testset "scitype-full" begin
    setfull()
    M.scitype(::FI, v, X) = ScientificTypes.scitype(X)

    ary = rand(10, 3)
    @test M.scitype(ary) == AbstractArray{Continuous, 2}

    df = DataFrame(A = rand(10), B = categorical(rand('a':'c', 10)))
    sch = M.scitype(df)
    @test sch <: Table(Continuous, Multiclass)
end

# ------------------------------------------------------------------------
@testset "schema-light" begin
    # throw error for any input anyway
    setlight()
    ary = rand(10, 3)
    @test_throws M.InterfaceError M.schema(ary)
    df = DataFrame(rand(10, 3), :auto)
    @test_throws M.InterfaceError M.schema(df)
end

@testset "schema-full" begin
    setfull()
    M.schema(::FI, v, X) = ScientificTypes.schema(X)

    ary = rand(10, 3)
    @test_throws ArgumentError M.schema(ary)

    df = DataFrame(A = rand(10), B = categorical(rand('a':'c', 10)))
    sch = M.schema(df)
    @test sch.names == (:A, :B)
    @test sch.types[1] <: Float64
    @test sch.types[2] <: CategoricalValue
    @test sch.scitypes[1] <: Continuous
    @test sch.scitypes[2] <: Multiclass
end

# ------------------------------------------------------------------------
@testset "istable" begin
    # Nothing stops someone from implementing a Tables.jl
    # interface that subtypes `AbstractArray`, so therefore 
    # `istable` should throw an error for `LightInterface`
    setlight()
    X = rand(5)
    @test_throws M.InterfaceError M.istable(X)
    X = randn(5, 5)
    @test_throws M.InterfaceError M.istable(X)
    
    # The method runs in `FullInterface`
    setfull()
    X = rand(5)
    @test !M.istable(X)
    X = rand(5, 5)
    @test !M.istable(X)
    X = DataFrame(A=rand(10))
    @test M.istable(X)
end

# ------------------------------------------------------------------------
@testset "decoder-light" begin
    setlight()
    x = 5
    @test_throws M.InterfaceError decoder(x)
end

@testset "decoder-full" begin
    setfull()
    # toy test because I don't want to copy the decoder logic here
    M.decoder(::FI, x) = 0
    @test decoder(nothing) == 0
end

# ------------------------------------------------------------------------
@testset "table-light" begin
    setlight()
    X = ones(3, 2)
    @test_throws M.InterfaceError table(X)
end

@testset "table-full" begin
    setfull()
    function M.table(::FI, A::AbstractMatrix; names=nothing)
        _names = [Symbol(:x, j) for j in 1:size(A, 2)]
        return Tables.table(A, header=_names)
    end
    X = ones(3, 2)
    T = table(X)
    @test Tables.istable(T)
    @test Tables.matrix(T) == X
end

# ------------------------------------------------------------------------
@testset "nrows-light" begin
    setlight()
    X = (a=[4, 2, 1], b=[3, 2, 1])
    @test_throws M.InterfaceError nrows(X)
    @test nrows(nothing) == 0
end

@testset "nrows-full" begin
    setfull()
    X = ones(5)
    @test nrows(X) == 5
    X = ones(5, 3)
    @test nrows(X) == 5 
    # It doesn't make sense to get the numbers of rows for 
    # `AbstractArray`'s of dimension 3 or more. Except if these are 
    # defined as Tables. Hence `FullInterface` would be required to check this 
    X = ones(5, 3, 2)
    @test_throws ArgumentError nrows(X)
    M.nrows(::FI, ::Val{:table}, X) = Tables.rowcount(X)
    X = (a=[4, 2, 1], b=[3, 2, 1])
    @test nrows(X) == 3
end

# ------------------------------------------------------------------------
@testset "select-light" begin
    setlight()

    # test fallback
    X = nothing
    @test selectrows(X, 1) === nothing
    @test selectcols(X, 1) === nothing
    @test select(X, 1, 2) === nothing

    # table
    X = (x=[1, 1, 1], y=[2, 2, 2])
    @test_throws M.InterfaceError selectrows(X, 1)
    @test_throws M.InterfaceError selectcols(X, 1)

    # something else
    # For this case we would need `FullInterface`.
    X = (1, 2, 3)
    @test_throws M.InterfaceError selectrows(X, 1)
    @test_throws M.InterfaceError selectcols(X, 1)
    @test_throws M.InterfaceError select(X, 1, 1)
end

@testset "select-full" begin
    setfull()
   
    # test fallback
    X = nothing
    @test selectrows(X, 1) === nothing
    @test selectcols(X, 1) === nothing
    @test select(X, 1, 2) === nothing
    
    # vector
    X = ones(5)
    @test selectrows(X, 1) == [1.0]
    @test selectrows(X, 1:2) == ones(2,)
    @test selectrows(X, :) === X
    @test_throws ArgumentError selectcols(X, 5)
    @test_throws ArgumentError select(X, 2, 2)

    # matrix
    X = ones(5, 3)
    @test selectrows(X, 1) == ones(1, 3)
    @test selectrows(X, 1:2) == ones(2, 3)
    @test selectrows(X, :) === X
    @test selectcols(X, 1) == ones(5,)
    @test selectcols(X, 1:2) == ones(5, 2)
    @test selectcols(X, :) === X
    @test select(X, 1, 1) == 1.0
    @test select(X, 1:2, 1) == ones(2,)
    @test select(X, 1:2, 1:2) == ones(2, 2)

    # implement some behaviour:
    M.selectrows(::FI, ::Val{:table}, X, ::Colon) = X
    M.selectcols(::FI, ::Val{:table}, X, ::Colon) = X

    function M.selectrows(::FI, ::Val{:table}, X, r)
        r = r isa Integer ? (r:r) : r
        cols = Tables.columntable(X)
        new_cols = NamedTuple{keys(cols)}(tuple((c[r] for c in values(cols))...))
        return Tables.materializer(X)(new_cols)
    end
    function M.selectcols(::FI, ::Val{:table}, X, c::Union{Symbol,Integer})
        cols = Tables.columntable(X) # named tuple of vectors
        return cols[c]
    end
    function M.selectcols(::FI, ::Val{:table}, X, c::AbstractArray)
        cols = Tables.columntable(X) # named tuple of vectors
        newcols = project(cols, c)
        return Tables.materializer(X)(newcols)
    end
    # project named tuple onto a tuple with only specified `labels` or indices:
    function project(t::NamedTuple, labels::AbstractArray{Symbol})
        return NamedTuple{tuple(labels...)}(t)
    end

    project(t::NamedTuple, label::Colon) = t
    project(t::NamedTuple, label::Symbol) = project(t, [label,])
    
    function project(t::NamedTuple, indices::AbstractArray{<:Integer})
        return NamedTuple{tuple(keys(t)[indices]...)}(tuple([t[i] for i in indices]...))
    end
    
    project(t::NamedTuple, i::Integer) = project(t, [i,])

    X = (x=[1, 2, 3], y=[4, 5, 6], z=[0, 0, 0])
    @test selectrows(X, 1) == (x=[1], y=[4], z=[0])
    @test selectrows(X, 1:2) == (x=[1, 2], y=[4, 5], z=[0, 0])
    @test selectrows(X, :) === X
    @test selectcols(X, 1) == [1, 2, 3]
    @test selectcols(X, 1:2) == (x = [1, 2, 3], y = [4, 5, 6])
    @test selectcols(X, :) === X
    @test select(X, 1, 1) == 1
    @test select(X, 1:2, 1) == [1, 2]
    @test select(X, :, 1) == [1, 2, 3]
    @test selectcols(X, :x) == [1, 2, 3]
    @test select(X, 1:2, :z) == [0, 0]
    
    # extra tests by Anthony
    X = (x=[1, 2, 3], y=[10, 20, 30], z= [:a, :b, :c])
    @test select(X, 2, :y) == 20
    @test select(X, 2, [:x, :y]) == (x=[2,], y=[20,])
    @test select(X, 2:3, :x) == [2, 3]
    @test select(X, 2:3, [:x, :y]) == (x=[2, 3], y=[20, 30])
    @test select(X, :, [:x, :y]) == select(X, 1:3, [:x, :y])
    @test select(X, 2, :) == select(X, 2, 1:3)
    @test select(X, 2:3, :) == select(X, 2:3, 1:3)

    @test select(X, 2, 2) == 20
    @test select(X, 2, [1, 2]) == (x=[2,], y=[20,])
    @test select(X, 2:3, 1) == [2, 3]
    @test select(X, 2:3, [1, 2]) == (x=[2, 3], y=[20, 30])
    @test select(X, :, [1, 2]) == select(X, 1:3, [1, 2])
    @test select(X, 2, :) == select(X, 2, 1:3)
    @test select(X, 2:3, :) == select(X, 2:3, 1:3)
end

# ------------------------------------------------------------------------
@testset "univ-finite" begin
    setlight()
    @test_throws M.InterfaceError UnivariateFinite(Dict(2=>3, 3=>4))
    @test_throws M.InterfaceError UnivariateFinite(randn(2), randn(2))
end

@testset "not assuming MLJModelInterface symbol at user-side" begin
    eval(:(module UserSide
            import MLJModelInterface: metadata_model, metadata_pkg
            struct A end
            human_name = "Big Foot"
            # Smoke tests.
            metadata_model(A; human_name)
            metadata_pkg(A)
    end))
end
