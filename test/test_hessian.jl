using Base.Test
using ReverseDiffSparse

function test_sparsity(sp, H)
    I,J = sp
    Hsp = sparse(I,J,ones(length(I)))
    H = sparse(tril(H))
    @test all( Hsp.colptr .== H.colptr)
    @test all( Hsp.rowval .== H.rowval)
end

x,y,z,q = placeholders(4)

ex = @processNLExpr sin(x*y) + exp(z+2q)
sp = compute_hessian_sparsity_IJ(ex)
hfunc = gen_hessian_dense(ex)
val = [3.0, 4.0, 5.0, 6.0]
exact(x,y,z,q) = [ -y^2*sin(x*y) cos(x*y)-x*y*sin(x*y) 0 0
                   cos(x*y)-x*y*sin(x*y) -x^2*sin(x*y) 0 0
                   0 0 exp(z+2q) 2*exp(z+2q)
                   0 0 2*exp(z+2q) 4*exp(z+2q) ]
@test_approx_eq hfunc(val) exact(val...)
test_sparsity(sp, exact(val...))

sparsemat, sparsefunc = gen_hessian_sparse_mat(ex)
sparsefunc(val, sparsemat)
@test_approx_eq sparsemat tril(exact(val...))

I,J, sparsefunc_color = gen_hessian_sparse_color_parametric(ex)
V = zeros(length(I))
sparsefunc_color(val, V, ex)
@test_approx_eq to_H(ex, I, J, V, 4) tril(exact(val...))

x = placeholders(5)

ex = @processNLExpr  sum{ x[i]^2, i =1:5 } + sin(x[1]*x[2])
sp = compute_hessian_sparsity_IJ(ex)
hfunc = gen_hessian_dense(ex)
exact(x) = [ -x[2]^2*sin(x[1]*x[2]) cos(x[1]*x[2])-x[1]*x[2]*sin(x[1]*x[2]) 0 0 0
            cos(x[1]*x[2])-x[1]*x[2]*sin(x[1]*x[2]) -x[1]^2*sin(x[1]*x[2]) 0 0 0
            0 0 0 0 0
            0 0 0 0 0
            0 0 0 0 0] + diagm(fill(2.0, length(x)))
val = rand(5)

@test_approx_eq hfunc(val) exact(val)
test_sparsity(sp, exact(val))

sparsemat, sparsefunc = gen_hessian_sparse_mat(ex)
sparsefunc(val, sparsemat)
@test_approx_eq sparsemat tril(exact(val))

I, J, sparsefunc_color = gen_hessian_sparse_color_parametric(ex)
V = zeros(length(I))
sparsefunc_color(val, V, ex)
@test_approx_eq to_H(ex, I, J, V, 5) tril(exact(val))

# Expr list
exlist = ExprList()
for i in 1:5
    push!(exlist,@processNLExpr x[i]^3/6)
end

I,J = prep_sparse_hessians(exlist)
V = zeros(length(I))
lambda = rand(5)
eval_hess!(V, exlist, val, lambda)
@test_approx_eq sparse(I,J,V) diagm(lambda.*val)

# test linear expressions
x,y = placeholders(2)
ex = @processNLExpr 2x + y
I, J, sparsefunc_color = gen_hessian_sparse_color_parametric(ex)
@assert length(I) == length(J) == 0

# constant expressions
a = 10
ex = @processNLExpr (1/a+a)*x^2*y
I, J, sparsefunc_color = gen_hessian_sparse_color_parametric(ex)
exact(x,y) = [2y*(1/a+a) 0; 2x*(1/a+a) 0]
val = [4.5,2.3]
V = zeros(length(I))
sparsefunc_color(val, V, ex)
@test_approx_eq to_H(ex, I, J, V, 2) tril(exact(val...))

# prod{}
x = placeholders(2)
ex = @processNLExpr prod{x[i], i = 1:2}
I, J, sparsefunc_color = gen_hessian_sparse_color_parametric(ex)
V = zeros(length(I))
sparsefunc_color(val, V, ex)
@test_approx_eq to_H(ex, I, J, V, 2) tril([ 0.0 1.0; 1.0 0.0 ])


println("Passed tests")
