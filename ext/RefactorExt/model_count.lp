% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Compression tree definition
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

% Each node might be compression node.
{ comp_node(NODE, RULE)} 1 :- node(NODE, RULE).

% Each compression node might be a compression root.
{ comp_root(ROOT)} 1 :- comp_node(ROOT, _).

% There are k=1 compression roots.
:- #count {ROOT: comp_root(ROOT)} != k.
%--- Removing count makes it slower:
%:- comp_root(ROOT_1), comp_root(ROOT_2), ROOT_1 != ROOT_2.

% Each edge might be a compression edge.
{ comp_edge(PARENT, CHILD, ID)} 1 :- edge(PARENT, CHILD, ID).

% A compression edge must be between two compression nodes
comp_node(NODE, RULE) :- node(NODE, RULE), comp_edge(NODE, _, _).
comp_node(NODE, RULE) :- node(NODE, RULE), comp_edge(_, NODE, _).

% A compression root cannot be the child of another compression node.
:- comp_root(ROOT), comp_node(PARENT, _), comp_edge(PARENT, ROOT, _).

% A compression node is the root if does not have an incomming compression edge.
comp_root(ROOT) :- comp_node(ROOT, _), #count {PARENT: comp_edge(PARENT, ROOT, _)} = 0.
%--- Removing count does not do anything
%comp_root(ROOT) :- comp_node(ROOT, _), not comp_edge(_, ROOT, _).

% A compression root must have at least one child.
:- comp_root(ROOT), #count {CHILD: comp_edge(ROOT, CHILD, _)} = 0.
% --- Removing count makes it way lower
%:- comp_root(ROOT), not comp_edge(ROOT, _, _).

% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Assignment constraints
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


% Each node might be assigned to an compression node with the same rule.
{ assign(C_NODE, NODE)} 1 :- node(NODE, RULE), comp_node(C_NODE, RULE).

% A node that is assigned must be a compression node.
comp_node(C_NODE, RULE) :- assign(C_NODE, _), node(C_NODE, RULE).

% Assigned nodes should have the same rule.
:- comp_node(C_NODE, RULE_1), node(NODE, RULE_2), assign(C_NODE, NODE), RULE_1 != RULE_2.

% Each compression root must be assigned at least twice.
:- comp_root(C_NODE), #count {NODE: assign(C_NODE, NODE)} < 2.
%--- Removing count statement makes it way slower
%comp_root_assigned_twice(ROOT) :- comp_root(ROOT), assign(ROOT, NODE_1), assign(ROOT, NODE_2), NODE_1 != NODE_2.
%:- comp_root(ROOT), not comp_root_assigned_twice(ROOT).

% If a compression node is assigned, so must the children of the node (if it has any)
assign(C_CHILD, CHILD) :- comp_edge(C_NODE, C_CHILD, ID), edge(NODE, CHILD, ID), assign(C_NODE, NODE).

% If a compression node is assigned, so must the parent of the node (if it has any)
assign(C_PARENT, PARENT) :- comp_edge(C_PARENT, C_NODE, ID), edge(PARENT, NODE, ID), assign(C_NODE, NODE).

% Enforce that assigned children have the correct index.
:- assign(C_NODE, NODE), comp_edge(C_PARENT, C_NODE, ID), #count{PARENT: edge(PARENT, NODE, ID)} = 0.
%-- Removing count statement does not do anything
%:- assign(C_NODE, NODE), comp_edge(C_PARENT, C_NODE, ID), not edge(_, NODE, ID).


#show comp_root/1.
#show comp_node/2.
#show comp_edge/3.

%% ------------------------- optimizing part ---------------------------------

% Maximize assignment
#maximize {1, X : assign(_, X)}.
%:~ assign(X, Y). [-1,Y]