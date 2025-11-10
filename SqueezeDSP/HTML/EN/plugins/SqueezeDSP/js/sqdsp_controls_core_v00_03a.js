/*---------------------------------------------------
Core UI Controls and Display Logic
-----------------------------------------------------*/

function logParentTheme() {
    const body = document.body;
    const textColor = getComputedStyle(body).color;
    
    console.log('=== THEME DETECTION LOG ===');
    console.log('Body classes:', body.className);
    console.log('Body computed color:', textColor);
    
    // Simple rule: if text color is light, we're in dark mode. If dark, we're in light mode.
    const rgb = textColor.match(/\d+/g);
    let isDark = false;
    
    if (rgb && rgb.length >= 3) {
        const [r, g, b] = rgb;
        const brightness = (r * 299 + g * 587 + b * 114) / 1000;
        isDark = brightness > 128; // Light text = dark theme
    }
    
    console.log('Decision: Using', isDark ? 'DARK' : 'LIGHT', 'theme based on text color');
    return isDark ? 'dark' : 'light';
}


function LocalBuildLists(data) {
    LocalBuildList('FIRWavFile', data);
    LocalBuildList('Preset', data);
}

function LocalBuildList(listType, data) {
    var select = document.getElementById("sel_" + listType);
    select.options.length = 1;
    
    var loop = data.result[listType + "_loop"];
    if (typeof loop == "object") {
        for (var j = 0; j < loop.length; j++) {
            var fullPath = loop[j][0];
            var fileName = fullPath.split(/[\\/]/).pop();
            
            var el = document.createElement("option");
            el.value = fullPath;
            el.textContent = fileName;
            el.dataset.fullPath = fullPath;
            
            select.appendChild(el);
        }
    }
}

function LocalUpdateSettings() {
    rebuildPEQUI('peqContainer');
    LocalDisplayVals();    
    
    myRadio = LocalSetupToggle('DSP', SqueezeDSPData.Client.Bypass, true);
    ToggleControl(myRadio, 'DSP_container', true);
                
    myRadio = LocalSetupToggle('Loudness', replaceNull(SqueezeDSPData.Client.Loudness.enabled,0));
    ToggleControl(myRadio, 'control_Loudness', false);        
    reStyleElement('btn_Apply', 'button-amber', 'button-blue');
    ListenForSlide();
}

function LocalDisplayVals() {
    if (!SqueezeDSPData.Client) SqueezeDSPData.Client = {};
    DisplayVal('Delay.delay', replaceNull(SqueezeDSPData.Client.Delay.delay, 0));
    DisplayVal('Width', replaceNull(SqueezeDSPData.Client.Width, 0));
    DisplayVal('Balance', replaceNull(SqueezeDSPData.Client.Balance, 0));
    DisplayVal('Preamp', replaceNull(SqueezeDSPData.Client.Preamp, 0));
    DisplayVal('Loudness.listening_level', replaceNull(SqueezeDSPData.Client.Loudness.listening_level,85));
    const presetPath = SqueezeDSPData.Client.Preset || 'none';
  
    document.getElementById('edt_NewPreset').value = getBaseFilename(presetPath);
    
    const firPath = SqueezeDSPData.Client.FIRWavFile || 'none';
    highlightMatchingOption('sel_FIRWavFile', firPath);
    
  
    document.getElementById('ClientName').value = SqueezeDSPData.ClientName;
}

function DisplayVal(ElName, MyVal) {
    try {
        document.getElementById(ElName).value = MyVal;
        document.getElementById('val_' + ElName).value = MyVal;
    } catch {
        DisplayAlert(ElName, "Function DisplayVal failing for:");
    }
}

function LocalSetupToggle(myControl, newValue, InvertToggle = false) {
    myCheck = document.getElementById(myControl);
    myCheck.value = newValue;
    
    if (myCheck.value == 1) {
        if (!InvertToggle) myCheck.checked = true;
        else myCheck.checked = false;
    }
    if (myCheck.value == 0) {
        if (InvertToggle) myCheck.checked = true;
        else myCheck.checked = false;
    }
    return myCheck;
}

function ToggleControl(myElement, myControltoToggle, InvertToggle = false) {
    var myValue = myElement.value;
    var element = document.getElementById(myControltoToggle);

    if (InvertToggle) {
        if (myValue == 1) {
            element.style.display = 'none';
            
        } else {
            element.style.display = ''; // or 'block' depending on your layout
            
        }
    } else {
        if (myValue == 0) {
            element.style.display = 'none';
            
        } else {
            element.style.display = '';
            
        }
    }
}

function updateLoudnessToggle() {
    const loudnessEnabled = SqueezeDSPData.Client.Loudness && SqueezeDSPData.Client.Loudness.enabled == 1;
    const loudnessControl = document.getElementById('control_Loudness');
    
    if (loudnessControl) {
        loudnessControl.style.display = loudnessEnabled ? '' : 'none';
    }
    
    // Update graph visibility and content
    updateGraphVisibility();
    updatePEQGraph();
}




function reStyleElement(ElementId, fromStyle, toStyle) {
    const myElement = document.getElementById(ElementId);
    if (myElement) {
        myElement.classList.remove(fromStyle);
        myElement.classList.add(toStyle);
    } else {
        console.warn(`Element with ID '${ElementId}' not found.`);
    }
}

function HideAlert() {
    myMessage.className = "bubble";
    myMessage.innerText = '';
}

function DisplayAlert(FieldName, Message, Duration = 2000) {
    myMessage.className = "localAlert";
    myMessage.innerText = Message + ' ' + FieldName + " ...";
    setTimeout(function() { HideAlert(); }, Duration);    
}

function SetNewPreset(myEl) {
    var val = myEl.value;
    //Remove callback, it was originally to check that everything had been saved
    SqueezeDSPSavePreset(val);    
    DisplayAlert('Preset', 'Saving to ' + val);
}

function GetLogSummary() {
    SqueezeDSPLogSummary(LocalDisplayLogSummary);
}

function LocalDisplayLogSummary(logData) {
    let myHTML = '';
    const tracklimit = 10;

    try {
        for (let i = 1; i <= tracklimit; i++) {
            const peakdBfs = logData.result['peakdBfs_' + i];
            let peakStyle = 'peak peak-unknown';
            
            if (peakdBfs < -5) peakStyle = 'peak peak-toolow';
            else if (peakdBfs < -1) peakStyle = 'peak peak-ok';
            else if (peakdBfs <= 0.1) peakStyle = 'peak peak-high';
            else if (peakdBfs > 0.1) peakStyle = 'peak peak-clipping';

            const tooltipContent = `
                <div class="tooltip-row">
                    <div class="tooltip-label">Playerid:</div>
                    <div class="tooltip-value">${logData.result['playerid_' + i]}</div>
                </div>
                <div class="tooltip-row">
                    <div class="tooltip-label">Start Date:</div>
                    <div class="tooltip-value">${logData.result['date_' + i]}</div>
                </div>
                <div class="tooltip-row">
                    <div class="tooltip-label">Start Time:</div>
                    <div class="tooltip-value">${logData.result['time_' + i]}</div>
                </div>
                <div class="tooltip-row">
                    <div class="tooltip-label">Preamp Gain:</div>
                    <div class="tooltip-value">${logData.result['preamp_' + i]}</div>
                </div>
                <div class="tooltip-row">
                    <div class="tooltip-label">Sample Rate:</div>
                    <div class="tooltip-value">${logData.result['outputrate_' + i]}</div>
                </div>
                <div class="tooltip-row">
                    <div class="tooltip-label">Peak Level:</div>
                    <div class="tooltip-value">${peakdBfs}</div>
                </div>
            `;

            myHTML += `
                <div class="led-container">
                    <div class="${peakStyle}"></div>
                    <div class="tooltiptext">
                        ${tooltipContent}
                    </div>
                </div>
            `;
        }
    } catch (error) {
        console.error("LocalDisplayLogSummary error:", error);
        DisplayAlert("LocalDisplayLogSummary", "Error building log summary", 3000);
    }
    
    document.getElementById('logSummary').innerHTML = myHTML;
}

function getBaseFilename(fullPath) {
    // Extract filename with extension using both Windows and Unix path separators
    const filenameWithExt = fullPath.split(/[\\/]/).pop();
    
    // Remove all extensions (everything after the first dot)
    const baseFilename = filenameWithExt.split('.')[0];
    
    return baseFilename;
}

function highlightMatchingOption(selectElementId, targetFullPath) {
    const selectElement = document.getElementById(selectElementId);
    if (!selectElement) {
        console.warn('Element not found:', selectElementId);
        return;
    }

    if (!targetFullPath || targetFullPath === '-') {
        selectElement.selectedIndex = 0;
        return;
    }

    // Use getBaseFilename to extract the short name (keeps original case)
    const targetBaseName = getBaseFilename(targetFullPath);
    const normalizePath = path => path.replace(/\\/g, '/');
    
    console.log(`Matching target: ${targetFullPath}`);
    console.log(`Base filename: ${targetBaseName}`);

    const isMaterialUI = selectElement.classList.contains('MuiSelect-nativeInput') || 
                        selectElement.closest('.MuiInputBase-root');

    const setValue = (element, value) => {
        if (isMaterialUI) {
            const hiddenInput = element.closest('.MuiInputBase-root')?.querySelector('input[type="hidden"]');
            if (hiddenInput) {
                hiddenInput.value = value;
                const event = new Event('change', { bubbles: true });
                hiddenInput.dispatchEvent(event);
            }
            
            const displayNode = element.closest('.MuiInputBase-root')?.querySelector('.MuiSelect-select');
            if (displayNode) {
                displayNode.textContent = value;
            }
        } else {
            for (let i = 0; i < element.options.length; i++) {
                if (element.options[i].value === value) {
                    element.selectedIndex = i;
                    element.dispatchEvent(new Event('change', { bubbles: true }));
                    break;
                }
            }
        }
    };

    // First try: match by base filename in option text
    if (!isMaterialUI) {
        for (let i = 0; i < selectElement.options.length; i++) {
            const optionBaseName = getBaseFilename(selectElement.options[i].text);
            if (optionBaseName === targetBaseName) {
                console.log(`Matched by base filename in text: ${selectElement.options[i].text}`);
                setValue(selectElement, selectElement.options[i].value);
                return;
            }
        }
    }

    // Second try: match by full path in option value
    const targetPath = normalizePath(targetFullPath);
    for (let i = 0; i < selectElement.options.length; i++) {
        const optionValue = normalizePath(selectElement.options[i].value);
        if (optionValue === targetPath) {
            console.log(`Matched by full path: ${optionValue}`);
            setValue(selectElement, selectElement.options[i].value);
            return;
        }
    }

    // Third try: match by base filename in option value
    for (let i = 0; i < selectElement.options.length; i++) {
        const optionBaseName = getBaseFilename(selectElement.options[i].value);
        if (optionBaseName === targetBaseName) {
            console.log(`Matched by base filename in value: ${selectElement.options[i].value}`);
            setValue(selectElement, selectElement.options[i].value);
            return;
        }
    }

    console.warn('No matching option found for:', targetFullPath);
}

function ListenForSlide() {
    const allRanges = document.querySelectorAll(".Slide");
    allRanges.forEach(wrap => {
        const range = wrap.querySelector(".range");
        const bubble = wrap.querySelector(".bubble");

        range.addEventListener("input", () => {
            setBubble(range, bubble);
        });
        setBubble(range, bubble);
    });
}

function setBubble(range, bubble) {
    const val = range.value;
    const min = range.min ? range.min : 0;
    const max = range.max ? range.max : 100;
  
    var mySlideName = range.id;
    if (mySlideName.endsWith("freq") || mySlideName.endsWith("Frequency")) {
        bubble.innerHTML = logScaleMapper(val);
    } else {
        bubble.innerHTML = val;
    }    
}

function showBubble(myObj) {
    var myBubble = document.getElementById(myObj.id + 'Bubble');
    setBubble(myObj, myBubble);
    myBubble.style.display = 'block';
}

function hideBubble(myObj) {
    document.getElementById(myObj.id + 'Bubble').style.display = 'none';
}

function improveMobileSliders() {
    const sliders = document.querySelectorAll('.range');
    
    sliders.forEach(slider => {
        // Prevent accidental changes on mobile
        slider.addEventListener('touchstart', function(e) {
            this.setAttribute('data-touch-start', this.value);
        });
        
        slider.addEventListener('touchend', function(e) {
            const startValue = this.getAttribute('data-touch-start');
            if (Math.abs(this.value - startValue) < 0.5) {
                // Small change, might be accidental
                console.log('Potential accidental touch on slider');
            }
        });
    });
}

// Simplified mobile initialization
function initializeTouchProtection() {
    if ('ontouchstart' in window) {
        console.log('Initializing touch protection for mobile');
        
        const ranges = document.querySelectorAll('.range');
        ranges.forEach(range => {
            range.addEventListener('touchstart', function(e) {
                // Small delay to prevent accidental changes
                setTimeout(() => {
                    this.focus();
                }, 100);
            });
        });
    }
}