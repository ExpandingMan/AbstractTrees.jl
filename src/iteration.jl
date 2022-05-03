

abstract type IteratorState{T<:TreeCursor} end

# we define this explicitly to avoid run-time dispatch
function instance(::Type{S}, node; kw...) where {S<:IteratorState}
    isnothing(node) ? nothing : S(node; kw...)
end


abstract type TreeIterator{T} end

Base.IteratorSize(::Type{<:TreeIterator}) = SizeUnknown()

function Base.iterate(ti::TreeIterator, s::Union{Nothing,IteratorState}=initial(statetype(ti), ti.root))
    isnothing(s) && return nothing
    (unwrap(s.cursor), next(s))
end


struct PreOrderState{T<:TreeCursor} <: IteratorState{T}
    cursor::T

    PreOrderState(csr::TreeCursor) = new{typeof(csr)}(csr)
end

PreOrderState(node) = (PreOrderState ∘ treecursor)(node)

initial(::Type{PreOrderState}, node) = PreOrderState(node)

function next(f, s::PreOrderState)
    if f(unwrap(s.cursor))
        ch = children(s.cursor)
        isempty(ch) || return instance(PreOrderState, first(ch))
    end

    csr = s.cursor
    while !isroot(csr)
        n = nextsibling(csr)
        if isnothing(n)
            csr = parent(csr)
        else
            return PreOrderState(n)
        end
    end
    nothing
end
next(s::PreOrderState) = next(x -> true, s)


struct PreOrderDFS{T,F} <: TreeIterator{T}
    filter::F
    root::T
end

PreOrderDFS(root) = PreOrderDFS(x -> true, root)

statetype(itr::PreOrderDFS) = PreOrderState

function Base.iterate(ti::PreOrderDFS, s::Union{Nothing,IteratorState}=initial(statetype(ti), ti.root))
    isnothing(s) && return nothing
    (unwrap(s.cursor), next(ti.filter, s))
end


struct PostOrderState{T<:TreeCursor} <: IteratorState{T}
    cursor::T

    PostOrderState(csr::TreeCursor) = new{typeof(csr)}(csr)
end

PostOrderState(node) = (PostOrderState ∘ treecursor)(node)

initial(::Type{PostOrderState}, node) = (PostOrderState ∘ descendleft ∘ treecursor)(node)

function next(s::PostOrderState)
    n = nextsibling(s.cursor)
    if isnothing(n)
        instance(PostOrderState, parent(s.cursor))
    else
        # descendleft is not allowed to return nothing
        PostOrderState(descendleft(n))
    end
end


struct PostOrderDFS{T} <: TreeIterator{T}
    root::T
end

statetype(itr::PostOrderDFS) = PostOrderState


struct LeavesState{T<:TreeCursor} <: IteratorState{T}
    cursor::T

    LeavesState(csr::TreeCursor) = new{typeof(csr)}(csr)
end

LeavesState(node) = (LeavesState ∘ treecursor)(node)

initial(::Type{LeavesState}, node) = (LeavesState ∘ descendleft ∘ treecursor)(node)

function next(s::LeavesState)
    csr = s.cursor
    while !isnothing(csr) && !isroot(csr)
        n = nextsibling(csr)
        if isnothing(n)
            csr = parent(csr)
        else
            # descendleft is not allowed to return nothing
            return LeavesState(descendleft(n))
        end
    end
    nothing
end


struct Leaves{T} <: TreeIterator{T}
    root::T
end

statetype(itr::Leaves) = LeavesState


struct SiblingState{T<:TreeCursor} <: IteratorState{T}
    cursor::T

    SiblingState(csr::TreeCursor) = new{typeof(csr)}(csr)
end

SiblingState(node) = (SiblingState ∘ treecursor)(node)

initial(::Type{SiblingState}, node) = SiblingState(node)

next(s::SiblingState) = nextsibling(s.cursor)


struct Siblings{T} <: TreeIterator{T}
    root::T
end

statetype(itr::Siblings) = SiblingState


function _ascend(getparent, select, node)
    isroot(node) && (select(node); return node)
    p = getparent(node)
    while select(node) && !isroot(node)
        node = p
        p = getparent(node)
    end
    node
end

"""
    ascend(select, node)
    ascend(select, tree, node)

Ascend a tree starting from node `node` and at each node choosing whether or not to terminate by calling
`select(n)` where `n` is the current node (`false` terminates).

For the two argument method, parents are obtained by calling `parent(tree, node)`, otherwise by calling
`parent(node)`.

Note that the parent is computed before `select` is executed, allowing modification to its argument
(as long as the tree structure is not altered).
"""
ascend(select, tree, node) = _ascend(n -> parent(tree, n), select, node)
ascend(select, node) = _ascend(parent, select, node)

"""
    descend(select, tree)

Descends the tree, at each node choosing the child given by select callback
or the current node if 0 is returned.

Requires tree nodes to have [`IndexedChildren`](@ref).
"""
function descend(select, ::IndexedChildren, tree)
    idx = select(tree)
    idx == 0 && return tree
    node = children(tree)[idx]
    while true
        idx = select(node)
        idx == 0 && return node
        node = children(node)[idx]
    end
end
descend(select, node) = descend(select, ChildIndexing(node), node)


struct StatelessBFS{T} <: TreeIterator{T}
    root::T
end

Base.iterate(ti::StatelessBFS) = (ti.root, [])

function _descend_left(inds, next_node, lvl)
    while length(inds) ≠ lvl
        ch = children(next_node)
        isempty(ch) && break
        push!(inds, 1)
        next_node = first(ch)
    end
    inds
end

function _nextind_or_deadend(node, ind, lvl)
    current_lvl = active_lvl = length(ind)
    active_inds = copy(ind)
    # go up until there is a sibling to the right
    while current_lvl > 0
        active_inds = ind[1:(current_lvl-1)]
        parent = childindex(node, active_inds)
        cur_child = ind[current_lvl]
        ch = children(parent)
        ni = nextind(ch, cur_child)
        current_lvl -= 1
        if !isnothing(iterate(ch, ni))
            newinds = [active_inds; ni]
            next_node = ch[ni]
            return _descend_left(newinds, next_node, lvl)
        end
    end
    nothing
end

function Base.iterate(ti::StatelessBFS, ind)
    org_lvl = active_lvl = length(ind)
    newinds = ind
    while true
        newinds = _nextind_or_deadend(ti.root, newinds, active_lvl)
        if isnothing(newinds)
            active_lvl += 1
            active_lvl > org_lvl + 1 && return nothing
            newinds = _descend_left([], ti.root, active_lvl)
        end
        length(newinds) == active_lvl && break
    end
    (childindex(ti.root, newinds), newinds)
end
