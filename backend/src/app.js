import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { ok, fail } from './lib/apiResponse.js';
import authRoutes from './routes/auth.routes.js';
import userRoutes from './routes/user.routes.js';
import runRoutes from './routes/run.routes.js';
import { getRunById } from './controllers/run.controller.js';
import { verifyToken } from './middleware/auth.js';

const app = express();

app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN }));
app.use(morgan('dev'));
app.use(express.json());

app.use('/v1/auth', authRoutes);
app.use('/v1/user', userRoutes);
app.use('/v1/runs', runRoutes);
app.get('/v1/run/:id', verifyToken, getRunById); 

app.get('/v1', (req, res) => {
    ok(res, { message: "LRC Run API sedang berjalan!" });
});

app.use((req, res) => {
    fail(res, 'NOT_FOUND', 'Endpoint tidak ditemukan', 404);
});

app.use((err, req, res, next) => {
    console.error(err.stack);
    fail(res, 'SERVER_ERROR', 'Internal server error', 500);
});

export default app;