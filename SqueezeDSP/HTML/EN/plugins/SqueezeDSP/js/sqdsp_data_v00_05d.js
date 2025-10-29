// Lets create the  SqueezeDSPData object
function getCurrentPlayer()
{
   return (playerid);
}

SqueezeDSPData = {
    Client: {},
    ClientName: "",
    Revision: 0
};

function InitialiseData()

    {
    return {
        Bypass: 0,
        Preamp: 0,
        Balance: 0,
        Width: 0,
        Delay: { delay: 0 },
        Loudness: {
            enabled: 0,
            listening_level: 85
        },
        Filters: [],
        FIRWavFile: "-",
        Last_preset: "",
        Preset: "None"
    };
}

function InitialiseSqueezeDSPData()
{
    if (typeof SqueezeDSPData === 'undefined') {
        SqueezeDSPData = {
            ClientName: "",
            Revision: 0
        };
        return;
    }
    SqueezeDSPData.Client = InitialiseData();
    // Ensure top-level structure exists
    SqueezeDSPData.Client = SqueezeDSPData.Client || {};
    SqueezeDSPData.ClientName = SqueezeDSPData.ClientName || "";
    SqueezeDSPData.Revision = SqueezeDSPData.Revision || 0;

}


function transformLegacyFilters(data) {
	if (!data || !data.Client) return data;

    const client = data.Client;
    if (!client.Filters) {
        client.Filters = [];
    }

    // Helper functions
    const toBoolean = val => String(val) === "1";
    const toNumber = val => parseFloat(val) || 0;

    // Process EQBand_* filters (Peaking filters)
    const eqBandKeys = Object.keys(client).filter(key => key.startsWith('EQBand_'));

    // Determine conversion count
    const eqBandsCount = client.EQBands ? parseInt(client.EQBands) : 0;
    const conversionCount = Math.min(eqBandsCount, eqBandKeys.length);

// Convert only the required bands
    for (let i = 0; i < conversionCount; i++) {
        const key = `EQBand_${i}`;
        if (client[key]) {
            const filter = client[key];
            client.Filters.push({
                FilterType: "peak",
                Frequency: toNumber(filter.freq),
                Gain: toNumber(filter.gain),
                SlopeType: "Q",
                Slope: toNumber(filter.q)
            });
        }
}

// Delete ALL EQBand_* keys and EQBands
eqBandKeys.forEach(key => delete client[key]);
delete client.EQBands;

    // Process Lowshelf
    if (client.Lowshelf) {
        const ls = client.Lowshelf;
        if (toBoolean(ls.enabled)) {
            client.Filters.push({
                FilterType: "lowshelf",
                Frequency: toNumber(ls.freq),
                Gain: toNumber(ls.gain),
                SlopeType: "slope",
                Slope: toNumber(ls.slope)
            });
        }
        delete client.Lowshelf;
    }

    // Process Highshelf
    if (client.Highshelf) {
        const hs = client.Highshelf;
        if (toBoolean(hs.enabled)) {
            client.Filters.push({
                FilterType: "highshelf",
                Frequency: toNumber(hs.freq),
                Gain: toNumber(hs.gain),
                SlopeType: "slope",
                Slope: toNumber(hs.slope)
            });
        }
        delete client.Highshelf;
    }

    // Process Lowpass
    if (client.Lowpass) {
        const lp = client.Lowpass;
        if (toBoolean(lp.enabled)) {
            client.Filters.push({
                FilterType: "lowpass",
                Frequency: toNumber(lp.freq),
                Gain: 0,
                SlopeType: "Q",
                Slope: toNumber(lp.q)
            });
        }
        delete client.Lowpass;
    }

    // Process Highpass
    if (client.Highpass) {
        const hp = client.Highpass;
        if (toBoolean(hp.enabled)) {
            client.Filters.push({
                FilterType: "highpass",
                Frequency: toNumber(hp.freq),
                Gain: 0,
                SlopeType: "Q",
                Slope: toNumber(hp.q)
            });
        }
        delete client.Highpass;
    }

    // Remove deprecated fields
    delete client.EQBands;
    
    return data;
}



function SqueezeDSPGetList(callback)
{
	// calls plugin filtersQuery
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'squeezedsp.filters'
				]
			]
		}),

		onFailure: function() { alert('Failed'); },

		onSuccess: function(response) {
			// debugger;
		var data = response.responseText.evalJSON(true);

		callback(data);

		}
	});
}


function SqueezeDSPLogSummary(callback)
{
	//alert ('Getting Settings');
	// calls plugin currentQuery
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		//asynchronous: false,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'squeezedsp.logsummary'
				]
			]
		}),

		onFailure: function() { alert('Failed'); },

		onSuccess: function(response) {
			// debugger;
		var data = response.responseText.evalJSON();
		callback(data);
		
		}
	});
}



function SqueezeDSPSelectPreset()
{
	// Save this value (async)
	// calls plugin setvalCommand - should drop through to loading preset
	var myProperty='Preset';
	var myVal = 'Joxy.preset.conf';
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'squeezedsp.setval',
					'key:'+myProperty,
					'val:'+myVal
				]
				]
			}),
			onFailure: function() { alert('Failed') },
			onSuccess: function(response) { 	// debugger;
			var data = response.responseText.evalJSON();
			SqueezeDSPGetSettings(LocalUpdateSettings);
			}
		});
	}

function SqueezeDSPSelectValue(myProperty, myVal, callback)
{
	// calls plugin setvalCommand - should drop through to setpref command
	// Save this value (async)

	//alert (myProperty);
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'squeezedsp.setval',
					'key:'+myProperty,
					'val:'+myVal
				]
				]
			}),
			onFailure: function() { alert('Failed') },
			onSuccess: function(response) { 	// debugger;
			var data = response.responseText.evalJSON();
			if(typeof callback !== 'undefined'){
					SqueezeDSPGetSettings(callback);
				};
			//SqueezeDSPGetSettings(LocalUpdateSettings);
			}
		});
	}
function SqueezeDSPSavePreset(myVal, callback)
{
	// calls plugin saveasCommand
	// Save this value (async)
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'squeezedsp.saveas',
					'preset:' + myVal,
				],
			]

		}),
		onFailure: function() { alert('Failed'); },

		onSuccess: function(response) {
			// debugger;
		var data = response.responseText.evalJSON();
				
		callback();
		}	});
}

function SqueezeDSPSaveEQBand(myBand, myFreq, myGain, myQ)
{
				//calls plugin seteqCommand
				new Ajax.Request('/jsonrpc.js', {
					method: 'post',
					asynchronous: true,
					postBody: Object.toJSON({
						id: 1, 
						method: 'slim.request', 
						params: [
							getCurrentPlayer(), 
							[
								'squeezedsp.seteq',
								'band:'+myBand,
								'freq:'+myFreq,
								'gain:'+myGain,
								'q:'+myQ
							]
						]
					}),
					onFailure: function() { alert('Failed'); },
					onSuccess: function(response) {
					// debugger;
						var data = response.responseText.evalJSON();
					}
				});
}

// Fetch current settings from server
// Modified processing function
// Fetch current settings from server
function SqueezeDSPFetchCurrentSettings(callback) {
    new Ajax.Request('/jsonrpc.js', {
        method: 'post',
        postBody: Object.toJSON({
            id: 1, 
            method: 'slim.request', 
            params: [getCurrentPlayer(), ['squeezedsp.readclientSettings']]
        }),
        onSuccess: (response) => {
            const data = response.responseText.evalJSON();
            const rawJson = data.result.json;
            
            try {
                // Parse JSON directly into application state
                
                InitialiseSqueezeDSPData();
                SqueezeDSPData = JSON.parse(rawJson);
                
                // Add any non-persistent metadata
                SqueezeDSPData.ClientName = data.result.clientName;
                SqueezeDSPData.Revision = data.result.revision || 1;
                
                // Transform legacy filters to new format
                SqueezeDSPData = transformLegacyFilters(SqueezeDSPData);
                
                if (callback) callback();
               
            } catch (e) {
                console.error("JSON parsing error:", e);
            } finally {
                // Ensure we reset the flag even if errors occur
                
            }
        }
    });
}

function SqueezeDSPFetchPresetSettings(presetFilePath, callback) {
    // Only proceed if this is not a programmatic change
    const cleanedPresetFilePath = presetFilePath.replace(/\\/g, '/');
    
    // Better callback handling with validation
    let callbacks = [];
    if (callback) {
        if (Array.isArray(callback)) {
            callbacks = callback.filter(cb => typeof cb === 'function');
        } else if (typeof callback === 'function') {
            callbacks = [callback];
        } else {
            console.warn('SqueezeDSPFetchPresetSettings: callback is not a function or array of functions', callback);
        }
    }
    
    new Ajax.Request('/jsonrpc.js', {
        method: 'post',
        postBody: Object.toJSON({
            id: 1, 
            method: 'slim.request', 
            params: [getCurrentPlayer(), ['squeezedsp.readpresetSettings', 'presetFileName:' + cleanedPresetFilePath]]
        }),
        onSuccess: (response) => {
            const data = response.responseText.evalJSON();
            const rawJson = data.result.json;
            
            try {
                LocalClearSettings();
                SqueezeDSPData = JSON.parse(rawJson);
                SqueezeDSPData.ClientName = data.result.clientName;
                SqueezeDSPData.Revision = data.result.revision || 1;
                SqueezeDSPData = transformLegacyFilters(SqueezeDSPData);
                
                // Execute callbacks with better error handling
                if (callbacks.length > 0) {
                    callbacks.forEach(cb => {
                        try {
                            // Check if it's still a function before calling
                            if (typeof cb === 'function') {
                                cb();
                            } else {
                                console.warn('SqueezeDSPFetchPresetSettings: callback is no longer a function', cb);
                            }
                        } catch (e) {
                            console.error("Error executing callback in SqueezeDSPFetchPresetSettings:", e);
                        }
                    });
                }
            } catch (e) {
                console.error("JSON parsing error in SqueezeDSPFetchPresetSettings:", e);
            }
        },
        onFailure: (response) => {
            console.error('Failed to fetch preset settings', response.status, response.statusText);
        }
    });
}

function SqueezeDSPSaveAll(callback) {

 	
    new Ajax.Request('/jsonrpc.js', {
        method: 'post',
        postBody: Object.toJSON({
            id: 1,
            method: 'slim.request',
            params: [
                getCurrentPlayer(),
                [
                    'squeezedsp.saveall',
                    'val:' + JSON.stringify(SqueezeDSPData)  // Send the JSON string
                ]
            ]
        }),
		onSuccess: (response) => {
            // Just check for done status, no result content
            const data = response.responseText.evalJSON();
            if (data.result && data.result._done) {
                if (callback) callback(true);
            } else {
                console.error('Save failed:', data);
                if (callback) callback(false, data.error);
            }
            reStyleElement('btn_Apply', 'button-amber', 'button-blue');
        },
        onFailure: (response) => {
            console.error('Save failed', response.status, response.statusText);
            if (callback) callback(false, response.statusText);
            reStyleElement('btn_Apply', 'button-amber', 'button-red');
        }
    });
}


function importWavFile(file, callbackLog = console.log, callbackRefresh = "") {
    if (!confirm('Import Filter Impulse Response file:\n' + file.name)) {
        return;
    }
    
    callbackLog('Importing: ' + file.name);
   
    const reader = new FileReader();
    reader.onload = function(e) {
        const base64Data = e.target.result.split(',')[1];
        
        new Ajax.Request('/jsonrpc.js', {
            method: 'post',
            postBody: Object.toJSON({
                id: 1,
                method: 'slim.request',
                params: [
                    getCurrentPlayer(),
                    [
                        'squeezedsp.importwav',
                        '_p0:' + file.name,
                        '_p1:' + base64Data
                    ]
                ]
            }),
            onSuccess: (response) => {
                const json = response.responseText.evalJSON();
                if (json?.result?._success) {
                    callbackLog('Imported: ' + file.name);
					if (callbackRefresh) callbackRefresh();
                } else {
                    callbackLog('Failed to import: ' + file.name);
                }
            },
            onFailure: () => {
                callbackLog('Failed to import: ' + file.name);
            }
        });
    };
    reader.onerror = () => {
        callbackLog('Error reading file: ' + file.name);
    };
    reader.readAsDataURL(file);
}