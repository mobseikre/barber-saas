const COUNTRY_CODE = '218';

export function toInternalEmail(input: string): string | null {
  const digits = input.replace(/\D/g, '');
  const national = digits.startsWith(COUNTRY_CODE) ? digits.slice(COUNTRY_CODE.length) : digits.replace(/^0/, '');
  return /^\d{9}$/.test(national) ? `${COUNTRY_CODE}${national}@app.local` : null;
}

export function formatPhone(phone: string | null | undefined): string {
  if (!phone) return '—';
  const national = phone.startsWith(COUNTRY_CODE) ? phone.slice(COUNTRY_CODE.length) : phone;
  return `+${COUNTRY_CODE} ${national.slice(0, 2)} ${national.slice(2, 5)} ${national.slice(5)}`.trim();
}

export function phoneSearchTerm(query: string): string {
  const digits = query.replace(/\D/g, '');
  return digits.startsWith(COUNTRY_CODE) ? digits : digits.replace(/^0/, '');
}
