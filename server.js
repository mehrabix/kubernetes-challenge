'use strict';

const createApp = require('./src/app');

const port = process.env.PORT || 4000;
const app = createApp();

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
