/*---------------------------------------------------
File Import and Processing
-----------------------------------------------------*/

function ProcessREW(EQText) {
    LocalClearSettings();
    EQRecords = EQText.split(/\r?\n/);;
    
    for (var i = 0; i < EQRecords.length; i++) {
        if (EQRecords[i].startsWith('Preamp')) {
            var PreampSettings = EQRecords[i].split(/(\s+)/).filter(function(e) { return e.trim().length > 0; });
            Gain = Math.round(PreampSettings[1] * 100) / 100;
            SqueezeDSPData.Client.Preamp = Gain;
        }
        
        if (EQRecords[i].startsWith('Filter')) {
            var EQSettings = EQRecords[i].split(/(\s+)/).filter(function(e) { return e.trim().length > 0; });
            var FilterType = '';
            var SlopeType = 'Q';
            
            if (EQSettings[2] == 'ON') {
                rewFilterType = EQSettings[3];
                switch (rewFilterType) {
                    case 'PK': FilterType = 'peak'; break;
                    case 'LS': case 'LSC': FilterType = 'lowshelf'; break;
                    case 'HS': case 'HSC': FilterType = 'highshelf'; break;
                    case 'LP': FilterType = 'lowpass'; break;
                    case 'HP': FilterType = 'highpass'; break;
                    default: FilterType = 'peak'; break;
                }
                
                if (FilterType.includes('shelf')) SlopeType = 'slope';
                
                Freq = Math.round(EQSettings[5]);
                Gain = Math.round(EQSettings[8] * 100) / 100;
                Slope = Math.round(EQSettings[11] * 100) / 100;
                
                if (SlopeType == 'slope') Slope = Math.round(qToSlope(Slope) * 100) / 100;
                
                SqueezeDSPData.Client.Filters.push({
                    FilterType: FilterType,
                    Frequency: Freq,
                    Gain: Gain,
                    SlopeType: SlopeType,
                    Slope: Slope
                });
            }
        }
    }
    
    LocalUpdateSettings();
    reStyleElement('btn_Apply', 'button-blue', 'button-amber');
}

function ConfirmREW(EQText) {
    if (!confirm('Load the Settings:\n' + EQText)) return;
    ProcessREW(EQText);
}

function readFile(file, callback) {
    const reader = new FileReader();
    reader.onload = () => callback(reader.result);
    reader.readAsText(file);
    outputlist("Last File loaded was: " + file.name);
}

function dodrop(event) {
    var dt = event.dataTransfer;
    var files = dt.files;
    
    if (files.length > 1) {
        outputlist('Only 1 file at a time Please');
        return;
    }

    for (var i = 0; i < files.length; i++) {
        var file = files[i];
        var extension = file.name.split('.').pop().toLowerCase();
        
        if (extension === 'txt') {
            readFile(file, ConfirmREW);
        } else if (extension === 'wav') {
            importWavFile(file, outputlist, refreshFIRWavList);
        } else {
            outputlist('Unsupported file type: ' + extension);
        }
    }
}

function refreshFIRWavList() {
    SqueezeDSPGetList(function(data) {
        LocalBuildList('FIRWavFile', data);
    });
}
  
function outputlist(text) {
    document.getElementById("LastFile").textContent = text;
    document.getElementById("rewpicker").value = "";
}