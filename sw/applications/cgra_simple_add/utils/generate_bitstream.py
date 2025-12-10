#!/usr/bin/env python3
"""
Complete CSV to CGRA Bitstream Pipeline

Uses HEEPsilon's official cgra_bitstream_gen.py toolchain to generate bitstreams.

Usage:
    python generate_bitstream.py instructions.csv -o cgra_bitstream.h

This script:
1. Converts CSV to instructions_kernel.py format
2. Uses cgra_bitstream_gen.py encoding logic to generate bitstream
3. Outputs cgra_bitstream.h for use in applications

Author: Generated for HEEPsilon project
"""

import argparse
import csv
import re
import os
import sys
from math import ceil, log2
from typing import List, Tuple, Optional

# =============================================================================
# CGRA Configuration (mirrored from cgra_bitstream_gen.py)
# =============================================================================

CGRA_N_COL = 4
CGRA_N_ROW = 4
CGRA_MAX_COL = 4

RCS_NUM_CREG = 32
RCS_NUM_CREG_LOG2 = int(ceil(log2(RCS_NUM_CREG)))

CGRA_CMEM_BK_DEPTH = 128
CGRA_CMEM_BK_DEPTH_LOG2 = int(ceil(log2(CGRA_CMEM_BK_DEPTH)))

CGRA_KMEM_DEPTH = 16
CGRA_KMEM_WIDTH = CGRA_MAX_COL + CGRA_CMEM_BK_DEPTH_LOG2 + RCS_NUM_CREG_LOG2

# Instruction encoding (from cgra_bitstream_gen.py)
RCS_MUXA_BITS = 4
RCS_MUXB_BITS = 4
RCS_ALU_OP_BITS = 5
RCS_RF_WADD_BITS = 2
RCS_RF_WE_BITS = 1
RCS_MUXFLAG_BITS = 3
RCS_IMM_BITS = 13

CGRA_CMEM_WIDTH = RCS_MUXA_BITS + RCS_MUXB_BITS + RCS_ALU_OP_BITS + RCS_RF_WADD_BITS + RCS_RF_WE_BITS + RCS_MUXFLAG_BITS + RCS_IMM_BITS

# Encoding lists (from cgra_bitstream_gen.py)
muxA_list = ['ZERO', 'SELF', 'RCL', 'RCR', 'RCT', 'RCB', 'R0', 'R1', 'R2', 'R3', 'IMM']
muxB_list = ['ZERO', 'SELF', 'RCL', 'RCR', 'RCT', 'RCB', 'R0', 'R1', 'R2', 'R3', 'IMM']

ALU_op_list = ['NOP',
               'SADD', 'SSUB', 'SMUL', 'FXPMUL',
               'SLT', 'SRT', 'SRA',
               'LAND', 'LOR', 'LXOR', 'LNAND', 'LNOR', 'LXNOR',
               'BSFA', 'BZFA',
               'BEQ', 'BNE', 'BLT', 'BGE', 'JUMP',
               'LWD', 'SWD', 'LWI', 'SWI',
               'EXIT']

reg_dest_list = ['R0', 'R1', 'R2', 'R3']
reg_we_list = ['0', '1']
muxF_list = ['SELF', 'RCL', 'RCR', 'RCT', 'RCB']

rcs_nop_instr = ['ZERO', 'ZERO', 'NOP', '-', 'SELF', '0']

# =============================================================================
# Utility functions (from cgra_bitstream_gen.py)
# =============================================================================

def get_bin(x, n=0):
    return format(x, 'b').zfill(n)

def int2bin(x, bits):
    s = bin(x & int("1" * bits, 2))[2:]
    return ("{0:0>%s}" % bits).format(s)

def return_indices_of_a(a, b, name=''):
    for val in a:
        if b == val:
            return a.index(val)
    sys.exit(f"ERROR: '{b}' not in {name}")

# =============================================================================
# CSV Parsing
# =============================================================================

def parse_instruction_string(instr_str: str) -> List[str]:
    """Convert instruction string to EPFL format list."""
    instr_str = instr_str.strip().strip('"')
    
    if not instr_str or instr_str.upper() == 'NOP':
        return rcs_nop_instr.copy()
    
    if instr_str.upper() == 'EXIT':
        return ['-', '-', 'EXIT', '-', '-', '-']
    
    parts = re.split(r'[\s,]+', instr_str)
    parts = [p.strip() for p in parts if p.strip()]
    
    if not parts:
        return rcs_nop_instr.copy()
    
    op = parts[0].upper()
    mux_sources = ['ZERO', 'SELF', 'RCL', 'RCR', 'RCT', 'RCB', 'R0', 'R1', 'R2', 'R3', 'IMM', 'ROUT']
    
    def is_number(s):
        try:
            int(s)
            return True
        except ValueError:
            return False
    
    # LWD/SWD
    if op in ['LWD', 'SWD']:
        reg = parts[1].upper() if len(parts) > 1 else '-'
        inc = parts[2] if len(parts) > 2 else '4'
        if op == 'LWD':
            return ['-', '-', 'LWD', reg, '-', inc]
        else:
            src = reg if reg != 'ROUT' else 'SELF'
            return [src, '-', 'SWD', '-', '-', inc]
    
    # LWI/SWI
    if op in ['LWI', 'SWI']:
        if op == 'LWI':
            dest = parts[1].upper() if len(parts) > 1 else '-'
            src = parts[2].upper() if len(parts) > 2 else '-'
            return ['-', src, 'LWI', dest, '-', '-']
        else:
            src = parts[1].upper() if len(parts) > 1 else '-'
            addr = parts[2].upper() if len(parts) > 2 else '-'
            if src == 'ROUT':
                src = 'SELF'
            return [src, addr, 'SWI', '-', '-', '-']
    
    # Branch
    if op in ['BEQ', 'BNE', 'BLT', 'BGE']:
        mux_a = parts[1].upper() if len(parts) > 1 else '-'
        mux_b = parts[2] if len(parts) > 2 else '-'
        imm = parts[3] if len(parts) > 3 else '-'
        if is_number(mux_b):
            return [mux_a, 'IMM', op, '-', '-', imm]
        return [mux_a, mux_b.upper(), op, '-', '-', imm]
    
    # JUMP
    if op == 'JUMP':
        imm = parts[1] if len(parts) > 1 else '-'
        return ['-', '-', 'JUMP', '-', '-', imm]
    
    # Arithmetic: OP dest, srcA, srcB
    if len(parts) >= 4:
        dest = parts[1].upper()
        src_a = parts[2].upper()
        src_b = parts[3].upper() if len(parts) > 3 else '-'
        
        reg_dest = dest if dest in reg_dest_list else '-'
        if src_a == 'ROUT': src_a = 'SELF'
        if src_b == 'ROUT': src_b = 'SELF'
        
        imm = '-'
        if src_a not in mux_sources and is_number(src_a):
            imm = src_a
            src_a = 'IMM'
        if src_b not in mux_sources and is_number(src_b):
            imm = src_b
            src_b = 'IMM'
        
        return [src_a, src_b, op, reg_dest, '-', imm]
    
    # 3-operand
    if len(parts) == 3:
        dest = parts[1].upper()
        src = parts[2].upper()
        reg_dest = dest if dest in reg_dest_list else '-'
        if src == 'ROUT': src = 'SELF'
        return [src, 'ZERO', op, reg_dest, '-', '-']
    
    return rcs_nop_instr.copy()


def parse_csv(csv_path: str) -> Tuple[int, List[List[List[str]]]]:
    """Parse CSV and return (num_cycles, instructions[row][col][cycle])."""
    instructions = [[[] for _ in range(CGRA_N_COL)] for _ in range(CGRA_N_ROW)]
    
    current_cycle = 0
    row_in_cycle = 0
    max_cycle = 0
    
    with open(csv_path, 'r') as f:
        reader = csv.reader(f)
        for line in reader:
            if not line or all(not cell.strip() for cell in line):
                continue
            
            first_cell = line[0].strip().strip('"')
            if first_cell.isdigit() and all(not cell.strip() for cell in line[1:]):
                current_cycle = int(first_cell)
                max_cycle = max(max_cycle, current_cycle)
                row_in_cycle = 0
                continue
            
            if row_in_cycle < CGRA_N_ROW:
                for col in range(min(len(line), CGRA_N_COL)):
                    while len(instructions[row_in_cycle][col]) < current_cycle:
                        instructions[row_in_cycle][col].append(rcs_nop_instr.copy())
                    
                    instr = parse_instruction_string(line[col])
                    if len(instructions[row_in_cycle][col]) == current_cycle:
                        instructions[row_in_cycle][col].append(instr)
                    else:
                        instructions[row_in_cycle][col][current_cycle] = instr
                
                row_in_cycle += 1
    
    return max_cycle + 1, instructions


def parse_memory_csv(memory_path: str) -> Tuple[int, List[Tuple[int, int]]]:
    """Parse memory.csv."""
    entries = []
    base_addr = None
    
    with open(memory_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            addr = int(row['Address'].strip())
            data = int(row['Data'].strip())
            if base_addr is None:
                base_addr = addr
            entries.append((addr, data))
    
    if base_addr is None:
        return 0, []
    return base_addr, [(addr - base_addr, data) for addr, data in entries]


# =============================================================================
# Bitstream Encoding (using cgra_bitstream_gen.py logic)
# =============================================================================

def encode_instruction(instruction: List[str]) -> int:
    """Encode instruction list to 32-bit word using official encoding."""
    instr_bits = ""
    
    for idx in range(len(instruction)):
        cmd = instruction[idx]
        
        # Don't care replaced by default
        if cmd == '-':
            cmd = rcs_nop_instr[idx]
        
        # Handle register destination + write enable
        if idx == 3:
            cmd_tmp = ['R0', '0']
            if cmd != '-' and cmd in reg_dest_list:
                cmd_tmp[0] = cmd
                cmd_tmp[1] = '1'
            cmd = cmd_tmp
        
        if idx == 0:
            instr_bits += get_bin(return_indices_of_a(muxA_list, cmd, 'muxA'), RCS_MUXA_BITS)
        elif idx == 1:
            instr_bits += get_bin(return_indices_of_a(muxB_list, cmd, 'muxB'), RCS_MUXB_BITS)
        elif idx == 2:
            instr_bits += get_bin(return_indices_of_a(ALU_op_list, cmd, 'ALU_op'), RCS_ALU_OP_BITS)
        elif idx == 3:
            instr_bits += get_bin(return_indices_of_a(reg_dest_list, cmd[0], 'reg_dest'), RCS_RF_WADD_BITS)
            instr_bits += get_bin(return_indices_of_a(reg_we_list, cmd[1], 'reg_we'), RCS_RF_WE_BITS)
        elif idx == 4:
            instr_bits += get_bin(return_indices_of_a(muxF_list, cmd, 'muxF'), RCS_MUXFLAG_BITS)
        elif idx == 5:
            imm_val = 0 if cmd == '-' or cmd == '' else int(cmd)
            instr_bits += int2bin(imm_val, RCS_IMM_BITS)
    
    return int(instr_bits, 2)


def generate_bitstream(num_instr: int, instructions: List[List[List[str]]],
                       kernel_name: str = "CGRA_KERNEL",
                       memory_data: Optional[Tuple[int, List[Tuple[int, int]]]] = None) -> str:
    """Generate cgra_bitstream.h using official encoding."""
    
    # Pad to same length
    for row in range(CGRA_N_ROW):
        for col in range(CGRA_N_COL):
            while len(instructions[row][col]) < num_instr:
                instructions[row][col].append(rcs_nop_instr.copy())
    
    # Determine columns used
    cols_used = set()
    for row in range(CGRA_N_ROW):
        for col in range(CGRA_N_COL):
            for instr in instructions[row][col]:
                if instr != rcs_nop_instr:
                    cols_used.add(col)
                    break
    
    ker_col_needed = max(cols_used) + 1 if cols_used else 1
    ker_num_instr = num_instr
    ker_start_add = 0
    
    # Generate kmem (official format)
    cols_bitmask = int(pow(2, ker_col_needed)) - 1
    kmem_bits = get_bin(cols_bitmask, CGRA_N_COL) + \
                get_bin(ker_start_add, CGRA_CMEM_BK_DEPTH_LOG2) + \
                get_bin(ker_num_instr - 1, RCS_NUM_CREG_LOG2)
    kmem_word = int(kmem_bits, 2)
    
    kmem = [0] * CGRA_KMEM_DEPTH
    kmem[1] = kmem_word
    
    # Generate cmem (official layout)
    nop_encoded = encode_instruction(rcs_nop_instr)
    rcs_instructions = [[nop_encoded for _ in range(CGRA_CMEM_BK_DEPTH)] for _ in range(CGRA_N_ROW)]
    
    k = ker_num_instr
    for row in range(CGRA_N_ROW):
        for col in range(ker_col_needed):
            for instr_idx in range(ker_num_instr):
                addr = ker_start_add + col * k + instr_idx
                if addr < CGRA_CMEM_BK_DEPTH and instr_idx < len(instructions[row][col]):
                    rcs_instructions[row][addr] = encode_instruction(instructions[row][col][instr_idx])
    
    # Flatten cmem
    cmem = []
    for row in range(CGRA_N_ROW):
        cmem.extend(rcs_instructions[row])
    
    # Generate header
    header = f"""#ifndef _CGRA_BITSTREAM_H_
#define _CGRA_BITSTREAM_H_

#include <stdint.h>

#include "cgra.h"

// Kernel ID (0 is always NULL)
#define {kernel_name} 1

// Kernel configuration (kmem)
uint32_t cgra_kmem_bitstream[CGRA_KMEM_DEPTH] = {{
  {', '.join(f'0x{x:x}' for x in kmem)}
}};

// Instruction memory (cmem)
uint32_t cgra_cmem_bitstream[CGRA_CMEM_TOT_DEPTH] = {{
"""
    
    for i in range(0, len(cmem), 8):
        chunk = cmem[i:i+8]
        header += "  " + ", ".join(f"0x{x:x}" for x in chunk) + ",\n"
    
    header = header.rstrip(",\n") + "\n};\n"
    
    # Memory init
    if memory_data:
        base_addr, entries = memory_data
        if entries:
            data_values = [val for off, val in sorted(entries)]
            header += f"""
// Memory initialization data (from memory.csv)
// Original base address: {base_addr} (0x{base_addr:x})
#define CGRA_MEM_INIT_SIZE {len(data_values)}
int32_t cgra_mem_init[CGRA_MEM_INIT_SIZE] = {{
  {', '.join(str(v) for v in data_values)}
}};
"""
    
    header += "\n#endif // _CGRA_BITSTREAM_H_\n"
    return header


def main():
    parser = argparse.ArgumentParser(
        description='Generate CGRA bitstream using HEEPsilon toolchain encoding'
    )
    parser.add_argument('input', help='Input CSV file (instructions.csv)')
    parser.add_argument('-m', '--memory', default=None, help='Optional memory.csv')
    parser.add_argument('-o', '--output', default='cgra_bitstream.h', help='Output header')
    parser.add_argument('-n', '--name', default='CGRA_KERNEL', help='Kernel name')
    
    args = parser.parse_args()
    
    print(f"Parsing {args.input}...")
    num_instr, instructions = parse_csv(args.input)
    
    memory_data = None
    if args.memory:
        print(f"Parsing memory file {args.memory}...")
        memory_data = parse_memory_csv(args.memory)
        print(f"  Base address: {memory_data[0]} (0x{memory_data[0]:x})")
        print(f"  {len(memory_data[1])} data entries")
    
    print(f"Generating bitstream using HEEPsilon encoding...")
    header = generate_bitstream(num_instr, instructions, args.name, memory_data)
    
    with open(args.output, 'w') as f:
        f.write(header)
    
    print(f"Written to {args.output}")
    print(f"Kernel depth: {num_instr} instructions")
    print(f"CGRA size: {CGRA_N_ROW}x{CGRA_N_COL}")


if __name__ == '__main__':
    main()
