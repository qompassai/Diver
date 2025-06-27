// ~/.config/nvim/types/cmp.d.ts
// -----------------------------
// Copyright (C) 2025 Qompass AI, All rights reserved
declare module 'cmp' {
  export const mapping: {
    scroll_docs(delta: number): void;
    complete(): void;
    confirm(opts: { behavior: any; select: boolean }): void;
  };
  
  export const config: {
    sources: (sources: any) => any;
  };
  
  export const ConfirmBehavior: {
    Replace: string;
    Insert: string;
  };
  
  export function visible(): boolean;
  export function select_next_item(): void;
  export function select_prev_item(): void;
}

