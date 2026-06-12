const convertPatternId = (id) => {
    const map = { 0: "3:2", 1: "2:1", 2: "2:2", 3: "3:3", 4: "4:4", 5: "4:3", 6: "1:1" };
    return map[id] || "3:2";
};

const mapPatternToY = (patternStr) => {
    const mapping = { "4:4": 7, "4:3": 6, "3:3": 5, "3:2": 4, "2:2": 3, "2:1": 2, "1:1": 1 };
    return mapping[patternStr] || 4;
};

const detectActualPattern = (inSteps, exSteps) => {
    const ratio = inSteps / (exSteps || 1);
    if (ratio >= 1.8) return "2:1";
    if (ratio >= 1.3) return "3:2";
    if (inSteps === exSteps) {
        if (inSteps >= 4) return "4:4";
        if (inSteps === 3) return "3:3";
        if (inSteps === 2) return "2:2";
        return "1:1";
    }
    return `${inSteps}:${exSteps}`;
};

const parsePattern = (patternStr) => {
    const parts = patternStr.split(':');
    return {
        N: parseInt(parts[0], 10) || 0,
        M: parseInt(parts[1], 10) || 0,
    };
};

const CSV_HEADER = 'sesi,mulai_lari,waktu_ms,breathPhase,step,spm,patternID';


const detectFormat = (rawData) => {
    const lines = rawData.split(/[\n;]/);
    for (const line of lines) {
        if (line.toLowerCase().includes('sesi')) continue;
        const parts = line.split(',');
        if (parts.length < 8) continue;
        const breathPhase = parseInt(parts[4], 10);
        const step = parseInt(parts[5], 10);
        if (step === 0 && (breathPhase === 1 || breathPhase === -1)) {
            return 'new';
        }
    }
    return 'old';
};

const analyzeOldFormat = (rawData) => {
    const rawLines = rawData.split(/[\n;]/).filter(row => row.trim() !== '');
    const sessionsMap = {};

    rawLines.forEach(line => {
        if (line.toLowerCase().includes('sesi') || line.includes('EOF')) return;

        const parts = line.split(',');
        if (parts.length < 8) return;

        const sessionId = parts[0].trim();
        const rawDate = `${parts[1].replace(/"/g, '').trim()}, ${parts[2].replace(/"/g, '').trim()}`;
        const timestamp = parseInt(parts[3]);
        const breathPhase = parseInt(parts[4]);
        const step = parseInt(parts[5]);
        const spm = parseFloat(parts[6]);
        const patternID = parseInt(parts[7]);

        if (!sessionsMap[sessionId]) {
            sessionsMap[sessionId] = {
                startDate: rawDate,
                spmSum: 0,
                spmCount: 0,
                startTime: timestamp,
                endTime: timestamp,
                currentPhase: null,
                currentInhaleSteps: 0,
                currentExhaleSteps: 0,
                cycleStartPatternId: null,
                cycles: [],
                targetPatternsUsed: new Set(),
                rawLines: []
            };
        }

        const session = sessionsMap[sessionId];
        session.rawLines.push(line);
        session.endTime = Math.max(session.endTime, timestamp);
        session.targetPatternsUsed.add(patternID);

        if (!isNaN(spm) && spm > 0) {
            session.spmSum += spm;
            session.spmCount++;
        }

        if (breathPhase === 1) {
            if (session.currentPhase === 'EX') {
                if (session.currentInhaleSteps > 0 || session.currentExhaleSteps > 0) {
                    session.cycles.push({
                        in: session.currentInhaleSteps,
                        ex: session.currentExhaleSteps,
                        activeTargetPatternId: session.cycleStartPatternId !== null ? session.cycleStartPatternId : patternID
                    });
                }
                session.currentInhaleSteps = 0;
                session.currentExhaleSteps = 0;
                session.cycleStartPatternId = patternID;
            } else if (session.currentPhase === null) {
                session.cycleStartPatternId = patternID;
            }
            session.currentPhase = 'IN';
        }
        else if (breathPhase === -1) {
            session.currentPhase = 'EX';
        }

        if (step === 1) {
            if (session.currentPhase === 'IN') session.currentInhaleSteps++;
            else if (session.currentPhase === 'EX') session.currentExhaleSteps++;
        }
    });

    const analyzedSessions = [];

    for (const [sessionId, session] of Object.entries(sessionsMap)) {
        const durationMs = session.endTime - session.startTime;
        const durationSeconds = Math.max(0, Math.floor(durationMs / 1000));
        const minutes = Math.floor(durationSeconds / 60);
        const seconds = durationSeconds % 60;
        const formattedDuration = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;

        let matchCount = 0;
        let totalCycles = 0;
        const graphDataPoints = [];

        const averagesMap = {};
        session.targetPatternsUsed.forEach(id => {
            const targetPatternStr = convertPatternId(id);
            averagesMap[targetPatternStr] = { inSum: 0, exSum: 0, count: 0 };
        });

        session.cycles.forEach(cycle => {
            const actualPattern = detectActualPattern(cycle.in, cycle.ex);
            const targetPatternStr = convertPatternId(cycle.activeTargetPatternId);
            const targetParts = targetPatternStr.split(':');
            const targetIn = parseInt(targetParts[0], 10);
            const targetEx = parseInt(targetParts[1], 10);
            if (cycle.in === targetIn && cycle.ex === targetEx) {
                matchCount++;
            }
            totalCycles++;

            if (!averagesMap[targetPatternStr]) {
                averagesMap[targetPatternStr] = { inSum: 0, exSum: 0, count: 0 };
            }
            averagesMap[targetPatternStr].inSum += cycle.in;
            averagesMap[targetPatternStr].exSum += cycle.ex;
            averagesMap[targetPatternStr].count++;

            graphDataPoints.push({
                y: mapPatternToY(actualPattern),
                targetPattern: targetPatternStr,
                actualPattern: actualPattern,
            });
        });

        const compliance = totalCycles > 0 ? Math.round((matchCount / totalCycles) * 100) : 0;

        const finalAvgLrcObj = {};
        for (const [patt, stats] of Object.entries(averagesMap)) {
            if (stats.count > 0) {
                const avgIn = (stats.inSum / stats.count).toFixed(1);
                const avgEx = (stats.exSum / stats.count).toFixed(1);
                finalAvgLrcObj[patt] = `${avgIn} : ${avgEx}`;
            } else {
                finalAvgLrcObj[patt] = "0.0 : 0.0";
            }
        }
        const avgLrcJsonString = JSON.stringify(finalAvgLrcObj);

        const finalGraphData = [];
        for (let i = 0; i < graphDataPoints.length; i++) {
            let sumY = 0;
            let count = 0;
            for (let j = Math.max(0, i - 1); j <= Math.min(graphDataPoints.length - 1, i + 1); j++) {
                sumY += graphDataPoints[j].y;
                count++;
            }
            finalGraphData.push({
                y: parseFloat((sumY / count).toFixed(2)),
                pattern: graphDataPoints[i].targetPattern,
                actualPattern: graphDataPoints[i].actualPattern,
            });
        }

        const patternsArray = Array.from(session.targetPatternsUsed).map(id => convertPatternId(id));
        const sessionTargetPatternStr = patternsArray.join(" & ");

        const rawCsvForSession = session.rawLines.length > 0
            ? `${CSV_HEADER}\n${session.rawLines.join('\n')}`
            : null;

        analyzedSessions.push({
            sessionNumber: parseInt(sessionId),
            startDate: session.startDate,
            targetPattern: sessionTargetPatternStr,
            duration: formattedDuration,
            avgSpm: session.spmCount > 0 ? Math.round(session.spmSum / session.spmCount) : 0,
            compliance: compliance,
            avgLrc: avgLrcJsonString,
            rawLrcData: finalGraphData,
            rawCsv: rawCsvForSession,
            // Metrik baru tidak tersedia untuk format lama
            avgLag: null,
            phaseDrift: null,
            consistencyScore: null,
        });
    }

    return analyzedSessions;
};

const TOLERANCE_MS = 50;
const DEBOUNCE_MS = 100;

const analyzeNewFormat = (rawData) => {
    const rawLines = rawData.split(/[\n;]/).filter(row => row.trim() !== '');
    const sessionsMap = {};

    // ---- Pass 1: Parse rows ke sessions ----
    rawLines.forEach(line => {
        if (line.toLowerCase().includes('sesi') || line.includes('EOF')) return;

        const parts = line.split(',');
        if (parts.length < 8) return;

        const sessionId = parts[0].trim();
        const rawDate = `${parts[1].replace(/"/g, '').trim()}, ${parts[2].replace(/"/g, '').trim()}`;
        const timestamp = parseInt(parts[3], 10);
        const breathPhase = parseInt(parts[4], 10);
        const step = parseInt(parts[5], 10);
        const spm = parseFloat(parts[6]);
        const patternID = parseInt(parts[7], 10);

        // Defensive: skip baris dengan timestamp invalid
        if (Number.isNaN(timestamp)) return;

        if (!sessionsMap[sessionId]) {
            sessionsMap[sessionId] = {
                startDate: rawDate,
                startTime: timestamp,
                endTime: timestamp,
                breathTransitions: [],
                stepEvents: [],
                targetPatternsUsed: new Set(),
                rawLines: [],
                spmSum: 0,
                spmCount: 0,
            };
        }

        const session = sessionsMap[sessionId];
        session.rawLines.push(line);
        session.endTime = Math.max(session.endTime, timestamp);
        if (!Number.isNaN(patternID)) session.targetPatternsUsed.add(patternID);

        if (step === 1) {
            session.stepEvents.push({ timestamp, breathPhase, spm, patternID });
            if (!Number.isNaN(spm) && spm > 0) {
                session.spmSum += spm;
                session.spmCount++;
            }
        } else if (step === 0 && (breathPhase === 1 || breathPhase === -1)) {
            session.breathTransitions.push({ timestamp, breathPhase, patternID });
        }
        // step=0 dengan breathPhase=0 → diabaikan (placeholder)
    });

    // ---- Pass 2: Analyze each session ----
    const analyzedSessions = [];

    for (const [sessionId, session] of Object.entries(sessionsMap)) {
        // Duration
        const durationMs = session.endTime - session.startTime;
        const durationSeconds = Math.max(0, Math.floor(durationMs / 1000));
        const minutes = Math.floor(durationSeconds / 60);
        const seconds = durationSeconds % 60;
        const formattedDuration = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;

        // Debounce breath transitions (filter sensor noise <100ms apart)
        const transitions = [];
        for (const t of session.breathTransitions) {
            if (
                transitions.length === 0 ||
                t.timestamp - transitions[transitions.length - 1].timestamp >= DEBOUNCE_MS
            ) {
                transitions.push(t);
            }
        }

        // Build cycles: cari sequence (+1, -1, +1)
        const cycles = [];
        let i = 0;
        // Skip leading non-IN transitions (sesi mulai mid-EX)
        while (i < transitions.length && transitions[i].breathPhase !== 1) i++;

        while (i < transitions.length - 2) {
            const inStart = transitions[i];
            const exStart = transitions[i + 1];
            const nextInStart = transitions[i + 2];

            if (inStart.breathPhase !== 1 || exStart.breathPhase !== -1 || nextInStart.breathPhase !== 1) {
                // Malformed sequence, skip current dan coba dari next
                i++;
                continue;
            }

            cycles.push({
                inStartTs: inStart.timestamp,
                exStartTs: exStart.timestamp,
                nextInStartTs: nextInStart.timestamp,
                patternID: inStart.patternID,
            });
            i += 2; // cycle berikutnya mulai di nextInStart (sekarang index i+2)
        }

        // Sort step events by timestamp (defensive — should already be in order)
        const stepEvents = [...session.stepEvents].sort((a, b) => a.timestamp - b.timestamp);

        // Per-cycle analysis
        let totalSteps = 0;
        let compliantSteps = 0;
        const lags = []; // semua lag (absolute & signed)
        const cycleLags = []; // {cycleIdx, lag} untuk phase drift regression
        const graphDataPoints = [];
        const averagesMap = {};

        // Initialize averagesMap untuk semua pola yang pernah aktif
        session.targetPatternsUsed.forEach(id => {
            const patternStr = convertPatternId(id);
            averagesMap[patternStr] = { inSum: 0, exSum: 0, count: 0 };
        });

        cycles.forEach((cycle, cycleIdx) => {
            const { inStartTs, exStartTs, nextInStartTs, patternID } = cycle;
            const targetPatternStr = convertPatternId(patternID);
            const { N, M } = parsePattern(targetPatternStr);

            if (N === 0 || M === 0) return; // Pola invalid

            // Get step events di phase IN dan EX cycle ini
            const inSteps = stepEvents.filter(s => s.timestamp >= inStartTs && s.timestamp < exStartTs);
            const exSteps = stepEvents.filter(s => s.timestamp >= exStartTs && s.timestamp < nextInStartTs);

            // Skip cycle kalau tidak ada step (user napas tapi tidak lari)
            if (inSteps.length === 0 && exSteps.length === 0) return;

            const allCycleSteps = [...inSteps, ...exSteps].sort((a, b) => a.timestamp - b.timestamp);
            allCycleSteps.forEach((step, idx) => {
                const cyclePos = idx + 1; // 1-indexed
                const expectedPhase = cyclePos <= N ? 1 : -1;

                // Actual phase: cari transition terakhir dengan ts <= step.ts
                let actualPhase = 0;
                for (let j = transitions.length - 1; j >= 0; j--) {
                    if (transitions[j].timestamp <= step.timestamp) {
                        actualPhase = transitions[j].breathPhase;
                        break;
                    }
                }

                totalSteps++;
                if (expectedPhase === actualPhase) {
                    compliantSteps++;
                }
            });

            // === Lag IN→EX transition ===
            if (inSteps.length >= 2) {
                let sum = 0;
                for (let j = 1; j < inSteps.length; j++) {
                    sum += inSteps[j].timestamp - inSteps[j - 1].timestamp;
                }
                const stepIntervalIn = sum / (inSteps.length - 1);
                const expectedExTs = inStartTs + N * stepIntervalIn;
                const lagInToEx = exStartTs - expectedExTs;
                lags.push(lagInToEx);
                cycleLags.push({ cycleIdx, lag: lagInToEx });
            }

            // === Lag EX→IN transition ===
            if (exSteps.length >= 2) {
                let sum = 0;
                for (let j = 1; j < exSteps.length; j++) {
                    sum += exSteps[j].timestamp - exSteps[j - 1].timestamp;
                }
                const stepIntervalEx = sum / (exSteps.length - 1);
                const expectedNextInTs = exStartTs + M * stepIntervalEx;
                const lagExToIn = nextInStartTs - expectedNextInTs;
                lags.push(lagExToIn);
                cycleLags.push({ cycleIdx, lag: lagExToIn });
            }

            // === Legacy fields: averagesMap & graph ===
            const actualPattern = detectActualPattern(inSteps.length, exSteps.length);

            if (!averagesMap[targetPatternStr]) {
                averagesMap[targetPatternStr] = { inSum: 0, exSum: 0, count: 0 };
            }
            averagesMap[targetPatternStr].inSum += inSteps.length;
            averagesMap[targetPatternStr].exSum += exSteps.length;
            averagesMap[targetPatternStr].count++;

            graphDataPoints.push({
                y: mapPatternToY(actualPattern),
                targetPattern: targetPatternStr,
                actualPattern: actualPattern,
            });
        });

        // === Aggregate metrics ===
        const compliance = totalSteps > 0 ? Math.round((compliantSteps / totalSteps) * 100) : 0;

        const avgLag = lags.length > 0
            ? Math.round(lags.reduce((sum, l) => sum + Math.abs(l), 0) / lags.length)
            : null;

        // Phase drift: linear regression slope dari signed lag vs cycle index
        let phaseDrift = null;
        if (cycleLags.length >= 3) {
            const n = cycleLags.length;
            let sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
            cycleLags.forEach((cl) => {
                sumX += cl.cycleIdx;
                sumY += cl.lag;
                sumXY += cl.cycleIdx * cl.lag;
                sumXX += cl.cycleIdx * cl.cycleIdx;
            });
            const denom = n * sumXX - sumX * sumX;
            if (denom !== 0) {
                phaseDrift = Math.round(((n * sumXY - sumX * sumY) / denom) * 100) / 100;
            }
        }

        // Consistency: 100 - min(100, stddev(lag) / 10)
        let consistencyScore = null;
        if (lags.length >= 2) {
            const meanLag = lags.reduce((s, l) => s + l, 0) / lags.length;
            const variance = lags.reduce((s, l) => s + (l - meanLag) ** 2, 0) / lags.length;
            const stddev = Math.sqrt(variance);
            consistencyScore = Math.max(0, Math.min(100, Math.round(100 - stddev / 10)));
        }

        // avgLrc JSON string
        const finalAvgLrcObj = {};
        for (const [patt, stats] of Object.entries(averagesMap)) {
            if (stats.count > 0) {
                const avgIn = (stats.inSum / stats.count).toFixed(1);
                const avgEx = (stats.exSum / stats.count).toFixed(1);
                finalAvgLrcObj[patt] = `${avgIn} : ${avgEx}`;
            } else {
                finalAvgLrcObj[patt] = "0.0 : 0.0";
            }
        }
        const avgLrcJsonString = JSON.stringify(finalAvgLrcObj);

        // Smoothing graph data (sama dengan old format)
        const finalGraphData = [];
        for (let k = 0; k < graphDataPoints.length; k++) {
            let sumY = 0;
            let count = 0;
            for (let j = Math.max(0, k - 1); j <= Math.min(graphDataPoints.length - 1, k + 1); j++) {
                sumY += graphDataPoints[j].y;
                count++;
            }
            finalGraphData.push({
                y: parseFloat((sumY / count).toFixed(2)),
                pattern: graphDataPoints[k].targetPattern,
                actualPattern: graphDataPoints[k].actualPattern,
            });
        }

        // Target pattern string
        const patternsArray = Array.from(session.targetPatternsUsed).map(id => convertPatternId(id));
        const sessionTargetPatternStr = patternsArray.join(" & ");

        // Raw CSV (header + baris asli)
        const rawCsvForSession = session.rawLines.length > 0
            ? `${CSV_HEADER}\n${session.rawLines.join('\n')}`
            : null;

        analyzedSessions.push({
            sessionNumber: parseInt(sessionId, 10),
            startDate: session.startDate,
            targetPattern: sessionTargetPatternStr,
            duration: formattedDuration,
            avgSpm: session.spmCount > 0 ? Math.round(session.spmSum / session.spmCount) : 0,
            compliance: compliance,
            avgLrc: avgLrcJsonString,
            rawLrcData: finalGraphData,
            rawCsv: rawCsvForSession,
            avgLag,
            phaseDrift,
            consistencyScore,
        });
    }

    return analyzedSessions;
};


export const analyzeRunData = (rawData) => {
    if (!rawData || typeof rawData !== 'string') return [];

    const format = detectFormat(rawData);
    if (format === 'new') {
        return analyzeNewFormat(rawData);
    }
    return analyzeOldFormat(rawData);
};