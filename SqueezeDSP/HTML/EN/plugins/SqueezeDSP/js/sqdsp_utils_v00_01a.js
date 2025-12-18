/*---------------------------------------------------
Utility Functions
-----------------------------------------------------*/

function replaceNull(ValueToCheck, DefaultValue) {    
    if (!ValueToCheck) return DefaultValue;
    else return ValueToCheck;
}

function iSlide(myObj) {
    myVal = document.getElementById('val_' + myObj.id);
    var mySlideName = myObj.id;
    
    if (mySlideName.endsWith("freq") || mySlideName.endsWith("Frequency")) {
        myVal.value = logScaleMapper(myObj.value);
    } else {
        myVal.value = myObj.value;
    }
    
    document.getElementById(myObj.id + 'Bubble').style.display = 'none';    
    NewFieldValue(myObj.id, myVal, false);
}

function SliderReset() {
    try {
        this.value = 0;
        myVal = document.getElementById('val_' + this.id);
        myVal.value = this.value;
        NewFieldValue(this.id, myVal, false);
    } catch {
        alert('Error on SliderReset');
    }
}

function LocalClearSettings() {
    InitialiseSqueezeDSPData();
    LocalUpdateSettings();
    highlightMatchingOption('sel_FIRWavFile', 'None');
    highlightMatchingOption('sel_Preset', 'None');
    reStyleElement('btn_Apply', 'button-blue', 'button-amber');
    reStyleElement('btn_LoadPreset', 'button-amber', 'button-teal');
}

function SwitchCheckbox(myElement, InvertToggle = false) {
    if (myElement.checked) {
        if (!InvertToggle) myElement.value = 1;
        else myElement.value = 0;
    }
    
    if (!myElement.checked) {
        if (InvertToggle) myElement.value = 1;
        else myElement.value = 0;
    }
}