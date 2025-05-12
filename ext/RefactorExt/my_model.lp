% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Compression tree definition
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

% Each node might be compression node.
{ comp_node(NODE, RULE)} 1 :- node(NODE, RULE).
%node(NODE, RULE) :- comp_node(NODE, RULE).

% Each compression node might be a compression root.
{ comp_root(ROOT)} 1 :- comp_node(ROOT, _).
%comp_node(ROOT, RULE) :- comp_root(ROOT), node(ROOT, RULE).

% There are k=1 compression roots.
:- #count {ROOT: comp_root(ROOT)} != 1.

% Each edge might be a compression edge.
{ comp_edge(PARENT, CHILD, ID)} 1 :- edge(PARENT, CHILD, ID).


% A compression edge must be between two compression nodes
comp_node(NODE, RULE) :- node(NODE, RULE), comp_edge(NODE, _, _).
comp_node(NODE, RULE) :- node(NODE, RULE), comp_edge(_, NODE, _).

% A compression root cannot be the child of another compression node.
:- comp_root(ROOT), comp_node(PARENT, _), comp_edge(PARENT, ROOT, _).

% A compression node is the root if does not have an incomming compression edge.
comp_root(ROOT) :- comp_node(ROOT, _), #count {PARENT: comp_edge(PARENT, ROOT, _)} = 0.
%comp_root(ROOT) :- comp_node(ROOT, _), edge(PARENT, ROOT, ID), not comp_edge(PARENT, ROOT, ID).
%comp_root(ROOT) :- comp_node(ROOT, _), not edge(_, ROOT, _).

% A compression root must have at least one child.
:- comp_root(ROOT), #count {CHILD: comp_edge(ROOT, CHILD, _)} = 0.
%comp_root_has_child(ROOT) :- comp_root(ROOT), comp_edge(ROOT, _, _).
%comp_root_has_child(ROOT) :- comp_root(ROOT).



% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Assignment constraints
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


% Each node might be assigned to an compression node.
{ assign(C_NODE, NODE)} 1 :- node(NODE, RULE), comp_node(C_NODE, RULE).

% A node that is assigned must be a compression node.
comp_node(C_NODE, RULE) :- assign(C_NODE, _), node(C_NODE, RULE).

% Assigned nodes should have the same rule.
:- comp_node(C_NODE, RULE_1), node(NODE, RULE_2), assign(C_NODE, NODE), RULE_1 != RULE_2.

% Each compression root must be assigned at least twice.
:- comp_root(C_NODE), #count {NODE: assign(C_NODE, NODE)} < 2.
%comp_root_assigned_twice(ROOT) :- comp_root(ROOT), assign(ROOT, NODE_1), assign(ROOT, NODE_2), NODE_1 != NODE_2.
%comp_root_assigned_twice(ROOT) :- comp_root(ROOT).

% If a compression node with children is assigned, the assigned node should have the same children.
%:- comp_node(C_NODE, RULE), comp_node(C_CHILD, _), node(NODE, RULE), assign(C_NODE, NODE), edge(C_NODE, C_CHILD, ID), #count{CHILD: edge(NODE, CHILD, ID)} = 0.
%a(C_NODE) :- comp_node(C_NODE, RULE), comp_node(C_CHILD, _), comp_edge(C_NODE, C_CHILD, ID), node(NODE, RULE), assign(C_NODE, NODE), edge(NODE, CHILD, ID).
%:- not a(_).

% If a compression node is assigned, so must the children of the node (if it has any)
assign(C_CHILD, CHILD) :- comp_edge(C_NODE, C_CHILD, ID), edge(NODE, CHILD, ID), assign(C_NODE, NODE).


% If a compression node is assigned and has a compression node as parent, the parent of the assigned node should be assigned as well.
%assign(C_PARENT, PARENT) :- comp_node(C_NODE, _), comp_node(C_PARENT, _), comp_edge(C_PARENT, C_NODE, _), node(NODE, _), node(PARENT, _), edge(PARENT, NODE, _), assign(C_NODE, NODE).

% Enforce that assigned children have the correct index.
%:- comp_node(C_PARENT, _), comp_node(C_CHILD, _), node(PARENT, _), node(CHILD, _), assign(C_PARENT, PARENT), assign(C_CHILD, CHILD), edge(PARENT, CHILD, ID_1), comp_edge(C_PARENT, C_CHILD, ID_2), ID_1 != ID_2.


% Useful assignments
useful_assign(C_NODE, NODE) :- assign(C_NODE, NODE), node(NODE, RULE), RULE > 5.


#show comp_root/1.
#show comp_node/2.
#show comp_edge/3.

%% ------------------------- optimizing part ---------------------------------

% Maximize raw assignment
% Problem: counts assignments non-meaningful boilerplate.
#maximize {1, X : assign(_, X)}.

% Maximize amount of useful assignment
% Problem: assigns small parts (e.g. one terminal) that occurs often.
%#maximize {1, X : useful_assign(_, X)}.

% Maximize size of assigned subroutine 
%#maximize {1, X : useful_assign(X, _)}.
