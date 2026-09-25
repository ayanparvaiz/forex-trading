// The day's reference rates, for the practice market to start from.
//
// The European Central Bank publishes one rate per currency each working
// day, free to reuse, and frankfurter.dev serves them without a key. They
// are not live — the market on the phone moves on its own from there — but
// they put EUR/USD where EUR/USD actually is, instead of where it was when
// the simulator was written.

const SOURCE_URL = 'https://api.frankfurter.dev/v1/latest?base=USD&symbols=EUR,GBP,JPY';
export const SOURCE = 'European Central Bank reference rates, via frankfurter.dev';

// Sanity bounds: a number outside these is a broken feed, not a market.
const BOUNDS = {
  'EUR/USD': [0.5, 2.5],
  'GBP/USD': [0.5, 3],
  'USD/JPY': [50, 400],
};

const round = (v, places) => Math.round(v * 10 ** places) / 10 ** places;

/**
 * The app's pairs from rates quoted against the dollar: how many euros,
 * pounds and yen one dollar buys. A pair whose rate is missing or absurd is
 * left out, and the app keeps the one it had.
 */
export function pairsFromUsdRates(rates) {
  const pairs = {};
  const put = (symbol, value, places) => {
    const [lo, hi] = BOUNDS[symbol];
    if (Number.isFinite(value) && value >= lo && value <= hi) pairs[symbol] = round(value, places);
  };
  if (rates?.EUR > 0) put('EUR/USD', 1 / rates.EUR, 5);
  if (rates?.GBP > 0) put('GBP/USD', 1 / rates.GBP, 5);
  if (rates?.JPY > 0) put('USD/JPY', rates.JPY, 3);
  return pairs;
}

/** Fetches today's rates. Throws if the source is down or says nothing. */
export async function referenceRates(fetchImpl = fetch) {
  const res = await fetchImpl(SOURCE_URL, { headers: { 'user-agent': 'forex-trading-stats-worker' } });
  if (!res.ok) throw new Error(`rates ${res.status}`);
  const body = await res.json();
  const pairs = pairsFromUsdRates(body.rates);
  if (!Object.keys(pairs).length) throw new Error('rates: nothing usable');
  return { date: body.date, source: SOURCE, pairs };
}
