% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Compression tree definition
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


% ---------------- Constants ----------------

% Loaded via data
% #const amount_of_rules = ?.
% #const max_children = ?.
% #const max_compression_nodes = ?.

comp_root_option(1..k).
comp_node_option(k+1..max_compression_nodes).

% ---------------- Generation ----------------

rules(RULE) :- node(NODE_1, RULE), node(NODE_2, RULE), NODE_1 != NODE_2.
edge_rule(P_RULE, C_RULE, ID) :- node(PARENT_1, P_RULE), node(CHILD_1, C_RULE), edge(PARENT_1, CHILD_1, ID), node(PARENT_2, P_RULE), node(CHILD_2, C_RULE), edge(PARENT_2, CHILD_2, ID), PARENT_1 != PARENT_2, CHILD_1 != CHILD_2.

1 { comp_root(K, RULE) : rules(RULE) } 1 :- comp_root_option(K).

{ comp_node(NODE, RULE) : rules(RULE) } 1 :- comp_node_option(NODE).


1 { comp_edge(ROOT, CHILD, POS) : comp_node(CHILD, CHILD_RULE), edge_rule(ROOT_RULE, CHILD_RULE, POS) } max_children :- comp_root(ROOT, ROOT_RULE).

%{ comp_edge(PARENT, CHILD, 1..max_children) } 1 :- comp_node_option(PARENT), comp_node_option(CHILD), CHILD > PARENT, CHILD <= PARENT + max_children.
%{ comp_edge(PARENT, CHILD, POS) : edge_rule(PARENT_RULE, CHILD_RULE, POS) } 1 :- comp_node(PARENT, PARENT_RULE), comp_node(CHILD, CHILD_RULE), CHILD > PARENT, CHILD <= PARENT + max_children.
%{ comp_edge(PARENT, CHILD, POS) : comp_node(PARENT, PARENT_RULE), edge_rule(PARENT_RULE, CHILD_RULE, POS), CHILD > PARENT, CHILD <= PARENT + max_children } 1 :- comp_node(CHILD, CHILD_RULE).
comp_edge(PARENT, CHILD, POS) :- comp_node(PARENT, PARENT_RULE), edge_rule(PARENT_RULE, CHILD_RULE, POS), CHILD > PARENT, CHILD <= PARENT + max_children, comp_node(CHILD, CHILD_RULE).


% ---------------- Node constraints ----------------

% Each compression node has a parent (notice that the root is not a compression node).
has_parent(NODE) :- comp_node(NODE, _), comp_edge(_, NODE, _).
:- comp_node(NODE, _), not has_parent(NODE).

% Nodes can only take on a rule that exists in at least some program.
%:- comp_node(_, RULE), not node(_, RULE).

% Nodes can only take on rules that exists in at least two programs.
% Note: while it seems like the rule must only exist in one program, a compression is only useful when there at least two occurences.
% rule_has_two_occurences(RULE) :- node(NODE_1, RULE), node(NODE_2, RULE), NODE_1 != NODE_2.
% :- comp_node(_, RULE), not rule_has_two_occurences(RULE).


% ---------------- Edge constraints ----------------

% An compression edge cannot be connected to itself.
%:- comp_edge(NODE, NODE, _).

% An compression edge going from the same nodes cannot have to different positions.
%:- comp_edge(PARENT, CHILD, POS_1), comp_edge(PARENT, CHILD, POS_2), POS_1 != POS_2.

% An compression edge from the same parent at the same position cannot go to different children.
:- comp_edge(PARENT, CHILD_1, POS), comp_edge(PARENT, CHILD_2, POS), CHILD_1 != CHILD_2.


% TODO: document, is actually enforced by the assignments, but makes it faster
comp_edge_rule(P_RULE, C_RULE, ID) :- comp_node(PARENT, P_RULE), comp_node(CHILD, C_RULE), comp_edge(PARENT, CHILD, ID).
comp_edge_rule(P_RULE, C_RULE, ID) :- comp_root(PARENT, P_RULE), comp_node(CHILD, C_RULE), comp_edge(PARENT, CHILD, ID).
:- comp_edge_rule(P_RULE, C_RULE, ID), not edge_rule(P_RULE, C_RULE, ID).
% Possible problem: not grounded

% Each edge is connected comp nodes
:- comp_edge(_, CHILD, _), not comp_node(CHILD, _).



% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Symmetry breaking constraints
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

% If there are K compression nodes, than they only have indices 1..K.
% Change this to within a tree
compressed(NODE) :- comp_root(NODE, _).
compressed(NODE) :- comp_node(NODE, _).
:- compressed(K), K > 1, not compressed(K-1).

% The index of a child left of its sibling cannot be larger than that of its sibling.
:- comp_edge(PARENT, CHILD_1, POS_1), comp_edge(PARENT, CHILD_2, POS_2), POS_1 < POS_2, CHILD_1 > CHILD_2.

% The index of a child is always larger than its parent
% Already enforced in the generation part
%:- comp_edge(PARENT, CHILD, _), PARENT > CHILD.

% The direct children of root K, have a larger index than the all nodes connected to root K-1
connects_to_root(ROOT, ROOT) :- comp_root(ROOT, _).
connects_to_root(NODE, ROOT) :- comp_edge(PARENT, NODE, _), connects_to_root(PARENT, ROOT).
:- comp_root(ROOT, _), ROOT > 1, comp_edge(ROOT, CHILD, _), connects_to_root(LEAF, ROOT-1), CHILD < LEAF.


% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Assignment constraints
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

% ---------------- Generation ----------------

% Each node might be assigned to an compression root with the same rule.
{ assign(C_NODE, NODE) } 1 :- node(NODE, RULE), comp_root(C_NODE, RULE).

% Each node might be assigned to an node.
{ assign(C_NODE, NODE) } 1 :- node(NODE, RULE), comp_node(C_NODE, RULE).


% ---------------- Constraints ----------------

% Each compression node must be assigned
:- comp_node(C_NODE, _), not assign(C_NODE, _).

% Assigned nodes should have the same rule.
:- comp_root(C_NODE, RULE_1), node(NODE, RULE_2), assign(C_NODE, NODE), RULE_1 != RULE_2.
:- comp_node(C_NODE, RULE_1), node(NODE, RULE_2), assign(C_NODE, NODE), RULE_1 != RULE_2.

% Each compression root must be assigned at least twice.
:- comp_root(C_NODE, _), #count {NODE: assign(C_NODE, NODE)} < 2.
%--- Removing count statement makes it way slower
%comp_root_assigned_twice(ROOT) :- comp_root(ROOT, _), assign(ROOT, NODE_1), assign(ROOT, NODE_2), NODE_1 != NODE_2.
%:- comp_root(ROOT, _), not comp_root_assigned_twice(ROOT).

% If a compression node is assigned, so must the children of the node (if it has any)
:- comp_edge(C_NODE, C_CHILD, ID), edge(NODE, CHILD, ID), assign(C_NODE, NODE), not assign(C_CHILD, CHILD).

% If a compression node is assigned, so must the parent of the node (if it has any)
:- comp_edge(C_PARENT, C_NODE, ID), edge(PARENT, NODE, ID), assign(C_NODE, NODE), not assign(C_PARENT, PARENT).

% Enforce that assigned children have the correct index.
%:- assign(C_NODE, NODE), comp_edge(C_PARENT, C_NODE, ID), #count{PARENT: edge(PARENT, NODE, ID)} = 0.
%-- Removing count statement does not do anything
:- assign(C_NODE, NODE), comp_edge(C_PARENT, C_NODE, ID), not edge(_, NODE, ID).


#show comp_root/2.
#show comp_node/2.
#show comp_edge/3.

%% ------------------------- optimizing part ---------------------------------

% Maximize assignment
%#maximize {1, X : assign(_, X)}.
:~ assign(_, Y). [-1, Y]
