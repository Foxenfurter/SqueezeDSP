/*---------------------------------------------------
Initialization and Event Handlers
-----------------------------------------------------*/

function initializeApp() {
    if (typeof myPlayer !== 'undefined' && typeof playerid !== 'undefined') {
        myPlayer.value = playerid;
    }

    SqueezeDSPGetList(function(data) {
        LocalBuildLists(data);
        SqueezeDSPFetchCurrentSettings(LocalUpdateSettings);
    });
    BuildFilterType("PEQ-filter-selector", "peak");
    
	
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

function initSectionToggles() {
    var pairs = [
        { toggle: 'toggle_presets',  body: 'body_presets'  },
        { toggle: 'toggle_signal',   body: 'body_signal'   },
        { toggle: 'toggle_eq',       body: 'body_eq'       },
        { toggle: 'toggle_external', body: 'body_external' }
    ];
    pairs.forEach(function(p) {
        var cb   = document.getElementById(p.toggle);
        var body = document.getElementById(p.body);
        if (!cb || !body) return;

        // Restore saved state
        var saved = localStorage.getItem('sqdsp_' + p.toggle);
        if (saved !== null) {
            cb.checked = saved === 'true';
            body.style.display = cb.checked ? '' : 'none';
        }

        cb.addEventListener('change', function() {
            body.style.display = this.checked ? '' : 'none';
            localStorage.setItem('sqdsp_' + p.toggle, this.checked);
            if (p.toggle === 'toggle_eq' && this.checked) {
                if (typeof updatePEQGraph === 'function') updatePEQGraph();
            }
        });
    });
}


// DOM Ready Initialization - handled in main page
/*document.observe('dom:loaded', function() {
    updateTextConstants();
    initializeApp();
    $('filePicker').observe('change', handleFileSelection);
    window.addEventListener('beforeunload', handleUnsavedChanges);
});*/