comp_node(NODE, RULE) :- comp_root(NODE), node(NODE, RULE).
%{ comp_node(CHILD, RULE) } 1 :- comp_node(PARENT, _), node(CHILD, RULE), edge(PARENT, CHILD, ID).
%comp_edge(PARENT, CHILD, ID) :- comp_node(PARENT, _), comp_node(CHILD, _), edge(PARENT, CHILD, ID).


%% Assigns compressions to models. Each node is assigned to either one or zero compression trees.
{ assign(A, X) : comp_root(A) } 1 :- node(X, _).

%% Only one compression tree is used
:- #count {A: comp_root(A), assign(A, _)} > 1.
%% nonassigned :- not assign(A, _). %% for k=2, not assign(B, _), B !=A.
%% :- not nonassigned. 

%% The used compression tree is assigned to at least two nodes
:- comp_root(A), assign(A, _), #count {X: node(X, _), assign(A, X)} < 2.
%%  

%% It may not be that K has child with index I, and X does not have a child with index I
:- assign(K, X), edge(K, M, I), #count {Y: edge(X, Y, I)} = 0.
%% 

%% Assign child I of X if there is child I of K to assign
assign(M, Y) :- assign(K, X), edge(X, Y, I), edge(K, M, I).

%% Each node X may have at most one assignment
:- node(X, _), #count {K: assign(K, X)} > 1.

%% Each node X may only be assigned to compressionnode K if they have the same type
:- assign(A, X), node(X, I), comp_node(A, J), I!=J.

#show assign/2.

%% ------------------------- optimizing part ---------------------------------

%% #maximize {1, X : assign( _, X)}.
%%:~ assign(X, Y), comp_root(X). [-1]