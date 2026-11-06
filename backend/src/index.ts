import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { initializeDatabase } from './models/database';
import { notificationService } from './services/notifications';
import routes from './api/routes';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.use('/api', routes);

app.get('/', (req, res) => {
  res.json({
    name: 'kv0 Backend API',
    version: '1.0.0',
    endpoints: {
      health: 'GET /api/health',
      users: 'POST /api/users, GET /api/users/:id',
      sleep: 'POST /api/sleep, GET /api/sleep/:userId',
      energy: 'GET /api/energy/:userId',
      journey: 'POST /api/journey, GET /api/journey/:userId',
      dashboard: 'GET /api/dashboard/:userId',
    },
  });
});

initializeDatabase();

notificationService.startScheduler();

app.listen(PORT, () => {
  console.log(`🚀 kv0 Backend API running on http://localhost:${PORT}`);
  console.log(`📊 Database: ${process.env.DATABASE_PATH || './data/kv0.db'}`);
  console.log(`🔔 Notification scheduler: Active`);
});

export default app;
