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

// 7 columns: date and time are combined into a single quoted CSV field
// when exported (see mergeDateTimeColumn below), even though they arrive
// as two separate columns in the raw input. This keeps mulai_lari as one
// cell in spreadsheet software instead of being split across two columns.
const CSV_HEADER = 'sesi,mulai_lari,waktu_ms,breathPhase,step,spm,patternID';

// Merges a raw input line's separate date/time columns (parts[1], parts[2])
// into a single quoted CSV field, so the exported row has the same column
// count as CSV_HEADER. Without this, opening the export in Excel/Sheets
// would misread the comma inside the unquoted date-time as a column
// separator, shifting every subsequent value one column to the right.
const mergeDateTimeColumn = (line) => {
    const parts = line.split(',');
    if (parts.length < 8) return line; // already malformed, leave as-is
    const sesi = parts[0];
    const tanggal = parts[1].replace(/"/g, '').trim();
    const waktu = parts[2].replace(/"/g, '').trim();
    const rest = parts.slice(3).join(',');
    return `${sesi},"${tanggal}, ${waktu}",${rest}`;
};

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

            // Kepatuhan STRICT: cycle harus persis sesuai target N:M.
            // Tidak lagi pakai matching berbasis ratio (detectActualPattern) yang
            // mengklasifikasi cycle in=2 ex=0 sebagai "2:1" karena rasio-nya
            // 2.0 — user yang skip step EX atau transisi terlalu cepat sekarang
            // tercatat sebagai non-compliant.
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

        // Tidak ada smoothing pada y — setiap titik adalah kategori pola
        // diskrit (3:2, 3:3, dst), bukan nilai kontinu. Merata-ratakan
        // dengan tetangga menghasilkan posisi pecahan yang tidak sesuai
        // kategori manapun, sehingga step chart "menggantung" di antara
        // dua garis pola alih-alih mendarat tepat di satu garis.
        const finalGraphData = graphDataPoints.map(point => ({
            y: point.y,
            pattern: point.targetPattern,
            actualPattern: point.actualPattern,
        }));

        const patternsArray = Array.from(session.targetPatternsUsed).map(id => convertPatternId(id));
        const sessionTargetPatternStr = patternsArray.join(" & ");

        // Sort by timestamp column before export — same fix as new format,
        // see comment in analyzeNewFormat for full rationale.
        const sortedRawLines = [...session.rawLines]
            .sort((a, b) => {
                const tsA = parseInt(a.split(',')[3], 10);
                const tsB = parseInt(b.split(',')[3], 10);
                return tsA - tsB;
            })
            .map(mergeDateTimeColumn);

        const rawCsvForSession = sortedRawLines.length > 0
            ? `${CSV_HEADER}\n${sortedRawLines.join('\n')}`
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
const DEBOUNCE_MS = 300;

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
        // breathPhase === 0 is never treated as a breath transition, in either
        // branch above. This commonly occurs at the start of a session before
        // the breath sensor has detected its first inhale/exhale (firmware
        // hasn't calibrated a baseline yet), so rows like (step=1, phase=0)
        // are intentionally counted as step events only — they do not count
        // toward, nor break, breath cycle construction. Likewise
        // (step=0, phase=0) carries no usable transition info and is dropped.
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

        // Sort breath transitions by timestamp BEFORE debouncing.
        //
        // ROOT CAUSE: ESP32 firmware writes step rows immediately using
        // millis() at write-time (handleStepAnalysis -> writeLogEntry),
        // but breath rows use breathSensor.getLastEventTimestamp() — the
        // precise moment the sensor detected the transition, which is read
        // and written on a LATER loop() iteration. The timestamp VALUE is
        // accurate, but by the time it's written, several step rows with
        // larger millis() may already be appended to /run.dat. File order
        // is therefore not chronological even though every individual
        // timestamp is correct. Sorting here restores chronological order
        // for cycle-building without needing a firmware fix.
        const sortedTransitions = [...session.breathTransitions].sort(
            (a, b) => a.timestamp - b.timestamp
        );

        // Debounce breath transitions (filter sensor noise <100ms apart)
        const transitions = [];
        for (const t of sortedTransitions) {
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
        let globalStepCounter = 0;
        let patterAnchorSet = false;

        // Tentukan N dan M dari pola dominan sesi ini
        const dominantPatternId = session.targetPatternsUsed.size > 0
            ? [...session.targetPatternsUsed][0]
            : 0;
        const dominantPattern = convertPatternId(dominantPatternId);
        const { N: globalN, M: globalM } = parsePattern(dominantPattern);
        const globalCycleLen = (globalN > 0 && globalM > 0) ? globalN + globalM : 5;

        stepEvents.forEach(step => {
            // Actual phase: cari transisi terakhir dengan ts <= step.ts
            let actualPhase = 0;
            for (let j = transitions.length - 1; j >= 0; j--) {
                if (transitions[j].timestamp <= step.timestamp) {
                    actualPhase = transitions[j].breathPhase;
                    break;
                }
            }

            // Skip langkah sebelum transisi napas pertama tercatat
            if (actualPhase === 0) return;

            // Reset posisi global saat IN baru dimulai (setiap cycle baru)
            // agar posisi tidak drift akibat langkah yang terlewat sensor
            const prevPhaseForStep = (() => {
                for (let j = transitions.length - 1; j >= 0; j--) {
                    if (transitions[j].timestamp <= step.timestamp) {
                        // Cari transisi sebelumnya
                        if (j > 0) return transitions[j - 1].breathPhase;
                        return 0;
                    }
                }
                return 0;
            })();

            // Expected phase dari posisi dalam pola
            const posInCycle = globalStepCounter % globalCycleLen;
            const expectedPhase = posInCycle < globalN ? 1 : -1;

            totalSteps++;
            if (actualPhase === expectedPhase) compliantSteps++;
            globalStepCounter++;
        });

        cycles.forEach((cycle, cycleIdx) => {
            const { inStartTs, exStartTs, nextInStartTs, patternID } = cycle;
            const targetPatternStr = convertPatternId(patternID);
            const { N, M } = parsePattern(targetPatternStr);

            if (N === 0 || M === 0) return;

            const inSteps = stepEvents.filter(s => s.timestamp >= inStartTs && s.timestamp < exStartTs);
            const exSteps = stepEvents.filter(s => s.timestamp >= exStartTs && s.timestamp < nextInStartTs);

            if (inSteps.length === 0 && exSteps.length === 0) return;

            // === Outlier guard: breath-sensor dropout ===
            // If the breath sensor stops firing transitions for an extended
            // period (e.g. poor skin contact, motion artifact) while the step
            // sensor keeps counting normally, the two transitions bounding
            // this "cycle" can be tens of seconds apart — producing absurd
            // ratios like 27:3 instead of a real LRC pattern (max realistic
            // pattern is 4:4). Such cycles are sensor dropout artifacts, not
            // genuine breath-step data, so they are excluded from the
            // averages and graph — but cycles entirely skipped here simply
            // contribute no data point, they are not corrected or guessed.
            const MAX_STEPS_PER_PHASE = 4;
            if (inSteps.length > MAX_STEPS_PER_PHASE || exSteps.length > MAX_STEPS_PER_PHASE) {
                return;
            }


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

        // Tidak ada smoothing pada y — lihat komentar pada analyzeOldFormat
        // untuk rationale lengkap. Setiap titik harus tetap di kategori
        // pola diskritnya agar step chart di Flutter mendarat tepat di garis.
        const finalGraphData = graphDataPoints.map(point => ({
            y: point.y,
            pattern: point.targetPattern,
            actualPattern: point.actualPattern,
        }));

        // Target pattern string
        const patternsArray = Array.from(session.targetPatternsUsed).map(id => convertPatternId(id));
        const sessionTargetPatternStr = patternsArray.join(" & ");

        // Raw CSV (header + baris asli)
        //
        // IMPORTANT: rawLines is pushed in raw FILE order (see push above),
        // never sorted — unlike stepEvents/breathTransitions which are sorted
        // before being used for metric calculation. That means metrics were
        // already correct, but the exported rawCsv itself was still scrambled
        // in firmware write order. Sort by the timestamp column (parts[3])
        // here so the CSV a user downloads reads chronologically too.
        //
        // mergeDateTimeColumn collapses the raw input's separate date/time
        // columns into one quoted field, matching CSV_HEADER's 7 columns —
        // otherwise the unquoted comma between date and time gets misread
        // as a column separator when opened in spreadsheet software.
        const sortedRawLines = [...session.rawLines]
            .sort((a, b) => {
                const tsA = parseInt(a.split(',')[3], 10);
                const tsB = parseInt(b.split(',')[3], 10);
                return tsA - tsB;
            })
            .map(mergeDateTimeColumn);

        const rawCsvForSession = sortedRawLines.length > 0
            ? `${CSV_HEADER}\n${sortedRawLines.join('\n')}`
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