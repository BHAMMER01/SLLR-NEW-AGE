import type { TufaClass } from './tufa.js';
export declare const OPCODES: readonly ["invalid", "local", "declare", "release", "and_test", "or_test", "type", "expr", "stmt", "str", "float", "int", "null", "bool", "rid", "unused", "end", "path", "name", "invalid", "jump", "jump_false", "jump_true", "case", "pop", "class", "method", "field", "getfield", "unused", "array_init", "push_zeros", "index", "new_init", "this_init", "super_init", "call", "call_on", "call_super", "push_int", "value", "push_void", "ret", "ret_value", "init", "store", "unused", "invalid"];
export declare const TAGS: readonly ["cond", "lor", "land", "bor", "bxor", "band", "ne", "eq", "ge", "le", "gt", "lt", "unused", "shr", "shl", "sub", "add", "mod", "div", "mul", "bnot", "lnot", "neg", "postinc", "postdec", "preinc", "predec", "call", "literal", "unused", "new", "newarray", "instanceof", "cast", "ctor", "assign", "mul_assign", "div_assign", "mod_assign", "add_assign", "sub_assign", "unused", "unused", "unused", "and_assign", "xor_assign", "or_assign"];
export type IrOperand = string | number | {
    owner: string;
    name: string;
    descriptor: string;
} | {
    pack: string;
    id: number;
};
export interface IrInstruction {
    index: number;
    line: number;
    op: number;
    name: string;
    raw?: number;
    operand?: IrOperand;
    target?: number;
}
export interface BasicBlock {
    id: number;
    start: number;
    end: number;
    instructions: IrInstruction[];
    successors: number[];
    predecessors: number[];
}
export interface IrMethod {
    className: string;
    methodName: string;
    descriptor: string;
    treeIndex: number;
    instructions: IrInstruction[];
    blocks: BasicBlock[];
}
export declare function lowerTree(cls: TufaClass, treeIndex: number, methodName?: string, descriptor?: string): IrMethod;
export declare function buildBlocks(instructions: IrInstruction[]): BasicBlock[];
export declare function formatIr(ir: IrMethod): string;
