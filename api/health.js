module.exports = function handler(_req, res) {
  res.setHeader('content-type', 'application/json; charset=utf-8');
  res.status(200).json({
    ok: true,
    hasToken: Boolean(process.env.PUTER_AUTH_TOKEN),
  });
};
