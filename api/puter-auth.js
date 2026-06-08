module.exports = function handler(req, res) {
  const requestedRedirect = typeof req.query?.redirect === 'string' ? req.query.redirect.trim() : '';
  const redirect = requestedRedirect.startsWith('imagestudio://puter-auth')
    ? requestedRedirect
    : 'imagestudio://puter-auth';

  res.setHeader('content-type', 'text/html; charset=utf-8');
  res.status(200).send(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Connect Puter</title>
  <script src="https://js.puter.com/v2/"></script>
  <style>
    :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #05070d; color: white; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: radial-gradient(circle at top, #275ddf55, transparent 35rem), #05070d; }
    main { width: min(28rem, calc(100vw - 2rem)); padding: 1.25rem; border: 1px solid #ffffff24; border-radius: 1.25rem; background: #00000080; box-shadow: 0 1rem 4rem #0008; }
    h1 { margin: 0 0 .5rem; font-size: 1.55rem; }
    p { color: #cbd5e1; line-height: 1.45; }
    button { width: 100%; border: 0; border-radius: .9rem; padding: .95rem 1rem; color: white; background: #2f71f2; font-weight: 700; font-size: 1rem; }
    #status { min-height: 1.5rem; font-size: .9rem; color: #93c5fd; }
  </style>
</head>
<body>
  <main>
    <h1>Connect Puter</h1>
    <p>Connect your Puter session to Image Studio so image generation runs through Puter's user-pays model instead of the shared server token.</p>
    <button id="connect">Connect Puter</button>
    <p id="status"></p>
  </main>
  <script>
    const redirect = ${JSON.stringify(redirect)};
    const status = document.getElementById('status');
    const connect = document.getElementById('connect');

    function appURL(result) {
      const params = new URLSearchParams();
      params.set('token', result.token || '');
      if (result.username) params.set('username', result.username);
      return redirect + '#' + params.toString();
    }

    connect.addEventListener('click', async () => {
      connect.disabled = true;
      status.textContent = 'Opening Puter sign in...';
      try {
        const result = await puter.auth.signIn({ attempt_temp_user_creation: true });
        if (!result || !result.token) throw new Error(result?.error || 'Puter did not return an auth token.');
        status.textContent = 'Returning to Image Studio...';
        window.location.href = appURL(result);
      } catch (error) {
        connect.disabled = false;
        status.textContent = error?.message || 'Could not connect Puter.';
      }
    });
  </script>
</body>
</html>`);
};
