import { type IrMethod } from './ir.js';
import { type TufaClass } from './tufa.js';
export interface DecompileResult {
    source: string;
    diagnostics: string[];
    intermediate: IrMethod[];
}
export declare function decodeType(descriptor: string): string;
export declare function decodeMethod(descriptor: string): {
    parameters: string[];
    returns: string;
};
export declare function decompileClass(cls: TufaClass): DecompileResult;
