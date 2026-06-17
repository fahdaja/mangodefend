module.exports = {
  apps: [
    {
      name: 'mangodefend-api',
      script: 'dist/main.js',
      exec_mode: 'fork',
      instances: 1,
      env: {
        NODE_ENV: 'production',
      },
    },
  ],
};

