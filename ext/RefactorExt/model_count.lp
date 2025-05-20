% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Compression tree definition
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

comp_root_option(1..k).

#const amount_of_rules = 5.

#const max_children = 2.

#const max_compression_nodes = 10.

% TODO: enforce order on existing nodes
comp_node_option(k+1..k+max_compression_nodes).


1 { comp_root(K, 1..amount_of_rules) } 1 :- comp_root_option(K).

1 { comp_edge(K, CHILD, 1..max_children): comp_node_option(CHILD) } max_children :- comp_root_option(K).

{ comp_edge(PARENT, CHILD, 1..max_children) } 1 :- comp_node_option(PARENT), comp_node_option(CHILD).

{ comp_node(NODE, 1..amount_of_rules) } 1 :- comp_node_option(NODE).

% comp_root(1, 2).
% comp_node(2, 1).
% comp_node(3, 1).
% comp_edge(1, 2, 1).
% comp_edge(1, 3, 2).


:- comp_edge(NODE, NODE, _).

:- comp_edge(PARENT, CHILD, POS_1), comp_edge(PARENT, CHILD, POS_2), POS_1 != POS_2.

:- comp_edge(PARENT, CHILD_1, POS_1), comp_edge(PARENT, CHILD_2, POS_1), CHILD_1 != CHILD_2.


edge_rule(P_RULE, C_RULE, ID) :- node(PARENT, P_RULE), node(CHILD, C_RULE), edge(PARENT, CHILD, ID).
comp_edge_rule(P_RULE, C_RULE, ID) :- comp_node(PARENT, P_RULE), comp_node(CHILD, C_RULE), comp_edge(PARENT, CHILD, ID).
comp_edge_rule(P_RULE, C_RULE, ID) :- comp_root(_, P_RULE), comp_node(CHILD, C_RULE), comp_edge(PARENT, CHILD, ID).
:- comp_edge_rule(P_RULE, C_RULE, ID), not edge_rule(P_RULE, C_RULE, ID).
% Possible problem: not grounded

%tree_exists(ROOT) :- comp_root(_, RULE), node(_, RULE).
%tree_exists(NODE) :- comp_node(PARENT, CP_RULE), comp_node(CHILD, CC_RULE), tree_exists(PARENT), node(_, )

has_parent(NODE) :- comp_node(NODE, _), comp_edge(_, NODE, _).
:- comp_node(NODE, _), not has_parent(NODE).

% Each edge is connected comp nodes
:- comp_edge(_, CHILD, _), not comp_node(CHILD, _).


% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Assignment constraints
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


% Each node might be assigned to an compression root with the same rule.
{ assign(C_NODE, NODE)} 1 :- node(NODE, RULE), comp_root(C_NODE, RULE).

% Each compression node must be assigned
:- comp_node(C_NODE, _), not assign(C_NODE, _).

% A node that is assigned must be a compression node.
comp_node_or_root(C_NODE) :- comp_node(C_NODE, _).
comp_node_or_root(C_NODE) :- comp_root(C_NODE, _).
:- assign(C_NODE, _), not comp_node_or_root(C_NODE).

% Assigned nodes should have the same rule.
:- comp_node(C_NODE, RULE_1), node(NODE, RULE_2), assign(C_NODE, NODE), RULE_1 != RULE_2.

% Each compression root must be assigned at least twice.
:- comp_root(C_NODE, _), #count {NODE: assign(C_NODE, NODE)} < 2.
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


#show comp_root/2.
#show comp_node/2.
#show comp_edge/3.
%#show assign/2.


%% ------------------------- optimizing part ---------------------------------

% Maximize assignment
#maximize {1, X : assign(_, X)}.
%:~ assign(X, Y). [-1,Y]