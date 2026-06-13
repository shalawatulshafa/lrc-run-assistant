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

// 1. MIDDLEWARE UTAMA (Harus di paling atas)
app.use(helmet());
app.use(cors({ origin: '*' })); 
app.use(morgan('dev'));
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));

// 2. ROUTES
app.get('/v1', (req, res) => {
    ok(res, { message: "LRC Run API sedang berjalan!" });
});

app.use('/v1/auth', authRoutes);
app.use('/v1/user', userRoutes);
app.use('/v1/runs', runRoutes);
app.get('/v1/run/:id', verifyToken, getRunById); 

// 3. ERROR HANDLING (Harus di paling bawah)
app.use((req, res) => {
    fail(res, 'NOT_FOUND', 'Endpoint tidak ditemukan', 404);
});

app.use((err, req, res, next) => {
    console.error("SERVER ERROR:", err.stack);
    fail(res, 'SERVER_ERROR', 'Internal server error', 500);
});

export default app;