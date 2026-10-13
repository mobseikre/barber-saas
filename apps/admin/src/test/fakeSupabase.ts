import { vi } from 'vitest';

type Result = { data: unknown; error: unknown };

export interface FakeSupabase {
  tables: Record<string, unknown[]>;
  rpc: ReturnType<typeof vi.fn<(name: string, args?: Record<string, unknown>) => Promise<Result>>>;
  invoke: ReturnType<typeof vi.fn<(name: string, options?: { body?: unknown }) => Promise<Result>>>;
  queries: { table: string; calls: [string, unknown[]][] }[];
  client: unknown;
}

export function fakeSupabase(tables: Record<string, unknown[]> = {}): FakeSupabase {
  const fake = {
    tables,
    rpc: vi.fn(async () => ({ data: null, error: null }) as Result),
    invoke: vi.fn(async () => ({ data: null, error: null }) as Result),
    queries: [] as FakeSupabase['queries'],
  } as FakeSupabase;

  function from(table: string) {
    const query = { table, calls: [] as [string, unknown[]][] };
    fake.queries.push(query);
    const builder: Record<string, unknown> = new Proxy(
      {},
      {
        get(_, prop: string) {
          if (prop === 'then') {
            const result: Result = { data: fake.tables[table] ?? [], error: null };
            return (resolve: (value: Result) => unknown, reject: (reason: unknown) => unknown) => Promise.resolve(result).then(resolve, reject);
          }
          return (...args: unknown[]) => {
            query.calls.push([prop, args]);
            return builder;
          };
        },
      },
    );
    return builder;
  }

  fake.client = { from, rpc: fake.rpc, functions: { invoke: fake.invoke } };
  return fake;
}
