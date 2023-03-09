// Lets create the  SqueezeDSPData object
function getCurrentPlayer()
{
   return (playerid);
}

SqueezeDSPData = function()

{
    
	this._EQ_loop = {};

	// Dictionary of lists (rc & MatrixFile filters, presets)
	// where the object model is nested - e.g. Loudness->enabled
	// we are using the convention as . = -> in a string and 
	// in object variables as _ = ->
	// the defaults below, will not actually be used as they are set at the server end and subsequently get overwritten
	this.Bypass = 0;
	this.Lists = {};
	this.MatrixFile = "";
	this.FIRWavFile = "";
	this.Preset = "";
	this.EQBands = 2;
	this.Balance = 0.0 ;
	this.Delay_delay = 0.0;
	this.Flatness= 10 ;
	this.Loudness_enabled = 0;
	this.Preamp = -12.0;
	this.Highpass_enabled =  0;
	this.Highpass_freq =  40;
	this.Highpass_q =  1.3;
	this.Highshelf_enabled =  0;
	this.Highshelf_freq =  8000;
	this.Highshelf_gain =  3.0;
	this.Highshelf_slope =  6.0;
	this.Lowpass_enabled =  0;
	this.Lowpass_freq =  20000;
	this.Lowpass_q =  1.0;
	this.Lowshelf_enabled =  0;
	this.Lowshelf_freq =  300;
	this.Lowshelf_gain =  6.0;
	this.Lowshelf_slope =  6.0;
	this.ClientName = "";
}

function UpdateSqueezeDSPData(data)
{
		SqueezeDSPData.Bypass = data.result['Bypass'];
		SqueezeDSPData.ClientName = data.result['ClientName'];
		SqueezeDSPData.EQBands =   data.result['EQBands'];
		SqueezeDSPData.Balance =   data.result['Balance'];
		SqueezeDSPData.Delay_delay =   data.result['Delay.delay'];
		//SqueezeDSPData.Flatness =   data.result['Flatness'];
		SqueezeDSPData.Loudness_enabled =   data.result['Loudness.enabled'];
		//SqueezeDSPData.Width =   data.result['Width'];
		
		SqueezeDSPData.MatrixFile = data.result['MatrixFile'];
		SqueezeDSPData.FIRWavFile = data.result['FIRWavFile'];
		SqueezeDSPData.Preset = data.result['Preset'];
		SqueezeDSPData.Preamp = data.result['Preamp'];
		
		SqueezeDSPData.Highpass_enabled =   data.result['Highpass.enabled'];
		SqueezeDSPData.Highpass_freq =   data.result['Highpass.freq'];
		SqueezeDSPData.Highpass_q =   data.result['Highpass.q'];
		
		SqueezeDSPData.Highshelf_enabled =   data.result['Highshelf.enabled'];
		SqueezeDSPData.Highshelf_freq =   data.result['Highshelf.freq'];
		SqueezeDSPData.Highshelf_gain =   data.result['Highshelf.gain'];
		SqueezeDSPData.Highshelf_slope =   data.result['Highshelf.slope'];
		
		SqueezeDSPData.Lowpass_enabled =   data.result['Lowpass.enabled'];
		SqueezeDSPData.Lowpass_freq =   data.result['Lowpass.freq'];
		SqueezeDSPData.Lowpass_q =   data.result['Lowpass.q'];
		
		SqueezeDSPData.Lowshelf_enabled =   data.result['Lowshelf.enabled'];
		SqueezeDSPData.Lowshelf_freq =   data.result['Lowshelf.freq'];
		SqueezeDSPData.Lowshelf_gain =   data.result['Lowshelf.gain'];
		SqueezeDSPData.Lowshelf_slope =   data.result['Lowshelf.slope'];

		// Copy EQ_loop
		SqueezeDSPData.EQ_loop = data.result.EQ_loop;

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

function SqueezeDSPGetSettings(callback)
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
					'squeezedsp.current'
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
