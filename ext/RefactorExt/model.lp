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

% If two compression nodes are connected, there should be an edge between them.
comp_edge(C_PARENT, C_CHILD, ID) :- comp_node(C_PARENT, _), comp_node(C_CHILD, _), edge(C_PARENT, C_CHILD, ID).



% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Assignment constraints
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


% Each node might be assigned to an compression node with the same rule.
{ assign(C_NODE, NODE)} 1 :- node(NODE, RULE), comp_node(C_NODE, RULE).

% Assigned nodes should have the same rule.
:- comp_node(C_NODE, RULE_1), node(NODE, RULE_2), assign(C_NODE, NODE), RULE_1 != RULE_2.

% Each compression root must be assigned at least twice.
root_assigned_twice(C_NODE) :- comp_root(C_NODE), assign(C_NODE, NODE_1), assign(C_NODE, NODE_2), NODE_1 != NODE_2.
:- not root_assigned_twice(_).

% If a compression node with children is assigned, the assigned node should have the same children.
:- comp_node(C_NODE, RULE), comp_node(C_CHILD, _), node(NODE, RULE), assign(C_NODE, NODE), edge(C_NODE, C_CHILD, ID), #count{CHILD: edge(NODE, CHILD, ID)} = 0.

% If a compression node is assigned, so must the children of the node (if it has any)
assign(C_CHILD, CHILD) :- comp_node(C_NODE, _), edge(C_NODE, C_CHILD, ID), node(NODE, _), edge(NODE, CHILD, ID), assign(C_NODE, NODE).


#show comp_root/1.
#show comp_node/2.
#show comp_edge/3.

%% ------------------------- optimizing part ---------------------------------

#maximize {1, X : assign(_, X)}.