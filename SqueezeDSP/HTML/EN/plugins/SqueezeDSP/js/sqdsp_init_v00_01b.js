/*---------------------------------------------------
Initialization and Event Handlers
-----------------------------------------------------*/

function initializeApp() {
    if (typeof myPlayer !== 'undefined' && typeof playerid !== 'undefined') {
        myPlayer.value = playerid;
    }

    SqueezeDSPGetList(LocalBuildLists);
    BuildFilterType("PEQ-filter-selector", "peak");
    SqueezeDSPFetchCurrentSettings(LocalUpdateSettings);

    GetLogSummary();
    setInterval(GetLogSummary, 30 * 1000);
}

function handleFileSelection(event) {
    const files = event.target.files;
    if (!files || files.length === 0) return;
    
    if (files.length > 1) {
        outputlist('Only 1 file at a time Please');
        event.target.value = '';
        return;
    }

    const file = files[0];
    const extension = file.name.split('.').pop().toLowerCase();

    if (extension === 'txt') {
        readFile(file, ConfirmREW);
    } else if (extension === 'wav') {
        importWavFile(file, outputlist, refreshFIRWavList);
    } else {
        outputlist('Unsupported file type: ' + extension);
    }

    event.target.value = '';
}

function handleUnsavedChanges(event) {
    const applyButton = document.getElementById('btn_Apply');
    if (applyButton?.classList.contains('button-amber')) {
        event.preventDefault();
        event.returnValue = 'You have unsaved changes. Press Leave to exit and Cancel to go back.';
        return event.returnValue;
    }
}

// DOM Ready Initialization
document.observe('dom:loaded', function() {
    updateTextConstants();
    initializeApp();
    $('filePicker').observe('change', handleFileSelection);
    window.addEventListener('beforeunload', handleUnsavedChanges);
});