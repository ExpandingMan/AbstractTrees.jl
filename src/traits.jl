abstract type ParentLinks end

"""
  Indicates that this tree stores parent links explicitly. The implementation
  is responsible for defining the parentind function to expose this
  information.
"""
struct StoredParents <: ParentLinks; end
struct ImplicitParents <: ParentLinks; end

parentlinks(::Type) = ImplicitParents()
parentlinks(tree) = parentlinks(typeof(tree))

abstract type SiblingLinks end

"""
  Indicates that this tree stores sibling links explicitly, or can compute them
  quickly (e.g. because the tree has a (small) fixed branching ratio, so the
  current index of a node can be determined by quick linear search). The
  implementation is responsible for defining the relative_state function
  to expose this information.
"""
struct StoredSiblings <: SiblingLinks; end
struct ImplicitSiblings <: SiblingLinks; end
struct StoredSiblingsWithParent <: SiblingLinks; end

siblinglinks(::Type) = ImplicitSiblings()
siblinglinks(tree) = siblinglinks(typeof(tree))

abstract type TreeKind end
struct RegularTree <: TreeKind; end
struct IndexedTree <: TreeKind; end

treekind(tree::Type) = RegularTree()
treekind(tree) = treekind(typeof(tree))

"""
    nodetype(tree)

A trait function, defined on the tree object, specifying the types of the nodes.
The default is `Any`. When applicable, define this trait to make iteration inferrable.

# Example

```
struct IntTree
    num::Int
    children::Vector{IntTree}
end
AbstractTrees.children(itree::IntTree) = itree.children
AbstractTrees.nodetype(::IntTree) = IntTree
```

This suffices to make iteration over, e.g., `Leaves(itree::IntTree)` inferrable.
"""
nodetype(tree) = Any
idxtype(tree) = Int
