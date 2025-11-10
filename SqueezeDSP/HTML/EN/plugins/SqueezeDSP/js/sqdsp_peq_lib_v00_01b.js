/*--------------------------
Parametric Equaliizer Library 
-----------------------------*/
class FoxPEQ {
    constructor(sampleRate, lowestFrequency = 15) {
        if (lowestFrequency < 15) lowestFrequency = 15;
        
        this.SampleRate = sampleRate;
        this.FilterLength = Math.floor((2 * sampleRate) / lowestFrequency);
        this.FilterCoefficients = [];
        this.Impulse = [];
        this.DebugFunc = null;
        this.WarningFunc = null;
    }

    // Coefficients structure
    static Coefficients = class {
        constructor() {
            this.A = [0, 0, 0]; // a0, a1, a2
            this.B = [0, 0, 0]; // b0, b1, b2
        }
    }

    // Frequency-Gain pair
    static FreqGain = class {
        constructor(freq, gain) {
            this.Freq = freq;
            this.Gain = gain;
        }
    }

    // Filter profile
    static FilterProfile = class extends Array {
        copy() {
            return new FoxPEQ.FilterProfile(...this);
        }
    }

    // IIR Filter implementation
    static IIRFilter(input, b, a, output) {
        const N = input.length;
        const M = b.length;
        const y = new Array(N).fill(0);
        const w = new Array(M).fill(0);

        for (let n = 0; n < N; n++) {
            y[n] = b[0] * input[n] + w[0];
            for (let i = 1; i < M; i++) {
                w[i - 1] = b[i] * input[n] + w[i] - a[i] * y[n];
            }
            output[n] = y[n];
        }
    }

    // Add coefficients to the filter
    addCoefficients(coeff) {
        this.FilterCoefficients.push(coeff);
    }

    // Generate filter impulse from all coefficients
    
    // Calculate biquad filter coefficients
    calcBiquadFilter(filterType, frequency, peakGain, width, slopeType) {
        const errorPrefix = "CalcBiquadFilter ";
        const Nyquist = 0.445;
        filterType = filterType.toLowerCase();
        
        // Input validation
        if (frequency < 10 || frequency > 25000) {
            throw new Error(`${errorPrefix} ${filterType} frequency should be between 10 and 25000, got: ${frequency}`);
        }
        if (this.SampleRate < 10000 || this.SampleRate > 400000) {
            throw new Error(`${errorPrefix} ${filterType} sampleRate should be a recognized sample rate, got: ${this.SampleRate}`);
        }
        if (peakGain < -30 || peakGain > 20) {
            throw new Error(`${errorPrefix} ${filterType} peakGain should be between -30 and +20, got: ${peakGain}`);
        }

        // Adjust frequency if it exceeds Nyquist
        if (frequency / this.SampleRate > Nyquist) {
            frequency = this.SampleRate * Nyquist;
        }

        let b0 = 1.0, b1 = 0.0, b2 = 0.0;
        let a0 = 1.0, a1 = 0.0, a2 = 0.0;
        let norm = 0.0;

        const ampl = Math.pow(10, Math.abs(peakGain) / 40);
        const actualAmpl = peakGain < 0 ? 1 / ampl : ampl;
        const SQRTA = Math.sqrt(actualAmpl);
        let alpha = 0, beta = 0;

        // Handle filter type adjustments
        if (filterType === "lowpass" || filterType === "highcut") {
            const desiredLevel = -1.0;
            const x = Math.pow(10, desiredLevel / 20.0);
            const desiredStartingPoint = frequency + frequency - (frequency * x);
            frequency = desiredStartingPoint;
            filterType = "lowpass";
        }

        if (filterType === "highpass" || filterType === "lowcut") {
            filterType = "highpass";
            const desiredLevel = 2.0;
            const desiredStartingPoint = frequency * Math.sqrt(Math.pow(10, desiredLevel / 10.0) - 1);
            frequency = desiredStartingPoint;
        }

        const omega = 2 * Math.PI * frequency / this.SampleRate;
        const coso = Math.cos(omega);
        const sino = Math.sin(omega);

        // Calculate alpha based on slope type
        switch (slopeType.toLowerCase()) {
            case "slope":
                alpha = sino / 2 * Math.sqrt((actualAmpl + 1 / actualAmpl) * (1 / width - 1) + 2);
                break;
            case "q":
                alpha = sino / (2 * width);
                break;
            case "octave":
                alpha = sino * Math.sinh(Math.log(2) / 2 * width * omega / sino);
                break;
            default:
                throw new Error(`${errorPrefix} slopeType ${slopeType} was not recognized [slope, Q, octave]`);
        }

        // Calculate coefficients based on filter type
        switch (filterType) {
            case "lowpass":
                norm = 1 / (1.0 + alpha);
                b0 = norm * ((1.0 - coso) / 2.0);
                b1 = norm * (1.0 - coso);
                b2 = norm * ((1.0 - coso) / 2.0);
                a0 = 1.0;
                a1 = norm * (-2.0 * coso);
                a2 = norm * (1.0 - alpha);
                break;

            case "highpass":
                norm = 1 / (1.0 + alpha);
                b0 = norm * ((1.0 + coso) / 2.0);
                b1 = norm * (-(1.0 + coso));
                b2 = b0;
                a0 = 1.0;
                a1 = norm * (-2.0 * coso);
                a2 = norm * (1.0 - alpha);
                break;

            case "bandpass":
                norm = 1 / (1.0 + alpha);
                b0 = norm * alpha;
                b1 = 0.0;
                b2 = norm * (-alpha);
                a0 = 1.0;
                a1 = norm * (-2.0 * coso);
                a2 = norm * (1.0 - alpha);
                break;

            case "notch":
                norm = 1 / (1.0 + alpha);
                b0 = norm;
                b1 = norm * -2.0 * coso;
                b2 = b0;
                a0 = 1.0;
                a1 = norm * -2.0 * coso;
                a2 = norm * (1.0 - alpha);
                break;

            case "peak":
                norm = 1 / (1 + alpha / actualAmpl);
                b0 = norm * (1 + alpha * actualAmpl);
                b1 = norm * (-2 * coso);
                b2 = norm * (1 - alpha * actualAmpl);
                a0 = 1;
                a1 = norm * (-2 * coso);
                a2 = norm * (1 - alpha / actualAmpl);
                break;

            case "lowshelf":
                beta = 2.0 * SQRTA * alpha;
                norm = 1 / (actualAmpl + 1 + (actualAmpl - 1) * coso + 2 * SQRTA * alpha);
                b0 = norm * (actualAmpl * (actualAmpl + 1 - (actualAmpl - 1) * coso + beta));
                b1 = norm * (2 * actualAmpl * (actualAmpl - 1 - (actualAmpl + 1) * coso));
                b2 = norm * (actualAmpl * (actualAmpl + 1 - (actualAmpl - 1) * coso - beta));
                a0 = 1;
                a1 = norm * (-2 * (actualAmpl - 1 + (actualAmpl + 1) * coso));
                a2 = norm * (actualAmpl + 1 + (actualAmpl - 1) * coso - beta);
                break;

            case "highshelf":
                norm = 1 / ((actualAmpl + 1) - (actualAmpl - 1) * coso + 2 * SQRTA * alpha);
                b0 = norm * (actualAmpl * ((actualAmpl + 1) + (actualAmpl - 1) * coso + 2 * SQRTA * alpha));
                b1 = norm * (-2 * actualAmpl * ((actualAmpl - 1) + (actualAmpl + 1) * coso));
                b2 = norm * (actualAmpl * ((actualAmpl + 1) + (actualAmpl - 1) * coso - 2 * SQRTA * alpha));
                a0 = 1.0;
                a1 = norm * (2 * ((actualAmpl - 1) - (actualAmpl + 1) * coso));
                a2 = norm * ((actualAmpl + 1) - (actualAmpl - 1) * coso - 2 * SQRTA * alpha);
                break;

            default:
                throw new Error(`${errorPrefix} filterType ${filterType} was not set to a recognized filter type`);
        }

        const myCoefficients = new FoxPEQ.Coefficients();
        myCoefficients.A = [a0, a1, a2];
        myCoefficients.B = [b0, b1, b2];
        
        this.addCoefficients(myCoefficients);
        return myCoefficients;
    }
}

// Utility functions for working with SqueezeDSPData
class SqueezeDSPHelper {
    /**
     * Generate coefficients from all filters in SqueezeDSPData
     */
    static generateFromAllFilters(squeezeDSPData, sampleRate = 48000) {
        if (!squeezeDSPData || !squeezeDSPData.Client || !squeezeDSPData.Client.Filters) {
            throw new Error("Invalid SqueezeDSPData structure");
        }

        const peq = new FoxPEQ(sampleRate);
        const filters = squeezeDSPData.Client.Filters;
        const allCoefficients = [];

        filters.forEach((filter, index) => {
            try {
                const coeff = peq.calcBiquadFilter(
                    filter.FilterType,  // Changed from filter.Type to filter.FilterType
                    filter.Frequency,
                    filter.Gain,
                    filter.Slope,       // This is the Q/slope value
                    filter.SlopeType    // This is 'slope' or 'Q'
                );
                allCoefficients.push({
                    filterIndex: index,
                    filterType: filter.FilterType,  // Fixed field name
                    coefficients: coeff
                });
            } catch (error) {
                console.warn(`Failed to process filter ${index}:`, error.message);
            }
        });

        return {
            peq: peq,
            coefficients: allCoefficients
        };
    }

    /**
     * Generate coefficients from a specific filter by index
     */
    static generateFromFilterIndex(squeezeDSPData, filterIndex, sampleRate = 48000) {
        if (!squeezeDSPData || !squeezeDSPData.Client || !squeezeDSPData.Client.Filters) {
            throw new Error("Invalid SqueezeDSPData structure");
        }

        const filters = squeezeDSPData.Client.Filters;
        if (filterIndex < 0 || filterIndex >= filters.length) {
            throw new Error(`Filter index ${filterIndex} out of range. Available filters: 0-${filters.length - 1}`);
        }

        const filter = filters[filterIndex];
        const peq = new FoxPEQ(sampleRate);

        try {
            const coeff = peq.calcBiquadFilter(
                filter.FilterType,   // Changed from filter.Type to filter.FilterType
                filter.Frequency,
                filter.Gain,
                filter.Slope,        // This is the Q/slope value
                filter.SlopeType     // This is 'slope' or 'Q'
            );

            return {
                filterIndex: filterIndex,
                filterType: filter.FilterType,  // Fixed field name
                coefficients: coeff,
                peq: peq
            };
        } catch (error) {
            throw new Error(`Failed to process filter ${filterIndex}: ${error.message}`);
        }
    }
}

// Export for use in different environments
if (typeof module !== 'undefined' && module.exports) {
    // Node.js
    module.exports = { FoxPEQ, SqueezeDSPHelper };
} else if (typeof window !== 'undefined') {
    // Browser
    window.FoxPEQ = FoxPEQ;
    window.SqueezeDSPHelper = SqueezeDSPHelper;
}

// Exact replica of your Go loudness implementation
class Loudness {
    constructor() {
        this.official = false;
        if (this.official) {
            // Official curve (not used)
            this.f = [20, 25, 31.5, 40.0, 50.0, 63.0, 80.0, 100.0, 125.0, 160.0, 200.0, 250.0, 315.0, 400.0, 500.0, 630.0, 800.0, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500];
            this.af = [0.532, 0.506, 0.480, 0.455, 0.432, 0.409, 0.387, 0.367, 0.349, 0.330, 0.315, 0.301, 0.288, 0.276, 0.267, 0.259, 0.253, 0.250, 0.246, 0.244, 0.243, 0.243, 0.243, 0.242, 0.242, 0.245, 0.254, 0.271, 0.301];
            this.Lu = [-31.6, -27.2, -23.0, -19.1, -15.9, -13.0, -10.3, -8.1, -6.2, -4.5, -3.1, -2.0, -1.1, -0.4, 0.0, 0.3, 0.5, 0.0, -2.7, -4.1, -1.0, 1.7, 2.5, 1.2, -2.1, -7.1, -11.2, -10.7, -3.1];
            this.Tf = [78.5, 68.7, 59.5, 51.1, 44.0, 37.5, 31.5, 26.5, 22.1, 17.9, 14.4, 11.4, 8.6, 6.2, 4.4, 3.0, 2.2, 2.4, 3.5, 1.7, -1.3, -4.2, -6.0, -5.4, -1.5, 6.0, 12.6, 13.9, 12.3];
        } else {
            // Your approximation curve (used)
            this.f = [40, 70, 1000, 1200, 2400, 6300, 12500];
            this.af = [0.455, 0.309, 0.25, 0.246, 0.243, 0.245, 0.301];
            this.Lu = [-19.1, -13.0, 0, -2.7, 1.7, -7.1, -3.1];
            this.Tf = [51.1, 31.5, 2.4, 3.5, -4.2, 6, 12.3];
        }
        this.ReferencePhon = 82.5;
        this.PlaybackPhon = 82.5; // Default, will be set from UI
    }

    // Exact JavaScript implementation of your Go spl function
    spl(phon) {
        if (phon < 0 || phon > 120) {
            throw new Error(`Phon value out of bounds! Got: ${phon}`);
        }

        const lfg = [];
        const Ln = phon;

        for (let j = 0; j < this.f.length; j++) {
            // Your exact Go calculation
            const Af = 4.47e-3 * (Math.pow(10.0, 0.025 * Ln) - 1.15) + Math.pow(0.4 * Math.pow(10.0, ((this.Tf[j] + this.Lu[j]) / 10.0) - 9.0), this.af[j]);
            const Lp = (10.0 / this.af[j]) * Math.log10(Af) - this.Lu[j] + 94.0;

            lfg.push({
                Freq: this.f[j],
                Gain: Lp
            });
        }
        return lfg;
    }

    // Exact JavaScript implementation of your Go DifferentialSPL function
    DifferentialSPL(scale = 1.0) {
        const spl0 = this.spl(this.ReferencePhon);
        const spl1 = this.spl(this.PlaybackPhon);

        let refLevel = 0;
        
        // Find the 1000Hz reference level
        for (let j = 0; j < spl0.length; j++) {
            if (spl0[j].Freq === 1000 && spl1[j].Freq === 1000) {
                refLevel = spl0[j].Gain - spl1[j].Gain;
                break;
            }
        }

        const spl = [];
        for (let j = 0; j < spl1.length; j++) {
            let gain;
            if (refLevel !== 0) {
                gain = (spl1[j].Gain + refLevel) - spl0[j].Gain;
            } else {
                gain = scale * (spl0[j].Gain - spl1[j].Gain);
            }
            
            spl.push({
                Freq: spl1[j].Freq,
                Gain: gain
            });
        }
        return spl;
    }
}

// Generate loudness filter coefficients using your exact Go logic
function generateLoudnessCoefficients(listeningLevel, sampleRate = 48000) {
    const loudness = new Loudness();
    loudness.PlaybackPhon = listeningLevel;
    
    // Get the differential SPL curve (your FilterProfile)
    const filterProfile = loudness.DifferentialSPL();
    
    // Generate coefficients using your exact filter structure
    const peq = new FoxPEQ(sampleRate);
    const coefficients = [];
    
    const mySize = filterProfile.length;
    const lastfilter = mySize - 1;

    for (let i = 0; i < mySize; i++) {
        let filterType;
        let Q;
        
        // Your exact Go filter type selection logic
        if (i >= 1 && i !== lastfilter) {
            filterType = "peak";
            Q = 0.41;
        } else {
            if (i === 0) {
                filterType = "lowshelf";
            } else {
                filterType = "highshelf";
            }
            Q = 0.51;
        }

        // Calculate coefficients using your exact parameters
        const coeff = peq.calcBiquadFilter(
            filterType,
            filterProfile[i].Freq,
            filterProfile[i].Gain,
            Q,
            "Q"
        );
        
        coefficients.push({
            filterIndex: i,
            filterType: filterType,
            frequency: filterProfile[i].Freq,
            gain: filterProfile[i].Gain,
            Q: Q,
            coefficients: coeff
        });
    }
    
    return {
        peq: peq,
        coefficients: coefficients,
        filterProfile: filterProfile
    };
}

   



// Lightweight graph management
let currentFilterIndex = null; // null means no single filter selected



// Set current filter and update graph
function setCurrentFilter(filterIndex) {
    // If clicking the same filter again, deselect it
    if (currentFilterIndex === filterIndex) {
        currentFilterIndex = null;
    } else {
        currentFilterIndex = filterIndex;
    }
    updatePEQGraph();
}



// Usage examples:
/*
// Example 1: Process all filters from SqueezeDSPData
const allFiltersResult = SqueezeDSPHelper.generateFromAllFilters(SqueezeDSPData, 48000);
console.log("All coefficients:", allFiltersResult.coefficients);

// Example 2: Process specific filter by index
const singleFilterResult = SqueezeDSPHelper.generateFromFilterIndex(SqueezeDSPData, 0, 48000);
console.log("Single filter coefficients:", singleFilterResult.coefficients);

// Example 3: Generate combined impulse response
const combinedImpulse = SqueezeDSPHelper.generateCombinedImpulse(SqueezeDSPData, 48000);
console.log("Combined impulse length:", combinedImpulse.length);

// Example 4: Direct usage for custom filters
const peq = new FoxPEQ(48000);
peq.calcBiquadFilter("lowpass", 1000, -12, 0.7, "Q");
peq.calcBiquadFilter("peak", 2000, 6, 2.0, "Q");
peq.generateFilterImpulse();
console.log("Custom impulse:", peq.Impulse);
*/
