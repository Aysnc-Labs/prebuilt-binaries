import { Pool, neonConfig } from '@neondatabase/serverless';
import ws from 'ws';

const proxy = process.env.PROXY ?? 'localhost:4444';
const port = process.env.PGPORT ?? '5432';
neonConfig.webSocketConstructor = ws;
neonConfig.useSecureWebSocket = false;
neonConfig.wsProxy = () => `${proxy}/v2`;

for (const db of ['alpha', 'beta']) {
  const pool = new Pool({
    connectionString: `postgres://postgres:postgres@localhost:${port}/${db}?options=endpoint%3Dlocal`,
  });
  const { rows } = await pool.query('select current_database() as db, name from t');
  if (rows.length !== 1 || rows[0].db !== db || rows[0].name !== `${db} row`) {
    throw new Error(`unexpected rows from ${db}: ${JSON.stringify(rows)}`);
  }
  console.log(JSON.stringify(rows));
  await pool.end();
}
