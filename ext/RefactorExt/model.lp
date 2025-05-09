% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Compression tree definition
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

% Each node might be compression node.
{ comp_node(NODE, RULE)} 1 :- node(NODE, RULE).

% Each compression node might be a compression root.
{ comp_root(ROOT)} 1 :- comp_node(ROOT, _).

% There are k=1 compression roots assigned.
:- #count {ROOT: comp_root(ROOT)} != 1.

% A compression root cannot be the child of another compression node.
:- comp_root(ROOT), edge(PARENT, ROOT, _), comp_node(PARENT, _).

% A compression node is the root if it is the child of a non-compression node.
comp_root(ROOT) :- comp_node(ROOT, _), edge(PARENT, ROOT, _), not comp_node(PARENT, _).

% A compression node is the root if it has no parents.
comp_root(ROOT) :- comp_node(ROOT, _), not edge(_, ROOT, _).

% A compression root must have at least one child.
root_has_child(ROOT) :- comp_root(ROOT), comp_node(CHILD, _), edge(ROOT, CHILD, _).
:- not root_has_child(_).


%
%  Idea: reuse the same structure as above, but assert that each node corresponds with a compression root or node.
%


% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Assignment constraints
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

%% Assigns compressions to models. Each node is assigned to either one or zero compression trees.
%%{ assign(A, X) : comp_root(A) } 1 :- node(X, _).

%% Only one compression tree is used
%%:- #count {A: comp_root(A), assign(A, _)} > 1.
%% nonassigned :- not assign(A, _). %% for k=2, not assign(B, _), B !=A.
%% :- not nonassigned. 

%% The used compression tree is assigned to at least two nodes
%%:- comp_root(A), assign(A, _), #count {X: node(X, _), assign(A, X)} < 2.

%% It may not be that K has child with index I, and X does not have a child with index I
%%:- assign(K, X), edge(K, M, I), comp_node(M, _), #count {Y: edge(X, Y, I)} = 0. 

%% Assign child I of X if there is child I of K to assign
%%assign(M, Y) :- assign(K, X), edge(X, Y, I), edge(K, M, I).

%% Each node X may have at most one assignment
%%:- node(X, _), #count {K: assign(K, X)} > 1.

%% Each node X may only be assigned to compression node K if they have the same type
%%:- assign(A, X), node(X, I), comp_node(A, J), I!=J.

#show assign/2.
#show comp_node/2.
#show comp_root/1.

%% ------------------------- optimizing part ---------------------------------

#maximize {1, X : assign(_, X)}.