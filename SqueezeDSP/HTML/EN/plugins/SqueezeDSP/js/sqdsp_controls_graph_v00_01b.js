/*-------------------------------
Graph Controls for PEQ
-------------------------------*/

// Apply the theme class to our containers
function applyThemeClass(theme) {
    const graphContainer = document.getElementById('peqGraphContainer');
    if (graphContainer) {
        graphContainer.className = ''; // Clear existing
        graphContainer.classList.add(theme);
        console.log('Applied theme class:', theme, 'to graph container');
    }
}

// Simple function to call from onchange events
function updateFilterGraphFromControl(controlElement) {
    try {
        // Extract filter index from control ID
        const id = controlElement.id;
        const match = id.match(/Filters\.(\d+)\./);
        if (match) {
            const filterIndex = parseInt(match[1]);
            
            // Set this as the current filter
            currentFilterIndex = filterIndex;
            
            // Update graph immediately
            updatePEQGraph();
        }
    } catch (error) {
        console.error('Error updating graph from control:', error);
    }
}
// Initialize graph on page load
// Initialize the graph when the page loads
function initializePEQGraph() {
    console.log('Initializing PEQ Graph...');
    
    // Wait for SqueezeDSPData to be fully loaded
    if (typeof SqueezeDSPData !== 'undefined' && SqueezeDSPData.Client && SqueezeDSPData.Client.Filters) {
        console.log('SqueezeDSPData loaded, updating graph...');
        
        // Auto-select first filter if none is selected
        if (currentFilterIndex === null && SqueezeDSPData.Client.Filters.length > 0) {
            currentFilterIndex = 0;
            console.log('Auto-selected filter index:', currentFilterIndex);
        }
        
        updatePEQGraph();
    } else {
        // Retry after a short delay
        console.log('SqueezeDSPData not ready, retrying...');
        setTimeout(initializePEQGraph, 100);
    }
}



function updatePEQGraph() {
    const graphElement = document.getElementById('peqGraph');
    if (!graphElement) {
        console.error('peqGraph element not found');
        return;
    }
    
    try {
        console.log('Updating PEQ Graph...');
        
        const loudnessEnabled = SqueezeDSPData.Client.Loudness && SqueezeDSPData.Client.Loudness.enabled == 1;
        const hasPEQFilters = SqueezeDSPData.Client.Filters && SqueezeDSPData.Client.Filters.length > 0;
        const listeningLevel = SqueezeDSPData.Client.Loudness?.listening_level || 82.5;
        
        // Get container dimensions
        const container = document.getElementById('peqGraphContainer');
        const containerWidth = container ? container.clientWidth : 800;
        const containerHeight = container ? container.clientHeight : 400;
        
        const plotter = new FrequencyResponsePlotter(containerWidth, containerHeight);
        const responses = [];
        const labels = [];
        
        let loudnessResult = null;
        
        // Generate loudness response if enabled
        if (loudnessEnabled) {
            loudnessResult = generateLoudnessCoefficients(listeningLevel);
            
            if (loudnessResult && loudnessResult.coefficients.length > 0) {
                const loudnessResponse = plotter.calculateCombinedResponse(
                    loudnessResult.coefficients.map(c => c.coefficients),
                    48000
                );
                responses.push(loudnessResponse);
                labels.push('Loudness');
            }
        }
        
        // Generate PEQ responses
        if (hasPEQFilters) {
            const peqResult = SqueezeDSPHelper.generateFromAllFilters(SqueezeDSPData, 48000);
            
            if (peqResult.coefficients.length > 0) {
                const peqResponse = plotter.calculateCombinedResponse(
                    peqResult.coefficients.map(c => c.coefficients),
                    48000
                );
                responses.push(peqResponse);
                labels.push('All Bands');
                
                // Show individual band if one is selected
                if (currentFilterIndex !== null && 
                    currentFilterIndex >= 0 && 
                    currentFilterIndex < SqueezeDSPData.Client.Filters.length) {
                    
                    try {
                        const singleResult = SqueezeDSPHelper.generateFromFilterIndex(
                            SqueezeDSPData, 
                            currentFilterIndex, 
                            48000
                        );
                        
                        const singleResponse = plotter.calculateFrequencyResponse(
                            singleResult.coefficients,
                            48000
                        );
                        
                        responses.push(singleResponse);
                        labels.push(`Band ${currentFilterIndex + 1}`);
                    } catch (error) {
                        console.warn('Could not generate single filter response:', error);
                    }
                }
                
                // Generate combined response if both loudness and PEQ are enabled
                if (loudnessEnabled && loudnessResult && loudnessResult.coefficients.length > 0) {
                    const allCoefficients = [
                        ...loudnessResult.coefficients.map(c => c.coefficients),
                        ...peqResult.coefficients.map(c => c.coefficients)
                    ];
                    const combinedResponse = plotter.calculateCombinedResponse(allCoefficients, 48000);
                    responses.push(combinedResponse);
                    labels.push('Everything');
                }
            }
        }
        
        // Update the graph
        if (responses.length > 0) {
            const svg = plotter.generateSVGPlot(responses, labels, '');
            graphElement.innerHTML = svg;
        } else {
            graphElement.innerHTML = `<div style="color: inherit; text-align: center; padding: 50px;">No active filters - Enable Loudness or add PEQ filters</div>`;
        }
        
    } catch (error) {
        console.error('Error in updatePEQGraph:', error);
        graphElement.innerHTML = `<div style="color: inherit; text-align: center; padding: 50px;">Graph Error: ${error.message}<br><small>Check console for details</small></div>`;
    }
}

// Update the display logic
function shouldShowGraph() {
    // Check if loudness is enabled (note: enabled is 0/1, not boolean)
    const loudnessEnabled = SqueezeDSPData.Client.Loudness && SqueezeDSPData.Client.Loudness.enabled == 1;
    const hasPEQFilters = SqueezeDSPData.Client.Filters && SqueezeDSPData.Client.Filters.length > 0;
    
    return loudnessEnabled || hasPEQFilters;
}

// Update graph container visibility
function updateGraphVisibility() {
    const graphContainer = document.getElementById('peqGraphContainer');
    if (graphContainer) {
        graphContainer.style.display = shouldShowGraph() ? 'block' : 'none';
    }
}

// Frequency Response Plotter for FoxPEQ filters - Fixed label sizing and improved legend
// Frequency Response Plotter with theme support
class FrequencyResponsePlotter {
    constructor(width = 800, height = 400) {
    // Ensure minimum dimensions for readability
    this.width = Math.max(width, 300);
    this.height = Math.max(height, 200);
    
    // Responsive margins based on container size
    const scale = Math.min(this.width / 800, 1);
    this.margin = {
        top: Math.max(10 * scale, 8),
        right: Math.max(15 * scale, 10),
        bottom: Math.max(25 * scale, 20),
        left: Math.max(35 * scale, 25)
    };
    this.scale = scale;
// plot colors are picked from the container theme in the order that they are listed.
this.colors = [
    '#3366cc',  // bright blue
    '#33cc33',  // bright green
    '#ff9900',  // bright orange     
    '#ff3333',  // bright red
    '#9966ff',  // bright purple
    '#cc6600',  // bright brown
    '#ff66cc',  // bright pink
    '#666666',  // medium gray
    '#cccc00',  // bright yellow
    '#00cccc'   // bright cyan
];
        
        // Set colors based on container theme
        this.setColorsFromContainer();

    }

    setColorsFromContainer() {
        const container = document.getElementById('peqGraphContainer');
        if (!container) return;
        
        const isDark = container.classList.contains('dark');
        
        if (isDark) {
            // Dark theme colors
            this.bgColor = '#303030';
            this.textColor = '#ffffff';
            this.gridColor = '#686868';
            this.axisColor = '#ffffff';
            this.zeroLineColor = '#ffffff';
        } else {
            // Light theme colors
            this.bgColor = '#f5f5f5';
            this.textColor = '#212121';
            this.gridColor = '#d0d0d0';
            this.axisColor = '#212121';
            this.zeroLineColor = '#212121';
        }
        
        console.log('Plotter colors - BG:', this.bgColor, 'Text:', this.textColor, 'Dark mode:', isDark);
    }

 /**
     * Calculate frequency response for a single biquad filter
     */
    calculateFrequencyResponse(coeff, sampleRate, minFreq = 10, maxFreq = 24000, points = 800) {
        const response = [];
        const a = coeff.A;
        const b = coeff.B;
        
        for (let i = 0; i < points; i++) {
            // Logarithmic spacing
            const freq = minFreq * Math.pow(maxFreq / minFreq, i / (points - 1));
            const omega = 2 * Math.PI * freq / sampleRate;
            const zReal = Math.cos(omega);
            const zImag = Math.sin(omega);
            
            // Numerator: B(z) = b0 + b1*z^-1 + b2*z^-2
            const numReal = b[0] + b[1] * zReal + b[2] * (zReal * zReal - zImag * zImag);
            const numImag = b[1] * (-zImag) + b[2] * (-2 * zReal * zImag);
            
            // Denominator: A(z) = a0 + a1*z^-1 + a2*z^-2
            const denReal = a[0] + a[1] * zReal + a[2] * (zReal * zReal - zImag * zImag);
            const denImag = a[1] * (-zImag) + a[2] * (-2 * zReal * zImag);
            
            // Magnitude = |H(z)| = |B(z)| / |A(z)|
            const numMag = Math.sqrt(numReal * numReal + numImag * numImag);
            const denMag = Math.sqrt(denReal * denReal + denImag * denImag);
            const magnitude = numMag / denMag;
            
            // Convert to dB
            const magnitudeDB = 20 * Math.log10(Math.max(magnitude, 1e-10));
            
            response.push({
                frequency: freq,
                magnitude: magnitudeDB,
                linearMagnitude: magnitude
            });
        }
        
        return response;
    }

    /**
     * Calculate combined frequency response for multiple filters
     */
    calculateCombinedResponse(coefficients, sampleRate, minFreq = 10, maxFreq = 24000, points = 800) {
        if (coefficients.length === 0) return [];
        
        // Calculate individual responses
        const individualResponses = coefficients.map(coeff => 
            this.calculateFrequencyResponse(coeff, sampleRate, minFreq, maxFreq, points)
        );
        
        // Combine responses by multiplying magnitudes (adding in dB)
        const combinedResponse = [];
        for (let i = 0; i < points; i++) {
            let combinedMagnitudeDB = 0;
            let freq = 0;
            
            for (let j = 0; j < coefficients.length; j++) {
                if (j === 0) {
                    freq = individualResponses[j][i].frequency;
                }
                combinedMagnitudeDB += individualResponses[j][i].magnitude;
            }
            
            combinedResponse.push({
                frequency: freq,
                magnitude: combinedMagnitudeDB,
                linearMagnitude: Math.pow(10, combinedMagnitudeDB / 20)
            });
        }
        
        return combinedResponse;
    }



/**
     * Generate SVG plot for frequency responses with theme support
     */
    generateSVGPlot(responses, labels, title = "") {
        const plotWidth = Math.max(this.width - this.margin.left - this.margin.right, 200);
        const plotHeight = Math.max(this.height - this.margin.top - this.margin.bottom, 150);
        
        // Find data ranges for frequency (X-axis)
        const minFreq = 10;
        const maxFreq = 24000;
        
        // Fixed dB range for Y-axis
        const minDB = -25;
        const maxDB = 15;
        
        // FIXED font sizes - no scaling
        const axisFontSize = 10;
        const tickFontSize = 9;
        const legendFontSize = 9;
        
        // Scales
        const xScale = (freq) => {
            const logMin = Math.log10(minFreq);
            const logMax = Math.log10(maxFreq);
            const logFreq = Math.log10(freq);
            return this.margin.left + ((logFreq - logMin) / (logMax - logMin)) * plotWidth;
        };
        
        const yScale = (db) => {
            return this.margin.top + plotHeight - ((db - minDB) / (maxDB - minDB)) * plotHeight;
        };
        
        // Generate SVG
        let svg = `<svg width="${this.width}" height="${this.height}" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${this.width} ${this.height}" preserveAspectRatio="xMidYMid meet">`;
        
        // Background with theme color
        svg += `<rect width="100%" height="100%" fill="${this.bgColor}"/>`;
        
        // Grid lines with theme colors
        svg += this._generateGrid(xScale, yScale, minFreq, maxFreq, minDB, maxDB, plotWidth, plotHeight, axisFontSize, tickFontSize);
        
        // Plot each response
        responses.forEach((response, index) => {
            svg += this._generateResponsePath(response, xScale, yScale, this.colors[index % this.colors.length]);
        });
        
        // Axes with theme colors
        svg += this._generateAxes(xScale, yScale, minFreq, maxFreq, minDB, maxDB, plotWidth, plotHeight, axisFontSize);
        
        // Title - only show if there's space
        if (title && this.width > 400) {
            svg += `<text x="${this.width / 2}" y="${Math.max(this.margin.top - 5, 10)}" text-anchor="middle" font-family="Arial, sans-serif" font-size="${axisFontSize}" font-weight="bold" fill="${this.textColor}">${title}</text>`;
        }
        
        // Legend - two column layout with theme colors
        svg += this._generateLegend(labels, plotWidth, legendFontSize);
        
        svg += `</svg>`;
        return svg;
    }

    /**
     * Generate grid lines with theme colors
     */
    _generateGrid(xScale, yScale, minFreq, maxFreq, minDB, maxDB, plotWidth, plotHeight, axisFontSize, tickFontSize) {
        let grid = '';
        
        const axisBottom = this.height - this.margin.bottom;
        const axisLeft = this.margin.left;
        
        // Horizontal grid lines (dB) - adjust density based on size
        const dbSteps = this.width < 400 ? [10] : [10, 5];
        for (let step of dbSteps) {
            for (let db = Math.ceil(minDB / step) * step; db <= maxDB; db += step) {
                const y = yScale(db);
                // Only draw grid line if it's within the plot area
                if (y >= this.margin.top && y <= axisBottom) {
                    grid += `<line x1="${axisLeft}" y1="${y}" x2="${this.width - this.margin.right}" y2="${y}" stroke="${this.gridColor}" stroke-width="1"/>`;
                    // Position dB labels with theme text color
                    grid += `<text x="${axisLeft - 5}" y="${y + 3}" text-anchor="end" font-family="Arial, sans-serif" font-size="${tickFontSize}" fill="${this.textColor}">${db.toFixed(0)}</text>`;
                }
            }
        }
        
        // 0dB line - highlight with theme color
        const zeroY = yScale(0);
        if (zeroY >= this.margin.top && zeroY <= axisBottom) {
            grid += `<line x1="${axisLeft}" y1="${zeroY}" x2="${this.width - this.margin.right}" y2="${zeroY}" stroke="${this.zeroLineColor}" stroke-width="1.5" stroke-dasharray="5,5"/>`;
        }
        
        // Vertical grid lines (frequency - log scale) - adjust density based on size
        const freqTicks = this._generateLogTicks(minFreq, maxFreq, this.width < 500);
        freqTicks.forEach(freq => {
            const x = xScale(freq);
            // Only draw grid line if it's within the plot area
            if (x >= axisLeft && x <= this.width - this.margin.right) {
                grid += `<line x1="${x}" y1="${this.margin.top}" x2="${x}" y2="${axisBottom}" stroke="${this.gridColor}" stroke-width="1"/>`;
                
                let label = freq >= 1000 ? `${(freq / 1000).toFixed(0)}k` : freq.toString();
                // Position frequency labels with theme text color
                grid += `<text x="${x}" y="${axisBottom + 12}" text-anchor="middle" font-family="Arial, sans-serif" font-size="${tickFontSize}" fill="${this.textColor}">${label}</text>`;
            }
        });
        
        return grid;
    }

    /**
     * Generate logarithmic frequency ticks with responsive density
     */
    _generateLogTicks(minFreq, maxFreq, isSmallScreen = false) {
        const ticks = [];
        const decades = Math.floor(Math.log10(maxFreq / minFreq));
        
        // Adjust tick density based on screen size
        const multipliers = isSmallScreen ? [1, 5] : [1, 2, 5];
        
        for (let decade = Math.floor(Math.log10(minFreq)); decade <= Math.ceil(Math.log10(maxFreq)); decade++) {
            const base = Math.pow(10, decade);
            multipliers.forEach(multiplier => {
                const freq = base * multiplier;
                if (freq >= minFreq && freq <= maxFreq) {
                    ticks.push(freq);
                }
            });
        }
        
        return ticks;
    }

    /**
     * Generate response path for a single filter
     */
    _generateResponsePath(response, xScale, yScale, color) {
        let path = `<path d="`;
        
        // Reduce number of points for better performance on small screens
        const step = this.width < 400 ? 2 : 1;
        
        for (let i = 0; i < response.length; i += step) {
            const point = response[i];
            const x = xScale(point.frequency);
            const y = yScale(point.magnitude);
            
            if (i === 0) {
                path += `M ${x} ${y} `;
            } else {
                path += `L ${x} ${y} `;
            }
        }
        
        path += `" stroke="${color}" stroke-width="${Math.max(2 * this.scale, 1.5)}" fill="none" />`;
        return path;
    }

    /**
     * Generate axes with theme colors
     */
    _generateAxes(xScale, yScale, minFreq, maxFreq, minDB, maxDB, plotWidth, plotHeight, axisFontSize) {
        let axes = '';
        
        const axisBottom = this.height - this.margin.bottom;
        const axisLeft = this.margin.left;
        
        // X-axis line with theme color
        axes += `<line x1="${axisLeft}" y1="${axisBottom}" x2="${this.width - this.margin.right}" y2="${axisBottom}" stroke="${this.axisColor}" stroke-width="1.5"/>`;
        
        // X-axis label - only show if there's space, with theme text color
        if (this.width > 350) {
            axes += `<text x="${this.width / 2}" y="${axisBottom + 20}" text-anchor="middle" font-family="Arial, sans-serif" font-size="${axisFontSize}" fill="${this.textColor}">Frequency (Hz)</text>`;
        }
        
        // Y-axis line with theme color
        axes += `<line x1="${axisLeft}" y1="${this.margin.top}" x2="${axisLeft}" y2="${axisBottom}" stroke="${this.axisColor}" stroke-width="1.5"/>`;
        
        // Y-axis label - only show if there's space, with theme text color
        if (this.width > 350) {
            axes += `<text x="${axisLeft - 25}" y="${this.height / 2}" text-anchor="middle" font-family="Arial, sans-serif" font-size="${axisFontSize}" fill="${this.textColor}" transform="rotate(-90, ${axisLeft - 25}, ${this.height / 2})">Gain (dB)</text>`;
        }
        
        return axes;
    }

    /**
     * Generate two-column legend with theme colors
     */
    _generateLegend(labels, plotWidth, legendFontSize) {
        if (labels.length === 0) return '';
        
        // Organize labels into columns
        const column1 = []; // Band-related items
        const column2 = []; // Loudness-related items
        
        // Process labels and assign to columns
        labels.forEach((label, index) => {
            if (label.startsWith('Band ')) {
                column1.push({ label, color: this.colors[index % this.colors.length], index });
            } else if (label === 'All Bands') {
                column1.push({ label, color: this.colors[index % this.colors.length], index });
            } else if (label === 'Loudness') {
                column2.push({ label, color: this.colors[index % this.colors.length], index });
            } else if (label === 'Everything') {
                column2.push({ label, color: this.colors[index % this.colors.length], index });
            } else {
                // Default to column1 for any unclassified labels
                column1.push({ label, color: this.colors[index % this.colors.length], index });
            }
        });
        
        // Sort column1: Band items first, then "All Bands"
        column1.sort((a, b) => {
            if (a.label.startsWith('Band ') && b.label === 'All Bands') return -1;
            if (a.label === 'All Bands' && b.label.startsWith('Band ')) return 1;
            return a.index - b.index;
        });
        
        // Sort column2: Loudness first, then Everything
        column2.sort((a, b) => {
            if (a.label === 'Loudness' && b.label === 'Everything') return -1;
            if (a.label === 'Everything' && b.label === 'Loudness') return 1;
            return a.index - b.index;
        });
        
        let legend = '';
        const legendX = this.margin.left + 5;
        const legendY = this.margin.top + 12;
        const itemHeight = 14;
        const columnWidth = 90;
        const columnGap = 10;
        
        // Draw column1 (left column)
        column1.forEach((item, index) => {
            const y = legendY + index * itemHeight;
            legend += `<rect x="${legendX}" y="${y - 5}" width="10" height="10" fill="${item.color}"/>`;
            legend += `<text x="${legendX + 15}" y="${y + 1}" font-family="Arial, sans-serif" font-size="${legendFontSize}" fill="${this.textColor}">${item.label}</text>`;
        });
        
        // Draw column2 (right column) - only if we have items
        if (column2.length > 0) {
            const column2X = legendX + columnWidth + columnGap;
            column2.forEach((item, index) => {
                const y = legendY + index * itemHeight;
                legend += `<rect x="${column2X}" y="${y - 5}" width="10" height="10" fill="${item.color}"/>`;
                legend += `<text x="${column2X + 15}" y="${y + 1}" font-family="Arial, sans-serif" font-size="${legendFontSize}" fill="${this.textColor}">${item.label}</text>`;
            });
        }
        
        return legend;
    }
}

