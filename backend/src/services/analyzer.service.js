export const analyzeRunData = (rawSamples, targetPattern) => {
    if (!rawSamples || rawSamples.length === 0) return null;

    let totalSteps = 0, totalSpm = 0, validSpmCount = 0;
    let correctCycles = 0, totalCycles = 0;
    let cycles = []; 

    // 🔥 MAP BARU: Menggunakan 7 level ritme standar
    const patternMap = {
        "1:1": 1, 
        "2:1": 2, 
        "2:2": 3, 
        "3:2": 4, 
        "3:3": 5, 
        "4:3": 6, 
        "4:4": 7
    };
    const targetY = patternMap[targetPattern] || 4; // Asumsi default 3:2 (Level 4) jika tidak ketemu

    // 1. 🔥 DEBOUNCE FILTER: Menghilangkan noise/lonjakan 1 detik dari sensor napas
    let smoothedSamples = JSON.parse(JSON.stringify(rawSamples)); 
    for (let i = 1; i < smoothedSamples.length - 1; i++) {
        if (smoothedSamples[i].breath !== smoothedSamples[i-1].breath &&
            smoothedSamples[i].breath !== smoothedSamples[i+1].breath) {
            // Jika fase napas hanya berubah selama 1 detik, anggap itu noise dan timpa
            smoothedSamples[i].breath = smoothedSamples[i-1].breath;
        }
    }

    let currentPhase = smoothedSamples[0].breath;
    let stepsInCurrentPhase = 0;
    let inhaleSteps = 0, exhaleSteps = 0;

    smoothedSamples.forEach((sample, index) => {
        if (sample.spm > 0) {
            totalSpm += sample.spm;
            validSpmCount++;
        }

        if (sample.step === 1) {
            totalSteps++;
            stepsInCurrentPhase++;
        }

        // Cek perubahan fase napas (Inhale -> Exhale atau sebaliknya)
        if (sample.breath !== currentPhase || index === smoothedSamples.length - 1) {
            if (currentPhase === 1) {
                inhaleSteps = stepsInCurrentPhase;
            } else {
                exhaleSteps = stepsInCurrentPhase;

                // Hitung hanya jika fasenya cukup panjang (bukan sisa noise)
                if (inhaleSteps + exhaleSteps >= 2) {
                    totalCycles++;
                    const pattern = `${inhaleSteps}:${exhaleSteps}`;
                    let detectedY = 0;

                    // 2. 🔥 RATIO APPROXIMATION (Berdasarkan Total Langkah)
                    const totalStepsInCycle = inhaleSteps + exhaleSteps;

                    if (patternMap[pattern]) {
                        detectedY = patternMap[pattern];
                    } else {
                        // Jika polanya aneh (Noise), bulatkan ke ritme terdekat
                        // berdasarkan seberapa banyak total langkah yang terjadi
                        if (totalStepsInCycle >= 8) detectedY = 7;      // Dibulatkan ke 4:4 (7)
                        else if (totalStepsInCycle === 7) detectedY = 6;// Dibulatkan ke 4:3 (6)
                        else if (totalStepsInCycle === 6) detectedY = 5;// Dibulatkan ke 3:3 (5)
                        else if (totalStepsInCycle === 5) detectedY = 4;// Dibulatkan ke 3:2 (4)
                        else if (totalStepsInCycle === 4) detectedY = 3;// Dibulatkan ke 2:2 (3)
                        else if (totalStepsInCycle === 3) detectedY = 2;// Dibulatkan ke 2:1 (2)
                        else detectedY = 1;                             // Dibulatkan ke 1:1 (1)
                    }

                    // Kepatuhan dihitung jika nilainya sama atau sangat mendekati target (Toleransi 1 level)
                    if (detectedY === targetY) { correctCycles++; }

                    const timestampInMinutes = (sample.timestamp - smoothedSamples[0].timestamp) / 60000000;
                    cycles.push({
                        x: parseFloat(timestampInMinutes.toFixed(2)),
                        y: detectedY,
                        label: pattern
                    });
                }
            }
            currentPhase = sample.breath;
            stepsInCurrentPhase = 0;
        }
    });

    // 3. 🔥 MOVING AVERAGE: Menghaluskan garis grafik agar tidak melompat-lompat
    let smoothedGraph = [];
    for (let i = 0; i < cycles.length; i++) {
        let sumY = 0;
        let count = 0;
        // Ambil rata-rata dari 3 siklus berdekatan (sebelum, sekarang, sesudah)
        for (let j = Math.max(0, i - 1); j <= Math.min(cycles.length - 1, i + 1); j++) {
            sumY += cycles[j].y;
            count++;
        }
        smoothedGraph.push({
            x: cycles[i].x,
            y: parseFloat((sumY / count).toFixed(2)), // Nilai Y menjadi desimal halus
            label: cycles[i].label
        });
    }

    const firstTs = smoothedSamples[0].timestamp;
    const lastTs = smoothedSamples[smoothedSamples.length - 1].timestamp;
    const durationSeconds = Math.floor((lastTs - firstTs) / 1000000);

    const minutes = Math.floor(durationSeconds / 60);
    const seconds = durationSeconds % 60;
    const formattedDuration = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;

    let compliance = totalCycles > 0 ? Math.round((correctCycles / totalCycles) * 100) : 0;
    

    return {
        duration: durationSeconds,           
        formattedDuration: formattedDuration, 
        avgSpm: validSpmCount > 0 ? Math.round(totalSpm / validSpmCount) : 0,
        compliance: compliance,
        graphData: smoothedGraph // Mengirim data yang sudah dihaluskan
    };
};