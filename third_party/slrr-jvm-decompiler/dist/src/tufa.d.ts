/** TUFA is SLRR's own class format, not JVM bytecode. */
export declare const NONE = 4294967295;
export type Constant = {
    kind: 'utf8';
    text: string;
} | {
    kind: 'resource';
    pack: number;
    id: number;
} | {
    kind: 'class';
    name: number;
} | {
    kind: 'reference';
    owner: number;
    nameAndType: number;
} | {
    kind: 'nameAndType';
    name: number;
    descriptor: number;
};
export interface Member {
    flags: number;
    name: number;
    descriptor: number;
    tree: number;
    locals?: number;
}
export interface TreeNode {
    index: number;
    offset: number;
    op: number;
    line: number;
    immediate?: number;
}
export interface TufaClass {
    build: number;
    constants: Constant[];
    staticFields: Member[];
    instanceFields: Member[];
    staticMethods: Member[];
    instanceMethods: Member[];
    nameIndex: number;
    superIndex: number;
    interfaceIndices: number[];
    isInterface: boolean;
    trees: TreeNode[][];
    utf8(index: number): string;
    className(index: number): string;
    reference(index: number): {
        owner: string;
        name: string;
        descriptor: string;
    };
    resource(index: number): {
        pack: string;
        id: number;
    };
    readonly name: string;
    readonly superName: string | undefined;
}
export declare const OP_FLAGS: readonly [0, 4097, 4098, 4099, 4, 5, 4102, 4103, 4104, 16393, 8202, 4107, 12, 4109, 4110, 4111, 16, 4113, 16402, 19, 4116, 4117, 4118, 4119, 24, 4121, 4122, 4123, 16412, 29, 4126, 4127, 32, 33, 34, 35, 36, 16421, 16422, 4135, 40, 41, 42, 43, 44, 45, 16430, 0];
export declare function parseTufa(input: Uint8Array): TufaClass[];
/** Some mod classes contain an empty own-name constant. Use a known filename as a fallback. */
export declare function recoverMissingClassName(cls: TufaClass, filenameStem: string): boolean;
