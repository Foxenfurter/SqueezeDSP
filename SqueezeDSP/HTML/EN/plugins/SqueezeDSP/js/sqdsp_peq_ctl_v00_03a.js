/*---------------------------------------------------
DSP Controls (PEQ, Filters, etc.)
-----------------------------------------------------*/

let highPassHelp = document.getElementById('HighPass_Help')?.value || "High Pass Help";
let lowPassHelp = document.getElementById('LowPass_Help')?.value || "Low Pass Help";
let lowShelfHelp = document.getElementById('LowShelf_Help')?.value || "Low Shelf Help";
let highShelfHelp = document.getElementById('HighShelf_Help')?.value || "High Shelf Help";
let peakHelp = document.getElementById('Peak_Help')?.value || "Peak Help";

let peakdesc = document.getElementById('Peak_Desc')?.value || "Peak";
let highPassdesc = document.getElementById('HighPass_Desc')?.value || "High Pass";
let lowPassdesc = document.getElementById('LowPass_Desc')?.value || "Low Pass";
let lowShelfdesc = document.getElementById('LowShelf_Desc')?.value || "Low Shelf";
let highShelfdesc = document.getElementById('HighShelf_Desc')?.value || "High Shelf";

let freqDesc = document.getElementById('Freq_Desc')?.value || "Frequency";
let gainDesc = document.getElementById('Gain_Desc')?.value || "Gain";
let qHelp = document.getElementById('Q_Help')?.value || "Quality factor";
let slopeHelp = document.getElementById('Slope_Help')?.value || "Slope";

let filterTypes = [];

function updateTextConstants() {
    highPassHelp = document.getElementById('HighPass_Help')?.value || "High Pass Help";
    lowPassHelp = document.getElementById('LowPass_Help')?.value || "Low Pass Help";
    lowShelfHelp = document.getElementById('LowShelf_Help')?.value || "Low Shelf Help";
    highShelfHelp = document.getElementById('HighShelf_Help')?.value || "High Shelf Help";
    peakHelp = document.getElementById('Peak_Help')?.value || "Peak Help";

    peakdesc = document.getElementById('Peak_Desc')?.value || "Peak";
    highPassdesc = document.getElementById('HighPass_Desc')?.value || "High Pass";
    lowPassdesc = document.getElementById('LowPass_Desc')?.value || "Low Pass";
    lowShelfdesc = document.getElementById('LowShelf_Desc')?.value || "Low Shelf";
    highShelfdesc = document.getElementById('HighShelf_Desc')?.value || "High Shelf";

    freqDesc = document.getElementById('Freq_Desc')?.value || "Frequency";
    gainDesc = document.getElementById('Gain_Desc')?.value || "Gain";
    qHelp = document.getElementById('Q_Help')?.value || "Quality factor";
    slopeHelp = document.getElementById('Slope_Help')?.value || "Slope";

    filterTypes = [
        { value: "peak", label: peakdesc, abbr: "P",  tooltip: peakHelp },
        { value: "lowshelf", label: lowShelfdesc, abbr: "LS", tooltip: lowShelfHelp },
        { value: "highshelf", label: highShelfdesc, abbr: "HS", tooltip: highShelfHelp },
        { value: "lowpass", label: lowPassdesc, abbr: "LP", tooltip: lowPassHelp },
        { value: "highpass", label: highPassdesc, abbr: "HP", tooltip: highPassHelp }
    ];
}

const minQ = 0.1;
const maxQ = 20;
const minSlope = 0.05;
const maxSlope = 1.2;

function createDefaultFilter() {
    return {
        FilterType: 'peak',
        Frequency: 1000,
        Gain: 0,
        Slope: 1.41,
        SlopeType: 'Q'
    };
}

function slopeToQ(slope) {
    slope = Math.max(minSlope, Math.min(maxSlope, slope));
    const position = (slope - minSlope) / (maxSlope - minSlope);
    return roundTo(minQ + position * (maxQ - minQ),1);
}
        
function qToSlope(Q) {
    Q = Math.max(minQ, Math.min(maxQ, Q));
    const position = (Q - minQ) / (maxQ - minQ);
    return roundTo(minSlope + position * (maxSlope - minSlope),2);
}

function roundTo(value, digits) {
    const factor = 10 ** digits;
    return Math.round(value * factor) / factor;
}

function roundToNearest(numIn, roundto = 5) {
    return Math.round(numIn / roundto) * roundto;
}

function BuildFilterType(ContainerName, selectedFilterType="peak") {
    let htmlString = '';
    let container = document.getElementById(ContainerName);
    
    filterTypes.forEach(type => {
        htmlString += `
        <div class="filter-type-container">
            <label class="filter-type">
                <input type="radio" name="new_PEQ.filtertype" value="${type.value}"
                       ${type.value === selectedFilterType ? 'checked' : ''}>
                <span class="full-label">${type.label}</span>
                <span class="abbr-label">${type.abbr}</span>
            </label>
            <span class="tooltiptext">${type.tooltip}</span>
        </div>`;
    });
    
    container.innerHTML = htmlString;	
}

function getSelectedFilterType() {
    const radioGroup = document.getElementsByName('new_PEQ.filtertype');
    for (const radio of radioGroup) {
        if (radio.checked) {
            return radio.value;
        }
    }
    return "peak";
}

function LocalbuildPEQ(filters, labeltype) {
    try {
        let myHTML = '';

        const createBand = (bandIndex, filter) => {
            const isPassFilter = filter.FilterType === 'lowpass' || filter.FilterType === 'highpass';
            const filterType = filter.FilterType.toLowerCase();
            
            let slopeMin, slopeMax, slopeStep, slopeLabel, slopeTooTip;
            const isSlopeFilter = (filter.SlopeType === 'slope');

            if (isSlopeFilter) {
                slopeMin = 0.05;
                slopeMax = 1.2;
                slopeStep = 0.01;
                slopeLabel = 'Slope';
                slopeTooTip = slopeHelp;
            } else {
                slopeMin = 0.1;
                slopeMax = 20;
                slopeStep = 0.01;
                slopeLabel = 'Q';
                slopeTooTip = qHelp;
            }
            
            const freqPos = log2LinearMapper(filter.Frequency);
            
            return `
            <TABLE class="table-container" id="control_${labeltype}_${bandIndex}" >
                <TR>
                    <TD class="rowTitle"><span style="font-weight: bold;">Band ${bandIndex + 1}</span></TD>
                    <TD class="rowBody" > 
                        <div class="filter-group-alt">
                            ${filterTypes.map(type => `
                                <div class="filter-type-container">
                                    <label class="filter-type">
                                        <input type="radio" name="${labeltype}.${bandIndex}.filtertype" 
                                                value="${type.value}" ${filterType === type.value ? 'checked' : ''}
                                                onchange="handleFilterTypeChange(this, ${bandIndex}); updateFilterGraphFromControl(this)">
                                        <span class="full-label">${type.label}</span>
                                        <span class="abbr-label">${type.abbr}</span>
                                    </label>
                                    <span class="tooltiptext">${type.tooltip}</span>
                                </div>
                            `).join('')}
                        </div>
                    </TD>
                    <TD class="rowSuffix" style="text-align: right;">
                        <button class="sqdsp-click minibutton button-red text-button" 
                                onclick="deleteFilterByIndex(${bandIndex});">X</button>
                    </TD>
                </TR>
                <TR>
                    <TD class="rowTitle">${freqDesc}</TD>
                    <TD class="Slide">
                        <input class="range" type="range" orient="horizontal"
                               min="0" max="100" step="0.01" 
                               value="${freqPos}"
                               onpointerdown="showBubble(this)" 
                               onpointerup="hideBubble(this)" 
                               ondblclick="SliderReset.call(this)"
                               onchange="iSlide(this); updateFilterGraphFromControl(this)" 
                               id="${labeltype}.${bandIndex}.Frequency">
                        <output id="${labeltype}.${bandIndex}.FrequencyBubble" class="bubble"></output>
                    </TD>
                    <TD class="rowSuffix">
                        <Input type="number" onChange="valInputLog(this, true); updateFilterGraphFromControl(this)" 
                               min="20" max="20000" step="1" 
                               class="OutputVal" id="val_${labeltype}.${bandIndex}.Frequency" 
                               value="${filter.Frequency}">
                    </TD>
                </TR>
                ${!isPassFilter ? `
                <TR>
                    <TD class="rowTitle">${gainDesc}</TD>
                    <TD class="Slide">
                        <input class="range" type="range" orient="horizontal"
                               min="-25" max="15" step="0.1" 
                               value="${filter.Gain}"
                               onpointerdown="showBubble(this)" 
                               onpointerup="hideBubble(this)" 
                               ondblclick="SliderReset.call(this)"
                               onchange="iSlide(this); updateFilterGraphFromControl(this)" 
                               id="${labeltype}.${bandIndex}.Gain">
                        <output id="${labeltype}.${bandIndex}.GainBubble" class="bubble"></output>
                    </TD>
                    <TD class="rowSuffix">
                        <Input type="number" onChange="valInputDecimal(this, false); updateFilterGraphFromControl(this)" 
                               min="-25" max="15" step="0.1" 
                               class="OutputVal" id="val_${labeltype}.${bandIndex}.Gain" 
                               value="${filter.Gain}">
                    </TD>
                </TR>
                ` : ''}
                <TR>
                    <TD class="rowTitle">
                        <div class="tooltip">${slopeLabel}<span class="tooltiptext">${slopeTooTip}</span></div>
                    </TD>
                    <TD class="Slide">
                        <input class="range" type="range" orient="horizontal"
                               min="${slopeMin}" max="${slopeMax}" step="${slopeStep}" 
                               value="${filter.Slope}"
                               onpointerdown="showBubble(this)" 
                               onpointerup="hideBubble(this)" 
                               ondblclick="SliderReset.call(this)"
                               onchange="iSlide(this); updateFilterGraphFromControl(this)" 
                               id="${labeltype}.${bandIndex}.Slope">
                        <output id="${labeltype}.${bandIndex}.SlopeBubble" class="bubble"></output>
                    </TD>
                    <TD class="rowSuffix">
                        <Input type="number" onChange="valInputDecimal(this, false); updateFilterGraphFromControl(this)" 
                               min="${slopeMin}" max="${slopeMax}" step="${slopeStep}" 
                               class="OutputVal" id="val_${labeltype}.${bandIndex}.Slope" 
                               value="${filter.Slope}">
                    </TD>
                </TR>
            </TABLE>
            `;
        };

        for (let i = 0; i < filters.length; i++) {
            const filter = filters[i];
            myHTML += createBand(i, {
                FilterType: filter.FilterType || 'peak',
                Frequency: filter.Frequency || 1000,
                Gain: filter.Gain || 0,
                Slope: filter.Slope || (filter.SlopeType === 'slope' ? 0.3 : 1.41),
                SlopeType: filter.SlopeType || 'Q'
            });
        }

        return myHTML;
    } catch (e) {
        console.error("Error building PEQ profile:", e);
        return '<div class="error">Error building PEQ controls</div>';
    }
}


function AddPEQBand() {
    const client = SqueezeDSPData.Client;
    if (!client.Filters) client.Filters = [];
    
    const selectedFilterType = getSelectedFilterType();
    let frequency = 1000;
    let gain = 0;
    let slopeValue = 1.41;
    let slopeType = "Q";
    
    switch (selectedFilterType) {
        case "lowshelf":
            slopeType = "slope";
            slopeValue = 0.3;
            frequency = 300;
            gain = 3.0;
            break;
        case "highshelf":
            slopeType = "slope";
            slopeValue = 0.3;
            frequency = 8000;
            gain = 3.0;
            break;
        case "highpass":
            slopeType = "Q";
            slopeValue = 1.0;
            frequency = 20;
            break;    
        case "lowpass":
            slopeType = "Q";
            slopeValue = 1.0;
            frequency = 20000;
            break;
        default:
            slopeType = "Q";
            slopeValue = 1.41;
            frequency = 1000;
            gain = 0;
            break;
    }
    
    client.Filters.push({
        FilterType: selectedFilterType,
        Frequency: frequency,
        Gain: gain,
        Slope: slopeValue,
        SlopeType: slopeType
    });
    
    reStyleElement('btn_Apply', 'button-blue', 'button-amber');
    rebuildPEQUI('peqContainer');
}

function DelPEQBand() {
    const client = SqueezeDSPData.Client;
    if (client.Filters && client.Filters.length > 0) {
        client.Filters.pop();
        rebuildPEQUI('peqContainer');
    }
    reStyleElement('btn_Apply', 'button-blue', 'button-amber');
}

function deleteFilterByIndex(index) {
    if (!SqueezeDSPData.Client.Filters) return;
    
    if (index >= 0 && index < SqueezeDSPData.Client.Filters.length) {
        SqueezeDSPData.Client.Filters.splice(index, 1);
        rebuildPEQUI();
    }
    reStyleElement('btn_Apply', 'button-blue', 'button-amber');
}

function rebuildPEQUI(containerId = 'peqContainer') {
    const container = document.getElementById(containerId);
    if (!container) return;
    
    const hasFilters = SqueezeDSPData.Client.Filters && SqueezeDSPData.Client.Filters.length > 0;
    
    // Update container visibility based on filter count
    if (container) {
        container.style.display = hasFilters ? 'block' : 'none';
    }
    
    // Update graph visibility based on both loudness AND filters
    updateGraphVisibility();
    
    // Only build UI and update graph if we have filters
    if (hasFilters) {
        container.innerHTML = LocalbuildPEQ(
            SqueezeDSPData.Client.Filters, 
            "Filters"
        );
        ListenForSlide();
        updatePEQGraph();
    } else {
        container.innerHTML = ''; // Clear any existing content
        // Still update graph in case loudness is enabled
        updatePEQGraph();
    }
}

function handleFilterTypeChange(radio, bandIndex) {
    const filter = SqueezeDSPData.Client.Filters[bandIndex];
    const previousFilterType = filter.FilterType;
    const newFilterType = radio.value;
    filter.FilterType = newFilterType;
    
    const wasShelf = previousFilterType.includes('shelf');
    const isShelf = newFilterType.includes('shelf');
    
    if (wasShelf != isShelf) {
        if (isShelf) {
            if (filter.SlopeType === 'Q') {
                filter.SlopeType = 'slope';
                filter.Slope = qToSlope(filter.Slope) || 0.05;
            } else {
                filter.SlopeType = 'Q';
                filter.Slope = slopeToQ(filter.Slope) || 0.1;
            }
        } else {
            if (filter.SlopeType === 'slope') {
                filter.SlopeType = 'Q';
                filter.Slope = slopeToQ(filter.Slope) || 0.1;
            } else {
                filter.Slope = filter.Slope || 1.41;
            }
        }
    }
    SqueezeDSPData.Client.Filters[bandIndex] = filter;
    rebuildPEQUI();
    reStyleElement('btn_Apply', 'button-blue', 'button-amber');
}

function valInputDecimal(myElement) {    
    var val = parseFloat(myElement.value),
        min = parseFloat(myElement.min),
        max = parseFloat(myElement.max);

    if (val > max) myElement.value = max;
    if (val < min) myElement.value = min;
    
    var myElementId = myElement.id;
    var mySliderId = myElementId.replace('val_', '');
    document.getElementById(mySliderId).value = myElement.value;
    NewFieldValue(mySliderId, myElement, false);    
}

function valInputLog(myElement) {
    var val = parseFloat(myElement.value),
        min = parseFloat(myElement.min),
        max = parseFloat(myElement.max);

    if (val > max) myElement.value = max;
    if (val < min) myElement.value = min;
    
    var myElementId = myElement.id;
    var mySliderId = myElementId.replace('val_', '');
    document.getElementById(mySliderId).value = log2LinearMapper(myElement.value);
    NewFieldValue(mySliderId, myElement, false);    
}

function NewFieldValue(FieldName, myEl) {
    const val = myEl.value;
     // Split the field name by dots to get the nested property path
    const path = FieldName.split('.');
    let current = SqueezeDSPData.Client;
    const lastIndex = path.length - 1;
    reStyleElement('btn_Apply', 'button-blue', 'button-amber');
    // Special handling for Filters array - they have numeric indices
    if (path[0] === 'Filters' && path.length >= 2) {
        const filterIndex = parseInt(path[1]);
        const property = path[2];
        
        if (!current.Filters) current.Filters = [];
        if (!current.Filters[filterIndex]) {
            current.Filters[filterIndex] = createDefaultFilter();
        }
        
        if (property) {
            current.Filters[filterIndex][property] = convertValue(property, val);
        }
        return; // Exit early since we handled the Filters case
    }
    
    // For other properties, use the standard nested property assignment
    for (let i = 0; i < lastIndex; i++) {
        const key = path[i];
        if (!current[key]) current[key] = {};
        current = current[key];
    }
    // Set the final property value with type conversion
    current[path[lastIndex]] = convertValue(path[lastIndex], val);
}

function GetCurrentPlayerSettings() {
    var myplayerconfigfile = myPlayer.value + '.settings.json';
    myplayerconfigfile = myplayerconfigfile.replaceAll(":", "_"); 
    SqueezeDSPSelectValue('Preset', myplayerconfigfile, LocalUpdateSettings);
}

function Initialise() {
    SqueezeDSPGetList(LocalBuildLists);
    SqueezeDSPGetSettings(LocalUpdateSettings);
}

function control_check() {
    DisplayAlert('connecting to', 'control lib');
}

function convertValue(key, value) {
    const numericKeys = [
        'Frequency', 'Gain', 'Slope', 
        'delay', 'listening_level', 
        'Preamp', 'Balance', 'Width'
    ];
    
    if (numericKeys.includes(key)) {
        const num = parseFloat(value);
        return isNaN(num) ? 0 : num;
    }
    return value;
}

function logScaleMapper(value) {
    const minLinear = 0;
    const maxLinear = 100;
    const minLog = Math.log10(20);
    const maxLog = Math.log10(20000);
    var retval;

    const logValue = (maxLog - minLog) / (maxLinear - minLinear) * (value - minLinear) + minLog;
    retval = Math.round(Math.pow(10, logValue));
    
    if (retval > 12000) retval = roundToNearest(retval, 1000);
    else if (retval >= 5000 && retval < 12000) retval = roundToNearest(retval, 100);
    else if (retval >= 1000 && retval < 5000) retval = roundToNearest(retval, 10);
    else if (retval > 30 && retval < 1000) retval = roundToNearest(retval, 5);
    
    return retval;
}

function log2LinearMapper(value) {
    const minLog = Math.log10(20);
    const maxLog = Math.log10(20000);
    const minLinear = 0;
    const maxLinear = 100;
    
    const logValue = (Math.log10(value) - minLog) / (maxLog - minLog);
    const sliderPosition = minLinear + (logValue * (maxLinear - minLinear));
    
    return sliderPosition;
}

function positionFreqSlider(elementname, value) {
    var myObj = document.getElementById(elementname);
    myObj.value = log2LinearMapper(value);
}