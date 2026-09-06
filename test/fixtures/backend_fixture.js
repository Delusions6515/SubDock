const http = require('node:http');

const mode = process.env.TEST_BACKEND_MODE || 'healthy';

console.log('fixture stdout');
console.error('fixture stderr');

if (mode === 'crash') {
  process.exitCode = 1;
} else {
  let keepAlive;
  const server = http.createServer((request, response) => {
    if (request.url !== '/api/utils/env') {
      response.statusCode = 404;
      response.end();
      return;
    }
    response.setHeader('content-type', 'application/json');
    response.end(
      JSON.stringify({
        data: {
          version: 'fixture-backend',
          meta: { node: { version: process.version } },
        },
      }),
    );
  });

  server.listen(process.env.SUB_STORE_BACKEND_API_PORT, '127.0.0.1');
  process.on('SIGTERM', () => {
    clearInterval(keepAlive);
    if (!server.listening) {
      process.exit(0);
      return;
    }
    server.close(() => process.exit(0));
  });

  if (mode === 'unhealthy') {
    setTimeout(() => {
      server.close();
      keepAlive = setInterval(() => {}, 1000);
    }, 100);
  }
}
