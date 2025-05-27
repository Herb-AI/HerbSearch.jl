
%
% Brief explainer of how this model works. Loaded in are a bunch of programs, represented in the following way:
% * root(ID):             
%     - ID is an unique identifier for a node. Starts at 1 and counting continues between programs.
%
%  * node(ID, RULE_INDEX):
%     - RULE_INDEX is the grammar rule that corresponds to this node.
%     - For each root(..), there also is a node(..).
%
%  * edge(PARENT_ID, CHILD_ID, CHILD_POSITION):
%     - CHILD_POSITION determines where the child is placed with respect to the parent. This matters since e.g. 2 / x != x / 2.
%
%
%
% The compression model consists of two parts:
%  * Compression tree definition:
%     - Defines how a compression tree looks. 
%     - Follows the same representations as programs, but with comp_ as prefix (i.e. comp_root, comp_node, comp_edge).
%     - Unlike the programs, a comp_root is not a comp_node.
%     - We also ensure that a compression tree has at least two nodes, otherwise it wouldn't compress anything.
%  
%  * Assignments:
%     - Assigns a compression tree to a program.
%     - The amount of assignments is actually what we wish to maximize.
%     - We ensure that each compression tree is actually assigned twice or more, otherwise it wouldn't be a compression.





% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Compression tree definition
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


% ---------------- Constants ----------------
% The following constants are loaded via data
%
% #const k = ?
% The number of compression trees to find. Is supplied by the user.
%
% #const amount_of_rules = ?.
% The number of rules in the grammar. Is extracted from the grammar itself.
%
% #const max_children = ?.
% The maximum number of children a node may have. This depends on the grammar, but must currently be supplied by the user.
%
% #const max_compression_nodes = ?.
% The maximum number of compression nodes that may be used. This number is shared amoung all compression trees.




% ---------------- Generation of compression tree ----------------

% Since we only want to find compression trees that can be assigned twice, we only need to consider rules that appear twice.
rule_appears_twice(RULE) :- node(NODE_1, RULE), node(NODE_2, RULE), NODE_1 != NODE_2.

% The same logic goes for edges. For this we create a new kind of statement (edge_rule) that contains the rule indicies that are connected and by which index.
edge_rule_twice(P_RULE, C_RULE, ID) :- node(PARENT_1, P_RULE), node(CHILD_1, C_RULE), edge(PARENT_1, CHILD_1, ID), node(PARENT_2, P_RULE), node(CHILD_2, C_RULE), edge(PARENT_2, CHILD_2, ID), PARENT_1 != PARENT_2, CHILD_1 != CHILD_2.

% Generate #k roots, only with rules that appear at least twice.
1 { comp_root(K, RULE) : rule_appears_twice(RULE) } 1 :- K = 1..k.

% Generate (#max_compression_node - #k) nodes, only with rules that appear at least twice.
{ comp_node(NODE, RULE) : rule_appears_twice(RULE) } 1 :- NODE = k+1..max_compression_nodes.

% For each root, create at most #max_children children with edge_rules that appear at least twice.
1 { comp_edge(ROOT, CHILD, POS) : comp_node(CHILD, CHILD_RULE), edge_rule_twice(ROOT_RULE, CHILD_RULE, POS) } max_children :- comp_root(ROOT, ROOT_RULE).

% For each pair of comp_nodes that has an edge_rule that appears twice we might create a comp_edge connecting them.
% This directly includes a symmetry breaking constraint:
%   The children of a comp_node with index ID can have indices ID + 1, ID + 2, ..., ID + #max_children.
% This only works since roots are not considered comp_nodes. Otherwise this would break since roots are indexed 1, 2, ..., k.
{ comp_edge(PARENT, CHILD, POS) } 1 :- comp_node(PARENT, PARENT_RULE), comp_node(CHILD, CHILD_RULE), edge_rule_twice(PARENT_RULE, CHILD_RULE, POS), CHILD > PARENT, CHILD <= PARENT + max_children.



% ---------------- Compression node constraints ----------------

% Each compression node has a parent (recall that the root is not a compression node).
has_parent(NODE) :- comp_node(NODE, _), comp_edge(_, NODE, _).
:- comp_node(NODE, _), not has_parent(NODE).



% ---------------- Compression edge constraints ----------------

% The symmetry breaking of compression edges already ensures that a compression edge cannot be connected to itself.

% That a compression edge going from the same parent and child node cannot have to different positions is ensured by the assignments.
% The rule below that would do that, only makes the model slower.
%:- comp_edge(PARENT, CHILD, POS_1), comp_edge(PARENT, CHILD, POS_2), POS_1 != POS_2.

% That a compression edge going from the same parent with the same child position cannot go to a different child node, is also ensured by the assignments.
% But including this rule, actually makes the model faster.
:- comp_edge(PARENT, CHILD_1, POS), comp_edge(PARENT, CHILD_2, POS), CHILD_1 != CHILD_2.


% The following ensures that each edge appears at least in twice in the programs. 
% This is also ensured by the assignments, but including it, makes it faster.
comp_edge_rule(P_RULE, C_RULE, ID) :- comp_node(PARENT, P_RULE), comp_node(CHILD, C_RULE), comp_edge(PARENT, CHILD, ID).
comp_edge_rule(P_RULE, C_RULE, ID) :- comp_root(PARENT, P_RULE), comp_node(CHILD, C_RULE), comp_edge(PARENT, CHILD, ID).
:- comp_edge_rule(P_RULE, C_RULE, ID), not edge_rule_twice(P_RULE, C_RULE, ID).

% This ensures that an compression edge is connected compression nodes.
% This is also ensured by the assignments, but including it, makes it faster.
:- comp_edge(_, CHILD, _), not comp_node(CHILD, _).



% ---------------- Symmetry breaking constraints ----------------

% This ensures that if there are N compression nodes used, they are index 1, 2, ..., N.
compressed(NODE) :- comp_root(NODE, _).
compressed(NODE) :- comp_node(NODE, _).
:- compressed(N), N > 1, not compressed(N-1).

% This ensures that children of the same parent have increasing indices given their positions.
% For example, a parent with ID=5 has children ID 6 at position 1, ID 7 at position 2, etc.
:- comp_edge(PARENT, CHILD_1, POS_1), comp_edge(PARENT, CHILD_2, POS_2), POS_1 < POS_2, CHILD_1 > CHILD_2.

% The following is in theory redundant, but gives a huge speed-up.
% It ensures that the children of root K, have a larger index than the all descendants of root K-1.
connects_to_root(ROOT, ROOT) :- comp_root(ROOT, _).
connects_to_root(NODE, ROOT) :- comp_edge(PARENT, NODE, _), connects_to_root(PARENT, ROOT).
:- comp_root(ROOT, _), ROOT > 1, comp_edge(ROOT, CHILD, _), connects_to_root(LEAF, ROOT-1), CHILD < LEAF.






% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
%
%    Assignment constraints
%
% -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

% ---------------- Assignment generation ----------------

% Befere generating the assignments, we first define two constraints that each assignment has to adhere to.
% 1. A node has the correct position w.r.t. a compression node if they have the same position relative to their parents.
correct_position(C_NODE, NODE) :- comp_edge(_, C_NODE, ID), edge(_, NODE, ID).

% 2. A node has a child at the correct position w.r.t. a compression node, if they have a child at the same position.
%    an exception occurs when a compression node does not have a child. 
correct_child_position(C_NODE, NODE) :- comp_edge(C_NODE, _, ID), edge(NODE, _, ID).
correct_child_position(C_NODE, NODE) :- not comp_edge(C_NODE, _, _), node(NODE, RULE), comp_node(C_NODE, RULE).

% Each node that has a child might be assigned to at most one compression root with the same rule.
{ assign(C_NODE, NODE) : comp_root(C_NODE, RULE), correct_child_position(C_NODE, NODE) } 1 :- node(NODE, RULE), edge(NODE, _, _).


% Each node might be assigned to at most one compression node with the same rule.
{ assign(C_NODE, NODE) : comp_node(C_NODE, RULE), correct_position(C_NODE, NODE), correct_child_position(C_NODE, NODE) } 1 :- node(NODE, RULE).
% comp_edge(C_PARENT, C_NODE, ID), not edge(_, NODE, ID)



% ---------------- Assignment constraints ----------------

% Each compression root must be assigned at least twice.
% Removing the count statement makes the model way slower.
:- comp_root(C_NODE, _), #count {NODE: assign(C_NODE, NODE)} < 2.

% Each compression node must be assigned.
% One could also say each compression node must be assigned twice, but the root constraint already ensures that. It makes it way slower.
:- comp_node(C_NODE, _), not assign(C_NODE, _).


% Now, we need to ensure that if one node of a compression is assigned, the whole tree is assigned. This needs to be down both top-down and bottom-up.

% Then, if a node is assigned, so must be the child.
:- assign(C_NODE, NODE), comp_edge(C_NODE, C_CHILD, ID), edge(NODE, CHILD, ID), not assign(C_CHILD, CHILD).

% Then, if a node is assigned, so must its the parent.
:- assign(C_NODE, NODE), comp_edge(C_PARENT, C_NODE, ID), edge(PARENT, NODE, ID), not assign(C_PARENT, PARENT).



%% ------------------------- Results ---------------------------------

% The following are outputted in order to reconstruct the compression tree
#show comp_root/2.
#show comp_node/2.
#show comp_edge/3.

%% ------------------------- Optimization ---------------------------------

% Maximize assignment
%#maximize {1, X : assign(_, X)}.

% This weak constraint allows us to timeout the search at any point and return the best found solution so far.
:~ assign(_, Y). [-1, Y]
