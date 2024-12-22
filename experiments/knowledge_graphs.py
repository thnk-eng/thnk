import numpy as np
import networkx as nx
from sklearn.mixture import GaussianMixture
from typing import List, Tuple, Dict, Optional
from collections import defaultdict
import time

class DynamicGraphGMM:
    def __init__(self, n_components: int, time_window: int = 5,
                 decay_factor: float = 0.9):
        """
        Initialize Dynamic Graph-Enhanced GMM.

        Args:
            n_components: Number of Gaussian components
            time_window: Number of time steps to consider for temporal features
            decay_factor: Weight decay for older graph features (0-1)
        """
        self.gmm = GaussianMixture(n_components=n_components)
        self.graph = nx.Graph()
        self.time_window = time_window
        self.decay_factor = decay_factor

        # Store temporal information
        self.edge_timestamps: Dict[Tuple, List[float]] = defaultdict(list)
        self.node_features_history: Dict[int, List[Tuple[float, np.ndarray]]] = defaultdict(list)
        self.last_update_time = time.time()

    def update_graph(self, new_edges: List[Tuple],
                    removed_edges: Optional[List[Tuple]] = None,
                    current_time: Optional[float] = None):
        """
        Update graph structure with new/removed edges.

        Args:
            new_edges: List of (source, target) edges to add
            removed_edges: List of (source, target) edges to remove
            current_time: Current timestamp (defaults to system time)
        """
        if current_time is None:
            current_time = time.time()

        # Add new edges
        for edge in new_edges:
            self.graph.add_edge(*edge)
            self.edge_timestamps[edge].append(current_time)

        # Remove old edges
        if removed_edges:
            for edge in removed_edges:
                if self.graph.has_edge(*edge):
                    self.graph.remove_edge(*edge)

        # Update temporal features
        self._update_temporal_features(current_time)

    def _update_temporal_features(self, current_time: float):
        """Update temporal features for all nodes."""
        for node in self.graph.nodes():
            features = self._compute_node_temporal_features(node, current_time)
            self.node_features_history[node].append((current_time, features))

            # Remove features older than time window
            cutoff_time = current_time - self.time_window
            self.node_features_history[node] = [
                (t, f) for t, f in self.node_features_history[node]
                if t > cutoff_time
            ]

    def _compute_node_temporal_features(self, node: int,
                                      current_time: float) -> np.ndarray:
        """
        Compute temporal features for a node.

        Returns:
            Array of temporal features including:
            - Recent degree changes
            - Edge addition rate
            - Community stability
        """
        # Calculate recent degree changes
        recent_degrees = []
        for t in np.linspace(current_time - self.time_window,
                           current_time, 5):
            degree = sum(1 for edge in self.edge_timestamps
                        if node in edge and any(ts <= t for ts in
                                              self.edge_timestamps[edge]))
            recent_degrees.append(degree)

        degree_changes = np.diff(recent_degrees)

        # Calculate edge addition rate
        recent_edges = sum(1 for edge in self.edge_timestamps
                         if node in edge and any(t > current_time - self.time_window
                                               for t in self.edge_timestamps[edge]))
        edge_rate = recent_edges / self.time_window

        # Calculate local community stability
        community_changes = self._compute_community_stability(node, current_time)

        return np.concatenate([
            degree_changes,
            [edge_rate],
            [community_changes]
        ])

    def _compute_community_stability(self, node: int,
                                   current_time: float) -> float:
        """
        Compute stability of node's local community over time.

        Returns:
            Stability score (0-1) where 1 is most stable
        """
        # Get current neighbors
        current_neighbors = set(self.graph.neighbors(node))

        # Compare with previous neighbor sets
        stability_scores = []
        for t in np.linspace(current_time - self.time_window,
                           current_time - 0.1, 5):
            past_neighbors = set(n for n in self.graph.nodes()
                               if any(edge in self.edge_timestamps and
                                    any(ts <= t for ts in self.edge_timestamps[edge])
                                    for edge in self.graph.edges(node)))

            if past_neighbors:
                jaccard = len(current_neighbors & past_neighbors) / \
                         len(current_neighbors | past_neighbors)
                stability_scores.append(jaccard)

        return np.mean(stability_scores) if stability_scores else 1.0

    def fit(self, X: np.ndarray, initial_edges: List[Tuple]):
        """
        Fit the model with initial data and graph structure.

        Args:
            X: Feature matrix
            initial_edges: Initial graph edges
        """
        self.update_graph(initial_edges)

        # Combine features with graph structure
        enhanced_features = self._combine_features(X)

        # Fit GMM
        self.gmm.fit(enhanced_features)

    def predict(self, X: np.ndarray,
                new_edges: Optional[List[Tuple]] = None) -> np.ndarray:
        """
        Predict cluster assignments for new data.

        Args:
            X: Feature matrix
            new_edges: Optional new edges to update graph

        Returns:
            Array of cluster assignments
        """
        if new_edges:
            self.update_graph(new_edges)

        enhanced_features = self._combine_features(X)
        return self.gmm.predict(enhanced_features)

    def _combine_features(self, X: np.ndarray) -> np.ndarray:
        """Combine input features with graph features."""
        current_time = time.time()

        # Compute graph features for all nodes
        graph_features = []
        for i in range(len(X)):
            # Static graph features
            static_features = [
                self.graph.degree(i),
                nx.clustering(self.graph, i) if self.graph.degree(i) > 1 else 0,
                nx.pagerank(self.graph)[i]
            ]

            # Temporal features
            temporal_features = self._compute_node_temporal_features(i, current_time)

            # Combine features
            node_features = np.concatenate([static_features, temporal_features])
            graph_features.append(node_features)

        graph_features = np.array(graph_features)

        # Apply temporal decay to older features
        time_diff = current_time - self.last_update_time
        decay = self.decay_factor ** time_diff
        graph_features *= decay

        # Combine with input features
        return np.hstack([X, graph_features])

# Example usage
def example_dynamic_usage():
    # Initialize model
    model = DynamicGraphGMM(n_components=3, time_window=5)

    # Initial data
    X = np.random.randn(100, 2)  # Initial features
    initial_edges = [(i, i+1) for i in range(99)]  # Initial edges

    # Fit model
    model.fit(X, initial_edges)

    # Simulate evolving graph
    for t in range(5):
        # New data points
        X_new = np.random.randn(10, 2)

        # New edges
        new_edges = [(100+t*10+i, 100+t*10+i+1) for i in range(9)]

        # Update and predict
        predictions = model.predict(X_new, new_edges)
        print(f"Time step {t}, predictions shape:", predictions.shape)

if __name__ == "__main__":
    example_dynamic_usage()