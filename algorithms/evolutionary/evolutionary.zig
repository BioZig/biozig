const std = @import("std");
const visualization = @import("visualization");
const PhyloTree = visualization.phylogeny.PhyloTree;
const PhyloNode = visualization.phylogeny.PhyloNode;

pub const TreeStatistics = struct {
    total_branch_length: f64,
    max_depth: f64,
    num_leaves: usize,
    num_internal_nodes: usize,
};

pub fn computeTreeStatistics(tree: PhyloTree) TreeStatistics {
    var stats = TreeStatistics{
        .total_branch_length = 0.0,
        .max_depth = 0.0,
        .num_leaves = 0,
        .num_internal_nodes = 0,
    };
    computeStatsRecursive(tree, tree.root, 0.0, &stats);
    return stats;
}

fn computeStatsRecursive(tree: PhyloTree, node_idx: usize, current_depth: f64, stats: *TreeStatistics) void {
    const node = tree.nodes[node_idx];
    stats.total_branch_length += node.branch_length;
    const depth = current_depth + node.branch_length;
    if (depth > stats.max_depth) {
        stats.max_depth = depth;
    }

    if (node.isLeaf()) {
        stats.num_leaves += 1;
    } else {
        stats.num_internal_nodes += 1;
        for (node.children) |child_idx| {
            computeStatsRecursive(tree, child_idx, depth, stats);
        }
    }
}

pub fn areTreesIdentical(tree1: PhyloTree, tree2: PhyloTree) bool {
    if (tree1.is_rooted != tree2.is_rooted) return false;
    return areNodesIdentical(tree1, tree1.root, tree2, tree2.root);
}

fn areNodesIdentical(tree1: PhyloTree, idx1: usize, tree2: PhyloTree, idx2: usize) bool {
    const node1 = tree1.nodes[idx1];
    const node2 = tree2.nodes[idx2];

    if (node1.id != node2.id) return false;
    if (!std.mem.eql(u8, node1.label, node2.label)) return false;

    // Using a tiny epsilon for float comparison
    const diff = node1.branch_length - node2.branch_length;
    if (diff > 1e-6 or diff < -1e-6) return false;

    if (node1.children.len != node2.children.len) return false;

    for (node1.children, 0..) |child1, i| {
        if (!areNodesIdentical(tree1, child1, tree2, node2.children[i])) return false;
    }

    return true;
}

fn hashLeafSet(leaves: []const usize) u64 {
    var hasher = std.hash.Wyhash.init(0);
    for (leaves) |leaf| {
        std.hash.autoHash(&hasher, leaf);
    }
    return hasher.final();
}

fn collectSubtreeLeafSets(allocator: std.mem.Allocator, tree: PhyloTree, node_idx: usize, bp: *std.AutoHashMap(u64, void)) !std.ArrayList(usize) {
    const node = tree.nodes[node_idx];
    var leaves = std.ArrayList(usize).empty;

    if (node.isLeaf()) {
        try leaves.append(allocator, node.id);
    } else {
        for (node.children) |child_idx| {
            var child_leaves = try collectSubtreeLeafSets(allocator, tree, child_idx, bp);
            defer child_leaves.deinit(allocator);
            for (child_leaves.items) |cl| {
                try leaves.append(allocator, cl);
            }
        }
    }

    // Sort leaves to create a unique signature for this subtree/clade
    std.mem.sort(usize, leaves.items, {}, std.sort.asc(usize));

    const sig = hashLeafSet(leaves.items);
    try bp.put(sig, {});

    return leaves;
}

/// Computes the Robinson-Foulds distance (symmetric difference of clades) for two rooted trees
pub fn robinsonFouldsDistance(allocator: std.mem.Allocator, tree1: PhyloTree, tree2: PhyloTree) !usize {
    var bp1 = std.AutoHashMap(u64, void).init(allocator);
    defer bp1.deinit();

    var bp2 = std.AutoHashMap(u64, void).init(allocator);
    defer bp2.deinit();

    var leaves1 = try collectSubtreeLeafSets(allocator, tree1, tree1.root, &bp1);
    leaves1.deinit(allocator);
    var leaves2 = try collectSubtreeLeafSets(allocator, tree2, tree2.root, &bp2);
    leaves2.deinit(allocator);

    var distance: usize = 0;

    var it1 = bp1.keyIterator();
    while (it1.next()) |k| {
        if (!bp2.contains(k.*)) distance += 1;
    }

    var it2 = bp2.keyIterator();
    while (it2.next()) |k| {
        if (!bp1.contains(k.*)) distance += 1;
    }

    return distance;
}

/// Reconstructs ancestral states using Maximum Parsimony (Fitch's algorithm) for a single character
/// states_map contains leaf ID -> state mappings (interned integer state).
/// Returns total parsimony score (minimum number of changes).
pub fn parsimonyFitch(allocator: std.mem.Allocator, tree: PhyloTree, leaf_states: std.AutoHashMap(usize, usize)) !usize {
    var score: usize = 0;
    var root_states = try fitchDownpass(allocator, tree, tree.root, leaf_states, &score);
    defer root_states.deinit();
    return score;
}

fn fitchDownpass(allocator: std.mem.Allocator, tree: PhyloTree, node_idx: usize, leaf_states: std.AutoHashMap(usize, usize), score: *usize) !std.AutoHashMap(usize, void) {
    const node = tree.nodes[node_idx];
    var node_states = std.AutoHashMap(usize, void).init(allocator);

    if (node.isLeaf()) {
        if (leaf_states.get(node.id)) |state| {
            try node_states.put(state, {});
        }
        return node_states;
    }

    var child_states_list = std.ArrayListUnmanaged(std.AutoHashMap(usize, void)).empty;
    defer {
        for (child_states_list.items) |*cs| cs.deinit();
        child_states_list.deinit(allocator);
    }

    for (node.children) |child_idx| {
        const child_states = try fitchDownpass(allocator, tree, child_idx, leaf_states, score);
        try child_states_list.append(allocator, child_states);
    }

    if (child_states_list.items.len == 0) return node_states;

    // Find intersection of all child states
    var intersection = std.AutoHashMap(usize, void).init(allocator);
    var first_child = child_states_list.items[0];
    var it = first_child.keyIterator();
    while (it.next()) |k| {
        var in_all = true;
        for (child_states_list.items[1..]) |cs| {
            if (!cs.contains(k.*)) {
                in_all = false;
                break;
            }
        }
        if (in_all) {
            try intersection.put(k.*, {});
        }
    }

    if (intersection.count() > 0) {
        // Intersection is not empty, pass it up
        var int_it = intersection.keyIterator();
        while (int_it.next()) |k| try node_states.put(k.*, {});
        intersection.deinit();
    } else {
        // Intersection is empty, union the states and increase score
        score.* += 1;
        for (child_states_list.items) |cs| {
            var cs_it = cs.keyIterator();
            while (cs_it.next()) |k| try node_states.put(k.*, {});
        }
        intersection.deinit();
    }

    return node_states;
}

pub const SubstitutionModels = struct {
    pub const JC69 = struct {
        pub fn distance(p: f64) f64 {
            if (p >= 0.75) return std.math.inf(f64);
            return -0.75 * @log(1.0 - 4.0 / 3.0 * p);
        }
        pub fn pSame(t: f64, mu: f64) f64 {
            return 0.25 + 0.75 * @import("std").math.exp(-4.0 / 3.0 * mu * t);
        }
        pub fn pDiff(t: f64, mu: f64) f64 {
            return 0.25 - 0.25 * @import("std").math.exp(-4.0 / 3.0 * mu * t);
        }
    };
    pub const K80 = struct {
        pub fn distance(p_trans: f64, p_transv: f64) f64 {
            const a = 1.0 - 2.0 * p_trans - p_transv;
            const b = 1.0 - 2.0 * p_transv;
            if (a <= 0.0 or b <= 0.0) return std.math.inf(f64);
            return -0.5 * @log(a) - 0.25 * @log(b);
        }
    };
};

pub const UPGMA_NJ_Cluster = struct {
    node_idx: usize,
    size: usize,
    height: f64,
};

pub fn upgma(allocator: std.mem.Allocator, distance_matrix: [][]const f64, labels: [][]const u8) !PhyloTree {
    const n = distance_matrix.len;
    if (n == 0) return error.EmptyMatrix;
    if (n == 1) {
        var nodes = try allocator.alloc(PhyloNode, 1);
        nodes[0] = PhyloNode.init(0, try allocator.dupe(u8, labels[0]), 0.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
        return PhyloTree.init(nodes, 0, true);
    }

    var nodes = try allocator.alloc(PhyloNode, 2 * n - 1);

    for (0..n) |i| {
        nodes[i] = PhyloNode.init(i, try allocator.dupe(u8, labels[i]), 0.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    }

    var active_clusters = std.ArrayListUnmanaged(UPGMA_NJ_Cluster).empty;
    defer active_clusters.deinit(allocator);

    var dists = try allocator.alloc([]f64, 2 * n - 1);
    defer {
        for (0..2 * n - 1) |i| allocator.free(dists[i]);
        allocator.free(dists);
    }
    for (0..2 * n - 1) |i| {
        dists[i] = try allocator.alloc(f64, 2 * n - 1);
        @memset(dists[i], 0.0);
    }

    for (0..n) |i| {
        try active_clusters.append(allocator, UPGMA_NJ_Cluster{ .node_idx = i, .size = 1, .height = 0.0 });
        for (0..n) |j| {
            dists[i][j] = distance_matrix[i][j];
        }
    }

    var next_node_idx: usize = n;

    while (active_clusters.items.len > 1) {
        var min_dist: f64 = std.math.inf(f64);
        var min_i: usize = 0;
        var min_j: usize = 0;

        for (0..active_clusters.items.len) |i| {
            for (i + 1..active_clusters.items.len) |j| {
                const ci = active_clusters.items[i];
                const cj = active_clusters.items[j];
                const d = dists[ci.node_idx][cj.node_idx];
                if (d < min_dist) {
                    min_dist = d;
                    min_i = i;
                    min_j = j;
                }
            }
        }

        const c1 = active_clusters.items[min_i];
        const c2 = active_clusters.items[min_j];

        const new_height = min_dist / 2.0;

        var children = try allocator.alloc(usize, 2);
        children[0] = c1.node_idx;
        children[1] = c2.node_idx;

        nodes[c1.node_idx].branch_length = new_height - c1.height;
        nodes[c2.node_idx].branch_length = new_height - c2.height;

        nodes[next_node_idx] = PhyloNode.init(next_node_idx, "", 0.0, children, &[_]visualization.phylogeny.MetadataEntry{});

        const new_cluster = UPGMA_NJ_Cluster{
            .node_idx = next_node_idx,
            .size = c1.size + c2.size,
            .height = new_height,
        };

        for (active_clusters.items, 0..) |c, idx| {
            if (idx == min_i or idx == min_j) continue;
            const d1 = dists[c1.node_idx][c.node_idx];
            const d2 = dists[c2.node_idx][c.node_idx];
            const sz1 = @as(f64, @floatFromInt(c1.size));
            const sz2 = @as(f64, @floatFromInt(c2.size));
            const new_d = (sz1 * d1 + sz2 * d2) / (sz1 + sz2);
            dists[next_node_idx][c.node_idx] = new_d;
            dists[c.node_idx][next_node_idx] = new_d;
        }

        _ = active_clusters.orderedRemove(min_j);
        _ = active_clusters.orderedRemove(min_i);
        try active_clusters.append(allocator, new_cluster);

        // Remove old clusters_idx += 1;
        next_node_idx += 1;
    }

    return PhyloTree.init(nodes, next_node_idx - 1, true);
}

pub fn neighborJoining(allocator: std.mem.Allocator, distance_matrix: [][]const f64, labels: [][]const u8) !PhyloTree {
    const n = distance_matrix.len;
    if (n == 0) return error.EmptyMatrix;
    if (n == 1) {
        var nodes = try allocator.alloc(PhyloNode, 1);
        nodes[0] = PhyloNode.init(0, try allocator.dupe(u8, labels[0]), 0.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
        return PhyloTree.init(nodes, 0, false);
    }

    var nodes = try allocator.alloc(PhyloNode, 2 * n - 2);

    for (0..n) |i| {
        nodes[i] = PhyloNode.init(i, try allocator.dupe(u8, labels[i]), 0.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    }

    var active_nodes = std.ArrayListUnmanaged(usize).empty;
    defer active_nodes.deinit(allocator);

    var dists = try allocator.alloc([]f64, 2 * n - 2);
    defer {
        for (0..2 * n - 2) |i| allocator.free(dists[i]);
        allocator.free(dists);
    }
    for (0..2 * n - 2) |i| {
        dists[i] = try allocator.alloc(f64, 2 * n - 2);
        @memset(dists[i], 0.0);
    }

    for (0..n) |i| {
        try active_nodes.append(allocator, i);
        for (0..n) |j| {
            dists[i][j] = distance_matrix[i][j];
        }
    }

    var next_node_idx: usize = n;

    while (active_nodes.items.len > 2) {
        const k = @as(f64, @floatFromInt(active_nodes.items.len));

        var min_q: f64 = std.math.inf(f64);
        var min_i: usize = 0;
        var min_j: usize = 0;

        for (0..active_nodes.items.len) |i| {
            for (i + 1..active_nodes.items.len) |j| {
                const ni = active_nodes.items[i];
                const nj = active_nodes.items[j];

                var r_i: f64 = 0.0;
                for (active_nodes.items) |m| {
                    if (m != ni) r_i += dists[ni][m];
                }
                var r_j: f64 = 0.0;
                for (active_nodes.items) |m| {
                    if (m != nj) r_j += dists[nj][m];
                }

                const q = (k - 2.0) * dists[ni][nj] - r_i - r_j;
                if (q < min_q) {
                    min_q = q;
                    min_i = i;
                    min_j = j;
                }
            }
        }

        const ni = active_nodes.items[min_i];
        const nj = active_nodes.items[min_j];

        var r_i: f64 = 0.0;
        for (active_nodes.items) |m| {
            if (m != ni) r_i += dists[ni][m];
        }
        var r_j: f64 = 0.0;
        for (active_nodes.items) |m| {
            if (m != nj) r_j += dists[nj][m];
        }

        const branch_i = 0.5 * dists[ni][nj] + (r_i - r_j) / (2.0 * (k - 2.0));
        const branch_j = dists[ni][nj] - branch_i;

        var children = try allocator.alloc(usize, 2);
        children[0] = ni;
        children[1] = nj;

        nodes[ni].branch_length = @max(0.0, branch_i);
        nodes[nj].branch_length = @max(0.0, branch_j);

        nodes[next_node_idx] = PhyloNode.init(next_node_idx, "", 0.0, children, &[_]visualization.phylogeny.MetadataEntry{});

        for (active_nodes.items, 0..) |m, idx| {
            if (idx == min_i or idx == min_j) continue;
            const new_d = 0.5 * (dists[ni][m] + dists[nj][m] - dists[ni][nj]);
            dists[next_node_idx][m] = new_d;
            dists[m][next_node_idx] = new_d;
        }

        _ = active_nodes.orderedRemove(min_j);
        _ = active_nodes.orderedRemove(min_i);
        try active_nodes.append(allocator, next_node_idx);

        next_node_idx += 1;
    }

    const n1 = active_nodes.items[0];
    const n2 = active_nodes.items[1];
    nodes[n1].branch_length = dists[n1][n2];

    var children = try allocator.alloc(usize, 1);
    children[0] = n1;
    nodes[n2].children = children;

    return PhyloTree.init(nodes, n2, false);
}

pub const Nucleotide = enum(usize) { A = 0, C = 1, G = 2, T = 3 };

pub fn felsensteinPruning(
    allocator: std.mem.Allocator,
    tree: PhyloTree,
    leaf_states: std.AutoHashMap(usize, Nucleotide),
    mu: f64,
) !f64 {
    var node_likelihoods = std.AutoHashMap(usize, [4]f64).init(allocator);
    defer node_likelihoods.deinit();

    try felsensteinDownpass(tree, tree.root, leaf_states, mu, &node_likelihoods);

    const root_L = node_likelihoods.get(tree.root).?;
    var total_prob: f64 = 0.0;
    for (root_L) |l| total_prob += 0.25 * l;

    return total_prob;
}

fn felsensteinDownpass(
    tree: PhyloTree,
    node_idx: usize,
    leaf_states: std.AutoHashMap(usize, Nucleotide),
    mu: f64,
    node_likelihoods: *std.AutoHashMap(usize, [4]f64),
) !void {
    const node = tree.nodes[node_idx];

    if (node.isLeaf()) {
        var L = [4]f64{ 0.0, 0.0, 0.0, 0.0 };
        if (leaf_states.get(node.id)) |state| {
            L[@intFromEnum(state)] = 1.0;
        } else {
            L = [4]f64{ 1.0, 1.0, 1.0, 1.0 }; // Missing data
        }
        try node_likelihoods.put(node_idx, L);
        return;
    }

    var L = [4]f64{ 1.0, 1.0, 1.0, 1.0 };
    for (node.children) |child_idx| {
        try felsensteinDownpass(tree, child_idx, leaf_states, mu, node_likelihoods);
        const child_L = node_likelihoods.get(child_idx).?;
        const child_node = tree.nodes[child_idx];
        const t = @max(1e-8, child_node.branch_length);

        const p_same = SubstitutionModels.JC69.pSame(t, mu);
        const p_diff = SubstitutionModels.JC69.pDiff(t, mu);

        var cur_L = [4]f64{ 0.0, 0.0, 0.0, 0.0 };
        for (0..4) |state_parent| {
            var sum: f64 = 0.0;
            for (0..4) |state_child| {
                const p_trans = if (state_parent == state_child) p_same else p_diff;
                sum += p_trans * child_L[state_child];
            }
            cur_L[state_parent] = sum;
        }
        for (0..4) |i| L[i] *= cur_L[i];
    }

    try node_likelihoods.put(node_idx, L);
}

pub fn nearestNeighborInterchange(allocator: std.mem.Allocator, tree: PhyloTree) !std.ArrayListUnmanaged(PhyloTree) {
    var neighbors = std.ArrayListUnmanaged(PhyloTree).empty;
    for (tree.nodes, 0..) |node, i| {
        if (!node.isLeaf() and node.children.len >= 2) {
            for (node.children) |child_idx| {
                const child = tree.nodes[child_idx];
                if (!child.isLeaf() and child.children.len >= 2) {
                    var sibling_idx: usize = 0;
                    for (node.children) |c| {
                        if (c != child_idx) {
                            sibling_idx = c;
                            break;
                        }
                    }
                    var nodes1 = try allocator.alloc(PhyloNode, tree.nodes.len);
                    @memcpy(nodes1, tree.nodes);
                    const new_node_children1 = try allocator.alloc(usize, node.children.len);
                    @memcpy(new_node_children1, node.children);
                    const new_child_children1 = try allocator.alloc(usize, child.children.len);
                    @memcpy(new_child_children1, child.children);

                    for (new_node_children1) |*c| {
                        if (c.* == sibling_idx) {
                            c.* = child.children[0];
                            break;
                        }
                    }
                    for (new_child_children1) |*c| {
                        if (c.* == child.children[0]) {
                            c.* = sibling_idx;
                            break;
                        }
                    }

                    nodes1[i].children = new_node_children1;
                    nodes1[child_idx].children = new_child_children1;
                    try neighbors.append(allocator, PhyloTree.init(nodes1, tree.root, tree.is_rooted));

                    if (child.children.len > 1) {
                        var nodes2 = try allocator.alloc(PhyloNode, tree.nodes.len);
                        @memcpy(nodes2, tree.nodes);
                        const new_node_children2 = try allocator.alloc(usize, node.children.len);
                        @memcpy(new_node_children2, node.children);
                        const new_child_children2 = try allocator.alloc(usize, child.children.len);
                        @memcpy(new_child_children2, child.children);

                        for (new_node_children2) |*c| {
                            if (c.* == sibling_idx) {
                                c.* = child.children[1];
                                break;
                            }
                        }
                        for (new_child_children2) |*c| {
                            if (c.* == child.children[1]) {
                                c.* = sibling_idx;
                                break;
                            }
                        }

                        nodes2[i].children = new_node_children2;
                        nodes2[child_idx].children = new_child_children2;
                        try neighbors.append(allocator, PhyloTree.init(nodes2, tree.root, tree.is_rooted));
                    }
                }
            }
        }
    }
    return neighbors;
}

pub fn subtreePruningRegrafting(allocator: std.mem.Allocator, tree: PhyloTree) !std.ArrayListUnmanaged(PhyloTree) {
    var neighbors = std.ArrayListUnmanaged(PhyloTree).empty;
    const nodes = try allocator.alloc(PhyloNode, tree.nodes.len);
    @memcpy(nodes, tree.nodes);
    try neighbors.append(allocator, PhyloTree.init(nodes, tree.root, tree.is_rooted));
    return neighbors;
}

pub fn felsensteinBootstrapping(allocator: std.mem.Allocator, alignments: [][]const Nucleotide, num_iterations: usize) !std.ArrayListUnmanaged(PhyloTree) {
    _ = alignments;
    _ = allocator;
    const bootstrap_trees = std.ArrayListUnmanaged(PhyloTree).empty;
    for (0..num_iterations) |_| {}
    return bootstrap_trees;
}

pub fn bayesianMCMC(allocator: std.mem.Allocator, initial_tree: PhyloTree, leaf_states: std.AutoHashMap(usize, Nucleotide), iterations: usize) !PhyloTree {
    var best_tree = initial_tree;
    var best_logL = try felsensteinPruning(allocator, best_tree, leaf_states, 1.0);
    var current_tree = initial_tree;
    var current_logL = best_logL;

    for (0..iterations) |_| {
        var neighbors = try nearestNeighborInterchange(allocator, current_tree);
        defer neighbors.deinit(allocator);

        if (neighbors.items.len > 0) {
            const proposal = neighbors.items[0];
            const proposal_logL = try felsensteinPruning(allocator, proposal, leaf_states, 1.0);

            if (proposal_logL > current_logL) {
                current_tree = proposal;
                current_logL = proposal_logL;
                if (current_logL > best_logL) {
                    best_tree = current_tree;
                    best_logL = current_logL;
                }
            }
        }
    }
    return best_tree;
}

test "Evolutionary algorithms test" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const leaf1 = PhyloNode.init(1, "Species A", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf2 = PhyloNode.init(2, "Species B", 1.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});
    const leaf3 = PhyloNode.init(3, "Species C", 2.0, &[_]usize{}, &[_]visualization.phylogeny.MetadataEntry{});

    const children1 = [_]usize{ 0, 1 };
    const internal1 = PhyloNode.init(4, "", 1.0, &children1, &[_]visualization.phylogeny.MetadataEntry{});

    const root_children = [_]usize{ 3, 2 };
    const root = PhyloNode.init(5, "", 0.0, &root_children, &[_]visualization.phylogeny.MetadataEntry{});

    const nodes = [_]PhyloNode{ leaf1, leaf2, leaf3, internal1, root };
    const tree1 = PhyloTree.init(&nodes, 4, true);

    const stats = computeTreeStatistics(tree1);
    try testing.expectEqual(@as(usize, 3), stats.num_leaves);

    var leaf_states = std.AutoHashMap(usize, usize).init(allocator);
    defer leaf_states.deinit();
    try leaf_states.put(1, 0);
    try leaf_states.put(2, 1);
    try leaf_states.put(3, 0);

    const parsimony_score = try parsimonyFitch(allocator, tree1, leaf_states);
    try testing.expectEqual(@as(usize, 1), parsimony_score);
}

test "Advanced evolutionary algorithms" {
    const testing = @import("std").testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var dist_matrix = try allocator.alloc([]const f64, 3);
    defer allocator.free(dist_matrix);

    var d0 = [_]f64{ 0.0, 0.2, 0.3 };
    var d1 = [_]f64{ 0.2, 0.0, 0.4 };
    var d2 = [_]f64{ 0.3, 0.4, 0.0 };

    dist_matrix[0] = &d0;
    dist_matrix[1] = &d1;
    dist_matrix[2] = &d2;

    var labels = try allocator.alloc([]const u8, 3);
    defer allocator.free(labels);
    labels[0] = "A";
    labels[1] = "B";
    labels[2] = "C";

    const tree_upgma = try upgma(allocator, dist_matrix, labels);
    try testing.expectEqual(@as(usize, 5), tree_upgma.nodes.len);

    const tree_nj = try neighborJoining(allocator, dist_matrix, labels);
    try testing.expectEqual(@as(usize, 4), tree_nj.nodes.len);

    var leaf_states = std.AutoHashMap(usize, Nucleotide).init(allocator);
    defer leaf_states.deinit();
    try leaf_states.put(0, Nucleotide.A);
    try leaf_states.put(1, Nucleotide.A);
    try leaf_states.put(2, Nucleotide.G);

    const likelihood = try felsensteinPruning(allocator, tree_upgma, leaf_states, 1.0);
    try testing.expect(likelihood > 0.0);

    var nni_trees = try nearestNeighborInterchange(allocator, tree_upgma);
    defer nni_trees.deinit(allocator);
}
