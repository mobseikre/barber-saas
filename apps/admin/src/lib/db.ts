import { SEARCH_MAX_LENGTH } from './constants';

export async function must<T>(query: PromiseLike<{ data: unknown; error: unknown }>): Promise<T> {
  const { data, error } = await query;
  if (error) throw error;
  return data as T;
}

export async function mustCount(query: PromiseLike<{ count: number | null; error: unknown }>): Promise<number> {
  const { count, error } = await query;
  if (error) throw error;
  return count ?? 0;
}

export const searchTerm = (query: string) =>
  Array.from(query.replace(/[\u0000-\u001f]/g, ' ').trim()).slice(0, SEARCH_MAX_LENGTH).join('').trim();

export function containsFilter(column: string, text: string): string {
  const like = text.replace(/[\\%_]/g, (c) => `\\${c}`);
  const quoted = `%${like}%`.replace(/[\\"]/g, (c) => `\\${c}`);
  return `${column}.ilike."${quoted}"`;
}
