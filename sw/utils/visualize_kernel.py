#!/usr/bin/env python3
import csv
import sys
import re

def visualize_kernel(csv_path, output_dot):
    # Load CSV
    instructions = []
    with open(csv_path, 'r') as f:
        reader = csv.reader(f)
        current_row = []
        for line in reader:
            if not line: continue
            # Check for cycle header
            if len(line) > 0 and line[0].strip().isdigit() and all(not x.strip() for x in line[1:]):
                if current_row:
                    instructions.append(current_row)
                    current_row = []
                continue
            
            # This is a row of instructions
            # Clean up line
            clean_line = [x.strip() for x in line]
            if any(clean_line):
                current_row.append(clean_line)
        
        if current_row:
            instructions.append(current_row)
            
    # Parse and Build Graph
    # Nodes: Cycle_Row_Col
    # Edges based on operands
    
    # Aesthetic settings
    dot_lines = [
        "digraph KernelFlow {",
        "  rankdir=TB;",
        # "  splines=ortho;", # Removed ortho as it causes artifacts with clusters
        "  nodesep=0.5;",
        "  ranksep=0.8;",
        "  node [shape=note, style=filled, fillcolor=white, fontname=\"Helvetica\", penwidth=1.5];",
        "  edge [fontname=\"Helvetica\", fontsize=10];"
    ]
    
    colors = {
        "LWD": "#ffeb3b",
        "SWD": "#ff9800",
        "SWI": "#f44336",
        "ALU": "#e3f2fd",
        "NOP": "#eeeeee"
    }

    # Track nodes for vertical alignment
    last_node_in_col = {} # col_idx -> node_id

    # Create Nodes
    for cycle_idx, cycle_rows in enumerate(instructions):
        dot_lines.append(f"  subgraph cluster_cycle_{cycle_idx} {{")
        dot_lines.append(f"    label=\"Cycle {cycle_idx}\";")
        dot_lines.append(f"    style=dotted; color=grey;")
        
        for row_idx, row_cols in enumerate(cycle_rows):
            for col_idx, instr in enumerate(row_cols):
                if not instr or instr == "NOP": continue
                
                node_id = f"c{cycle_idx}_r{row_idx}_c{col_idx}"
                
                # Determine color
                fill = colors["ALU"]
                if "LWD" in instr: fill = colors["LWD"]
                elif "SWD" in instr: fill = colors["SWD"]
                elif "SWI" in instr: fill = colors["SWI"]
                
                label = f"{instr}\\n(R{row_idx}, C{col_idx})"
                # Add group attribute for vertical alignment
                dot_lines.append(f"    {node_id} [label=\"{label}\", fillcolor=\"{fill}\", group=\"col_{col_idx}\"];")
                
                # Logic for connections
                specs = {
                    "RCT": ((-1, 0), "blue"),
                    "RCB": ((1, 0), "green"),
                    "RCL": ((0, -1), "purple"),
                    "RCR": ((0, 1), "orange")
                }
                
                for key, ((dr, dc), col_color) in specs.items():
                    if key in instr:
                        sr = (row_idx + dr) % 4
                        sc = (col_idx + dc) % 4
                        src_id = f"c{cycle_idx}_r{sr}_c{sc}"
                        dot_lines.append(f"    {src_id} -> {node_id} [label=\"{key}\", color=\"{col_color}\", penwidth=2];")
                            
                # Temporal Dependencies (Registers)
                has_temporal_dep = False
                if any(x in instr for x in ["R0","R1","R2","R3"]):
                    if cycle_idx > 0:
                        prev_id = f"c{cycle_idx-1}_r{row_idx}_c{col_idx}"
                        dot_lines.append(f"    {prev_id} -> {node_id} [label=\"Reg\", style=dashed, color=black];")
                        has_temporal_dep = True
                
                # Enforce Vertical Backbone (Structure & Control Flow)
                if col_idx in last_node_in_col:
                     prev_node = last_node_in_col[col_idx]
                     if has_temporal_dep:
                         # If we already have a Reg dependency, use invisible edge just for alignment weight
                         dot_lines.append(f"    {prev_node} -> {node_id} [style=invis, weight=10];")
                     else:
                         # No data dependency, but execution follows sequentially
                         # Show this flow clearly so detached blocks don't float away
                         dot_lines.append(f"    {prev_node} -> {node_id} [color=\"#aaaaaa\", style=dotted, weight=10];")
                
                last_node_in_col[col_idx] = node_id

                # --- CONTROL FLOW LOGIC ---
                # Detect JUMP / BEQ / BNE / etc.
                # Common format: OP Op1, Op2, Immediate (Target Cycle)
                # Regex to capture the last number
                cf_match = re.search(r"(JUMP|BEQ|BNE|BLT|BGE)\s+[^,]+,\s*[^,]+,\s*(-?\d+)", instr.upper())
                if cf_match:
                    op = cf_match.group(1)
                    target_cycle = int(cf_match.group(2))
                    
                    # Target Node: Same Row/Col in Target Cycle
                    # (Assuming Branch affects PC of this column or global flow mapped strictly)
                    target_id = f"c{target_cycle}_r{row_idx}_c{col_idx}"
                    
                    if op == "JUMP":
                        # Unconditional Jump (Loop back)
                        dot_lines.append(f"    {node_id} -> {target_id} [label=\"Jump\", color=red, penwidth=2, constraint=false];")
                    else:
                        # Conditional Branch
                        dot_lines.append(f"    {node_id} -> {target_id} [label=\"True ({op})\", color=darkred, style=dashed, constraint=false];")
                        # False path is implicit fall-through (next cycle)

        dot_lines.append("  }")

    dot_lines.append("}")
    
    with open(output_dot, 'w') as f:
        f.write("\n".join(dot_lines))
    print(f"Graph written to {output_dot}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: visualize_kernel.py <csv> <output.dot>")
        sys.exit(1)
    visualize_kernel(sys.argv[1], sys.argv[2])
